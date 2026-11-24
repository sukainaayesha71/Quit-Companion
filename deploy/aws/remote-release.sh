#!/usr/bin/env bash
# Quit Companion - server half of deploy/aws/deploy.sh (runs on the EC2 server).
#   bash ~/quit-companion/remote-release.sh <release-stamp> [--detach]
# Expects deploy.sh to have uploaded releases/quit-companion-<stamp>.tgz plus
# .incoming/deploy.env and .incoming/firebase-admin.json.
#
# Steps 1-5 run BEFORE anything live changes; a failure there leaves the
# currently running version untouched (only its code folder is replaced).
set -euo pipefail

STAMP="${1:?release stamp}"
BASE="$HOME/quit-companion"
LOG="$BASE/releases/release-$STAMP.log"
EXIT_FILE="$BASE/releases/release-$STAMP.exit"

# --detach (used by deploy.sh): run this release in the background, logging to
# $LOG, so a dropped SSH connection can't kill it halfway. deploy.sh follows
# the log and waits for $EXIT_FILE, which holds the release's exit code.
if [ "${2:-}" = "--detach" ]; then
  if [ -f "$EXIT_FILE" ]; then echo "release $STAMP already finished"; exit 0; fi
  if [ -f "$BASE/release.pid" ]; then
    read -r OLD_PID OLD_STAMP < "$BASE/release.pid" || true
    if [ -n "${OLD_PID:-}" ] && kill -0 "$OLD_PID" 2>/dev/null; then
      if [ "${OLD_STAMP:-}" = "$STAMP" ]; then echo "release $STAMP already running"; exit 0; fi
      echo "release ${OLD_STAMP:-?} is still running (pid $OLD_PID) - not starting another"
      exit 1
    fi
  fi
  setsid nohup bash -c 'bash "$0" "$1"; echo $? > "$2"' "$0" "$STAMP" "$EXIT_FILE" \
    > "$LOG" 2>&1 < /dev/null &
  echo "$! $STAMP" > "$BASE/release.pid"
  echo "started release $STAMP in the background (log: $LOG)"
  exit 0
fi
APP="$BASE/app"
IN="$BASE/.incoming"
KEY_DEST="$BASE/secrets/firebase-admin.json"
IMG=deploy-backend                # compose image name: <project "deploy">-<service>
COMPOSE=(docker compose --env-file deploy/.env -f deploy/compose.yaml)

echo "== 1. unpack release $STAMP"
rm -rf "$APP/backend" "$APP/mobile" "$APP/deploy/reviews"
mkdir -p "$APP/deploy"
tar -C "$APP" -xzf "$BASE/releases/quit-companion-$STAMP.tgz"
if [ -f "$IN/deploy.env" ]; then
  tr -d '\r' < "$IN/deploy.env" > "$APP/deploy/.env"   # tolerate a Notepad-edited file
  chmod 600 "$APP/deploy/.env"
  rm -f "$IN/deploy.env"
fi
[ -f "$APP/deploy/.env" ] || { echo "no deploy/.env on the server"; exit 1; }
cd "$APP"

echo "== 2. build the backend image"
"${COMPOSE[@]}" build --pull 2>&1 | tail -n 12

echo "== 3. install the Firebase Admin key for the container user"
CUID=$(docker run --rm --entrypoint id "$IMG" -u)
CGID=$(docker run --rm --entrypoint id "$IMG" -g)
if [ -f "$IN/firebase-admin.json" ]; then
  sudo install -o "$CUID" -g "$CGID" -m 400 "$IN/firebase-admin.json" "$KEY_DEST"
  rm -f "$IN/firebase-admin.json"
fi
sudo test -f "$KEY_DEST" || { echo "Firebase Admin key missing at $KEY_DEST"; exit 1; }
echo "key at $KEY_DEST: owner uid $CUID, mode 400 (read-only, container user only)"

if [ "${SKIP_TESTS:-0}" != "1" ]; then
  echo "== 4. backend test suite inside the image (networking disabled: no live calls possible)"
  docker run --rm --network none -v "$APP:/src:ro" -w /src/backend \
    -e PYTHONDONTWRITEBYTECODE=1 "$IMG" python -m pytest -q -p no:cacheprovider 2>&1 | tail -n 15
else
  echo "== 4. tests skipped (SKIP_TESTS=1)"
fi

echo "== 5. preflight (prints OK/WARN/FAIL only, never values)"
docker run --rm --network none -v "$APP:/repo:ro" -v "$KEY_DEST:$KEY_DEST:ro" \
  "$IMG" python /repo/backend/tools/check_deploy_config.py /repo/deploy/.env

DOMAIN=$(sed -n 's/^SITE_DOMAIN=//p' deploy/.env | tail -n 1 | tr -d "\"' ")
PUBLIC_IP=$(curl -fsS --max-time 5 https://checkip.amazonaws.com || true)
RESOLVED=$(getent ahostsv4 "$DOMAIN" | awk 'NR==1{print $1}' || true)
if [ -z "$PUBLIC_IP" ] || [ "$RESOLVED" != "$PUBLIC_IP" ]; then
  echo "STOPPED before go-live: $DOMAIN resolves to '${RESOLVED:-nothing}', this server is '${PUBLIC_IP:-unknown}'."
  echo "Point the DNS name at the server's Elastic IP, wait a minute, then re-run deploy.sh."
  exit 3
fi
echo "DNS OK: $DOMAIN -> $PUBLIC_IP"

echo "== 6. start backend + worker + Caddy (waits until healthy)"
if ! "${COMPOSE[@]}" up -d --remove-orphans --wait --wait-timeout 300; then
  "${COMPOSE[@]}" ps
  "${COMPOSE[@]}" logs --tail 40
  echo "STARTED BUT NOT HEALTHY - see the logs above"
  exit 4
fi
"${COMPOSE[@]}" ps

echo "== 7. verify https://$DOMAIN"
ok=""
for _ in $(seq 1 30); do                       # Caddy may still be getting the certificate
  if curl -fsS --max-time 10 "https://$DOMAIN/health" >/dev/null 2>&1; then ok=1; break; fi
  sleep 4
done
if [ -z "$ok" ]; then
  "${COMPOSE[@]}" logs --tail 40 proxy
  echo "HTTPS NOT ANSWERING - see the Caddy log above"
  exit 5
fi
echo "health    $(curl -sS --max-time 10 "https://$DOMAIN/health")"
echo "ready     $(curl -sS --max-time 10 -w '  (HTTP %{http_code})' "https://$DOMAIN/ready")"
echo "redirect  $(curl -sS --max-time 10 -o /dev/null -w 'HTTP %{http_code} -> %{redirect_url}' "http://$DOMAIN/health")"
echo "auth      POST /predict/relapse without a token -> $(curl -sS --max-time 10 -o /dev/null -w 'HTTP %{http_code}' \
  -X POST -H 'Content-Type: application/json' -d '{}' "https://$DOMAIN/predict/relapse")"
echo "cert      $(echo | openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" 2>/dev/null \
  | openssl x509 -noout -issuer -enddate 2>/dev/null | tr '\n' ' ')"
echo "-- worker log"
"${COMPOSE[@]}" logs --tail 8 worker

echo "== 8. tidy up and report resources"
docker image prune -f >/dev/null
keep_newest() {  # $1 = how many to keep; remaining args = files (none is fine)
  local keep="$1"; shift
  [ "$#" -gt "$keep" ] || return 0
  ls -1t -- "$@" | tail -n +"$((keep + 1))" | xargs -r rm -f --
}
shopt -s nullglob              # an unmatched pattern expands to nothing, not to itself
keep_newest 3 "$BASE"/releases/*.tgz           # last 3 bundles, for rollback
keep_newest 5 "$BASE"/releases/release-*.log
keep_newest 5 "$BASE"/releases/release-*.exit
shopt -u nullglob
df -h / | awk 'NR==2{print "disk      "$3" used of "$2" ("$5")"}'
free -m | awk 'NR==2{print "memory    "$3" MB used of "$2" MB"}'
docker stats --no-stream --format 'container {{.Name}}: {{.MemUsage}}'
echo "DEPLOY OK - https://$DOMAIN"

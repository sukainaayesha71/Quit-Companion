#!/usr/bin/env bash
# Quit Companion - deploy the CURRENT working tree to the AWS server.
#
#   bash deploy/aws/deploy.sh <server-elastic-ip> [ssh-private-key]
#
# Run from Git Bash on the project PC. No git push is needed. It packages the
# working tree (code only: no .env files, keys, venv or training data), then
# uploads it with deploy/.env and the Firebase Admin key over SSH. The server
# then (deploy/aws/remote-release.sh) builds the image, runs the backend tests
# inside it with networking off, runs the preflight, checks DNS, starts
# backend + worker + Caddy and verifies HTTPS.
#
# First run on a fresh server also installs Docker (bootstrap-server.sh).
# SKIP_TESTS=1 skips the in-image test run (quick config-only redeploys).
# ADMIN_KEY=/path/key.json overrides the Admin key found via backend/.env.
set -euo pipefail

HOST="${1:?usage: deploy.sh <server-elastic-ip> [ssh-private-key]}"
KEY="${2:-$HOME/.ssh/quit-companion-aws}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REMOTE_BASE=/home/ubuntu/quit-companion
SERVER_KEY_PATH="$REMOTE_BASE/secrets/firebase-admin.json"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
SSH_OPTS=(-i "$KEY" -o BatchMode=yes -o ConnectTimeout=30 -o ServerAliveInterval=15
          -o ServerAliveCountMax=8 -o StrictHostKeyChecking=accept-new)
TARGET="ubuntu@$HOST"

fail() { echo "DEPLOY STOPPED: $*" >&2; exit 1; }
# Value of KEY=... in an env file (last one wins), quotes and CR removed. Never printed.
env_value() { sed -n "s/^$1=//p" "$2" | tail -n 1 | tr -d '\r' | sed -e "s/^[\"']//" -e "s/[\"']\$//"; }
remote() { ssh "${SSH_OPTS[@]}" "$TARGET" "$@"; }
# Slow or high-latency links can drop a connection during the SSH handshake.
# Retry only when SSH itself failed (exit 255), never when the command failed.
remote_retry() {
  local attempt rc
  for attempt in 1 2 3 4; do
    remote "$@" && return 0
    rc=$?
    [ "$rc" = 255 ] || return "$rc"
    [ "$attempt" = 4 ] || { echo "  (SSH connection failed, attempt $attempt - retrying in 10 s)" >&2; sleep 10; }
  done
  return 255
}
upload() {  # $1 local file, $2 remote path, $3 label for messages (never print key file names)
  local attempt
  for attempt in 1 2 3 4; do
    scp "${SSH_OPTS[@]}" "$1" "$TARGET:$2" && return 0
    [ "$attempt" = 4 ] || { echo "  (upload of ${3:-file} failed, attempt $attempt - retrying in 10 s)" >&2; sleep 10; }
  done
  return 1
}

echo "== checks on this PC"
[ -f "$KEY" ] || fail "SSH key not found: $KEY"
ENV_FILE="$REPO/deploy/.env"
[ -f "$ENV_FILE" ] || fail "deploy/.env is missing (copy deploy/.env.example and fill it in)"
DOMAIN="$(env_value SITE_DOMAIN "$ENV_FILE")"
case "$DOMAIN" in ""|localhost|your-api-domain.example) fail "set SITE_DOMAIN in deploy/.env to the real DNS name" ;; esac
[ "$(env_value FIREBASE_CREDENTIAL_FILE "$ENV_FILE")" = "$SERVER_KEY_PATH" ] \
  || fail "FIREBASE_CREDENTIAL_FILE in deploy/.env must be $SERVER_KEY_PATH (where the key is installed)"
if [ -z "${ADMIN_KEY:-}" ]; then
  rel="$(env_value FIREBASE_SERVICE_ACCOUNT_JSON "$REPO/backend/.env" 2>/dev/null || true)"
  case "$rel" in
    "") ;;
    /*|[A-Za-z]:*) ADMIN_KEY="$rel" ;;
    *) ADMIN_KEY="$REPO/backend/${rel#./}" ;;
  esac
fi
[ -n "${ADMIN_KEY:-}" ] && [ -f "$ADMIN_KEY" ] || fail "Firebase Admin key not found (set ADMIN_KEY=/path/to/key.json)"
grep -q '"type": *"service_account"' "$ADMIN_KEY" || fail "the Admin key file is not a service-account key"
echo "domain $DOMAIN, server $HOST, Admin key found (not printed)"

echo "== package the working tree"
BUNDLE="$WORK/quit-companion-$STAMP.tgz"
tar -C "$REPO" -czf "$BUNDLE" \
  --exclude='__pycache__' --exclude='*.pyc' --exclude='.pytest_cache' \
  --exclude='.env' --exclude='*firebase-adminsdk*.json' --exclude='*serviceAccount*.json' \
  --exclude='backend/ml/models' --exclude='backend/ml/outputs' \
  backend/app backend/requirements.txt backend/Dockerfile backend/.dockerignore \
  backend/tools backend/tests backend/ml \
  deploy/compose.yaml deploy/Caddyfile deploy/reviews deploy/.env.example \
  mobile/firebase.json \
  mobile/lib/features/health_bot/domain/local_health_bot_fallback.dart
if tar -tzf "$BUNDLE" | grep -Eq '(^|/)\.env$|adminsdk|serviceAccount'; then
  fail "the bundle would contain a secret file - nothing was uploaded"
fi
echo "bundle: $(tar -tzf "$BUNDLE" | wc -l) files, $(du -h "$BUNDLE" | cut -f1)"
for script in bootstrap-server.sh remote-release.sh; do      # LF line endings for Linux
  tr -d '\r' < "$REPO/deploy/aws/$script" > "$WORK/$script"
done

echo "== connect"
remote_retry true || fail "cannot SSH to $TARGET - does the security group allow this PC's current IP?"
if ! remote_retry 'command -v docker >/dev/null 2>&1 && test -d ~/quit-companion/secrets'; then
  echo "== first run: preparing the server (Docker, swap, folders)"
  upload "$WORK/bootstrap-server.sh" "bootstrap-server.sh" "bootstrap script"
  remote_retry 'bash ~/bootstrap-server.sh && rm -f ~/bootstrap-server.sh'
fi

echo "== upload release $STAMP"
upload "$BUNDLE" "$REMOTE_BASE/releases/" "release bundle"
upload "$WORK/remote-release.sh" "$REMOTE_BASE/remote-release.sh" "release script"
upload "$ENV_FILE" "$REMOTE_BASE/.incoming/deploy.env" "deploy/.env"
upload "$ADMIN_KEY" "$REMOTE_BASE/.incoming/firebase-admin.json" "Firebase Admin key"

echo "== release on the server (runs detached: a dropped connection can't interrupt it)"
remote_retry "SKIP_TESTS=${SKIP_TESTS:-0} bash $REMOTE_BASE/remote-release.sh $STAMP --detach"
LOGF="$REMOTE_BASE/releases/release-$STAMP.log"
EXITF="$REMOTE_BASE/releases/release-$STAMP.exit"
shown=0      # complete log lines already printed
status=""
show_new_lines() {  # $1 = text from the remote log; print only complete lines
  local complete=""
  [[ "$1" == *$'\n'* ]] && complete="${1%$'\n'*}"$'\n'
  if [ -n "$complete" ]; then
    printf '%s' "$complete"
    shown=$((shown + $(printf '%s' "$complete" | wc -l)))
  fi
}
for _ in $(seq 1 120); do              # up to ~40 minutes
  out="$(remote "tail -n +$((shown + 1)) $LOGF 2>/dev/null; printf '@@exit:%s' \"\$(cat $EXITF 2>/dev/null)\"" 2>/dev/null)" \
    || out="@@exit:"                  # this poll's connection failed - just try again
  show_new_lines "${out%@@exit:*}"
  status="${out##*@@exit:}"
  [ -n "$status" ] && break
  sleep 15
done
[ -n "$status" ] || fail "still running on the server after 40 minutes - see $LOGF there"
final="$(remote_retry "tail -n +$((shown + 1)) $LOGF" || true)"   # lines written just before the end
[ -z "$final" ] || printf '%s\n' "$final"
[ "$status" = 0 ] || fail "the release failed on the server (exit $status) - see the log above"

echo "== check from this PC"
curl -fsS --max-time 20 "https://$DOMAIN/health" && echo " <- https://$DOMAIN/health from outside AWS"
echo
echo "Release APK for this backend:"
echo "  cd mobile && flutter build apk --release --dart-define=OTP_BACKEND_BASE_URL=https://$DOMAIN"

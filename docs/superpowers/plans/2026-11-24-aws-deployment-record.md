# AWS deployment — implementation record (2026-11-24)

## Status: backend live at `https://quitcompanion.duckdns.org`

The project owner asked to deploy the whole project on AWS free-plan credits. The backend and worker now run on AWS EC2 behind Caddy with a Let's Encrypt certificate. A release APK was built against that URL. Firebase (Auth, Firestore, FCM) stays on Google, unchanged.

## What runs where

| Part | Where |
| --- | --- |
| FastAPI backend, worker, Caddy | EC2 `t3.small`, Ubuntu 26.04.1 LTS, **ap-southeast-2 (Sydney)**, Elastic IP `3.24.103.41`; Docker Compose stack from `deploy/compose.yaml` |
| Hostname / TLS | `quitcompanion.duckdns.org` (DuckDNS) → Elastic IP; Let's Encrypt certificate via Caddy (issuer YE2, valid to 2027-02-22, auto-renewed) |
| Auth, Firestore (`asia-south1`, Mumbai), FCM | Firebase, project `quit-companion`, unchanged |
| Android app | `mobile/build/app/outputs/flutter-apk/app-release.apk` (60.3 MB), built with `OTP_BACKEND_BASE_URL=https://quitcompanion.duckdns.org` |

**Region note.** The recommended region was ap-south-1 (Mumbai, next to Firestore). The owner's console was set to Sydney, so the instance was launched there. Measured TCP round trips:

| Route | Round trip |
| --- | --- |
| Sydney server → AWS Mumbai | ≈ 153 ms |
| Sydney server → local AWS endpoint | ≈ 2 ms |
| Deploy PC → Sydney | ≈ 705 ms |
| Deploy PC → Mumbai | ≈ 366 ms |

Every backend Firestore call therefore pays about 150 ms. Moving to Mumbai needs no app rebuild, because the APK and certificate are bound to the hostname:
1. launch a new instance in ap-south-1;
2. run `deploy.sh <new IP>`;
3. repoint DuckDNS;
4. delete the Sydney instance and release its Elastic IP.

## Owner decisions applied (template values kept; flip in `deploy/.env` + redeploy)

- `RELAPSE_PREDICTOR_MODE=rule_based`. `/ready` reports `requested_mode=rule_based, active=rule_based`. Table 4.3 ("Rule-based predictor in production") holds.
- `REQUIRE_CLINICAL_REVIEW=true`, with no review record and **no Gemini key on the server**. Non-emergency Health-Bot and coaching requests return 503 and the app shows its curated fallback. `/ready` returns 503 by design; container health uses `/health`.

## Changes made for the deployment

- **`deploy/aws/` (new).** All scripts are idempotent and documented in `deploy/aws/README.md`:

  | File | Purpose |
  | --- | --- |
  | `provision-cloudshell.sh` | Key pair, security group, instance, Elastic IP and budget (CloudShell) |
  | `bootstrap-server.sh` | Docker Engine + Compose from Docker's apt repo, 2 GB swap, folders |
  | `deploy.sh` | Packages the **working tree** (no git push), uploads it with `deploy/.env` and the Admin key, follows the server-side release |
  | `remote-release.sh` | Server side, in order: build, backend tests **inside the image with `--network none`**, preflight, DNS check, `compose up --wait`, HTTPS verification |
  | `teardown-cloudshell.sh` | Deletes everything after a typed confirmation |

- **README option 2b:** console clicks. New accounts couldn't use CloudShell ("account verification is in progress", up to 2 days).
- **`deploy/compose.yaml`:**
  - json-file log rotation (10 MB × 5) on all services;
  - a `caddy_config` volume.
- **`.gitattributes`:** `*.sh text eol=lf`. The repo uses `core.autocrlf=true`, and CRLF would break bash on Linux.
- **`docs/SETUP_GUIDE.md` §6:** pointer to the AWS runbook.
- **`deploy/.env`** (git-ignored) created from the template.
- **SSH key** `~/.ssh/quit-companion-aws` (ed25519) on the deploy PC. Only the public key went to AWS.

### Problems found and fixed during the run

1. **The first deploy died at the upload** (`scp: Connection closed`). The server's sshd log shows the connection stalled before authentication (`Connection closed … [preauth]`) for about 97 s on this PC's slow, high-latency link (≈100 KB/s up). A 6.5 MB test upload then succeeded in 63 s. Fixes:
   - uploads are retried;
   - SSH handshakes are retried (on exit 255 only);
   - the server-side release runs **detached** (`setsid nohup`), and `deploy.sh` re-polls its log (`releases/release-<stamp>.log`) until a `.exit` file appears.

   The follow loop was tested locally with half-written lines, dropped connections and a failing release.
2. **The second deploy went live, but reported exit 2 from the clean-up step.** Under `pipefail`, `ls release-*.exit` with no matching files returns 2. Fixed with `nullglob` and a `keep_newest` helper, which was tested with no, few and many files. That step runs after go-live; the services were unaffected.

## Verification (evidence)

**In the image, on the server:** backend suite **317 passed, 5 skipped, 0 failed**. The skips are training-only: no ML models or pandas in the image. On the PC the full suite is 322 passed.

**Preflight:** "ready". The WARNs are the expected empty `GEMINI_API_KEY`, empty `FCM_SCHEDULER_TOKEN`, gate without a record, and "git not available" (in the image).

**Containers:** `deploy-backend-1` healthy, `deploy-worker-1` healthy (heartbeat), `deploy-proxy-1` up.

**From the server and again from the deploy PC (outside AWS):**

| Check | Result |
| --- | --- |
| `GET /health` | 200 `{"status":"ok"}` |
| `GET /ready` | 503 `{"ready":false,"relapse_predictor":{"requested_mode":"rule_based","active":"rule_based"}}` |
| `http://…/health` | 308 → https |
| unauthenticated `POST /predict/relapse` | 401 |
| response headers | `Via: Caddy`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer` |
| server time | `X-Response-Time-Ms` 0.3 |

**Worker:** starts and polls Firestore (positional-filter `UserWarning`s from google-cloud-firestore only). The collection-group indexes it needs were already configured on the live project (`tools/ensure_indexes.py` dry run).

**APK:**
- `libapp.so` for arm64-v8a, armeabi-v7a and x86_64 contains `https://quitcompanion.duckdns.org`, and no `10.0.2.2:8000` or `127.0.0.1:8000`;
- signed with the Android **debug** certificate (no `key.properties`), SHA-1 `02:92:F9:5C:CA:35:57:A2:04:1B:46:DC:65:F9:3E:0B:09:4D:C3:0E`.

**Server resources after go-live:**

| Measure | Value |
| --- | --- |
| Memory | 693 MB used of 1905 MB |
| Containers | backend 58 MB, worker 81 MB, Caddy 12 MB (rule_based mode; `ml` would add the XGBoost model) |
| Disk | 8.3 GB of 19 GB (46%). The image is large because `xgboost` 2.1.4 pulls in `nvidia-nccl-cu12` on x86_64 Linux |

A `t3.micro` (1 GB) would fit this load. `t3.small` leaves headroom for `ml` mode and image builds.

**Confirmation redeploy** (`SKIP_TESTS=1`, same code):
- `DEPLOY OK`, exit 0. Containers were *not* recreated (image cached) and the certificate was kept.
- One upload failed on attempt 1 and succeeded on the automatic retry.
- The check from the PC returned `{"status":"ok"}`.

**Server logs after go-live:**
- worker: `Worker started (notifications=True, poll=30s)` and 0 error/denied/unauthenticated lines, so the Firestore queries run with the deployed key;
- backend: 0 errors;
- Caddy: `certificate obtained successfully`, background certificate maintenance (renewal) started.

**Credentials:**
- The deployment used the Admin key that `backend/.env` points to, stored outside the repo.
- An older Admin key file is still in `backend/` (git-ignored, not used).

## Not done / owner actions

1. **Firestore rules (Step 10) not deployed.** `firebase deploy --only firestore:rules --project quit-companion --dry-run` compiled successfully against the live project. The real deploy was blocked by the session's permission classifier (production change). The owner runs it.
2. **Phone checks** (owner, manual): install the release APK, then check sign-in, craving log → risk score, Health-Bot fallback, reminders/FCM, community post.
3. **Google Sign-In with this APK** needs the debug SHA-1 above registered in Firebase.
4. **Move to Mumbai** (recommended, see the region note).
5. Optional: `ml` predictor and/or Health-Bot gate off (+ Gemini key) — owner decisions.
6. **Live Gemini, FCM delivery and production latency from a phone** were not tested: no Gemini key is on the server, and no device was used.
7. **Old Admin key file in `backend/`.** If that key is retired, delete the file and confirm the key is deleted in Google Cloud Console → IAM → Service accounts → Keys. Credential changes are the owner's.

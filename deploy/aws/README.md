# Deploying the Quit Companion backend on AWS (free-plan credits)

*Written 2026-11-24. Commands for the project PC use Git Bash, run from the repository root.*

## What runs where

| Part | Where | Notes |
| --- | --- | --- |
| FastAPI backend, worker and Caddy (HTTPS) | **AWS EC2**, one Ubuntu 24.04/26.04 LTS server in `ap-south-1` (Mumbai) | `deploy/compose.yaml`, unchanged architecture from Step 12 |
| Auth, Firestore, FCM push | Firebase (Google), Firestore in `asia-south1` (Mumbai) | Not moved. Mumbai was chosen so the server sits next to the database |
| Android app | Users' phones | Release APK built with `OTP_BACKEND_BASE_URL=https://<your-hostname>` |
| HTTPS certificate | Let's Encrypt via Caddy | Free; renewed automatically |
| Hostname | Free DuckDNS subdomain (or your own domain) | Points at the server's Elastic IP |

## Cost on the AWS Free plan

New AWS accounts (created on or after 15 July 2025) get up to **US$200 in credits** ($100 at sign-up, plus up to $100 more for trying services such as launching EC2 and setting up a budget). The Free plan lasts **6 months or until the credits run out**, whichever comes first. A Free-plan account isn't charged: to keep the server running after that, you upgrade to a paid plan. `t3.small` is on the Free plan's eligible list. Sources: [AWS Free Tier](https://aws.amazon.com/free/), [EC2 Free Tier usage](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-free-tier-usage.html), [EC2 pricing](https://aws.amazon.com/ec2/pricing/on-demand/).

| Item (Mumbai, on-demand, approximate) | Per month |
| --- | --- |
| EC2 `t3.small` (2 vCPU, 2 GB RAM), about $0.0224/hour | ≈ $16.4 |
| Elastic IP (public IPv4), $0.005/hour | ≈ $3.7 |
| 20 GB gp3 disk | ≈ $2 |
| Data out (first 100 GB/month free) | $0 for this app |
| **Total, drawn from the credits** | **≈ $22** |

So **$100 covers about 4½ months, and $200 covers the full 6-month plan.** `INSTANCE_TYPE=t3.micro` (1 GB RAM) is about $14/month in total, but tight for two Python processes. The provisioning script sets "standard" CPU credits, so a busy CPU is slowed down rather than billed extra. It also creates a $30/month budget that e-mails you if spending runs higher than planned.

## One-time setup

### 1. AWS account (you)

Sign up at <https://aws.amazon.com/free/> and choose the **Free plan**. Turn on MFA for the root user (IAM → Security credentials). In the console, switch the region (top right) to **Asia Pacific (Mumbai) ap-south-1**.

### 2. Create the server (you, about 5 minutes)

Use either **2a (CloudShell script)** or **2b (console clicks)**. They create the same setup. Brand-new accounts often can't use CloudShell yet: the error says "Unable to create the environment. Your account verification is in progress…", which can take up to two days. In that case, use 2b.

#### 2a. AWS CloudShell script

1. Open **CloudShell** (the `>_` icon in the console's top bar).
2. **Actions → Upload file** → choose `deploy/aws/provision-cloudshell.sh` from this repository.
3. Run this, all on one line, with your values:
   ```bash
   SSH_CIDR="<this PC's public IP>/32" SSH_PUBKEY="<the line in ~/.ssh/quit-companion-aws.pub>" BUDGET_EMAIL="<your e-mail>" bash provision-cloudshell.sh
   ```
   - This PC's IP is shown at <https://checkip.amazonaws.com>.
   - The public key comes from `ssh-keygen -t ed25519 -f ~/.ssh/quit-companion-aws` (already created on the project PC). The **private** key never leaves the PC.
4. Write down the **Elastic IP** printed at the end.

The script is safe to re-run: it reuses existing resources rather than duplicating them. It creates:
- a key pair;
- a security group: SSH from your IP and from EC2 Instance Connect only, 80/443 public;
- the server: 20 GB encrypted disk, IMDSv2 only;
- the Elastic IP;
- the budget.

#### 2b. Console clicks (no CloudShell needed)

First check that the region selector (top right) shows **Asia Pacific (Mumbai) ap-south-1**. Resources created in another region won't be next to Firestore.

1. **EC2 → Key Pairs → Actions → Import key pair**:
   - Name: `quit-companion-deploy`.
   - Paste the single line from `~/.ssh/quit-companion-aws.pub`.
   - Click **Import key pair**.
2. **EC2 → Instances → Launch instances**:
   - **Name:** `quit-companion-api`.
   - **Application and OS image:** Quick Start → **Ubuntu** → **Ubuntu Server 24.04 LTS** or the console's default **26.04 LTS** (both work), architecture **64-bit (x86)**.
   - **Instance type:** **t3.small**.
   - **Key pair:** `quit-companion-deploy`.
   - **Network settings:**
     - tick **Allow SSH traffic from → My IP**;
     - tick **Allow HTTPS traffic from the internet**;
     - tick **Allow HTTP traffic from the internet**.
   - **Configure storage:** **20** GiB, **gp3**.
   - **Advanced details:**
     - **Credit specification → Standard**;
     - **Metadata version → V2 only (token required)**.
   - Click **Launch instance**.
3. **EC2 → Elastic IPs → Allocate Elastic IP address → Allocate**. Then select it → **Actions → Associate Elastic IP address** → Instance `quit-companion-api` → **Associate**. Note the address.
4. Optional: **Billing and Cost Management → Budgets → Create budget**, using the *Monthly cost budget* template ($30, your e-mail).

If **Launch instance** fails with a message about account verification or `PendingVerification`, the whole account is still being verified, not only CloudShell. In that case:
- check that sign-up was fully completed (phone verification and a **verified payment card**: AWS places a small temporary charge, so the card must allow international online payments);
- check your e-mail from AWS;
- after two days, open a free **Account and billing** case in the AWS Support Center.

### 3. Hostname (you, about 2 minutes)

1. Sign in at <https://www.duckdns.org>.
2. Add a subdomain, for example `quitcompanion-api` → `quitcompanion-api.duckdns.org`.
3. Set **current ip** to the Elastic IP and click **update ip**.

(Using your own domain instead: add an `A` record for, say, `api.example.com` pointing at the Elastic IP.)

### 4. Deploy (project PC)

1. Set `SITE_DOMAIN` in `deploy/.env` (git-ignored; created from `deploy/.env.example`). Leave `FIREBASE_CREDENTIAL_FILE=/home/ubuntu/quit-companion/secrets/firebase-admin.json` as it is.
2. Review the two owner settings:

   | Setting | Template value | Alternative |
   | --- | --- | --- |
   | `RELAPSE_PREDICTOR_MODE` | `rule_based` (SRDS rule table; matches Table 4.3) | `ml` (experimental XGBoost; app shows "Scored by: ML (Experimental)") |
   | `REQUIRE_CLINICAL_REVIEW` | `true`: no advisor record exists, so Health-Bot and AI plans return 503 and the app shows its curated fallback. No Gemini key is needed on the server | `false` + `GEMINI_API_KEY=...`: live Gemini answers that no advisor has reviewed |

3. Run:
   ```bash
   bash deploy/aws/deploy.sh <ELASTIC_IP>
   ```

`deploy.sh` uploads the **current working tree** (no git push needed) together with `deploy/.env` and the Firebase Admin key (found through `backend/.env`). On a fresh server it installs Docker first (`bootstrap-server.sh`). The server (`remote-release.sh`) then:
1. builds the image;
2. runs the **backend test suite inside the image with networking disabled**;
3. runs the preflight (`backend/tools/check_deploy_config.py`);
4. checks that the hostname resolves to the server;
5. only then starts backend + worker + Caddy and waits for health checks;
6. checks `/health`, `/ready`, the HTTP→HTTPS redirect, the auth guard and the certificate.

It ends with `DEPLOY OK - https://<hostname>`. Steps 1–4 run before anything live changes.

Built for slow or high-latency links:
- uploads and SSH handshakes are retried automatically;
- the server-side release runs **detached**, so a dropped connection can't stop it halfway. `deploy.sh` keeps reconnecting to follow its log, which stays on the server at `~/quit-companion/releases/release-<stamp>.log`.

### 5. Release APK (project PC)

```bash
cd mobile
flutter build apk --release --dart-define=OTP_BACKEND_BASE_URL=https://<SITE_DOMAIN>
```

Without `mobile/android/key.properties` the APK is signed with the debug key: fine for sideloading, not for Play (see `docs/SETUP_GUIDE.md` §5). Google Sign-In only works once the signing key's SHA-1 is registered in Firebase.

## Day-to-day operations

```bash
KEY=~/.ssh/quit-companion-aws; IP=<ELASTIC_IP>
DC='cd ~/quit-companion/app && docker compose --env-file deploy/.env -f deploy/compose.yaml'
ssh -i $KEY ubuntu@$IP "$DC ps"                         # status: backend/worker healthy, proxy up
ssh -i $KEY ubuntu@$IP "$DC logs --tail 100 backend"    # or worker / proxy
ssh -i $KEY ubuntu@$IP "$DC restart"
bash deploy/aws/deploy.sh $IP                           # redeploy after code or deploy/.env changes
SKIP_TESTS=1 bash deploy/aws/deploy.sh $IP              # quick redeploy (settings only)
```

- **Rollback:** the last 3 bundles stay in `~/quit-companion/releases/`. Run `ssh -i $KEY ubuntu@$IP 'SKIP_TESTS=1 bash ~/quit-companion/remote-release.sh <stamp>'`, where `<stamp>` is the part of the bundle name after `quit-companion-`.
- **SSH stops working** (your home IP changed): re-run the provisioning script with the new `SSH_CIDR` (it adds the rule), or use **EC2 → Connect → EC2 Instance Connect** in the browser.
- **Pause to save credits:** stop the instance in the EC2 console. The disk and Elastic IP still cost about $5.7/month. Starting it again keeps the same IP, and the containers start automatically.
- **Finished with AWS:** upload and run `deploy/aws/teardown-cloudshell.sh` in CloudShell. It deletes the server, Elastic IP, firewall, key pair and budget after you type `DELETE`. Firebase data isn't affected.

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| `STOPPED before go-live: ... resolves to ...` | The DuckDNS IP isn't the Elastic IP yet. Fix it, wait a minute, re-run |
| `HTTPS NOT ANSWERING` | The Caddy log is printed. Check that 80/443 are open and DNS is right. Let's Encrypt allows 5 failed validations per hostname per hour, so wait if you hit that |
| `/ready` returns 503 | Expected while `REQUIRE_CLINICAL_REVIEW=true` and no approved record is in `deploy/reviews/`. Container health uses `/health`, and the app never calls `/ready` |
| Health-Bot shows the curated fallback | Same gate, by design |
| Worker unhealthy | `"$DC logs --tail 100 worker"`. Its heartbeat is older than 3 minutes |

## Security notes

- **Firebase Admin key:**
  - lives only at `~/quit-companion/secrets/firebase-admin.json`;
  - mode 400, owned by the container user, mounted read-only;
  - never in the image, the upload bundle (checked) or git.
- **Network:**
  - only ports 80/443 are public;
  - the API listens on `127.0.0.1:8000` behind Caddy;
  - SSH is key-only, from one IP plus EC2 Instance Connect.
- **Server:** the disk is encrypted, and instance metadata is IMDSv2-only.
- **Logs:** they rotate (10 MB × 5 per container) so they can't fill the disk.
- **Gemini key:** only on the server when `REQUIRE_CLINICAL_REVIEW=false`.

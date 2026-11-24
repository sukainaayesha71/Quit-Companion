#!/usr/bin/env bash
# Quit Companion - one-time AWS setup for the backend server.
#
# Run it in AWS CloudShell (the >_ icon in the AWS console). It uses your
# console sign-in, so no AWS access keys are created or stored anywhere.
#
# Creates in ap-south-1 (Mumbai - next to the Firestore database, which is in
# asia-south1 Mumbai), or reuses what already exists on a re-run:
#   * key pair "quit-companion-deploy" from the PUBLIC SSH key you pass in
#   * security group "quit-companion-api": SSH only from your PC's IP (plus
#     EC2 Instance Connect for browser SSH); HTTP and HTTPS open for Caddy
#   * one Ubuntu 24.04 LTS server (default t3.small, free-plan eligible):
#     20 GB encrypted gp3 disk, IMDSv2 only, "standard" CPU credits so a busy
#     CPU is throttled instead of billed extra
#   * an Elastic IP, so the server keeps one address for its DNS name
#   * optional: a monthly cost budget that e-mails you (BUDGET_EMAIL)
#
# Usage (one line in CloudShell, after uploading this file):
#   SSH_CIDR="<your-pc-ip>/32" SSH_PUBKEY="ssh-ed25519 AAAA... quit-companion-deploy" \
#     BUDGET_EMAIL="<you@example.com>" bash provision-cloudshell.sh
#
# Optional overrides: INSTANCE_TYPE (t3.micro = cheaper, 1 GB RAM, tight),
# VOLUME_GB, BUDGET_USD, REGION.
set -euo pipefail
export AWS_PAGER=""   # AWS CLI v2 would otherwise open "less" and wait for a keypress

REGION="${REGION:-ap-south-1}"
NAME="quit-companion-api"
KEY_NAME="quit-companion-deploy"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.small}"
VOLUME_GB="${VOLUME_GB:-20}"
BUDGET_USD="${BUDGET_USD:-30}"
BUDGET_NAME="quit-companion-monthly"
AMI_PARAM="/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
PROJECT_TAG="{Key=Project,Value=quit-companion}"

: "${SSH_CIDR:?set SSH_CIDR to your PC public IP followed by /32}"
: "${SSH_PUBKEY:?set SSH_PUBKEY to the one-line SSH public key}"
[[ "$SSH_CIDR" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/32$ ]] \
  || { echo "SSH_CIDR must look like 203.0.113.7/32 (one address, not 0.0.0.0/0)" >&2; exit 1; }
[[ "$SSH_PUBKEY" =~ ^ssh-(ed25519|rsa)\ [A-Za-z0-9+/=]+ ]] \
  || { echo "SSH_PUBKEY must be an OpenSSH public key line (ssh-ed25519 ...)" >&2; exit 1; }

ec2() { aws ec2 --region "$REGION" "$@"; }
say() { printf '\n== %s\n' "$*"; }
none() { [ -z "$1" ] || [ "$1" = "None" ]; }

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) \
  || { echo "The AWS CLI isn't signed in - run this inside AWS CloudShell." >&2; exit 1; }
say "Account $ACCOUNT_ID, region $REGION"

say "Key pair"
if ec2 describe-key-pairs --key-names "$KEY_NAME" >/dev/null 2>&1; then
  echo "exists: $KEY_NAME (reused; delete it first if you generated a new SSH key)"
else
  printf '%s\n' "$SSH_PUBKEY" > /tmp/quit-companion-deploy.pub
  ec2 import-key-pair --key-name "$KEY_NAME" \
    --public-key-material fileb:///tmp/quit-companion-deploy.pub \
    --tag-specifications "ResourceType=key-pair,Tags=[$PROJECT_TAG]" >/dev/null
  rm -f /tmp/quit-companion-deploy.pub
  echo "imported: $KEY_NAME"
fi

say "Network"
VPC_ID=$(ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
if none "$VPC_ID"; then
  echo "no default VPC in $REGION - creating one"
  VPC_ID=$(ec2 create-default-vpc --query 'Vpc.VpcId' --output text)
fi
echo "VPC: $VPC_ID"

SG_ID=$(ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=$NAME" \
  --query 'SecurityGroups[0].GroupId' --output text)
if none "$SG_ID"; then
  SG_ID=$(ec2 create-security-group --vpc-id "$VPC_ID" --group-name "$NAME" \
    --description "Quit Companion API - SSH from the deploy PC, HTTP and HTTPS public" \
    --tag-specifications "ResourceType=security-group,Tags=[$PROJECT_TAG]" \
    --query GroupId --output text)
  ec2 authorize-security-group-ingress --group-id "$SG_ID" --ip-permissions '[
    {"IpProtocol":"tcp","FromPort":80,"ToPort":80,
     "IpRanges":[{"CidrIp":"0.0.0.0/0","Description":"HTTP - certificate checks and redirect to HTTPS"}]},
    {"IpProtocol":"tcp","FromPort":443,"ToPort":443,
     "IpRanges":[{"CidrIp":"0.0.0.0/0","Description":"HTTPS API"}]}]' >/dev/null
  echo "created security group: $SG_ID (80, 443 open)"
else
  echo "exists: security group $SG_ID (reused)"
fi

allow_ssh() {  # $1 = ip-permissions JSON, $2 = label. A duplicate rule is not an error.
  if ec2 authorize-security-group-ingress --group-id "$SG_ID" --ip-permissions "$1" >/dev/null 2>&1; then
    echo "SSH allowed: $2"
  else
    echo "SSH already allowed (or unavailable): $2"
  fi
}
allow_ssh "[{\"IpProtocol\":\"tcp\",\"FromPort\":22,\"ToPort\":22,\"IpRanges\":[{\"CidrIp\":\"$SSH_CIDR\",\"Description\":\"SSH from the deploy PC\"}]}]" \
  "from $SSH_CIDR"
EIC_LIST=$(ec2 describe-managed-prefix-lists \
  --filters "Name=prefix-list-name,Values=com.amazonaws.$REGION.ec2-instance-connect" \
  --query 'PrefixLists[0].PrefixListId' --output text 2>/dev/null || echo None)
if ! none "$EIC_LIST"; then
  allow_ssh "[{\"IpProtocol\":\"tcp\",\"FromPort\":22,\"ToPort\":22,\"PrefixListIds\":[{\"PrefixListId\":\"$EIC_LIST\",\"Description\":\"EC2 Instance Connect - browser SSH\"}]}]" \
    "from EC2 Instance Connect (console browser SSH)"
fi

say "Server"
INSTANCE_ID=$(ec2 describe-instances \
  --filters "Name=tag:Name,Values=$NAME" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].InstanceId | [0]' --output text)
if none "$INSTANCE_ID"; then
  # Canonical's published "latest Ubuntu 24.04" image id (gp2 path as a fallback).
  AMI_ID=$(aws ssm get-parameter --region "$REGION" --name "$AMI_PARAM" --query Parameter.Value --output text 2>/dev/null \
    || aws ssm get-parameter --region "$REGION" --name "${AMI_PARAM/ebs-gp3/ebs-gp2}" --query Parameter.Value --output text)
  ROOT_DEVICE=$(ec2 describe-images --image-ids "$AMI_ID" --query 'Images[0].RootDeviceName' --output text)
  INSTANCE_ID=$(ec2 run-instances --image-id "$AMI_ID" --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" --security-group-ids "$SG_ID" \
    --block-device-mappings "[{\"DeviceName\":\"$ROOT_DEVICE\",\"Ebs\":{\"VolumeSize\":$VOLUME_GB,\"VolumeType\":\"gp3\",\"Encrypted\":true,\"DeleteOnTermination\":true}}]" \
    --metadata-options "HttpTokens=required,HttpEndpoint=enabled" \
    --credit-specification "CpuCredits=standard" \
    --tag-specifications \
      "ResourceType=instance,Tags=[{Key=Name,Value=$NAME},$PROJECT_TAG]" \
      "ResourceType=volume,Tags=[{Key=Name,Value=$NAME},$PROJECT_TAG]" \
    --query 'Instances[0].InstanceId' --output text)
  echo "launched: $INSTANCE_ID ($INSTANCE_TYPE, Ubuntu 24.04 LTS $AMI_ID, ${VOLUME_GB} GB)"
else
  echo "exists: $INSTANCE_ID (reused)"
  STATE=$(ec2 describe-instances --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].State.Name' --output text)
  case "$STATE" in
    stopping) ec2 wait instance-stopped --instance-ids "$INSTANCE_ID"
              ec2 start-instances --instance-ids "$INSTANCE_ID" >/dev/null; echo "started (was stopping)" ;;
    stopped)  ec2 start-instances --instance-ids "$INSTANCE_ID" >/dev/null; echo "started (was stopped)" ;;
  esac
fi
echo "waiting for the server to be running..."
ec2 wait instance-running --instance-ids "$INSTANCE_ID"

say "Elastic IP"
ALLOC_ID=$(ec2 describe-addresses --filters "Name=tag:Name,Values=$NAME" \
  --query 'Addresses[0].AllocationId' --output text)
if none "$ALLOC_ID"; then
  ALLOC_ID=$(ec2 allocate-address --domain vpc \
    --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=$NAME},$PROJECT_TAG]" \
    --query AllocationId --output text)
  echo "allocated: $ALLOC_ID"
fi
ec2 associate-address --instance-id "$INSTANCE_ID" --allocation-id "$ALLOC_ID" --allow-reassociation >/dev/null
EIP=$(ec2 describe-addresses --allocation-ids "$ALLOC_ID" --query 'Addresses[0].PublicIp' --output text)
echo "attached: $EIP"

if [ -n "${BUDGET_EMAIL:-}" ]; then
  say "Cost budget"
  if [[ ! "$BUDGET_EMAIL" =~ ^[^@\ \"]+@[^@\ \"]+\.[^@\ \"]+$ ]]; then
    echo "BUDGET_EMAIL doesn't look like an e-mail address - skipped (not required)"
  else
    if aws budgets describe-budget --region us-east-1 --account-id "$ACCOUNT_ID" \
         --budget-name "$BUDGET_NAME" >/dev/null 2>&1; then
      echo "exists: $BUDGET_NAME (reused)"
    else
      SUBSCRIBERS="[{\"SubscriptionType\":\"EMAIL\",\"Address\":\"$BUDGET_EMAIL\"}]"
      # IncludeCredit=false: track real usage *before* credits, so the alert
      # fires if credits are being spent faster than planned.
      if aws budgets create-budget --region us-east-1 --account-id "$ACCOUNT_ID" \
           --budget "{\"BudgetName\":\"$BUDGET_NAME\",\"BudgetLimit\":{\"Amount\":\"$BUDGET_USD\",\"Unit\":\"USD\"},\"TimeUnit\":\"MONTHLY\",\"BudgetType\":\"COST\",\"CostTypes\":{\"IncludeCredit\":false}}" \
           --notifications-with-subscribers "[{\"Notification\":{\"NotificationType\":\"ACTUAL\",\"ComparisonOperator\":\"GREATER_THAN\",\"Threshold\":80,\"ThresholdType\":\"PERCENTAGE\"},\"Subscribers\":$SUBSCRIBERS},{\"Notification\":{\"NotificationType\":\"FORECASTED\",\"ComparisonOperator\":\"GREATER_THAN\",\"Threshold\":100,\"ThresholdType\":\"PERCENTAGE\"},\"Subscribers\":$SUBSCRIBERS}]"; then
        echo "created: $BUDGET_NAME - \$$BUDGET_USD/month before credits; e-mails at 80% actual and 100% forecast"
      else
        echo "could not create the budget - add one in Billing and Cost Management > Budgets (optional)"
      fi
    fi
  fi
fi

say "Done"
cat <<EOF
Instance    $INSTANCE_ID ($INSTANCE_TYPE) in $REGION
Elastic IP  $EIP
SSH         ssh -i ~/.ssh/quit-companion-aws ubuntu@$EIP

Next: point your DNS name (for example a free DuckDNS subdomain) at $EIP,
then run deploy/aws/deploy.sh from the project PC (see deploy/aws/README.md).
EOF

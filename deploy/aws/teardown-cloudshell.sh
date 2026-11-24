#!/usr/bin/env bash
# Quit Companion - delete everything provision-cloudshell.sh created, so it
# stops using AWS credits. Run in AWS CloudShell. Asks you to type DELETE.
#
# PERMANENT: the server and its disk are destroyed. The app's user data is in
# Firebase (Google), not on this server, so it is NOT affected. The backend can
# be recreated later with provision-cloudshell.sh + deploy.sh.
#
# To pause instead (cheaper, reversible): stop the instance in the EC2 console.
# A stopped server still bills its disk and Elastic IP (about $5/month).
set -euo pipefail
export AWS_PAGER=""   # AWS CLI v2 would otherwise open "less" and wait for a keypress

REGION="${REGION:-ap-south-1}"
NAME="quit-companion-api"
KEY_NAME="quit-companion-deploy"
BUDGET_NAME="quit-companion-monthly"
ec2() { aws ec2 --region "$REGION" "$@"; }
none() { [ -z "$1" ] || [ "$1" = "None" ]; }

INSTANCE_ID=$(ec2 describe-instances \
  --filters "Name=tag:Name,Values=$NAME" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].InstanceId | [0]' --output text)
ALLOC_ID=$(ec2 describe-addresses --filters "Name=tag:Name,Values=$NAME" \
  --query 'Addresses[0].AllocationId' --output text)
SG_ID=$(ec2 describe-security-groups --filters "Name=group-name,Values=$NAME" \
  --query 'SecurityGroups[0].GroupId' --output text)

echo "In $REGION this deletes:"
echo "  server        ${INSTANCE_ID} (and its disk)"
echo "  Elastic IP    ${ALLOC_ID}"
echo "  firewall      ${SG_ID} ($NAME)"
echo "  key pair      $KEY_NAME"
echo "  budget        $BUDGET_NAME (if present)"
read -rp "Type DELETE to continue: " answer
[ "$answer" = "DELETE" ] || { echo "Cancelled - nothing changed."; exit 1; }

if ! none "$INSTANCE_ID"; then
  ec2 terminate-instances --instance-ids "$INSTANCE_ID" >/dev/null
  echo "terminating $INSTANCE_ID ..."
  ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"
  echo "server deleted"
fi
if ! none "$ALLOC_ID"; then
  ec2 release-address --allocation-id "$ALLOC_ID"
  echo "Elastic IP released"
fi
if ! none "$SG_ID"; then
  # The terminated server's network interface can take a few seconds to detach.
  for attempt in 1 2 3 4 5 6 7 8 9; do
    if ec2 delete-security-group --group-id "$SG_ID" >/dev/null 2>&1; then
      echo "security group deleted"; break
    fi
    if [ "$attempt" = 9 ]; then
      echo "security group $SG_ID still in use - delete it later in EC2 > Security Groups"
    else
      sleep 10
    fi
  done
fi
if ec2 describe-key-pairs --key-names "$KEY_NAME" >/dev/null 2>&1; then
  ec2 delete-key-pair --key-name "$KEY_NAME"
  echo "key pair deleted"
fi
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if aws budgets delete-budget --region us-east-1 --account-id "$ACCOUNT_ID" \
     --budget-name "$BUDGET_NAME" >/dev/null 2>&1; then
  echo "budget deleted"
fi
echo "Done. Also delete the DuckDNS name if you no longer need it."

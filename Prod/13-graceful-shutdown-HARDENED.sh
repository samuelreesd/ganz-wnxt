#!/bin/bash
# Graceful shutdown script for WNXT Prod User Server
# Triggered by ASG Lifecycle Hook on scale-in
# Place at: /usr/local/bin/graceful-shutdown.sh
# chmod +x /usr/local/bin/graceful-shutdown.sh

set -u
set -o pipefail

LOGFILE="/var/log/graceful-shutdown.log"

REGION="us-east-1"
READINESS_TG="REPLACE_WITH_PROD_READINESS_TG_ARN"
LIFECYCLE_HOOK="WNXT-PROD-USER-TerminateHook"

SERVICE_NAME="wnxt-user.service"

HUB_HOST="10.2.150.101"
HUB_USER="root"
HUB_HOSTSLIST="/srv/wnxt-on-aws/hub/hostslist"
HUB_RECONCILE_FLAG="/tmp/multicast-reconcile-needed"

DRAIN_TIMEOUT_SECONDS=180
DRAIN_CHECK_INTERVAL=10

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOGFILE"
}

fail_and_continue() {
  log "ERROR: $*"
  log "Signalling ASG ABANDON because graceful shutdown failed"

  aws autoscaling complete-lifecycle-action \
    --lifecycle-hook-name "$LIFECYCLE_HOOK" \
    --auto-scaling-group-name "$ASG_NAME" \
    --lifecycle-action-result ABANDON \
    --instance-id "$INSTANCE_ID" \
    --region "$REGION" >> "$LOGFILE" 2>&1 || true

  exit 1
}

log "============================================"
log "Graceful shutdown started"

# Validate required config
if [[ "$READINESS_TG" == "REPLACE_WITH_PROD_READINESS_TG_ARN" ]]; then
  log "ERROR: READINESS_TG is still a placeholder"
  exit 1
fi

# Get EC2 instance metadata using IMDSv2
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

if [[ -z "$TOKEN" ]]; then
  log "ERROR: Unable to get IMDSv2 token"
  exit 1
fi

INSTANCE_ID=$(curl -s \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

if [[ -z "$INSTANCE_ID" ]]; then
  log "ERROR: Unable to get instance ID"
  exit 1
fi

log "Instance ID: $INSTANCE_ID"

ASG_NAME=$(aws autoscaling describe-auto-scaling-instances \
  --instance-ids "$INSTANCE_ID" \
  --query "AutoScalingInstances[0].AutoScalingGroupName" \
  --output text \
  --region "$REGION" 2>> "$LOGFILE")

if [[ -z "$ASG_NAME" || "$ASG_NAME" == "None" ]]; then
  log "ERROR: Unable to determine Auto Scaling Group name"
  exit 1
fi

log "ASG Name: $ASG_NAME"

# Step 1 - Deregister from ALB
log "Step 1: Deregistering instance from ALB target group"

aws elbv2 deregister-targets \
  --target-group-arn "$READINESS_TG" \
  --targets "Id=$INSTANCE_ID,Port=80" \
  --region "$REGION" >> "$LOGFILE" 2>&1 \
  || fail_and_continue "Failed to deregister instance from target group"

log "Step 1: Deregistration requested"

# Step 2 - Wait for ALB draining
log "Step 2: Waiting for ALB target to finish draining"

SECONDS_WAITED=0

while [[ $SECONDS_WAITED -lt $DRAIN_TIMEOUT_SECONDS ]]; do
  TARGET_STATE=$(aws elbv2 describe-target-health \
    --target-group-arn "$READINESS_TG" \
    --targets "Id=$INSTANCE_ID,Port=80" \
    --query "TargetHealthDescriptions[0].TargetHealth.State" \
    --output text \
    --region "$REGION" 2>> "$LOGFILE")

  log "Current target state: $TARGET_STATE"

  if [[ "$TARGET_STATE" == "unused" || "$TARGET_STATE" == "draining" || "$TARGET_STATE" == "None" ]]; then
    log "ALB target is no longer receiving normal traffic"
    break
  fi

  sleep "$DRAIN_CHECK_INTERVAL"
  SECONDS_WAITED=$((SECONDS_WAITED + DRAIN_CHECK_INTERVAL))
done

if [[ $SECONDS_WAITED -ge $DRAIN_TIMEOUT_SECONDS ]]; then
  log "WARNING: ALB drain wait timed out after ${DRAIN_TIMEOUT_SECONDS}s"
fi

# Step 3 - Stop WNXT service
log "Step 3: Stopping $SERVICE_NAME"

systemctl stop "$SERVICE_NAME" >> "$LOGFILE" 2>&1 \
  || fail_and_continue "Failed to stop $SERVICE_NAME"

log "Step 3: $SERVICE_NAME stopped"

# Step 4 - Remove from hub hostslist
INSTANCE_IP=$(hostname -i | awk '{print $1}')

if [[ -z "$INSTANCE_IP" ]]; then
  fail_and_continue "Unable to determine instance private IP"
fi

log "Step 4: Removing $INSTANCE_IP from hub hostslist on $HUB_HOST"

ssh -o StrictHostKeyChecking=no \
    -o ConnectTimeout=10 \
    "${HUB_USER}@${HUB_HOST}" \
    "sed -i.bak '/${INSTANCE_IP}/d' '$HUB_HOSTSLIST' && touch '$HUB_RECONCILE_FLAG'" \
    >> "$LOGFILE" 2>&1 \
    || fail_and_continue "Failed to update hub hostslist"

log "Step 4: Removed $INSTANCE_IP from hub hostslist"

# Step 5 - Signal ASG
log "Step 5: Signalling ASG CONTINUE"

aws autoscaling complete-lifecycle-action \
  --lifecycle-hook-name "$LIFECYCLE_HOOK" \
  --auto-scaling-group-name "$ASG_NAME" \
  --lifecycle-action-result CONTINUE \
  --instance-id "$INSTANCE_ID" \
  --region "$REGION" >> "$LOGFILE" 2>&1 \
  || exit 1

log "Step 5: ASG signalled CONTINUE"
log "Graceful shutdown completed successfully"
log "============================================"

exit 0

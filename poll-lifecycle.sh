#!/bin/bash
# Poll for ASG lifecycle termination hook
# Runs every minute via cron
# Place at: /usr/local/bin/poll-lifecycle.sh
# chmod +x /usr/local/bin/poll-lifecycle.sh

LOGFILE=/var/log/graceful-shutdown.log
REGION=us-east-1
LOCKFILE=/tmp/graceful-shutdown.lock

# Acquire lock - prevent multiple simultaneous runs
exec 9>$LOCKFILE
if ! flock -n 9; then
    exit 0
fi

# Get instance ID
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

# Check current lifecycle state
STATE=$(aws autoscaling describe-auto-scaling-instances \
  --instance-ids ${INSTANCE_ID} \
  --query "AutoScalingInstances[0].LifecycleState" \
  --output text \
  --region ${REGION} 2>/dev/null)

# If in Terminating:Wait state - run graceful shutdown
if [ "$STATE" = "Terminating:Wait" ] || [ "$STATE" = "Terminating" ]; then
    echo "$(date) - Lifecycle state is ${STATE} - running graceful shutdown" >> $LOGFILE
    /usr/local/bin/graceful-shutdown.sh
fi

flock -u 9
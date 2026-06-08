#!/bin/bash
# Graceful shutdown script for WNXT Prod User Server
# Triggered by ASG Lifecycle Hook on scale-in
# Place at: /usr/local/bin/graceful-shutdown.sh on PROD image builder
# chmod +x /usr/local/bin/graceful-shutdown.sh

LOGFILE=/var/log/graceful-shutdown.log
REGION=us-east-1
READINESS_TG=REPLACE_WITH_PROD_READINESS_TG_ARN
LIFECYCLE_HOOK=WNXT-PROD-USER-TerminateHook

echo "$(date) - ============================================" >> $LOGFILE
echo "$(date) - Graceful shutdown started" >> $LOGFILE

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
echo "$(date) - Instance ID: ${INSTANCE_ID}" >> $LOGFILE

ASG_NAME=$(aws autoscaling describe-auto-scaling-instances \
  --instance-ids ${INSTANCE_ID} \
  --query "AutoScalingInstances[0].AutoScalingGroupName" \
  --output text \
  --region ${REGION})
echo "$(date) - ASG Name: ${ASG_NAME}" >> $LOGFILE

# Step 1 - Deregister from ALB
echo "$(date) - Step 1: Deregistering from ALB readiness target group..." >> $LOGFILE
aws elbv2 deregister-targets \
  --target-group-arn ${READINESS_TG} \
  --targets Id=${INSTANCE_ID},Port=80 \
  --region ${REGION}
echo "$(date) - Step 1: Deregistered - no new traffic will arrive" >> $LOGFILE

# Step 2 - Wait for connections to drain
echo "$(date) - Step 2: Waiting 30 seconds for connections to drain..." >> $LOGFILE
sleep 30

# Step 3 - Stop WNXT user service
echo "$(date) - Step 3: Stopping wnxt-user.service..." >> $LOGFILE
systemctl stop wnxt-user.service
echo "$(date) - Step 3: wnxt-user.service stopped" >> $LOGFILE

# Step 4 - Remove from hub hostslist
INSTANCE_IP=$(hostname -i | awk '{print $1}')
echo "$(date) - Step 4: Removing ${INSTANCE_IP} from hub hostslist..." >> $LOGFILE
ssh -o StrictHostKeyChecking=no root@10.2.150.101 \
  "sed -i '/${INSTANCE_IP}/d' /srv/wnxt-on-aws/hub/hostslist"
ssh -o StrictHostKeyChecking=no root@10.2.150.101 \
  "touch /tmp/multicast-reconcile-needed"
echo "$(date) - Step 4: Removed from hub" >> $LOGFILE

# Step 5 - Signal ASG
echo "$(date) - Step 5: Signalling ASG CONTINUE..." >> $LOGFILE
aws autoscaling complete-lifecycle-action \
  --lifecycle-hook-name ${LIFECYCLE_HOOK} \
  --auto-scaling-group-name ${ASG_NAME} \
  --lifecycle-action-result CONTINUE \
  --instance-id ${INSTANCE_ID} \
  --region ${REGION}
echo "$(date) - Step 5: ASG signalled" >> $LOGFILE
echo "$(date) - ============================================" >> $LOGFILE

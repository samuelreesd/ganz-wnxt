#!/bin/bash
# ============================================================
# WNXT Prod - Step 07 - Create ASG
# Update LAUNCH_TEMPLATE_ID after building prod AMI
# ============================================================

REGION=us-east-1
ASG_NAME=WNXT-PROD-USER-ASG
LAUNCH_TEMPLATE_ID=REPLACE_WITH_PROD_LT_ID
HEALTH_TG_ARN=REPLACE_WITH_HEALTH_TG_ARN_FROM_STEP_03
EC2_SG=REPLACE_WITH_SG_FROM_STEP_02

aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name ${ASG_NAME} \
  --launch-template LaunchTemplateId=${LAUNCH_TEMPLATE_ID},Version='$Latest' \
  --min-size 2 \
  --max-size 10 \
  --desired-capacity 2 \
  --target-group-arns ${HEALTH_TG_ARN} \
  --health-check-type ELB \
  --health-check-grace-period 300 \
  --termination-policies OldestInstance \
  --vpc-zone-identifier "subnet-62002407,subnet-c1cb3ded" \
  --region ${REGION}

echo "ASG ${ASG_NAME} created"

echo "Creating lifecycle hook..."
aws autoscaling put-lifecycle-hook \
  --lifecycle-hook-name WNXT-PROD-USER-TerminateHook \
  --auto-scaling-group-name ${ASG_NAME} \
  --lifecycle-transition autoscaling:EC2_INSTANCE_TERMINATING \
  --heartbeat-timeout 300 \
  --default-result CONTINUE \
  --region ${REGION}

echo "Lifecycle hook created"

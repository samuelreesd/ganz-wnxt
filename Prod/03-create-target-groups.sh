#!/bin/bash
# ============================================================
# WNXT Prod - Step 03 - Create Target Groups
# ============================================================

REGION=us-east-1
VPC_ID=vpc-4c677e2a
ALB_ARN=arn:aws:elasticloadbalancing:us-east-1:604009108246:loadbalancer/app/alb-wnxt/a4a019fc8ef45e8f

echo "Creating health target group..."
HEALTH_TG_ARN=$(aws elbv2 create-target-group \
  --name "tgrp-wnxt-prod-user" \
  --protocol HTTP \
  --port 80 \
  --vpc-id ${VPC_ID} \
  --health-check-protocol HTTP \
  --health-check-port 8080 \
  --health-check-path /health \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3 \
  --target-type instance \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text \
  --region ${REGION})
echo "Health TG created: ${HEALTH_TG_ARN}"

echo "Creating readiness target group..."
READINESS_TG_ARN=$(aws elbv2 create-target-group \
  --name "tgrp-wnxt-prod-user-readiness" \
  --protocol HTTP \
  --port 80 \
  --vpc-id ${VPC_ID} \
  --health-check-protocol HTTP \
  --health-check-port 8080 \
  --health-check-path /readiness \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3 \
  --target-type instance \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text \
  --region ${REGION})
echo "Readiness TG created: ${READINESS_TG_ARN}"

echo ""
echo "============================================"
echo "IMPORTANT - Save these ARNs:"
echo "Health TG ARN:    ${HEALTH_TG_ARN}"
echo "Readiness TG ARN: ${READINESS_TG_ARN}"
echo "============================================"
echo ""
echo "Next: Run 04-update-alb-rule.sh with these ARNs"
echo "Next: Update IAM ELB policy with readiness TG ARN:"
echo "aws iam put-role-policy --role-name ganz-cloudwatch-addnl-metrics-prod --policy-name WNXT-Prod-ELB-Register --policy-document '{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"elasticloadbalancing:RegisterTargets\",\"elasticloadbalancing:DeregisterTargets\"],\"Resource\":\"'${READINESS_TG_ARN}'\"}]}' --region ${REGION}"

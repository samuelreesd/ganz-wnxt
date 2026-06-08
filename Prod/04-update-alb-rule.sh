#!/bin/bash
# ============================================================
# WNXT Prod - Step 04 - Update ALB Rule
# Update TG ARNs from step 03 output before running
# ============================================================

REGION=us-east-1
LISTENER_80=arn:aws:elasticloadbalancing:us-east-1:604009108246:listener/app/alb-wnxt/a4a019fc8ef45e8f/7c882c43bae9c39b
LISTENER_443=arn:aws:elasticloadbalancing:us-east-1:604009108246:listener/app/alb-wnxt/a4a019fc8ef45e8f/4e489d4e53b8c641

# Update these after step 03
HEALTH_TG_ARN=REPLACE_WITH_HEALTH_TG_ARN_FROM_STEP_03
READINESS_TG_ARN=REPLACE_WITH_READINESS_TG_ARN_FROM_STEP_03

echo "Creating ALB rule for prod-user.webkinz.com on port 80..."
aws elbv2 create-rule \
  --listener-arn ${LISTENER_80} \
  --priority 20 \
  --conditions '[{"Field":"host-header","Values":["prod-user.webkinz.com"]}]' \
  --actions "[{\"Type\":\"forward\",\"ForwardConfig\":{\"TargetGroups\":[{\"TargetGroupArn\":\"${READINESS_TG_ARN}\",\"Weight\":100},{\"TargetGroupArn\":\"${HEALTH_TG_ARN}\",\"Weight\":0}]}}]" \
  --region ${REGION}
echo "ALB rule created on port 80"

echo "Creating ALB rule for prod-user.webkinz.com on port 443..."
aws elbv2 create-rule \
  --listener-arn ${LISTENER_443} \
  --priority 20 \
  --conditions '[{"Field":"host-header","Values":["prod-user.webkinz.com"]}]' \
  --actions "[{\"Type\":\"forward\",\"ForwardConfig\":{\"TargetGroups\":[{\"TargetGroupArn\":\"${READINESS_TG_ARN}\",\"Weight\":100},{\"TargetGroupArn\":\"${HEALTH_TG_ARN}\",\"Weight\":0}]}}]" \
  --region ${REGION}
echo "ALB rule created on port 443"

echo ""
echo "Next: Create DNS record prod-user.webkinz.com -> alb-wnxt-440462891.us-east-1.elb.amazonaws.com"

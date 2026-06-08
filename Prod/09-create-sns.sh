#!/bin/bash
# ============================================================
# WNXT Prod - Step 09 - Create SNS Topic and Subscriptions
# ============================================================

REGION=us-east-1

echo "Creating SNS topic..."
SNS_ARN=$(aws sns create-topic \
  --name WNXT-Prod-Alerts \
  --query TopicArn \
  --output text \
  --region ${REGION})
echo "SNS Topic ARN: ${SNS_ARN}"

echo "Adding email subscriptions..."
echo "Update emails below before running!"
aws sns subscribe \
  --topic-arn ${SNS_ARN} \
  --protocol email \
  --notification-endpoint jareks@ganz.com \
  --region ${REGION}

aws sns subscribe \
  --topic-arn ${SNS_ARN} \
  --protocol email \
  --notification-endpoint samuelr@ganz.com \
  --region ${REGION}

echo ""
echo "============================================"
echo "SNS Topic ARN: ${SNS_ARN}"
echo "IMPORTANT: Both emails must confirm subscription!"
echo "Update SNS_ARN in 10-create-alarms.sh before running"
echo "============================================"

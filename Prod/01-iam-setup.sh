#!/bin/bash
# ============================================================
# WNXT Prod - Step 01 - IAM Setup
# Run from Jarek's Mac/PC
# ============================================================

REGION=us-east-1
ROLE_NAME=ganz-cloudwatch-addnl-metrics-prod

echo "Step 1: Creating IAM role..."
aws iam create-role \
  --role-name ${ROLE_NAME} \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' \
  --region ${REGION}
echo "IAM role created"

echo "Step 2: Creating metrics publisher policy..."
aws iam create-policy \
  --policy-name ganz-cloudwatch-metrics-publisher-prod \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": "cloudwatch:PutMetricData",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "cloudwatch:namespace": "Ganz/Webkinz"
        }
      }
    }]
  }' \
  --region ${REGION}
echo "Metrics publisher policy created"

echo "Step 3: Attaching metrics policy to role..."
aws iam attach-role-policy \
  --role-name ${ROLE_NAME} \
  --policy-arn arn:aws:iam::604009108246:policy/ganz-cloudwatch-metrics-publisher-prod \
  --region ${REGION}
echo "Policy attached"

echo "Step 4: Adding ELB register inline policy (update READINESS_TG_ARN after TG is created)..."
# Run this after target groups are created in step 03
# aws iam put-role-policy \
#   --role-name ${ROLE_NAME} \
#   --policy-name WNXT-Prod-ELB-Register \
#   --policy-document '{
#     "Version": "2012-10-17",
#     "Statement": [{
#       "Effect": "Allow",
#       "Action": [
#         "elasticloadbalancing:RegisterTargets",
#         "elasticloadbalancing:DeregisterTargets"
#       ],
#       "Resource": "REPLACE_WITH_PROD_READINESS_TG_ARN"
#     }]
#   }' \
#   --region ${REGION}

echo "Step 5: Adding lifecycle complete inline policy..."
aws iam put-role-policy \
  --role-name ${ROLE_NAME} \
  --policy-name WNXT-Prod-Lifecycle-Complete \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "autoscaling:CompleteLifecycleAction",
        "autoscaling:DescribeAutoScalingInstances"
      ],
      "Resource": "*"
    }]
  }' \
  --region ${REGION}
echo "Lifecycle policy added"

echo "Step 6: Creating instance profile..."
aws iam create-instance-profile \
  --instance-profile-name ${ROLE_NAME} \
  --region ${REGION}
aws iam add-role-to-instance-profile \
  --instance-profile-name ${ROLE_NAME} \
  --role-name ${ROLE_NAME} \
  --region ${REGION}
echo "Instance profile created"

echo "IAM setup complete!"

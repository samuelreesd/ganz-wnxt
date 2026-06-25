#!/bin/bash
# ============================================================
# WNXT Production - Deploy Scaling Policy
# Target Tracking = Scale Out only
# Step Scaling    = Controlled Scale In
#
# UPDATE THESE VALUES BEFORE RUNNING:
# ============================================================

REGION=us-east-1
ASG_NAME=WNXT-PROD-USER-ASG
CLUSTER_NAME=WNXT-PROD-CLUSTER

# Target value for scale out (sessions per instance)
TARGET_VALUE=150

# Scale in threshold = 30% of target value
# e.g. 30% of 8.0 = 2.4
SCALEIN_THRESHOLD=70

# How many minutes sessions must stay below threshold before scale in
SCALEIN_MINUTES=5

# Instance warmup time in seconds
INSTANCE_WARMUP=300

# Cooldown between scale in events in seconds
SCALEIN_COOLDOWN=300

# Number of instances to remove per scale in event
SCALEIN_ADJUSTMENT=-1

# ============================================================
# DO NOT EDIT BELOW THIS LINE
# ============================================================

echo "============================================"
echo "WNXT Production Scaling Configuration:"
echo "  ASG:                ${ASG_NAME}"
echo "  Cluster:            ${CLUSTER_NAME}"
echo "  Scale Out target:   Sessions > ${TARGET_VALUE}"
echo "  Scale In threshold: Sessions < ${SCALEIN_THRESHOLD} for ${SCALEIN_MINUTES} min"
echo "  Instance warmup:    ${INSTANCE_WARMUP}s"
echo "  Scale In cooldown:  ${SCALEIN_COOLDOWN}s"
echo "  Scale In step:      ${SCALEIN_ADJUSTMENT} instance(s)"
echo "============================================"
echo ""

# Calculate evaluation periods (1 period = 60 seconds)
SCALEIN_PERIODS=$((SCALEIN_MINUTES * 60 / 60))

# Step 1 - Update Target Tracking policy with DisableScaleIn=true
echo "Step 1: Updating Target Tracking policy..."
echo "  TargetValue=${TARGET_VALUE}, DisableScaleIn=true"

cat > /tmp/tt-policy.json << TTEOF
{
  "CustomizedMetricSpecification": {
    "MetricName": "Sessions",
    "Namespace": "Ganz/Webkinz",
    "Dimensions": [
      {"Name": "AutoScalingGroupName", "Value": "${ASG_NAME}"},
      {"Name": "ClusterName",          "Value": "${CLUSTER_NAME}"}
    ],
    "Statistic": "Average"
  },
  "TargetValue": ${TARGET_VALUE},
  "DisableScaleIn": true
}
TTEOF

aws autoscaling put-scaling-policy \
  --auto-scaling-group-name ${ASG_NAME} \
  --policy-name "WNXT-PROD-USER-TargetTracking-Sessions" \
  --policy-type TargetTrackingScaling \
  --estimated-instance-warmup ${INSTANCE_WARMUP} \
  --target-tracking-configuration file:///tmp/tt-policy.json \
  --region ${REGION}
echo "Target Tracking policy updated ✅"

# Step 2 - Create Step Scaling Scale In policy
echo ""
echo "Step 2: Creating Step Scaling Scale In policy..."
echo "  Adjustment=${SCALEIN_ADJUSTMENT}, Cooldown=${SCALEIN_COOLDOWN}s"

SCALEIN_POLICY_ARN=$(aws autoscaling put-scaling-policy \
  --auto-scaling-group-name ${ASG_NAME} \
  --policy-name "WNXT-PROD-USER-StepScaleIn-Sessions" \
  --policy-type StepScaling \
  --adjustment-type ChangeInCapacity \
  --step-adjustments MetricIntervalUpperBound=0,ScalingAdjustment=${SCALEIN_ADJUSTMENT} \
  --cooldown ${SCALEIN_COOLDOWN} \
  --query "PolicyARN" \
  --output text \
  --region ${REGION})
echo "Step Scaling policy created ✅"
echo "  ARN: ${SCALEIN_POLICY_ARN}"

# Step 3 - Create CloudWatch alarm for scale in
echo ""
echo "Step 3: Creating scale in alarm..."
echo "  Sessions < ${SCALEIN_THRESHOLD} for ${SCALEIN_MINUTES} min (${SCALEIN_PERIODS} periods)"

aws cloudwatch put-metric-alarm \
  --alarm-name "WNXT-PROD-Sessions-ScaleIn" \
  --alarm-description "Sessions average below ${SCALEIN_THRESHOLD} (30% of target ${TARGET_VALUE}) for ${SCALEIN_MINUTES} minutes - trigger scale in" \
  --namespace "Ganz/Webkinz" \
  --metric-name "Sessions" \
  --dimensions Name=AutoScalingGroupName,Value=${ASG_NAME} Name=ClusterName,Value=${CLUSTER_NAME} \
  --statistic Average \
  --period 60 \
  --threshold ${SCALEIN_THRESHOLD} \
  --comparison-operator LessThanThreshold \
  --evaluation-periods ${SCALEIN_PERIODS} \
  --alarm-actions ${SCALEIN_POLICY_ARN} \
  --treat-missing-data notBreaching \
  --region ${REGION}
echo "Scale in alarm created ✅"

# Step 4 - Verify
echo ""
echo "Step 4: Verifying deployment..."
aws autoscaling describe-policies \
  --auto-scaling-group-name ${ASG_NAME} \
  --query "ScalingPolicies[*].{Name:PolicyName,Type:PolicyType}" \
  --region ${REGION}

echo ""
echo "============================================"
echo "Deployment complete!"
echo ""
echo "Scale Out: Target Tracking → Sessions > ${TARGET_VALUE}"
echo "Scale In:  Step Scaling   → Sessions < ${SCALEIN_THRESHOLD} for ${SCALEIN_MINUTES} min"
echo "Yoyo prevention: DisableScaleIn=true on Target Tracking ✅"
echo "============================================"

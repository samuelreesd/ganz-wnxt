#!/bin/bash
# ============================================================
# WNXT Prod - Step 08 - Create Target Tracking Scaling Policy
# ============================================================

REGION=us-east-1
ASG_NAME=WNXT-PROD-USER-ASG

cat > /tmp/prod-target-tracking-policy.json << 'JSON'
{
  "CustomizedMetricSpecification": {
    "MetricName": "Sessions",
    "Namespace": "Ganz/Webkinz",
    "Dimensions": [
      {"Name": "AutoScalingGroupName", "Value": "WNXT-PROD-USER-ASG"},
      {"Name": "ClusterName",          "Value": "WNXT-PROD-CLUSTER"}
    ],
    "Statistic": "Average"
  },
  "TargetValue": 6.0,
  "DisableScaleIn": false
}
JSON

aws autoscaling put-scaling-policy \
  --auto-scaling-group-name ${ASG_NAME} \
  --policy-name "WNXT-PROD-USER-TargetTracking-Sessions" \
  --policy-type TargetTrackingScaling \
  --estimated-instance-warmup 300 \
  --target-tracking-configuration file:///tmp/prod-target-tracking-policy.json \
  --region ${REGION}

echo "Target tracking policy created"
echo "AWS will automatically create AlarmHigh and AlarmLow alarms"

#!/bin/bash
# ============================================================
# WNXT Prod - Step 10 - Create CloudWatch Alarms
# Update SNS_ARN from step 09 before running
# ============================================================

REGION=us-east-1
NS="Ganz/Webkinz"
ASG=WNXT-PROD-USER-ASG
CLUSTER=WNXT-PROD-CLUSTER
SNS_ARN=REPLACE_WITH_PROD_SNS_ARN_FROM_STEP_09

echo "[1/13] Mem % Used"
aws cloudwatch put-metric-alarm \
  --alarm-name "WNXT-PROD-MemUsedPct-High" \
  --alarm-description "Memory used exceeds 80%" \
  --namespace "${NS}" --metric-name "Mem % Used" \
  --dimensions Name=AutoScalingGroupName,Value=${ASG} Name=ClusterName,Value=${CLUSTER} \
  --statistic Maximum --period 60 --threshold 80 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 2 --alarm-actions ${SNS_ARN} \
  --ok-actions ${SNS_ARN} --treat-missing-data notBreaching \
  --region ${REGION}

echo "[2/13] Mem Used"
aws cloudwatch put-metric-alarm \
  --alarm-name "WNXT-PROD-MemUsed-High" \
  --alarm-description "Absolute memory used is high" \
  --namespace "${NS}" --metric-name "Mem Used" \
  --dimensions Name=AutoScalingGroupName,Value=${ASG} Name=ClusterName,Value=${CLUSTER} \
  --statistic Maximum --period 60 --threshold 800 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 2 --alarm-actions ${SNS_ARN} \
  --treat-missing-data notBreaching --region ${REGION}

echo "[3/13] Mem Committed"
aws cloudwatch put-metric-alarm \
  --alarm-name "WNXT-PROD-MemCommitted-High" \
  --alarm-description "Committed memory is high" \
  --namespace "${NS}" --metric-name "Mem Committed" \
  --dimensions Name=AutoScalingGroupName,Value=${ASG} Name=ClusterName,Value=${CLUSTER} \
  --statistic Maximum --period 60 --threshold 900 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 2 --alarm-actions ${SNS_ARN} \
  --treat-missing-data notBreaching --region ${REGION}

echo "[4/13] Mem Max"
aws cloudwatch put-metric-alarm \
  --alarm-name "WNXT-PROD-MemMax-Low" \
  --alarm-description "Max available memory is critically low" \
  --namespace "${NS}" --metric-name "Mem Max" \
  --dimensions Name=AutoScalingGroupName,Value=${ASG} Name=ClusterName,Value=${CLUSTER} \
  --statistic Minimum --period 60 --threshold 512 \
  --comparison-operator LessThanOrEqualToThreshold \
  --evaluation-periods 2 --alarm-actions ${SNS_ARN} \
  --treat-missing-data notBreaching --region ${REGION}

echo "[5/13] Mem Init"
aws cloudwatch put-metric-alarm \
  --alarm-name "WNXT-PROD-MemInit-High" \
  --alarm-description "Initial memory allocation is unexpectedly high" \
  --namespace "${NS}" --metric-name "Mem Init" \
  --dimensions Name=AutoScalingGroupName,Value=${ASG} Name=ClusterName,Value=${CLUSTER} \
  --statistic Maximum --period 300 --threshold 512 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 1 --alarm-actions ${SNS_ARN} \
  --treat-missing-data notBreaching --region ${REGION}

echo "[6/13] Threads"
aws cloudwatch put-metric-alarm \
  --alarm-name "WNXT-PROD-Threads-High" \
  --alarm-description "Thread count is high - possible thread leak" \
  --namespace "${NS}" --metric-name "Threads" \
  --dimensions Name=AutoScalingGroupName,Value=${ASG} Name=ClusterName,Value=${CLUSTER} \
  --statistic Maximum --period 60 --threshold 200 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 3 --alarm-actions ${SNS_ARN} \
  --treat-missing-data notBreaching --region ${REGION}

echo "[7/13] Busy"
aws cloudwatch put-metric-alarm \
  --alarm-name "WNXT-PROD-Busy-High" \
  --alarm-description "Busy workers are high" \
  --namespace "${NS}" --metric-name "Busy" \
  --dimensions Name=AutoScalingGroupName,Value=${ASG} Name=ClusterName,Value=${CLUSTER} \
  --statistic Maximum --period 60 --threshold 50 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 2 --alarm-actions ${SNS_ARN} \
  --treat-missing-data notBreaching --region ${REGION}

echo "[8/13] Client Rate"
aws cloudwatch put-metric-alarm \
  --alarm-name "WNXT-PROD-ClientRate-High" \
  --alarm-description "Client request rate is high" \
  --namespace "${NS}" --metric-name "Client Rate" \
  --dimensions Name=AutoScalingGroupName,Value=${ASG} Name=ClusterName,Value=${CLUSTER} \
  --statistic Maximum --period 60 --threshold 500 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 2 --alarm-actions ${SNS_ARN} \
  --treat-missing-data notBreaching --region ${REGION}

echo "[9/13] Connections"
aws cloudwatch put-metric-alarm \
  --alarm-name "WNXT-PROD-Connections-High" \
  --alarm-description "Connection count is high" \
  --namespace "${NS}" --metric-name "Connections" \
  --dimensions Name=AutoScalingGroupName,Value=${ASG} Name=ClusterName,Value=${CLUSTER} \
  --statistic Maximum --period 60 --threshold 100 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 2 --alarm-actions ${SNS_ARN} \
  --treat-missing-data notBreaching --region ${REGION}

echo "[10/13] Connections Max"
aws cloudwatch put-metric-alarm \
  --alarm-name "WNXT-PROD-ConnectionsMax-High" \
  --alarm-description "Max connections are near ceiling" \
  --namespace "${NS}" --metric-name "Connections Max" \
  --dimensions Name=AutoScalingGroupName,Value=${ASG} Name=ClusterName,Value=${CLUSTER} \
  --statistic Maximum --period 60 --threshold 150 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 2 --alarm-actions ${SNS_ARN} \
  --treat-missing-data notBreaching --region ${REGION}

echo "[11/13] RuntimeInGC"
aws cloudwatch put-metric-alarm \
  --alarm-name "WNXT-PROD-RuntimeInGC-High" \
  --alarm-description "JVM spending too much time in GC" \
  --namespace "${NS}" --metric-name "RuntimeInGC" \
  --dimensions Name=AutoScalingGroupName,Value=${ASG} Name=ClusterName,Value=${CLUSTER} \
  --statistic Maximum --period 60 --threshold 10 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 3 --alarm-actions ${SNS_ARN} \
  --treat-missing-data notBreaching --region ${REGION}

echo "[12/13] Hung"
aws cloudwatch put-metric-alarm \
  --alarm-name "WNXT-PROD-Hung-Any" \
  --alarm-description "CRITICAL: One or more hung threads detected" \
  --namespace "${NS}" --metric-name "Hung" \
  --dimensions Name=AutoScalingGroupName,Value=${ASG} Name=ClusterName,Value=${CLUSTER} \
  --statistic Sum --period 60 --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 1 --alarm-actions ${SNS_ARN} \
  --treat-missing-data notBreaching --region ${REGION}

echo "[13/13] Sessions High"
aws cloudwatch put-metric-alarm \
  --alarm-name "WNXT-PROD-Sessions-High" \
  --alarm-description "Average Sessions across all WNXT-PROD-USER-ASG instances crossed 8" \
  --namespace "${NS}" --metric-name "Sessions" \
  --dimensions Name=AutoScalingGroupName,Value=${ASG} Name=ClusterName,Value=${CLUSTER} \
  --statistic Average --period 60 --threshold 8 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --alarm-actions ${SNS_ARN} \
  --ok-actions ${SNS_ARN} \
  --treat-missing-data notBreaching \
  --region ${REGION}

echo ""
echo "All 13 alarms created!"

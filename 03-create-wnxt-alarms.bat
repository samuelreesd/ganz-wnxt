@echo off
REM ============================================================
REM  WNXT - Ganz/Webkinz CloudWatch Alarms Setup
REM  Namespace : Ganz/Webkinz
REM  ASG       : WNXT-INT-USER-ASG
REM  Cluster   : WNXT-INT-CLUSTER
REM  Region    : us-east-1
REM  Note      : InstanceId dimension removed - alarms aggregate
REM              across ALL instances in the ASG
REM ============================================================

SET REGION=us-east-1
SET NS=Ganz/Webkinz
SET ASG=WNXT-INT-USER-ASG
SET CLUSTER=WNXT-INT-CLUSTER

REM --- REQUIRED: Replace with your SNS Topic ARN ---
SET SNS_ARN=arn:aws:sns:us-east-1:604009108246:WNXT-Alerts

REM --- OPTIONAL: Leave blank until Auto Scaling is set up ---
SET SCALEOUT_ARN=
SET SCALEIN_ARN=

REM ============================================================
REM  Build alarm-actions string (SNS only, or SNS + ScaleOut)
REM ============================================================
SET ALARM_ACTIONS=%SNS_ARN%
SET OK_ACTIONS=%SNS_ARN%
IF NOT "%SCALEOUT_ARN%"=="" SET ALARM_ACTIONS=%SNS_ARN% %SCALEOUT_ARN%
IF NOT "%SCALEIN_ARN%"=="" SET OK_ACTIONS=%SNS_ARN% %SCALEIN_ARN%

echo.
echo ============================================================
echo  Starting WNXT Alarm Creation
echo  ASG         : %ASG%
echo  Cluster     : %CLUSTER%
echo  SNS         : %SNS_ARN%
echo  Scale-Out   : %SCALEOUT_ARN% (blank = not set yet)
echo  Scale-In    : %SCALEIN_ARN%  (blank = not set yet)
echo ============================================================

echo.
echo [1/13] Mem %% Used - High Memory Warning
aws cloudwatch put-metric-alarm ^
  --alarm-name "WNXT-MemUsedPct-High" ^
  --alarm-description "Memory used exceeds 80%%" ^
  --namespace "%NS%" ^
  --metric-name "Mem %% Used" ^
  --dimensions Name=AutoScalingGroupName,Value=%ASG% Name=ClusterName,Value=%CLUSTER% ^
  --statistic Maximum ^
  --period 60 ^
  --threshold 80 ^
  --comparison-operator GreaterThanOrEqualToThreshold ^
  --evaluation-periods 2 ^
  --alarm-actions %ALARM_ACTIONS% ^
  --ok-actions %OK_ACTIONS% ^
  --treat-missing-data notBreaching ^
  --region %REGION%
echo Done.

echo.
echo [2/13] Mem Used - Absolute memory usage high
aws cloudwatch put-metric-alarm ^
  --alarm-name "WNXT-MemUsed-High" ^
  --alarm-description "Absolute memory used is high" ^
  --namespace "%NS%" ^
  --metric-name "Mem Used" ^
  --dimensions Name=AutoScalingGroupName,Value=%ASG% Name=ClusterName,Value=%CLUSTER% ^
  --statistic Maximum ^
  --period 60 ^
  --threshold 800 ^
  --comparison-operator GreaterThanOrEqualToThreshold ^
  --evaluation-periods 2 ^
  --alarm-actions %ALARM_ACTIONS% ^
  --treat-missing-data notBreaching ^
  --region %REGION%
echo Done.

echo.
echo [3/13] Mem Committed - Committed memory high
aws cloudwatch put-metric-alarm ^
  --alarm-name "WNXT-MemCommitted-High" ^
  --alarm-description "Committed memory is high" ^
  --namespace "%NS%" ^
  --metric-name "Mem Committed" ^
  --dimensions Name=AutoScalingGroupName,Value=%ASG% Name=ClusterName,Value=%CLUSTER% ^
  --statistic Maximum ^
  --period 60 ^
  --threshold 900 ^
  --comparison-operator GreaterThanOrEqualToThreshold ^
  --evaluation-periods 2 ^
  --alarm-actions %ALARM_ACTIONS% ^
  --treat-missing-data notBreaching ^
  --region %REGION%
echo Done.

echo.
echo [4/13] Mem Max - Max memory threshold breach
aws cloudwatch put-metric-alarm ^
  --alarm-name "WNXT-MemMax-Low" ^
  --alarm-description "Max available memory is critically low" ^
  --namespace "%NS%" ^
  --metric-name "Mem Max" ^
  --dimensions Name=AutoScalingGroupName,Value=%ASG% Name=ClusterName,Value=%CLUSTER% ^
  --statistic Minimum ^
  --period 60 ^
  --threshold 512 ^
  --comparison-operator LessThanOrEqualToThreshold ^
  --evaluation-periods 2 ^
  --alarm-actions %ALARM_ACTIONS% ^
  --treat-missing-data notBreaching ^
  --region %REGION%
echo Done.

echo.
echo [5/13] Mem Init - Init memory anomaly
aws cloudwatch put-metric-alarm ^
  --alarm-name "WNXT-MemInit-High" ^
  --alarm-description "Initial memory allocation is unexpectedly high" ^
  --namespace "%NS%" ^
  --metric-name "Mem Init" ^
  --dimensions Name=AutoScalingGroupName,Value=%ASG% Name=ClusterName,Value=%CLUSTER% ^
  --statistic Maximum ^
  --period 300 ^
  --threshold 512 ^
  --comparison-operator GreaterThanOrEqualToThreshold ^
  --evaluation-periods 1 ^
  --alarm-actions %ALARM_ACTIONS% ^
  --treat-missing-data notBreaching ^
  --region %REGION%
echo Done.

echo.
echo [6/13] Threads - High thread count
aws cloudwatch put-metric-alarm ^
  --alarm-name "WNXT-Threads-High" ^
  --alarm-description "Thread count is high - possible thread leak" ^
  --namespace "%NS%" ^
  --metric-name "Threads" ^
  --dimensions Name=AutoScalingGroupName,Value=%ASG% Name=ClusterName,Value=%CLUSTER% ^
  --statistic Maximum ^
  --period 60 ^
  --threshold 200 ^
  --comparison-operator GreaterThanOrEqualToThreshold ^
  --evaluation-periods 3 ^
  --alarm-actions %ALARM_ACTIONS% ^
  --treat-missing-data notBreaching ^
  --region %REGION%
echo Done.

echo.
echo [7/13] Busy - High busy worker count
aws cloudwatch put-metric-alarm ^
  --alarm-name "WNXT-Busy-High" ^
  --alarm-description "Busy workers are high - capacity may be exhausted" ^
  --namespace "%NS%" ^
  --metric-name "Busy" ^
  --dimensions Name=AutoScalingGroupName,Value=%ASG% Name=ClusterName,Value=%CLUSTER% ^
  --statistic Maximum ^
  --period 60 ^
  --threshold 50 ^
  --comparison-operator GreaterThanOrEqualToThreshold ^
  --evaluation-periods 2 ^
  --alarm-actions %ALARM_ACTIONS% ^
  --treat-missing-data notBreaching ^
  --region %REGION%
echo Done.

echo.
echo [8/13] Client Rate - High incoming client rate
aws cloudwatch put-metric-alarm ^
  --alarm-name "WNXT-ClientRate-High" ^
  --alarm-description "Client request rate is high" ^
  --namespace "%NS%" ^
  --metric-name "Client Rate" ^
  --dimensions Name=AutoScalingGroupName,Value=%ASG% Name=ClusterName,Value=%CLUSTER% ^
  --statistic Maximum ^
  --period 60 ^
  --threshold 500 ^
  --comparison-operator GreaterThanOrEqualToThreshold ^
  --evaluation-periods 2 ^
  --alarm-actions %ALARM_ACTIONS% ^
  --treat-missing-data notBreaching ^
  --region %REGION%
echo Done.

echo.
echo [9/13] Connections - High connection count
aws cloudwatch put-metric-alarm ^
  --alarm-name "WNXT-Connections-High" ^
  --alarm-description "Connection count is high" ^
  --namespace "%NS%" ^
  --metric-name "Connections" ^
  --dimensions Name=AutoScalingGroupName,Value=%ASG% Name=ClusterName,Value=%CLUSTER% ^
  --statistic Maximum ^
  --period 60 ^
  --threshold 100 ^
  --comparison-operator GreaterThanOrEqualToThreshold ^
  --evaluation-periods 2 ^
  --alarm-actions %ALARM_ACTIONS% ^
  --treat-missing-data notBreaching ^
  --region %REGION%
echo Done.

echo.
echo [10/13] Connections Max - Max connections ceiling reached
aws cloudwatch put-metric-alarm ^
  --alarm-name "WNXT-ConnectionsMax-High" ^
  --alarm-description "Max connections are near ceiling" ^
  --namespace "%NS%" ^
  --metric-name "Connections Max" ^
  --dimensions Name=AutoScalingGroupName,Value=%ASG% Name=ClusterName,Value=%CLUSTER% ^
  --statistic Maximum ^
  --period 60 ^
  --threshold 150 ^
  --comparison-operator GreaterThanOrEqualToThreshold ^
  --evaluation-periods 2 ^
  --alarm-actions %ALARM_ACTIONS% ^
  --treat-missing-data notBreaching ^
  --region %REGION%
echo Done.

echo.
echo [11/13] RuntimeInGC - GC pausing application too long
aws cloudwatch put-metric-alarm ^
  --alarm-name "WNXT-RuntimeInGC-High" ^
  --alarm-description "JVM spending too much time in garbage collection" ^
  --namespace "%NS%" ^
  --metric-name "RuntimeInGC" ^
  --dimensions Name=AutoScalingGroupName,Value=%ASG% Name=ClusterName,Value=%CLUSTER% ^
  --statistic Maximum ^
  --period 60 ^
  --threshold 10 ^
  --comparison-operator GreaterThanOrEqualToThreshold ^
  --evaluation-periods 3 ^
  --alarm-actions %ALARM_ACTIONS% ^
  --treat-missing-data notBreaching ^
  --region %REGION%
echo Done.

echo.
echo [12/13] Hung - Any hung threads detected
aws cloudwatch put-metric-alarm ^
  --alarm-name "WNXT-Hung-Any" ^
  --alarm-description "CRITICAL: One or more hung threads detected" ^
  --namespace "%NS%" ^
  --metric-name "Hung" ^
  --dimensions Name=AutoScalingGroupName,Value=%ASG% Name=ClusterName,Value=%CLUSTER% ^
  --statistic Sum ^
  --period 60 ^
  --threshold 1 ^
  --comparison-operator GreaterThanOrEqualToThreshold ^
  --evaluation-periods 1 ^
  --alarm-actions %ALARM_ACTIONS% ^
  --treat-missing-data notBreaching ^
  --region %REGION%
echo Done.

echo.
echo [13/13] Sessions - Sessions crossed alert threshold of 8
aws cloudwatch put-metric-alarm ^
  --alarm-name "WNXT-Sessions-High" ^
  --alarm-description "Sessions have crossed alert threshold of 8" ^
  --namespace "%NS%" ^
  --metric-name "Sessions" ^
  --dimensions Name=AutoScalingGroupName,Value=%ASG% Name=ClusterName,Value=%CLUSTER% ^
  --statistic Maximum ^
  --period 60 ^
  --threshold 8 ^
  --comparison-operator GreaterThanThreshold ^
  --evaluation-periods 1 ^
  --alarm-actions %ALARM_ACTIONS% ^
  --ok-actions %OK_ACTIONS% ^
  --treat-missing-data notBreaching ^
  --region %REGION%
echo Done.

echo.
echo ============================================================
echo  All 13 alarms created successfully!
echo  Verify at: https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#alarmsV2
echo ============================================================

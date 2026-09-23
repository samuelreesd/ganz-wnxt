*** Build the AMI from the WNXT Prod Image Builder 10.20.150.115
aws ec2 create-image \
  --instance-id i-07d0055cac7d7dc3e \
  --name "WNXT-Prod20-User-AMI-v5" \
  --description "WNXT Prod20 User AMI Branch Build #154.2" \
  --no-reboot \
  --region us-east-1

*** Check if the AMI is ready
aws ec2 describe-images \
  --filters "Name=name,Values=WNXT-Prod20-User-AMI-v5" \
  --query "Images[*].{ID:ImageId,State:State,Name:Name}" \
  --region us-east-1

*************************************** Create new Launch Template version with new AMI
aws ec2 create-launch-template-version \
  --launch-template-id  lt-000c91378cae1aaa3  \
  --source-version 3 \
  --version-description "v4 - Trunk Build #422.3" \
  --launch-template-data '{
    "ImageId": "ami-0eb7a278bbb0a7928",
    "InstanceType": "r7i.large",
    "TagSpecifications": [
      {
        "ResourceType": "instance",
        "Tags": [
          {"Key": "Name", "Value": "wnxt-prod20-user"}
        ]
      }
    ]
  }' \
  --region us-east-1


*** Check the Launch Template
aws ec2 describe-launch-template-versions \
  --launch-template-id lt-000c91378cae1aaa3 \
  --query "LaunchTemplateVersions[*].{Version:VersionNumber,Default:DefaultVersion,Description:VersionDescription,AMI:LaunchTemplateData.ImageId,InstanceType:LaunchTemplateData.InstanceType}" \
  --output table \
  --region us-east-1

*** Set v4 as default
aws ec2 modify-launch-template \
  --launch-template-id lt-000c91378cae1aaa3 \
  --default-version 4 \
  --region us-east-1

*** Confirm the default, latest version of the Launch Template
aws ec2 describe-launch-templates \
  --launch-template-ids lt-000c91378cae1aaa3 \
  --query "LaunchTemplates[0].{Default:DefaultVersionNumber,Latest:LatestVersionNumber}" \
  --output table \
  --region us-east-1

*** Verify ASG is Launching Instances
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names WNXT-PROD20-USER-ASG \
  --query "AutoScalingGroups[*].{Desired:DesiredCapacity,Min:MinSize,Max:MaxSize,Instances:Instances[*].{ID:InstanceId,State:LifecycleState,Health:HealthStatus}}" \
  --region us-east-1

*** Verify ASG is Launching Instances to show with IP
aws ec2 describe-instances \
  --filters "Name=tag:aws:autoscaling:groupName,Values=WNXT-PROD20-USER-ASG" \
            "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].{ID:InstanceId,IP:PrivateIpAddress,Name:Tags[?Key=='Name'].Value|[0],Type:InstanceType,State:State.Name}" \
  --output table \
  --region us-east-1

*** List Metrics
Prod$ aws cloudwatch list-metrics \
  --namespace "Ganz/Webkinz/Nxt/Prod20" \
  --dimensions Name=AutoScalingGroupName,Value=WNXT-PROD20-USER-ASG \
  --region us-east-1

***
# GRACEFUL SHUTDOWN LIFECYCLE HOOK Graceful Shutdown Lifecycle hook (describe it)
aws autoscaling describe-lifecycle-hooks \
  --auto-scaling-group-name WNXT-PROD20-USER-ASG \
  --region us-east-1

***
# GRACEFUL SHUTDOWN LIFECYCLE HOOK check graceful shudown on the instance
[root@ip-10-2-151-155 aw]# grep "LIFECYCLE_HOOK" /usr/local/bin/graceful-shutdown.sh
LIFECYCLE_HOOK=WNXT-PROD-USER-TerminateHook
  --lifecycle-hook-name ${LIFECYCLE_HOOK} \
[root@ip-10-20-151-155 aw]#

***
# GRACEFUL SHUTDOWN LIFECYCLE HOOK crontab on the instance for Graceful Shutdown
[root@ip-10-2-151-155 aw]# crontab -l
* * * * * /usr/local/bin/poll-lifecycle.sh

0 0 * * 0 > /var/log/graceful-shutdown.log
[root@ip-10-2-151-155 aw]#

[root@ip-10-2-151-155 aw]# crontab -l
* * * * * /usr/local/bin/poll-lifecycle.sh

0 0 * * 0 > /var/log/graceful-shutdown.log
[root@ip-10-2-151-155 aw]#

***
# GRACEFUL SHUTDOWN LIFECYCLE HOOK Check both scripts exist and are executable
ls -la /usr/local/bin/poll-lifecycle.sh
ls -la /usr/local/bin/graceful-shutdown.sh

# GRACEFUL SHUTDOWN LIFECYCLE HOOK Check /etc/environment has correct values
cat /etc/environment

# GRACEFUL SHUTDOWN LIFECYCLE HOOK Check which ASG this instance belongs to
aws autoscaling describe-auto-scaling-instances \
  --instance-ids $(curl -s http://169.254.169.254/latest/meta-data/instance-id) \
  --query "AutoScalingInstances[0].{ASG:AutoScalingGroupName,State:LifecycleState,Health:HealthStatus}" \
  --region us-east-1


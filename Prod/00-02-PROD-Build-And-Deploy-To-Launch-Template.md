*** Build the AMI from the WNXT Prod Image Builder 10.2.150.115
aws ec2 create-image \
  --instance-id i-0819cfae81cfe42d9 \
  --name "WNXT-Prod-User-AMI-v12" \
  --description "WNXT Prod User AMI Branch Build #133.1" \
  --no-reboot \
  --region us-east-1

*** Check if the AMI is ready
aws ec2 describe-images \
  --filters "Name=name,Values=WNXT-Prod-User-AMI-v12" \
  --query "Images[*].{ID:ImageId,State:State,Name:Name}" \
  --region us-east-1

  *** Create the Launch Template !!!!!!!!!!!!!!!!!! EXECUTE ONLY FOR THE FIRST TIME !!!!!!!!!!!!
  aws ec2 create-launch-template \
  --launch-template-name lt-wnxt-prod-user \
  --version-description "v1 - WNXT Prod User For ASG" \
  --launch-template-data '{
    "ImageId": "ami-0e14a749e83e91208",
    "InstanceType": "m5.large",
    "IamInstanceProfile": {"Name": "ganz-cloudwatch-addnl-metrics"},
    "SecurityGroupIds": [
      "sg-0aaa5de6c2c1ad13f",
      "sg-8796e1f2",
      "sg-a578b9db",
      "sg-cf87b6b1",
      "sg-08ce79c729380bebd",
      "sg-066a462b5d2f154d3"
    ]
  }' \
  --region us-east-1

*************************************** Create new Launch Template version with new AMI
aws ec2 create-launch-template-version \
  --launch-template-id lt-0db8382b7b0f7b04c \
  --source-version 11 \
  --version-description "v12 - Branch Build #133.1" \
  --launch-template-data '{
    "ImageId": "ami-0e14a749e83e91208",
    "InstanceType": "r5.large",
    "TagSpecifications": [
      {
        "ResourceType": "instance",
        "Tags": [
          {"Key": "Name", "Value": "wnxt-prod-user"}
        ]
      }
    ]
  }' \
  --region us-east-1


*** Check the Launch Template
aws ec2 describe-launch-template-versions \
  --launch-template-id lt-0db8382b7b0f7b04c \
  --query "LaunchTemplateVersions[*].{Version:VersionNumber,Default:DefaultVersion,Description:VersionDescription,AMI:LaunchTemplateData.ImageId,InstanceType:LaunchTemplateData.InstanceType}" \
  --output table \
  --region us-east-1

*** Set v12 as default
aws ec2 modify-launch-template \
  --launch-template-id lt-0db8382b7b0f7b04c \
  --default-version 12 \
  --region us-east-1

*** Confirm the default, latest version of the Launch Template
aws ec2 describe-launch-templates \
  --launch-template-ids lt-0db8382b7b0f7b04c \
  --query "LaunchTemplates[0].{Default:DefaultVersionNumber,Latest:LatestVersionNumber}" \
  --output table \
  --region us-east-1

*** Verify ASG is Launching Instances
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names WNXT-PROD-USER-ASG \
  --query "AutoScalingGroups[*].{Desired:DesiredCapacity,Min:MinSize,Max:MaxSize,Instances:Instances[*].{ID:InstanceId,State:LifecycleState,Health:HealthStatus}}" \
  --region us-east-1

*** Verify ASG is Launching Instances to show with IP
aws ec2 describe-instances \
  --filters "Name=tag:aws:autoscaling:groupName,Values=WNXT-PROD-USER-ASG" \
            "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].{ID:InstanceId,IP:PrivateIpAddress,Name:Tags[?Key=='Name'].Value|[0],Type:InstanceType,State:State.Name}" \
  --output table \
  --region us-east-1

*** List Metrics
Prod$ aws cloudwatch list-metrics \
  --namespace "Ganz/Webkinz" \
  --dimensions Name=AutoScalingGroupName,Value=WNXT-PROD-USER-ASG \
  --region us-east-1

***
# GRACEFUL SHUTDOWN LIFECYCLE HOOK Graceful Shutdown Lifecycle hook (describe it)
aws autoscaling describe-lifecycle-hooks \
  --auto-scaling-group-name WNXT-PROD-USER-ASG \
  --region us-east-1

***
# GRACEFUL SHUTDOWN LIFECYCLE HOOK check graceful shudown on the instance
[root@ip-10-2-151-155 aw]# grep "LIFECYCLE_HOOK" /usr/local/bin/graceful-shutdown.sh
LIFECYCLE_HOOK=WNXT-PROD-USER-TerminateHook
  --lifecycle-hook-name ${LIFECYCLE_HOOK} \
[root@ip-10-2-151-155 aw]#

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


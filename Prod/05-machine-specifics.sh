#!/bin/sh -x
# ============================================================
# WNXT Prod - machine-specifics.sh
# Place at: /opt/webkinz-next/systems/user-server/machine-specifics.sh
# on the PROD image builder
# ============================================================

thismachineIP_user=$(hostname -i | awk '{print $1}')
gsfserverName_user=`hostname`-user
lastoctet=$(hostname -i | awk -F\. '{print $4}' | tr -d '[:space:]')
mcip=172.16.1.${lastoctet}

### Set ASG and Cluster names
ASG_NAME=WNXT-PROD-USER-ASG
CLUSTER_NAME=WNXT-PROD-CLUSTER
sed -i '/^ASG_NAME/d' /etc/environment
sed -i '/^CLUSTER_NAME/d' /etc/environment
echo "ASG_NAME=${ASG_NAME}" >> /etc/environment
echo "CLUSTER_NAME=${CLUSTER_NAME}" >> /etc/environment
export ASG_NAME=${ASG_NAME}
export CLUSTER_NAME=${CLUSTER_NAME}
echo "ASG_NAME set to: ${ASG_NAME}"
echo "CLUSTER_NAME set to: ${CLUSTER_NAME}"

### Set MAX_CONNECTIONS based on production instance type
### Update this value based on production instance type
MAX_CONNECTIONS=REPLACE_WITH_PROD_MAX_CONNECTIONS
sed -i '/^MAX_CONNECTIONS/d' /etc/environment
echo "MAX_CONNECTIONS=${MAX_CONNECTIONS}" >> /etc/environment
export MAX_CONNECTIONS=${MAX_CONNECTIONS}
echo "MAX_CONNECTIONS set to: ${MAX_CONNECTIONS}"

### Update AwUserServer properties
sed -i "s/^this.machineIP.*$/this.machineIP     = ${thismachineIP_user}/" /opt/sites/aw/user-server/conf/AwUserServer.props
sed -i "s/^gsf.serverName.*$/gsf.serverName     = ${gsfserverName_user}/" /opt/sites/aw/user-server/conf/AwUserServer.props
sed -i "s/^this.machineMCIP.*$/this.machineMCIP = ${mcip}/" /opt/sites/aw/user-server/conf/AwUserServer.props

### Update the Gateway Multicast Hub hostslist
ssh -o StrictHostKeyChecking=no root@10.2.150.101 \
  "grep -q ${thismachineIP_user} /srv/wnxt-on-aws/hub/hostslist || echo ${thismachineIP_user} >> /srv/wnxt-on-aws/hub/hostslist"

### Trigger reconciliation on hub
ssh -o StrictHostKeyChecking=no root@10.2.150.101 \
  "touch /tmp/multicast-reconcile-needed"
echo "Triggered multicast reconciliation on hub for ${thismachineIP_user}"

##### Setup overlay multicast on local instance
sleep 3
systemctl stop multicast-ganz.service
systemctl start multicast-ganz.service

### Register this instance in the ALB readiness target group
### Update with prod readiness TG ARN from step 03
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
READINESS_TG_ARN=REPLACE_WITH_PROD_READINESS_TG_ARN
aws elbv2 register-targets \
  --target-group-arn ${READINESS_TG_ARN} \
  --targets Id=${INSTANCE_ID},Port=80 \
  --region us-east-1
echo "Registered ${INSTANCE_ID} in readiness target group"

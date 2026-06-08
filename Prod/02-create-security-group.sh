#!/bin/bash
# ============================================================
# WNXT Prod - Step 02 - Create EC2 Security Group
# ============================================================

REGION=us-east-1
VPC_ID=vpc-4c677e2a
ALB_SG=sg-04fff5cbf33216ec4

echo "Creating wnxt-prod-user security group..."
SG_ID=$(aws ec2 create-security-group \
  --group-name wnxt-prod-user \
  --description "WNXT Production User Server" \
  --vpc-id ${VPC_ID} \
  --query "GroupId" \
  --output text \
  --region ${REGION})
echo "Security group created: ${SG_ID}"

echo "Adding inbound rule - port 8080 from ALB..."
aws ec2 authorize-security-group-ingress \
  --group-id ${SG_ID} \
  --protocol tcp \
  --port 8080 \
  --source-group ${ALB_SG} \
  --region ${REGION}
echo "Port 8080 from ALB SG added"

echo "Adding inbound rule - SSH from jump server..."
aws ec2 authorize-security-group-ingress \
  --group-id ${SG_ID} \
  --protocol tcp \
  --port 22 \
  --source-group sg-015d3d1129b426011 \
  --region ${REGION}
echo "SSH from jump server added"

echo "Security Group ID: ${SG_ID}"
echo "Update this value in subsequent scripts!"

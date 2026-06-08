#!/bin/bash
# ============================================================
# WNXT Prod - Step 12 - Deploy CloudWatch Dashboards
# ============================================================

REGION=us-east-1

echo "Deploying WNXT Prod metrics dashboard..."
aws cloudwatch put-dashboard \
  --dashboard-name "WNXT-Prod-Ganz-Webkinz" \
  --dashboard-body file://11-wnxt-prod-dashboard.json \
  --region ${REGION}
echo "Metrics dashboard deployed"

echo ""
echo "Deploying WNXT Prod multicast dashboard..."
echo "NOTE: Update HUB_IP to 10.2.150.101 in multicast dashboard JSON first"
# aws cloudwatch put-dashboard \
#   --dashboard-name "WNXT-Prod-Multicast" \
#   --dashboard-body file://wnxt-prod-multicast-dashboard.json \
#   --region ${REGION}

echo "Dashboards deployed!"
echo "View at: https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:"

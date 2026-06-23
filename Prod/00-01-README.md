# WNXT Production Auto Scaling — Deployment Guide

## Account Details
- AWS Account: 604009108246
- Region: us-east-1
- VPC: vpc-4c677e2a
- ALB: alb-wnxt
- ALB ARN: arn:aws:elasticloadbalancing:us-east-1:604009108246:loadbalancer/app/alb-wnxt/a4a019fc8ef45e8f
- ALB DNS: alb-wnxt-440462891.us-east-1.elb.amazonaws.com
- ALB SG: sg-04fff5cbf33216ec4
- Subnets: subnet-62002407 (us-east-1a), subnet-c1cb3ded (us-east-1b)
- Hub IP: 10.2.150.101

## Values Still Needed Before Deployment
- [ ] Production EC2 security group ID (wnxt-prod-user) — needs to be created
- [ ] Production instance type (m5.large or larger)
- [ ] Production MAX_CONNECTIONS value
- [ ] Production AMI ID (after building from prod image builder)
- [ ] Production Launch Template ID (after creating)
- [ ] SNS subscriber emails for production alerts

## Deployment Order
01. Create IAM role and policies
02. Create EC2 security group for prod user servers
03. Create target groups
04. Update ALB rule
05. Update machine-specifics.sh on prod image builder
06. Deploy hub scripts on prod hub (10.2.150.101)
07. Build AMI from prod image builder
08. Create Launch Template
09. Create ASG
10. Create Lifecycle Hook
11. Create Target Tracking scaling policy
12. Create SNS topic and subscriptions
13. Create 13 CloudWatch alarms
--------------------------------
14. Deploy CloudWatch dashboards

# Metrics dashboard
aws cloudwatch put-dashboard \
  --dashboard-name "WNXT-Prod-Ganz-Webkinz" \
  --dashboard-body file://11-metrics-wnxt-prod-dashboard.json \
  --region us-east-1

# Multicast dashboard
aws cloudwatch put-dashboard \
  --dashboard-name "WNXT-Prod-Multicast" \
  --dashboard-body file://11-multicast-wnxt-prod-dashboard.json \
  --region us-east-1

-----------------------------------------------------------------
New Scripts on the Hub 10.2.150.101

reconcile-multicast-ganz.sh
Runs every 5 minutes to keep the multicast bridge in sync with the hostslist. Removes stale GRE tunnels for terminated ASG instances and adds missing tunnels for newly launched instances. Publishes per-host MulticastHostStatus and summary metrics (Total, Healthy, Missing, Stale) to CloudWatch for dashboard visibility.

check-multicast-health.sh
A manual diagnostic tool run on-demand to inspect the current state of the multicast bridge. Compares the hostslist against active bridge interfaces to identify hosts that are unreachable, missing from the bridge, or stale tunnels that shouldn't be there. Publishes the health summary to CloudWatch so the dashboard reflects the latest state immediately after running.

manage-hostslist.sh
Runs every 5 minutes to clean up the hostslist by pinging each IP and removing any that are no longer reachable (terminated ASG instances). When a host is removed it immediately publishes MulticastHostStatus=0 to CloudWatch so the dashboard shows the host as gone without waiting for data to expire. Restarts the multicast service only when the hostslist actually changed to minimize disruption.

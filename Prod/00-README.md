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
14. Deploy CloudWatch dashboards

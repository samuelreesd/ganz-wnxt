This is a new dashboard (separate from your app-metrics one) focused on infra-level CPU/memory/network, structured in two sections:

Section 1 — Auto Scaling User Fleet (WNXT-PROD20-USER-ASG)
Since instances here come and go, these widgets use CloudWatch search expressions on the AutoScalingGroupName dimension instead of hardcoded instance IDs — they'll automatically pick up new instances and drop terminated ones. Includes: fleet-average CPU, per-instance CPU breakdown (good for spotting one bad instance), fleet memory average, network in/out, disk read/write, status check failures, and ASG capacity (desired/min/max/in-service) — plus the existing Sessions/Hung alarms for context.

Section 2 — Fixed Role Servers (web, location, sync, dcache, maintenance)
One block per server with static instance IDs, each showing: a metadata panel (instance ID, type, AZ, key, launch time, security groups), CPU, memory, network in/out, disk read/write, and status check failed.

Two things to verify before this is fully live:

Memory requires the CloudWatch Agent. CPU/network/disk are default EC2 metrics, but mem_used_percent only exists if the CloudWatch Agent is installed and reporting to the CWAgent namespace on each instance. If it's not installed yet, those panels will just show "No data" — let me know if you want help setting that up.
ASG memory search assumes the agent's config tags metrics with AutoScalingGroupName (via append_dimensions in the agent config). If that dimension isn't set, that one panel specifically will need adjusting to use per-instance search instead.

To deploy it:


aws cloudwatch put-dashboard --dashboard-name WNXT-Prod20-Infrastructure --dashboard-body file://wnxt-prod20-infra-dashboard.json --region us-east-1

---
on each WNXT Server, Builder
under /opt/
we have cwa.sh [cloud watch agent install, configure, status]
This is to send Memory, Disk Metrics to Cloudwatch

# ganz-wnxt

Autoscaling scripts for the **Ganz WNXT** deployment.

## Overview

The autoscaler monitors CPU, memory, and active-connection metrics across all running instances and automatically adds or removes instances to keep the deployment within the configured thresholds.

```
autoscaling/
├── config/
│   └── autoscaler.conf      # Thresholds, limits, provider settings
└── scripts/
    ├── autoscaler.sh        # Main orchestration loop
    ├── health_check.sh      # Liveness & readiness checks
    ├── metrics.sh           # Metric collection helpers
    ├── scale_up.sh          # Add instances
    ├── scale_down.sh        # Remove instances
    └── utils.sh             # Shared logging & state helpers
```

## Quick start

### 1. Configure

Copy the default config and edit the values to suit your environment:

```bash
cp autoscaling/config/autoscaler.conf /etc/ganz-wnxt/autoscaler.conf
$EDITOR /etc/ganz-wnxt/autoscaler.conf
```

Key settings:

| Variable | Default | Description |
|---|---|---|
| `PROVIDER` | `custom` | Instance provider: `aws`, `gcp`, `azure`, or `custom` |
| `MIN_INSTANCES` | `2` | Minimum number of running instances |
| `MAX_INSTANCES` | `20` | Maximum number of running instances |
| `CPU_SCALE_UP_THRESHOLD` | `75` | CPU % that triggers a scale-up |
| `CPU_SCALE_DOWN_THRESHOLD` | `30` | CPU % below which scale-down is considered |
| `METRICS_INTERVAL` | `30` | Seconds between evaluation passes |

### 2. Run

```bash
# Continuous loop (recommended for production)
CONFIG_FILE=/etc/ganz-wnxt/autoscaler.conf \
    ./autoscaling/scripts/autoscaler.sh

# Single evaluation pass (useful for cron or debugging)
CONFIG_FILE=/etc/ganz-wnxt/autoscaler.conf \
    ./autoscaling/scripts/autoscaler.sh --once
```

### 3. Manual scaling

```bash
# Add 3 instances immediately
./autoscaling/scripts/scale_up.sh --count 3

# Remove 2 instances immediately
./autoscaling/scripts/scale_down.sh --count 2
```

### 4. Health check

```bash
# Check all instances
./autoscaling/scripts/health_check.sh --all

# Check a specific host
./autoscaling/scripts/health_check.sh --instance 10.0.1.42
```

## Provider configuration

### AWS

```bash
PROVIDER=aws
AWS_REGION=us-east-1
AWS_AUTO_SCALING_GROUP=ganz-wnxt-asg
```

Requires the `aws` CLI and an IAM role / profile with `autoscaling:SetDesiredCapacity` and `ec2:DescribeInstances` permissions.

### GCP

```bash
PROVIDER=gcp
GCP_PROJECT=my-project
GCP_ZONE=us-central1-a
GCP_INSTANCE_GROUP=ganz-wnxt-mig
```

Requires the `gcloud` CLI and a service account with `compute.instanceGroupManagers.update` permission.

### Azure

```bash
PROVIDER=azure
AZURE_RESOURCE_GROUP=ganz-wnxt-rg
AZURE_VMSS_NAME=ganz-wnxt-vmss
```

Requires the `az` CLI and a service principal with `Contributor` access to the VMSS.

### Custom provider

```bash
PROVIDER=custom
CUSTOM_ADD_INSTANCE_SCRIPT=/opt/ganz-wnxt/add_instance.sh
CUSTOM_REMOVE_INSTANCE_SCRIPT=/opt/ganz-wnxt/remove_instance.sh
CUSTOM_LIST_INSTANCES_SCRIPT=/opt/ganz-wnxt/list_instances.sh
```

Each script receives the instance count as its first argument (for add/remove) or prints one host per line (for list).

## Notifications

Set `NOTIFY_WEBHOOK_URL` to a Slack or Microsoft Teams incoming webhook URL to receive alerts on every scaling event:

```bash
NOTIFY_ON_SCALE=true
NOTIFY_WEBHOOK_URL=https://hooks.slack.com/services/...
```

## Logging

Logs are written to `LOG_FILE` (default: `/var/log/ganz-wnxt/autoscaler/autoscaler.log`) and to stdout. Set `LOG_LEVEL=DEBUG` for verbose output.

## State

State (last scale times, current instance count) is stored in `STATE_DIR` (default: `/var/lib/ganz-wnxt/autoscaler/state`). The directory is created automatically on first run.

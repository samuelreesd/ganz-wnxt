#!/bin/bash
# ============================================================
# WNXT Prod - Step 06 - Hub Setup
# Run ON the production hub: 10.2.150.101
# ============================================================

echo "Creating hostslist..."
mkdir -p /srv/wnxt-on-aws/hub
touch /srv/wnxt-on-aws/hub/hostslist

echo "Copying scripts from integration hub..."
echo "NOTE: Copy these scripts from integration hub 10.2.170.101:"
echo "  /usr/local/bin/reconcile-multicast-ganz.sh"
echo "  /usr/local/bin/check-multicast-health.sh"
echo "  /srv/wnxt-on-aws/hub/manage-hostslist.sh"
echo ""
echo "Update HUB_IP to 10.2.150.101 in all scripts after copying"
echo ""
echo "Setting up crontab..."
cat << 'CRON'
# Add to crontab on prod hub (crontab -e):

# WNXT Hostslist cleanup - remove dead Auto Scaling instances every 5 minutes
*/5 * * * * /srv/wnxt-on-aws/hub/manage-hostslist.sh

# Rotate hostslist log weekly
0 0 * * 0 > /var/log/wnxt-hostslist-cleanup.log

# Triggered reconciliation when new instance starts
* * * * * [ -f /tmp/multicast-reconcile-needed ] && /usr/local/bin/reconcile-multicast-ganz.sh

# Scheduled reconciliation every 5 minutes - runs 30 seconds after hostslist cleanup
*/5 * * * * sleep 30 && /usr/local/bin/reconcile-multicast-ganz.sh

# Rotate reconcile log weekly
0 0 * * 0 > /var/log/multicast-reconcile.log
CRON

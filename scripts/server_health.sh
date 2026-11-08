#!/usr/bin/env bash

#server health monitoring
#Collects basic system diagnostics.

set -u

echo "===================="
echo "SERVER HEALTH REPORT"

echo "===================="

echo "Timestamp: $(date -Is)"
echo "Hostname: $(hostname)"
echo

#Sys uptime and load

echo "=== SYSTEM UPTIME ==="
uptime
echo

#mem usage
echo "=== MEMORY ==="
free -h 
echo

#Disk usage
echo "=== DISK ==="
df -h /
echo

# Service status
echo "=== SERVICES ==="

for service in docker nginx ssh; do
    if systemctl is-active --quiet "$service"; then
        echo "$service: ACTIVE"
    else
        echo "$service: INACTIVE"
    fi
done

echo

# Listening network ports
echo "=== LISTENING PORTS ==="
ss -ltn

echo
echo "=== END OF REPORT ==="
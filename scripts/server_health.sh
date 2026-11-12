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

# Sys uptime and load

echo "=== SYSTEM UPTIME ==="
uptime
echo

# Mem usage
echo "=== MEMORY ==="
free -h 
echo

# Disk usage
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





# Check versions of installed packages:
echo "=== CONTROLLING PACKAGE VERSIONS ==="

# Configuration
SECS_IN_A_DAY=$((24 * 60 * 60))
stamp="/var/log/last-apt-update"
# Current Unix timestamp
now_sec=$(date +%s)

# Check when APT was last updated
if [ -f "$stamp" ]; then
    last_sec=$(date -r "$stamp" +%s)
    seconds_since_update=$((now_sec - last_sec))
    days_since_update=$((seconds_since_update / SECS_IN_A_DAY))
    echo "Last APT update: $(date -Is -r "$stamp")"
    echo "Days since last update: $days_since_update"
else
    echo "No previous APT update recorded."
    seconds_since_update=$SECS_IN_A_DAY # Force trying to upate the list
fi

# Check if package lists are older than one day
if (( seconds_since_update >= SECS_IN_A_DAY )); then
    if [ "$EUID" -eq 0 ]; then
        echo "Root privilege detected: refreshing APT package lists..."
        if apt-get update -qq -o APT::Update::Error-Mode=any; then
            touch "$stamp"
            echo "APT package lists successfully refreshed!"
        else
            echo "WARNING: APT update failed!"
        fi
    else
        echo "WARNING: APT package lists may be outdated!"
        echo "Root privileges required to refresh them."
    fi
else
    echo "APT package lists are sufficiently recent."
fi
echo

echo "=== PACKAGE VERSIONS ==="
echo "Checking package versioning:"
for package in docker.io docker-compose-v2 nginx git curl certbot fail2ban tree htop micro; do # Ensure that this has the same ones as in setup script
    current=$(dpkg-query -W -f='${Version}' "$package" 2>/dev/null) || continue # Don't keep stderrors as we are just version checking
    latest=$(apt-cache policy "$package" | awk '/Candidate:/ {print $2}') # uses awk to find and extract the latest version 
    echo "$package: $current (Latest: $latest)"
        # IF latest is NOT empty AND latest version is GREATER THAN current, then 
    if [ "$latest" != "(none)" ] && dpkg --compare-versions "$latest" gt "$current"; then 
        echo "  --> UPDATE AVAILABLE!"
    fi
done
echo

# Check book-api status:
echo "=== SERVER STATUS ==="
if curl -fsS --max-time 5 http://127.0.0.1:80/status; then # Avoids returning weird messages
    echo "Book API: HEALTHY"
else
    echo "Book API: UNHEALTHY"
    echo "uvicorn status info:"
    
    curl -i http://127.0.0.1:8000/status
    echo "nginx status info:"
    curl -i http://127.0.0.1:80/status
fi

echo

# Listening network ports
echo "=== LISTENING PORTS ==="
ss -ltn

echo
echo "=== END OF REPORT ==="


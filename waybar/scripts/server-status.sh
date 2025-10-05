#!/bin/bash
# ~/.config/waybar/scripts/server-status.sh

SERVER_HOST="hetzner"
CACHE_FILE="/tmp/waybar_server_status"
CACHE_TIME=300  # 5 minutes

# Check if we should do a fresh check
DO_CHECK=false

if [[ ! -f "$CACHE_FILE" ]]; then
    DO_CHECK=true
elif [[ $(($(date +%s) - $(stat -c %Y "$CACHE_FILE"))) -gt $CACHE_TIME ]]; then
    DO_CHECK=true
fi

if [[ "$DO_CHECK" == "true" ]]; then
    # Try SSH connection
    if timeout 3 ssh -o ConnectTimeout=2 -o BatchMode=yes "$SERVER_HOST" "exit" 2>/dev/null; then
        # Get latency and server info
        START=$(date +%s%3N)
        SERVER_INFO=$(ssh -o ConnectTimeout=2 "$SERVER_HOST" "uptime | awk -F'load average: ' '{print \$2}' | awk '{print \$1}' | tr -d ',' && uptime -p" 2>/dev/null)
        END=$(date +%s%3N)
        LATENCY=$((END - START))
        
        LOAD=$(echo "$SERVER_INFO" | head -n1)
        UPTIME=$(echo "$SERVER_INFO" | tail -n1)
        
        if [[ -n "$LOAD" ]]; then
            echo "{\"text\": \"󰒋 ${LATENCY}ms | ${LOAD}\", \"tooltip\": \"Server: $SERVER_HOST\\nLatency: ${LATENCY}ms\\nLoad: ${LOAD}\\nUptime: ${UPTIME}\", \"class\": \"online\"}" | tee "$CACHE_FILE"
        else
            echo "{\"text\": \"󰒋 ${LATENCY}ms\", \"tooltip\": \"Server: $SERVER_HOST\\nLatency: ~${LATENCY}ms\", \"class\": \"online\"}" | tee "$CACHE_FILE"
        fi
    else
        echo "{\"text\": \"󰒎 Offline\", \"tooltip\": \"Server: $SERVER_HOST\\nStatus: SSH unreachable\", \"class\": \"offline\"}" | tee "$CACHE_FILE"
    fi
else
    # Return cached result
    cat "$CACHE_FILE"
fi

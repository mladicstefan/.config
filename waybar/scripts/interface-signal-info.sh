#!/bin/bash

# Find the primary default interface name
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)

if [ "$INTERFACE" == "" ]; then
    echo '{"text": "Offline", "class": "red", "tooltip": "No active network interface"}'
    exit 0
fi

# ----------------- Check for VPN -----------------
if [[ "$INTERFACE" == *"mullvad"* ]] || [[ "$INTERFACE" == "wg0" ]]; then
    CLASS="vpn-active"
    TEXT="$INTERFACE 100%"
    TOOLTIP="Connected via VPN: $INTERFACE"

# ----------------- Check for WiFi -----------------
elif [[ "$INTERFACE" == wlan* ]]; then
    CLASS="wifi-active"
    # Get signal strength in % using iw
    SIGNAL=$(iw dev "$INTERFACE" link 2>/dev/null | grep signal | awk '{print $2}' | cut -d'.' -f1)
    # Convert dBm to percentage (rough approximation for display)
    if [ -n "$SIGNAL" ]; then
        PERCENTAGE=$((2 * ($SIGNAL + 100)))
        if [ "$PERCENTAGE" -gt 100 ]; then PERCENTAGE=100; fi
        if [ "$PERCENTAGE" -lt 0 ]; then PERCENTAGE=0; fi
    else
        PERCENTAGE=0
    fi

    TEXT="$INTERFACE $PERCENTAGE%"
    TOOLTIP="Connected via Wi-Fi: $INTERFACE"

# ----------------- Check for Ethernet -----------------
elif [[ "$INTERFACE" == eth* ]]; then
    CLASS="ethernet-active"
    TEXT="$INTERFACE 100%"
    TOOLTIP="Connected via Ethernet: $INTERFACE"

# ----------------- Fallback -----------------
else
    CLASS="default-active"
    TEXT="$INTERFACE"
    TOOLTIP="Connected via $INTERFACE"
fi

echo "{\"text\": \"$TEXT\", \"class\": \"$CLASS\", \"tooltip\": \"$TOOLTIP\"}"

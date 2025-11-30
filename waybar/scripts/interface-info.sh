#!/bin/bash

# Find the primary default interface
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)

if [ "$INTERFACE" == "" ]; then
    echo '{"text": "Offline", "class": "red", "tooltip": "No active network interface"}'
    exit 0
fi

if [[ "$INTERFACE" == *"mullvad"* ]]; then
    CLASS="vpn-active" # Green
    TEXT="VPN: $INTERFACE"
    TOOLTIP="Connected via Mullvad VPN"
elif [[ "$INTERFACE" == "wg0" ]]; then
    CLASS="vpn-active" # Green
    TEXT="VPN: $INTERFACE"
    TOOLTIP="Connected via WireGuard (wg0)"
else
    CLASS="wifi-active" # Red/Default
    TEXT="WIFI: $INTERFACE"
    TOOLTIP="Connected via $INTERFACE"
fi

echo "{\"text\": \"$TEXT\", \"class\": \"$CLASS\", \"tooltip\": \"$TOOLTIP\"}"

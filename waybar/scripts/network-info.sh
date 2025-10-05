#!/bin/bash
# ~/.config/waybar/scripts/network-info.sh

# Get active interface
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

if [[ -z "$INTERFACE" ]]; then
    echo '{"text": "No connection", "class": "disconnected"}'
    exit 0
fi

# Get IP address
IP=$(ip -4 addr show "$INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

if [[ -z "$IP" ]]; then
    echo '{"text": "No IP", "class": "disconnected"}'
    exit 0
fi

# Output JSON
echo "{\"text\": \"$INTERFACE: $IP\", \"tooltip\": \"Interface: $INTERFACE\\nIP: $IP\", \"class\": \"connected\"}"

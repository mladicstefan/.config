#!/bin/bash
MULLVAD_STATUS=$(mullvad status 2>/dev/null)
CONNECTION_STATUS=$(echo "$MULLVAD_STATUS" | head -n 1)
GREEN_CLASS="vpn-active"
RED_CLASS="wifi-active"

trim() {
    echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

json_escape() {
    echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ' | sed 's/  */ /g'
}

if [[ "$CONNECTION_STATUS" == "Connected" ]]; then
    SERVER_LOCATION_RAW=$(echo "$MULLVAD_STATUS" | grep "Visible location:" | tail -n 1 | sed 's/Visible location: *//' | sed 's/ IPv4.*//')
    SERVER_LOCATION=$(trim "$SERVER_LOCATION_RAW")

    IPV6=$(echo "$MULLVAD_STATUS" | grep -oP 'IPv6:\s*\K[0-9a-fA-F:]+' | head -n 1)

    if [ -z "$IPV6" ]; then
        IPV6_DISPLAY="(IPv6 N/A)"
    else
        CLEAN_IPV6=$(echo "$IPV6" | tr -d ',.')
        IPV6_DISPLAY="($CLEAN_IPV6)"
    fi

    FULL_TEXT_RAW="${SERVER_LOCATION} ${IPV6_DISPLAY}"
    TEXT=$(trim "$FULL_TEXT_RAW")
    CLASS="$GREEN_CLASS"

    TOOLTIP=$(json_escape "Connected via Mullvad VPN - $MULLVAD_STATUS")
else
    INTERFACE=$(ip route | grep default | grep -v 'wg0' | awk '{print $5}' | head -n 1)

    if [ -z "$INTERFACE" ]; then
        TEXT="Offline"
        CLASS="offline"
        TOOLTIP="No connection."
    else
        PERCENTAGE="100%"
        CLASS="$RED_CLASS"

        if [[ "$INTERFACE" == wlan* ]]; then
            SIGNAL_DBM=$(iw dev "$INTERFACE" link 2>/dev/null | grep signal | awk '{print $2}' | cut -d'.' -f1)
            if [ -n "$SIGNAL_DBM" ]; then
                PERCENTAGE=$((2 * ($SIGNAL_DBM + 100)))
                if [ "$PERCENTAGE" -gt 100 ]; then PERCENTAGE=100; fi
                if [ "$PERCENTAGE" -lt 0 ]; then PERCENTAGE=0; fi
                PERCENTAGE="${PERCENTAGE}%"
            else
                PERCENTAGE="N/A"
            fi
        fi

        TEXT="$INTERFACE $PERCENTAGE"
        TOOLTIP="Default interface: $INTERFACE"
    fi
fi

echo "{\"text\": \"$TEXT\", \"class\": \"$CLASS\", \"tooltip\": \"$TOOLTIP\"}"

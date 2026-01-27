#!/usr/bin/env bash
set -euo pipefail

readonly GREEN_CLASS="vpn-active"
readonly RED_CLASS="wifi-active"

trim() {
    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/ }"
    str="${str//  / }"
    printf '%s' "$str"
}

get_wifi_info() {
    local interface="$1"
    local signal_dbm ssid percentage signal_display

    signal_dbm=$(iw dev "$interface" link 2>/dev/null | grep -i signal | awk '{print $2}' | cut -d'.' -f1) || true
    ssid=$(iw dev "$interface" link 2>/dev/null | grep -i ssid | awk '{print $2}') || true

    if [[ -n "${signal_dbm:-}" ]]; then
        percentage=$((2 * (signal_dbm + 100)))
        ((percentage > 100)) && percentage=100
        ((percentage < 0)) && percentage=0
        signal_display="${percentage}%"
    else
        signal_display="N/A"
    fi

    printf '%s|%s' "${ssid:-Unknown}" "$signal_display"
}

main() {
    local mullvad_status connection_status
    local text class tooltip
    local server_location ipv6 ipv6_display
    local interface wifi_info ssid signal

    mullvad_status=$(mullvad status 2>/dev/null) || mullvad_status=""
    connection_status=$(printf '%s' "$mullvad_status" | head -n 1)

    if [[ "$connection_status" == "Connected" ]]; then
        server_location=$(printf '%s' "$mullvad_status" | grep "Visible location:" | tail -n 1 | sed 's/Visible location: *//' | sed 's/ IPv4.*//')
        server_location=$(trim "$server_location")

        ipv6=$(printf '%s' "$mullvad_status" | grep -oP 'IPv6:\s*\K[0-9a-fA-F:]+' | head -n 1) || true

        if [[ -z "${ipv6:-}" ]]; then
            ipv6_display="(IPv6 N/A)"
        else
            ipv6_display="(${ipv6//[,.]/})"
        fi

        text="󰦝"
        class="$GREEN_CLASS"
        tooltip=$(json_escape "Mullvad VPN Connected\n${server_location} ${ipv6_display}")
    else
        interface=$(ip route 2>/dev/null | grep default | grep -v 'wg0' | awk '{print $5}' | head -n 1) || true

        if [[ -z "${interface:-}" ]]; then
            text="󰤮"
            class="offline"
            tooltip="Offline"
        else
            class="$RED_CLASS"

            if [[ "$interface" == wlan* ]] || [[ "$interface" == wlp* ]]; then
                wifi_info=$(get_wifi_info "$interface")
                ssid="${wifi_info%%|*}"
                signal="${wifi_info##*|}"

                text="󰤥"
                tooltip=$(json_escape "⚠ NO VPN\n${ssid} (${signal})")
            else
                text="󰈀"
                tooltip=$(json_escape "⚠ NO VPN\n${interface}")
            fi
        fi
    fi

    printf '{"text": "%s", "class": "%s", "tooltip": "%s"}\n' "$text" "$class" "$tooltip"
}

main "$@"

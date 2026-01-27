#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_NAME="${0##*/}"

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME <wallpaper_path>

Set wallpaper using swww with smooth transition.

Arguments:
    wallpaper_path    Path to the wallpaper image file

Options:
    -h, --help        Show this help message

Example:
    $SCRIPT_NAME ~/Pictures/wallpaper.jpg
EOF
}

log_info() {
    printf '[INFO] %s\n' "$1" >&2
}

log_error() {
    printf '[ERROR] %s\n' "$1" >&2
}

check_dependencies() {
    local missing=()

    command -v swww &>/dev/null || missing+=("swww")

    if ((${#missing[@]} > 0)); then
        log_error "Missing dependencies: ${missing[*]}"
        exit 1
    fi
}

validate_wallpaper() {
    local wallpaper="$1"

    if [[ ! -f "$wallpaper" ]]; then
        log_error "File not found: $wallpaper"
        exit 1
    fi

    if [[ ! -r "$wallpaper" ]]; then
        log_error "File not readable: $wallpaper"
        exit 1
    fi
}

set_wallpaper() {
    local wallpaper="$1"

    if ! pgrep -x swww-daemon &>/dev/null; then
        log_info "Starting swww daemon..."
        swww-daemon &
        sleep 1
    fi

    log_info "Setting wallpaper: $wallpaper"
    swww img "$wallpaper" \
        --transition-type wipe \
        --transition-fps 60 \
        --transition-duration 1 \
        --transition-angle 30

    log_info "Wallpaper set successfully"
}

main() {
    if (($# == 0)) || [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
        usage
        exit 0
    fi

    local wallpaper="$1"

    check_dependencies
    validate_wallpaper "$wallpaper"
    set_wallpaper "$wallpaper"
}

main "$@"

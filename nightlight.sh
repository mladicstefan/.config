#!/bin/bash
pkill gammastep
if [ "$1" = "start" ]; then
    nohup gammastep -c ~/.config/gammastep.conf >/dev/null 2>&1 & disown
fi

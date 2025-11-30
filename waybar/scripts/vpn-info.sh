#!/bin/bash
if ip a | grep -q 'wg0'; then
    echo 'Active'
else
    echo 'Off'
fi

#!/bin/bash
# ~/.config/waybar/scripts/extract-colors.sh

WALLPAPER=$(swww query | grep -oP 'image: \K.*')

# Extract dominant colors using imagemagick
magick "$WALLPAPER" -resize 100x100 -colors 5 -unique-colors txt:- | \
  grep -oP '#[0-9A-Fa-f]{6}' | head -5 > /tmp/waybar-colors

# Generate waybar.css with extracted colors
COLOR1=$(sed -n '1p' /tmp/waybar-colors)
COLOR2=$(sed -n '2p' /tmp/waybar-colors)
COLOR3=$(sed -n '3p' /tmp/waybar-colors)

cat > ~/.config/waybar/waybar.css << EOF
@define-color bg $COLOR1;
@define-color fg $COLOR2;
@define-color accent $COLOR3;
EOF

# Reload waybar
pkill -SIGUSR2 waybar

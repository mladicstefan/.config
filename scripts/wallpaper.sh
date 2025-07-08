#!/bin/bash

# Path to your wallpapers folder
WALLPAPER_DIR="$HOME/wallpapers/"

# Cache file to track current wallpaper index
INDEX_FILE="$HOME/.cache/current_wallpaper_index"

# Get sorted list of .jpg files
mapfile -t WALLPAPERS < <(find "$WALLPAPER_DIR" -type f -iname '*.jpg' | sort)

# Ensure there are wallpapers
TOTAL=${#WALLPAPERS[@]}
if (( TOTAL == 0 )); then
    echo "No JPG files found in $WALLPAPER_DIR"
    exit 1
fi

# Load current index or default to 0
if [[ -f "$INDEX_FILE" ]]; then
    INDEX=$(<"$INDEX_FILE")
else
    INDEX=0
fi

# Sanitize index
if ! [[ "$INDEX" =~ ^[0-9]+$ ]]; then
    INDEX=0
fi

# Get the next index and wallpaper
NEXT_INDEX=$(( (INDEX + 1) % TOTAL ))
NEXT_WALLPAPER="${WALLPAPERS[$NEXT_INDEX]}"

# Set wallpaper
swww img "$NEXT_WALLPAPER" --transition-type grow --transition-fps 60 --transition-duration 1

# Save next index
echo "$NEXT_INDEX" > "$INDEX_FILE"


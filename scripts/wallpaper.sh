#!/bin/bash
WALLPAPER_DIR="$HOME/.config/wallpapers/"
THUMB_DIR="$HOME/.cache/wallpaper_thumbs/"
WOFI_CONFIG="$HOME/.config/wofi/config"

mkdir -p "$THUMB_DIR"
mkdir -p "$(dirname "$WOFI_CONFIG")"

if [[ ! -f "$WOFI_CONFIG" ]] || ! grep -q "allow_images" "$WOFI_CONFIG"; then
    echo "allow_images=true" >> "$WOFI_CONFIG"
    echo "allow_markup=true" >> "$WOFI_CONFIG"
fi

mapfile -t WALLPAPERS < <(find "$WALLPAPER_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' \) | sort)

TOTAL=${#WALLPAPERS[@]}
if (( TOTAL == 0 )); then
    echo "No image files found in $WALLPAPER_DIR"
    exit 1
fi

for wallpaper in "${WALLPAPERS[@]}"; do
    filename=$(basename "$wallpaper")
    thumb_path="$THUMB_DIR/${filename%.*}_thumb.jpg"
    
    if [[ ! -f "$thumb_path" ]] || [[ "$wallpaper" -nt "$thumb_path" ]]; then
        convert "$wallpaper" -resize 150x150^ -gravity center -extent 150x150 "$thumb_path" 2>/dev/null
    fi
done

DISPLAY_SCRIPT="$THUMB_DIR/display_thumb.sh"
cat > "$DISPLAY_SCRIPT" << 'EOF'
#!/bin/bash
filename="$1"
thumb_dir="$HOME/.cache/wallpaper_thumbs/"
thumb_name="${filename%.*}_thumb.jpg"
thumb_path="$thumb_dir$thumb_name"

if [[ -f "$thumb_path" ]]; then
    echo "img:$thumb_path:text:$filename"
else
    echo "$filename"
fi
EOF
chmod +x "$DISPLAY_SCRIPT"

WALLPAPER_LIST=""
for wallpaper in "${WALLPAPERS[@]}"; do
    filename=$(basename "$wallpaper")
    WALLPAPER_LIST+="$filename"$'\n'
done

CHOICE=$(echo "$WALLPAPER_LIST" | wofi --dmenu --prompt "Wallpaper" --insensitive --pre-display-cmd "$DISPLAY_SCRIPT %s")

if [[ -z "$CHOICE" ]]; then
    exit 0
fi

FULL_PATH=""
for wallpaper in "${WALLPAPERS[@]}"; do
    if [[ "$(basename "$wallpaper")" == "$CHOICE" ]]; then
        FULL_PATH="$wallpaper"
        break
    fi
done

if [[ -n "$FULL_PATH" ]]; then
    swww img "$FULL_PATH" --transition-type grow --transition-fps 60 --transition-duration 0.3
    ~/.config/waybar/scripts/extract-colors.sh "$FULL_PATH" &
else
    echo "Error: Could not find wallpaper file for '$CHOICE'"
    exit 1
fi

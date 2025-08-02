#!/bin/bash
set -e  # Exit on any error

echo "=== Arch Linux Package Installation Script ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
   echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
   echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
   echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
  error "This script should not be run as root"
  exit 1
fi

# Update system first
log "Updating system packages..."
sudo pacman -Syu --noconfirm

# Install Rust first
if ! command -v rustc &> /dev/null; then
   log "Installing Rust via rustup..."
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
   source ~/.cargo/env
else
   log "Rust already installed"
fi

# Install yay (AUR helper) - manual installation since it's not in official repos
if ! command -v yay &> /dev/null; then
   log "Installing yay..."
   cd /tmp
   git clone https://aur.archlinux.org/yay.git
   cd yay
   makepkg -si --noconfirm
   cd ~
else
   log "yay already installed"
fi

# All packages from list 
PACKAGES=(
   "adobe-source-code-pro-fonts"
   "adobe-source-sans-fonts"
   "adobe-source-serif-fonts"
   "apparmor"
   "base"
   "base-devel"
   "bob"
   "brightnessctl"
   "btop"
   "cliphist"
   "discord"
   "docker"
   "dunst"
   "efibootmgr"
   "fastfetch"
   "firefox"
   "gammastep"
   "git"
   "gst-plugin-pipewire"
   "hyprland"
   "hyprpicker"
   "hyprpolkitagent"
   "hyprshot"
   "intel-ucode"
   "iwd"
   "kitty"
   "linux"
   "linux-firmware"
   "linux-headers"
   "ly"
   "man-db"
   "man-pages"
   "mesa-utils"
   "neovim"
   "network-manager-applet"
   "noto-fonts"
   "noto-fonts-cjk"
   "noto-fonts-emoji"
   "npm"
   "nwg-look"
   "obs-studio"
   "obsidian"
   "openssh"
   "pavucontrol"
   "pipewire-alsa"
   "pipewire-pulse"
   "qt5-wayland"
   "qt6-wayland"
   "ripgrep"
   "rofi"
   "sassc"
   "sbctl"
   "signal-desktop"
   "sof-firmware"
   "spotify-launcher"
   "swww"
   "systemd-resolvconf"
   "timeshift"
   "tlp"
   "ttf-dejavu"
   "ttf-firacode-nerd"
   "ttf-font-awesome"
   "ttf-jetbrains-mono"
   "ttf-jetbrains-mono-nerd"
   "ttf-liberation"
   "typst"
   "ufw"
   "unzip"
   "v4l2loopback-dkms"
   "virtualbox"
   "virtualbox-host-modules-arch"
   "waybar"
   "wireguard-tools"
   "xdg-desktop-portal-hyprland"
   "xdg-desktop-portal-kde"
   "xdg-desktop-portal-wlr"
   "zed"
   "zram-generator"
   "zsh"
)

# Install all packages via pacman
log "Installing all packages via pacman..."
sudo pacman -S --needed --noconfirm "${PACKAGES[@]}"

# Copy configuration files
log "=== Copying Configuration Files ==="
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p ~/.config

log "Copying config files from $SCRIPT_DIR to ~/.config..."

# Create backup of existing config if it exists
if [ -d ~/.config ] && [ "$(ls -A ~/.config 2>/dev/null)" ]; then
    warn "Backing up existing ~/.config to ~/.config.backup.$(date +%Y%m%d_%H%M%S)"
    cp -r ~/.config ~/.config.backup.$(date +%Y%m%d_%H%M%S)
fi

# Copy all directories and files except script files
for item in "$SCRIPT_DIR"/*; do
    if [ -f "$item" ] && [[ "$(basename "$item")" == *.sh ]]; then
        log "Skipping $(basename "$item") (script file)"
        continue
    fi
    
    if [ -e "$item" ]; then
        ITEM_NAME="$(basename "$item")"
        
        # Remove existing directory/file if it exists to avoid conflicts
        if [ -e ~/.config/"$ITEM_NAME" ]; then
            warn "Removing existing ~/.config/$ITEM_NAME to avoid conflicts"
            rm -rf ~/.config/"$ITEM_NAME"
        fi
        
        log "Copying $ITEM_NAME..."
        cp -r "$item" ~/.config/
    fi
done

# Set proper permissions
chmod -R 755 ~/.config/
log "Configuration files copied successfully!"

# Post-installation security & system setup
log "=== Starting Post-Installation Security Setup ==="

# 2. Firewall setup
log "Configuring UFW firewall..."
sudo ufw --force enable
sudo ufw default allow outgoing
sudo ufw default deny incoming
sudo ufw allow ssh
log "UFW status:"
sudo ufw status verbose

# 3. SSH hardening
log "Hardening SSH configuration..."
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
echo "UsePAM no" | sudo tee -a /etc/ssh/sshd_config

# Generate SSH key if it doesn't exist
if [ ! -f ~/.ssh/id_ed25519 ]; then
   log "Generating SSH key..."
   ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)" -N "" -f ~/.ssh/id_ed25519
fi

sudo systemctl restart sshd
sudo systemctl enable sshd

# 4. CPU Microcode (detect and install)
log "Installing CPU microcode..."
CPU_VENDOR=$(lscpu | grep "Vendor ID" | awk '{print $3}')
if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
   sudo pacman -S --noconfirm intel-ucode
   warn "Intel microcode installed. You may need to regenerate initramfs."
elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
   sudo pacman -S --noconfirm amd-ucode
   warn "AMD microcode installed. You may need to regenerate initramfs."
fi

# 5. Check vulnerabilities
log "Checking CPU vulnerabilities..."
grep -r . /sys/devices/system/cpu/vulnerabilities/ || true

# Backup and update information
log "For system backups and updates, use the ./system_update.sh script"

# 8. Nvidia drivers (if Nvidia GPU detected)
if lspci | grep -i nvidia > /dev/null; then
   log "Nvidia GPU detected, installing drivers..."
   sudo pacman -S --noconfirm nvidia nvidia-utils
fi

# 9. Change shell to zsh
log "Setting up zsh shell..."
ZSH_PATH=$(which zsh)
sudo chsh -s "$ZSH_PATH" "$USER"
warn "Shell changed to zsh. Log out and back in for changes to take effect."

# 10. Waybar configuration
log "Setting up Waybar configuration..."
if [ -d /etc/xdg/waybar/ ]; then
   mkdir -p ~/.config/waybar
   cp -r /etc/xdg/waybar/* ~/.config/waybar/
fi

# 12. AppArmor setup
log "Configuring AppArmor..."
sudo systemctl enable apparmor.service

# Check if using systemd-boot
if [ -d /boot/loader/entries/ ]; then
   log "Systemd-boot detected. Adding AppArmor kernel parameters..."
   
   # Find the main boot entry (not fallback)
   BOOT_ENTRY=$(ls /boot/loader/entries/ | grep -v fallback | head -1)
   
   if [ -n "$BOOT_ENTRY" ]; then
       sudo cp "/boot/loader/entries/$BOOT_ENTRY" "/boot/loader/entries/$BOOT_ENTRY.backup"
       
       # Add AppArmor parameters if not already present
       if ! grep -q "apparmor=1" "/boot/loader/entries/$BOOT_ENTRY"; then
           sudo sed -i '/^options/ s/$/ lsm=landlock,lockdown,yama,apparmor,bpf apparmor=1 security=apparmor/' "/boot/loader/entries/$BOOT_ENTRY"
           log "AppArmor kernel parameters added to $BOOT_ENTRY"
       fi
   fi
fi

# 14. Final touches - themes
log "Installing additional themes and fonts..."
cd /tmp
if [ ! -d "Graphite-gtk-theme" ]; then
   git clone https://github.com/vinceliuice/Graphite-gtk-theme.git --depth=1
fi
cd Graphite-gtk-theme
./install.sh --tweaks rimless normal
cd ~

# Enable essential services
log "Enabling essential services..."
sudo systemctl enable docker.service
sudo systemctl enable tlp.service
sudo systemctl enable ly.service  # Display manager

# Add user to important groups
sudo usermod -aG docker "$USER"

# Final system information
log "=== Setup Complete ==="
log "System information:"
echo "CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
echo "Kernel: $(uname -r)"
echo "Services enabled: docker, tlp, ufw, sshd, apparmor, ly"
echo ""
warn "IMPORTANT: Reboot required for all changes to take effect!"
warn "After reboot, run: aa-enabled && sudo aa-status to verify AppArmor"
warn "Consider setting up Secure Boot manually if needed"
warn "SSH key generated at ~/.ssh/id_ed25519.pub - copy to servers for passwordless login"

echo -e "\n${GREEN}Installation and security hardening complete!${NC}"
echo -e "${YELLOW}Reboot recommended.${NC}"

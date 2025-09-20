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
    "adobe-source-code-pro-fonts 2.042u+1.062i+1.026vf-2"
    "adobe-source-sans-fonts 3.052-2"
    "adobe-source-serif-fonts 4.005-2"
    "apparmor 4.1.2-1"
    "base 3-2"
    "base-devel 1-2"
    "bear 3.1.6-5"
    "binwalk 3.1.0-1"
    "bluetui 0.6-1"
    "bluez 5.83-1"
    "bluez-utils 5.83-1"
    "bob 4.1.2-1"
    "brave-bin 1:1.82.166-1"
    "brightnessctl 0.5.1-3"
    "btop 1.4.4-1"
    "clang 20.1.8-1"
    "cliphist 1:0.6.1-1"
    "docker 1:28.4.0-1"
    "dunst 1.13.0-1"
    "efibootmgr 18-3"
    "ethtool 1:6.15-1"
    "fastfetch 2.52.0-1"
    "firefox 142.0.1-1"
    "fwupd 2.0.16-1"
    "gammastep 2.0.11-1"
    "gdb 16.3-1"
    "git 2.51.0-1"
    "gopls 0.20.0-3"
    "gst-plugin-pipewire 1:1.4.8-1"
    "hypridle 0.1.7-1"
    "hyprland 0.51.0-2"
    "hyprlock 0.9.1-1"
    "hyprpicker 0.4.5-4"
    "hyprpolkitagent 0.1.3-1"
    "hyprshot 1.3.0-4"
    "intel-ucode 20250812-1"
    "iwd 3.9-1"
    "kitty 0.42.2-1"
    "linux 6.16.7.arch1-1"
    "linux-firmware 20250808-1"
    "linux-headers 6.16.7.arch1-1"
    "lua-language-server 3.15.0-1"
    "luarocks 3.12.2-1"
    "ly 1.1.2-1"
    "man-db 2.13.1-1"
    "man-pages 6.15-1"
    "mariadb 12.0.2-1"
    "mesa-utils 9.0.0-7"
    "mingw-w64-gcc 15.2.0-1"
    "mtpfs 1.1-5"
    "mullvad-vpn 2025.7-1"
    "musl-git 1.2.5.r100.g0b86d60b-1"
    "neovim 0.11.4-1"
    "network-manager-applet 1.36.0-1"
    "nmap 7.97-1"
    "noto-fonts 1:2025.09.01-1"
    "noto-fonts-cjk 20240730-1"
    "noto-fonts-emoji 1:2.051-1"
    "npm 11.6.0-1"
    "nwg-look 1.0.6-1"
    "obs-studio 31.1.2-1"
    "openssh 10.0p1-4"
    "pavucontrol 1:6.1-1"
    "php 8.4.12-1"
    "pipewire-alsa 1:1.4.8-1"
    "pipewire-pulse 1:1.4.8-1"
    "python-pip 25.2-1"
    "python-pipx 1.7.1-2"
    "qt5-wayland 5.15.17+kde+r57-1"
    "qt6-wayland 6.9.2-1"
    "ripgrep 14.1.1-1"
    "rofi 2.0.0-1"
    "rust-analyzer 20250825-1"
    "sassc 3.6.2-5"
    "sbctl 0.17-1"
    "signal-desktop 7.70.0-1"
    "sof-firmware 2025.05.1-1"
    "spotify-launcher 0.6.3-2"
    "strace 6.16-1"
    "swww 0.10.3-1"
    "systemd-resolvconf 257.9-1"
    "tcpdump 4.99.5-1"
    "thunar 4.20.5-1"
    "timeshift 25.07.7-1"
    "tlp 1.8.0-1"
    "torbrowser-launcher 0.3.7-3"
    "traceroute 2.1.6-1"
    "ttf-dejavu 2.37+18+g9b5d1b2f-7"
    "ttf-firacode-nerd 3.4.0-1"
    "ttf-jetbrains-mono 2.304-2"
    "ttf-jetbrains-mono-nerd 3.4.0-1"
    "ttf-liberation 2.1.5-2"
    "typst 1:0.13.1-1"
    "ufw 0.36.2-5"
    "unzip 6.0-23"
    "v4l2loopback-dkms 0.15.1-1"
    "valgrind 3.25.1-3"
    "virtualbox 7.2.2-1"
    "virtualbox-host-modules-arch 7.2.2-2"
    "wabt 1.0.37-1"
    "wasm-pack 0.13.1-1"
    "waybar 0.14.0-1"
    "wget 1.25.0-2"
    "wireguard-tools 1.0.20250521-1"
    "wireshark-qt 4.4.9-1"
    "woff2-font-awesome 7.0.1-1"
    "xdg-desktop-portal-gtk 1.15.3-1"
    "xdg-desktop-portal-hyprland 1.3.10-1"
    "xdg-desktop-portal-wlr 0.7.1-1"
    "xwaylandvideobridge-git 0.4.0_r257.gb7d6dd1-1"
    "yay 12.5.0-1"
    "yay-debug 12.5.0-1"
    "zed 0.203.5-1"
    "zram-generator 1.2.1-1"
    "zsh 5.9-5"
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

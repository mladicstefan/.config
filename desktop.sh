#!/usr/bin/env bash
set -e

if [ "$EUID" -eq 0 ]; then
    echo "Run as regular user with sudo."
    exit 1
fi

sudo pacman -S --noconfirm pacman-contrib
curl -s "https://archlinux.org/mirrorlist/?country=all&protocol=https&ip_version=4" | sed 's/^#Server/Server/' | rankmirrors -n 5 - | sudo tee /etc/pacman.d/mirrorlist
sudo pacman -Syy

KERNEL_TYPE=$(uname -r | sed 's/[0-9.-]*//')
if [[ "$KERNEL_TYPE" == *"lts"* ]]; then
    HEADERS="linux-lts-headers"
elif [[ "$KERNEL_TYPE" == *"zen"* ]]; then
    HEADERS="linux-zen-headers"
else
    HEADERS="linux-headers"
fi

sudo pacman -S --noconfirm --needed base-devel git btrfs-progs "$HEADERS"

if ! command -v yay &>/dev/null; then
    BUILD_DIR=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$BUILD_DIR"
    cd "$BUILD_DIR"
    makepkg -si --noconfirm
    cd -
    rm -rf "$BUILD_DIR"
fi

sudo pacman -S --noconfirm --needed \
    nvidia-dkms \
    nvidia-utils \
    nvidia-settings \
    opencl-nvidia \
    cuda \
    gdm \
    gnome-shell \
    gnome-control-center \
    gnome-console \
    nautilus \
    gnome-backgrounds \
    xdg-user-dirs-gtk \
    rust \
    python \
    neovim \
    qemu-desktop \
    virt-manager \
    libvirt \
    dnsmasq \
    iptables-nft \
    dmidecode \
    zsh \
    zsh-completions

if ! grep -q "nvidia_drm" /etc/mkinitcpio.conf; then
    sudo sed -i 's/^MODULES=(/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm /' /etc/mkinitcpio.conf
fi

echo "options nvidia_drm modeset=1 fbdev=1" | sudo tee /etc/modprobe.d/nvidia.conf

sudo systemctl enable gdm.service
sudo systemctl enable libvirtd.service
sudo usermod -aG libvirt "$USER"

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi
sudo chsh -s /usr/bin/zsh "$USER"

sudo mkinitcpio -P

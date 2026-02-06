#!/usr/bin/env bash
set -e

if [ "$EUID" -eq 0 ]; then
    echo "Run this script as a regular user with sudo privileges, not root."
    exit 1
fi

sudo pacman -Syu --noconfirm --needed base-devel git

if ! command -v yay &>/dev/null; then
    BUILD_DIR=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$BUILD_DIR"
    cd "$BUILD_DIR"
    makepkg -si --noconfirm
    cd -
    rm -rf "$BUILD_DIR"
fi

sudo pacman -S --noconfirm --needed \
    gnome \
    gdm \
    nvidia \
    nvidia-utils \
    nvidia-settings \
    cuda \
    opencl-nvidia \
    rust \
    python \
    neovim \
    qemu-desktop \
    virt-manager \
    libvirt \
    dnsmasq \
    iptables-nft \
    dmidecode \
    zsh

sudo systemctl enable gdm.service
sudo systemctl enable libvirtd.service
sudo usermod -aG libvirt "$USER"

echo "options nvidia_drm modeset=1 fbdev=1" | sudo tee /etc/modprobe.d/nvidia.conf

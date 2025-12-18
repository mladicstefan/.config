
## Features

- **LUKS encryption** setup in prerequisites
- **Users and groups** management
- **UFW firewall** configuration
- **OpenSSH and SSH keys** for secure access
- **Microcode** installation guide
- **Security** best practices
- **System backup** strategies
- **AppArmor** mandatory access control
- **Secure Boot** implementation (optional)
- **Automated installation** scripts
- **Safe system updates** with backup protection
- **Hyprland** Wayland compositor setup
- **Complete dotfiles** and configuration management

---

## Prerequisites

- Fresh Arch Linux installation with LUKS encryption
- Follow the [Arch Installation Guide](https://wiki.archlinux.org/title/Installation_guide) or use `archinstall`
- Refer to [LUKS encryption setup](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system)

##  Quick Start

### Option 1: Automated Installation
For quick deployment:
```bash
sudo sh fresh_install.sh
```

### Option 2: Manual Setup
Follow the step-by-step guide below for learning and customization.

---

## 📖 Manual Setup Guide

### 1. Basic Setup
**References:** [Users and groups](https://wiki.archlinux.org/title/Users_and_groups)
```bash
groups $(whoami)  # Check user groups
sudo pacman -S man-pages man-db btop
```

### 2. Firewall Configuration
**References:** [Uncomplicated Firewall](https://wiki.archlinux.org/title/Uncomplicated_Firewall)
```bash
sudo pacman -S ufw
sudo ufw enable
sudo ufw default allow outgoing
sudo ufw default deny incoming
sudo ufw allow ssh
sudo ufw status verbose  # Verify configuration
```

### 3. SSH Hardening
**References:** [OpenSSH](https://wiki.archlinux.org/title/OpenSSH), [SSH keys](https://wiki.archlinux.org/title/SSH_keys)
```bash
sudo pacman -S openssh
sudo nvim /etc/ssh/sshd_config
```

Add these configurations:
```
UsePAM no
PermitRootLogin prohibit-password
PasswordAuthentication no
```

Generate SSH key:
```bash
ssh-keygen -t ed25519 -C "your-description"
sudo systemctl restart sshd
```

### 4. CPU Microcode
**References:** [Microcode](https://wiki.archlinux.org/title/Microcode)

Install appropriate microcode for your processor:
```bash
# For AMD processors
sudo pacman -S amd-ucode

# For Intel processors  
sudo pacman -S intel-ucode
```

### 5. Security Audit
**References:** [Security](https://wiki.archlinux.org/title/Security)

Check system vulnerabilities:
```bash
grep -r . /sys/devices/system/cpu/vulnerabilities/
```

### 6. Backup System
**References:** [System backup](https://wiki.archlinux.org/title/System_backup)
```bash
sudo pacman -S timeshift
sudo timeshift --create --comments "post security setup"
```

### 7. AUR Helper
**References:** [Arch User Repository](https://wiki.archlinux.org/title/Arch_User_Repository), [AUR helpers](https://wiki.archlinux.org/title/AUR_helpers)
```bash
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
```

### 8. Graphics Drivers
**References:** [NVIDIA](https://wiki.archlinux.org/title/NVIDIA)

For NVIDIA users:
```bash
sudo pacman -S nvidia nvidia-utils
```

### 9. Desktop Environment
**References:** [Hyprland](https://wiki.archlinux.org/title/Hyprland), [Wayland](https://wiki.archlinux.org/title/Wayland)
```bash
sudo pacman -S kitty ly hyprland zsh xdg-desktop-portal-hyprland dunst hyprpolkitagent qt5-wayland qt6-wayland
```

### 10. Shell Configuration
**References:** [Zsh](https://wiki.archlinux.org/title/Zsh), [Command-line shell](https://wiki.archlinux.org/title/Command-line_shell)
```bash
sudo pacman -S zsh
chsh -s $(which zsh)
```

### 11. Status Bar
**References:** [Waybar](https://wiki.archlinux.org/title/Waybar)
```bash
sudo pacman -S waybar
cp -r /etc/xdg/waybar/ ~/.config/
```

### 12. Application Launcher
**References:** [Application launcher](https://wiki.archlinux.org/title/List_of_applications/Other#Application_launchers)
```bash
sudo pacman -S rofi
```

### 13. AppArmor Security
**References:** [AppArmor](https://wiki.archlinux.org/title/AppArmor)
```bash
sudo pacman -S apparmor
sudo timeshift --create --comments "pre-apparmor setup"
```

Edit boot entry (usually in `/boot/loader/entries/`):
```
options ... lsm=landlock,lockdown,yama,apparmor,bpf apparmor=1 security=apparmor
```

Enable and verify:
```bash
sudo systemctl enable apparmor.service
# After reboot:
aa-enabled  # Should return "Yes"
sudo aa-status
```

### 14. Final Touches
**References:** [Font configuration](https://wiki.archlinux.org/title/Font_configuration), [GTK](https://wiki.archlinux.org/title/GTK)
```bash
# Audio and theme management
sudo pacman -S pavucontrol nwg-look

# Additional fonts
sudo pacman -S ttf-font-awesome ttf-jetbrains-mono-nerd

# GTK themes
git clone https://github.com/vinceliuice/Graphite-gtk-theme.git --depth=1
cd Graphite-gtk-theme
./install.sh
nwg-look  # Configure themes
```

---

## Secure Boot (Optional but Recommended)

**References:** [Unified Extensible Firmware Interface/Secure Boot](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot)

> **Warning**: Only proceed if you understand the implications. Dual-boot setups require special consideration.

1. **Reset Secure Boot keys in BIOS**
2. **Create and enroll keys:**
   ```bash
   sudo sbctl setup
   sudo sbctl create-keys
   sudo sbctl enroll-keys -m
   ```

3. **Sign bootloader:**
   ```bash
   sudo sbctl sign -s -o /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed /usr/lib/systemd/boot/efi/systemd-bootx64.efi
   ```

4. **Sign kernel:**
   ```bash
   sudo sbctl sign -s /boot/vmlinuz-linux
   ```

5. **Reinstall bootloader and verify:**
   ```bash
   bootctl install
   sudo sbctl verify
   ```

6. **Enable Secure Boot in BIOS**

---

## System Maintenance

**References:** [System maintenance](https://wiki.archlinux.org/title/System_maintenance), [Pacman](https://wiki.archlinux.org/title/Pacman)

### Important: Safe System Updates

**Never run `sudo pacman -Syu` directly** - this can potentially break your system!

Instead, use the provided update script that creates automatic backups:

```bash
./system_update.sh
```

**What this script does:**
- Creates a timestamped Timeshift backup before updates
- Only proceeds with updates if backup succeeds
- Shows available updates before applying
- Provides rollback instructions if issues occur
- Optional package cache cleanup

### Manual Backup Creation
```bash
sudo timeshift --create --comments "manual backup - $(date)"
```

### System Restoration
If something goes wrong after an update:
```bash
sudo timeshift --list                    # List available snapshots
sudo timeshift --restore --snapshot SNAPSHOT_NAME
```

<div align="center">

**Stay secure, stay updated! 🔐**

</div>

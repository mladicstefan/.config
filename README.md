

Archlinux secure & lightweight Setup guide.
## 0. Install
use archinstall or do it manually just make sure you setup luks encrypt.
[Arch wiki guide](https://wiki.archlinux.org/title/Installation_guide])
# POST INSTALL
## OPTION 1:
This is for repetitive
sudo sh fresh_install.sh

## OPTION 2:
for learning and seeing the exact config
## 1. group policies and little things
~~~
groups (user) #check if you're superuser
sudo pacman -S man-pages man-db
sudo pacman -S btop
~~~

## 2. firewall
~~~
sudo pacman -S ufw
sudo ufw enable
sudo ufw default allow outgoing
sudo ufw default deny incoming
ufw allow ssh
ufw status verbose #check status
~~~
## 3.  ssh
prevent root ssh, insecure, 
~~~
sudo pacman -S openssh
sudo nvim /etc/ssh/sshd_config

UsePAM no #only if not using Multi Factor Authentication
PermitRootLogin prohibit-password
PasswordAuthentication no

ssh-keygen -t ed25519 -C "phrase to generate key from..."
sudo systemctl restart ssh
~~~
## 4. CPU Microcode
[See](https://wiki.archlinux.org/title/Microcode)
~~~
sudo pacman -S amd-ucode 
	#for AMD processors,
    #intel-ucode for Intel processors.
~~~

## 5. find vulnerabilities in your architecture
```
grep -r . /sys/devices/system/cpu/vulnerabilities/
```

## 6. Timeshift
It is very important that we keep backups in case of fuckups which always seem to happen at the worst moment 
```
sudo pacman -S timeshift
timeshift --create --comments "post security setup"
#consider even scheduling, more info on timeshift help
```
## 7. Install yay
```
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
```
## 8. Nvidia Drivers
```
sudo pacman -S nvidia nvidia-utils
```
## 8. Hyprland and dependencies
```
sudo pacman -S kitty ly hyprland fish xdg-desktop-portal-hyprland dunst hyprpolkitagent qt5-wayland qt6-wayland
```
## 9. Change shell
```
sudo pacman -S fish
which fish 
chsh path/to/fish
```
## 10. Waybar
```
yay -S waybar --needed
cp -r /etc/xdg/waybar/ .config/

```
## 11. Open apps like this until u install rofi
```
sudo pacman -S rofi
```
then apply the hyprland.conf or copy the line and rofi launch script
## 12. Apparmor
```
sudo pacman -S apparmor
timeshift --create --comment "just in case"
nvim /boot/loader/entries/ #open the file without the fallback mark
```
Add this to your options:
lsm=landlock,lockdown,yama,apparmor,bpf apparmor=1 security=apparmor 
```
sudo systemctl enable apparmor.service
```
reboot
```
aa-enabled #should be yes
aa-status #use sudo if you cannot see profiles.
```
## 13. Secure boot
#### This is really important! Other than protecting yourself from physical attacks, you also prevent from malicious packages. It is easy for makepkg -si to inject a malicious kernel. This is a must!
1. Go into your bios and reset Secure Boot Keys (DO NOT DO THIS UNLESS DUAL BOOTING TO WINDOWS, IF DUAL BOOTING, REFER TO A DIFFERENT GUIDE FOR SECURE BOOT)
2. Create and Enroll keys
```
sudo sbctl setup #output you should see setup mode = true if not do sudo sbctl setup
sudo sbctl create-keys
sudo sbctl enroll-keys -m #-m for microsoft keys, needed for some services
```
3. Sign bootloader (systemd for grub refer to another guide)
```
sudo sbctl sign -s -o /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed /usr/lib/systemd/boot/efi/systemd-bootx64.efi
```
4. Find and sign linux kernel
```
cat /etc/mkinitcpio.d/linux.preset

#output should have a bunch of lines either commented out with # at the beggining or not.
#look at the next lines:
#ALL_kver =...
#default_uki =....
# If using unified kernel image, the default_uki line wont start with a # therefore you will include that path
#into the next command, but i'm using a standard kernel so i will include ALL_kver.

sudo sbctl sign -s /boot/vmlinuz-linux
```
5. Reinstall bootloader
```
bootctl install
```
6. Verify sbctl
```
sudo sbctl verify
```
7. Reboot & enter BIOS and enable Secure Boot
   
That's it!
## 14. final touches
```
# audio control and theme control
sudo pacman -S pavucontrol nwg-look
# fonts
sudo pacman -S ttf-font-awesome ttf-jetbrains-mono-nerd
# themes
git clone https://github.com/vinceliuice/Graphite-gtk-theme.git --depth=1
cd Graphite-gtk-theme
./install-sh
nwg-look #customize
```

My own config and personal computer moderate secure setup, my laptop is more hardcore tho
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
AllowRootLogin no #cant remember exact cmd
AllowPasswordAuthentication no

ssh-keygen -t ed25519 -C "string"
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
nohup firefox & disown
```
## 12. final touches
```
# audio control and theme control
sudo pacman -S pauvcontrol nwg-look
# fonts
sudo pacman -S ttf-font-awesome ttf-jetbrains-mono-nerd
# themes
$git clone https://github.com/vinceliuice/Graphite-gtk-theme.git --depth=1
$cd Graphite-gtk-theme
$./install-sh -c dark -t purple -s standard -s compact -l --tweaks black rimless

```

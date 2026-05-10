# Arch Linux — LUKS2 + BTRFS + UKI + CIS IG2 (Dev Machine)
### v2.0 — Secure Boot, PAM Hardening, auditd Rules, /proc hidepid

---

## ⚠️ Before You Start — Set Your Disk Variable

Run `lsblk` to identify your disk, then export it. **Every command in this guide uses `$DISK` — do not skip this step.**

```bash
lsblk
export DISK=/dev/nvme0n1   # <-- change this to your actual disk
```

Verify it's set before proceeding:

```bash
echo "Disk: $DISK"
# Should print: Disk: /dev/nvme0n1 (or whatever you set)
```

**Partition references throughout this guide use `${DISK}p1` and `${DISK}p2`.** If your disk is `/dev/sda`-style (no `p` separator), adjust accordingly: `${DISK}1`, `${DISK}2`.

---

## Phase 1 — Live Environment

### 1.1 Verify UEFI

```bash
cat /sys/firmware/efi/fw_platform_size
```

Must return `64`. If it returns `32` or errors, you booted in legacy BIOS mode — stop and fix your boot media.

### 1.2 Console & clock

```bash
loadkeys us
timedatectl set-timezone Europe/Belgrade
timedatectl set-ntp true
```

### 1.3 Internet

Wired works automatically. For Wi-Fi:

```bash
iwctl station wlan0 connect <SSID>
ping -c 3 archlinux.org
```

### 1.4 Mirrors

```bash
reflector --country France,Germany,Netherlands,Austria,Sweden,Serbia \
  --protocol https --age 12 --sort rate --save /etc/pacman.d/mirrorlist
```

---

## Phase 2 — Disk Setup

### 2.1 Wipe & partition

```bash
sgdisk --zap-all $DISK
sgdisk -n1:0:+1G   -t1:ef00 -c1:EFI \
       -n2:0:0     -t2:8304 -c2:CRYPTROOT \
       $DISK
partprobe $DISK
```

- `--zap-all` — destroy all existing partition data
- `-n1:0:+1G` — 1 GiB ESP, large enough for 8–10 UKIs
- `-t1:ef00` — EFI System Partition type
- `-n2:0:0` — remainder of disk for encrypted root
- `-t2:8304` — Linux x86-64 root per [Discoverable Partitions Spec](https://wiki.archlinux.org/title/Discoverable_Partitions_Specification)

### 2.2 LUKS2

Check your physical sector size first:

```bash
DISKNAME=$(basename $DISK)
cat /sys/block/${DISKNAME}/queue/physical_block_size
```

Adjust `--sector-size` below if it reports `512` instead of `4096`.

```bash
cryptsetup luksFormat --type luks2 \
  --cipher aes-xts-plain64 \
  --key-size 512 \
  --hash sha512 \
  --pbkdf argon2id \
  --pbkdf-memory 1048576 \
  --pbkdf-parallel 4 \
  --iter-time 3000 \
  --sector-size 4096 \
  --label CRYPTROOT \
  ${DISK}p2
```

- `aes-xts-plain64` — AES-256 in XTS mode (512-bit key splits to 2×256). HW-accelerated via AES-NI
- `argon2id` — memory-hard KDF, resistant to GPU/ASIC offline attacks
- `--pbkdf-memory 1048576` — 1 GiB memory cost per derivation attempt
- `--iter-time 3000` — 3-second time target for passphrase hashing
- `--sector-size 4096` — matches NVMe physical sectors, reduces crypto overhead

```bash
cryptsetup luksOpen ${DISK}p2 cryptroot
```

### 2.3 Filesystems

```bash
mkfs.fat -F32 -n EFI ${DISK}p1
mkfs.btrfs -f -L archroot /dev/mapper/cryptroot
```

### 2.4 BTRFS subvolumes

```bash
mount /dev/mapper/cryptroot /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_log_audit
btrfs subvolume create /mnt/@var_cache
btrfs subvolume create /mnt/@var_tmp

umount /mnt
```

Flat layout at BTRFS top level. CIS IG2 requires separate mounts for `/home`, `/tmp`, `/var/log`, `/var/log/audit`, `/var/tmp`. `/var/cache` is separate to keep package cache out of root snapshots. `/var/lib` stays in `@` so pacman DB and containers are included in rollbacks.

### 2.5 Mount everything

```bash
BTRFS_OPTS="noatime,compress=zstd:1,discard=async,space_cache=v2"

mount -o subvol=@,$BTRFS_OPTS /dev/mapper/cryptroot /mnt

mkdir -p /mnt/{efi,home,.snapshots}
mkdir -p /mnt/var/{log,cache,tmp}
mkdir -p /mnt/var/log/audit

mount -o subvol=@home,$BTRFS_OPTS,nosuid,nodev                  /dev/mapper/cryptroot /mnt/home
mount -o subvol=@snapshots,$BTRFS_OPTS                           /dev/mapper/cryptroot /mnt/.snapshots
mount -o subvol=@var_log,$BTRFS_OPTS,nosuid,nodev,noexec         /dev/mapper/cryptroot /mnt/var/log
mount -o subvol=@var_log_audit,$BTRFS_OPTS,nosuid,nodev,noexec   /dev/mapper/cryptroot /mnt/var/log/audit
mount -o subvol=@var_cache,$BTRFS_OPTS,nosuid,nodev,noexec       /dev/mapper/cryptroot /mnt/var/cache
mount -o subvol=@var_tmp,$BTRFS_OPTS,nosuid,nodev,noexec         /dev/mapper/cryptroot /mnt/var/tmp

mount -o umask=0077 ${DISK}p1 /mnt/efi
```

BTRFS options:
- `noatime` — skip access-time writes, reduces I/O
- `compress=zstd:1` — level 1 zstd, near-zero CPU cost, solid compression
- `discard=async` — batched TRIM for SSD longevity
- `space_cache=v2` — free space tree (explicit for clarity)

CIS mount flags:
- `nosuid` — ignore SUID/SGID bits
- `nodev` — ignore device special files
- `noexec` — prevent binary execution
- `umask=0077` — ESP accessible only by root

Verify:

```bash
findmnt -t btrfs,vfat
```

---

## Phase 3 — Base Install

### 3.1 Keyring — fix before pacstrap

If pacstrap fails with `signature is unknown trust` or `invalid or corrupted package`, your live ISO keyring is stale. Fix it first:

```bash
pacman -Sy archlinux-keyring
```

If that still fails (keyserver connectivity issues are common in live environments):

```bash
pacman-key --init
pacman-key --populate archlinux
pacman -Sy archlinux-keyring
```

Then proceed with pacstrap below.

### 3.2 Pacstrap

```bash
pacstrap -K /mnt \
  base linux linux-lts linux-firmware \
  intel-ucode amd-ucode \
  btrfs-progs cryptsetup \
  networkmanager \
  vim nano sudo \
  man-db man-pages \
  reflector \
  snapper snap-pac \
  zram-generator \
  audit apparmor \
  ufw \
  sbctl \
  libpwquality \
  base-devel git
```

**Changes from v1:**
- `linux-lts` added — gives you a signed fallback kernel with a separate UKI. If mainline breaks, you boot LTS without touching your config.
- `libpwquality` added — required for PAM password complexity enforcement (CIS 5.3.x)
- `sbctl` — now used immediately for Secure Boot enrollment, no longer deferred

### 3.3 Generate fstab

```bash
genfstab -U /mnt >> /mnt/etc/fstab
```

### 3.4 Edit fstab

Open `/mnt/etc/fstab`. Verify the ESP `/efi` line has `fmask=0077,dmask=0077`.

Add these lines at the bottom:

```
tmpfs   /tmp      tmpfs  defaults,nosuid,nodev,noexec,size=2G  0 0
tmpfs   /dev/shm  tmpfs  defaults,nosuid,nodev,noexec          0 0
```

- `/tmp` and `/dev/shm` with `nosuid,nodev,noexec` — CIS 1.1.x

---

## Phase 4 — System Configuration

### 4.1 Chroot

```bash
arch-chroot /mnt
```

### 4.2 Timezone & locale

```bash
ln -sf /usr/share/zoneinfo/Europe/Belgrade /etc/localtime
hwclock --systohc
```

Edit `/etc/locale.gen` — uncomment:

```
en_US.UTF-8 UTF-8
```

```bash
locale-gen
```

Write `/etc/locale.conf`:

```
LANG=en_US.UTF-8
```

Write `/etc/vconsole.conf`:

```
KEYMAP=us
```

### 4.3 Hostname

Write `/etc/hostname`:

```
archlinux
```

Write `/etc/hosts`:

```
127.0.0.1  localhost
::1        localhost
127.0.1.1  archlinux.localdomain  archlinux
```

### 4.4 Pacman config

Edit `/etc/pacman.conf` — uncomment:

```
Color
ParallelDownloads = 5
```

Also add under `[options]`:

```
DisableSandbox
```

> Note: `DisableSandbox` is sometimes needed in chroot environments. Remove it post-install if unneeded.

### 4.5 mkinitcpio

Write `/etc/mkinitcpio.conf` (replace entire contents):

```
MODULES=(btrfs)
BINARIES=()
FILES=()
HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems)
```

- `systemd` hook — required for `sd-encrypt` and UKI generation
- `microcode` — bundles CPU microcode update directly into the UKI binary
- `sd-vconsole` — loads keymap in early userspace
- `sd-encrypt` — LUKS unlock via kernel parameters
- No `fsck` — BTRFS uses scrub, not fsck

### 4.6 Kernel command line

Get your LUKS UUID:

```bash
blkid -s UUID -o value ${DISK}p2
```

Write `/etc/kernel/cmdline` (single line, substitute your UUID):

```
rd.luks.name=<YOUR-LUKS-UUID>=cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw quiet loglevel=3 audit=1 lsm=landlock,lockdown,yama,integrity,apparmor,bpf slab_nomerge init_on_alloc=1 init_on_free=1 page_alloc.shuffle=1 randomize_kstack_offset=on vsyscall=none pti=on
```

| Parameter | Purpose |
|---|---|
| `rd.luks.name=…=cryptroot` | Map LUKS partition to `/dev/mapper/cryptroot` |
| `rootflags=subvol=@` | Mount BTRFS subvolume `@` as `/` |
| `audit=1` | Enable kernel audit subsystem at boot (CIS) |
| `lsm=…apparmor…` | Enable AppArmor in LSM stack (CIS MAC) |
| `slab_nomerge` | Prevent SLAB cache merging — reduces heap exploit surface |
| `init_on_alloc=1` | Zero-fill memory on allocation — prevents info leaks |
| `init_on_free=1` | Zero-fill memory on free — prevents use-after-free data leaks |
| `page_alloc.shuffle=1` | Randomize page allocator freelists |
| `randomize_kstack_offset=on` | Per-syscall kernel stack randomization |
| `vsyscall=none` | Disable legacy vsyscall interface |
| `pti=on` | Force Page Table Isolation (Meltdown mitigation) |

### 4.7 UKI presets

```bash
mkdir -p /efi/EFI/Linux
```

Write `/etc/mkinitcpio.d/linux.preset` (replace entire contents):

```
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"

PRESETS=('default' 'fallback')

default_uki="/efi/EFI/Linux/arch-linux.efi"
default_options=""

fallback_uki="/efi/EFI/Linux/arch-linux-fallback.efi"
fallback_options="-S autodetect"
```

Write `/etc/mkinitcpio.d/linux-lts.preset` (new — LTS kernel):

```
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux-lts"

PRESETS=('default' 'fallback')

default_uki="/efi/EFI/Linux/arch-linux-lts.efi"
default_options=""

fallback_uki="/efi/EFI/Linux/arch-linux-lts-fallback.efi"
fallback_options="-S autodetect"
```

Each kernel produces its own self-contained `.efi` binary — kernel + initramfs + cmdline + microcode. systemd-boot auto-discovers all of them in `EFI/Linux/`. The LTS UKI is your recovery safety net if a mainline update breaks something.

### 4.8 Build UKIs

```bash
mkinitcpio -P
```

Verify:

```bash
ls -lh /efi/EFI/Linux/
```

You should see four files: `arch-linux.efi`, `arch-linux-fallback.efi`, `arch-linux-lts.efi`, `arch-linux-lts-fallback.efi`.

### 4.9 systemd-boot

```bash
bootctl install --esp-path=/efi
```

Write `/efi/loader/loader.conf`:

```
default @saved
timeout 3
console-mode max
editor no
```

- `editor no` — prevents editing kernel parameters at boot prompt (CIS)
- `@saved` — remembers last booted entry

### 4.10 Secure Boot enrollment

**This was deferred in v1. It is not deferred here.**

First, verify you're in Setup Mode (Secure Boot disabled in UEFI):

```bash
sbctl status
```

Should report `Setup Mode: Enabled`. If not, enter your UEFI firmware and clear/reset Secure Boot keys.

```bash
sbctl create-keys
sbctl enroll-keys --microsoft
```

`--microsoft` includes Microsoft's UEFI CA alongside your own key — required for firmware drivers (USB controllers, NVMe) that are Microsoft-signed. Without it some hardware won't initialise pre-boot.

Sign all UKI binaries:

```bash
sbctl sign -s /efi/EFI/Linux/arch-linux.efi
sbctl sign -s /efi/EFI/Linux/arch-linux-fallback.efi
sbctl sign -s /efi/EFI/Linux/arch-linux-lts.efi
sbctl sign -s /efi/EFI/Linux/arch-linux-lts-fallback.efi
sbctl sign -s /efi/EFI/systemd/systemd-bootx64.efi
sbctl sign -s /efi/EFI/BOOT/BOOTX64.EFI
```

The `-s` flag saves the signing paths to the sbctl database. Every time `mkinitcpio -P` runs (e.g. after a kernel update via `snap-pac`), sbctl automatically re-signs the new binaries.

Verify:

```bash
sbctl verify
```

All listed files should show `✓ Signed`.

Enable Secure Boot in your UEFI firmware settings, then continue.

### 4.11 DNS resolution

```bash
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
mkdir -p /etc/NetworkManager/conf.d
```

Write `/etc/NetworkManager/conf.d/dns.conf`:

```
[main]
dns=systemd-resolved
```

### 4.12 Users

```bash
passwd
```

Set root password.

```bash
useradd -m -G wheel -s /bin/bash <YOUR_USERNAME>
passwd <YOUR_USERNAME>
```

Run `visudo` — uncomment:

```
%wheel ALL=(ALL:ALL) ALL
```

Also add below it to harden sudo sessions:

```
Defaults timestamp_timeout=5
Defaults passwd_timeout=1
Defaults logfile=/var/log/sudo.log
Defaults use_pty
Defaults !visiblepw
```

- `timestamp_timeout=5` — sudo credential cache expires after 5 minutes
- `use_pty` — forces sudo commands into a pseudo-terminal, blocks some injection attacks
- `logfile` — writes sudo session log in addition to syslog (CIS 5.3.x)

### 4.13 Enable services

```bash
systemctl enable NetworkManager
systemctl enable systemd-resolved
systemctl enable systemd-timesyncd
systemctl enable fstrim.timer
systemctl enable auditd
systemctl enable apparmor
systemctl enable reflector.timer
systemctl enable systemd-boot-update.service
systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer
```

### 4.14 Reflector config

Write `/etc/xdg/reflector/reflector.conf`:

```
--country France,Germany,Netherlands,Austria,Sweden,Serbia
--protocol https
--age 12
--sort rate
--save /etc/pacman.d/mirrorlist
```

### 4.15 Snapper

```bash
umount /.snapshots
snapper -c root create-config /
btrfs subvolume delete /.snapshots
mkdir /.snapshots
mount -a
chmod 750 /.snapshots
```

Why the dance: `snapper create-config` auto-creates a nested `.snapshots` subvolume inside `@`. We delete it and remount the top-level `@snapshots` subvolume instead — keeps the flat layout intact.

Edit `/etc/snapper/configs/root`:

```
TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="0"
TIMELINE_LIMIT_YEARLY="0"
```

### 4.16 ZRAM

Write `/etc/systemd/zram-generator.conf`:

```
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
```

Compressed RAM swap. No disk I/O, no SSD wear, nothing to encrypt on disk.

---

## Phase 5 — CIS IG2 Hardening

### 5.1 Sysctl

Write `/etc/sysctl.d/99-cis-hardening.conf`:

```
# ==============================================================================
# KERNEL
# ==============================================================================

# Disable SysRq key — the SysRq combo (Alt+SysRq+key) allows low-level kernel
# commands from the keyboard: killing all processes, rebooting, dumping memory.
# An attacker with physical or remote console access could use it to bypass
# normal access controls or extract data. 0 = fully disabled.
# Ref: https://www.kernel.org/doc/html/latest/admin-guide/sysrq.html
kernel.sysrq = 0

# Append PID to core dump filenames — without this, concurrent crashes from
# different processes overwrite each other's core files, destroying forensic
# evidence. With it, each dump is uniquely named (core.1234).
# Ref: https://man7.org/linux/man-pages/man5/core.5.html
kernel.core_uses_pid = 1

# Restrict dmesg to root — dmesg contains kernel ring buffer messages including
# kernel addresses, driver info, hardware details, and boot secrets. Unprivileged
# users reading it can map kernel memory layout for exploit targeting (KASLR bypass).
# 1 = only root or CAP_SYSLOG can read dmesg.
# Ref: https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html
kernel.dmesg_restrict = 1

# Hide kernel pointer addresses — functions like /proc/kallsyms and kernel
# oops messages print raw kernel memory addresses. An attacker uses these to
# defeat KASLR (Kernel Address Space Layout Randomisation) and calculate where
# exploit payloads need to land. 2 = replace all addresses with 0s even for root.
# Ref: https://lwn.net/Articles/420403/
kernel.kptr_restrict = 2

# Restrict ptrace to parent processes only — ptrace is the syscall used by
# debuggers (gdb, strace). Without restriction, any process can attach to and
# read/write the memory of any other process owned by the same user — trivially
# used to steal credentials from running processes (browsers, password managers).
# 1 = a process can only ptrace its own children. Allows normal debugging.
# Ref: https://wiki.archlinux.org/title/Security#Restricting_ptrace
kernel.yama.ptrace_scope = 1

# Disable unprivileged eBPF — eBPF programs run inside the kernel and have been
# the source of numerous privilege escalation CVEs (CVE-2021-3490, CVE-2022-23222
# etc.). Unprivileged users should never be able to load kernel programs.
# Ref: https://security.googleblog.com/2023/06/learnings-from-kctf-vrps-42-linux.html
kernel.unprivileged_bpf_disabled = 1

# Harden eBPF JIT compiler — the JIT compiler turns eBPF bytecode into native
# machine code. Without hardening it leaks kernel addresses and is easier to
# exploit via JIT spraying attacks. 2 = constant blinding + address restriction.
# Ref: https://www.kernel.org/doc/html/latest/admin-guide/sysctl/net.html
net.core.bpf_jit_harden = 2

# Restrict perf_event_open — the perf subsystem exposes hardware performance
# counters which can be used for side-channel attacks (measuring cache behaviour
# to infer cryptographic keys, etc.). 3 = only root can use perf at all.
# Ref: https://lwn.net/Articles/696216/
kernel.perf_event_paranoid = 3

# Disable kexec — kexec allows loading a new kernel at runtime without rebooting
# through firmware/Secure Boot. An attacker with root could use it to replace the
# running kernel with a malicious one, bypassing Secure Boot entirely.
# Cannot be re-enabled without reboot once set.
# Ref: https://wiki.archlinux.org/title/Security#Restricting_kexec
kernel.kexec_load_disabled = 1

# Disable unprivileged user namespaces — user namespaces allow unprivileged
# processes to create isolated environments with their own UID mappings. They
# are the primary attack surface for container escape exploits and have been
# involved in dozens of local privilege escalation CVEs. Disable unless you
# need rootless Docker/Podman, in which case set to 1.
# Ref: https://nvd.nist.gov/vuln/detail/CVE-2022-0492
kernel.unprivileged_userns_clone = 0

# ==============================================================================
# FILESYSTEM
# ==============================================================================

# Disable core dumps for SUID binaries — SUID binaries run with elevated
# privileges. If they crash and dump core, that file could contain sensitive
# memory (password hashes, keys) from the elevated context, readable by the
# calling user. 0 = no core dumps for SUID/privilege-elevated processes.
# Ref: https://www.cyberciti.biz/faq/linux-disable-core-dumps/
fs.suid_dumpable = 0

# Protect hardlinks — without this, a user can hardlink to a SUID binary or
# file they don't own, then wait for a privileged process to follow that link.
# This enables TOCTOU (time-of-check-time-of-use) privilege escalation attacks.
# 1 = you can only hardlink to files you own.
# Ref: https://www.kernel.org/doc/html/latest/admin-guide/sysctl/fs.html
fs.protected_hardlinks = 1

# Protect symlinks — prevents symlink following attacks in world-writable
# directories like /tmp. Classic attack: create a symlink from /tmp/evil ->
# /etc/passwd, trick a root process into writing to /tmp/evil.
# 1 = symlinks in sticky world-writable dirs only followed if owner matches.
# Ref: https://www.kernel.org/doc/html/latest/admin-guide/sysctl/fs.html
fs.protected_symlinks = 1

# Protect FIFOs (named pipes) — prevents an attacker in a world-writable
# directory from creating a FIFO that a privileged process might accidentally
# open, allowing data injection or reading.
# 2 = FIFOs in sticky dirs only openable by owner or directory owner.
fs.protected_fifos = 2

# Protect regular files — same principle as FIFOs but for regular files.
# Prevents privilege escalation via O_CREAT race conditions in /tmp.
# 2 = files in sticky dirs not openable by non-owner unless they own the dir.
fs.protected_regular = 2

# Network IPv4
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.all.arp_announce = 2

# Network IPv6
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
```

**Network parameter reference:**

| Parameter | Attack prevented |
|---|---|
| `send_redirects = 0` | Stops this machine poisoning LAN routing tables via ICMP redirects (MITM) |
| `accept_source_route = 0` | Blocks source-routed packets used to bypass firewalls and spoof return paths — [RFC 791](https://www.rfc-editor.org/rfc/rfc791) |
| `accept_redirects = 0` | Blocks forged ICMP redirects from silently rerouting your traffic through an attacker on the LAN |
| `secure_redirects = 0` | Same as above — "secure" redirects are still exploitable if the gateway is compromised |
| `log_martians = 1` | Logs packets with impossible source addresses (spoofing detection) |
| `icmp_echo_ignore_broadcasts = 1` | Prevents Smurf DDoS — broadcast ping amplification attack — [CISA 1998](https://www.cisa.gov/news-events/alerts/1998/01/05/smurf-ip-denial-service-attacks) |
| `icmp_ignore_bogus_error_responses = 1` | Drops malformed ICMP errors from broken routers, prevents log flooding |
| `rp_filter = 1` | Drops packets whose source address wouldn't route back the same interface — blocks IP spoofing — [RFC 3704](https://www.rfc-editor.org/rfc/rfc3704) |
| `tcp_syncookies = 1` | SYN flood DoS mitigation — encodes state into sequence numbers so connection table can't be exhausted — [RFC 4987](https://www.rfc-editor.org/rfc/rfc4987) |
| `tcp_rfc1337 = 1` | Blocks TCP TIME-WAIT assassination — forged RST injection into expiring connections — [RFC 1337](https://www.rfc-editor.org/rfc/rfc1337) |
| `arp_ignore = 1` | Stops replying to ARP requests for IPs not on the receiving interface — prevents IP disclosure across segments |
| `arp_announce = 2` | Prevents ARP requests leaking IPs from other interfaces onto the wrong network segment |
| `accept_ra = 0` | Blocks forged IPv6 Router Advertisement MITM — attacker becomes your default IPv6 gateway — [RFC 6104](https://www.rfc-editor.org/rfc/rfc6104) |
| `disable_ipv6 = 1` | Eliminates entire IPv6 stack if unused — remove if your network requires IPv6 |

<details>
<summary>Dev-machine notes on specific kernel values</summary>

- `kernel.yama.ptrace_scope = 1` — a process can only be ptraced by its parent. Allows `gdb ./myapp` normally. Use `2` if you never debug.
- `kernel.perf_event_paranoid = 3` — blocks `perf` for non-root. Temporarily set to `2` or run perf as root if profiling your own code.
- `kernel.kexec_load_disabled = 1` — cannot be undone without reboot. Prevents runtime kernel replacement.
- `kernel.unprivileged_userns_clone = 0` — breaks rootless containers. Set to `1` if you use rootless Podman or Docker.

</details>

### 5.2 Disable unused kernel modules

Write `/etc/modprobe.d/cis-disable-fs.conf`:

```
install cramfs /bin/false
install freevxfs /bin/false
install hfs /bin/false
install hfsplus /bin/false
install jffs2 /bin/false
install udf /bin/false
```

Write `/etc/modprobe.d/cis-disable-net.conf`:

```
install dccp /bin/false
install sctp /bin/false
install rds /bin/false
install tipc /bin/false
```

`install <module> /bin/false` redirects any attempt to load the module to a command that immediately exits with failure — cleaner and more reliable than `blacklist` alone, which can still be overridden by a direct `modprobe`. These are obscure filesystems and network protocols with no legitimate use on a dev workstation that have historically been sources of kernel vulnerabilities. CIS 1.1.1.x + 3.4.x.

### 5.3 Core dump restrictions

Write `/etc/security/limits.d/99-coredump.conf`:

```
* hard core 0
* hard maxlogins 10
* soft nproc 512
* hard nproc 1024
```

Write `/etc/systemd/coredump.conf`:

```
[Coredump]
Storage=none
ProcessSizeMax=0
```

- `hard core 0` — CIS 1.5.1: prevent info leakage through core dumps
- `maxlogins 10` — CIS 5.4.x: cap concurrent logins per user
- `nproc` limits — prevent fork-bomb style resource exhaustion

### 5.4 PAM hardening — faillock, password quality, password history

**This entire section is new in v2. It was the most significant gap in v1.**

Write `/etc/security/faillock.conf`:

```
deny = 5
fail_interval = 900
unlock_time = 600
audit
silent
even_deny_root
root_unlock_time = 60
```

- `deny = 5` — lock account after 5 failed attempts (CIS 5.3.3.1.1)
- `fail_interval = 900` — count failures within a 15-minute window
- `unlock_time = 600` — auto-unlock after 10 minutes (CIS 5.3.3.1.2)
- `even_deny_root` — root account is also subject to lockout
- `root_unlock_time = 60` — root unlocks faster (60 seconds) to prevent lockout-based DoS on single-user machine

Write `/etc/security/pwquality.conf`:

```
minlen = 14
minclass = 4
maxrepeat = 3
maxclassrepeat = 4
gecoscheck = 1
dictcheck = 1
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
```

- `minlen = 14` — CIS 5.3.3.2.1: minimum 14-character passwords
- `minclass = 4` — require all four character classes
- `maxrepeat = 3` — no more than 3 consecutive identical characters
- `gecoscheck = 1` — reject passwords containing the username
- `dictcheck = 1` — reject dictionary words

Write `/etc/pam.d/system-auth`:

```
#%PAM-1.0

auth      required  pam_faillock.so preauth silent audit deny=5 fail_interval=900 unlock_time=600
auth      required  pam_unix.so try_first_pass
auth      [default=die] pam_faillock.so authfail audit deny=5 fail_interval=900 unlock_time=600
auth      optional  pam_permit.so
auth      required  pam_env.so

account   required  pam_unix.so
account   required  pam_faillock.so
account   optional  pam_permit.so
account   required  pam_time.so

password  required  pam_pwquality.so try_first_pass retry=3
password  required  pam_pwhistory.so use_authtok remember=5 enforce_for_root
password  required  pam_unix.so sha512 shadow use_authtok
password  optional  pam_permit.so

session   required  pam_limits.so
session   required  pam_unix.so
session   optional  pam_permit.so
```

- `pam_faillock` — account lockout after failed attempts (CIS 5.3.3.1.x)
- `pam_pwquality` — enforces `/etc/security/pwquality.conf` rules (CIS 5.3.3.2.x)
- `pam_pwhistory remember=5` — prevents reuse of last 5 passwords (CIS 5.3.3.3.1)
- `sha512` — strong password hash algorithm (CIS 5.3.3.4.3)

Edit `/etc/login.defs` — find and set these values:

```
PASS_MAX_DAYS   365
PASS_MIN_DAYS   1
PASS_WARN_AGE   14
ENCRYPT_METHOD  SHA512
SHA_CRYPT_MIN_ROUNDS  10000
```

- `PASS_MAX_DAYS 365` — CIS 5.4.1.1: passwords expire annually
- `PASS_MIN_DAYS 1` — CIS 5.4.1.2: can't immediately change back
- `PASS_WARN_AGE 14` — CIS 5.4.1.3: 14-day warning before expiry
- `SHA_CRYPT_MIN_ROUNDS 10000` — increases hashing cost for `/etc/shadow`

### 5.5 Journald

```bash
mkdir -p /etc/systemd/journald.conf.d
```

Write `/etc/systemd/journald.conf.d/cis.conf`:

```
[Journal]
Storage=persistent
Compress=yes
ForwardToSyslog=no
SystemMaxUse=500M
SystemKeepFree=100M
MaxRetentionSec=1month
```

CIS 4.2.2 — persist logs to `/var/log/journal`. `MaxRetentionSec` prevents unbounded log accumulation.

### 5.6 auditd rules

**Completely new in v2. Previously auditd was enabled with zero rules — effectively useless.**

```bash
mkdir -p /etc/audit/rules.d
```

Write `/etc/audit/rules.d/99-cis-hardening.rules`:

```
# --- Buffer & failure mode ---
-b 8192
-f 1
-e 1

# --- Identity & authentication files (CIS 4.1.x) ---
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity

# --- Sudoers (CIS 4.1.x) ---
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers

# --- PAM configuration ---
-w /etc/pam.d/ -p wa -k pam
-w /etc/security/ -p wa -k pam

# --- Login and session events (CIS 4.1.x) ---
-w /var/log/lastlog -p wa -k logins
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k session
-w /var/log/btmp -p wa -k session

# --- Time changes (CIS 4.1.x) ---
-a always,exit -F arch=b64 -S adjtimex,settimeofday,clock_settime -k time-change
-a always,exit -F arch=b32 -S adjtimex,settimeofday,clock_settime -k time-change
-w /etc/localtime -p wa -k time-change

# --- Network configuration changes (CIS 4.1.x) ---
-a always,exit -F arch=b64 -S sethostname,setdomainname -k network-config
-a always,exit -F arch=b32 -S sethostname,setdomainname -k network-config
-w /etc/hosts -p wa -k network-config
-w /etc/NetworkManager/ -p wa -k network-config

# --- Privilege escalation (CIS 4.1.x) ---
-a always,exit -F arch=b64 -S setuid -F a0=0 -F exe=/usr/bin/su -k elevated-privs
-a always,exit -F arch=b64 -S setresuid -F a0=0 -F exe=/usr/bin/sudo -k elevated-privs
-a always,exit -F arch=b64 -S execve -C uid!=euid -F euid=0 -k elevated-privs

# --- Kernel module loading/unloading (CIS 4.1.x) ---
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module,finit_module,delete_module -k modules

# --- File permission modifications (CIS 4.1.x) ---
-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=-1 -k perm-mod
-a always,exit -F arch=b32 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=-1 -k perm-mod
-a always,exit -F arch=b64 -S chown,fchown,fchownat,lchown -F auid>=1000 -F auid!=-1 -k perm-mod
-a always,exit -F arch=b32 -S chown,fchown,fchownat,lchown -F auid>=1000 -F auid!=-1 -k perm-mod
-a always,exit -F arch=b64 -S setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid>=1000 -F auid!=-1 -k perm-mod

# --- Unsuccessful file access attempts (CIS 4.1.x) ---
-a always,exit -F arch=b64 -S creat,open,openat,open_by_handle_at,truncate,ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=-1 -k access
-a always,exit -F arch=b64 -S creat,open,openat,open_by_handle_at,truncate,ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=-1 -k access

# --- File deletions (CIS 4.1.x) ---
-a always,exit -F arch=b64 -S unlink,unlinkat,rename,renameat -F auid>=1000 -F auid!=-1 -k delete
-a always,exit -F arch=b32 -S unlink,unlinkat,rename,renameat -F auid>=1000 -F auid!=-1 -k delete

# --- Privileged command execution (CIS 4.1.x) ---
-a always,exit -F path=/usr/bin/sudo -F perm=x -F auid>=1000 -F auid!=-1 -k privileged
-a always,exit -F path=/usr/bin/su -F perm=x -F auid>=1000 -F auid!=-1 -k privileged
-a always,exit -F path=/usr/bin/newgrp -F perm=x -F auid>=1000 -F auid!=-1 -k privileged
-a always,exit -F path=/usr/bin/chsh -F perm=x -F auid>=1000 -F auid!=-1 -k privileged
-a always,exit -F path=/usr/bin/mount -F perm=x -F auid>=1000 -F auid!=-1 -k privileged
-a always,exit -F path=/usr/bin/umount -F perm=x -F auid>=1000 -F auid!=-1 -k privileged
-a always,exit -F path=/usr/bin/passwd -F perm=x -F auid>=1000 -F auid!=-1 -k privileged

# --- MAC policy changes (AppArmor) ---
-w /etc/apparmor/ -p wa -k MAC-policy
-w /etc/apparmor.d/ -p wa -k MAC-policy

# --- Immutable flag: lock rules at runtime ---
# -e 2
```

> The final `-e 2` line is commented out. When uncommented, it makes audit rules immutable until reboot — even root cannot disable auditing. Uncomment it once you're confident your ruleset is stable. It will cause `augenrules --load` to fail on a running system (requires reboot to change rules).

Set correct permissions on audit rules:

```bash
chmod 0640 /etc/audit/rules.d/99-cis-hardening.rules
chmod 0640 /etc/audit/auditd.conf
```

### 5.7 Login banners

> This banner is mostly for the lols, but it does satisfy CIS 1.7.x and a strongly worded banner has genuine legal value — it establishes that access is monitored and not implicit, which matters if you ever pursue unauthorised access legally.

Write `/etc/issue` and `/etc/issue.net` with identical contents:

```
*******************************************************************************
                           RESTRICTED SYSTEM
                      UNAUTHORISED ACCESS PROHIBITED
*******************************************************************************

This system is privately owned and operated. Access is granted exclusively to
authorised users for approved purposes. No expectation of privacy exists on
this system.

By proceeding beyond this point you acknowledge that:

  - All activity on this system is monitored, logged, and recorded in full
  - Logs are retained and may be provided to law enforcement authorities
  - Unauthorised access or misuse will be prosecuted to the maximum extent
    permitted under applicable national and international law
  - This includes the Computer Fraud and Abuse Act (18 U.S.C. § 1030),
    the Budapest Convention on Cybercrime, and all equivalent local statutes

If you are not an authorised user, disconnect immediately.

*******************************************************************************
```

```bash
> /etc/motd
```

CIS 1.7.x.

### 5.8 Restrict su to wheel

Write `/etc/pam.d/su`:

```
#%PAM-1.0
auth  sufficient  pam_rootok.so
auth  required    pam_wheel.so use_uid
auth  required    pam_unix.so
account  required  pam_unix.so
session  required  pam_unix.so
```

CIS 5.7 — only `wheel` members can `su`.

### 5.9 Umask & shell timeout

Write `/etc/profile.d/cis-umask.sh`:

```bash
umask 027
```

Write `/etc/profile.d/cis-timeout.sh`:

```bash
TMOUT=900
readonly TMOUT
export TMOUT
```

- `umask 027` — CIS 5.5.5: new files not world-readable
- `TMOUT=900` — CIS 5.5.4: 15-minute idle shell logout

### 5.10 File permissions

```bash
chmod 600 /etc/crontab 2>/dev/null || true
chmod 700 /etc/cron.d 2>/dev/null || true
chmod 700 /etc/cron.daily 2>/dev/null || true
chmod 700 /etc/cron.hourly 2>/dev/null || true
chmod 700 /etc/cron.monthly 2>/dev/null || true
chmod 700 /etc/cron.weekly 2>/dev/null || true
chmod 600 /efi/loader/loader.conf
chmod 700 /efi/loader
chmod 700 /efi/EFI
chmod 600 /etc/audit/auditd.conf
chmod 640 /etc/audit/rules.d/99-cis-hardening.rules
chmod 600 /etc/security/pwquality.conf
chmod 600 /etc/security/faillock.conf
```

### 5.11 Ctrl-Alt-Delete protection

```bash
systemctl mask ctrl-alt-del.target
systemctl daemon-reload
```

Prevents physical-access reboot via keyboard shortcut. CIS 1.5.x.

### 5.12 Firewall

```bash
pacman -S ufw
ufw default deny incoming
ufw default allow outgoing
ufw enable
systemctl enable ufw
```

Simple default-deny inbound, allow outbound. Add rules as needed for dev services, e.g. `ufw allow 22/tcp` for SSH. Disable nftables since ufw manages its own rules:

```bash
systemctl disable nftables
systemctl stop nftables
```

---

## Phase 6 — Reboot

```bash
exit
umount -R /mnt
reboot
```

Remove installation media. If Secure Boot enrollment was completed in 4.10, your firmware will now enforce it.

---

## Post-Reboot Verification

```bash
# Filesystem layout
findmnt -t btrfs,tmpfs
lsblk -o NAME,TYPE,FSTYPE,SIZE,MOUNTPOINTS

# Boot integrity
bootctl status
sbctl status               # Should show Secure Boot: enabled

# AppArmor
aa-status

# Audit
systemctl status auditd
auditctl -l                # List loaded rules

# ZRAM swap
swapon --show

# Sysctl spot-check
sysctl kernel.dmesg_restrict kernel.kptr_restrict kernel.yama.ptrace_scope \
       kernel.unprivileged_userns_clone fs.protected_hardlinks

# Firewall
ufw status verbose

# Faillock — verify it's configured
faillock --user <YOUR_USERNAME>

# Secure Boot — verify UKI signatures
sbctl verify

# PAM — test password quality (should reject weak password)
passwd  # try entering "password123" — should be rejected

# Create first clean snapshot
snapper -c root create --description "Fresh install v2"

# Run Lynis security audit (optional)
# pacman -S lynis && lynis audit system
```

---

## What Changed from v1

| Area | v1 | v2 |
|---|---|---|
| Disk variable | Hardcoded `/dev/nvme0n1` everywhere | `$DISK` variable set once at top |
| Secure Boot | Deferred | Completed in Phase 4 with `sbctl` |
| LTS kernel | Not included | Installed with its own UKI preset |
| PAM faillock | Not configured | Full `faillock.conf` + PAM stack |
| Password policy | Not configured | `pwquality.conf` + history + expiry |
| auditd rules | Zero rules | Full CIS 4.1.x ruleset |
| Sudo hardening | Basic wheel restriction | `use_pty`, log file, timestamp timeout |
| Kernel cmdline | 10 parameters | 11 clean parameters, no workflow-breaking mitigations |
| Firewall | Custom nftables ruleset | `ufw default deny incoming` |
| Login banner | One line | Scary wall of text (for the lols) |
| Module blacklist | 10 modules | 10 modules, no overkill |
| Core limits | Core dumps only | Core + maxlogins + nproc |
| Ctrl-Alt-Del | Not masked | Masked |
| TPM2 | Deferred | Phase 7 — full enrollment guide |
| Hyprland | Deferred | Phase 8 — full stack with fonts, GTK, Qt, waybar |

---

**Still deferred:** AppArmor enforce-mode profiles (requires per-application profiling).

---

## Phase 7 — TPM2 LUKS Binding

This allows the disk to auto-decrypt at boot without typing your passphrase, as long as Secure Boot is active and the boot chain hasn't changed. If someone disables Secure Boot or boots a different kernel, the TPM refuses to release the key and you fall back to passphrase.

### 7.1 Install dependencies

```bash
pacman -S tpm2-tss tpm2-tools
```

### 7.2 Enroll a recovery key first

Before binding to TPM, enroll a recovery key and write it down somewhere safe. If your TPM ever refuses (firmware update, Secure Boot key rotation, BIOS change), this is your only way back in.

```bash
systemd-cryptenroll --recovery-key ${DISK}p2
```

Write down or store the recovery key somewhere offline and secure. Treat it like your LUKS passphrase.

### 7.3 Verify TPM is available

```bash
systemd-cryptenroll --tpm2-device=list
```

Should show your TPM device. If nothing appears your CPU/firmware doesn't have TPM2 or it's disabled in UEFI — enable it there first.

### 7.4 Enroll TPM2

```bash
systemd-cryptenroll \
  --tpm2-device=auto \
  --tpm2-pcrs=7 \
  ${DISK}p2
```

PCR 7 binds the key to the Secure Boot state — the key is only released if Secure Boot is enabled and your enrolled keys are intact. This is the recommended single PCR for most setups.

> **Why not PCR 0 or PCR 4?** PCR 0 measures firmware — any firmware update invalidates it and locks you out until you re-enroll. PCR 4 measures the bootloader binary — same problem on every systemd-boot update. PCR 7 is stable across normal updates while still protecting against Secure Boot bypass.

### 7.5 Update crypttab

Edit `/etc/crypttab` — find your entry and add `tpm2-device=auto`:

```
cryptroot  UUID=<YOUR-LUKS-UUID>  -  tpm2-device=auto
```

Rebuild UKIs so the initramfs picks up the new crypttab:

```bash
mkinitcpio -P
```

### 7.6 Test

Reboot. The disk should decrypt automatically without a passphrase prompt. If it doesn't and asks for a passphrase, enter it — the system still boots, TPM just didn't release the key.

### 7.7 Re-enrolling after firmware updates

If you update firmware via `fwupdmgr` and the TPM subsequently refuses to unlock:

```bash
# Wipe the old TPM enrollment
systemd-cryptenroll --wipe-slot=tpm2 ${DISK}p2

# Re-enroll
systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 ${DISK}p2
```

---

## Phase 8 — Hyprland + Wayland Stack

### 8.1 Core packages

```bash
pacman -S \
  hyprland xorg-xwayland \
  hyprpaper hyprlock hypridle hyprpolkitagent \
  waybar \
  rofi-wayland \
  dunst \
  kitty \
  pipewire wireplumber pipewire-audio pipewire-pulse pipewire-alsa \
  sddm \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  qt5-wayland qt6-wayland \
  qt5ct qt6ct \
  nwg-look \
  wl-clipboard \
  hyprshot \
  brightnessctl \
  playerctl \
  network-manager-applet \
  bluez bluez-utils blueman \
  gnome-themes-extra \
  papirus-icon-theme
```

- `hyprland` — the compositor
- `hyprpaper` — wallpaper daemon
- `hyprlock` — screen locker
- `hypridle` — idle management (dim/lock/sleep triggers)
- `hyprpolkitagent` — polkit authentication popups (sudo GUI prompts)
- `waybar` — status bar
- `rofi-wayland` — application launcher (use `rofi-wayland` not `rofi` on Wayland)
- `dunst` — notification daemon
- `kitty` — terminal (GPU-accelerated, good Wayland support)
- `pipewire` stack — modern audio, replaces PulseAudio
- `xdg-desktop-portal-hyprland` — screen sharing, file picker backend
- `xdg-desktop-portal-gtk` — file picker for GTK apps
- `qt5ct/qt6ct` — Qt theme configuration tools
- `nwg-look` — GTK theme configuration GUI for Wayland
- `wl-clipboard` — clipboard (`wl-copy`, `wl-paste`)
- `brightnessctl` — display brightness control
- `playerctl` — media player control (waybar integration)

### 8.2 Fonts

```bash
pacman -S \
  ttf-jetbrains-mono-nerd \
  ttf-font-awesome \
  noto-fonts \
  noto-fonts-emoji \
  ttf-dejavu
```

- `ttf-jetbrains-mono-nerd` — terminal + waybar icons (nerd font patched)
- `ttf-font-awesome` — icon font used by many waybar configs
- `noto-fonts` — wide Unicode coverage, good for UI
- `noto-fonts-emoji` — emoji rendering
- `ttf-dejavu` — fallback font, prevents missing glyph boxes

### 8.3 Enable services

```bash
systemctl --user enable pipewire pipewire-pulse wireplumber

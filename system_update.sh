#!/bin/bash
set -e  # Exit on any error

echo "=== Arch Linux Safe Update Script ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root"
   exit 1
fi

# Check if timeshift is installed
if ! command -v timeshift &> /dev/null; then
    error "Timeshift is not installed. Please install it first: sudo pacman -S timeshift"
    exit 1
fi

# Generate current date for backup name
BACKUP_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_COMMENT="Pre-update backup - $BACKUP_DATE"

log "Starting safe system update process..."
info "Backup will be named: $BACKUP_DATE"

# Create timeshift backup
log "Creating Timeshift backup before update..."
echo "This may take a few minutes depending on your system size..."

if sudo timeshift --create --comments "$BACKUP_COMMENT" --scripted; then
    log "✓ Timeshift backup created successfully!"
    log "Backup comment: $BACKUP_COMMENT"
else
    error "✗ Timeshift backup failed!"
    error "Aborting system update for safety."
    exit 1
fi

# Check for available updates first
log "Checking for available updates..."
if ! sudo pacman -Sy; then
    error "Failed to sync package databases"
    exit 1
fi

# Show what would be updated
info "Packages that will be updated:"
pacman -Qu || echo "No updates available"

# Ask for confirmation
echo ""
read -p "Do you want to proceed with the system update? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    warn "Update cancelled by user"
    exit 0
fi

# Perform the system update
log "Starting system update..."
log "Running: sudo pacman -Syu"

if sudo pacman -Syu; then
    log "✓ System update completed successfully!"
    
    # Check if reboot is required
    if [ -f /var/run/reboot-required ] || 
       pacman -Q linux | grep -q "$(uname -r | sed 's/-.*//g')" 2>/dev/null || 
       [ "$(pacman -Q linux | awk '{print $2}' | cut -d'-' -f1)" != "$(uname -r | cut -d'-' -f1)" ]; then
        warn "⚠️  System reboot recommended after kernel/critical updates"
        warn "Run 'sudo reboot' when convenient"
    fi
    
    # Optional: Clean package cache
    read -p "Clean package cache to free up space? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Cleaning package cache..."
        sudo pacman -Sc --noconfirm
        log "✓ Package cache cleaned"
    fi
    
    log "Update process completed successfully!"
    log "Backup created: $BACKUP_DATE"
    
else
    error "✗ System update failed!"
    warn "Your system was not modified. Timeshift backup is available if needed."
    warn "Backup name: $BACKUP_DATE"
    exit 1
fi

echo ""
log "=== Update Summary ==="
echo "• Timeshift backup: ✓ Created ($BACKUP_DATE)"
echo "• System update: ✓ Completed"
echo "• Cache cleanup: $([ "$REPLY" = "y" ] && echo "✓ Done" || echo "⊗ Skipped")"
echo ""
info "If you encounter any issues, restore with:"
info "sudo timeshift --restore --snapshot '$BACKUP_DATE'"

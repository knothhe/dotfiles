#!/bin/bash

# Linux Flatpak Package Installation Script
# Installs Flatpak packages defined in flatpak.packages file

set -e

# Source common functions for consistent UI
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
COMMON_FUNCTIONS="$PARENT_DIR/home/dot_local/xbin/common_functions.sh"

# Source common functions - this is required, not optional
if [ -f "$COMMON_FUNCTIONS" ]; then
    source "$COMMON_FUNCTIONS"
else
    echo "ERROR: Required common_functions.sh not found at $COMMON_FUNCTIONS"
    exit 1
fi

# Configuration
PACKAGES_FILE="$SCRIPT_DIR/flatpak.packages"

# Check if flatpak is available
if ! command -v flatpak >/dev/null 2>&1; then
    print_error "Flatpak not found. Please install Flatpak first."
    exit 1
fi

# Check if packages file exists
if [ ! -f "$PACKAGES_FILE" ]; then
    print_error "Packages file not found: $PACKAGES_FILE"
    exit 1
fi

# Read packages from file (skip comments and empty lines)
print_title "Installing Flatpak Packages"

# Read packages using simple loop (compatible with all shells)
packages=()
while IFS= read -r line; do
    [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]] && packages+=("$line")
done < "$PACKAGES_FILE"

if [ ${#packages[@]} -eq 0 ]; then
    print_warning "No packages found in $PACKAGES_FILE"
    exit 0
fi

print_info "Packages to install" "${#packages[@]} packages"
echo "Packages: ${packages[*]}"

# Add Flathub remote if not exists
print_progress "Adding Flathub remote..."
if flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo; then
    print_success "Flathub remote configured"
else
    print_warning "Flathub remote may already exist or failed to add"
fi

# Install packages using flatpak
print_progress "Installing Flatpak packages..."

if flatpak install flathub "${packages[@]}" -y; then
    print_completion
else
    print_error "Flatpak package installation failed"
    exit 1
fi
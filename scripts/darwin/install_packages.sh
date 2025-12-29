#!/bin/bash

# macOS Package Installation Script
# Installs Homebrew packages and casks defined in darwin.brews and darwin.casks files

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BREWS_FILE="$SCRIPT_DIR/darwin.brews"
CASKS_FILE="$SCRIPT_DIR/darwin.casks"

# Simple output functions
print_info() {
    echo "INFO: $1"
}

print_error() {
    echo "ERROR: $1" >&2
}

print_warning() {
    echo "WARNING: $1"
}

# Check if brew is available
if ! command -v brew >/dev/null 2>&1; then
    print_error "Homebrew not found. Please install Homebrew first."
    echo "Visit: https://brew.sh/"
    exit 1
fi

echo "=== Installing macOS Packages ==="

# Read brews and casks
brews=()
casks=()

if [ -f "$BREWS_FILE" ]; then
    # Read packages using simple loop (compatible with all shells)
    brews=()
    while IFS= read -r line; do
        [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]] && brews+=("$line")
    done < "$BREWS_FILE"
    print_info "Found ${#brews[@]} Homebrew packages"
else
    print_warning "Brews file not found: $BREWS_FILE"
fi

if [ -f "$CASKS_FILE" ]; then
    # Read casks using simple loop (compatible with all shells)
    casks=()
    while IFS= read -r line; do
        [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]] && casks+=("$line")
    done < "$CASKS_FILE"
    print_info "Found ${#casks[@]} Homebrew casks"
else
    print_warning "Casks file not found: $CASKS_FILE"
fi

if [ ${#brews[@]} -eq 0 ] && [ ${#casks[@]} -eq 0 ]; then
    print_warning "No packages found to install"
    exit 0
fi

# Create Brewfile content
BREWFILE_CONTENT=""
for brew in "${brews[@]}"; do
    BREWFILE_CONTENT+="brew \"$brew\""$'\n'
done
for cask in "${casks[@]}"; do
    BREWFILE_CONTENT+="cask \"$cask\""$'\n'
done

# Install packages using brew bundle
echo "Installing packages with Homebrew..."

if echo "$BREWFILE_CONTENT" | brew bundle --file=/dev/stdin; then
    echo "✓ Package installation completed successfully"
else
    print_error "Package installation failed"
    exit 1
fi
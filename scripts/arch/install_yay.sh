#!/bin/bash
set -e

# Color variables
readonly GREEN='\033[32m'
readonly RED='\033[31m'
readonly YELLOW='\033[33m'
readonly CYAN='\033[36m'
readonly NC='\033[0m' # No Color

# Function to show usage
show_usage() {
    echo "Usage: $0 [package_file]"
    echo ""
    echo "This script installs packages from AUR using yay."
    echo ""
    echo "Arguments:"
    echo "  package_file    Path to file containing package list (one per line)"
    echo "                  Defaults to './yay.packages'"
    echo ""
    echo "Packages can also be piped via stdin."
    echo ""
    echo "Note: This script requires yay to be installed."
    echo "If yay is not installed, it will show installation instructions."
}

# Function to install packages with yay
install_yay_packages() {
    local packages=("$@")
    local yay_success=()
    local yay_skipped=()
    local yay_failed=()

    # Check if yay is available
    if ! command -v yay &> /dev/null; then
        echo -e "${RED}✗ yay not found. Cannot install AUR packages.${NC}"
        echo ""
        echo "To install yay first:"
        echo "  sudo pacman -S --needed git base-devel"
        echo "  git clone https://aur.archlinux.org/yay.git"
        echo "  cd yay && makepkg -si"
        echo ""
        echo "Or use the pacman installer for repository packages."
        exit 1
    fi

    # Check if we have a proper terminal for sudo password input
    if ! tty -s; then
        echo -e "${RED}✗ No terminal detected. Cannot prompt for sudo password.${NC}"
        echo -e "${YELLOW}To run this script, use one of these methods:${NC}"
        echo ""
        echo -e "${CYAN}Method 1: Run in an interactive terminal:${NC}"
        echo "  ./scripts/arch/install_yay.sh"
        echo ""
        echo -e "${CYAN}Method 2: Establish sudo credentials first:${NC}"
        echo "  sudo -v"
        echo "  ./scripts/arch/install_yay.sh"
        echo ""
        echo -e "${CYAN}Method 3: Run with explicit sudo:${NC}"
        echo "  sudo bash ./scripts/arch/install_yay.sh"
        echo ""
        exit 1
    fi

    # Check if we can use sudo (for password prompts)
    if ! sudo -n true 2>/dev/null; then
        echo -e "${YELLOW}⚠ This script requires sudo privileges for package installation.${NC}"
        echo -e "${YELLOW}⚠ You will be prompted for your password.${NC}"
        echo ""
        # Pre-test sudo to ensure it works
        echo -e "${CYAN}Testing sudo access...${NC}"
        if ! sudo true; then
            echo -e "${RED}✗ Sudo authentication failed. Please check your password.${NC}"
            exit 1
        fi
        echo -e "${GREEN}✓ Sudo access confirmed${NC}"
        echo ""
    fi

    # Try to install all packages with yay
    for package in "${packages[@]}"; do
        echo -e "${CYAN}Installing $package...${NC}"

        # Run yay without capturing stderr to avoid confusing error messages
        # Use --needed to skip if already installed and --noconfirm to avoid interactive prompts
        if yay -S --needed --noconfirm "$package"; then
            # Check if package was actually installed or skipped
            if yay_output=$(yay -Qi "$package" 2>/dev/null); then
                local version
                version=$(echo "$yay_output" | grep "^Version" | cut -d':' -f2 | xargs)
                echo -e "${GREEN}✓ $package (version: $version) is installed${NC}"
                yay_success+=("$package")
            else
                echo -e "${YELLOW}⤷ $package was processed (may have been up to date)${NC}"
                yay_skipped+=("$package")
            fi
        else
            local exit_code=$?
            if [[ $exit_code -eq 1 ]]; then
                # Check if package already exists despite the error
                if yay_output=$(yay -Qi "$package" 2>/dev/null); then
                    local version
                    version=$(echo "$yay_output" | grep "^Version" | cut -d':' -f2 | xargs)
                    echo -e "${GREEN}✓ $package (version: $version) is installed${NC}"
                    yay_success+=("$package")
                else
                    yay_failed+=("$package")
                    echo -e "${RED}✗ Failed to install $package from AUR${NC}"
                fi
            else
                yay_failed+=("$package")
                echo -e "${RED}✗ Failed to install $package from AUR (exit code: $exit_code)${NC}"
            fi
        fi
        echo ""
    done

    # Print comprehensive statistics
    print_yay_statistics "${#packages[@]}" "${#yay_success[@]}" "${#yay_skipped[@]}" "${#yay_failed[@]}"

    if [[ ${#yay_failed[@]} -gt 0 ]]; then
        return 1
    fi

    return 0
}

# Function to print yay installation statistics
print_yay_statistics() {
    local total_packages=$1
    local yay_installed=$2
    local yay_skipped=$3
    local failed=$4

    echo -e "${YELLOW}=== YAY AUR Installation Statistics ===${NC}"
    echo -e "Total packages processed: ${CYAN}${total_packages}${NC}"
    echo ""
    echo -e "${GREEN}✓ Successfully installed from AUR: ${yay_installed}${NC}"
    echo ""
    echo -e "${YELLOW}⤷ Already installed (skipped): ${yay_skipped}${NC}"
    echo ""
    if [[ $failed -gt 0 ]]; then
        echo -e "${RED}✗ Failed to install: ${failed}${NC}"
    else
        echo -e "${GREEN}✓ No failures encountered${NC}"
    fi
    echo ""
    # Success rate: packages that were successfully installed
    local success_rate=0
    if [[ $total_packages -gt 0 ]]; then
        success_rate=$(( yay_installed * 100 / total_packages ))
    fi
    echo -e "${YELLOW}Installation success rate: ${success_rate}% (${yay_installed}/${total_packages})${NC}"
}

# Check for help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

# Determine package source
local_package_file=""
if [[ -n "$1" ]]; then
    local_package_file="$1"
elif [[ -f "./yay.packages" ]]; then
    local_package_file="./yay.packages"
elif [[ -f "$(dirname "$0")/yay.packages" ]]; then
    local_package_file="$(dirname "$0")/yay.packages"
fi

# Install packages
# First check for stdin input by testing if there's actual data
stdin_has_data=false
if [[ ! -t 0 ]]; then
    # Read a small sample to check if there's actual data
    if IFS= read -r sample_line; then
        stdin_has_data=true
        # Put the first line back for full processing
        { echo "$sample_line"; cat; } > /tmp/stdin_content_$$_tmp
    fi
fi

if [[ "$stdin_has_data" == true ]]; then
    echo "Installing packages from stdin..."
    # Read packages from temp file, filtering out empty lines and comments
    mapfile -t packages < <(grep -v '^#' /tmp/stdin_content_$$_tmp | grep -v '^$')
    rm -f /tmp/stdin_content_$$_tmp
    if [[ ${#packages[@]} -gt 0 ]]; then
        install_yay_packages "${packages[@]}" || {
            echo "Failed to install some packages from stdin"
            exit 1
        }
    else
        echo "No valid packages found in stdin"
        exit 1
    fi
elif [[ -n "$local_package_file" ]]; then
    if [[ -f "$local_package_file" ]]; then
        echo "Installing packages from $local_package_file..."
        mapfile -t packages < <(grep -v '^#' "$local_package_file" | grep -v '^$')
        if [[ ${#packages[@]} -gt 0 ]]; then
            install_yay_packages "${packages[@]}" || {
                echo "Failed to install some packages from $local_package_file"
                exit 1
            }
        else
            echo "No packages found in $local_package_file"
            exit 1
        fi
    else
        echo "Error: Package file '$local_package_file' not found"
        exit 1
    fi
else
    echo "Error: No package file found and no packages piped from stdin"
    echo "Use './yay.packages' or pipe packages from stdin"
    exit 1
fi

echo "YAY AUR package installation completed successfully!"
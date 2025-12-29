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
    echo "Usage: $0 [options] [package_file]"
    echo ""
    echo "This script installs packages from official repositories using pacman."
    echo ""
    echo "Arguments:"
    echo "  package_file    Path to file containing package list (one per line)"
    echo "                  Defaults to './pacman.packages'"
    echo ""
    echo "Options:"
    echo "  --base          Install only base packages from './pacman.packages'"
    echo "  --extra         Install only extra packages from './pacman_extra.packages'"
    echo "  --all           Install all packages from both base and extra files"
    echo "  -h, --help      Show this help message"
    echo ""
    echo "If no option is specified, defaults to --base behavior."
    echo ""
    echo "Packages can also be piped via stdin."
}

# Function to install packages with pacman
install_pacman_packages() {
    local packages=("$@")
    local pacman_success=()
    local pacman_skipped=()
    local pacman_failed=()

    # Try to install all packages with pacman, preserving installation output
    for package in "${packages[@]}"; do
        # First check if package exists in repositories
        if ! pacman -Ss "^${package}$" &> /dev/null; then
            echo -e "${RED}✗ Package '$package' not found in repositories${NC}"
            pacman_failed+=("$package")
            continue
        fi

        # Try to install with pacman, showing full installation output
        local pacman_output
        if pacman_output=$(sudo pacman -S --noconfirm --needed "$package" 2>&1); then
            # Check if package is up to date (show only first line)
            if echo "$pacman_output" | grep -q "up to date -- skipping"; then
                local first_line
                first_line=$(echo "$pacman_output" | head -1)
                # Add color to the package name using echo -e for proper escape sequence handling
                echo -e "${first_line//${package}/${GREEN}${package}${NC}}"
                pacman_skipped+=("$package")
            # Check if there is nothing to do
            elif echo "$pacman_output" | grep -q "there is nothing to do"; then
                echo "warning: ${GREEN}${package}${NC} is up to date -- skipping"
                pacman_skipped+=("$package")
            # Otherwise show full installation output (new installation)
            else
                echo "$pacman_output"
                echo -e "${GREEN}✓ $package installed successfully${NC}"
            fi

            if sudo pacman -Qi "$package" &> /dev/null; then
                pacman_success+=("$package")
            else
                pacman_failed+=("$package")
                echo -e "${RED}✗ Failed to install $package${NC}"
            fi
        else
            pacman_failed+=("$package")
            echo -e "${RED}✗ Failed to install $package${NC}"
        fi
    done

    # Print comprehensive statistics
    echo ""
    print_pacman_statistics "${#packages[@]}" "${#pacman_success[@]}" "${#pacman_skipped[@]}" "${#pacman_failed[@]}"

    if [[ ${#pacman_failed[@]} -gt 0 ]]; then
        return 1
    fi

    return 0
}

# Function to print pacman installation statistics
print_pacman_statistics() {
    local total_packages=$1
    local pacman_installed=$2
    local pacman_skipped=$3
    local failed=$4

    echo -e "${YELLOW}=== Pacman Installation Statistics ===${NC}"
    echo -e "Total packages processed: ${CYAN}${total_packages}${NC}"
    echo ""
    echo -e "${GREEN}✓ Successfully installed: ${pacman_installed}${NC}"
    echo ""
    echo -e "${YELLOW}⤷ Already installed (skipped): ${pacman_skipped}${NC}"
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
        success_rate=$(( pacman_installed * 100 / total_packages ))
    fi
    echo -e "${YELLOW}Installation success rate: ${success_rate}% (${pacman_installed}/${total_packages})${NC}"
}

# Function to install packages from multiple files
install_from_files() {
    local files=("$@")
    local all_packages=()

    # Collect packages from all files
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            echo -e "${CYAN}Reading packages from $file...${NC}"
            mapfile -t file_packages < <(grep -v '^#' "$file" | grep -v '^$')
            all_packages+=("${file_packages[@]}")
            echo -e "${GREEN}  Found ${#file_packages[@]} packages${NC}"
        else
            echo -e "${RED}Warning: Package file '$file' not found, skipping${NC}"
        fi
    done

    if [[ ${#all_packages[@]} -gt 0 ]]; then
        echo -e "${CYAN}Installing ${#all_packages[@]} total packages...${NC}"
        install_pacman_packages "${all_packages[@]}"
    else
        echo -e "${RED}Error: No valid packages found in any file${NC}"
        exit 1
    fi
}

# Initialize variables
install_mode="base"  # Default to base mode
local_package_file=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --base)
            install_mode="base"
            shift
            ;;
        --extra)
            install_mode="extra"
            shift
            ;;
        --all)
            install_mode="all"
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            echo -e "${RED}Error: Unknown option $1${NC}"
            show_usage
            exit 1
            ;;
        *)
            local_package_file="$1"
            shift
            ;;
    esac
done

# Determine default package file if not specified
if [[ -z "$local_package_file" ]]; then
    if [[ -f "./pacman.packages" ]]; then
        local_package_file="./pacman.packages"
    elif [[ -f "$(dirname "$0")/pacman.packages" ]]; then
        local_package_file="$(dirname "$0")/pacman.packages"
    fi
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
        install_pacman_packages "${packages[@]}" || {
            echo "Failed to install some packages from stdin"
            exit 1
        }
    else
        echo "No valid packages found in stdin"
        exit 1
    fi
elif [[ -n "$local_package_file" ]]; then
    # Determine extra package file path
    extra_package_file=""
    if [[ -f "./pacman_extra.packages" ]]; then
        extra_package_file="./pacman_extra.packages"
    elif [[ -f "$(dirname "$0")/pacman_extra.packages" ]]; then
        extra_package_file="$(dirname "$0")/pacman_extra.packages"
    fi

    # Handle different installation modes
    case "$install_mode" in
        "base")
            echo -e "${CYAN}Installing base packages...${NC}"
            install_from_files "$local_package_file" || {
                echo "Failed to install some base packages"
                exit 1
            }
            ;;
        "extra")
            echo -e "${CYAN}Installing extra packages...${NC}"
            if [[ -n "$extra_package_file" ]]; then
                install_from_files "$extra_package_file" || {
                    echo "Failed to install some extra packages"
                    exit 1
                }
            else
                echo -e "${RED}Error: pacman_extra.packages not found${NC}"
                exit 1
            fi
            ;;
        "all")
            echo -e "${CYAN}Installing all packages (base + extra)...${NC}"
            if [[ -n "$extra_package_file" ]]; then
                install_from_files "$local_package_file" "$extra_package_file" || {
                    echo "Failed to install some packages from files"
                    exit 1
                }
            else
                echo -e "${YELLOW}Warning: pacman_extra.packages not found, installing from base file only${NC}"
                install_from_files "$local_package_file" || {
                    echo "Failed to install some packages from $local_package_file"
                    exit 1
                }
            fi
            ;;
    esac
else
    echo "Error: No package file found and no packages piped from stdin"
    echo "Use './pacman.packages' or pipe packages from stdin"
    exit 1
fi

echo "Pacman package installation completed successfully!"
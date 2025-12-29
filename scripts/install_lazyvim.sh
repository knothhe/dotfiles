#!/bin/bash

# LazyVim Installation Script
# Based on installation guide from https://www.lazyvim.org/installation

set -e

# Source common functions for consistent UI
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
COMMON_FUNCTIONS="$PARENT_DIR/home/dot_local/xbin/common_functions.sh"

# Source common functions - this is required, not optional
if [ -f "$COMMON_FUNCTIONS" ]; then
    source "$COMMON_FUNCTIONS"
else
    echo "ERROR: Required common_functions.sh not found at $COMMON_FUNCTIONS"
    exit 1
fi

# Default values
BACKUP_DIR=""
SKIP_BACKUP=false
SKIP_PREREQS=false

# Neovim directories to backup
NVIM_DIRS=(
    "$HOME/.config/nvim"
    "$HOME/.local/share/nvim"
    "$HOME/.local/state/nvim"
    "$HOME/.cache/nvim"
)

# Prerequisites to check (core requirements)
PREREQS=("git" "fd" "curl" "rg" "nvim")

# Optional prerequisites
OPTIONAL_PREREQS=("tree-sitter-cli")

# Function to check if color output is supported
supports_color() {
    # Check if NO_COLOR environment variable is set
    if [ -n "$NO_COLOR" ]; then
        return 1
    fi

    # Check common TERM values that support color
    case "$TERM" in
        xterm*|screen*|tmux*|rxvt*|konsole*|gnome*|alacritty*|kitty*|xterm-ghostty)
            return 0
            ;;
        *)
            # Fallback: enable colors unless explicitly disabled
            return 0
            ;;
    esac
}


# Function to show usage
show_usage() {
    cat << EOF
LazyVim Installation Script

USAGE:
    install_lazyvim.sh [options]

OPTIONS:
    -b, --backup-dir DIR    Backup directory (default: create timestamped backup in current directory)
    -s, --skip-backup      Skip backup of existing Neovim configuration
    -p, --skip-prereqs     Skip prerequisite checking
    -h, --help            Show this help message

EXAMPLES:
    install_lazyvim.sh
    install_lazyvim.sh -b ~/backups
    install_lazyvim.sh -s -p

DESCRIPTION:
    This script installs LazyVim by:
    1. Checking prerequisites (git, fd, curl, ripgrep/rg, nvim)
       Optional: tree-sitter-cli
    2. Detecting existing Neovim configuration and asking for confirmation
    3. Backing up existing Neovim configuration (optional)
    4. Cloning LazyVim starter configuration
    5. Removing git history to start fresh
    6. Verifying installation

INTERACTIVE FEATURES:
    - If existing Neovim configuration is detected, you will be asked to:
      1) Continue with backup (recommended)
      2) Continue without backup (irreversible)
      3) Cancel installation

LAZYVIM STARTER:
    https://github.com/LazyVim/starter

POST-INSTALLATION:
    After installation, run ':LazyHealth' in Neovim to verify the installation.
EOF
}


# Function to check prerequisites
check_prerequisites() {
    print_title "Checking Prerequisites"

    local missing_prereqs=()
    local missing_optional=()

    # Check core prerequisites
    echo -e "\n${YELLOW_BOLD}Core Requirements:${NC}"
    for prereq in "${PREREQS[@]}"; do
        if command -v "$prereq" >/dev/null 2>&1; then
            local version
            case "$prereq" in
                nvim)
                    version=$("$prereq" --version | head -n1)
                    print_success "$prereq: $version"
                    ;;
                git)
                    version=$("$prereq" --version | head -n1)
                    print_success "$prereq: $version"
                    ;;
                rg)
                    version=$("$prereq" --version | head -n1)
                    print_success "ripgrep: $version"
                    ;;
                *)
                    version=$("$prereq" --version 2>/dev/null || echo "installed")
                    print_success "$prereq: $version"
                    ;;
            esac
        else
            # Show user-friendly name for rg
            local display_name="$prereq"
            [ "$prereq" = "rg" ] && display_name="ripgrep"
            print_error "$display_name: not found"
            missing_prereqs+=("$display_name")
        fi
    done

    # Check optional prerequisites
    echo -e "\n${YELLOW_BOLD}Optional Requirements:${NC}"
    for prereq in "${OPTIONAL_PREREQS[@]}"; do
        if command -v "$prereq" >/dev/null 2>&1; then
            local version=$("$prereq" --version 2>/dev/null || echo "installed")
            print_success "$prereq: $version"
        else
            print_warning "$prereq: not found (optional)"
            missing_optional+=("$prereq")
        fi
    done

    if [ ${#missing_prereqs[@]} -gt 0 ]; then
        echo -e "\n${RED_BOLD}Missing core prerequisites:${NC}"
        for prereq in "${missing_prereqs[@]}"; do
            echo "  - $prereq"
        done

        echo -e "\n${YELLOW_BOLD}Installation instructions:${NC}"
        echo "On macOS (using Homebrew):"
        echo "  brew install git fd curl ripgrep neovim"
        if [ ${#missing_optional[@]} -gt 0 ]; then
            echo "  # Optional:"
            echo "  brew install tree-sitter"
        fi
        echo ""
        echo "On Ubuntu/Debian:"
        echo "  sudo apt install git fd-find curl ripgrep neovim"
        if [ ${#missing_optional[@]} -gt 0 ]; then
            echo "  # Optional:"
            echo "  sudo apt install tree-sitter-cli"
        fi
        echo ""
        echo "On Fedora:"
        echo "  sudo dnf install git fd-find curl ripgrep neovim lazygit"
        if [ ${#missing_optional[@]} -gt 0 ]; then
            echo "  # Optional:"
            echo "  sudo dnf install tree-sitter-cli"
        fi
        echo ""
        echo "On Arch Linux:"
        echo "  sudo pacman -S git fd curl ripgrep neovim"
        if [ ${#missing_optional[@]} -gt 0 ]; then
            echo "  # Optional:"
            echo "  sudo pacman -S tree-sitter"
        fi

        return 1
    fi

    if [ ${#missing_optional[@]} -gt 0 ]; then
        echo -e "\n${YELLOW_BOLD}Note:${NC} Some optional dependencies are missing."
        echo "LazyVim will work without them, but you may want to install them later:"
        for prereq in "${missing_optional[@]}"; do
            echo "  - $prereq"
        done
    fi

    return 0
}

# Function to check for existing Neovim configuration and ask for confirmation
check_existing_config() {
    local existing_dirs=()

    # Check for existing Neovim directories
    for dir in "${NVIM_DIRS[@]}"; do
        if [ -e "$dir" ]; then
            existing_dirs+=("$dir")
        fi
    done

    # If no existing configuration found, return success
    if [ ${#existing_dirs[@]} -eq 0 ]; then
        print_success "No existing Neovim configuration found"
        return 0
    fi

    # Found existing configuration, ask for confirmation
    print_title "Existing Neovim Configuration Detected"

    echo -e "\n${YELLOW_BOLD}Found the following Neovim configuration directories:${NC}"
    for dir in "${existing_dirs[@]}"; do
        local size=""
        if [ -d "$dir" ]; then
            # Calculate directory size in a simple way
            local file_count=$(find "$dir" -type f 2>/dev/null | wc -l)
            size="($file_count files)"
        elif [ -f "$dir" ]; then
            size="($(du -h "$dir" 2>/dev/null | cut -f1))"
        fi

        # Shorten home directory path for cleaner display
        local display_dir="$dir"
        if [[ "$dir" == "$HOME/"* ]]; then
            display_dir="~/${dir#$HOME/}"
        fi

        # Calculate padding for alignment
        local dir_length=${#display_dir}
        local padding=$((50 - dir_length))
        local pad_spaces=$(printf "%*s" "$padding" | tr ' ' ' ')

        printf "  ${CYAN_BOLD}%s${NC} %s %s\n" "$display_dir" "$pad_spaces" "$size"
    done

    echo -e "\n${RED_BOLD}LazyVim installation will replace your existing Neovim configuration.${NC}"
    echo -e "\n${YELLOW_BOLD}Options:${NC}"
    echo -e "  1) ${GREEN_BOLD}Continue with backup${NC}     - Backup existing configuration and install LazyVim"
    echo -e "  2) ${YELLOW_BOLD}Continue without backup${NC} - Overwrite existing configuration (irreversible)"
    echo -e "  3) ${RED_BOLD}Cancel${NC}                - Abort installation"

    while true; do
        echo -n -e "\n${CYAN_BOLD}Your choice (1/2/3):${NC} "
        read -r choice

        case "$choice" in
            1)
                print_success "Proceeding with backup and installation"
                return 0
                ;;
            2)
                print_warning "Proceeding without backup (existing configuration will be lost)"
                SKIP_BACKUP=true
                return 0
                ;;
            3)
                print_warning "Installation cancelled by user"
                echo "Your existing Neovim configuration was not modified."
                exit 0
                ;;
            *)
                print_error "Invalid choice. Please enter 1, 2, or 3."
                ;;
        esac
    done
}

# Function to create backup
create_backup() {
    if [ "$SKIP_BACKUP" = true ]; then
        print_warning "Skipping backup as requested"
        return 0
    fi

    print_title "Creating Backup"

    local backup_timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_base="${BACKUP_DIR:-$HOME/.config/lazyvim_backup_$backup_timestamp}"

    echo "Backup base directory: $backup_base"

    local backed_up_something=false

    # Create backup base directory
    mkdir -p "$backup_base"

    for dir in "${NVIM_DIRS[@]}"; do
        if [ -e "$dir" ]; then
            # Create meaningful backup names based on original path
            case "$dir" in
                "$HOME/.config/nvim")
                    local backup_name="config"
                    ;;
                "$HOME/.local/share/nvim")
                    local backup_name="share"
                    ;;
                "$HOME/.local/state/nvim")
                    local backup_name="state"
                    ;;
                "$HOME/.cache/nvim")
                    local backup_name="cache"
                    ;;
                *)
                    local backup_name=$(basename "$dir")
                    ;;
            esac

            local backup_path="$backup_base/$backup_name"

            # Shorten paths for display
            local display_source="$dir"
            local display_target="$backup_path"
            if [[ "$dir" == "$HOME/"* ]]; then
                display_source="~/${dir#$HOME/}"
            fi
            if [[ "$backup_path" == "$HOME/"* ]]; then
                display_target="~/${backup_path#$HOME/}"
            fi

            echo -e "Backing up: ${CYAN_BOLD}$display_source${NC} → ${GREEN_BOLD}$display_target${NC}"

            # Handle conflicts - if backup target already exists, remove it first
            if [ -e "$backup_path" ]; then
                echo "Removing existing backup target: $backup_path"
                rm -rf "$backup_path"
            fi

            if mv "$dir" "$backup_path"; then
                print_success "Backed up: $backup_name"
                backed_up_something=true
            else
                print_error "Failed to backup: $backup_name"
                return 1
            fi
        fi
    done

    if [ "$backed_up_something" = false ]; then
        print_warning "No existing Neovim configuration found to backup"
        # Remove empty backup directory if nothing was backed up
        rmdir "$backup_base" 2>/dev/null || true
    else
        print_success "Backup completed: $backup_base"
        echo ""
        echo -e "${CYAN_BOLD}Backup structure:${NC}"
        # Shorten backup base path for display
        local display_backup="$backup_base"
        if [[ "$backup_base" == "$HOME/"* ]]; then
            display_backup="~/${backup_base#$HOME/}"
        fi
        echo "  ${CYAN_BOLD}$display_backup/${NC}"
        echo "  ├── ${GREEN_BOLD}config${NC}  (from ~/.config/nvim)"
        echo "  ├── ${GREEN_BOLD}share${NC}   (from ~/.local/share/nvim)"
        echo "  ├── ${GREEN_BOLD}state${NC}   (from ~/.local/state/nvim)"
        echo "  └── ${GREEN_BOLD}cache${NC}   (from ~/.cache/nvim)"
    fi

    return 0
}

# Function to install LazyVim
install_lazyvim() {
    print_title "Installing LazyVim"

    local nvim_config_dir="$HOME/.config/nvim"
    local lazyvim_repo="https://github.com/LazyVim/starter"

    echo "Cloning LazyVim starter configuration..."
    echo "Repository: $lazyvim_repo"
    echo "Target directory: $nvim_config_dir"

    # Clone the starter configuration
    if git clone "$lazyvim_repo" "$nvim_config_dir"; then
        print_success "Cloned LazyVim starter to: $nvim_config_dir"
    else
        print_error "Failed to clone LazyVim starter"
        return 1
    fi

    # Remove git history to start fresh
    echo "Removing git history..."
    if rm -rf "$nvim_config_dir/.git"; then
        print_success "Removed git history"
    else
        print_warning "Failed to remove git history (not critical)"
    fi

    return 0
}

# Function to verify installation
verify_installation() {
    print_title "Verifying Installation"

    local nvim_config_dir="$HOME/.config/nvim"

    if [ ! -d "$nvim_config_dir" ]; then
        print_error "Neovim configuration directory not found: $nvim_config_dir"
        return 1
    fi

    # Check for key LazyVim files
    local key_files=("init.lua" "lua")
    local missing_files=()

    for file in "${key_files[@]}"; do
        local target_path="$nvim_config_dir/$file"
        if [ -e "$target_path" ]; then
            print_success "Found: $file"
        else
            print_error "Missing: $file"
            missing_files+=("$file")
        fi
    done

    if [ ${#missing_files[@]} -gt 0 ]; then
        print_error "Installation verification failed - missing key files"
        return 1
    fi

    print_success "Installation verification passed"
    return 0
}

# Function to show next steps
show_next_steps() {
    print_title "Next Steps"

    echo -e "\n${GREEN_BOLD}LazyVim has been successfully installed!${NC}"
    echo ""
    echo "1. Start Neovim:"
    echo "   ${YELLOW_BOLD}nvim${NC}"
    echo ""
    echo "2. Verify installation in Neovim:"
    echo "   ${YELLOW_BOLD}:LazyHealth${NC}"
    echo ""
    echo "3. Explore LazyVim:"
    echo "   ${YELLOW_BOLD}:Lazy${NC}           - Open Lazy UI"
    echo "   ${YELLOW_BOLD}:Mason${NC}          - Manage LSP, formatters, linters"
    echo "   ${YELLOW_BOLD}:Telescope${NC}      - Fuzzy finder"
    echo ""
    echo "4. Configuration files:"
    echo "   ${YELLOW_BOLD}~/.config/nvim/lua/config/options.lua${NC}    - Basic options"
    echo "   ${YELLOW_BOLD}~/.config/nvim/lua/config/keymaps.lua${NC}    - Key mappings"
    echo "   ${YELLOW_BOLD}~/.config/nvim/lua/plugins/${NC}              - Custom plugins"
    echo ""
    echo "Documentation: ${COLOR_BLUE}https://www.lazyvim.org${NC}"
    echo ""
    echo -e "${CYAN_BOLD}Enjoy your new Neovim setup! 🚀${NC}"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -b|--backup-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -s|--skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        -p|--skip-prereqs)
            SKIP_PREREQS=true
            shift
            ;;
        -*)
            print_error "Unknown option: $1"
            echo "Use -h or --help for usage information."
            exit 1
            ;;
        *)
            print_error "Invalid argument: $1"
            echo "Use -h or --help for usage information."
            exit 1
            ;;
    esac
done

# Main installation process
main() {
    print_title "LazyVim Installation Script"
    echo "This script will install LazyVim Neovim configuration"
    echo "Based on: https://www.lazyvim.org/installation"

    # Check prerequisites
    if [ "$SKIP_PREREQS" = false ]; then
        if ! check_prerequisites; then
            print_error "Prerequisites check failed. Use -p to skip this check."
            exit 1
        fi
    else
        print_warning "Skipping prerequisites check as requested"
    fi

    # Check for existing configuration and ask for confirmation
    check_existing_config

    # Create backup
    if ! create_backup; then
        print_error "Backup creation failed"
        exit 1
    fi

    # Install LazyVim
    if ! install_lazyvim; then
        print_error "LazyVim installation failed"
        exit 1
    fi

    # Verify installation
    if ! verify_installation; then
        print_error "Installation verification failed"
        exit 1
    fi

    # Show next steps
    show_next_steps

    print_success "Installation completed successfully!"
}

# Run main function
main "$@"
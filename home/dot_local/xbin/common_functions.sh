#!/bin/bash

# Common Functions Library
# Contains color and formatting functions shared by multiple scripts

# OS Detection Functions
detect_os() {
    if [[ "$(uname)" == "Darwin" ]]; then
        echo "darwin"
    elif [[ "$(uname)" == "Linux" ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

is_darwin() {
    [[ "$(detect_os)" == "darwin" ]]
}

is_linux() {
    [[ "$(detect_os)" == "linux" ]]
}

get_os_info() {
    local os=$(detect_os)
    local arch=$(uname -m)
    local kernel=$(uname -r)

    case $os in
        "darwin")
            echo "macOS $arch (kernel $kernel)"
            ;;
        "linux")
            if [[ -f /etc/os-release ]]; then
                local distro=$(source /etc/os-release && echo "$PRETTY_NAME")
                echo "$distro $arch (kernel $kernel)"
            else
                echo "Linux $arch (kernel $kernel)"
            fi
            ;;
        *)
            echo "Unknown OS $arch (kernel $kernel)"
            ;;
    esac
}

get_os_specific_path() {
    local darwin_path="$1"
    local linux_path="$2"
    local default_path="${3:-$darwin_path}"

    if is_darwin; then
        echo "$darwin_path"
    elif is_linux; then
        echo "$linux_path"
    else
        echo "$default_path"
    fi
}

# Print OS information
print_os_info() {
    print_info "Operating System" "$(get_os_info)"
}

# Color definitions
BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# Bold color variants
GREEN_BOLD='\033[1;32m'
RED_BOLD='\033[1;31m'
YELLOW_BOLD='\033[1;33m'
BLUE_BOLD='\033[1;34m'
CYAN_BOLD='\033[1;36m'
MAGENTA_BOLD='\033[1;35m'
WHITE_BOLD='\033[1;37m'

# Print colored title
print_title() {
    local title="$1"
    local width=60
    local line=""
    local i

    # Create separator line
    for ((i=0; i<width; i++)); do
        line+="═"
    done

    echo -e "${CYAN}$line${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}$title${NC}"
    echo -e "${CYAN}$line${NC}"
    echo
}

# Print simple title (minimal formatting)
print_simple_title() {
    local title="$1"
    echo -e "${CYAN_BOLD}$title${NC}"
}

# Print information with border
print_info() {
    echo -e "${BLUE}┌${NC} ${BOLD}$1${NC}"
    echo -e "${BLUE}└${NC} $2"
    echo
}

# Print success message
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Print error message
print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Print warning message
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Print header message (simple colored text)
print_header() {
    echo -e "${BLUE_BOLD}$1${NC}"
}

# Print highlighted text
print_highlight() {
    echo -e "${CYAN_BOLD}$1${NC}"
}

# Print success bold message
print_success_bold() {
    echo -e "${GREEN_BOLD}$1${NC}"
}

# Print colored text with custom color
print_colored_text() {
    local color="$1"
    local text="$2"
    echo -e "${color}$text${NC}"
}

# Print progress message
print_progress() {
    echo -e "${YELLOW}⏳${NC} $1"
}

# Print separator line
print_separator() {
    echo -e "${CYAN}$(printf '─%.0s' {1..60})${NC}"
}

# Display completion information
print_completion() {
    print_title "All operations completed successfully"
    echo -e "${GREEN}🎉${NC} ${BOLD}All tasks completed successfully!${NC}"
}

# Display completion information only if completion messages are not suppressed
print_completion_conditional() {
    # Only print completion if completion messages are not suppressed
    if [[ -z "$SUPPRESS_COMPLETION_MESSAGES" ]]; then
        print_completion
    fi
}

# Display error information
print_failure() {
    local failed_operation="$1"
    echo
    print_info "Operation Failed" "Failed at: ${RED}$failed_operation${NC}"
}

# ============================================================================
# GIT OPERATIONS
# ============================================================================

# Generic git sync function - Sync any git repository to remote
# Usage: git_sync <directory_path> [repository_name]
git_sync() {
    local sync_dir="$1"
    local repo_name="${2:-$(basename "$sync_dir")}"
    local commit_message="Auto-sync $repo_name changes $(date '+%Y-%m-%d %H:%M:%S')"

    # Check if directory exists
    if [ ! -d "$sync_dir" ]; then
        print_error "Directory $sync_dir does not exist"
        return 1
    fi

    # Check if it's a git repository
    if [ ! -d "$sync_dir/.git" ]; then
        print_error "Not a git repository in $sync_dir"
        return 1
    fi

    print_progress "Syncing $repo_name repository..."

    # Change to the repository directory
    local current_dir
    current_dir=$(pwd)
    cd "$sync_dir" || return 1

    # Check if there are uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        print_progress "Detected uncommitted changes. Adding and committing..."

        # Add all modified and untracked files
        git add -A

        # Commit changes
        if git commit -m "$commit_message"; then
            print_success "Changes committed successfully"
        else
            print_warning "No changes to commit (possibly empty commit)"
        fi
    else
        print_info "Status" "No changes to commit"
    fi

    # Pull latest changes from remote repository
    print_progress "Pulling latest changes from remote repository..."
    if git pull; then
        print_success "Successfully pulled latest changes from remote"
    else
        print_warning "Failed to pull latest changes. Continuing with sync..."
    fi

    # Push to remote repository
    print_progress "Pushing changes to remote repository..."
    if git push; then
        print_success "Successfully pushed changes to remote"
    else
        print_error "Failed to push changes"
        cd "$current_dir"
        return 1
    fi

    # Return to original directory
    cd "$current_dir"
    return 0
}

# ============================================================================
# FILE AND PATH OPERATIONS
# ============================================================================

# Expand tilde in path to home directory
expand_path() {
    echo "$1" | sed "s|^~|$HOME|"
}

# Check if directory exists, print error if it does
check_directory_exists() {
    local dir="$1"
    local expanded_dir
    expanded_dir=$(expand_path "$dir")

    if [ -d "$expanded_dir" ]; then
        print_error "Directory already exists: $expanded_dir"
        return 1
    fi
    return 0
}

# Ensure directory exists, create if it doesn't
ensure_directory() {
    local dir="$1"
    local expanded_dir
    expanded_dir=$(expand_path "$dir")

    if [ ! -d "$expanded_dir" ]; then
        mkdir -p "$expanded_dir" || {
            print_error "Failed to create directory: $expanded_dir"
            return 1
        }
        print_success "Created directory: $expanded_dir"
    fi
    echo "$expanded_dir"
}

# Check if file exists and is not empty
validate_file() {
    local file="$1"
    local description="${2:-File}"

    if [ ! -f "$file" ]; then
        print_error "$description does not exist: $file"
        return 1
    fi

    if [ ! -s "$file" ]; then
        print_error "$description is empty: $file"
        return 1
    fi

    return 0
}

# Create temporary file securely
create_temp_file() {
    local prefix="${1:-tmp}"
    local tmp_file

    tmp_file=$(mktemp -t "${prefix}.XXXXXX") || {
        print_error "Failed to create temporary file"
        return 1
    }

    chmod 600 "$tmp_file"
    echo "$tmp_file"
}

# ============================================================================
# DEPENDENCY CHECKING
# ============================================================================

# Check if required commands are available
check_dependencies() {
    local missing_deps=()
    local dep

    for dep in "$@"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        return 1
    fi

    return 0
}

# Check for common clipboard tools
check_clipboard_tools() {
    if is_linux; then
        if command -v wl-copy >/dev/null 2>&1 && command -v wl-paste >/dev/null 2>&1; then
            echo "wayland"
        elif command -v xclip >/dev/null 2>&1; then
            echo "x11"
        else
            return 1
        fi
    elif is_darwin; then
        if command -v pbcopy >/dev/null 2>&1 && command -v pbpaste >/dev/null 2>&1; then
            echo "macos"
        else
            return 1
        fi
    else
        return 1
    fi
}

# ============================================================================
# INTERACTIVE PROMPTS AND USER INPUT
# ============================================================================

# Wait for user input before continuing
wait_for_user() {
    echo
    echo -e "${BLUE}Press any key to continue...${NC}"
    read -n 1 -s
    echo
}

# Unified confirmation prompt
confirm_action() {
    local message="$1"
    local default="${2:-n}"  # y or n
    local prompt

    if [[ "$default" == "y" ]]; then
        prompt="$message (Y/n)"
    else
        prompt="$message (y/N)"
    fi

    echo -e "${YELLOW}$prompt${NC}"
    read -r response

    if [ -z "$response" ]; then
        # Return based on default value
        if [[ "$default" == "y" ]]; then
            return 0
        else
            return 1
        fi
    elif [[ "$response" =~ ^[yY]([eE][sS])?$ ]]; then
        return 0
    else
        return 1
    fi
}

# Prompt for user input with validation
prompt_input() {
    local prompt="$1"
    local default="$2"
    local validation_pattern="$3"
    local error_message="$4"
    local input

    while true; do
        if [ -n "$default" ]; then
            echo -e "${BLUE}$prompt${NC} (${YELLOW}default: $default${NC}):" >&2
        else
            echo -e "${BLUE}$prompt${NC}:" >&2
        fi

        read -r input

        if [ -z "$input" ] && [ -n "$default" ]; then
            echo "$default"
            return 0
        fi

        if [ -n "$validation_pattern" ]; then
            if [[ "$input" =~ $validation_pattern ]]; then
                echo "$input"
                return 0
            else
                if [ -n "$error_message" ]; then
                    print_error "$error_message"
                else
                    print_error "Invalid input format"
                fi
            fi
        else
            echo "$input"
            return 0
        fi
    done
}

# ============================================================================
# CLIPBOARD OPERATIONS
# ============================================================================

# Copy text to clipboard (cross-platform)
copy_to_clipboard() {
    local text="$1"

    if [[ -z "$text" ]]; then
        print_error "No text provided to copy"
        return 1
    fi

    if is_linux; then
        if command -v wl-copy >/dev/null 2>&1; then
            echo -n "$text" | wl-copy
        elif command -v xclip >/dev/null 2>&1; then
            echo -n "$text" | xclip -selection clipboard
        else
            print_error "No clipboard utility found (wl-copy or xclip). Please install wl-clipboard or xclip."
            return 1
        fi
    elif is_darwin; then
        if command -v pbcopy >/dev/null 2>&1; then
            echo -n "$text" | pbcopy
        else
            print_error "pbcopy not found"
            return 1
        fi
    else
        print_error "Unsupported platform"
        return 1
    fi
}

# Get text from clipboard (cross-platform)
get_from_clipboard() {
    if is_linux; then
        if command -v wl-paste >/dev/null 2>&1; then
            wl-paste
        elif command -v xclip >/dev/null 2>&1; then
            xclip -selection clipboard -o
        else
            print_error "No clipboard utility found (wl-paste or xclip). Please install wl-clipboard or xclip."
            return 1
        fi
    elif is_darwin; then
        if command -v pbpaste >/dev/null 2>&1; then
            pbpaste
        else
            print_error "pbpaste not found"
            return 1
        fi
    else
        print_error "Unsupported platform"
        return 1
    fi
}

# ============================================================================
# ERROR HANDLING AND SCRIPT MANAGEMENT
# ============================================================================

# Safe exit with user confirmation
safe_exit() {
    local exit_code="${1:-1}"
    if [ "$exit_code" -eq 0 ]; then
        exit 0
    else
        wait_for_user
        exit "$exit_code"
    fi
}

# Script cleanup function
cleanup() {
    local temp_files=("$@")
    for file in "${temp_files[@]}"; do
        [[ -f "$file" ]] && rm -f "$file"
    done
}

# Set up script directory sourcing
setup_script_environment() {
    local script_file="${1:-${BASH_SOURCE[1]}}"
    local script_dir
    script_dir="$(cd "$(dirname "$script_file")" && pwd)"

    # Source common functions if not already sourced
    if ! command -v print_title >/dev/null 2>&1; then
        local common_functions="$script_dir/common_functions.sh"
        if [[ -f "$common_functions" ]]; then
            source "$common_functions"
        else
            echo "Error: common_functions.sh not found at $common_functions" >&2
            exit 1
        fi
    fi

    echo "$script_dir"
}

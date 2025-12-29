#!/bin/bash
# Chrome Extension Downloader
# Downloads and manages Chrome extensions with checksum verification

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/extensions.json"
# For testing: uncomment to use test config
# CONFIG_FILE="/tmp/test_config/local_test.json"

# Default download directory
DEFAULT_DOWNLOAD_DIR="${HOME}/Workspace/ChromeExtensions"

# Parse command line arguments
DOWNLOAD_DIR="$DEFAULT_DOWNLOAD_DIR"
FORCE_DOWNLOAD=false
KEEP_SOURCE_FILES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            # Show help immediately
            echo "Chrome Extension Downloader"
            echo "Downloads and extracts Chrome extensions with checksum verification"
            echo
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  -d, --directory DIR    Directory to download extensions to"
            echo "                          Default: $DEFAULT_DOWNLOAD_DIR"
            echo "  -f, --force           Force re-download even if files exist"
            echo "  -k, --keep            Keep source archive files after extraction"
            echo "                          Default: delete source files after successful extraction"
            echo "  -h, --help            Show this help message"
            echo
            echo "Configuration:"
            echo "  Edit $CONFIG_FILE to configure extensions"
            echo
            echo "Behavior:"
            echo "  - Downloads and extracts Chrome extensions with checksum verification"
            echo "  - Automatically deletes source archive files after successful extraction"
            echo "  - Use -k/--keep to preserve source files if needed"
            echo
            echo "Examples:"
            echo "  $0                                    # Use default download directory"
            echo "  $0 -d ~/Downloads/extensions          # Use custom download directory"
            echo "  $0 --directory /tmp/chrome-extensions # Use temporary directory"
            echo "  $0 -f                                 # Force re-download all extensions"
            echo "  $0 -d ~/ext -f                        # Force re-download to custom directory"
            echo "  $0 -k                                 # Keep source files after extraction"
            echo "  $0 -f -k                              # Force re-download and keep source files"
            echo
            exit 0
            ;;
        -d|--directory)
            DOWNLOAD_DIR="$2"
            shift 2
            ;;
        -f|--force)
            FORCE_DOWNLOAD=true
            shift
            ;;
        -k|--keep)
            KEEP_SOURCE_FILES=true
            shift
            ;;
        *)
            # Unknown option
            print_error "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Source common functions from installed location
if [[ -f "$HOME/.local/xbin/common_functions.sh" ]]; then
    source "$HOME/.local/xbin/common_functions.sh"
else
    echo "ERROR: common_functions.sh not found at ~/.local/xbin/common_functions.sh" >&2
    echo "Please ensure the dotfiles are properly applied with chezmoi" >&2
    exit 1
fi

# Function to download file with curl
download_file() {
    local url="$1"
    local output_file="$2"

    print_header "Downloading: $(basename "$output_file")"

    if curl -fsSL --progress-bar -o "$output_file" "$url"; then
        print_success "Download completed: $(basename "$output_file")"
        return 0
    else
        print_error "Failed to download: $url"
        return 1
    fi
}

# Function to calculate SHA256 checksum
calculate_checksum() {
    local file="$1"

    # Use sha256sum if available, fallback to shasum
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | cut -d' ' -f1
    else
        print_error "No checksum calculation tool found (sha256sum or shasum)"
        return 1
    fi
}

# Function to extract archive
extract_archive() {
    local archive_file="$1"
    local extract_dir="$2"
    local filename=$(basename "$archive_file")

    print_header "Extracting: $filename"

    ensure_directory "$extract_dir"

    case "$filename" in
        *.zip)
            if unzip -q -o "$archive_file" -d "$extract_dir"; then
                print_success "Successfully extracted: $filename"
                return 0
            else
                print_error "Failed to extract ZIP: $filename"
                return 1
            fi
            ;;
        *.crx)
            # CRX files are ZIP files with a header
            # Remove the first 30 bytes (CRX header) and extract as ZIP
            if tail -c +31 "$archive_file" | unzip -q -d "$extract_dir"; then
                print_success "Successfully extracted CRX: $filename"
                return 0
            else
                print_error "Failed to extract CRX: $filename"
                return 1
            fi
            ;;
        *)
            print_warning "Unsupported archive format: $filename"
            return 0
            ;;
    esac
}

# Function to get file extension from URL or content-type
get_file_extension() {
    local url="$1"
    local filename="$2"

    # First try to get extension from URL
    if [[ "$url" =~ \.(zip|crx|tar\.gz|tgz)$ ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi

    # If no extension in URL, try to detect from filename or content-type
    local extension=""
    case "$filename" in
        *.zip|*.crx|*.tar.gz|*.tgz)
            extension="${filename##*.}"
            # Handle .tar.gz case
            if [[ "$filename" =~ \.tar\.gz$ ]]; then
                extension="tar.gz"
            fi
            ;;
        *)
            # Default to zip for Chrome extensions if we can't determine
            extension="zip"
            ;;
    esac

    echo "$extension"
}

# Function to update checksum in JSON file
update_checksum_in_json() {
    local name="$1"
    local checksum="$2"
    local temp_file="${CONFIG_FILE}.tmp"

    # Use jq to update the checksum if available, otherwise use sed
    if command -v jq >/dev/null 2>&1; then
        jq --arg name "$name" --arg checksum "$checksum" \
            '(.extensions[] | select(.name == $name) | .checksum.hash) = $checksum' \
            "$CONFIG_FILE" > "$temp_file"
        mv "$temp_file" "$CONFIG_FILE"
        print_success "Updated checksum for $name in $CONFIG_FILE"
    else
        # Fallback to sed (less robust)
        print_warning "jq not found, using sed to update JSON (less reliable)"
        sed -i.tmp "s/\"name\": \"$name\",[[:space:]]*\"url\"/[\"name\": \"$name\", \"url\"/" "$CONFIG_FILE"
        # This is a simplified approach - jq is strongly recommended
        print_error "Please install jq for proper JSON manipulation"
        rm -f "$temp_file" "$CONFIG_FILE.tmp"
        return 1
    fi
}

# Function to get checksum from JSON
get_checksum_from_json() {
    local name="$1"

    if command -v jq >/dev/null 2>&1; then
        jq -r ".extensions[] | select(.name == \"$name\") | .checksum.hash" "$CONFIG_FILE"
    else
        print_warning "jq not found, cannot reliably parse JSON for checksum"
        return 1
    fi
}

# Main download function
download_extension() {
    local name="$1"
    local url="$2"

    print_simple_title "Processing Extension: $name"

    # Get file extension
    local extension=$(get_file_extension "$url" "$name")
    local source_file="${name}.${extension}"
    local source_path="${DOWNLOAD_DIR}/${source_file}"
    local extract_dir="${DOWNLOAD_DIR}/${name}"

    # Create download directory
    ensure_directory "$DOWNLOAD_DIR"

    # Check if extension is already installed and handle based on force flag
    if [[ -f "$extract_dir/manifest.json" && "$FORCE_DOWNLOAD" == false ]]; then
        print_success "Extension $name already installed, skipping download"
        print_success "Use -f/--force to re-download"
        echo
        return 0
    fi

    # Download the file
    if ! download_file "$url" "$source_path"; then
        return 1
    fi

    # Calculate checksum
    print_header "Calculating checksum"
    local calculated_checksum=$(calculate_checksum "$source_path")
    if [[ -z "$calculated_checksum" ]]; then
        print_error "Failed to calculate checksum"
        return 1
    fi

    print_success "Calculated checksum: $calculated_checksum"

    # Get existing checksum from JSON
    local existing_checksum=$(get_checksum_from_json "$name")

    if [[ -z "$existing_checksum" || "$existing_checksum" == "null" || "$existing_checksum" == "" ]]; then
        # No checksum exists, update the JSON
        print_header "No existing checksum found, updating JSON"
        update_checksum_in_json "$name" "$calculated_checksum"
    else
        # Verify checksum
        if [[ "$calculated_checksum" == "$existing_checksum" ]]; then
            print_success "Checksum verification passed"
        else
            print_error "Checksum mismatch!"
            print_error "Expected: $existing_checksum"
            print_error "Calculated: $calculated_checksum"
            return 1
        fi
    fi

    # Extract the archive
    if extract_archive "$source_path" "$extract_dir"; then
        # Delete source file after successful extraction (unless keep flag is set)
        if [[ "$KEEP_SOURCE_FILES" == false ]]; then
            print_header "Cleaning up source file"
            if rm -f "$source_path"; then
                print_success "Deleted source file: $(basename "$source_path")"
            else
                print_warning "Failed to delete source file: $(basename "$source_path")"
            fi
        else
            print_success "Keeping source file: $(basename "$source_path")"
        fi

        print_success "Extension $name processed successfully"
        echo
    else
        print_error "Failed to extract extension $name"
        return 1
    fi
}

# Main execution
main() {
    print_title "Chrome Extension Downloader"

    # Display download directory
    print_header "Download Directory: $DOWNLOAD_DIR"

    # Check dependencies
    local deps=("curl" "unzip")
    if command -v jq >/dev/null 2>&1; then
        deps+=("jq")
    else
        print_warning "jq not found - JSON manipulation will be limited"
    fi
    if ! check_dependencies "${deps[@]}"; then
        print_error "Please install missing dependencies"
        return 1
    fi

    # Check if config file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Configuration file not found: $CONFIG_FILE"
        return 1
    fi

    # Parse extensions from JSON and download each one
    if command -v jq >/dev/null 2>&1; then
        local extensions=()
        while IFS= read -r name; do
            extensions+=("$name")
        done < <(jq -r '.extensions[].name' "$CONFIG_FILE")

        local urls=()
        while IFS= read -r url; do
            urls+=("$url")
        done < <(jq -r '.extensions[].url' "$CONFIG_FILE")

        local success_count=0
        local total_count=${#extensions[@]}

        for ((i=0; i<total_count; i++)); do
            if download_extension "${extensions[i]}" "${urls[i]}"; then
                success_count=$((success_count + 1))
            fi
        done

        print_title "Download Summary"
        print_success "Successfully processed: $success_count/$total_count extensions"

        if [[ $success_count -eq $total_count ]]; then
            print_success "All extensions downloaded and verified successfully!"
        else
            print_warning "Some extensions failed to process"
            return 1
        fi
    else
        print_error "jq is required for JSON parsing"
        return 1
    fi
}

# Run main function
main
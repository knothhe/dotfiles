#!/bin/bash

set -eufo pipefail

# Function to add source line to shell config if it doesn't exist
add_source_line() {
    local source_line="$1"
    local config_file="$2"
    local file_name="$3"

    if grep -qF "$source_line" "$config_file" 2>/dev/null; then
        echo "$file_name source line already exists in $config_file"
        return 0
    else
        echo "$source_line" >> "$config_file"
        echo "Added $file_name source line to $config_file"
        return 0
    fi
}

# Determine the operating system
OS="$(uname)"
if [[ "$OS" == "Darwin" ]]; then
    # macOS - use .zshrc
    SHELL_CONFIG="$HOME/.zshrc"
else
    # Linux - use .bashrc
    SHELL_CONFIG="$HOME/.bashrc"
fi

# Create shell config file if it doesn't exist
touch "$SHELL_CONFIG" 2>/dev/null || {
    echo "Cannot create $SHELL_CONFIG"
    exit 1
}

# Source files to add
SOURCE_FILES=(
    "xshrc:source ~/.config/xshrc/rc"
)

# Add all source files
for source_entry in "${SOURCE_FILES[@]}"; do
    file_name="${source_entry%%:*}"
    source_line="${source_entry#*:}"
    add_source_line "$source_line" "$SHELL_CONFIG" "$file_name"
done

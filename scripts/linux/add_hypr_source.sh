#!/bin/bash

set -eufo pipefail

# Function to add source line to hyprland config if it doesn't exist
add_source_line() {
    local source_line="$1"
    local config_file="$2"
    local comment="$3"
    local file_name="$4"

    if grep -qF "$source_line" "$config_file" 2>/dev/null; then
        echo "$file_name source line already exists in $config_file"
        return 0
    else
        # Add comment if provided
        if [[ -n "$comment" ]]; then
            echo "# $comment" >> "$config_file"
        fi
        echo "$source_line" >> "$config_file"
        echo "Added $file_name source line to $config_file"
        if [[ -n "$comment" ]]; then
            echo "  with comment: $comment"
        fi
        return 0
    fi
}

# Configuration
HYPRLAND_CONFIG="$HOME/.config/hypr/hyprland.conf"
CUSTOM_CONFIG_PATH="$HOME/.config/hypr/custom.conf"

# Check if custom config exists
if [[ ! -f "$CUSTOM_CONFIG_PATH" ]]; then
    echo "Custom config file not found: $CUSTOM_CONFIG_PATH"
    exit 1
fi

# Check if hyprland config exists
if [[ ! -f "$HYPRLAND_CONFIG" ]]; then
    echo "Hyprland config file not found: $HYPRLAND_CONFIG"
    exit 1
fi

# Create hyprland config file if it doesn't exist
touch "$HYPRLAND_CONFIG" 2>/dev/null || {
    echo "Cannot create $HYPRLAND_CONFIG"
    exit 1
}

# Source files to add
SOURCE_LINE="source = ~/.config/hypr/custom.conf"
COMMENT="Custom configuration overrides"

# Add source line
add_source_line "$SOURCE_LINE" "$HYPRLAND_CONFIG" "$COMMENT" "custom.conf"

echo "Hyprland configuration updated successfully!"
echo "Please restart Hyprland for changes to take effect."
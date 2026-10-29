#!/bin/bash
# Add personal Lua rules after Omarchy defaults without replacing the main config.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../home/dot_local/xbin/common_functions.sh"

HYPRLAND_CONFIG="$HOME/.config/hypr/hyprland.lua"
CUSTOM_CONFIG_PATH="$HOME/.config/hypr/custom.lua"

validate_file "$HYPRLAND_CONFIG" "Hyprland Lua configuration"
validate_file "$CUSTOM_CONFIG_PATH" "Personal window rules"
ensure_line_in_file 'require("hypr.custom")' "$HYPRLAND_CONFIG"
print_success "Personal rules load after Omarchy defaults."
print_info "Validation" "Run hyprctl reload followed by hyprctl configerrors in your Hyprland session."

#!/bin/bash

# Closes the active window, with optional confirmation for specific apps

set -e
source "$HOME/.local/xbin/common_functions.sh"

# Classes that require confirmation
CONFIRM_APPS=(
  "chromium"
  "code"
  # Add more applications here
)

# Get the current window class
CLASS="$(hyprctl activewindow -j | jq -r '.class // ""')"

# If class not listed, close immediately
if [[ ! " ${CONFIRM_APPS[*]} " =~ " ${CLASS} " ]]; then
  hyprctl eval 'hl.dispatch(hl.dsp.window.close())'
  exit 0
fi

# Confirmation is needed - tracked using a temp file
CONFIRM_FILE="/tmp/omarchy-confirm-close-${CLASS:-global}"
NOW="$(date +%s)"
LAST="$(stat -c %Y "$CONFIRM_FILE" 2>/dev/null || echo 0)"

# If SUPER+W pressed again within 3s, confirm and close
if [ $((NOW - LAST)) -le 3 ]; then
  rm -f -- "$CONFIRM_FILE"
  hyprctl eval 'hl.dispatch(hl.dsp.window.close())'
else
  # Otherwise: record the attempt and show a reminder
  echo "$NOW" > "$CONFIRM_FILE"
  omarchy osd --message "SUPER + W again to confirm"
fi

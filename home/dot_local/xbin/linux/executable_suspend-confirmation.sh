#!/bin/bash

# Suspends the computer with double-key confirmation

CONFIRM_FILE="/tmp/omarchy-confirm-suspend"
NOW="$(date +%s)"
LAST="$(stat -c %Y "$CONFIRM_FILE" 2>/dev/null || echo 0)"

# If SUPER+CTRL+X pressed again within 3s, confirm and suspend
if [ $((NOW - LAST)) -le 3 ]; then
  rm -f -- "$CONFIRM_FILE"
  systemctl suspend
else
  # Otherwise: record the attempt and show a reminder
  echo "$NOW" > "$CONFIRM_FILE"
  swayosd-client --custom-message "SUPER + CTRL + X again to suspend"
fi

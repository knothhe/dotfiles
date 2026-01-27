#!/bin/bash
selected=$(cliphist list | fzf \
    --preview 'echo {} | cliphist decode' \
    --preview-window 'right:50%:wrap' \
    --layout reverse \
    --border \
    --prompt '📋 ' \
    --header 'Clipboard History (Enter to copy, Esc to cancel)')

[[ -n "$selected" ]] && echo "$selected" | cliphist decode | wl-copy

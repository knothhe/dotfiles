#!/bin/bash

set -eufo pipefail

defaults write org.gpgtools.common UseKeychain NO
# Purpose: Completely disable the Command + Shift + / (⌘⇧/) shortcut in Google Chrome on macOS
# This shortcut normally opens the "Search menus" / help menu search feature.
# Setting it to 'nil' removes / disables the key equivalent for that menu item,
# effectively preventing the shortcut from triggering anything in Chrome.
defaults write com.google.Chrome NSUserKeyEquivalents -dict-add 'Search menus' nil
# Remove all custom key equivalents (or use -dict-remove for just one)
# defaults delete com.google.Chrome NSUserKeyEquivalents

# For mouse only (disable natural scrolling for mouse)
defaults write com.apple.trackpad.scrollBehavior -int 0 # or 2
defaults write com.apple.mouse.scrollBehavior -int 0    # traditional scroll

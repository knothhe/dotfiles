-- Omarchy defaults load first; replace only these personal shortcuts.
-- Unbind before binding to avoid running both the default and custom action.

hl.unbind("SUPER + ALT + RETURN")
o.bind("SUPER + ALT + RETURN", "Tmux", "uwsm-app -- $HOME/.local/xbin/linux/xdg-terminal-exec --dir=\"$(omarchy-cmd-terminal-cwd)\" tmux new")

hl.unbind("SUPER + SHIFT + ALT + B")
o.bind("SUPER + SHIFT + ALT + B", "Browser (private)", "omarchy-launch-browser --private")

hl.unbind("SUPER + SHIFT + CTRL + O")
o.bind("SUPER + SHIFT + CTRL + O", "NormCap", "flatpak run com.github.dynobo.normcap")

hl.unbind("SUPER + SHIFT + CTRL + X")
o.bind("SUPER + SHIFT + CTRL + X", "Flameshot", "flameshot gui")

hl.unbind("SUPER + SHIFT + B")
o.bind("SUPER + SHIFT + B", "Browser", "omarchy-launch-browser")

hl.unbind("SUPER + SHIFT + D")
o.bind("SUPER + SHIFT + D", "Docker", "omarchy-launch-tui lazydocker")

hl.unbind("SUPER + SHIFT + F")
o.bind("SUPER + SHIFT + F", "File manager", "uwsm-app -- nautilus --new-window")

hl.unbind("SUPER + ALT + SHIFT + F")
o.bind("SUPER + ALT + SHIFT + F", "File manager (cwd)", "uwsm-app -- nautilus --new-window \"$(omarchy-cmd-terminal-cwd)\"")

hl.unbind("SUPER + SHIFT + O")
o.bind("SUPER + SHIFT + O", "Obsidian", "omarchy-launch-or-focus ^obsidian$ \"uwsm-app -- obsidian -disable-gpu --enable-wayland-ime\"")

-- Disable the default password-manager shortcut.
hl.unbind("SUPER + SHIFT + SLASH")

hl.unbind("SUPER + SHIFT + T")
o.bind("SUPER + SHIFT + T", "Activity", "omarchy-launch-tui btop")

hl.unbind("SUPER + RETURN")
o.bind("SUPER + RETURN", "Terminal", "uwsm-app -- $HOME/.local/xbin/linux/xdg-terminal-exec --dir=\"$(omarchy-cmd-terminal-cwd)\"")

hl.unbind("SUPER + SHIFT + RETURN")
o.bind("SUPER + SHIFT + RETURN", "Browser", "omarchy-launch-browser")

hl.unbind("SUPER + SHIFT + ALT + A")
o.bind("SUPER + SHIFT + ALT + A", "Grok", "omarchy-launch-or-focus-webapp Grok \"https://grok.com\"")

hl.unbind("SUPER + SHIFT + CTRL + A")
o.bind("SUPER + SHIFT + CTRL + A", "Alma", "omarchy-launch-or-focus ^alma$ \"uwsm-app -- /opt/Alma/alma\"")

hl.unbind("SUPER + SHIFT + A")
o.bind("SUPER + SHIFT + A", "Deepseek", "omarchy-launch-or-focus-webapp Deepseek \"https://chat.deepseek.com\"")

hl.unbind("SUPER + SHIFT + ALT + X")
o.bind("SUPER + SHIFT + ALT + X", "X Post", "omarchy-launch-webapp \"https://x.com/compose/post\"")

hl.unbind("SUPER + SHIFT + C")
o.bind("SUPER + SHIFT + C", "Calendar", "omarchy-launch-or-focus-webapp Calendar \"https://calendar.google.com/calendar\"")

hl.unbind("SUPER + SHIFT + E")
o.bind("SUPER + SHIFT + E", "Email", "omarchy-launch-or-focus-webapp Gmail \"https://gmail.com\"")

hl.unbind("SUPER + SHIFT + L")
o.bind("SUPER + SHIFT + L", "Linkding", "omarchy-launch-or-focus-webapp Linkding \"https://linkding.guanglai.me\"")

hl.unbind("SUPER + SHIFT + M")
o.bind("SUPER + SHIFT + M", "Music", "omarchy-launch-or-focus-webapp Music \"https://music.163.com/st/webplayer\"")

hl.unbind("SUPER + SHIFT + N")
o.bind("SUPER + SHIFT + N", "Memos", "omarchy-launch-or-focus-webapp Memos \"https://memos.guanglai.me\"")

hl.unbind("SUPER + SHIFT + S")
o.bind("SUPER + SHIFT + S", "Translate", "omarchy-launch-or-focus-webapp Translate \"https://chatgpt.com/translate\"")

hl.unbind("SUPER + SHIFT + X")
o.bind("SUPER + SHIFT + X", "X", "omarchy-launch-or-focus-webapp X-Twitter \"https://x.com/\"")

hl.unbind("SUPER + SHIFT + Y")
o.bind("SUPER + SHIFT + Y", "YouTube", "omarchy-launch-or-focus-webapp YouTube \"https://youtube.com/\"")

hl.unbind("SUPER + W")
o.bind("SUPER + W", "Close active window", "$HOME/.local/xbin/hypr/close-confirmation.sh")

-- External-monitor brightness controls (also available while locked).
hl.unbind("XF86MonBrightnessUp")
o.bind("XF86MonBrightnessUp", "Monitor brightness up", "~/.local/xbin/linux/monitor_brightness up", { locked = true, repeating = true })
hl.unbind("XF86MonBrightnessDown")
o.bind("XF86MonBrightnessDown", "Monitor brightness down", "~/.local/xbin/linux/monitor_brightness down", { locked = true, repeating = true })

# Dotfiles Manager with Chezmoi

> Cross-platform development environment managed with [Chezmoi](https://www.chezmoi.io/)

A comprehensive dotfiles repository providing automated setup, synchronization utilities, and development tools for macOS and Linux.

## ✨ Key Features

- **🔧 Shell Environment**: Modular bash/zsh configuration with proxy management
- **🔄 Git Synchronization**: Auto-sync utilities for pass, Obsidian, Rime, and general repos
- **🤖 AI Integration**: Pre-configured Claude Code and OpenCode environments (BigModel primary)
- **🖼️ Image Tools**: Clipboard image management and cloud upload (x_pic)
- **🔐 Password Management**: Interactive fzf-based password interface (pass_fzf)
- **⌨️ Input Methods**: Complete fcitx5 configuration with Catppuccin theme
- **🖥️ Terminal**: Ghostty configuration with CJK support
- **📦 Package Management**: Automated installation via Makefile
- **🔑 SSH Management**: Encrypted key storage for multiple services
- **🎨 Development**: LazyVim, Hyprland/skhd, and tool configurations
- **🤖 AI Tools**: OpenCode launcher with Obsidian workspace integration
- **📚 Agent Skills**: Pre-configured skills for Hyprland development

## 📁 Structure

```
dotfiles/
├── home/
│   ├── dot_config/           # Configuration files
│   │   ├── xshrc/           # Shell environment (modular)
│   │   ├── git/             # Git configuration
│   │   ├── ghostty/         # Terminal settings
│   │   ├── fcitx5/          # Linux input method
│   │   ├── hypr/            # Hyprland WM config
│   │   ├── nvim/            # Neovim/LazyVim
│   │   ├── skhd/            # macOS window manager
│   │   ├── opencode/        # OpenCode configuration
│   │   └── agents/          # Global AI agent guidelines
│   ├── dot_local/xbin/      # Custom scripts & utilities
│   ├── private_dot_*        # Encrypted configs (SSH, GPG)
│   └── dot_claude/          # Claude Code setup
├── scripts/                 # Installation & setup scripts
├── Makefile               # Build automation
└── docs/                  # Utility documentation
```

## 🚀 Installation

```bash
# Initialize chezmoi
chezmoi init git@github.com:knothhe/dotfiles.git

# Apply all dotfiles
chezmoi apply

# Apply all dotfiles and ignore pass and encrypt files
chezmoi apply --exclude=encrypted --override-data '{"excludePassFile": true}'
```

Automatically detects OS and configures shell environment (`.zshrc` for macOS, `.bashrc` for Linux).

## 🛠️ Core Utilities

### Git Synchronization
```bash
pass_sync      # Sync password store
ob_sync        # Sync Obsidian vault
rime_sync      # Sync input method config
x_sync         # Master sync orchestrator
```

### Development Tools
```bash
x_clone        # Interactive repo cloning
x_pic          # Clipboard image management
pass_fzf       # Interactive password manager
x_sharding     # Database table sharding tool
x_opencode     # OpenCode launcher
```

### Build Automation
```bash
make help                           # List all targets
make install_lazyvim                # Install LazyVim
make install_pacman_packages        # Install Arch pacman packages
make install_yay_packages           # Install Arch AUR packages
make install_flatpak_packages       # Install Flatpak packages
make install_darwin_packages        # Install macOS packages
make download_chrome_extensions     # Download Chrome extensions
```

## 🔧 Configuration

### Proxy Manager
```bash
proxyon [host:port] [username:password]  # Activate proxy
proxyoff                                # Deactivate proxy
proxyinfo                               # Check status
```

### Shell Environment
- **Modular structure**: Configuration in `~/.config/xshrc/` with separate components
- **Cross-platform**: Automatic OS detection and platform-specific settings
- **AI Integration**: Pre-configured Claude Code and OpenCode with BigModel primary

### Template Usage
```bash
# Add encrypted file
chezmoi add --encrypt ~/.ssh/id_rsa

# Add template file
chezmoi add --template ~/.config/xshrc/envs

# Use secrets in templates
{{ pass "secret/token" }}

# OS-specific configuration
{{- if eq .chezmoi.os "darwin" }}
# macOS settings
{{- end }}
```

## 📋 Key Scripts & Tools

- **`x_pic`**: Cross-platform clipboard image management with format conversion and upload
- **`pass_fzf`**: Interactive password selection with generation; press `Ctrl-T` to switch between single and batch modes
- **`x_clone`**: Interactive repository cloning with branch support
- **`x_sharding`**: Database table sharding tool for SQL schema transformation
- **`x_sync`**: Master synchronization orchestrator
- **`x_opencode`**: OpenCode launcher with Obsidian workspace integration
- **`x_launchagent`** (macOS): LaunchAgent management utility
- **`common_functions.sh`**: Shared utility library for all scripts

## 🔒 Security

- **Encrypted storage**: SSH keys and sensitive data encrypted with GPG
- **Password manager**: Integration with `pass` for secure token storage
- **Selective sync**: Configurable exclusion of sensitive files
- **Git integration**: Secure remote synchronization

## 📦 Dependencies

**Required**: Chezmoi, Git, Bash/Zsh

**Optional**: Pass, Fzf, Pwgen, Fcitx5, Ghostty, LazyVim, Skhd/Hyprland, OpenCode

## 📚 Agent Skills

Pre-configured skills for enhanced AI-assisted development.

### Hyprland Skill
- **Source**: [tobi/frameling](https://github.com/tobi/frameling/tree/master/.claude/skills/hyprland)
- **Location**: `.claude/skills/hyprland/`
- **Description**: Comprehensive Hyprland window manager reference with documentation, examples, and search utilities for configuration, keybindings, animations, window rules, and dispatchers.

## 📚 Documentation

See `AGENTS.md` for detailed development guidance and API documentation for custom utilities.

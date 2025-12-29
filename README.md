# Dotfiles Manager with Chezmoi

> Cross-platform development environment managed with [Chezmoi](https://www.chezmoi.io/)

A comprehensive dotfiles repository providing automated setup, synchronization utilities, and development tools for macOS and Linux.

## ✨ Key Features

- **🔧 Shell Environment**: Modular bash/zsh configuration with proxy management
- **🔄 Git Synchronization**: Auto-sync utilities for pass, Obsidian, Rime, and general repos
- **🤖 AI Integration**: Pre-configured Claude Code environment (BigModel primary)
- **🖼️ Image Tools**: Clipboard image management and cloud upload (x_pic)
- **🔐 Password Management**: Interactive fzf-based password interface (pass_fzf)
- **⌨️ Input Methods**: Complete fcitx5 configuration with Catppuccin theme
- **🖥️ Terminal**: Ghostty configuration with CJK support
- **📦 Package Management**: Automated installation via Makefile
- **🔑 SSH Management**: Encrypted key storage for multiple services
- **🎨 Development**: LazyVim, Hyprland/skhd, and tool configurations

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
│   │   └── skhd/            # macOS window manager
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
```

### Build Automation
```bash
make help                           # List all targets
make install_lazyvim                # Install LazyVim
make install_arch_packages          # Install Arch packages
make download_chrome_extensions     # Download extensions
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
- **AI Integration**: Pre-configured Claude Code with BigModel primary

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

- **`x_pic`**: Cross-platform clipboard image management
- **`pass_fzf`**: Interactive password selection with generation
- **`x_clone`**: Interactive repository cloning with branch support
- **`x_sync`**: Master synchronization orchestrator
- **`common_functions.sh`**: Shared utility library for all scripts

## 🔒 Security

- **Encrypted storage**: SSH keys and sensitive data encrypted with GPG
- **Password manager**: Integration with `pass` for secure token storage
- **Selective sync**: Configurable exclusion of sensitive files
- **Git integration**: Secure remote synchronization

## 📦 Dependencies

**Required**: Chezmoi, Git, Bash/Zsh

**Optional**: Pass, Fzf, Pwgen, Fcitx5, Ghostty, LazyVim, Skhd/Hyprland

## 📚 Documentation

See `CLAUDE.md` for detailed development guidance and API documentation for custom utilities.

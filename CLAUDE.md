# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a comprehensive chezmoi-managed dotfiles repository providing cross-platform development environment setup with automation, synchronization utilities, and AI tool integration. The repository uses chezmoi's Go template system for platform-specific configuration management and supports both macOS ("darwin") and Linux with specialized configurations.

## Key Architecture Components

### Template System
- Uses chezmoi Go templates with `.chezmoi.os`, `.chezmoi.arch`, `.chezmoi.username` variables
- Password manager integration via `{{ pass "token/..." }}` syntax
- OS-specific configurations with `{{ if eq .chezmoi.os "darwin" }}` conditionals
- Template files use `.tmpl` suffix

### Shared Function Library (`home/dot_local/xbin/common_functions.sh`)
All scripts source this shared library for consistent UI:
- `print_title()` - Colored title with borders
- `print_success()`, `print_error()`, `print_warning()` - Status messages
- `print_progress()` - Progress indicators
- `print_completion()` - Success summary
- `print_header()`, `print_highlight()`, `print_success_bold()` - Formatted text
- `check_dependencies()` - Dependency validation
- `ensure_directory()` - Directory creation with feedback
- Consistent color scheme: CYAN, GREEN, RED, YELLOW, BLUE, MAGENTA, WHITE

#### Common Functions Reuse Guidelines
**CRITICAL**: All scripts MUST maximize reuse of `common_functions.sh` functionality. Before writing any custom code, check if the functionality already exists in `common_functions.sh`.

##### Mandatory Requirements:
1. **Always source `common_functions.sh`** at the beginning of every script
2. **Never hardcode ANSI escape sequences** for colors or formatting
3. **Never duplicate existing functionality** - use functions from `common_functions.sh` instead
4. **Check `common_functions.sh` first** before writing any utility functions

##### Available Functions (non-exhaustive):
- **UI/Formatting**: `print_title()`, `print_success()`, `print_error()`, `print_warning()`, `print_progress()`, `print_completion()`, `print_header()`, `print_highlight()`, `print_success_bold()`, `print_colored_text()`
- **File/Directory**: `ensure_directory()`, `validate_file()`, `expand_path()`, `check_directory_exists()`, `create_temp_file()`, `create_temp_file_with_cleanup()`
- **Dependencies**: `check_dependencies()`, `check_clipboard_tools()`
- **Array/Data**: `array_contains()`, `array_get_index()`, `parse_config()`, `read_file_to_array()`
- **OS Detection**: `detect_os()`, `is_darwin()`, `is_linux()`, `get_os_info()`, `get_os_specific_path()`
- **User Input**: `confirm_action()`, `prompt_input()`, `wait_for_user()`
- **Clipboard**: `copy_to_clipboard()`, `get_from_clipboard()`
- **Git**: `git_sync()` (for repository synchronization)

##### Color Constants:
- **Colors**: `$GREEN`, `$RED`, `$YELLOW`, `$BLUE`, `$CYAN`, `$MAGENTA`, `$WHITE`
- **Bold Colors**: `$BOLD`, `$GREEN_BOLD`, `$RED_BOLD`, `$YELLOW_BOLD`, `$BLUE_BOLD`, `$CYAN_BOLD`
- **Reset**: `$NC` (No Color)

##### Before Writing Custom Code:
1. **Search `common_functions.sh`** for existing functionality
2. **Use existing functions** instead of writing custom implementations
3. **Add missing functions** to `common_functions.sh` if they are generally useful
4. **Keep scripts DRY** - Don't Repeat Yourself

##### Examples of Required Changes:
- ❌ `mkdir -p "$DIR"` → ✅ `ensure_directory "$DIR"`
- ❌ `echo -e "\033[1;34mText\033[0m"` → ✅ `echo -e "${BLUE_BOLD}Text${NC}"`
- ❌ `if command -v fzf >/dev/null 2>&1` → ✅ `check_dependencies fzf`
- ❌ Custom array parsing → ✅ `array_contains()`, `parse_config()`, `read_file_to_array()`

#### Exceptions: Simple Installation Scripts
**Note**: Platform-specific package installation scripts (`scripts/arch/install_pacman.sh`, `scripts/arch/install_yay.sh`, `scripts/darwin/install_packages.sh`) are intentionally kept simple without `common_functions.sh` dependency to ensure they work reliably in minimal environments. These scripts:

- Use basic echo statements for output instead of colored formatting
- Have minimal dependencies (only require standard shell utilities)
- Are designed to work even when the dotfiles repository is not fully applied
- Provide simple INFO/WARNING/ERROR messages for clarity

**Design Rationale**: Package installation scripts may run in bootstrap environments where the full `common_functions.sh` library is not yet available. These scripts prioritize reliability and minimal dependencies over UI consistency.

### Sync Utilities Architecture
- **`git_sync`** - Generic git repository sync (auto-pull, add, commit, push)
- **Specialized syncs** (`pass_sync`, `ob_sync`, `rime_sync`) - Wrap `git_sync` for specific repositories
- **`x_sync`** - Master orchestrator that runs multiple syncs in sequence
- **`x_clone`** - Interactive repository cloning tool with branch support
- **`x_pic`** - Cross-platform clipboard image management and upload tool
- **`pass_fzf`** - Interactive password selection and generation with fzf integration
- **`x_sharding`** - Database table sharding tool for SQL schema transformation
- **`x_launchagent`** (macOS) - LaunchAgent management utility
- **`Makefile`** - Build automation for common setup tasks (Chrome extensions, package installation, LazyVim)
- All use `common_functions.sh` for consistent output and error handling

## Development Commands

### Chezmoi Operations
```bash
chezmoi apply          # Apply all dotfiles
chezmoi apply ~/.local/xbin/x_pic # Only apply ~/.local/xbin/x_pic in this respository
chezmoi execute-template .chezmoi/scripts/run_once_setup.sh.tmpl # For test tmpl file
chezmoi status         # Check status
chezmoi diff           # Preview changes
chezmoi edit <file>    # Edit specific file
chezmoi add <file>     # Add file to management
chezmoi forget <file>  # Remove from management
```

### Shell Integration
```bash
# Source the shell config to test proxy functions
source ~/.zshrc  # or ~/.bashrc
proxyon [host:port] [username:password]
proxyoff
proxyinfo
```

### Configuration Files
- `home/dot_config/xshrc/` - Shell configuration and environment files (modular structure)
  - `rc` - Main shell configuration loader that sources all components
  - `envs` - Environment variables (Claude Code, XDG paths, PATH)
  - `alias` - Shell aliases for common commands
  - `functions` - Custom shell functions
  - `proxy` - Proxy management functions
  - `keybindings` - Shell-specific key mappings and bindings
  - `darwin` - macOS-specific configuration
  - `linux` - Linux-specific configuration
  - `tmpl.tmpl` - Template configuration file
- `home/dot_config/git/` - Git configuration
  - `config.tmpl` - Main git configuration template
  - `config_dev` - Development-specific git configuration
- `home/dot_config/ghostty/` - Terminal emulator configuration
  - `config.tmpl` - Ghostty settings with CJK support and cross-platform optimization
- `home/dot_config/fcitx5/` - Linux input method configuration
- `home/dot_config/hypr/` - Hyprland window manager configuration
  - `bindings.conf` - Key bindings configuration
  - `custom.conf` - Custom Hyprland settings
- `home/dot_config/x-export/` - Export configuration files
- `home/dot_config/fontconfig/` - Font configuration
- `home/dot_config/starship.toml` - Starship prompt configuration
- `home/dot_config/skhd/skhdrc` - macOS window management configuration
- `home/dot_config/nvim/` - Neovim configuration (LazyVim integration)
  - `lua/config/` - Configuration files
  - `lua/plugins/` - Plugin configurations
- `home/dot_ideavimrc` - IntelliJ IDEA Vim configuration
- `home/.chezmoi.toml.tmpl` - Main chezmoi configuration template
- `home/private_dot_gnupg/` - GPG configuration files
- `home/private_dot_ssh/` - SSH configuration and encrypted keys
- `home/dot_claude/` - Claude Code configuration and custom commands
- `home/dot_local/share/private_fcitx5/` - Fcitx5 themes and assets
- `home/dot_piclist/` - PicList image uploader configuration
- Template files use `.tmpl` suffix
- Environment-specific configs use chezmoi variables
- Shell configuration is modularized into separate components for better maintainability

### Build Automation
- `Makefile` - Root-level build automation with convenient targets for common setup tasks
- Chrome extension download and management targets
- Platform-specific package installation (Arch Linux pacman/yay, Flatpak, macOS)
- Global package installation (PicList via pnpm)
- Development environment setup (LazyVim installation)
- System service management (skhd for macOS)
- Window manager configuration (Hyprland source addition)
- Help target for discovering available commands

### Scripts Organization
- `scripts/chrome/` - Chrome extension management
  - `download_extension.sh` - Automated Chrome extension downloader
  - `extensions.json` - Extension definitions
- `scripts/darwin/` - macOS-specific setup
  - `install_packages.sh` - Package installation script
  - `darwin.brews`, `darwin.casks` - Package definitions
- `scripts/arch/` - Arch Linux packages
  - `install_pacman.sh` - Pacman package installation
  - `install_yay.sh` - Yay AUR helper installation
  - `pacman.packages`, `pacman_extra.packages`, `yay.packages` - Package lists
- `scripts/linux/` - Linux utilities
  - `install_flatpak.sh` - Flatpak installation
  - `add_hypr_source.sh` - Hyprland configuration helper
- `scripts/tampermonkey/` - Browser user scripts
- `scripts/install_lazyvim.sh` - LazyVim setup script
- `docs/` - Documentation for custom utilities
  - `x_launchagent.md`, `x_sharding.md`

## File Structure Conventions

### Executable Scripts
- `executable_*` prefix for scripts that should be executable
- Located in `home/dot_local/xbin/` (added to PATH via shell config)
- Use `#!/bin/bash` shebang and `set -e` for strict error handling

### Documentation and Comments
- All scripts include inline documentation
- Comments have been translated to English
- Function documentation includes purpose and parameters

## Security Considerations

### Password Manager Integration
- Uses `pass` password manager for sensitive data
- Tokens stored in password store with paths like `token/bigmodel/anthropic_auth_token`
- Template syntax: `{{ pass "token/..." }}`

### File Exclusions
- `.chezmoiignore` excludes sensitive directories and files
- `.ssh/` directory ignored for security
- Personal history files excluded

## Cross-Platform Support

### OS Detection
- Uses `.chezmoi.os` variable for platform-specific logic
- Supports macOS ("darwin") and Linux
- Conditional paths and commands based on OS

### Platform-Specific Implementations
- `rime_sync.tmpl` has different implementations for macOS (Squirrel) and Linux (Fcitx5)
- Shell configuration paths vary by platform (.zshrc vs .bashrc)
- OS-specific shell configs: `darwin` and `linux` files in xshrc directory
- **Linux input method support**: Complete fcitx5 configuration with Catppuccin theme
- **Shell configuration restructured**: Moved from `dot_config/dot_xshrc/` to `dot_config/xshrc/` with modular components
- **Terminal emulator**: Ghostty configuration with platform-specific font sizing and CJK support
- **Package management**: Platform-specific installation scripts for Arch Linux, Flatpak, and macOS
- **Window management**:
  - skhd integration for macOS tiling window management
  - Hyprland configuration support for Linux
- **Font configuration**: Cross-platform font management with fontconfig
- **Development environment**: LazyVim integration with platform-specific optimizations

## Common Development Patterns

### Error Handling
- All scripts use `set -e` for strict error handling
- Graceful degradation for non-critical failures
- Color-coded error messages with clear feedback

### Function Modularity
- Reusable functions in `common_functions.sh`
- Generic `git_sync` function reused by specialized scripts
- Master `x_sync` orchestrates multiple operations
- Interactive `x_clone` provides repository management with selection UI
- **Password management**: `pass_fzf` provides comprehensive password interface with generation options
- **Image processing**: `x_pic` handles cross-platform clipboard image extraction and upload

### Template Variables
- Available variables: `.chezmoi.os`, `.chezmoi.arch`, `.chezmoi.username`, `.chezmoi.hostname`
- Use `chezmoi data` get all variable
- Used for conditional configuration and personalization
- Enable cross-platform compatibility

## AI Tool Integration

### Claude Code Configuration
- Pre-configured in `dot_config/xshrc/envs`
- Supports multiple AI providers (Anthropic, BigModel, Moonshot)
- Environment variables for API endpoints and model selection
- Token management via password manager
- **Primary provider: BigModel** (glm-4.5) with Moonshot AI fallback
- Custom slash commands in `home/dot_claude/commands/` for enhanced workflow

### Custom Claude Commands
- `/commit` - Intelligent git commit generation with conventional commit format
- Commands are defined in `home/dot_claude/commands/` with markdown format
- Each command specifies allowed tools and provides structured task guidance

### Model Configuration
- Primary model: `glm-4.5` (BigModel)
- Fallback models: `glm-4.5-air` (BigModel), `kimi-k2-turbo-preview` (Moonshot AI)
- Configurable via environment variables

## Password Management Integration

### Pass + Fzf Interface
The `pass_fzf` tool provides comprehensive password management:
- **Interactive selection**: fzf-powered interface for password browsing
- **Multi-key operations**: Enter (copy), Ctrl+E (edit), Ctrl+G (generate)
- **Password generation**: Advanced options with custom character classes
- **Entry creation**: Support for new password entries with validation
- **Security features**: Automatic clipboard clearing (45 seconds)
- **Cross-platform**: Works on Linux and macOS with clipboard integration
- **Customizable**: Support for default password length and symbol preferences

### Dependencies
- `pass` - Password store core functionality
- `fzf` - Interactive fuzzy finder
- `pwgen` - Password generation tool
- `fd` - Fast file finding for password store traversal
- `gpg` - Encryption backend for password store

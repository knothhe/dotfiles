# Makefile for Chrome Extension Downloads and Arch Package Installation

# Default target
.DEFAULT_GOAL := help

# Chrome Extension targets
download_chrome_extensions:
	@./scripts/chrome/download_extension.sh

select_chrome_extensions:
	@./scripts/chrome/download_extension.sh --select

install_pacman_packages:
	@cd scripts/arch && ./install_pacman.sh

install_yay_packages:
	@cd scripts/arch && ./install_yay.sh

# Flatpak package installation
install_flatpak_packages:
	@cd scripts/linux && ./install_flatpak.sh

# macOS package installation
install_darwin_packages:
	@cd scripts/darwin && ./install_packages.sh

# enable macOS shkd
enable_darwin_skhd:
	@skhd --start-service

# Global npm/pnpm package installation
install_piclist:
	@pnpm install -g piclist

# LazyVim installation
install_lazyvim:
	@./scripts/install_lazyvim.sh

# Hyprland configuration
add_hypr_source:
	@./scripts/linux/add_hypr_source.sh

# Help
help:
	@echo "Available targets:"
	@echo "  download_chrome_extensions   - Download all Chrome extensions"
	@echo "  select_chrome_extensions     - Select and download Chrome extensions"
	@echo "  install_arch_packages        - Install Arch Linux base packages"
	@echo "  install_arch_extra_packages  - Install Arch Linux extra packages"
	@echo "  install_pacman_packages      - Install Pacman packages"
	@echo "  install_yay_packages         - Install Yay AUR helper and packages"
	@echo "  install_flatpak_packages     - Install Flatpak packages"
	@echo "  install_darwin_packages      - Install macOS packages"
	@echo "  enable_darwin_skhd           - Enable macOS skhd service"
	@echo "  install_piclist              - Install PicList globally via pnpm"
	@echo "  install_lazyvim              - Install LazyVim Neovim configuration"
	@echo "  add_hypr_source              - Add custom.conf source to Hyprland config"
	@echo "  help                         - Show this help"

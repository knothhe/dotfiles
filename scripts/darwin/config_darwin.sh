#!/bin/bash

# Configure macOS shell integration and the Browserpass native messaging host.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../home/dot_local/xbin/common_functions.sh"

readonly SUPPORTED_BROWSERS=(chromium chrome vivaldi brave firefox)
readonly BROWSER="${1:-chrome}"
readonly STARSHIP_INIT='eval "$(starship init zsh)"'

if ! is_darwin; then
    print_error "This configuration script is only supported on macOS"
    exit 1
fi

check_dependencies brew gpg jq make starship

ensure_line_in_file "$STARSHIP_INIT" "$HOME/.zshrc"

browser_supported=false
for supported_browser in "${SUPPORTED_BROWSERS[@]}"; do
    if [[ "$BROWSER" == "$supported_browser" ]]; then
        browser_supported=true
        break
    fi
done

if [[ "$browser_supported" != true ]]; then
    print_error "Unsupported browser: $BROWSER"
    print_info "Supported browsers" "${SUPPORTED_BROWSERS[*]}"
    exit 1
fi

print_progress "Configuring Browserpass for $BROWSER..."

browserpass_prefix="$(brew --prefix browserpass)"
PREFIX="$browserpass_prefix" make \
    -f "$browserpass_prefix/lib/browserpass/Makefile" \
    "hosts-${BROWSER}-user"

password_store_dir="${PASSWORD_STORE_DIR:-$HOME/.password-store}"
browserpass_config="$password_store_dir/.browserpass.json"
gpg_path="$(command -v gpg)"

if [[ ! -d "$password_store_dir" ]]; then
    print_error "Password store does not exist: $password_store_dir"
    exit 1
fi

temporary_config="$(create_temp_file browserpass)"
trap 'cleanup "$temporary_config"' EXIT

if [[ -f "$browserpass_config" ]]; then
    jq --arg gpg_path "$gpg_path" '.gpgPath = $gpg_path' \
        "$browserpass_config" > "$temporary_config"
else
    jq -n --arg gpg_path "$gpg_path" '{gpgPath: $gpg_path}' \
        > "$temporary_config"
fi

chmod 600 "$temporary_config"
mv "$temporary_config" "$browserpass_config"
trap - EXIT

print_success "Configured Browserpass to use $gpg_path"
print_success "macOS configuration completed"

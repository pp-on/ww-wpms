#!/bin/bash
#
# Webwerk WordPress Management Suite Installer
# Creates symbolic link for system-wide access
#

set -euo pipefail

# Colors for output
readonly RED='\e[31m'
readonly GREEN='\e[32m'
readonly YELLOW='\e[33m'
readonly CYAN='\e[36m'
readonly COLOR_OFF='\e[0m'

# Get script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WEBWERK_SCRIPT="${SCRIPT_DIR}/webwerk"
readonly INSTALL_DIR="${HOME}/.local/bin"
readonly LINK_PATH="${INSTALL_DIR}/webwerk"
readonly DDEV_LAUNCH_SRC="${SCRIPT_DIR}/ddev/commands/host/launch"
readonly DDEV_LAUNCH_DEST="${HOME}/.ddev/commands/host/launch"
readonly COMPLETIONS_SRC="${SCRIPT_DIR}/completions"

# Logging functions
log_info() {
    echo -e "${CYAN}[INFO]${COLOR_OFF} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${COLOR_OFF} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${COLOR_OFF} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${COLOR_OFF} $*" >&2
}

# Install DDEV global command overrides
install_ddev_commands() {
    local dest_dir
    dest_dir="$(dirname "$DDEV_LAUNCH_DEST")"

    # Skip if already installed
    if grep -q "WAYLAND_DISPLAY" "$DDEV_LAUNCH_DEST" 2>/dev/null; then
        log_info "DDEV launch command already customized, skipping"
        return 0
    fi

    mkdir -p "$dest_dir"
    cp "$DDEV_LAUNCH_SRC" "$DDEV_LAUNCH_DEST"
    chmod +x "$DDEV_LAUNCH_DEST"
    log_success "Installed custom DDEV launch command (WSL xdg-open fix)"
}

# Install shell completions for webwerk and ddev-wp
install_completions() {
    local bash_completion_dir="${HOME}/.bash_completion.d"
    local fish_dir="${HOME}/.config/fish/completions"
    local zsh_completion_dir="${HOME}/.local/share/zsh/completions"

    # ── Fish ──────────────────────────────────────────────────────────────────
    if command -v fish >/dev/null 2>&1; then
        mkdir -p "$fish_dir"
        for src in ddev-wp.fish webwerk.fish; do
            local dest="${fish_dir}/${src}"
            cp "${COMPLETIONS_SRC}/${src}" "$dest"
            log_success "Installed fish completion: $src"
        done
    else
        log_info "Fish not found, skipping fish completions"
    fi

    # ── Bash ──────────────────────────────────────────────────────────────────
    mkdir -p "$bash_completion_dir"
    for src in ddev-wp.bash webwerk.bash; do
        cp "${COMPLETIONS_SRC}/${src}" "${bash_completion_dir}/${src}"
        log_success "Installed bash completion: $src"
    done
    # Source the completion dir from .bashrc if not already done
    local bashrc="${HOME}/.bashrc"
    if ! grep -q "bash_completion.d" "$bashrc" 2>/dev/null; then
        echo '' >> "$bashrc"
        echo '# Load custom bash completions' >> "$bashrc"
        echo 'for f in ~/.bash_completion.d/*.bash; do source "$f"; done' >> "$bashrc"
        log_info "Added bash completion loader to ~/.bashrc"
    fi

    # ── Zsh ───────────────────────────────────────────────────────────────────
    if command -v zsh >/dev/null 2>&1; then
        mkdir -p "$zsh_completion_dir"
        cp "${COMPLETIONS_SRC}/_webwerk" "${zsh_completion_dir}/_webwerk"
        log_success "Installed zsh completion: _webwerk"
        # Add fpath entry to .zshrc if not already present
        local zshrc="${HOME}/.zshrc"
        if ! grep -q "zsh/completions" "$zshrc" 2>/dev/null; then
            echo '' >> "$zshrc"
            echo '# Load custom zsh completions' >> "$zshrc"
            echo 'fpath=(~/.local/share/zsh/completions $fpath)' >> "$zshrc"
            log_info "Added zsh completion path to ~/.zshrc (restart shell or run: autoload -Uz compinit && compinit)"
        fi
    else
        log_info "Zsh not found, skipping zsh completions"
    fi
}

# Offer to scaffold a project .env from the template (guarded, opt-in).
# Never overwrites; skips when an existing config is already in effect.
scaffold_env() {
    local template="${SCRIPT_DIR}/env.example"
    local target="${SCRIPT_DIR}/.env"

    if [[ -f "$target" ]]; then
        log_info "Project .env already exists, leaving it untouched"
        return
    fi
    if [[ -f "$HOME/.env" ]]; then
        log_info "Using existing ~/.env for configuration (no project .env created)"
        return
    fi
    if [[ ! -f "$template" ]]; then
        log_warning "env.example template not found, skipping .env scaffold"
        return
    fi

    read -rp "$(echo -e "${CYAN}No configuration found. Create .env from env.example? [y/N] ${COLOR_OFF}")" reply
    if [[ "$reply" =~ ^[Yy]$ ]]; then
        cp "$template" "$target"
        log_success "Created $target — edit it with your DB and site settings before installing"
    else
        log_info "Skipped .env creation; configure ~/.env or $target manually"
    fi
}

# Main installation function
install_webwerk() {
    log_info "Installing Webwerk WordPress Management Suite..."
    
    # Check if webwerk script exists
    if [[ ! -f "$WEBWERK_SCRIPT" ]]; then
        log_error "webwerk script not found at: $WEBWERK_SCRIPT"
        log_error "Please run this installer from the webwerk directory"
        exit 1
    fi
    
    # Make webwerk executable
    chmod +x "$WEBWERK_SCRIPT"
    log_info "Made webwerk script executable"
    
    # Create ~/.local/bin if it doesn't exist
    if [[ ! -d "$INSTALL_DIR" ]]; then
        mkdir -p "$INSTALL_DIR"
        log_info "Created directory: $INSTALL_DIR"
    fi
    
    # Remove existing link if it exists
    if [[ -L "$LINK_PATH" ]]; then
        rm "$LINK_PATH"
        log_info "Removed existing symbolic link"
    elif [[ -f "$LINK_PATH" ]]; then
        log_warning "File exists at $LINK_PATH (not a symbolic link)"
        log_warning "Please remove it manually and run the installer again"
        exit 1
    fi
    
    # Create symbolic link
    ln -sf "$WEBWERK_SCRIPT" "$LINK_PATH"
    log_success "Created symbolic link: $LINK_PATH -> $WEBWERK_SCRIPT"
    
    # Check if ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        log_warning "~/.local/bin is not in your PATH"
        log_info "Add this line to your ~/.bashrc or ~/.zshrc:"
        echo -e "${CYAN}export PATH=\"\$HOME/.local/bin:\$PATH\"${COLOR_OFF}"
        log_info "Then run: source ~/.bashrc (or restart your terminal)"
    fi
    
    # Test installation
    if command -v webwerk &> /dev/null; then
        log_success "Installation successful! You can now use 'webwerk' from anywhere"
        log_info "Try: webwerk --help"
    else
        log_warning "Installation completed, but 'webwerk' command not found in PATH"
        log_info "You may need to restart your terminal or update your PATH"
    fi
    
    # Install DDEV command overrides
    install_ddev_commands

    # Install shell completions
    install_completions

    # Offer to scaffold a project .env (guarded, opt-in)
    scaffold_env

    # Show configuration reminder
    log_info "Don't forget to configure your environment:"
    log_info "1. Copy env.example to .env and edit your settings (if not done above)"
    log_info "2. Create ~/.keys with your license keys"
    log_info "3. Run 'webwerk status' to verify configuration"
}

# Uninstall function
uninstall_webwerk() {
    log_info "Uninstalling Webwerk..."
    
    if [[ -L "$LINK_PATH" ]]; then
        rm "$LINK_PATH"
        log_success "Removed symbolic link: $LINK_PATH"
    else
        log_warning "No symbolic link found at: $LINK_PATH"
    fi
    
    log_success "Uninstallation completed"
}

# Show help
show_help() {
    cat << EOF
Webwerk WordPress Management Suite Installer

Usage: $0 [COMMAND]

Commands:
  install     Install webwerk for system-wide access (default)
  uninstall   Remove webwerk symbolic link
  help        Show this help message

Installation creates a symbolic link at ~/.local/bin/webwerk
pointing to the webwerk script in this directory.

After installation, ensure ~/.local/bin is in your PATH:
  export PATH="\$HOME/.local/bin:\$PATH"

EOF
}

# Main execution
main() {
    local command="${1:-install}"
    
    case "$command" in
        "install" | "")
            install_webwerk
            ;;
        "uninstall")
            uninstall_webwerk
            ;;
        "help" | "--help" | "-h")
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
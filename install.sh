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
    
    # Show configuration reminder
    log_info "Don't forget to configure your environment:"
    log_info "1. Copy .env.example to .env and edit your settings"
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
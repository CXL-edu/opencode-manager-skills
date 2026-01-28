#!/bin/bash
#
# OpenCode Manager Skill Installer
# Supports: Chinese (zh) / English (en)
#
# One-line install:
#   curl -fsSL https://raw.githubusercontent.com/CXL-edu/opencode-manager-skills/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/CXL-edu/opencode-manager-skills/main/install.sh | bash -s -- --lang zh
#   curl -fsSL https://raw.githubusercontent.com/CXL-edu/opencode-manager-skills/main/install.sh | bash -s -- --lang en
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
LANG=""
INSTALL_DIR=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect if running from curl (no local files)
REMOTE_INSTALL=false
if [[ ! -f "$SCRIPT_DIR/zh/opencode-manager.md" ]]; then
    REMOTE_INSTALL=true
    REPO_URL="https://raw.githubusercontent.com/CXL-edu/opencode-manager-skills/main"
fi

print_banner() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║       OpenCode Manager Skill Installer                ║"
    echo "║       OpenCode 管理器技能安装程序                     ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}→ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}! $1${NC}"
}

# Detect Cursor/VSCode workspace
detect_install_dir() {
    local dirs=(
        ".cursor/commands"
        ".cursor/skills"
        ".vscode/commands"
        ".vscode/skills"
    )
    
    # Check current directory
    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            echo "$dir"
            return 0
        fi
    done
    
    # Default to .cursor/commands
    echo ".cursor/commands"
    return 0
}

# Show language selection menu
select_language() {
    if [[ -n "$LANG" ]]; then
        return 0
    fi
    
    echo ""
    echo "Please select language / 请选择语言:"
    echo ""
    echo "  [1] 中文 (Chinese)"
    echo "  [2] English"
    echo ""
    read -p "Enter choice (1 or 2): " choice
    
    case $choice in
        1|zh|ZH|中文)
            LANG="zh"
            ;;
        2|en|EN|English|english)
            LANG="en"
            ;;
        *)
            print_warning "Invalid choice, defaulting to Chinese"
            LANG="zh"
            ;;
    esac
}

# Show install directory selection
select_install_dir() {
    local detected_dir=$(detect_install_dir)
    
    echo ""
    if [[ "$LANG" == "zh" ]]; then
        echo "安装目录 Install directory:"
    else
        echo "Install directory:"
    fi
    echo ""
    echo "  [1] $detected_dir (detected/检测到)"
    echo "  [2] .cursor/commands"
    echo "  [3] .cursor/skills"
    echo "  [4] Custom path / 自定义路径"
    echo ""
    read -p "Enter choice (1-4) [1]: " choice
    
    case $choice in
        ""|1)
            INSTALL_DIR="$detected_dir"
            ;;
        2)
            INSTALL_DIR=".cursor/commands"
            ;;
        3)
            INSTALL_DIR=".cursor/skills"
            ;;
        4)
            read -p "Enter custom path: " custom_path
            INSTALL_DIR="$custom_path"
            ;;
        *)
            INSTALL_DIR="$detected_dir"
            ;;
    esac
}

# Download file from remote
download_file() {
    local url="$1"
    local dest="$2"
    
    if command -v curl &> /dev/null; then
        curl -fsSL "$url" -o "$dest"
    elif command -v wget &> /dev/null; then
        wget -q "$url" -O "$dest"
    else
        print_error "curl or wget required"
        exit 1
    fi
}

# Install the skill
install_skill() {
    local source_file=""
    local dest_file="$INSTALL_DIR/opencode-manager.md"
    
    # Create directory if not exists
    mkdir -p "$INSTALL_DIR"
    
    if [[ "$REMOTE_INSTALL" == true ]]; then
        # Download from remote
        print_info "Downloading from remote..."
        download_file "$REPO_URL/$LANG/opencode-manager.md" "$dest_file"
    else
        # Copy from local
        source_file="$SCRIPT_DIR/$LANG/opencode-manager.md"
        
        if [[ ! -f "$source_file" ]]; then
            print_error "Source file not found: $source_file"
            exit 1
        fi
        
        cp "$source_file" "$dest_file"
    fi
    
    print_success "Installed: $dest_file"
}

# Show completion message
show_completion() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    
    if [[ "$LANG" == "zh" ]]; then
        echo -e "${GREEN}  安装完成！${NC}"
        echo ""
        echo "  文件位置: $INSTALL_DIR/opencode-manager.md"
        echo ""
        echo "  使用方法:"
        echo "    1. 在 Cursor 中打开项目"
        echo "    2. 使用 AI 助手时引用此 skill"
        echo "    3. 例如: \"使用 opencode-manager 启动后台服务\""
    else
        echo -e "${GREEN}  Installation Complete!${NC}"
        echo ""
        echo "  File location: $INSTALL_DIR/opencode-manager.md"
        echo ""
        echo "  Usage:"
        echo "    1. Open project in Cursor"
        echo "    2. Reference this skill when using AI assistant"
        echo "    3. Example: \"Use opencode-manager to start background server\""
    fi
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --lang|-l)
                LANG="$2"
                shift 2
                ;;
            --dir|-d)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done
}

show_help() {
    echo "OpenCode Manager Skill Installer"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --lang, -l    Language: zh (Chinese) or en (English)"
    echo "  --dir, -d     Install directory path"
    echo "  --help, -h    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                        # Interactive mode"
    echo "  $0 --lang zh              # Install Chinese version"
    echo "  $0 --lang en --dir .      # Install English to current dir"
    echo ""
    echo "One-line install:"
    echo "  curl -fsSL URL/install.sh | bash -s -- --lang zh"
}

# Main
main() {
    parse_args "$@"
    
    print_banner
    
    # Select language if not specified
    if [[ -z "$LANG" ]]; then
        select_language
    fi
    
    # Select install dir if not specified
    if [[ -z "$INSTALL_DIR" ]]; then
        select_install_dir
    fi
    
    echo ""
    print_info "Language: $LANG"
    print_info "Install to: $INSTALL_DIR"
    echo ""
    
    # Confirm
    read -p "Continue? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn] ]]; then
        print_warning "Installation cancelled"
        exit 0
    fi
    
    # Install
    install_skill
    
    # Done
    show_completion
}

main "$@"

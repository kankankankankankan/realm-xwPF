#!/bin/bash

# xwPF - Realm 端口转发管理工具
# Bootstrap 引导器 + 入口

# 安装路径
INSTALL_DIR="/usr/local/bin"
LIB_DIR="$INSTALL_DIR/lib"
SHORTCUT_PATH="/usr/local/bin/pf"

# 仓库地址
REPO_RAW_URL="https://raw.githubusercontent.com/kankankankankankan/realm-xwPF/main"
GITHUB_ACCELERATOR_URL_DEFAULT="https://github.palees.com"
GITHUB_ACCELERATOR_URL="${GITHUB_ACCELERATOR_URL-}"

# 模块列表（加载顺序）
LIB_FILES=("core.sh" "rules.sh" "server.sh" "realm.sh" "ui.sh")

# 颜色
_RED='\033[0;31m'
_GREEN='\033[0;32m'
_YELLOW='\033[1;33m'
_BLUE='\033[0;34m'
_NC='\033[0m'

_init_utf8_locale() {
    local current_locale="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"
    local candidate

    case "$current_locale" in
        *UTF-8*|*utf8*|*utf-8*)
            export LESSCHARSET=utf-8
            return 0
            ;;
    esac

    for candidate in C.UTF-8 en_US.UTF-8 zh_CN.UTF-8; do
        if locale -a 2>/dev/null | grep -qi "^${candidate}$"; then
            export LANG="$candidate"
            export LC_ALL="$candidate"
            export LC_CTYPE="$candidate"
            export LESSCHARSET=utf-8
            return 0
        fi
    done

    export LANG=C.UTF-8
    export LC_ALL=C.UTF-8
    export LC_CTYPE=C.UTF-8
    export LESSCHARSET=utf-8
}

_init_utf8_locale

# 下载函数
_github_accelerated_url() {
    local url="$1"
    local base="${GITHUB_ACCELERATOR_URL%/}"

    [ -z "$base" ] && return 1

    case "$url" in
        https://github.com/*)
            echo "$base/$url"
            ;;
        https://raw.githubusercontent.com/*)
            local path="${url#https://raw.githubusercontent.com/}"
            local owner="${path%%/*}"
            path="${path#*/}"
            local repo="${path%%/*}"
            path="${path#*/}"
            local branch="${path%%/*}"
            local file_path="${path#*/}"
            [ -z "$owner" ] || [ -z "$repo" ] || [ -z "$branch" ] || [ -z "$file_path" ] && return 1
            echo "$base/https://github.com/$owner/$repo/raw/$branch/$file_path"
            ;;
        *)
            return 1
            ;;
    esac
}

_download() {
    local url="$1" target="$2"
    local accel_url

    accel_url=$(_github_accelerated_url "$url" 2>/dev/null || true)
    if [ -n "$accel_url" ]; then
        if curl -fsSL --connect-timeout 10 --max-time 60 "$accel_url" -o "$target" 2>/dev/null ||
           wget -qO "$target" "$accel_url" 2>/dev/null; then
            return 0
        fi
    fi

    curl -fsSL --connect-timeout 10 --max-time 60 "$url" -o "$target" 2>/dev/null ||
    wget -qO "$target" "$url" 2>/dev/null
}

_prompt_github_acceleration() {
    local choice=""

    if [ "${XWPF_GITHUB_ACCELERATION_ASKED:-}" = "1" ]; then
        return 0
    fi

    if [ -n "$GITHUB_ACCELERATOR_URL" ]; then
        echo -e "${_GREEN}已启用 GitHub 加速源: ${GITHUB_ACCELERATOR_URL%/}${_NC}"
        export GITHUB_ACCELERATOR_URL
        export XWPF_GITHUB_ACCELERATION_ASKED=1
        return 0
    fi

    if [ ! -t 0 ]; then
        GITHUB_ACCELERATOR_URL="$GITHUB_ACCELERATOR_URL_DEFAULT"
        echo -e "${_GREEN}已启用 GitHub 加速源: ${GITHUB_ACCELERATOR_URL%/}${_NC}"
        export GITHUB_ACCELERATOR_URL
        export XWPF_GITHUB_ACCELERATION_ASKED=1
        return 0
    fi

    read -r -p "是否启用国内 GitHub 加速下载？(Y/n) [默认: Y]: " choice
    case "$choice" in
        [Nn])
            GITHUB_ACCELERATOR_URL=""
            echo -e "${_BLUE}已关闭 GitHub 加速下载${_NC}"
            ;;
        *)
            GITHUB_ACCELERATOR_URL="$GITHUB_ACCELERATOR_URL_DEFAULT"
            echo -e "${_GREEN}已启用 GitHub 加速源: ${GITHUB_ACCELERATOR_URL%/}${_NC}"
            ;;
    esac

    export GITHUB_ACCELERATOR_URL
    export XWPF_GITHUB_ACCELERATION_ASKED=1
}

# 安装/更新脚本文件到系统（幂等）
_bootstrap() {
    echo -e "${_YELLOW}正在安装/更新脚本文件...${_NC}"

    mkdir -p "$LIB_DIR"

    # 下载入口脚本
    if _download "$REPO_RAW_URL/xwPF.sh" "$INSTALL_DIR/xwPF.sh"; then
        chmod +x "$INSTALL_DIR/xwPF.sh"
        echo -e "  ${_GREEN}✓${_NC} xwPF.sh"
    else
        echo -e "  ${_RED}✗${_NC} xwPF.sh 下载失败"
        return 1
    fi

    # 下载所有模块
    local failed=0
    for f in "${LIB_FILES[@]}"; do
        if _download "$REPO_RAW_URL/lib/$f" "$LIB_DIR/$f"; then
            echo -e "  ${_GREEN}✓${_NC} lib/$f"
        else
            echo -e "  ${_RED}✗${_NC} lib/$f 下载失败"
            failed=1
        fi
    done

    [ "$failed" -eq 1 ] && return 1

    # 创建快捷命令
    ln -sf "$INSTALL_DIR/xwPF.sh" "$SHORTCUT_PATH"
    echo -e "${_GREEN}✓ 快捷命令已创建: pf${_NC}"

    echo -e "${_GREEN}=== 脚本安装完成${_NC}"
    echo ""
}

# 加载模块
_load_libs() {
    if [ ! -d "$LIB_DIR" ] || [ ! -f "$LIB_DIR/core.sh" ]; then
        echo -e "${_RED}错误: 未找到模块目录，请先安装${_NC}"
        if [ -n "$GITHUB_ACCELERATOR_URL" ]; then
            echo -e "${_BLUE}wget -qO- ${GITHUB_ACCELERATOR_URL%/}/https://github.com/kankankankankankan/realm-xwPF/raw/main/xwPF.sh | sudo bash -s install${_NC}"
        else
            echo -e "${_BLUE}wget -qO- ${GITHUB_ACCELERATOR_URL_DEFAULT%/}/https://github.com/kankankankankankan/realm-xwPF/raw/main/xwPF.sh | sudo bash -s install${_NC}"
        fi
        return 1
    fi

    for f in "${LIB_FILES[@]}"; do
        if [ -f "$LIB_DIR/$f" ]; then
            source "$LIB_DIR/$f"
        else
            echo -e "${_RED}错误: 缺少模块 $f${_NC}"
            return 1
        fi
    done
}

if [ "${1:-}" = "-s" ] && [ "${2:-}" = "install" ]; then
    shift
fi

# 主入口
case "${1:-}" in
    install)
        [ "$(id -u)" -ne 0 ] && { echo -e "${_RED}错误: 需要 root 权限${_NC}"; exit 1; }
        _prompt_github_acceleration
        _bootstrap || exit 1
        _load_libs || exit 1
        _SKIP_SCRIPT_UPDATE=1 smart_install
        ;;
    *)
        _load_libs || exit 1
        main "$@"
        ;;
esac

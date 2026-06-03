#!/bin/bash
# setup.sh
# 用途：安装小程序版本管理所需的 CLI 工具
# 用法：bash setup.sh [--all | --gh | --alipay | --douyin | --weixin]
# 不带参数时安装全部

set -e

install_gh() {
    if command -v gh >/dev/null 2>&1; then
        echo "✅ GitHub CLI (gh) 已安装：$(gh --version | head -1)"
    else
        echo "📦 安装 GitHub CLI (gh)..."
        if command -v brew >/dev/null 2>&1; then
            brew install gh
        else
            echo "❌ 未检测到 Homebrew，请手动安装："
            echo "   brew install gh"
            echo "   或参考：https://cli.github.com/"
            return 1
        fi
    fi
}

install_alipay() {
    if command -v minidev >/dev/null 2>&1; then
        echo "✅ 支付宝 CLI (minidev) 已安装"
    else
        echo "📦 安装支付宝小程序 CLI (minidev)..."
        npm install -g minidev
    fi
}

install_douyin() {
    if command -v tma >/dev/null 2>&1; then
        echo "✅ 抖音 CLI (tt-ide-cli) 已安装"
    else
        echo "📦 安装抖音小程序 CLI (tt-ide-cli)..."
        npm install -g tt-ide-cli
    fi
}

install_weixin() {
    if command -v wxcloud >/dev/null 2>&1; then
        echo "✅ 微信 CLI (@wxcloud/cli) 已安装"
    else
        echo "📦 安装微信小程序 CLI (@wxcloud/cli)..."
        npm install -g @wxcloud/cli
    fi
}

# 解析参数
if [ $# -eq 0 ] || [ "$1" = "--all" ]; then
    echo "🔧 安装所有 CLI 工具..."
    echo ""
    install_gh
    echo ""
    install_alipay
    echo ""
    install_douyin
    echo ""
    install_weixin
else
    for arg in "$@"; do
        case "$arg" in
            --gh)
                install_gh
                ;;
            --alipay)
                install_alipay
                ;;
            --douyin)
                install_douyin
                ;;
            --weixin)
                install_weixin
                ;;
            *)
                echo "❌ 未知选项：$arg"
                echo "可用选项：--all | --gh | --alipay | --douyin | --weixin"
                exit 1
                ;;
        esac
        echo ""
    done
fi

echo "✅ 安装完成！"

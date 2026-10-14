#!/usr/bin/env bash
# mp-cli.sh - 微信小程序版本管理 CLI
# 用法：bash mp-cli.sh <command> [args...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CMD_DIR="${SCRIPT_DIR}/commands"

show_help() {
    echo "微信小程序版本管理 CLI"
    echo ""
    echo "用法：bash mp-cli.sh <command> [args...]"
    echo ""
    echo "可用命令："
    echo "  setup                         检查 GitHub CLI"
    echo "  init [项目路径]                初始化 .mp-release.json"
    echo "  release <版本号>               创建 release/vA.B.C 分支"
    echo "  preview <stg|prod> <版本号>    拉取 release 分支并构建微信小程序"
    echo "  notice <版本号> \"<内容>\" [二维码路径] 发送企业微信通知"
    echo "  merge [版本号]                 创建 PR 合并到主干"
    echo "  tag [版本号]                   在主干上打 vA.B.C 标签"
    echo "  help                           显示此帮助信息"
    echo ""
    echo "示例："
    echo "  bash mp-cli.sh release 1.2.0"
    echo "  bash mp-cli.sh preview stg 1.2.0"
    echo "  bash mp-cli.sh notice 1.2.0 \"stg 包已构建\" /tmp/qr.png"
    echo "  bash mp-cli.sh merge 1.2.0"
    echo "  bash mp-cli.sh tag 1.2.0"
}

COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
    setup)
        bash "${CMD_DIR}/setup.sh" "$@"
        ;;
    init)
        bash "${CMD_DIR}/init.sh" "$@"
        ;;
    release)
        bash "${CMD_DIR}/release.sh" "$@"
        ;;
    preview)
        bash "${CMD_DIR}/preview.sh" "$@"
        ;;
    notice)
        bash "${CMD_DIR}/notice.sh" "$@"
        ;;
    merge)
        bash "${CMD_DIR}/merge.sh" "$@"
        ;;
    tag)
        bash "${CMD_DIR}/tag.sh" "$@"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "❌ 未知命令：${COMMAND}"
        echo ""
        show_help
        exit 1
        ;;
esac

#!/bin/bash
# mp-cli.sh - 小程序版本管理 CLI
# 用法：bash mp-cli.sh <command> [args...]

set -e

# 定位 commands 目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CMD_DIR="${SCRIPT_DIR}/commands"

show_help() {
    echo "小程序版本管理 CLI"
    echo ""
    echo "用法：bash mp-cli.sh <command> [args...]"
    echo ""
    echo "可用命令："
    echo "  init                        初始化 .mp-release.json 配置文件"
    echo "  release <版本号>             创建 release/vA.B.C 分支"
    echo "  publish <平台> <环境> <版本号> \"<描述>\" [额外参数...]"
    echo "                              发布小程序到指定平台（项目路径默认 ./）"
    echo "  merge [版本号]               创建 PR 将 release 分支合并到主干"
    echo "  tag [版本号]                 在主干上打 vA.B.C 标签"
    echo "  setup [--all|--gh|--alipay|--douyin|--weixin]"
    echo "                              安装所需 CLI 工具（默认全部安装）"
    echo "  help                        显示此帮助信息"
    echo ""
    echo "示例："
    echo "  bash mp-cli.sh setup"
    echo "  bash mp-cli.sh setup --gh --alipay"
    echo "  bash mp-cli.sh init"
    echo "  bash mp-cli.sh release 1.2.0"
    echo "  bash mp-cli.sh publish alipay prod 1.2.0 \"修复bug\""
    echo "  bash mp-cli.sh merge 1.2.0"
    echo "  bash mp-cli.sh tag 1.2.0"
}

COMMAND="$1"
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
    publish)
        bash "${CMD_DIR}/publish.sh" "$@"
        ;;
    merge)
        bash "${CMD_DIR}/merge.sh" "$@"
        ;;
    tag)
        bash "${CMD_DIR}/tag.sh" "$@"
        ;;
    help|--help|-h|"")
        show_help
        ;;
    *)
        echo "❌ 未知命令：${COMMAND}"
        echo ""
        show_help
        exit 1
        ;;
esac

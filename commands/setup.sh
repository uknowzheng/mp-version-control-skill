#!/usr/bin/env bash
# setup.sh
# 用途：检查小程序版本管理所需的 GitHub CLI

set -euo pipefail

if command -v gh >/dev/null 2>&1; then
    echo "✅ GitHub CLI (gh) 已安装：$(gh --version | head -n 1)"
else
    echo "📦 未安装 GitHub CLI (gh)"
    if command -v brew >/dev/null 2>&1; then
        read -r -p "是否执行 brew install gh？[y/N] " answer
        case "$answer" in
            y|Y|yes|YES)
                brew install gh
                ;;
            *)
                echo "请手动安装：brew install gh"
                exit 1
                ;;
        esac
    else
        echo "请手动安装 GitHub CLI：https://cli.github.com/"
        exit 1
    fi
fi

echo "✅ 版本控制依赖检查完成"

CONFIG_FILE="./.mp-release.json"
if [ -f "$CONFIG_FILE" ]; then
    GH_HOSTNAME="$(node - "$CONFIG_FILE" <<'NODE'
const fs = require('fs');
try {
  const config = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  process.stdout.write(config.git?.hostname || '');
} catch (_) {}
NODE
)"
    if [ -n "$GH_HOSTNAME" ]; then
        echo "💡 检测到 GitHub Enterprise 配置：${GH_HOSTNAME}"
        echo "   请确保已执行：gh auth login --hostname ${GH_HOSTNAME}"
    fi
fi

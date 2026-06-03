#!/bin/bash
# merge.sh
# 用途：为当前 release 分支创建 PR 合并到主干（master/main）
# 用法：bash merge.sh [版本号]
# 如果不传版本号，自动从当前分支名解析

set -e

VERSION="$1"

# 0. 读取 GitHub 企业版域名（若配置了）
GH_HOSTNAME=""
CONFIG_FILE="./.mp-release.json"
if [ -f "$CONFIG_FILE" ]; then
    if command -v jq >/dev/null 2>&1; then
        GH_HOSTNAME="$(jq -r '.git.hostname // ""' "$CONFIG_FILE" 2>/dev/null)"
    elif command -v python3 >/dev/null 2>&1; then
        GH_HOSTNAME="$(python3 -c "
import json, sys
try:
    with open('$CONFIG_FILE', 'r') as f:
        data = json.load(f)
    print(data.get('git', {}).get('hostname', '') or '')
except:
    print('')
" 2>/dev/null)"
    fi
fi

# 1. 如果未传版本号，从当前分支名解析
# 当前分支必须是 release/vX.Y.Z 格式
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ -z "$VERSION" ]; then
    if [[ "$CURRENT_BRANCH" =~ ^release/v([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
        VERSION="${BASH_REMATCH[1]}"
    else
        echo "❌ 错误：当前不在 release 分支上，且未指定版本号"
        echo "用法：bash merge.sh <版本号>"
        exit 1
    fi
fi

BRANCH_NAME="release/v${VERSION}"

# 2. 确保在正确分支上
if [ "$CURRENT_BRANCH" != "$BRANCH_NAME" ]; then
    echo "🔄 切换到 ${BRANCH_NAME} ..."
    git checkout "$BRANCH_NAME"
fi

# 3. 推送最新代码
echo "📤 推送 ${BRANCH_NAME} 最新代码..."
git push origin "$BRANCH_NAME"

# 4. 检测主分支
MAIN_BRANCH=""
if git show-ref --verify --quiet refs/remotes/origin/master; then
    MAIN_BRANCH="master"
elif git show-ref --verify --quiet refs/remotes/origin/main; then
    MAIN_BRANCH="main"
else
    echo "❌ 错误：远端未找到 master 或 main 分支"
    exit 1
fi

# 5. 检查 gh CLI 是否安装
if ! command -v gh >/dev/null 2>&1; then
    echo "❌ 未安装 GitHub CLI (gh)"
    echo "请先安装：brew install gh"
    echo "或参考：https://cli.github.com/"
    exit 1
fi

# 6. 检查 gh 认证状态
GH_HOST_FLAG=()
if [ -n "$GH_HOSTNAME" ]; then
    GH_HOST_FLAG=(--hostname "$GH_HOSTNAME")
    echo "🏢 使用 GitHub Enterprise：${GH_HOSTNAME}"
fi

if ! gh auth status "${GH_HOST_FLAG[@]}" >/dev/null 2>&1; then
    echo "❌ GitHub CLI 未登录"
    if [ -n "$GH_HOSTNAME" ]; then
        echo "请先执行：gh auth login --hostname ${GH_HOSTNAME}"
    else
        echo "请先执行：gh auth login"
    fi
    exit 1
fi

# 7. 创建 PR
echo "🔀 创建 PR：${BRANCH_NAME} → ${MAIN_BRANCH}"
gh pr create \
    --base "$MAIN_BRANCH" \
    --head "$BRANCH_NAME" \
    --title "Release ${VERSION}" \
    --body "## Release ${VERSION}

合并 \`${BRANCH_NAME}\` 到 \`${MAIN_BRANCH}\`

灰度验证已通过，准备合入主干。"

echo ""
echo "✅ PR 创建成功！"
echo "   源分支：${BRANCH_NAME}"
echo "   目标分支：${MAIN_BRANCH}"
echo "   请在 GitHub 上 review 后合并"
echo ""
echo "💡 合并后可执行打 tag："
echo "   bash mp-cli.sh tag ${VERSION}"

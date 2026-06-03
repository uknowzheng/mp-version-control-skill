#!/bin/bash
# tag.sh
# 用途：PR 合并后在主干上打 tag
# 用法：bash tag.sh <版本号>
# 会创建 vA.B.C 格式的 tag

set -e

VERSION="$1"

# 1. 校验参数
if [ -z "$VERSION" ]; then
    # 尝试从当前分支解析
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$CURRENT_BRANCH" =~ ^release/v([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
        VERSION="${BASH_REMATCH[1]}"
    else
        echo "❌ 错误：请提供版本号"
        echo "用法：bash tag.sh <版本号>"
        exit 1
    fi
fi

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ 错误：版本号格式不正确，必须为 A.B.C"
    exit 1
fi

TAG_NAME="v${VERSION}"

# 2. 检测主分支
git fetch origin --prune

MAIN_BRANCH=""
if git show-ref --verify --quiet refs/remotes/origin/master; then
    MAIN_BRANCH="master"
elif git show-ref --verify --quiet refs/remotes/origin/main; then
    MAIN_BRANCH="main"
else
    echo "❌ 错误：远端未找到 master 或 main 分支"
    exit 1
fi

# 3. 切换到主分支并拉取最新
echo "🔄 切换到 ${MAIN_BRANCH} 并同步..."
git checkout "$MAIN_BRANCH"
git pull origin "$MAIN_BRANCH"

# 4. 检查 tag 是否已存在
if git tag -l "$TAG_NAME" | grep -q "$TAG_NAME"; then
    echo "❌ 错误：tag ${TAG_NAME} 已存在"
    exit 1
fi

if git ls-remote --tags origin "$TAG_NAME" | grep -q "$TAG_NAME"; then
    echo "❌ 错误：远端 tag ${TAG_NAME} 已存在"
    exit 1
fi

# 5. 创建并推送 tag
echo "🏷️  创建 tag ${TAG_NAME}..."
git tag -a "$TAG_NAME" -m "Release ${VERSION}"

echo "🚀 推送 tag ${TAG_NAME} 到 origin..."
git push origin "$TAG_NAME"

echo ""
echo "✅ 成功创建并推送 tag：${TAG_NAME}"
echo "   基于分支：${MAIN_BRANCH}"
echo "   release/v${VERSION} 分支已保留"

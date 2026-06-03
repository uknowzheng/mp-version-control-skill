#!/bin/bash
# release.sh
# 用途：从主分支（master/main）创建并推送 release/vA.B.C 分支
# 用法：bash release.sh <版本号>
# 示例：bash release.sh 1.2.0

set -e

VERSION="$1"

# ---------- 1. 校验参数 ----------
if [ -z "$VERSION" ]; then
    echo "❌ 错误：缺少版本号参数"
    echo "用法：bash release.sh <版本号>"
    echo "示例：bash release.sh 1.2.0"
    exit 1
fi

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ 错误：版本号格式不正确，必须为 A.B.C（例如 1.2.0）"
    exit 1
fi

BRANCH_NAME="release/v${VERSION}"

# ---------- 2. 检查是否在 git 仓库 ----------
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ 错误：当前目录不是 git 仓库"
    exit 1
fi

# ---------- 3. 检查工作区是否干净 ----------
if [ -n "$(git status --porcelain)" ]; then
    echo "❌ 错误：工作区存在未提交修改，请先 commit 或 stash"
    git status --short
    exit 1
fi

# ---------- 4. 拉取远端信息 ----------
echo "📥 git fetch origin ..."
git fetch origin --prune

# ---------- 5. 检测主分支 ----------
MAIN_BRANCH=""
if git show-ref --verify --quiet refs/remotes/origin/master; then
    MAIN_BRANCH="master"
elif git show-ref --verify --quiet refs/remotes/origin/main; then
    MAIN_BRANCH="main"
else
    echo "❌ 错误：远端未找到 master 或 main 分支"
    exit 1
fi

echo "✅ 检测到主分支：${MAIN_BRANCH}"

# ---------- 6. 检查目标分支是否已存在 ----------
if git show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
    echo "❌ 错误：本地已存在分支 ${BRANCH_NAME}"
    exit 1
fi

if git show-ref --verify --quiet "refs/remotes/origin/${BRANCH_NAME}"; then
    echo "❌ 错误：远端已存在分支 ${BRANCH_NAME}"
    exit 1
fi

# ---------- 7. 切换到主分支并 pull ----------
echo "🔄 切换到 ${MAIN_BRANCH} 并同步最新代码 ..."
git checkout "${MAIN_BRANCH}"
git pull origin "${MAIN_BRANCH}"

# ---------- 8. 创建 release 分支 ----------
echo "🌱 创建分支 ${BRANCH_NAME} ..."
git checkout -b "${BRANCH_NAME}"

# ---------- 9. 推送至远端 ----------
echo "🚀 推送 ${BRANCH_NAME} 到 origin ..."
git push -u origin "${BRANCH_NAME}"

# ---------- 10. 切回主干分支 ----------
echo "🔄 切回 ${MAIN_BRANCH} ..."
git checkout "${MAIN_BRANCH}"

echo ""
echo "✅ 成功创建并推送分支：${BRANCH_NAME}"
echo "   基线分支：${MAIN_BRANCH}"
echo "   当前所在分支：$(git rev-parse --abbrev-ref HEAD)"

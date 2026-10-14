#!/usr/bin/env bash
# preview.sh
# 用途：切换 release 分支，构建微信小程序并校验 dist 产物
# 用法：bash preview.sh <stg|prod> <版本号>

set -euo pipefail

ENV_NAME="${1:-}"
VERSION="${2:-}"

if [[ "$ENV_NAME" != "stg" && "$ENV_NAME" != "prod" ]]; then
    echo "❌ 错误：环境必须是 stg 或 prod"
    echo "用法：bash preview.sh <stg|prod> <版本号>"
    exit 1
fi

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ 错误：版本号格式不正确，必须为 A.B.C"
    exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ 错误：当前目录不是 git 仓库"
    exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
    echo "❌ 错误：工作区存在未提交修改，请先 commit 或 stash"
    git status --short
    exit 1
fi

BRANCH_NAME="release/v${VERSION}"
echo "📥 同步远端分支信息..."
git fetch origin --prune

if ! git show-ref --verify --quiet "refs/remotes/origin/${BRANCH_NAME}"; then
    echo "❌ 错误：远端不存在分支 ${BRANCH_NAME}"
    exit 1
fi

if git show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
    git checkout "${BRANCH_NAME}"
else
    git checkout -b "${BRANCH_NAME}" --track "origin/${BRANCH_NAME}"
fi

git pull --ff-only origin "${BRANCH_NAME}"

BUILD_SCRIPT="app:${ENV_NAME}:mp-weixin"
echo "📦 构建微信小程序：pnpm run ${BUILD_SCRIPT}"
pnpm run "${BUILD_SCRIPT}"

PROJECT_PATH="$(pwd)/dist/${ENV_NAME}/mp-weixin"
CONFIG_PATH="${PROJECT_PATH}/project.config.json"
APP_PATH="${PROJECT_PATH}/app.json"

if [ ! -d "$PROJECT_PATH" ] || [ ! -f "$CONFIG_PATH" ] || [ ! -f "$APP_PATH" ]; then
    echo "❌ 错误：构建产物不完整：${PROJECT_PATH}"
    exit 1
fi

node - "$CONFIG_PATH" "$APP_PATH" <<'NODE'
const fs = require('fs');
const [configPath, appPath] = process.argv.slice(2);
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const app = JSON.parse(fs.readFileSync(appPath, 'utf8'));
if (!config.appid || config.appid === 'touristappid' || config.compileType !== 'miniprogram') {
  throw new Error('project.config.json 缺少有效 appid 或 compileType 不是 miniprogram');
}
if (!Array.isArray(app.pages) || !app.pages[0]) {
  throw new Error('app.json 缺少首个页面路径');
}
NODE

ENTRY_PAGE="$(node - "$APP_PATH" <<'NODE'
const fs = require('fs');
const app = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
process.stdout.write(app.pages[0]);
NODE
)"

printf '\n✅ 微信小程序构建完成\n'
printf 'PREVIEW_ENV=%s\n' "$ENV_NAME"
printf 'PREVIEW_VERSION=%s\n' "$VERSION"
printf 'PREVIEW_BRANCH=%s\n' "$BRANCH_NAME"
printf 'PREVIEW_PROJECT=%s\n' "$PROJECT_PATH"
printf 'PREVIEW_PAGE=%s\n' "$ENTRY_PAGE"

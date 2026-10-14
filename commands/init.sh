#!/usr/bin/env bash
# init.sh
# 用途：在项目根目录生成 GitHub Enterprise 配置模板
# 用法：bash init.sh [项目目录]

set -euo pipefail

INPUT_PATH="${1:-.}"
if [ -d "$INPUT_PATH" ]; then
    OUTPUT_FILE="${INPUT_PATH%/}/.mp-release.json"
else
    OUTPUT_FILE="$INPUT_PATH"
fi

OUTPUT_DIR="$(dirname "$OUTPUT_FILE")"
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "❌ 错误：目录不存在：${OUTPUT_DIR}"
    exit 1
fi

if [ -e "$OUTPUT_FILE" ]; then
    echo "⚠️  文件已存在：${OUTPUT_FILE}"
    if [ -t 0 ]; then
        read -r -p "是否覆盖？[y/N] " answer
    else
        answer="${MP_INIT_OVERWRITE:-n}"
    fi
    case "$answer" in
        y|Y|yes|YES) echo "🔄 将覆盖原文件" ;;
        *) echo "✋ 已取消，未修改原文件"; exit 0 ;;
    esac
fi

cat > "$OUTPUT_FILE" <<'EOF'
{
  "git": {
    "hostname": ""
  }
}
EOF

echo "✅ 已生成配置模板：${OUTPUT_FILE}"
echo "👉 GitHub Enterprise 用户填写 git.hostname；默认 GitHub 留空即可。"
echo "👉 企业微信通知请在项目根目录创建 .notice，并将其加入 .gitignore。"

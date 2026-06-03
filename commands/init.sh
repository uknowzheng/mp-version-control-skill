#!/bin/bash
# init.sh
# 用途：在项目根目录生成 .mp-release.json 配置模板
# 用法：bash init.sh [输出路径]
# 示例：
#   bash init.sh                       # 生成 ./.mp-release.json
#   bash init.sh /path/to/project      # 生成 /path/to/project/.mp-release.json
#   bash init.sh /tmp/custom.json      # 生成 /tmp/custom.json

set -e

INPUT_PATH="${1:-.}"

# ---------- 1. 解析输出路径 ----------
# 若传入的是目录，则在其下生成 .mp-release.json；若是文件路径，按原样使用
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

# ---------- 2. 文件已存在则询问是否覆盖 ----------
if [ -e "$OUTPUT_FILE" ]; then
    echo "⚠️  文件已存在：${OUTPUT_FILE}"
    if [ -t 0 ]; then
        read -r -p "是否覆盖？[y/N] " ANSWER
    else
        ANSWER="${MP_INIT_OVERWRITE:-n}"
    fi
    case "$ANSWER" in
        y|Y|yes|YES)
            echo "🔄 将覆盖原文件"
            ;;
        *)
            echo "✋ 已取消，未修改原文件"
            exit 0
            ;;
    esac
fi

# ---------- 3. 写入模板 JSON ----------
# 每个平台下默认放一个名为 "default" 的环境占位，
# 用户可自行重命名/复制为 "生产"、"测试"、"staging" 等任意环境名。
cat > "$OUTPUT_FILE" <<'EOF'
{
  "platforms": {
    "alipay": {
      "default": {
        "appId": "",
        "identityKeyPath": ""
      }
    },
    "douyin": {
      "default": {
        "appId": "",
        "token": ""
      }
    },
    "weixin": {
      "default": {
        "appId": "",
        "privateKeyPath": "",
        "envId": "",
        "serviceName": ""
      }
    }
  }
}
EOF

echo "✅ 已生成配置模板：${OUTPUT_FILE}"
echo ""
echo "👉 后续步骤："
echo "   1. 手动编辑该文件，填入各平台实际参数；"
echo "      或通过 SKILL 的交互式 init 流程由 AI 引导填入。"
echo "   2. 由于包含敏感信息，建议将其加入 .gitignore："
echo "        echo '.mp-release.json' >> .gitignore"

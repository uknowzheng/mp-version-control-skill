#!/bin/bash
# notice.sh
# 用途：通过企业微信 webhook 群机器人发送版本通知
# 用法：bash notice.sh <版本号> "<通知内容>"
#
# 示例：
#   bash notice.sh 10.25.1 "小程序版本10.25.1，跟版的需求请合并到 release/v10.25.1 分支"

set -e

VERSION="$1"
MESSAGE="$2"

# ---------- 1. 校验参数 ----------
if [ -z "$VERSION" ] || [ -z "$MESSAGE" ]; then
    echo "❌ 错误：参数不完整"
    echo "用法：bash notice.sh <版本号> \"<通知内容>\""
    exit 1
fi

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ 错误：版本号格式不正确，必须为 A.B.C"
    exit 1
fi

# ---------- 2. 读取 webhook URL ----------
NOTICE_FILE="./.notice"
WEBHOOK_URL=""

if [ -f "$NOTICE_FILE" ]; then
    # 读取第一行非空非注释内容作为 webhook URL
    WEBHOOK_URL="$(grep -v '^[[:space:]]*#' "$NOTICE_FILE" | grep -v '^[[:space:]]*$' | head -n 1 | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
fi

if [ -z "$WEBHOOK_URL" ]; then
    echo "❌ 错误：未找到 webhook URL"
    echo "请在项目根目录创建 .notice 文件，内容为企业微信 webhook 地址"
    echo "示例：https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_KEY"
    exit 1
fi

# ---------- 3. 构建 JSON payload（优先 jq，fallback python3，再 fallback 手动转义） ----------
if command -v jq >/dev/null 2>&1; then
    PAYLOAD=$(jq -n --arg msg "$MESSAGE" '{msgtype:"text",text:{content:$msg,mentioned_list:["@all"]}}')
elif command -v python3 >/dev/null 2>&1; then
    PAYLOAD=$(python3 -c "
import json, sys
msg = sys.argv[1]
print(json.dumps({'msgtype':'text','text':{'content':msg,'mentioned_list':['@all']}}, ensure_ascii=False))
" "$MESSAGE")
else
    # fallback: 手动转义 " 与换行
    ESCAPED_MSG=$(printf '%s' "$MESSAGE" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk 'BEGIN{ORS=""} {if(NR>1) print "\\n"; print}')
    PAYLOAD="{\"msgtype\":\"text\",\"text\":{\"content\":\"${ESCAPED_MSG}\",\"mentioned_list\":[\"@all\"]}}"
fi

# ---------- 4. 发送请求 ----------
echo "📢 发送版本通知..."
echo "   版本：v${VERSION}"
echo "   Webhook：${WEBHOOK_URL:0:50}..."
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" \
  "$WEBHOOK_URL" \
  -H 'Content-Type: application/json' \
  -d "$PAYLOAD")

HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    # 检查企业微信返回的 errcode
    ERRCODE=""
    if command -v jq >/dev/null 2>&1; then
        ERRCODE="$(echo "$BODY" | jq -r '.errcode // 0')"
    elif command -v python3 >/dev/null 2>&1; then
        ERRCODE="$(python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('errcode',0))" <<< "$BODY" 2>/dev/null)"
    fi

    if [ "$ERRCODE" = "0" ] || [ -z "$ERRCODE" ]; then
        echo "✅ 通知发送成功！"
    else
        echo "❌ 发送失败，企业微信返回错误："
        echo "$BODY"
        exit 1
    fi
else
    echo "❌ 请求失败，HTTP 状态码：${HTTP_CODE}"
    echo "$BODY"
    exit 1
fi

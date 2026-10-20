#!/usr/bin/env bash
# notice.sh
# 用途：按通知场景通过企业微信 webhook 发送版本通知，可附带二维码图片
# 用法：bash notice.sh <checkbranch|release> <版本号> "<通知内容>" [二维码图片路径]

set -euo pipefail

NOTICE_SCENE="${1:-}"
VERSION="${2:-}"
MESSAGE="${3:-}"
QR_PATH="${4:-}"

if [[ "$NOTICE_SCENE" != "checkbranch" && "$NOTICE_SCENE" != "release" ]]; then
    echo "❌ 错误：通知场景必须是 checkbranch 或 release"
    echo "用法：bash notice.sh <checkbranch|release> <版本号> \"<通知内容>\" [二维码图片路径]"
    exit 1
fi

if [ -z "$VERSION" ] || [ -z "$MESSAGE" ]; then
    echo "❌ 错误：参数不完整"
    echo "用法：bash notice.sh <checkbranch|release> <版本号> \"<通知内容>\" [二维码图片路径]"
    exit 1
fi

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ 错误：版本号格式不正确，必须为 A.B.C"
    exit 1
fi

if [ "$NOTICE_SCENE" = "checkbranch" ] && [ -n "$QR_PATH" ]; then
    echo "❌ 错误：checkbranch 通知不支持二维码图片"
    exit 1
fi

NOTICE_FILE="./.notice.${NOTICE_SCENE}"
WEBHOOK_URL=""

if [ -f "$NOTICE_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        if [ -n "$line" ] && [[ "$line" != \#* ]]; then
            WEBHOOK_URL="$line"
            break
        fi
    done < "$NOTICE_FILE"
fi

if [ -z "$WEBHOOK_URL" ]; then
    echo "❌ 错误：未找到 ${NOTICE_SCENE} webhook URL"
    echo "请在项目根目录创建 ${NOTICE_FILE}，内容为企业微信 webhook 地址"
    echo "示例：https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_KEY"
    exit 1
fi

build_text_payload() {
    if command -v jq >/dev/null 2>&1; then
        if [ "$NOTICE_SCENE" = "checkbranch" ]; then
            jq -n --arg msg "$MESSAGE" '{msgtype:"text",text:{content:$msg,mentioned_list:["@all"]}}'
        else
            jq -n --arg msg "$MESSAGE" '{msgtype:"text",text:{content:$msg}}'
        fi
    elif command -v python3 >/dev/null 2>&1; then
        python3 - "$NOTICE_SCENE" "$MESSAGE" <<'PY'
import json
import sys

scene, message = sys.argv[1:]
text = {'content': message}
if scene == 'checkbranch':
    text['mentioned_list'] = ['@all']
print(json.dumps({'msgtype': 'text', 'text': text}, ensure_ascii=False))
PY
    else
        echo "❌ 错误：发送通知需要 jq 或 python3"
        exit 1
    fi
}

build_image_payload() {
    if [ ! -f "$QR_PATH" ]; then
        echo "❌ 错误：二维码文件不存在：${QR_PATH}" >&2
        exit 1
    fi

    local size
    size="$(wc -c < "$QR_PATH" | tr -d ' ')"
    if [ "$size" -gt 2097152 ]; then
        echo "❌ 错误：二维码图片超过企业微信机器人 2MB 限制" >&2
        exit 1
    fi

    if command -v python3 >/dev/null 2>&1; then
        python3 - "$QR_PATH" <<'PY'
import base64
import hashlib
import json
import sys
from pathlib import Path

content = Path(sys.argv[1]).read_bytes()
print(json.dumps({
    'msgtype': 'image',
    'image': {
        'base64': base64.b64encode(content).decode('ascii'),
        'md5': hashlib.md5(content).hexdigest(),
    }
}))
PY
    elif command -v jq >/dev/null 2>&1; then
        local base64_content md5_value
        base64_content="$(base64 < "$QR_PATH" | tr -d '\r\n')"
        if command -v md5 >/dev/null 2>&1; then
            md5_value="$(md5 -q "$QR_PATH")"
        elif command -v md5sum >/dev/null 2>&1; then
            md5_value="$(md5sum "$QR_PATH" | awk '{print $1}')"
        else
            echo "❌ 错误：发送二维码需要 md5 或 md5sum" >&2
            exit 1
        fi
        jq -n --arg base64 "$base64_content" --arg md5 "$md5_value" \
            '{msgtype:"image",image:{base64:$base64,md5:$md5}}'
    else
        echo "❌ 错误：发送二维码需要 python3 或 jq" >&2
        exit 1
    fi
}

send_payload() {
    local payload="$1"
    local response http_code body errcode

    response="$(curl -s -w '\n%{http_code}' \
        "$WEBHOOK_URL" \
        -H 'Content-Type: application/json' \
        -d "$payload")"
    http_code="$(printf '%s\n' "$response" | tail -n 1)"
    body="$(printf '%s\n' "$response" | sed '$d')"

    if [ "$http_code" != "200" ]; then
        echo "❌ 请求失败，HTTP 状态码：${http_code}" >&2
        printf '%s\n' "$body" >&2
        return 1
    fi

    if command -v jq >/dev/null 2>&1; then
        errcode="$(printf '%s' "$body" | jq -r '.errcode // 0')"
    elif command -v python3 >/dev/null 2>&1; then
        errcode="$(printf '%s' "$body" | python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("errcode",0))' 2>/dev/null || printf '0')"
    else
        errcode="0"
    fi

    if [ "$errcode" != "0" ]; then
        echo "❌ 发送失败，企业微信返回错误：" >&2
        printf '%s\n' "$body" >&2
        return 1
    fi
}

echo "📢 发送版本通知..."
echo "   版本：v${VERSION}"
echo "   Webhook：${WEBHOOK_URL:0:50}..."
echo ""

send_payload "$(build_text_payload)"
echo "✅ 文字通知发送成功！"

if [ -n "$QR_PATH" ]; then
    send_payload "$(build_image_payload)"
    echo "✅ 二维码图片发送成功！"
fi

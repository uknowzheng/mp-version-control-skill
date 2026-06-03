#!/bin/bash
# publish.sh
# 用途：调用各平台 CLI 完成小程序版本上传/发布
# 用法：bash publish.sh <平台> <环境名> <版本号> "<描述>" [额外参数...]
# 项目路径默认为 ./（当前目录）
# 平台：alipay | douyin | weixin
# 环境名：用户自定义（如 prod / test / staging / default 等），需与 .mp-release.json 中一致
#
# 示例：
#   bash publish.sh alipay prod 1.2.0 "修复登录问题"
#   bash publish.sh douyin prod 1.2.0 "新增首页改版"
#   bash publish.sh weixin test 1.2.0 "v1.2.0 修复 bug" \
#       --envId test-xxx --serviceName app-service-test

set -e

PLATFORM="$1"
ENV_NAME="$2"
VERSION="$3"
DESCRIPTION="$4"
shift 4 || true
CLI_ARGS=("$@")
EXTRA_ARGS=("$@")

# 项目路径默认为当前目录
PROJECT_PATH="./"

# ---------- 1. 校验基础参数 ----------
if [ -z "$PLATFORM" ] || [ -z "$ENV_NAME" ] || [ -z "$VERSION" ] || [ -z "$DESCRIPTION" ]; then
    echo "❌ 错误：参数不完整"
    echo "用法：bash publish.sh <平台> <环境名> <版本号> \"<描述>\" [额外参数...]"
    echo "平台：alipay | douyin | weixin"
    echo "环境名：用户自定义（与 .mp-release.json 中的 key 对应）"
    exit 1
fi

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ 错误：版本号格式不正确，必须为 A.B.C"
    exit 1
fi

# ---------- 1.5 读取 .mp-release.json（若存在） ----------
# 命令行参数优先级 > 配置文件，因此把配置文件值放在 EXTRA_ARGS 前面，
# 后续 get_arg 顺序遍历时同名 key 命中"最后一个"可保证 CLI 显式传入的值生效。
CONFIG_FILE="${PROJECT_PATH%/}/.mp-release.json"
CONFIG_ARGS=()

read_json_field() {
    # 用法：read_json_field <file> <platform> <env> <field>
    local file="$1" platform="$2" env="$3" field="$4"
    if command -v jq >/dev/null 2>&1; then
        jq -r --arg p "$platform" --arg e "$env" --arg f "$field" \
            '.platforms[$p][$e][$f] // ""' "$file" 2>/dev/null
    elif command -v python3 >/dev/null 2>&1; then
        python3 - "$file" "$platform" "$env" "$field" <<'PY' 2>/dev/null
import json, sys
try:
    with open(sys.argv[1], 'r', encoding='utf-8') as fp:
        data = json.load(fp)
    print(
        data.get('platforms', {})
            .get(sys.argv[2], {})
            .get(sys.argv[3], {})
            .get(sys.argv[4], '') or ''
    )
except Exception:
    print('')
PY
    else
        echo ""
    fi
}

env_exists_in_config() {
    # 用法：env_exists_in_config <file> <platform> <env>
    local file="$1" platform="$2" env="$3"
    if command -v jq >/dev/null 2>&1; then
        local has
        has="$(jq -r --arg p "$platform" --arg e "$env" \
            '(.platforms[$p][$e] // empty) | type' "$file" 2>/dev/null)"
        [ "$has" = "object" ]
    elif command -v python3 >/dev/null 2>&1; then
        python3 - "$file" "$platform" "$env" <<'PY' >/dev/null 2>&1
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as fp:
    data = json.load(fp)
node = data.get('platforms', {}).get(sys.argv[2], {}).get(sys.argv[3])
if not isinstance(node, dict):
    raise SystemExit(1)
PY
    else
        return 1
    fi
}

append_config_arg() {
    # 用法：append_config_arg <cli-key> <field-value>
    local key="$1" val="$2"
    if [ -n "$val" ]; then
        CONFIG_ARGS+=("$key" "$val")
    fi
}

if [ -f "$CONFIG_FILE" ]; then
    if command -v jq >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1; then
        echo "📄 检测到配置文件：${CONFIG_FILE}"
        if env_exists_in_config "$CONFIG_FILE" "$PLATFORM" "$ENV_NAME"; then
            echo "🌐 使用环境：${PLATFORM} / ${ENV_NAME}"
            case "$PLATFORM" in
                alipay)
                    append_config_arg "--app-id" "$(read_json_field "$CONFIG_FILE" alipay "$ENV_NAME" appId)"
                    append_config_arg "--token" "$(read_json_field "$CONFIG_FILE" alipay "$ENV_NAME" token)"
                    ;;
                douyin)
                    append_config_arg "--app-id" "$(read_json_field "$CONFIG_FILE" douyin "$ENV_NAME" appId)"
                    append_config_arg "--token" "$(read_json_field "$CONFIG_FILE" douyin "$ENV_NAME" token)"
                    ;;
                weixin)
                    append_config_arg "--envId"       "$(read_json_field "$CONFIG_FILE" weixin "$ENV_NAME" envId)"
                    append_config_arg "--serviceName" "$(read_json_field "$CONFIG_FILE" weixin "$ENV_NAME" serviceName)"
                    ;;
            esac
            # 微信 token 需单独处理（用于 wxcloud login 而非 deploy 参数）
            if [ "$PLATFORM" = "weixin" ]; then
                WX_TOKEN="$(read_json_field "$CONFIG_FILE" weixin "$ENV_NAME" token)"
                WX_APP_ID="$(read_json_field "$CONFIG_FILE" weixin "$ENV_NAME" appId)"
                if [ -n "$WX_TOKEN" ] && [ -n "$WX_APP_ID" ]; then
                    echo "🔑 使用 token 认证（CI/CD 模式）"
                    wxcloud login --appId "$WX_APP_ID" --privateKey "$WX_TOKEN"
                fi
            fi
            # 配置文件参数在前，命令行参数在后；后者覆盖前者
            EXTRA_ARGS=("${CONFIG_ARGS[@]}" "${CLI_ARGS[@]}")
        else
            echo "⚠️  配置文件中未找到环境：.platforms.${PLATFORM}.\"${ENV_NAME}\"，将仅使用命令行参数继续执行"
        fi
    else
        echo "⚠️  检测到 ${CONFIG_FILE} 但未安装 jq / python3，跳过配置文件解析，仅使用命令行参数"
    fi
fi

# ---------- 2. 提取额外参数中的具名值（k v 形式） ----------
get_arg() {
    # 用法：get_arg "--app-id" "${EXTRA_ARGS[@]}"
    # 注意：返回最后一次出现的值，配合"配置文件在前、命令行在后"实现命令行覆盖。
    local key="$1"
    shift
    local prev=""
    local found=""
    local has=1
    for v in "$@"; do
        if [ "$prev" = "$key" ]; then
            found="$v"
            has=0
        fi
        prev="$v"
    done
    if [ "$has" -eq 0 ]; then
        echo "$found"
        return 0
    fi
    return 1
}

check_cli() {
    # 用法：check_cli <命令名> <安装命令>
    local cmd="$1"
    local install_cmd="$2"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "❌ 未安装 CLI 工具：${cmd}"
        echo "请先执行：${install_cmd}"
        exit 1
    fi
}

# ---------- 3. 分发到具体平台 ----------
case "$PLATFORM" in

    alipay)
        echo "📦 平台：支付宝小程序（minidev） / 环境：${ENV_NAME}"
        check_cli "minidev" "npm install -g minidev"

        APP_ID="$(get_arg "--app-id" "${EXTRA_ARGS[@]}" || true)"
        TOKEN="$(get_arg "--token" "${EXTRA_ARGS[@]}" || true)"

        if [ -z "$APP_ID" ]; then
            echo "❌ 错误：缺少 --app-id"
            exit 1
        fi

        CMD=(minidev upload
             --app-id "$APP_ID"
             --version "$VERSION"
             --description "$DESCRIPTION")

        if [ -n "$TOKEN" ]; then
            CMD+=(--token "$TOKEN")
            echo "🔑 使用 token 认证（CI/CD 模式）"
        fi

        echo "🚀 执行：${CMD[*]}"
        ( cd "$PROJECT_PATH" && "${CMD[@]}" )
        ;;

    douyin)
        echo "📦 平台：抖音小程序（tt-ide-cli） / 环境：${ENV_NAME}"
        check_cli "tma" "npm install -g tt-ide-cli"

        TOKEN="$(get_arg "--token" "${EXTRA_ARGS[@]}" || true)"

        CMD=(tma upload "$PROJECT_PATH"
             --app-version "$VERSION"
             --app-changelog "$DESCRIPTION")

        if [ -n "$TOKEN" ]; then
            CMD+=(--token "$TOKEN")
            echo "🔑 使用 token 认证（CI/CD 模式）"
        fi

        echo "🚀 执行：${CMD[*]}"
        "${CMD[@]}"
        ;;

    weixin)
        echo "📦 平台：微信小程序（@wxcloud/cli） / 环境：${ENV_NAME}"
        check_cli "wxcloud" "npm install -g @wxcloud/cli"

        ENV_ID="$(get_arg "--envId" "${EXTRA_ARGS[@]}" || true)"
        SERVICE_NAME="$(get_arg "--serviceName" "${EXTRA_ARGS[@]}" || true)"
        RELEASE_TYPE="$(get_arg "--releaseType" "${EXTRA_ARGS[@]}" || echo "FULL")"

        if [ -z "$ENV_ID" ] || [ -z "$SERVICE_NAME" ]; then
            echo "❌ 错误：缺少 --envId 或 --serviceName"
            exit 1
        fi

        CMD=(wxcloud run:deploy
             --envId "$ENV_ID"
             --serviceName "$SERVICE_NAME"
             --remark "$DESCRIPTION"
             --releaseType "$RELEASE_TYPE")

        echo "🚀 执行：${CMD[*]}"
        ( cd "$PROJECT_PATH" && "${CMD[@]}" )
        ;;

    *)
        echo "❌ 错误：不支持的平台 ${PLATFORM}"
        echo "支持的平台：alipay | douyin | weixin"
        exit 1
        ;;
esac

echo ""
echo "✅ ${PLATFORM} 平台 [${ENV_NAME}] 环境发布命令执行完毕（版本 ${VERSION}）"

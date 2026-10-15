# 微信小程序版本管理 Skill（mp-version-control）

通过 AI 对话完成微信小程序的 release 分支管理、环境构建、二维码预览、企业微信通知、体验版上传、PR 合并和打 tag。

## 适用范围

本 Skill 只处理微信小程序，不再安装或调用支付宝、抖音、`wxcloud` 等平台 CLI。

- Git：创建和同步 `release/vA.B.C` 分支
- pnpm：构建 `stg` / `prod` 微信小程序
- wechatide-skill：加载 `dist` 产物、编译、生成二维码、上传体验版
- 企业微信机器人：发送分支通知和带二维码的构建通知
- GitHub CLI：创建 PR

## 安装

```bash
npx skills add uknowzheng/mp-version-control-skill
```

前置依赖：

- Git
- Node.js / pnpm
- GitHub CLI（仅创建 PR 时需要）
- 微信开发者工具及 `wechatide` Skill

微信开发者工具的登录、状态检查、编译、二维码和上传必须通过 `wechatide-skill`，本 Skill 不直接伪造 MCP 调用。

## 命令

| 命令 | 用途 | 示例 |
|---|---|---|
| `/mp-version-setup` | 检查 GitHub CLI | `/mp-version-setup` |
| `/mp-version-init` | 初始化 Git 配置 | `/mp-version-init` |
| `/mp-version-release` | 创建并推送 release 分支 | `/mp-version-release 1.2.0` |
| `/mp-version-preview` | 拉取 release 分支并打 stg/prod 测试包 | `/mp-version-preview stg 1.2.0` |
| `/mp-version-notice` | 手动发送企业微信通知 | `/mp-version-notice 1.2.0` |
| `/mp-version-merge` | 创建 release → 主干 PR | `/mp-version-merge 1.2.0` |
| `/mp-version-tag` | 在主干创建并推送版本 tag | `/mp-version-tag 1.2.0` |

## 工作流边界

### 版本分支拉取工作流

这一步只负责创建版本分支并通知团队：

```text
/mp-version-release 1.2.0
→ 创建并推送 release/v1.2.0
→ 询问是否发送分支通知
→ （确认后发送企业微信分支通知）
```

该工作流不构建小程序，也不调用 `wechatide`。

### 打测试包工作流

`/mp-version-preview` 表示打包预览流程。以 stg 为例：

```text
/mp-version-preview stg 1.2.0
→ checkout release/v1.2.0
→ 拉最新的 release/v1.2.0 代码
→ pnpm run app:stg:mp-weixin
→ dist/stg/mp-weixin
→ wechatide 编译
→ 生成二维码
→ 询问是否发送构建通知
→ 发送文字 + 二维码图片
→ 用户明确要求后调用 wechatide upload
→ 设置上传版本号 1.2.0
```

`prod` 复用同一打包流程，仅替换构建命令和产物目录：

```text
/mp-version-preview prod 1.2.0
→ pnpm run app:prod:mp-weixin
→ dist/prod/mp-weixin
```

### 完整流程

```text
版本分支拉取工作流
→ 打测试包工作流
→ merge
→ tag
```

### 1. 创建 release 分支

```bash
bash mp-cli.sh release 1.2.0
```

脚本会从 `master` 或 `main` 创建并推送：

```text
release/v1.2.0
```

脚本完成后会切回主分支。Skill 随后询问是否发送第一类企业微信通知：

```text
版本 1.2.0 的 release/v1.2.0 分支已创建，请将需求代码合入该分支。
```

确认发送后调用 `notice`，这条通知不附带二维码。

### 2. 打测试包

```bash
bash mp-cli.sh preview stg 1.2.0
bash mp-cli.sh preview prod 1.2.0
```

构建映射固定为：

```text
stg  → pnpm run app:stg:mp-weixin  → dist/stg/mp-weixin
prod → pnpm run app:prod:mp-weixin → dist/prod/mp-weixin
```

`preview` 会：

1. 允许项目运行时生成的文件保留在工作区，例如 `src/common/router.config.js`、`src/pages.json`、`src/manifest.json`、`src/config/`、`src/common/store/business/`、`build-target/`、`dist/`、`unpackage/` 和 `.builder-hook-context.json`；
2. 仍拦截其他未提交业务代码修改；
3. 拉取远端信息；
4. 切换到 `release/vA.B.C` 并执行 fast-forward pull；
5. 执行对应 pnpm 构建；
6. 校验 `project.config.json`、有效 `appid`、`compileType` 和 `app.json`；
7. 输出 `PREVIEW_PROJECT`、`PREVIEW_PAGE` 等结果供 Agent 交给 `wechatide-skill`。

随后 Agent 调用微信开发者工具：

```text
open_project_window(project=dist/<env>/mp-weixin)
simulator_open_page(project=dist/<env>/mp-weixin, page=<app.json 首页面>)
create_preview_qrcode(project=dist/<env>/mp-weixin, qr-format=image, qr-output=<二维码图片路径>)
```

### 3. 构建完成后的企业微信通知

生成二维码后，Skill 询问是否发送第二类通知。确认后发送：

1. 版本、环境、分支和构建结果文字；
2. 二维码图片消息。

调用方式：

```bash
bash mp-cli.sh notice \
  1.2.0 \
  "stg 包已构建完成，请扫码验证" \
  "/tmp/mp-preview-1.2.0-stg.png"
```

二维码通过企业微信机器人 `image` 消息发送，使用图片 Base64 和 MD5，不要求图片有公网 URL。

`.notice` 文件格式：

```text
# 企业微信群机器人 webhook
https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_KEY
```

脚本会先发文字，再发二维码。任一发送失败都会报告失败，不会继续假装完成后续步骤。

### 4. 上传体验版

只有用户明确要求上传时，Agent 才调用微信开发者工具：

```text
upload(
  project=dist/<env>/mp-weixin,
  upload-version=1.2.0,
  desc=<版本描述>
)
```

上传前必须确认版本号、环境、产物路径和版本描述。开发者工具出现确认弹窗或返回 `pending` 时暂停等待，不自动重试上传。

## 配置

`.mp-release.json` 只保存可公开的 GitHub Enterprise 域名配置：

```json
{
  "git": {
    "hostname": ""
  }
}
```

不要将 AppID 私钥、企业微信 webhook 或其他凭据提交到 Git。`.notice` 和本地敏感配置应加入 `.gitignore`。

## 安全边界

- 分支创建、构建和二维码生成可以自动执行。
- 企业微信通知在两个节点分别询问：分支创建后、二维码生成后。
- 体验版上传是写操作，必须获得用户明确要求和开发者工具确认。
- 不自动发布正式版，不操作云数据库，不部署云函数。
- `wechatide` 工具名和参数以当前安装的 `wechatide-skill` 为准。

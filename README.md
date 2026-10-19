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
→ 生成开发者预览二维码
→ 自动发送构建通知（文字 + 二维码图片）
→ 当前任务明确要求时调用 wechatide upload
→ upload 明确成功后发送上传结果通知
→ 关闭微信开发者工具项目预览窗口
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
5. 加载 NVM 并执行 `nvm use 18`，确认成功后才执行 pnpm 构建；
6. 执行对应 pnpm 构建；
7. 校验 `project.config.json`、有效 `appid`、`compileType` 和 `app.json`；
8. 输出 `PREVIEW_PROJECT`、`PREVIEW_PAGE` 等结果供 Agent 交给 `wechatide-skill`。

随后 Agent 调用微信开发者工具：

```text
open_project_window(project=dist/<env>/mp-weixin)
simulator_open_page(project=dist/<env>/mp-weixin, page=<app.json 首页面>)
create_preview_qrcode(project=dist/<env>/mp-weixin, qr-format=image, qr-output=<二维码图片路径>)
```
这里生成的是**开发者预览二维码**，不是体验版二维码。二维码生成成功后自动发送构建通知，不再询问是否发送。

### 3. 构建完成后的企业微信通知

每次成功生成开发者预览二维码后，发送两条企业微信机器人消息：

1. 文字消息：

```text
【微信小程序构建通知】
环境：stg
版本：1.2.0
分支：release/v1.2.0
二维码类型：开发者预览二维码
说明：请开发者扫码验证
构建产物：dist/stg/mp-weixin
```

2. 开发者预览二维码图片。

调用方式：

```bash
bash mp-cli.sh notice \
  1.2.0 \
  $'【微信小程序构建通知】\n环境：stg\n版本：1.2.0\n分支：release/v1.2.0\n二维码类型：开发者预览二维码\n说明：请开发者扫码验证\n构建产物：dist/stg/mp-weixin' \
  "/tmp/mp-preview-1.2.0-stg.png"
```

二维码通过企业微信机器人 `image` 消息发送，使用图片 Base64 和 MD5，不要求图片有公网 URL。脚本先发文字，再发二维码；任一失败都会报告真实失败结果。

上传明确成功后，再发送“体验版 1.2.0 上传成功”的文字通知；上传 pending、超时、失败或取消时不得发送成功通知。

### 4. 上传体验版

用户明确要求上传后，Agent 调用微信开发者工具：

```text
upload(
  project=dist/<env>/mp-weixin,
  upload-version=1.2.0,
  desc=<版本描述>
)
```

上传完成后只使用 `upload` 实际返回的体验版二维码路径、图片或 URL。当前微信 Skill 提供独立的预览二维码工具，但没有独立的体验版二维码工具；如果 `upload` 不返回体验版二维码，只报告上传成功，并说明需要从微信开发者工具或公众平台获取体验版二维码，不能把预览二维码改称为体验版二维码。

只有 `upload` 明确成功后，才发送“已调用微信开发者工具 upload，体验版 1.2.0 上传成功”的文字通知。上传中的授权确认或 `pending` 必须等待，不得自动重试；超时、失败或取消时不得发送成功通知。

不上传时，在构建通知发送完成后关闭窗口；需要上传时，在二维码生成失败、上传完成、明确失败，或用户处理完 `pending` 后，调用 `close_project_window` 关闭本次打开的 `dist/<env>/mp-weixin` 项目窗口。

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

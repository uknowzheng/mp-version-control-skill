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
| `/mp-version-release` | 创建并推送 release 分支，自动发送 checkbranch 通知 | `/mp-version-release 1.2.0` |
| `/mp-version-preview` | 拉取 release 分支并打 stg/prod 测试包，自动发送 release 通知 | `/mp-version-preview stg 1.2.0` |
| `/mp-version-notice` | 按场景手动发送企业微信通知 | `/mp-version-notice release 1.2.0` |
| `/mp-version-merge` | 创建 release → 主干 PR | `/mp-version-merge 1.2.0` |
| `/mp-version-tag` | 在主干创建并推送版本 tag | `/mp-version-tag 1.2.0` |

## 工作流边界

### 版本分支拉取工作流

这一步负责创建版本分支，并使用 `checkbranch` webhook 通知所有人进行分支集成：

```text
/mp-version-release 1.2.0
→ 清理工作区：丢弃未提交修改，移除未跟踪文件（保留本地 webhook 配置）
→ git fetch origin --prune
→ checkout 主分支并重置为 origin/<主分支> 最新代码
→ 创建并推送 release/v1.2.0
→ 使用 .notice.checkbranch 发送分支集成通知
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

脚本会：

1. 清理工作区：丢弃未提交修改，移除未跟踪文件；本地 `.notice`、`.notice.checkbranch`、`.notice.release` 会保留；
2. `git fetch origin --prune`；
3. 切换到 `master` 或 `main`，并重置为对应 `origin/<主分支>` 的最新代码；
4. 创建并推送：

```text
release/v1.2.0
```

5. 切回主分支；
6. 使用 `.notice.checkbranch` 自动发送分支集成通知。该通知会 @ 所有人，不附带二维码。

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
7. 校验 `project.config.json`、`compileType` 和 `app.json` 的结构，但不读取 `project.config.json.appid` 作为通知来源；
8. 输出 `PREVIEW_PROJECT`、`PREVIEW_PAGE` 等结果供 Agent 交给 `wechatide-skill`；
9. 会话首次调用 `check_wechatide_status`，确认登录、版本关系和 `loginUser.nickName`；
10. 调用 `project_list(scope=miniprogram)`，按完整路径匹配 `PREVIEW_PROJECT`，从微信开发者工具返回的 `appId` 获取动态 APPID；如果没有匹配项目或 `appId` 为空，停止通知，不回退读取 `project.config.json`。

随后 Agent 调用微信开发者工具：

```text
check_wechatide_status(skill-version=<当前 wechatide-skill 版本>)
open_project_window(project=dist/<env>/mp-weixin)
project_list(scope=miniprogram)
simulator_open_page(project=dist/<env>/mp-weixin, page=<app.json 首页面>)
create_preview_qrcode(project=dist/<env>/mp-weixin, qr-format=image, qr-output=<二维码图片路径>)
```

这里生成的是**开发者预览二维码**，不是体验版二维码。只有动态 APPID、开发者昵称、编译和二维码都成功后，才自动发送构建通知；任一校验失败都不发送成功通知。

### 3. 构建完成后的企业微信通知

每次成功生成开发者预览二维码后，发送两条企业微信机器人消息：
消息中的“开发者”必须使用会话首次 `check_wechatide_status` 返回的 `loginUser.nickName`，不得使用 `xxx` 或其他占位值；如果登录态没有昵称，应停止发送并报告原因。

1. 文字消息（不 @ 所有人）：

```text
【微信小程序个人开发版本构建通知｜测试】
环境：stg
版本：1.2.0
分支：release/v1.2.0
APPID：<微信开发者工具 project_list 返回的 PREVIEW_APPID>
二维码类型：开发者预览二维码，5分钟内过期，请到小程序【开发者助手】- 选择小程序 - 版本查看 - 体验版列表 - 找到开发者的微信名称的版本
开发者：<开发者微信名称>
构建产物：dist/stg/mp-weixin
```

2. 开发者预览二维码图片。

调用方式：使用 `release` webhook：

```bash
bash mp-cli.sh notice release \
  1.2.0 \
  $'【微信小程序个人开发版本构建通知｜测试】\n环境：stg\n版本：1.2.0\n分支：release/v1.2.0\nAPPID：<微信开发者工具 project_list 返回的 PREVIEW_APPID>\n二维码类型：开发者预览二维码，5分钟内过期，请到小程序【开发者助手】- 选择小程序 - 版本查看 - 体验版列表 - 找到开发者的微信名称的版本\n开发者：<开发者微信名称>\n构建产物：dist/stg/mp-weixin' \
  "/tmp/mp-preview-1.2.0-stg.png"
```

二维码通过企业微信机器人 `image` 消息发送，使用图片 Base64 和 MD5，不要求图片有公网 URL。文字消息不带 `mentioned_list`，因此不会 @ 所有人；脚本先发文字，再发二维码图片；任一失败都会报告真实失败结果。

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

企业微信通知使用两个相互独立的本地 webhook 文件：

```text
.notice.checkbranch  # release 分支创建后，通知所有人进行分支集成
.notice.release      # 本地完成 stg/prod 出包后，通知开发者本人
```

每个文件只放一条 webhook URL，例如：

```text
https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_KEY
```

手动发送通知时，必须显式指定场景：

```bash
bash mp-cli.sh notice checkbranch <版本号> "请将需求合入 release 分支"
bash mp-cli.sh notice release <版本号> "stg 包已构建完成" <二维码图片路径>
```

`.notice.checkbranch`、`.notice.release`、二维码和其他凭据不能提交到 Git，必须加入 `.gitignore` 或本机 Git exclude。

## 安全边界

- 分支创建、构建、动态元数据读取和二维码生成可以自动执行；
- 构建二维码生成成功后自动发送个人开发版本构建通知，不 @ 所有人；
- 体验版上传是写操作，必须获得用户明确要求和开发者工具确认；只有明确上传成功后才发送上传成功通知；
- 不自动发布正式版，不操作云数据库，不部署云函数。
- `wechatide` 工具名和参数以当前安装的 `wechatide-skill` 为准。

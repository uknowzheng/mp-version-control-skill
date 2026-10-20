---
name: mp-version-control
version: 0.2.9
description: 微信小程序版本控制与预览发布。创建 release 分支，构建 stg/prod 微信小程序，调用 wechatide-skill 加载 dist、编译、生成开发者预览二维码，按 checkbranch 与 release 场景使用独立企业微信 webhook 发送分支集成和本地出包通知，自动获取动态 APPID 与开发者昵称，按用户确认上传体验版并发送上传结果，关闭项目预览窗口，支持 PR 与 tag。
---

# 微信小程序版本控制

本 Skill 只处理微信小程序。不要安装或调用支付宝、抖音、`wxcloud` 等平台 CLI。微信开发者工具操作必须交给已安装的 `wechatide-skill`，不要在 shell 中伪造 MCP 请求。

## 命令

| 命令 | Workflow |
|---|---|
| `/mp-version-release <version>` | 创建并推送 `release/v<version>`，发送 checkbranch 分支集成通知 |
| `/mp-version-preview <stg|prod> <version>` | 拉取 release 分支、打微信测试包并发送 release 出包通知 |
| `/mp-version-notice <checkbranch|release> <version>` | 按场景手动发送企业微信通知 |
| `/mp-version-merge [version]` | 创建 release → 主干 PR |
| `/mp-version-tag [version]` | 在主干创建并推送 tag |

触发词：release、拉版本、构建微信小程序、stg、prod、预览、二维码、上传体验版、通知群、合并、tag。

## 工作流边界

### 版本分支拉取工作流

这一步只负责建立版本分支并通知团队：

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
→ 用户明确要求后调用 wechatide upload
→ upload 明确成功后发送上传结果通知
→ 关闭微信开发者工具项目预览窗口
```

`prod` 使用同一流程，仅替换为：

```text
/mp-version-preview prod 1.2.0
→ checkout release/v1.2.0
→ 拉最新的 release/v1.2.0 代码
→ pnpm run app:prod:mp-weixin
→ dist/prod/mp-weixin
```

### 完整版本流程

```text
版本分支拉取工作流
→ 打测试包工作流
→ merge
→ tag
```

## 环境门禁

调用 `wechatide-skill` 前遵循其当前版本的根 `SKILL.md`：

1. 会话首次检查 `wechatide` 状态；
2. 使用当前 Skill frontmatter 的版本，不硬编码版本；
3. 确认微信开发者工具已登录且版本匹配；
4. `tokenRequired` 时使用用户从「设置 → 安全」复制的 Token；
5. 用 `project_list(scope=miniprogram)` 按 `PREVIEW_PROJECT` 完整路径匹配当前项目，从返回的 `appId` 读取动态 APPID；
6. 用首次状态检查返回的 `loginUser.nickName` 作为通知中的开发者名称；
7. 动态 APPID 或开发者昵称缺失时停止通知，不读取 `project.config.json.appid`，也不使用占位值；
8. 工具返回 `pending + taskId` 时遵循微信 Skill 的异步任务规则，不重复提交写操作。


## Workflow：release

### 输入

版本号必须匹配：

```text
^[0-9]+\.[0-9]+\.[0-9]+$
```

### 执行

```bash
bash ${SKILL_DIR}/mp-cli.sh release <版本号>
```

脚本会：

1. 检查 Git 仓库和干净工作区；
2. `git fetch origin --prune`；
3. 检测 `master` 或 `main`；
4. 同步主分支；
5. 创建并推送 `release/v<版本号>`；
6. 切回主分支。

### checkbranch 企业微信通知

分支创建成功后，询问：

```text
release/v<version> 已创建，是否使用 checkbranch webhook 通知所有人进行分支集成？
```

确认后使用 `.notice.checkbranch` 发送文字通知：

```text
小程序版本 1.2.0，release/v1.2.0 分支已创建，请将本版需求合入该分支。
```

调用：

```bash
bash ${SKILL_DIR}/mp-cli.sh notice checkbranch \
  <版本号> \
  "小程序版本 <版本号>，release/v<版本号> 分支已创建，请将本版需求合入该分支。"
```

这条通知不附带二维码；跳过通知不影响后续 `preview`。

## Workflow：打测试包（preview）

### 输入

只接受：

```text
stg
prod
```

版本号必须是 `A.B.C`。

### 打测试包内的分支同步与构建顺序

`preview` 是完整的打测试包命令。它先同步并 checkout 目标 release 分支，再继续构建；这里的 checkout 是打包流程的前置步骤，不另行归入版本分支拉取工作流。

```text
bash ${SKILL_DIR}/mp-cli.sh preview stg <版本号>
→ git fetch origin --prune
→ checkout release/v<版本号>
→ git pull --ff-only origin release/v<版本号>
→ pnpm run app:stg:mp-weixin
```

生产环境只替换构建命令：

```bash
bash ${SKILL_DIR}/mp-cli.sh preview prod <版本号>
→ checkout release/v<版本号>
→ pnpm run app:prod:mp-weixin
```

内部固定映射：

```text
stg  → pnpm run app:stg:mp-weixin  → dist/stg/mp-weixin
prod → pnpm run app:prod:mp-weixin → dist/prod/mp-weixin
```

版本分支拉取失败时，不执行 pnpm 构建，也不调用 wechatide。
构建前门禁只拦截未提交的业务代码修改。项目运行时生成或更新的文件允许保留，例如 `src/common/router.config.js`、`src/pages.json`、`src/manifest.json`、`src/config/`、`src/common/store/business/`、`build-target/`、`dist/`、`unpackage/` 和 `.builder-hook-context.json`。

如果工作区包含其他未提交文件，脚本仍会停止，避免把业务改动误带入测试包。
构建前会加载 NVM 并显式执行 `nvm use 18`，然后才执行 `pnpm run`。如果 NVM 或 Node.js 18 不可用，流程直接停止，不回退到其他 Node 版本。

脚本然后校验：

- `dist/<env>/mp-weixin` 存在；
- `project.config.json` 存在；
- `compileType` 为 `miniprogram`；
- `app.json` 存在且有首个页面。

构建脚本只校验构建产物结构，不读取 `project.config.json.appid` 作为通知来源。

脚本输出：

```text
PREVIEW_ENV
PREVIEW_VERSION
PREVIEW_BRANCH
PREVIEW_PROJECT
PREVIEW_PAGE
```

随后按以下顺序调用微信开发者工具：

1. `check_wechatide_status`：会话首次调用一次，确认登录、版本关系和 `loginUser.nickName`；
2. `open_project_window(project=PREVIEW_PROJECT)`：只加载 `dist/<env>/mp-weixin`，不要加载源码根目录；
3. `project_list(scope=miniprogram)`：按完整路径匹配 `PREVIEW_PROJECT`，读取匹配项目返回的 `appId` 作为 `PREVIEW_APPID`；找不到项目或 `appId` 为空时停止，不回退到 `project.config.json`；
4. `simulator_open_page(project=PREVIEW_PROJECT, page=PREVIEW_PAGE)`：触发编译并打开首页；
5. 编译成功后调用 `create_preview_qrcode`，使用 `qr-format=image` 和本地 `qr-output`；
6. 组装通知文字，使用动态 `PREVIEW_APPID` 和 `loginUser.nickName`，调用 `mp-cli.sh notice` 发送文字与二维码图片；
7. 当前任务明确要求上传时调用 `upload`，只有明确成功后才发送上传成功通知；
8. 不上传时在构建通知完成后关闭窗口；需要上传时在上传完成、明确失败或用户处理完 `pending` 后调用 `close_project_window`。

任何编译、二维码、动态 APPID 或开发者昵称校验失败，都不得发送成功通知或继续上传。

### 预览二维码与体验版上传

`create_preview_qrcode` 生成的是本地构建产物的开发者预览二维码，不是体验版二维码。用户明确要求上传后，调用：

```text
upload(
  project=PREVIEW_PROJECT,
  upload-version=PREVIEW_VERSION,
  desc=<版本描述>
)
```

上传成功后必须根据 `upload` 的真实返回值报告：

- 若返回中明确包含体验版二维码路径、图片或 URL，才报告体验版二维码并提供该结果；
- 若返回不包含体验版二维码，报告“体验版上传成功，但当前 wechatide Skill 未返回体验版二维码”，不要把此前的预览二维码改称为体验版二维码；
- 当前工具注册表只有 `create_preview_qrcode`（预览二维码）和 `upload`（上传体验版），没有独立的“获取体验版二维码”工具，因此不能凭猜测补调其他工具。

`upload` 返回明确成功后，才发送上传结果通知；返回 `pending + taskId`、超时、失败或取消时，不得发送“上传成功”。

`upload` 返回 `pending + taskId` 时，暂停并等待用户在微信开发者工具内完成确认；不得重发上传。用户处理完确认后，根据最终结果发送通知并关闭项目预览窗口。

不要把源码根目录交给微信开发者工具；必须加载构建产物 `dist/<env>/mp-weixin`。

## 第二类企业微信通知

开发者预览二维码生成成功后，自动发送两条企业微信机器人消息，不再询问是否发送。消息中的“开发者”必须取会话首次 `check_wechatide_status` 返回的 `loginUser.nickName`；不得使用 `xxx` 或其他占位值。若登录态没有昵称，先停止通知并报告无法取得开发者昵称。

1. 文字消息，固定使用以下格式，不 @ 所有人：

```text
【微信小程序个人开发版本构建通知｜测试】
环境：<env>
版本：<版本号>
分支：release/v<版本号>
APPID：<PREVIEW_APPID，由微信开发者工具 project_list 返回>
二维码类型：开发者预览二维码，5分钟内过期，请到小程序【开发者助手】- 选择小程序 - 版本查看 - 体验版列表 - 找到开发者的微信名称的版本
开发者：<开发者微信名称>
构建产物：dist/<env>/mp-weixin
```

2. 开发者预览二维码图片。

调用：

```bash
bash ${SKILL_DIR}/mp-cli.sh notice release \
  <版本号> \
  $'【微信小程序个人开发版本构建通知｜测试】\n环境：<env>\n版本：<版本号>\n分支：release/v<版本号>\nAPPID：<PREVIEW_APPID，由微信开发者工具 project_list 返回>\n二维码类型：开发者预览二维码，5分钟内过期，请到小程序【开发者助手】- 选择小程序 - 版本查看 - 体验版列表 - 找到开发者的微信名称的版本\n开发者：<开发者微信名称>\n构建产物：dist/<env>/mp-weixin' \
  <二维码图片绝对路径>
```

`notice.sh` 通过企业微信机器人 `image` 消息发送本地二维码的 Base64 和 MD5，不需要公网图片 URL。文字消息不再携带 `mentioned_list`，因此不会 @ 所有人；先发文字，后发二维码图片；任一失败都必须报告真实失败结果。

`upload` 明确成功后，再发送一条文字消息：

```text
【微信小程序上传通知】
环境：<env>
版本：<版本号>
操作：已调用微信开发者工具 upload
结果：体验版 <版本号> 上传成功
```

上传未明确成功时，不得发送“上传成功”通知。

## Workflow：upload

上传不是 shell CLI 命令，由 Agent 调用 `wechatide-skill` 的 `upload`：

```text
upload(
  project=PREVIEW_PROJECT,
  upload-version=<版本号>,
  desc=<版本描述>
)
```

- 只有用户明确要求“上传体验版/上传代码”时才调用；
- 上传前确认环境、项目路径、版本号和描述；
- 开发者工具弹窗、授权或 `pending` 时等待用户处理；
- 用户拒绝、超时或取消后不要自动重试；
- 上传成功前不能报告“已上传”，也不能发送“上传成功”通知；
- 只有 `upload` 明确返回成功后，才发送包含“已调用 upload”和版本号的上传结果通知；
- 上传成功后只使用 `upload` 实际返回的体验版二维码路径、图片或 URL；
- `upload` 未返回体验版二维码时，明确报告已上传但当前工具无法自动获取体验版二维码，不得复用或改名此前的开发者预览二维码；
- 上传完成、明确失败，或用户处理完 `pending` 后，调用 `close_project_window` 关闭本次打开的 `PREVIEW_PROJECT`。

## Workflow：notice

手动通知必须显式指定场景：

```bash
bash ${SKILL_DIR}/mp-cli.sh notice checkbranch <版本号> "请将需求合入 release 分支"
bash ${SKILL_DIR}/mp-cli.sh notice release <版本号> "stg 包已构建完成" <二维码图片路径>
```

场景与配置文件对应关系：

| 场景 | 配置文件 | 用途 |
|---|---|---|
| `checkbranch` | `.notice.checkbranch` | release 分支创建后，通知所有人进行分支集成 |
| `release` | `.notice.release` | 本地完成 stg/prod 出包后，通知开发者本人，可附开发者预览二维码 |

每个配置文件只放一条企业微信 webhook URL：

```text
https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_KEY
```

两个配置文件、二维码和其他凭据不能提交到 Git，必须加入 `.gitignore` 或本机 Git exclude。

## Workflow：merge

```bash
bash ${SKILL_DIR}/mp-cli.sh merge [版本号]
```

脚本确保当前 release 分支已推送，然后用 GitHub CLI 创建 release → 主干 PR。不要自动合并 PR。

## Workflow：tag

```bash
bash ${SKILL_DIR}/mp-cli.sh tag [版本号]
```

脚本同步主分支，创建并推送 `v<版本号>`。只有确认 PR 已合并后才执行。

## 错误处理

| 情况 | 处理 |
|---|---|
| 工作区不干净 | 停止并报告文件，不自动 stash |
| release 分支不存在 | 停止并报告，不猜测其他分支 |
| 构建失败 | 不调用 wechatide，不发送成功通知，不上传 |
| dist 产物不完整 | 停止并报告具体缺失文件 |
| wechatide 编译失败 | 不生成成功二维码报告，不上传 |
| 动态 APPID 或开发者昵称缺失 | 停止发送通知，不读取 `project.config.json.appid`，不使用占位值 |
| 构建通知发送失败 | 报告真实失败，不伪造成功；按用户决定是否重试 |
| 上传被拒绝、取消、超时或 `pending` | 不重试，不报告成功；按最终结果关闭项目窗口 |
| `gh` 未登录 | 停止 merge，提示 `gh auth login` |

---
name: mp-version-control
description: 小程序版本管理与发布工具。创建 release 分支并调用各平台 CLI 工具上传/发布小程序代码。适用于需要创建 release 分支、上传小程序版本、发布支付宝/抖音/微信小程序时使用。支持 slash 命令：/mp-version-setup、/mp-version-init、/mp-version-release、/mp-version-publish、/mp-version-merge、/mp-version-tag。触发词：release、发布、小程序、版本、上传、mp-version、setup、安装。
---

# 小程序版本管理与发布

本 Skill 提供以下核心能力：

- **环境安装（setup）**：一键安装 GitHub CLI 和各平台小程序 CLI 工具
0. **初始化配置（init）**：在项目根目录生成 `.mp-release.json`，集中管理各平台认证参数
1. **创建 Release 分支**：基于语义化版本号从主分支创建 `release/vA.B.C` 分支
2. **发布小程序**：调用支付宝（minidev）、抖音（tt-ide-cli）、微信（@wxcloud/cli）三大平台 CLI 工具完成版本上传/发布
3. **合并到主干（merge）**：通过 GitHub CLI 为 release 分支创建 PR 合入 master/main
4. **打标签（tag）**：在主干上创建 `vA.B.C` 标签，保留 release 分支

## Slash 命令

| 命令 | 功能 | 示例 |
| --- | --- | --- |
| `/mp-version-setup` | 安装所需 CLI 工具（gh、minidev、tma、wxcloud） | `/mp-version-setup` |
| `/mp-version-init` | 初始化 `.mp-release.json` 配置文件 | `/mp-version-init` |
| `/mp-version-release` | 创建 release/vA.B.C 分支 | `/mp-version-release 1.2.0` |
| `/mp-version-publish` | 发布小程序到指定平台 | `/mp-version-publish` |
| `/mp-version-merge` | 创建 PR 合并到主干 | `/mp-version-merge` |
| `/mp-version-tag` | 在主干上打版本标签 | `/mp-version-tag` |

当用户输入以上任意 slash 命令时，直接执行对应命令的 Workflow，无需额外确认命令类型。
如果命令后附带了参数（如版本号），直接使用该参数，不再询问。

## 触发场景

- `/mp-version-setup` 或“安装 CLI”、“setup”
- `/mp-version-init` 或“初始化配置”、“init”
- `/mp-version-release` 或“创建 release 分支”、“拉版本”
- `/mp-version-publish` 或“发布小程序”、“上传”
- `/mp-version-merge` 或“合并到主干”、“创建 PR”
- `/mp-version-tag` 或“打 tag”、“打标签”
- 用户提到 init、release、版本号、上传、发布、merge、tag 等关键词

---

## 命令：环境安装（setup）

### 触发场景

- `/mp-version-setup` 或“安装 CLI 工具”、“setup”

### Workflow

1. **询问安装范围**：使用 AskUserQuestion 询问用户要安装哪些工具（支持多选）：GitHub CLI (gh)、支付宝 CLI (minidev)、抖音 CLI (tt-ide-cli)、微信 CLI (@wxcloud/cli)、或全部安装
2. **执行安装**：

```bash
bash ${SKILL_DIR}/mp-cli.sh setup --all
# 或选择性安装
bash ${SKILL_DIR}/mp-cli.sh setup --gh --alipay
```

脚本会自动检测已安装的工具并跳过，只安装缺失的。

3. **反馈结果**：告知用户安装结果，提示下一步可执行 init 初始化配置。若 `.mp-release.json` 中配置了 `git.hostname`，额外提示用户执行 `gh auth login --hostname <domain>`。

### 前置条件

- Node.js 和 npm、Homebrew（macOS）

---

## 命令零：初始化配置（init）

### 触发场景

- 用户要求“初始化小程序配置”、“/init”、“配置平台参数”；项目首次接入本 Skill

### 功能说明

在项目根目录生成 `.mp-release.json` 配置文件，集中保存各平台必备参数。后续"发布小程序"流程会优先读取该文件，避免每次重复询问。

### Workflow

#### Step 1：询问 GitHub Enterprise 配置

使用 `AskUserQuestion` 询问：

```
问题：是否使用 GitHub 企业版（GitHub Enterprise）？
选项：是 / 否
```

如果是，追问域名（不含 `https://` 前缀，如 `scm.starbucks.com`）。如果否，`hostname` 保留为空字符串。

#### Step 2：选择要配置的平台

使用 `AskUserQuestion` 多选询问：

```
问题：要配置哪些平台？（支持多选）
选项：支付宝 / 抖音 / 微信
```

#### Step 3：针对每个平台，询问环境数量与环境名

针对每个被选中的平台，先使用 `AskUserQuestion` 询问：

```
问题：要为 <平台名> 配置几个环境？
校验：必须为大于等于 1 的正整数（如 1、2、3）
```

再对每个环境逐个询问其名称（用户自定义，不做固定约束）：

```
问题：请输入第 N 个环境的名称（如 prod / test / staging / default 等）
```

#### Step 4：逐环境收集参数

针对每个已命名的环境，使用 `AskUserQuestion` 依次收集对应字段：

| 平台 | 必填字段 | 可选字段 |
| --- | --- | --- |
| 支付宝（alipay） | `appId` | `token` |
| 抖音（douyin） | `appId` | `token` |
| 微信（weixin） | `appId`、`envId`、`serviceName` | `token` |

> 💡 `token` 为可选字段，用于 CI/CD 免登录认证。留空则使用预登录会话。

#### Step 5：生成配置文件

先调用脚本生成模板（默认在每个平台下生成 `default` 环境占位），再由 AI 按上一步收集的真实环境名与字段值改写为最终结构：

```bash
bash ${SKILL_DIR}/mp-cli.sh init <项目路径>
```

#### Step 6：提示加入 .gitignore

建议将 `.mp-release.json` 加入版本忽略：

```bash
echo '.mp-release.json' >> .gitignore
```

### 配置文件格式

每个平台下按「环境名」分组，环境名由用户自定义（如 `prod`、`test`、`staging`、`default` 等均可）：

```json
{
  "git": {
    "hostname": ""
  },
  "platforms": {
    "alipay": {
      "prod": {
        "appId": "2021000000000000",
        "token": ""
      },
      "test": {
        "appId": "2021000000000001",
        "token": ""
      }
    },
    "douyin": {
      "prod": {
        "appId": "ttxxxxxxx",
        "token": ""
      }
    },
    "weixin": {
      "prod": {
        "appId": "wx_prod_abcdef",
        "envId": "prod-1abc2def",
        "serviceName": "app-service",
        "token": ""
      },
      "test": {
        "appId": "wx_test_123456",
        "envId": "test-3ghi4jkl",
        "serviceName": "app-service-test",
        "token": ""
      }
    }
  }
}
```

### 注意事项

- 文件已存在时脚本会询问是否覆盖；非交互场景可设置 `MP_INIT_OVERWRITE=y`
- 仅需配置实际使用的平台与环境，未使用的字段可保留为空字符串
- 同一平台可配置任意多个环境，环境名完全自由（prod/test/staging/default 等）
- `git.hostname`：GitHub 企业版域名（不含 `https://`），留空则使用默认 github.com
- `token`：可选，用于 CI/CD 免登录认证；留空则依赖各平台 CLI 预登录会话
- 建议加入 `.gitignore`

---

## 命令一：创建 Release 分支

### 分支命名规范

- 格式：`release/vA.B.C`（A、B、C 均为非负整数，遵循语义化版本规范）
- 来源分支：自动检测仓库中存在的 `master` 或 `main`

### Workflow

#### Step 1：询问版本号

使用 `AskUserQuestion` 工具向用户收集版本号：

```
问题：请输入要创建的 release 版本号（格式 A.B.C，例如 1.2.0）
校验：必须匹配正则 ^[0-9]+\.[0-9]+\.[0-9]+$
```

如果用户输入不合法，重新询问直至格式正确。

#### Step 2：调用脚本创建分支

执行随附脚本完成检测、拉取与推送：

```bash
bash ${SKILL_DIR}/mp-cli.sh release <版本号>
```

脚本会自动完成：

1. 校验版本号格式
2. 检测主分支为 `master` 还是 `main`（优先 `master`，其次 `main`）
3. `git fetch origin` 拉取最新远端信息
4. 切换到主分支并 `git pull` 同步最新代码
5. 创建本地分支 `release/v<版本号>`
6. `git push -u origin release/v<版本号>` 推送至远端

#### Step 3：反馈结果

向用户确认分支创建成功，并提示后续可执行"发布小程序"命令。

### 注意事项

- 若工作区有未提交修改，脚本会终止；需要先提交或 stash
- 若 `release/v<版本号>` 分支已存在，脚本会报错并退出
- 仓库需已配置 `origin` 远端

---

## 命令二：发布小程序

支持三个平台 CLI，工具与平台映射：

| 平台 | CLI 包名 | 全局命令 |
| --- | --- | --- |
| 支付宝小程序 | `minidev` | `minidev` |
| 抖音小程序 | `tt-ide-cli` | `tma` |
| 微信小程序 | `@wxcloud/cli` | `wxcloud` |

### Workflow

#### Step 1：询问发布平台

使用 `AskUserQuestion` 询问用户：

```
问题：要发布到哪些平台？（支持多选）
选项：支付宝 / 抖音 / 微信
```

#### Step 2：询问发布环境

针对每个选中的平台，读取项目根目录的 `.mp-release.json`：

- 若该平台在配置文件中**仅有一个环境**（如仅一个 `default` 或仅一个 `prod`），直接使用，不再询问
- 若该平台在配置文件中**存在多个环境**，使用 `AskUserQuestion` 询问：

```
问题：要将 <平台名> 发布到哪个环境？
选项：列出该平台下配置文件中的所有环境名（动态读取，如 prod / test / staging 等）
```

- 若配置文件不存在或该平台未配置，询问用户手动输入环境名（可提示先执行「命令零：init」）

#### Step 3：询问版本号

使用 `AskUserQuestion` 询问版本号，默认值为当前 release 分支解析出的版本号：

```bash
# 解析当前分支
git rev-parse --abbrev-ref HEAD   # 期望输出 release/vA.B.C
```

如当前不在 `release/*` 分支上，提示用户先切换或先执行"创建 Release 分支"命令。

#### Step 4：询问版本描述

使用 `AskUserQuestion` 收集本次发布的更新日志/描述（一段中文文字即可）。

#### Step 5：确认平台必备参数

参数读取优先级：

1. **优先**：从项目根目录的 `.mp-release.json` 读取 `.platforms.<平台>.<环境名>` 下的配置（若存在且字段非空，直接使用，不再向用户询问）
2. **fallback**：若配置文件不存在、对应平台/环境缺失或字段为空，再使用 `AskUserQuestion` 交互式收集（参数说明见下方各平台章节）
3. **覆盖**：用户在命令行显式传入的 `EXTRA_ARGS` 优先级最高，会覆盖配置文件中的同名值

> 💡 若用户尚未初始化配置，可建议先执行「命令零：初始化配置（init）」。

**认证优先级：**

- 若配置文件中 `token` 字段有值，自动使用 token 进行免登录认证（CI/CD 模式）
- 若 `token` 为空，依赖各平台 CLI 的预登录会话（本地模式）
- 支付宝/抖音：token 作为 `--token` 参数传给 upload 命令
- 微信：token 作为 `--privateKey` 传给 `wxcloud login` 完成免登录

#### Step 6：检查并执行

针对每个平台依次执行：

```bash
bash ${SKILL_DIR}/mp-cli.sh publish <平台> <环境名> <版本号> "<描述>" [额外参数...]
```

脚本内部会先检查 CLI 是否已安装，未安装则中止并提示安装命令。

---

### 平台一：支付宝小程序（minidev）

#### 安装

```bash
npm install -g minidev
```

#### 认证方式

发布前需完成认证（二选一）：

- **本地模式**：预先执行 `minidev quickauth`，配置文件中 `token` 留空
- **CI/CD 模式**：在配置文件中填入 `token`，发布时自动传给 `minidev upload --token`

#### 上传命令

```bash
minidev upload \
  --app-id <APPID> \
  --version <版本号> \
  --description "<描述>"
```

#### 参数说明

| 参数 | 说明 | 示例 |
| --- | --- | --- |
| `--app-id` | 支付宝小程序 App ID | `2021000000000000` |
| `--version` | 版本号 | `1.2.0` |
| `--description` | 版本描述 | `"修复登录问题"` |

调用：

```bash
bash ${SKILL_DIR}/mp-cli.sh publish alipay prod 1.2.0 "修复登录问题"
```

---

### 平台二：抖音小程序（tt-ide-cli）

#### 安装

```bash
npm install -g tt-ide-cli
```

#### 认证方式

发布前需完成认证（二选一）：

- **本地模式**：预先执行 `tma login`，配置文件中 `token` 留空
- **CI/CD 模式**：在配置文件中填入 `token`，发布时自动传给 `tma upload --token`

#### 上传命令

```bash
tma upload <项目路径> \
  --app-version <版本号> \
  --app-changelog "<更新日志>"
```

#### 参数说明

| 参数 | 说明 | 示例 |
| --- | --- | --- |
| `<项目路径>` | 小程序源码目录 | `./` |
| `--app-version` | 版本号 | `1.2.0` |
| `--app-changelog` | 更新日志 | `"新增首页改版"` |

调用：

```bash
bash ${SKILL_DIR}/mp-cli.sh publish douyin prod 1.2.0 "新增首页改版"
```

---

### 平台三：微信小程序（@wxcloud/cli）

> 注意：`@wxcloud/cli` 主要用于微信云开发服务部署。若仅上传小程序代码请使用 `miniprogram-ci`。本 Skill 按需求文档使用 `@wxcloud/cli`。

#### 安装

```bash
npm install -g @wxcloud/cli
```

#### 认证方式

发布前需完成认证（二选一）：

- **本地模式**：预先执行 `wxcloud login`，配置文件中 `token` 留空
- **CI/CD 模式**：在配置文件中填入 `token`，发布时自动执行 `wxcloud login --appId <appId> --privateKey <token>`

#### 部署命令

```bash
wxcloud run:deploy \
  --envId <环境ID> \
  --serviceName <服务名> \
  --remark "<版本备注>" \
  --releaseType FULL
```

#### 参数说明

| 参数 | 说明 | 示例 |
| --- | --- | --- |
| `--envId` | 云开发环境 ID | `prod-1abc2def` |
| `--serviceName` | 服务名 | `app-service` |
| `--remark` | 版本备注 | `"v1.2.0 修复 bug"` |
| `--releaseType` | 发布类型 | `FULL` 或 `GRAY` |

调用：

```bash
bash ${SKILL_DIR}/mp-cli.sh publish weixin test 1.2.0 "v1.2.0 修复 bug"
```

---

## 命令三：合并到主干（merge）

### 触发场景

- 用户说“合回主干”、“合并到 master”、“创建 PR”；灰度完成后需将 release 分支合入主干

### Workflow

1. **确认版本号**：使用 AskUserQuestion 确认要合并的版本号（默认从当前 release 分支自动解析）。
2. **创建 PR**：`bash ${SKILL_DIR}/mp-cli.sh merge <版本号>`。脚本会：确保在对应 release 分支 → 推送最新代码 → 检测主分支（master/main）→ 通过 `gh pr create` 创建 PR（标题 `Release A.B.C`）。
3. **反馈结果**：告知用户 PR 已创建，提示在 GitHub 上 review 后合并，合并后可执行打 tag 操作。

### 前置条件

- 已安装并认证 GitHub CLI（`gh auth login`）
- 如使用 GitHub Enterprise：配置 `git.hostname` 并执行 `gh auth login --hostname <domain>`

---

## 命令四：打标签（tag）

### 触发场景

- 用户说“打 tag”、“打标签”、“创建版本标签”；PR 已合并到主干后

### Workflow

1. **确认版本号**：使用 AskUserQuestion 确认版本号（默认从上下文或当前分支解析）。
2. **创建并推送 tag**：`bash ${SKILL_DIR}/mp-cli.sh tag <版本号>`。脚本会：fetch 远端 → 切换到主分支并 pull → 检查 tag 不重复 → 创建带注释的 tag `vA.B.C` → 推送 tag 到远端 → 保留 release 分支（不删除）。
3. **反馈结果**：告知用户 tag 已创建成功，release 分支已保留。

---

## 完整执行示例

```text
用户：帮我发个 1.2.0 版本，发到支付宝和抖音
Skill：询问平台/环境/版本号/描述 → 读取配置 → 检查 CLI → 执行 publish → 汇总结果
```

## 错误处理

| 场景 | 处理方式 |
| --- | --- |
| 版本号格式错误 | 重新调用 `AskUserQuestion` 询问 |
| 主分支不存在 | 中止并提示用户检查仓库 |
| release 分支已存在 | 中止并提示用户更换版本号 |
| CLI 未安装 | 中止并输出对应的 `npm install -g ...` 安装命令 |
| 上传失败 | 输出 CLI 原始错误信息，提示用户检查认证/网络 |
| 不在 release 分支 | 提示用户先切换分支或执行"创建 Release 分支" |

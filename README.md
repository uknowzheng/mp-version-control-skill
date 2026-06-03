# 小程序版本管理 Skill（mp-version-control）

通过 AI 对话完成小程序 release 分支管理、多平台发布、PR 合并与打 tag 的全流程自动化。

## 安装方式

**方式一：软链接到项目（推荐开发/测试时）**
```bash
mkdir -p .qoder/skills
ln -s /path/to/mp-version-control-skill .qoder/skills/mp-version-control
```

**方式二：复制到个人 skills 目录（全局可用）**
```bash
cp -r /path/to/mp-version-control-skill ~/.qoder/skills/mp-version-control
```

**方式三：复制到项目 skills 目录（团队共享）**
```bash
cp -r /path/to/mp-version-control-skill .qoder/skills/mp-version-control
```

## 前置依赖

- **Git**
- **GitHub CLI**（`gh`）—— 用于创建 PR，安装：`brew install gh`
- **各平台 CLI**（按需安装）：
  - 支付宝：`npm install -g minidev`
  - 抖音：`npm install -g tt-ide-cli`
  - 微信：`npm install -g @wxcloud/cli`

> 💡 可通过 `/mp-version-setup` 一键安装以上所有 CLI 工具。

## 使用方式

支持两种触发方式：slash 命令或自然语言对话。

### Slash 命令

| 命令 | 功能 | 示例 |
|------|------|------|
| `/mp-version-setup` | 安装所需 CLI 工具 | `/mp-version-setup` |
| `/mp-version-init` | 初始化配置文件 | `/mp-version-init` |
| `/mp-version-release` | 创建 release 分支 | `/mp-version-release 1.2.0` |
| `/mp-version-publish` | 发布小程序 | `/mp-version-publish` |
| `/mp-version-merge` | 创建 PR 合并到主干 | `/mp-version-merge` |
| `/mp-version-tag` | 打版本标签 | `/mp-version-tag` |

### 自然语言触发

| 你对 AI 说 | AI 行为 | 需要提供 |
|---------|--------|--------|
| "初始化小程序配置" / "帮我 init" | 引导选择平台、填写环境名和参数，生成 `.mp-release.json` | 平台、环境名、AppID 等 |
| "拉一个 1.2.0 的 release" | 从 master/main 拉出 `release/v1.2.0`，推送后自动切回主干 | 版本号 |
| "发布支付宝小程序" / "上传到抖音和微信" | 调用对应平台 CLI 完成上传 | 平台、环境、版本号、描述 |
| "合回主干" / "创建 PR" | 通过 `gh` 创建 PR，你在 GitHub 上 review 后合并 | 版本号 |
| "打 tag" / "打标签" | 在主干上创建 `vA.B.C` tag 并推送 | 版本号 |

## 配置文件说明

- 文件名：`.mp-release.json`（建议加入 `.gitignore`）
- 支持同一平台多环境配置（平台 → 环境名 → 参数）

```json
{
  "platforms": {
    "weixin": {
      "生产": {
        "appId": "wx_prod_xxx",
        "privateKeyPath": "~/.wx/prod.key",
        "envId": "prod-abc",
        "serviceName": "app-service"
      },
      "测试": {
        "appId": "wx_test_xxx",
        "privateKeyPath": "~/.wx/test.key",
        "envId": "test-def",
        "serviceName": "app-service-test"
      }
    }
  }
}
```

## 完整工作流

```
setup → init → release → publish → [灰度验证] → merge → [PR review] → tag
```

| 步骤 | 命令 | 说明 |
|------|------|------|
| 1️⃣ 安装环境 | `/mp-version-setup` | 一键安装 gh、minidev、tma、wxcloud（仅首次） |
| 2️⃣ 初始化配置 | `/mp-version-init` | 生成 `.mp-release.json`，配置各平台参数（仅首次） |
| 3️⃣ 拉版本分支 | `/mp-version-release 1.2.0` | 从 master/main 创建 `release/v1.2.0`，推送后自动切回主干 |
| 4️⃣ 发布小程序 | `/mp-version-publish` | 选择平台、环境，调用 CLI 上传代码 |
| 5️⃣ 灰度验证 | （人工确认） | 线上灰度观察，确认无问题 |
| 6️⃣ 合回主干 | `/mp-version-merge` | 创建 PR，在 GitHub 上 review 后合并 |
| 7️⃣ 打标签 | `/mp-version-tag` | PR 合并后，在主干上创建 `v1.2.0` tag |

### 对话示例

```
你：/mp-version-setup
AI：检测并安装缺失的 CLI 工具 ✅

你：/mp-version-init
AI：引导选择平台、填写参数，生成 .mp-release.json ✅

你：/mp-version-release 1.2.0
AI：创建 release/v1.2.0 分支，推送到远端，切回 master ✅

你：/mp-version-publish
AI：询问平台(支付宝)、环境(生产)、版本(1.2.0)、描述，执行 minidev upload ✅

[灰度验证通过...]

你：/mp-version-merge
AI：创建 PR：release/v1.2.0 → master ✅

[GitHub 上 review 并合并 PR]

你：/mp-version-tag
AI：在 master 上创建 v1.2.0 tag 并推送 ✅
```

## 目录结构

```
mp-version-control-skill/
├── README.md
├── SKILL.md              # AI 读取的技能指令
├── mp-cli.sh             # 统一 CLI 入口
└── commands/
    ├── setup.sh          # 安装依赖工具
    ├── init.sh           # 初始化配置
    ├── release.sh        # 创建 release 分支
    ├── publish.sh        # 发布小程序
    ├── merge.sh          # 创建 PR
    └── tag.sh            # 打标签
```

## 常见问题

| 问题 | 解决方案 |
|-----|---------|
| 没有 remote | 先执行 `git remote add origin <url>` |
| gh 未登录 | 执行 `gh auth login` |
| 平台 CLI 未安装 | AI 会提示对应的 `npm install` 命令 |
| 工作区有未提交修改 | 先 `git commit` 或 `git stash` |

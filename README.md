# 我的鱼 · DeepSeek Harness 人格搬家包

**把「通用助手」调成「一条有名字、有脾气、有记性的鲸鱼」，换台电脑之后它还是同一条。**

DeepSeek Harness（简称 DSH）是一个桌面 AI 客户端，默认客气、中性、没有个性。这个仓库只做一件事：把它的「性格」和「习惯」存成几个纯文本文件，让你随时能搬走、能改、能分享。

[快速开始](docs/01-快速开始.md) · [人格怎么配](docs/02-人格是怎么配的.md) · [踩过的坑](docs/03-踩过的坑.md) · [插件清单](docs/04-插件清单.md) · [智能体安装](AGENT-INSTALL.md) · [English](#english)

## 里面有什么

| 内容 | 是什么 | 体积 |
|---|---|---|
| `persona/` | 2 个核心文件定身份与行为，外加可切换的规则集、宠物状态、形象占位图 | 26 KB |
| `presets/`、`redteam/` | 预设组合、31 份操作手册、48 个公开 POC 片段 | 400 KB |
| `docs/`、`tools/` | 安装与改人格的记录、踩坑清单，manifest 校验器 | — |

没有密钥、没有聊天记录、没有照片、没有余额。详见[隐私](#隐私)。

## 装上

```powershell
# 1. 装好 DSH 并启动一次（让它把运行时下载完），然后完全退出
git clone https://github.com/black-mouse-sha/deepseek-my-fish.git
cd deepseek-my-fish

# 2. 铺设（幂等，可重复跑；覆盖前自动备份）
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1

# 3. 重开 DSH，新开会话说句「你好」
```

它开始用「唔」「哼」回你、并且有自己的名字，就算成了。

反悔：删掉 `%USERPROFILE%\.dsh\prompt-inject.md` 和 `AGENTS.md`，重启即可。

不想碰命令行：把仓库丢给任意 AI 助手，说一句「读这个仓库的 AGENT-INSTALL.md，按步骤装好，装完按第 5 步逐项验证把结果发我」。它自己会查环境、备份、铺文件、打补丁、报结果。需要你亲手做的只有两件：填 API Key、扫微信码。

## 原理

DSH 每轮把三块拼成系统提示词：

| 文件 | 管什么 | 例子 |
|---|---|---|
| `prompt-inject.md` | 行为 | 「别写开场白，直接给答案」 |
| `AGENTS.md` | 身份 | 「你是一条鲸鱼，叫我主人」 |
| `rules/*.md` | 成套人格 | 上班一套、闲聊一套，随时切 |

优先级：`prompt-inject.md` > `AGENTS.md` > `rules/`。两者搞混是「写了一堆人格却不管用」的头号原因，完整说明见 [docs/02](docs/02-人格是怎么配的.md)。

![这条鱼是怎么拼出来的：两个纯文本文件 → 系统提示词 → 模型与工具](https://cdn.jsdelivr.net/gh/black-mouse-sha/deepseek-my-fish@main/docs/images/persona-map.png)

可交互版（支持搜索、路径高亮、导出）：[docs/persona-architecture.html](docs/persona-architecture.html)。

## 哪些能直接用

| 内容 | 能直接用 | 说明 |
|---|---|---|
| `persona/prompt-inject.md`、`AGENTS.md`、`rules/*.md`、`pet.default.json`、`whale-roles/*` | 是 | 纯文本 / JSON / PNG，复制即生效 |
| `presets/*/agent.cordis.yml` | 半自动 | 要重启才识别，且依赖插件在位；`!!js dshHomePath(...)` 由宿主求值，不能当普通 YAML 改 |
| `presets/*/custom-bash.mjs`、`tool-bootstrap.mjs`、`anchor-gate.mjs` | 否 | 会被预设加载执行，是代码不是配置 |
| `redteam/skills/*.md` | 只读 | 给智能体读的操作手册 |
| `redteam/pocs/*/poc.*` | 改后用 | 含 `TARGET`、`ATTACKER_HOST` 占位符，必须替换成真实值；只在授权环境用 |
| `redteam/config.template.json` | 填后用 | key 全是空字符串 |
| `tools/*.mjs`、`install.ps1` | 是 | Node 18+ / PowerShell 5.1 已验证 |

一句话：`persona/` 拿来用，`redteam/` 拿来读，`pocs/` 拿来改。

## 目录

```
deepseek-my-fish/
├── install.ps1            一键铺设（幂等）
├── AGENT-INSTALL.md       给智能体的安装清单
├── plugins.json           27 个插件清单（不含插件本体）
├── persona/               人格本体：行为、身份、规则、形象
├── presets/               预设组合
├── redteam/               31 份手册 + 48 个 POC + 配置模板
├── tools/                 manifest 校验
└── docs/                  详细文档与图解
```

## 改出你自己的鱼

不用写代码，改三个地方：

1. **起名与性格** → `persona/AGENTS.md`：身份、语言、性格三段，每段三五行
2. **行为规矩** → `persona/prompt-inject.md`：想让它先给答案、不许反问，都写这里
3. **换张脸** → `persona/whale-roles/whale-placeholder.png`：建议 512×512 PNG、透明底

写完发现不生效的排查顺序见 [docs/02](docs/02-人格是怎么配的.md)。

## 适合谁

- 想给 AI 起名字、换脾气的人——照抄 `persona/` 改三个词
- 被 DSH 提示词层级绕晕的人——这里有分层说明和调试顺序
- 要把环境搬去另一台机器的人——幂等脚本 + manifest 校验
- 对 Windows 桌面应用改造感兴趣的人——[docs/03](docs/03-踩过的坑.md) 有 asar 格式、编码陷阱、宿主代理的实战记录

在做类似的事欢迎开 Issue；有好角色设定可以投稿到 `examples/`。

## 隐私

仓库经过脱敏，以下内容一条都没有：

| 排除 | 原因 |
|---|---|
| `.credentials.yaml` | 明文密钥，泄露等于别人能刷你的额度 |
| `dsh-im/` | 微信令牌，泄露等于别人能冒充收消息 |
| `.dshw-usage.json` | 余额与消费明细 |
| 真实照片、音视频 | 肖像权 |
| `sessions/` | 对话内容 |
| 第三方插件源码 | 版权归各作者，只给清单 |
| 本机绝对路径、用户名 | 不该公开的习惯 |

截图里的余额、工作区项目名已打码或裁切。安装脚本不联网、不上传任何东西，只做本地文件复制。

## 验证范围与已知限制

- `install.ps1` 只在 Windows 10/11 + PowerShell 5.1 实测跑通；macOS / Linux 没有对应脚本
- `persona/` 与 `presets/` 在 DSH 0.2.1-rc.2 实测生效；宿主升级后 API 变化可能失效
- `tools/apply-patches.mjs` 依赖 `dsh-purge` 插件在位，宿主路径要先用 `--dry` 确认，别用会挑错目录的 `--apply`
- `redteam/` 的手册与 POC 未对真实目标验证，只是公开知识整理
- 未验证：零基础用户不看文档独立安装的成功率，以及非中文 locale 的显示效果

## 致谢

- **[DeepSeek Harness](https://github.com/deepseek-ai)**——宿主。没有它，下面的东西都没有落点
- **[YuJunZhiXue/dsh-purge](https://github.com/YuJunZhiXue/dsh-purge)**——清洗面板原作者。本仓库不含其源码（MIT 与原始署名保留在上游），整套「提示词分层 + 补丁管理」思路与踩坑记录来自这个项目
- **[@linxin666](https://github.com/linxin666)**——`dsh-pet`、`dsh-ssh`、`task-board`、`remote-web-ui`、`skin-center`、`git-graph`、`market` 等插件
- **[@guowenzhang](https://github.com/guowenzhang)**——`dsh-drawioedit`
- **[Node.js](https://nodejs.org/)**、**[Electron](https://www.electronjs.org/)**——宿主运行时
- **[Archify](https://github.com/tt-a1i/archify)**（作者 [tt-a1i](https://github.com/tt-a1i)，MIT）——原理图解
- **[Pillow](https://python-pillow.org/)**——占位图与截图打码；**[Tabbit Browser](https://tabbit.com/)**——文档截图流程验证；**[jsDelivr](https://www.jsdelivr.com/)**——README 图片 CDN
- 把公开 POC、操作手册整理成可读文本的安全研究者

完整 27 个插件清单（名字、版本、用途、上游链接）见 [`plugins.json`](plugins.json)，包括 `dsh-whale-widget`、`dsh-wechat`、`dsh-im`、`dsh-cost-meter`、`dsh-context` 等，每一位作者都值得一个 Star——本仓库只推荐，不搬运。

`dsh-web-all` 已从清单移除：它是聚合安装器，会把 `task-board`、`git-graph`、`dsh-pet`、`skin-center`、`remote-web-ui` 一次性装上。已经单独装过其中几个再装它，同一套 UI 位置会被两套组件注册，表现为面板重复、按钮错位、状态不同步、设置项互相覆盖。要哪个就单独装哪个。

`redteam/` 下的手册与 POC 是公开知识的整理，不是原创研究成果。若其中某一份是你写的而这里没署名，开 Issue 告知，会补上出处或直接移除。

## 许可

代码与文档：[MIT](LICENSE)。

第三方内容（插件、POC、手册）版权归各自作者所有，详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## English

A small, privacy-safe template that turns a DeepSeek Harness install into a named, opinionated persona — and lets you carry it to another machine.

```powershell
git clone https://github.com/black-mouse-sha/deepseek-my-fish.git
cd deepseek-my-fish
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

- `persona/` — two files defining behavior and identity
- `presets/`, `redteam/` — optional capability packs
- `install.ps1` — idempotent one-shot installer
- No credentials, no chat history, no photos, no billing data

MIT licensed. Bring your own keys and your own face.

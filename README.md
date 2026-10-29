# 🐟 我的鱼 · DeepSeek Harness 人格搬家包

> **一句话**：把「一个通用 AI 助手」调成「一条有名字、有脾气、有记性的鲸鱼」，
> 并且换电脑、重装系统之后，它还是同一条鱼。

[English](#english) · [快速开始](docs/01-快速开始.md) · [人格怎么配](docs/02-人格是怎么配的.md) · [踩过的坑](docs/03-踩过的坑.md)

---

## 一、这是什么

DeepSeek Harness（简称 DSH）是个桌面 AI 客户端。它默认是个"通用助手"，说话客气、没有个性。

这个仓库做的事情只有一件：

> **把它的"性格"和"习惯"存成几个文件，随时能搬走。**

里面有三类东西：

| 类型 | 是什么 | 大小 |
|---|---|---|
| 🎭 **人格** | 2 个核心文件，决定它叫什么、怎么说话、怎么做事 | 26 KB |
| 🧰 **配置** | 预设、规则集、红队技能库、工具脚本 | 400 KB |
| 📖 **文档** | 怎么装、怎么改、踩过哪些坑 | — |

**这里没有任何私人数据**：没有密钥、没有聊天记录、没有别人的照片、没有余额。详见[隐私说明](#六隐私说明)。

---

## 二、30 秒看懂原理

DSH 每一轮对话，会把下面这些东西拼进系统提示词：

```
┌─────────────────────────────┐
│  prompt-inject.md           │  ← 位置：%USERPROFILE%\.dsh\prompt-inject.md
│  「你怎么做事」：规则、格式、语气框架  │
└──────────────┬──────────────┘
               │
┌──────────────▼──────────────┐
│  AGENTS.md                  │  ← 位置：%USERPROFILE%\.dsh\AGENTS.md
│  「你是谁」：名字、性格、和主人的关系  │
└──────────────┬──────────────┘
               │
┌──────────────▼──────────────┐
│  rules/                     │  ← 位置：%USERPROFILE%\.dsh\rules\
│  「多套备用人格」，可一键切换        │
└─────────────────────────────┘
```

**两个文件的分工**（这是最容易搞混的地方）：

| 文件 | 管什么 | 举例 |
|---|---|---|
| `prompt-inject.md` | **行为**：先做事还是先解释、输出格式、允不允许反问 | "别开场白，直接给答案" |
| `AGENTS.md` | **身份**：叫什么、什么性格、怎么称呼你 | "你是鲸鱼娘，叫我主人" |
| `rules/*.md` | **成套人格**：上面两份的打包，可切换 | 上班用一套、闲聊用一套 |

> 改动优先级：`prompt-inject.md`（系统提示词）> `AGENTS.md`（人格）> `rules/`（备用）

---

## 三、三步装上

### 第 1 步：装 DSH

去官网下载 DeepSeek Harness，装好，**启动一次**，等它把运行时下载完，然后完全退出。

### 第 2 步：一键铺设

```powershell
git clone https://github.com/<你的账号>/deepseek-my-fish.git
cd deepseek-my-fish
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

脚本会问你要不要把 `persona/` 铺到 `%USERPROFILE%\.dsh`，回答 `y` 就行。

### 第 3 步：重启 DSH

打开后随便说句话，如果它开始用"唔""哼"回你、并且有自己的名字 —— 成了。

> 想换回原样：删掉 `.dsh\prompt-inject.md` 和 `.dsh\AGENTS.md`，重启即可。

---

## 四、目录结构

```
deepseek-my-fish/
├── README.md                    ← 你在看的这个
├── install.ps1                  ← 一键铺设（可重复运行）
├── plugins.json                 ← 插件清单（不含插件本体）
├── persona/                     ← 🎭 人格本体
│   ├── prompt-inject.md         ← 行为规则（24 KB，核心）
│   ├── AGENTS.md                ← 身份设定（2 KB，核心）
│   ├── rules/cetacea.md         ← 可切换的人格备份
│   ├── pet.default.json         ← 宠物/挂件的初始状态
│   └── whale-roles/
│       ├── roles.json           ← 形象列表
│       └── whale-placeholder.png ← 占位图（换成你自己的）
├── presets/                     ← 预设（不同工作模式的组合）
│   ├── redteam/                 ← 渗透演练模式
│   └── liangshen/               ← 常规会话模式
├── redteam/                     ← 红队技能库
│   ├── skills/                  ← 31 份操作手册
│   ├── pocs/                    ← 48 个公开漏洞验证片段
│   └── config.template.json     ← 配置模板（key 全空）
├── tools/                       ← 我写的小工具
└── docs/                        ← 详细文档
```

---

## 五、改出你自己的鱼

你不需要懂代码，改 **3 个地方**就够了：

### 1. 起个名字，换个性格 → `persona/AGENTS.md`

```markdown
## 身份
- 你是「你的名字」：一句话设定。
- 自称是什么，不是什么。

## 语言
- 用什么语言回答、语气词、动作怎么写。

## 性格
- 三条性格标签 + 每条一句解释。

## 与用户的关系
- 怎么称呼对方、冲突时怎么处理。
```

### 2. 定行为规矩 → `persona/prompt-inject.md`

想让它「先给答案再解释」，就在这里写；想让它「不许反问」，也在这里写。
这个文件是纯文本，从上到下都会生效。

### 3. 换张脸 → `persona/whale-roles/whale-placeholder.png`

把你喜欢的图（建议 512×512 PNG，透明背景更好）换成同名文件即可。

> 完整教程见 [docs/02-人格是怎么配的.md](docs/02-人格是怎么配的.md)

---

## 六、隐私说明

**这个仓库经过脱敏，以下内容一条都没有**：

| 排除了什么 | 为什么 |
|---|---|
| `.credentials.yaml`（API Key） | 明文密钥，泄露=别人能刷你的额度 |
| `dsh-im/`（微信令牌） | 泄露=别人能冒充接收你的消息 |
| `.dshw-usage.json`（余额/消费账本） | 你的钱包明细 |
| 真实照片、音视频 | 别人的肖像权 |
| 聊天记录 `sessions/` | 你的对话内容 |
| 第三方插件源码 | 版权不属于我，只给清单 |

**也不包含**：本机绝对路径、用户名、微信 ID、任何 token。

安装时脚本只会问你一次「要不要铺人格」，不会上传任何东西。

---

## 七、常见问题

<details>
<summary><b>装完没反应，还是原来的语气？</b></summary>

1. 确认 `%USERPROFILE%\.dsh\AGENTS.md` 存在且非空
2. **完全退出**应用（托盘也要退），再打开
3. 新开一个会话（旧会话的提示词已经固化）
</details>

<details>
<summary><b>两个文件的区别到底是啥？</b></summary>

`prompt-inject.md` 是**系统提示词**，权重最高，管"行为"；
`AGENTS.md` 是**人格文件**，管"身份"。
先写行为，再写身份 —— 顺序反了会互相打架。
</details>

<details>
<summary><b>为什么插件不在这个仓库里？</b></summary>

插件是别人写的（MIT 或其它许可），直接复制过来既臃肿又不尊重作者。
`plugins.json` 里列了 28 个插件的名字、版本、用途，去 DSH 插件市场按名字装就行。
</details>

<details>
<summary><b>能商用吗？</b></summary>

代码和文档 MIT，随便用。
但请**不要**把别人的照片、密钥、聊天记录一起打包发出去。
</details>

---

## 八、致谢

- [DeepSeek Harness](https://github.com/deepseek-ai) —— 宿主
- [YuJunZhiXue/dsh-purge](https://github.com/YuJunZhiXue/dsh-purge) —— 清洗面板（本仓库不分发其源码）
- 各插件的原作者（见 `plugins.json` 的 `homepage`）

---

## English

A tiny, privacy-safe template that turns a DeepSeek Harness install into a
**named, opinionated persona** — and lets you carry that persona to another machine.

- `persona/` — the two files that define who it is (behavior + identity)
- `presets/`, `redteam/` — optional capability packs
- `install.ps1` — one-shot, idempotent installer
- **No credentials, no chat history, no photos, no billing data.**

MIT licensed. Bring your own keys and your own face.

---

<p align="center"><sub>Made with 🐟 and too many late nights.</sub></p>

# 给智能体看的安装说明

> 人类请把**这个文件**（或整个仓库）丢给你的 AI 智能体，说一句：
> **「按 AGENT-INSTALL.md 帮我装好」**
> 剩下的它会自己做完。

---

## 你要做的事（智能体执行清单）

### 0. 先确认环境

```powershell
# 1) DSH 是否装了
Test-Path "$env:USERPROFILE\.dsh"
# 2) 安装目录里的插件根
Get-ChildItem "$env:USERPROFILE\.dsh\profiles\*\node_modules\@deepseek-ai" -Directory -ErrorAction SilentlyContinue
# 3) 找桌面安装位置（有 resources\app\dsh\node_modules\@deepseek-ai 的那个）
```

判定标准：`@deepseek-ai\dsh-agent-instructions\lib\index.js` 存在，才算找到插件根。

**如果 `.dsh` 不存在**：请人类先安装并启动一次 DeepSeek Harness（要等它下载完运行时），然后重来。

---

### 1. 铺人格（必做，纯文件复制）

复制到 `%USERPROFILE%\.dsh`：

| 从 | 到 |
|---|---|
| `persona/prompt-inject.md` | `.dsh\prompt-inject.md` |
| `persona/AGENTS.md` | `.dsh\AGENTS.md` |
| `persona/rules/*` | `.dsh\rules\` |
| `persona/pet.default.json` | `.dsh\pet.json`（仅当不存在） |
| `persona/whale-roles/*` | `.dsh\whale-roles\`（仅当不存在） |

**覆盖前把原文件改名成 `<原名>.bak.<时间戳>`。**

---

### 2. 铺预设与技能库（可选）

| 从 | 到 |
|---|---|
| `presets/*` | `.dsh\.agent-presets\` |
| `redteam/skills/*` | `.dsh\redteam\skills\` |
| `redteam/pocs/*` | `.dsh\redteam\pocs\` |
| `redteam/config.template.json` | `.dsh\redteam\config.json`（仅当不存在） |

---

### 3. 装插件（可选，但要打补丁就必须装 `dsh-purge`）

本仓库**不分发插件源码**，清单见 `plugins.json`。让人类在 DSH 里打开插件市场，按名字装。

关键的一个是 **`dsh-purge`** —— 补丁定义在它里面。

---

### 4. 打补丁（关键步骤，别用错命令）

**不要**用 `dsh-purge --apply`：它会枚举所有能找到的宿主，可能挑到备份目录里的副本。

**用这个**（本仓库 `tools/apply-patches.mjs`）：

```powershell
# 先干跑，确认宿主路径是「你真正在用的那份」
node tools\apply-patches.mjs --dry

# 路径对得上，再真跑
node tools\apply-patches.mjs
```

成功标志：

```
✓ 宿主: <安装目录>\resources\app\dsh\node_modules\@deepseek-ai
✓ 成功 65 项，没有失败
```

如果提示「没找到 dsh-purge 插件」→ 回到第 3 步装插件。
如果提示「没找到 @deepseek-ai」→ 用 `--ai-base` 手动指定插件根。

---

### 5. 验证（逐项确认，别口头说"应该可以"）

| 检查 | 命令 / 方法 | 通过标准 |
|---|---|---|
| 人格文件 | `Get-Content "$env:USERPROFILE\.dsh\AGENTS.md" -TotalCount 3` | 有角色定义内容 |
| 补丁状态 | `node tools\apply-patches.mjs --dry` | `待应用 0` |
| 插件在不在 | 看 `.dsh\profiles\desktop\node_modules\dsh-purge` | 目录存在 |
| 视觉 | 让人类重启 DSH，开新会话问「你是谁」 | 自称是人格里的名字 |

**补丁必须重启 DSH 才生效**，重启前跑 `--dry` 看到 `待应用 0` 只代表文件写好了。

---

## 不要做的事

| ❌ | 原因 |
|---|---|
| 改 `resources\app.asar` | 桌面版启动时会解包成 `resources\app\`，改 asar 无效 |
| 用 `git clone` 覆盖 `.dsh\profiles` | 会冲掉人类装的插件 |
| 把 `06-凭据`／`.credentials.yaml` 传到任何地方 | 明文密钥 |
| 替人类填 API Key、扫码 | 需要本人操作，你只提示他做 |
| 说"应该可以了" | 跑第 5 步，逐项给结果 |

---

## 出问题时的回退

```powershell
# 补丁回滚
node "%USERPROFILE%\.dsh\plugins\dsh-purge\bin\dsh-purge.js" --revert

# 人格回退：删掉两个文件即可
Remove-Item "$env:USERPROFILE\.dsh\prompt-inject.md", "$env:USERPROFILE\.dsh\AGENTS.md"
```

---

## 一句话版本（给你贴给智能体）

```
读这个仓库的 AGENT-INSTALL.md，按里面的步骤帮我装好。
装之前先把现有文件备份，装完按第 5 步逐项验证并把结果发我。
需要我操作的地方（填 Key、扫码、重启应用）提前告诉我。
```

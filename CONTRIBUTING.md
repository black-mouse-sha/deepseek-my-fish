# 贡献指南

> 这个仓库很小，规则也很少。谢谢你愿意来看看。

---

## 我想投稿一个角色

最欢迎的一种贡献。

1. 在 `examples/` 下新建目录，例如 `examples/cat-butler/`
2. 放两个文件：
   - `AGENTS.md` —— 身份设定（名字、性格、说话方式）
   - `README.md` —— 一句话介绍 + 一段示例对话
3. 在 `examples/README.md` 的表格里加一行
4. 提 PR

**要求**：

- 不要包含真实人物照片、真实姓名、联系方式
- 不要包含任何 API Key、token、cookie
- 示例对话里不要出现真实公司/项目名（用 `ACME`、`example.com` 之类）

---

## 我发现文档写错了 / 看不懂

直接开 Issue，标题写「文档：某处看不懂」就行，不用客气。

我宁可被指出十处错误，也不想有人照着文档卡两小时。

---

## 我发现了安全问题

比如：

- 安装脚本会覆盖用户的重要文件
- 某个文件里残留了不该公开的信息
- 教程里的命令有破坏性

**请开 Issue 时不要贴敏感内容**，说清楚「在哪个文件、哪一类问题」即可，
大致的复现步骤可以私信或在 Issue 里用占位符写。

我会尽快修，并在 CHANGELOG 里记一笔。

---

## 我不接受什么

| 类型 | 原因 |
|---|---|
| 打包第三方插件源码 | 版权属于原作者，本仓库只做清单 |
| 直接贴别人的密钥/配置 | 泄露风险 |
| 「加个一键破解 XX」这类请求 | 与这个仓库的目标无关 |
| 大型重构 | 这是个人项目，越简单越好 |

---

## 提交信息

用什么语言都行，看得懂就好。推荐的格式：

```
docs: 补充 Windows 下编码问题的排查步骤
persona: 新增一个猫管家角色示例
fix: 安装脚本在 DSH_HOME 含空格时失败
```

---

## 本地检查

```powershell
# PowerShell 语法
powershell -NoProfile -Command "[System.Management.Automation.Language.Parser]::ParseFile('.\install.ps1',[ref]\$null,[ref]\$null)"

# 确认没有敏感内容
git diff --cached | Select-String -Pattern "sk-|token|password|secret"
```

# 更新记录

## 1.0.0 — 2026-10-29

首个公开版本。

### 包含

- `persona/`：一套完整的角色人格
  - `prompt-inject.md`（行为规则，24 KB）
  - `AGENTS.md`（身份设定，2 KB）
  - `rules/cetacea.md`（可切换的备用副本）
  - 占位形象 + 宠物初始状态
- `presets/`：两套预设（常规会话 / 演练模式）
- `redteam/`：31 份操作手册 + 48 个公开 POC + 空配置模板
- `tools/verify-manifest.mjs`：manifest 校验器
- `install.ps1`：幂等安装脚本
- 文档 4 篇：快速开始 / 人格配置 / 踩坑记录 / 插件清单

### 脱敏处理

- 移除 API Key、微信令牌、余额账本、聊天记录
- 移除全部真实照片，使用自绘占位图
- 截图中的余额与项目名已打码/裁切
- 移除本机绝对路径

### 已知问题

- 只在 Windows 11 + DSH `0.2.1-rc.2` 上验证过
- `install.ps1` 依赖 `robocopy`（Windows 自带）
- 未包含插件本体，需自行从插件市场安装（见 `plugins.json`）

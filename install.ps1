# ============================================================
#  deepseek-my-fish · 一键铺设人格
#  用法：powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
#  说明：可重复运行；覆盖前会把旧文件备份成 .bak.<时间戳>
#  本脚本不联网、不上传任何东西
# ============================================================
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
if (-not $Root) { $Root = Split-Path $MyInvocation.MyCommand.Definition -Parent }

$H = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $env:USERPROFILE '.dsh' }
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

function Say($t) { Write-Host $t }

Say ""
Say "=============================================="
Say "  deepseek-my-fish  ·  人格铺设"
Say "  目标目录: $H"
Say "=============================================="
Say ""

if (-not (Test-Path -LiteralPath $H)) {
  Say "[停止] 没找到 $H"
  Say "       请先安装并启动一次 DeepSeek Harness，让它把运行时下载完，再运行本脚本。"
  Read-Host "按回车退出"
  exit 1
}

$ok = Read-Host "把人格铺到这个目录？已有文件会先备份 (y/N)"
if ($ok -notmatch '^[yY]') { Say "已取消。"; Read-Host "按回车退出"; exit 0 }

function Backup($p) {
  if (Test-Path -LiteralPath $p) {
    Copy-Item -LiteralPath $p -Destination "$p.bak.$Stamp" -Force
  }
}

function PutFile($src, $dst, [switch]$NoOverwrite) {
  if (-not (Test-Path -LiteralPath $src)) { Say "  [跳过] 缺少 $src"; return }
  New-Item -ItemType Directory -Force -Path (Split-Path $dst -Parent) | Out-Null
  if ((Test-Path -LiteralPath $dst) -and $NoOverwrite) { Say "  [保留] $(Split-Path $dst -Leaf) 已存在"; return }
  Backup $dst
  Copy-Item -LiteralPath $src -Destination $dst -Force
  Say "  [完成] $(Split-Path $src -Leaf)"
}

function PutTree($src, $dst) {
  if (-not (Test-Path -LiteralPath $src)) { Say "  [跳过] 缺少 $src"; return }
  New-Item -ItemType Directory -Force -Path $dst | Out-Null
  & robocopy $src $dst /E /XC /XN /XO /NFL /NDL /NJH /NJS /R:1 /W:1 | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "robocopy 失败 ($LASTEXITCODE): $src -> $dst" }
  Say "  [完成] $(Split-Path $src -Leaf)/"
}

Say "[1/5] 人格（行为 + 身份）"
PutFile (Join-Path $Root 'persona\prompt-inject.md') (Join-Path $H 'prompt-inject.md')
PutFile (Join-Path $Root 'persona\AGENTS.md')        (Join-Path $H 'AGENTS.md')

Say "[2/5] 规则集（可切换的备用人格）"
PutTree (Join-Path $Root 'persona\rules') (Join-Path $H 'rules')

Say "[3/5] 预设"
PutTree (Join-Path $Root 'presets') (Join-Path $H '.agent-presets')

Say "[4/5] 红队技能库（可选，纯文本手册）"
PutTree (Join-Path $Root 'redteam\skills') (Join-Path $H 'redteam\skills')
PutTree (Join-Path $Root 'redteam\pocs')   (Join-Path $H 'redteam\pocs')
PutFile (Join-Path $Root 'redteam\config.template.json') (Join-Path $H 'redteam\config.json') -NoOverwrite

Say "[5/5] 挂件资源"
PutFile (Join-Path $Root 'persona\pet.default.json') (Join-Path $H 'pet.json') -NoOverwrite
PutFile (Join-Path $Root 'persona\whale-roles\roles.json') (Join-Path $H 'whale-roles\roles.json') -NoOverwrite
PutFile (Join-Path $Root 'persona\whale-roles\whale-placeholder.png') (Join-Path $H 'whale-roles\whale-placeholder.png') -NoOverwrite

Say ""
Say "----------------------------------------------"
Say "  下一步："
Say "  1) 完全退出 DeepSeek Harness（托盘也要退）"
Say "  2) 重新打开，新开一个会话"
Say "  3) 说句「你好」，看它是不是换了个语气"
Say ""
Say "  想换自己的形象：替换 $H\whale-roles\whale-placeholder.png"
Say "  想装插件：见 docs\04-插件清单.md"
Say "----------------------------------------------"
Say ""
Read-Host "按回车退出"

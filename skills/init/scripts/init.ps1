# claude-to-claw workspace 初始化 script（Windows PowerShell）。
# 與 init.sh 保持功能對等。
#
# 規則：
# - 一律用範本更新 CLAUDE.md（內容不同時先備份）。
# - 其他既有檔案一律不改動。
# - 只補上缺少的範本檔。
[CmdletBinding()]
param(
  [string]$Target = '',
  [string]$Name = '',
  [string]$Role = '',
  [string]$Tone = '',
  [string]$Policies = '',
  [string]$Language = '',
  [switch]$Upgrade,
  [switch]$NonInteractive,
  [switch]$Help
)

$ErrorActionPreference = 'Stop'
$TemplateVersion = '0.1.0'

if ($Help) {
  @'
用法：init.ps1 [options]

建立或安全升級 claude-to-claw workspace。

選項：
  -Target DIR       workspace 目錄（預設：%USERPROFILE%\Documents\claude-claw）
  -Name NAME        agent 名稱（預設：Claw）
  -Role TEXT        agent 角色 / 使命
  -Tone TEXT        個性 / 語氣
  -Policies TEXT    工作政策，用 ';' 或換行分隔
  -Language TEXT    偏好語言（預設：繁體中文（zh-TW））
  -Upgrade          既有 workspace：只更新 CLAUDE.md，並補上缺少的檔案
  -NonInteractive   不問問題，只使用旗標與預設值
  -Help             顯示本說明

重跑是安全的：只會更新 CLAUDE.md（必要時先備份），並補上缺少的
範本檔。其他檔案不會被覆寫。
'@ | Write-Output
  exit 0
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TemplateDir = (Resolve-Path (Join-Path $ScriptDir '..\template') -ErrorAction SilentlyContinue)
if (-not $TemplateDir) { throw "找不到範本目錄，應在 $ScriptDir 的上一層" }
$TemplateDir = $TemplateDir.Path
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$OsName = 'windows'
$DefaultTarget = Join-Path $env:USERPROFILE 'Documents\claude-claw'

function OneLine([string]$s) { return (($s -replace '[\r\n]+', ' ').Trim()) }

# 只在互動模式、非升級、且該值仍為空時詢問。
function Ask([string]$Current, [string]$Prompt, [string]$Default) {
  if ($Current) { return $Current }
  if (-not $NonInteractive -and -not $Upgrade -and [Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
    $reply = Read-Host "$Prompt [$Default]"
    if ($reply) { return $reply }
  }
  return $Default
}

$Target = Ask $Target 'workspace 目錄' $DefaultTarget
if ($Target -eq '~' -or $Target.StartsWith('~/') -or $Target.StartsWith('~\')) {
  $Target = Join-Path $env:USERPROFILE $Target.Substring(1).TrimStart('/', '\')
}
New-Item -ItemType Directory -Force -Path $Target | Out-Null
$Target = (Resolve-Path $Target).Path

# 既有 workspace 略過個性問題。
$Existing = (Test-Path (Join-Path $Target '.claude-to-claw\manifest.json')) -or (Test-Path (Join-Path $Target 'CLAUDE.md'))
if ($Existing) { $Upgrade = [switch]$true }

$Name = OneLine (Ask $Name 'agent 名稱' 'Claw')
$Role = OneLine (Ask $Role 'agent 角色 / 使命' '常駐助理。把每件任務交給 Subagent。')
$Tone = OneLine (Ask $Tone '個性 / 語氣' '簡潔、友善、直接。')
$Policies = Ask $Policies "工作政策（用 ';' 分隔）" ''
$Language = OneLine (Ask $Language '偏好語言' '繁體中文')

# 把自由格式的多項文字轉成「- 項目」行（依換行、';'、全形分號分割）。
function ToBullets([string]$text) {
  $items = @()
  foreach ($raw in ($text -split "[\r\n;；]+")) {
    $line = $raw.Trim()
    $line = ($line -replace '^(-|\*|•)\s+', '').Trim()
    if ($line) { $items += $line }
  }
  return $items
}

$PolicyItems = @(ToBullets $Policies)

function Render([string]$Src, [string]$Dst) {
  $out = New-Object System.Collections.Generic.List[string]
  foreach ($line in [IO.File]::ReadAllLines($Src)) {
    if ($line -eq '{{USER_POLICIES}}') {
      foreach ($p in $PolicyItems) { $out.Add("- $p") }
      continue
    }
    $line = $line.Replace('{{AGENT_NAME}}', $Name).Replace('{{AGENT_ROLE}}', $Role).Replace('{{AGENT_TONE}}', $Tone)
    $line = $line.Replace('{{PREFERRED_LANGUAGE}}', $Language).Replace('{{WORKSPACE_PATH}}', $Target).Replace('{{OS}}', $OsName)
    $out.Add($line)
  }
  $text = if ($out.Count -gt 0) { ($out -join "`n") + "`n" } else { '' }
  [IO.File]::WriteAllText($Dst, $text, $Utf8)
}

$Updated = New-Object System.Collections.Generic.List[string]
$Backed = New-Object System.Collections.Generic.List[string]
$Added = New-Object System.Collections.Generic.List[string]
$Kept = New-Object System.Collections.Generic.List[string]
$Changed = $false

function SameBytes([string]$A, [string]$B) {
  return [System.Linq.Enumerable]::SequenceEqual([IO.File]::ReadAllBytes($A), [IO.File]::ReadAllBytes($B))
}

# --- CLAUDE.md：一律更新（必要時先備份）---
$SrcClaude = Join-Path $TemplateDir 'CLAUDE.md'
$DstClaude = Join-Path $Target 'CLAUDE.md'
if (-not (Test-Path $DstClaude)) {
  Copy-Item $SrcClaude $DstClaude
  $Added.Add('CLAUDE.md'); $Changed = $true
} elseif (SameBytes $SrcClaude $DstClaude) {
  $Kept.Add('CLAUDE.md（已是最新）')
} else {
  $BackupDir = Join-Path $Target '.claude-to-claw\backups'
  New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
  $BackupName = 'CLAUDE.md.{0}.bak' -f (Get-Date -Format 'yyyyMMdd-HHmmss')
  Copy-Item $DstClaude (Join-Path $BackupDir $BackupName)
  Copy-Item $SrcClaude $DstClaude -Force
  $Backed.Add(".claude-to-claw/backups/$BackupName")
  $Updated.Add('CLAUDE.md'); $Changed = $true
}

# --- 其他檔案：只在缺少時新增 ---
$Files = Get-ChildItem -Path $TemplateDir -Recurse -File -Force | Sort-Object FullName
foreach ($f in $Files) {
  $rel = $f.FullName.Substring($TemplateDir.Length).TrimStart('\', '/').Replace('\', '/')
  if ($rel -eq 'CLAUDE.md') { continue }
  if ($rel -eq '.claude/settings.windows.json') { continue }
  if ($rel -eq '.claude/settings.json') { continue }   # handled below from settings.windows.json

  $dst = Join-Path $Target ($rel.Replace('/', '\'))
  if (Test-Path $dst) { $Kept.Add($rel); continue }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
  if ($rel -in @('SOUL.md', 'POLICY.md', 'USER.md')) { Render $f.FullName $dst } else { Copy-Item $f.FullName $dst }
  $Added.Add($rel); $Changed = $true
}

# --- Windows hook settings：把 settings.windows.json 複製成 .claude/settings.json ---
$SettingsDst = Join-Path $Target '.claude\settings.json'
if (Test-Path $SettingsDst) {
  $Kept.Add('.claude/settings.json')
} else {
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $SettingsDst) | Out-Null
  Copy-Item (Join-Path $TemplateDir '.claude\settings.windows.json') $SettingsDst
  $Added.Add('.claude/settings.json'); $Changed = $true
}

# --- .claude-to-claw/profile.json：只建立一次 ---
$State = Join-Path $Target '.claude-to-claw'
New-Item -ItemType Directory -Force -Path $State | Out-Null
$Profile = Join-Path $State 'profile.json'
if (Test-Path $Profile) {
  $Kept.Add('.claude-to-claw/profile.json')
} else {
  $obj = [ordered]@{ name = $Name; role = $Role; tone = $Tone; language = $Language; policies = @($PolicyItems) }
  $json = ($obj | ConvertTo-Json -Depth 4)
  [IO.File]::WriteAllText($Profile, $json + "`n", $Utf8)
  $Added.Add('.claude-to-claw/profile.json'); $Changed = $true
}

# --- .claude-to-claw/manifest.json ---
$Manifest = Join-Path $State 'manifest.json'
$NowIso = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$InitializedAt = $NowIso
$UpdatedAt = $NowIso
$ManifestExisted = Test-Path $Manifest
if ($ManifestExisted) {
  try {
    $old = Get-Content -Raw $Manifest | ConvertFrom-Json
    if ($old.initialized_at) { $InitializedAt = [string]$old.initialized_at }
    # 本次沒有改動：保留 manifest（含 updated_at）。
    if (-not $Changed -and $old.template_version -eq $TemplateVersion -and $old.os -eq $OsName -and $old.updated_at) {
      $UpdatedAt = [string]$old.updated_at
    }
  } catch { }
}
$NewManifest = "{`n  `"template_version`": `"$TemplateVersion`",`n  `"initialized_at`": `"$InitializedAt`",`n  `"updated_at`": `"$UpdatedAt`",`n  `"os`": `"$OsName`"`n}`n"
$OldText = if ($ManifestExisted) { [IO.File]::ReadAllText($Manifest).Replace("`r`n", "`n") } else { '' }
if ($ManifestExisted -and $OldText -eq $NewManifest) {
  $Kept.Add('.claude-to-claw/manifest.json')
} else {
  [IO.File]::WriteAllText($Manifest, $NewManifest, $Utf8)
  if ($ManifestExisted) { $Updated.Add('.claude-to-claw/manifest.json') } else { $Added.Add('.claude-to-claw/manifest.json') }
}

# --- 摘要 ---
Write-Output "claude-to-claw workspace: $Target"
if ($Existing) { Write-Output '模式：升級既有 workspace' } else { Write-Output '模式：新 workspace' }
Write-Output ''
foreach ($i in $Updated) { Write-Output "[updated]  $i" }
foreach ($i in $Backed)  { Write-Output "[backed up]  $i" }
foreach ($i in $Added)   { Write-Output "[added]  $i" }
foreach ($i in $Kept)    { Write-Output "[kept]  $i" }
Write-Output ''
Write-Output "下一步：cd `"$Target`"; claude   # 然後執行 /remote-control"

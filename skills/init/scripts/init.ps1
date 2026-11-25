# claude-to-claw workspace initializer (Windows PowerShell).
# Keep feature-equivalent with init.sh.
#
# Rules:
# - CLAUDE.md is always refreshed from the template (backup first if it differs).
# - Every other existing file is left untouched.
# - Missing template files are added.
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
Usage: init.ps1 [options]

Create or safely upgrade a claude-to-claw workspace.

Options:
  -Target DIR       Workspace directory (default: %USERPROFILE%\Documents\claude-claw)
  -Name NAME        Agent name (default: Claw)
  -Role TEXT        Agent role / mission
  -Tone TEXT        Persona / tone
  -Policies TEXT    Working policies; separate items with ';' or newlines
  -Language TEXT    Preferred language (default: English)
  -Upgrade          Existing workspace: refresh CLAUDE.md and add missing files only
  -NonInteractive   Never prompt; use flags and defaults
  -Help             Show this help

Re-running is safe: only CLAUDE.md is refreshed (with a backup) and missing
template files are added. Nothing else is overwritten.
'@ | Write-Output
  exit 0
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TemplateDir = (Resolve-Path (Join-Path $ScriptDir '..\template') -ErrorAction SilentlyContinue)
if (-not $TemplateDir) { throw "Template directory not found next to $ScriptDir" }
$TemplateDir = $TemplateDir.Path
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$OsName = 'windows'
$DefaultTarget = Join-Path $env:USERPROFILE 'Documents\claude-claw'

function OneLine([string]$s) { return (($s -replace '[\r\n]+', ' ').Trim()) }

# Prompt only when interactive, not upgrading, and the value is still unset.
function Ask([string]$Current, [string]$Prompt, [string]$Default) {
  if ($Current) { return $Current }
  if (-not $NonInteractive -and -not $Upgrade -and [Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
    $reply = Read-Host "$Prompt [$Default]"
    if ($reply) { return $reply }
  }
  return $Default
}

$Target = Ask $Target 'Workspace directory' $DefaultTarget
if ($Target -eq '~' -or $Target.StartsWith('~/') -or $Target.StartsWith('~\')) {
  $Target = Join-Path $env:USERPROFILE $Target.Substring(1).TrimStart('/', '\')
}
New-Item -ItemType Directory -Force -Path $Target | Out-Null
$Target = (Resolve-Path $Target).Path

# Skip persona questions for an existing workspace.
$Existing = (Test-Path (Join-Path $Target '.claude-to-claw\manifest.json')) -or (Test-Path (Join-Path $Target 'CLAUDE.md'))
if ($Existing) { $Upgrade = [switch]$true }

$Name = OneLine (Ask $Name 'Agent name' 'Claw')
$Role = OneLine (Ask $Role 'Agent role / mission' 'Persistent assistant that dispatches every task to subagents.')
$Tone = OneLine (Ask $Tone 'Persona / tone' 'Concise, friendly, and direct.')
$Policies = Ask $Policies "Working policies (separate with ';')" ''
$Language = OneLine (Ask $Language 'Preferred language' 'English')

# Turn free-form multi-item text into "- item" lines (split on newline, ';', full-width ';').
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

# --- CLAUDE.md: always refreshed (with backup) ---
$SrcClaude = Join-Path $TemplateDir 'CLAUDE.md'
$DstClaude = Join-Path $Target 'CLAUDE.md'
if (-not (Test-Path $DstClaude)) {
  Copy-Item $SrcClaude $DstClaude
  $Added.Add('CLAUDE.md'); $Changed = $true
} elseif (SameBytes $SrcClaude $DstClaude) {
  $Kept.Add('CLAUDE.md (already up to date)')
} else {
  $BackupDir = Join-Path $Target '.claude-to-claw\backups'
  New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
  $BackupName = 'CLAUDE.md.{0}.bak' -f (Get-Date -Format 'yyyyMMdd-HHmmss')
  Copy-Item $DstClaude (Join-Path $BackupDir $BackupName)
  Copy-Item $SrcClaude $DstClaude -Force
  $Backed.Add(".claude-to-claw/backups/$BackupName")
  $Updated.Add('CLAUDE.md'); $Changed = $true
}

# --- Everything else: add only when missing ---
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

# --- Windows hook settings: settings.windows.json becomes .claude/settings.json ---
$SettingsDst = Join-Path $Target '.claude\settings.json'
if (Test-Path $SettingsDst) {
  $Kept.Add('.claude/settings.json')
} else {
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $SettingsDst) | Out-Null
  Copy-Item (Join-Path $TemplateDir '.claude\settings.windows.json') $SettingsDst
  $Added.Add('.claude/settings.json'); $Changed = $true
}

# --- .claude-to-claw/profile.json: created once ---
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
    # Nothing changed this run: keep the manifest (and its updated_at) as is.
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

# --- Summary ---
Write-Output "claude-to-claw workspace: $Target"
if ($Existing) { Write-Output 'Mode: upgrade of an existing workspace' } else { Write-Output 'Mode: new workspace' }
Write-Output ''
foreach ($i in $Updated) { Write-Output "[updated]  $i" }
foreach ($i in $Backed)  { Write-Output "[backed up]  $i" }
foreach ($i in $Added)   { Write-Output "[added]  $i" }
foreach ($i in $Kept)    { Write-Output "[kept]  $i" }
Write-Output ''
Write-Output "Next: cd `"$Target`"; claude   # then run /remote-control"

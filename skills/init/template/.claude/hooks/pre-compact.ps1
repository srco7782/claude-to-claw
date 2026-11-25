$ErrorActionPreference = 'SilentlyContinue'
$Utf8 = New-Object System.Text.UTF8Encoding($false)

$StdinJson = ''
if ([Console]::IsInputRedirected) {
  $StdinJson = [Console]::In.ReadToEnd()
}
if (-not $StdinJson) { $StdinJson = '{}' }

$Root = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
$BackupDir = Join-Path $Root '.claude-to-claw\backups'
$MemoryDir = Join-Path $Root 'memory'
New-Item -ItemType Directory -Force -Path $BackupDir, $MemoryDir | Out-Null

$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Today = Get-Date -Format 'yyyy-MM-dd'
$NowHm = Get-Date -Format 'HH:mm'

$BackupFile = Join-Path $BackupDir "pre-compact-$Stamp.json"
[IO.File]::WriteAllText($BackupFile, "$StdinJson`n", $Utf8)

$TodayFile = Join-Path $MemoryDir "$Today.md"
if (-not (Test-Path $TodayFile)) {
  [IO.File]::WriteAllText($TodayFile, "# $Today`n`n", $Utf8)
}
$Line = "- [$NowHm] Context 開始 compact。Hook metadata 已存到 ``.claude-to-claw/backups/pre-compact-$Stamp.json``。`n"
[IO.File]::AppendAllText($TodayFile, $Line, $Utf8)

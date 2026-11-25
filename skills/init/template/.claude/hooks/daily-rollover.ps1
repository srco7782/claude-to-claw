param(
  [ValidateSet('session-start', 'prompt')]
  [string]$Event = 'session-start'
)

$ErrorActionPreference = 'SilentlyContinue'
$Utf8 = New-Object System.Text.UTF8Encoding($false)

$StdinJson = ''
if ([Console]::IsInputRedirected) {
  $StdinJson = [Console]::In.ReadToEnd()
}

$Root = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
$StateDir = Join-Path $Root '.claude-to-claw'
$MemoryDir = Join-Path $Root 'memory'
$LastDateFile = Join-Path $StateDir 'last-date'
$PendingFile = Join-Path $StateDir 'pending-rollover'

New-Item -ItemType Directory -Force -Path $StateDir, $MemoryDir | Out-Null

$Today = Get-Date -Format 'yyyy-MM-dd'
$TodayFile = Join-Path $MemoryDir "$Today.md"
if (-not (Test-Path $TodayFile)) {
  [IO.File]::WriteAllText($TodayFile, "# $Today`n`n", $Utf8)
}

$SessionId = ''
$TranscriptPath = ''
if ($StdinJson) {
  try {
    $Parsed = $StdinJson | ConvertFrom-Json
    if ($Parsed.session_id) { $SessionId = [string]$Parsed.session_id }
    if ($Parsed.transcript_path) { $TranscriptPath = [string]$Parsed.transcript_path }
  } catch { }
}

if (-not (Test-Path $LastDateFile)) {
  [IO.File]::WriteAllText($LastDateFile, "$Today`n", $Utf8)
} else {
  $LastDate = ([IO.File]::ReadAllText($LastDateFile)).Trim()
  if ($LastDate -and $LastDate -ne $Today) {
    if (-not (Test-Path $PendingFile)) {
      $NowIso = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
      $Content = "from_date=$LastDate`nto_date=$Today`ndetected_at=$NowIso`nsession_id=$SessionId`ntranscript_path=$TranscriptPath`n"
      [IO.File]::WriteAllText($PendingFile, $Content, $Utf8)
    }
    [IO.File]::WriteAllText($LastDateFile, "$Today`n", $Utf8)
  } elseif (-not $LastDate) {
    [IO.File]::WriteAllText($LastDateFile, "$Today`n", $Utf8)
  }
}

if (-not (Test-Path $PendingFile)) { exit 0 }

$Lines = [IO.File]::ReadAllLines($PendingFile)
$FromDate = (($Lines | Where-Object { $_ -like 'from_date=*' } | Select-Object -First 1) -replace '^from_date=', '')
$ToDate = (($Lines | Where-Object { $_ -like 'to_date=*' } | Select-Object -First 1) -replace '^to_date=', '')
if (-not $FromDate) { $FromDate = 'previous day' }
if (-not $ToDate) { $ToDate = $Today }

$Msg = "[claude-to-claw Daily Rollover] Date changed ($FromDate -> $ToDate). Check memory/tasks.md: if no rollover worker is already running, dispatch a background worker subagent to compact prior day notes into memory/<date>.md, distill durable facts into MEMORY.md, archive completed rows in memory/tasks.md, and delete .claude-to-claw/pending-rollover when done."

if ($Event -eq 'prompt') {
  @{
    hookSpecificOutput = @{
      hookEventName = 'UserPromptSubmit'
      additionalContext = $Msg
    }
  } | ConvertTo-Json -Compress
} else {
  Write-Output $Msg
}

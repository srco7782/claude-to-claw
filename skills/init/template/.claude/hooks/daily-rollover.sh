#!/usr/bin/env bash
# 偵測跨 session 或正在進行的 Remote Control session 跨日變更。
set -eu

EVENT="${1:-session-start}"
STDIN_JSON=""
if [ ! -t 0 ]; then
  STDIN_JSON="$(cat || true)"
fi

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
STATE_DIR="$ROOT/.claude-to-claw"
MEMORY_DIR="$ROOT/memory"
LAST_DATE_FILE="$STATE_DIR/last-date"
PENDING_FILE="$STATE_DIR/pending-rollover"

mkdir -p "$STATE_DIR" "$MEMORY_DIR"

TODAY="$(date +%Y-%m-%d)"
TODAY_FILE="$MEMORY_DIR/$TODAY.md"
if [ ! -f "$TODAY_FILE" ]; then
  printf '# %s\n\n' "$TODAY" > "$TODAY_FILE"
fi

extract_json_field() { # key
  local key="$1"
  [ -n "$STDIN_JSON" ] || return 0
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$STDIN_JSON" | python3 -c "import json,sys
try:
  d=json.load(sys.stdin)
  v=d.get(sys.argv[1],'')
  print(v if isinstance(v,str) else '')
except Exception:
  pass" "$key" 2>/dev/null || true
  else
    printf '%s' "$STDIN_JSON" | tr '\n' ' ' | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1 || true
  fi
}

if [ ! -f "$LAST_DATE_FILE" ]; then
  printf '%s\n' "$TODAY" > "$LAST_DATE_FILE"
else
  LAST_DATE="$(tr -d ' \t\r\n' < "$LAST_DATE_FILE" 2>/dev/null || true)"
  if [ -n "$LAST_DATE" ] && [ "$LAST_DATE" != "$TODAY" ]; then
    if [ ! -f "$PENDING_FILE" ]; then
      SESSION_ID="$(extract_json_field session_id)"
      TRANSCRIPT_PATH="$(extract_json_field transcript_path)"
      NOW_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      cat > "$PENDING_FILE" <<PEND
from_date=$LAST_DATE
to_date=$TODAY
detected_at=$NOW_ISO
session_id=$SESSION_ID
transcript_path=$TRANSCRIPT_PATH
PEND
    fi
    printf '%s\n' "$TODAY" > "$LAST_DATE_FILE"
  elif [ -z "$LAST_DATE" ]; then
    printf '%s\n' "$TODAY" > "$LAST_DATE_FILE"
  fi
fi

[ -f "$PENDING_FILE" ] || exit 0

FROM_DATE="$(sed -n 's/^from_date=//p' "$PENDING_FILE" | head -n 1)"
TO_DATE="$(sed -n 's/^to_date=//p' "$PENDING_FILE" | head -n 1)"
MSG="[claude-to-claw 每日 rollover] 日期已變更（${FROM_DATE:-前一日} -> ${TO_DATE:-$TODAY}）。請先讀 memory/tasks.md。若尚無 rollover 的 worker 在執行，請啟動背景 worker Subagent，把前一日紀錄 compact 到 memory/<date>.md，把持久事實提煉到 MEMORY.md，把已完成列歸檔，完成後刪除 .claude-to-claw/pending-rollover。"

if [ "$EVENT" = "prompt" ]; then
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":sys.argv[1]}}))' "$MSG"
  else
    ESC="${MSG//\\/\\\\}"
    ESC="${ESC//\"/\\\"}"
    printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' "$ESC"
  fi
else
  printf '%s\n' "$MSG"
fi

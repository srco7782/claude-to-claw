#!/usr/bin/env bash
# Detect date changes across sessions or midnight inside an active Remote Control session.
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
MSG="[claude-to-claw Daily Rollover] Date changed (${FROM_DATE:-previous day} -> ${TO_DATE:-$TODAY}). Check memory/tasks.md: if no rollover worker is already running, dispatch a background worker subagent to compact prior day notes into memory/<date>.md, distill durable facts into MEMORY.md, archive completed rows in memory/tasks.md, and delete .claude-to-claw/pending-rollover when done."

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

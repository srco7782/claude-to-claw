#!/usr/bin/env bash
# Save PreCompact hook metadata to .claude-to-claw/backups/ and log to today's note.
set -eu

STDIN_JSON=""
if [ ! -t 0 ]; then
  STDIN_JSON="$(cat || true)"
fi

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
BACKUP_DIR="$ROOT/.claude-to-claw/backups"
MEMORY_DIR="$ROOT/memory"
mkdir -p "$BACKUP_DIR" "$MEMORY_DIR"

STAMP="$(date +%Y%m%d-%H%M%S)"
TODAY="$(date +%Y-%m-%d)"
NOW_HM="$(date +%H:%M)"

BACKUP_FILE="$BACKUP_DIR/pre-compact-$STAMP.json"
printf '%s\n' "${STDIN_JSON:-{}}" > "$BACKUP_FILE"

TODAY_FILE="$MEMORY_DIR/$TODAY.md"
if [ ! -f "$TODAY_FILE" ]; then
  printf '# %s\n\n' "$TODAY" > "$TODAY_FILE"
fi
printf -- '- [%s] Context compaction triggered; hook metadata saved to `.claude-to-claw/backups/pre-compact-%s.json`.\n' "$NOW_HM" "$STAMP" >> "$TODAY_FILE"

#!/usr/bin/env bash
# claude-to-claw workspace initializer (POSIX / macOS / Linux / WSL).
# Keep feature-equivalent with init.ps1.
#
# Rules:
# - CLAUDE.md is always refreshed from the template (backup first if it differs).
# - Every other existing file is left untouched.
# - Missing template files are added.
set -eu

TEMPLATE_VERSION="0.1.0"

# `&` in ${var//a/b} replacements must stay literal (bash >= 5.2).
shopt -u patsub_replacement 2>/dev/null || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../template"

TARGET=""
NAME=""
ROLE=""
TONE=""
POLICIES=""
LANGUAGE=""
UPGRADE=0
NON_INTERACTIVE=0

usage() {
  cat <<'EOF'
Usage: init.sh [options]

Create or safely upgrade a claude-to-claw workspace.

Options:
  --target DIR        Workspace directory (default depends on OS)
  --name NAME         Agent name (default: Claw)
  --role TEXT         Agent role / mission
  --tone TEXT         Persona / tone
  --policies TEXT     Working policies; separate items with ';' or newlines
  --language TEXT     Preferred language (default: English)
  --upgrade           Existing workspace: refresh CLAUDE.md and add missing files only
  --non-interactive   Never prompt; use flags and defaults
  --help              Show this help

Re-running is safe: only CLAUDE.md is refreshed (with a backup) and missing
template files are added. Nothing else is overwritten.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --target)   [ $# -ge 2 ] || { echo "Missing value for $1" >&2; exit 2; }; TARGET="$2"; shift 2 ;;
    --name)     [ $# -ge 2 ] || { echo "Missing value for $1" >&2; exit 2; }; NAME="$2"; shift 2 ;;
    --role)     [ $# -ge 2 ] || { echo "Missing value for $1" >&2; exit 2; }; ROLE="$2"; shift 2 ;;
    --tone)     [ $# -ge 2 ] || { echo "Missing value for $1" >&2; exit 2; }; TONE="$2"; shift 2 ;;
    --policies) [ $# -ge 2 ] || { echo "Missing value for $1" >&2; exit 2; }; POLICIES="$2"; shift 2 ;;
    --language) [ $# -ge 2 ] || { echo "Missing value for $1" >&2; exit 2; }; LANGUAGE="$2"; shift 2 ;;
    --upgrade) UPGRADE=1; shift ;;
    --non-interactive) NON_INTERACTIVE=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[ -d "$TEMPLATE_DIR" ] || { echo "Template directory not found: $TEMPLATE_DIR" >&2; exit 1; }

case "$(uname -s)" in
  Darwin) OS_NAME="macos"; DEFAULT_TARGET="$HOME/Documents/claude-claw" ;;
  Linux)  OS_NAME="linux"; DEFAULT_TARGET="$HOME/workspace/claude-claw" ;;
  *)      OS_NAME="posix"; DEFAULT_TARGET="$HOME/Documents/claude-claw" ;;
esac

trim() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }
oneline() { trim "$(printf '%s' "$1" | tr '\r\n' '  ')"; }

# Prompt only when interactive, not upgrading, and the value is still unset.
ask() { # var_name prompt default
  local current
  eval "current=\${$1}"
  [ -n "$current" ] && return 0
  if [ "$NON_INTERACTIVE" -eq 0 ] && [ "$UPGRADE" -eq 0 ] && [ -t 0 ]; then
    local reply=""
    printf '%s [%s]: ' "$2" "$3"
    IFS= read -r reply || true
    [ -n "$reply" ] && { eval "$1=\$reply"; return 0; }
  fi
  eval "$1=\$3"
}

ask TARGET "Workspace directory" "$DEFAULT_TARGET"
TARGET="${TARGET/#\~/$HOME}"
mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"

# Skip persona questions for an existing workspace.
EXISTING=0
if [ -f "$TARGET/.claude-to-claw/manifest.json" ] || [ -f "$TARGET/CLAUDE.md" ]; then EXISTING=1; fi
[ "$EXISTING" -eq 1 ] && UPGRADE=1

ask NAME "Agent name" "Claw"
ask ROLE "Agent role / mission" "Persistent assistant that dispatches every task to subagents."
ask TONE "Persona / tone" "Concise, friendly, and direct."
ask POLICIES "Working policies (separate with ';')" ""
ask LANGUAGE "Preferred language" "English"

NAME="$(oneline "$NAME")"
ROLE="$(oneline "$ROLE")"
TONE="$(oneline "$TONE")"
LANGUAGE="$(oneline "$LANGUAGE")"

# Turn free-form multi-item text into "- item" lines (split on newline, ';', '；').
to_bullets() {
  local text="$1" line
  text="${text//；/$'\n'}"
  text="${text//;/$'\n'}"
  while IFS= read -r line || [ -n "$line" ]; do
    line="$(trim "$line")"
    case "$line" in
      "- "*) line="${line#- }" ;;
      "* "*) line="${line#\* }" ;;
      "• "*) line="${line#• }" ;;
    esac
    line="$(trim "$line")"
    if [ -n "$line" ]; then printf -- '- %s\n' "$line"; fi
  done <<EOF
$text
EOF
  return 0
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\t'/ }"
  printf '%s' "$s"
}

POLICY_BULLETS="$(to_bullets "$POLICIES")"

# Render a template to a destination, filling placeholders.
render() { # src dest
  local line
  : > "$2"
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$line" = "{{USER_POLICIES}}" ]; then
      [ -n "$POLICY_BULLETS" ] && printf '%s\n' "$POLICY_BULLETS" >> "$2"
      continue
    fi
    line="${line//\{\{AGENT_NAME\}\}/$NAME}"
    line="${line//\{\{AGENT_ROLE\}\}/$ROLE}"
    line="${line//\{\{AGENT_TONE\}\}/$TONE}"
    line="${line//\{\{PREFERRED_LANGUAGE\}\}/$LANGUAGE}"
    line="${line//\{\{WORKSPACE_PATH\}\}/$TARGET}"
    line="${line//\{\{OS\}\}/$OS_NAME}"
    printf '%s\n' "$line" >> "$2"
  done < "$1"
}

UPDATED=""; BACKED=""; ADDED=""; KEPT=""
note() { # list_name text
  printf -v "$1" '%s  %s\n' "${!1}" "$2"
}
CHANGED=0

# --- CLAUDE.md: always refreshed (with backup) ---
SRC_CLAUDE="$TEMPLATE_DIR/CLAUDE.md"
DST_CLAUDE="$TARGET/CLAUDE.md"
if [ ! -e "$DST_CLAUDE" ]; then
  cp "$SRC_CLAUDE" "$DST_CLAUDE"
  note ADDED "CLAUDE.md"; CHANGED=1
elif cmp -s "$SRC_CLAUDE" "$DST_CLAUDE"; then
  note KEPT "CLAUDE.md (already up to date)"
else
  mkdir -p "$TARGET/.claude-to-claw/backups"
  BACKUP_REL=".claude-to-claw/backups/CLAUDE.md.$(date +%Y%m%d-%H%M%S).bak"
  cp "$DST_CLAUDE" "$TARGET/$BACKUP_REL"
  cp "$SRC_CLAUDE" "$DST_CLAUDE"
  note BACKED "$BACKUP_REL"
  note UPDATED "CLAUDE.md"; CHANGED=1
fi

# --- Everything else: add only when missing ---
while IFS= read -r src; do
  rel="${src#"$TEMPLATE_DIR"/}"
  [ "$rel" = "CLAUDE.md" ] && continue
  [ "$rel" = ".claude/settings.windows.json" ] && continue

  dst="$TARGET/$rel"
  if [ -e "$dst" ]; then
    note KEPT "$rel"
    continue
  fi
  mkdir -p "$(dirname "$dst")"
  case "$rel" in
    SOUL.md|POLICY.md|USER.md) render "$src" "$dst" ;;
    *) cp "$src" "$dst" ;;
  esac
  case "$rel" in .claude/hooks/*.sh) chmod +x "$dst" ;; esac
  note ADDED "$rel"; CHANGED=1
done <<EOF
$(find "$TEMPLATE_DIR" -type f | LC_ALL=C sort)
EOF

# Keep hook scripts executable (also fixes workspaces copied without the mode bit).
for hook in "$TARGET"/.claude/hooks/*.sh; do
  if [ -f "$hook" ] && [ ! -x "$hook" ]; then chmod +x "$hook"; fi
done

# --- .claude-to-claw/profile.json: created once ---
STATE="$TARGET/.claude-to-claw"
mkdir -p "$STATE"
PROFILE="$STATE/profile.json"
if [ -e "$PROFILE" ]; then
  note KEPT ".claude-to-claw/profile.json"
else
  {
    printf '{\n'
    printf '  "name": "%s",\n' "$(json_escape "$NAME")"
    printf '  "role": "%s",\n' "$(json_escape "$ROLE")"
    printf '  "tone": "%s",\n' "$(json_escape "$TONE")"
    printf '  "language": "%s",\n' "$(json_escape "$LANGUAGE")"
    printf '  "policies": ['
    first=1
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      [ "$first" -eq 1 ] || printf ','
      printf '\n    "%s"' "$(json_escape "${p#- }")"
      first=0
    done <<EOF
$POLICY_BULLETS
EOF
    [ "$first" -eq 1 ] || printf '\n  '
    printf ']\n}\n'
  } > "$PROFILE"
  note ADDED ".claude-to-claw/profile.json"; CHANGED=1
fi

# --- .claude-to-claw/manifest.json ---
MANIFEST="$STATE/manifest.json"
NOW_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
INITIALIZED_AT="$NOW_ISO"
UPDATED_AT="$NOW_ISO"
if [ -f "$MANIFEST" ]; then
  old_init="$(sed -n 's/.*"initialized_at"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$MANIFEST" | head -n 1)"
  old_upd="$(sed -n 's/.*"updated_at"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$MANIFEST" | head -n 1)"
  old_ver="$(sed -n 's/.*"template_version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$MANIFEST" | head -n 1)"
  old_os="$(sed -n 's/.*"os"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$MANIFEST" | head -n 1)"
  [ -n "$old_init" ] && INITIALIZED_AT="$old_init"
  # Nothing changed this run: keep the manifest (and its updated_at) as is.
  if [ "$CHANGED" -eq 0 ] && [ "$old_ver" = "$TEMPLATE_VERSION" ] && [ "$old_os" = "$OS_NAME" ] && [ -n "$old_upd" ]; then
    UPDATED_AT="$old_upd"
  fi
fi
NEW_MANIFEST="$(printf '{\n  "template_version": "%s",\n  "initialized_at": "%s",\n  "updated_at": "%s",\n  "os": "%s"\n}\n' \
  "$TEMPLATE_VERSION" "$INITIALIZED_AT" "$UPDATED_AT" "$OS_NAME")"
if [ -f "$MANIFEST" ] && [ "$(cat "$MANIFEST")" = "$NEW_MANIFEST" ]; then
  note KEPT ".claude-to-claw/manifest.json"
else
  EXISTED=0; [ -f "$MANIFEST" ] && EXISTED=1
  printf '%s\n' "$NEW_MANIFEST" > "$MANIFEST"
  if [ "$EXISTED" -eq 1 ]; then note UPDATED ".claude-to-claw/manifest.json"; else note ADDED ".claude-to-claw/manifest.json"; fi
fi

# --- Summary ---
echo "claude-to-claw workspace: $TARGET"
[ "$EXISTING" -eq 1 ] && echo "Mode: upgrade of an existing workspace" || echo "Mode: new workspace"
echo
print_list() { # label text
  [ -n "$2" ] || return 0
  printf '%s\n' "$2" | while IFS= read -r l; do
    if [ -n "$l" ]; then printf '[%s]%s\n' "$1" "$l"; fi
  done
}
print_list updated "$UPDATED"
print_list "backed up" "$BACKED"
print_list added "$ADDED"
print_list kept "$KEPT"
echo
echo "Next: cd \"$TARGET\" && claude   # then run /remote-control"

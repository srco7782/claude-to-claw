# claude-to-claw

Bring an OpenClaw-style persistent assistant workspace to **Claude Code + Remote Control**.

- One workspace = one persistent session.
- The main agent is an **assistant whose role is Dispatcher**.
- The Dispatcher never does task work itself; it stays responsive for chat (for example from your phone via Remote Control) and delegates every task to a subagent.
- Everything that must survive restarts lives in plain files, not in the model's context.

> 繁體中文概覽請見 [下方](#繁體中文概覽)。

## Architecture

### 1. Dispatcher

For every incoming message the Dispatcher consults `memory/tasks.md` and routes:

- Follow-up on an existing task -> `SendMessage` to that task's existing subagent, so its context stays intact.
- Brand-new task -> spawn a new resumable subagent (`worker` or `researcher`), record it in `memory/tasks.md`.
- Chitchat, status questions, clarifications -> answer directly.

### 2. Resumable subagents

- `worker` (does things) and `researcher` (reads and investigates) live in `.claude/agents/`.
- They are spawned in the background and resumed with `SendMessage`, so one task keeps one conversation.
- They write findings to the daily note and return short summaries to the Dispatcher.

### 3. OpenClaw-style file memory

| File | Purpose |
| ---- | ------- |
| `CLAUDE.md` | Dispatcher rules and routing; `@`-imports the three files below. Managed by `init`. |
| `SOUL.md` | Who the agent is: name, persona, tone, mission. |
| `POLICY.md` | How the agent must behave: guardrails, approval gates, workflow rules. |
| `MEMORY.md` | The must-remember file. Anything you say "remember ..." about goes here. |
| `USER.md` | Stable user profile and environment (OS, workspace path, language). |
| `memory/tasks.md` | Task registry: `Task ID \| Topic \| Subagent ID \| Agent Type \| Status \| Updated \| Notes`. |
| `memory/YYYY-MM-DD.md` | Daily log and daily compacted summary. |

Format rule for all memory-style files: **one rule or fact per line, bulleted** (`- ...` or `- [YYYY-MM-DD] ...`).

### 4. Hooks (daily compaction and backup)

- `SessionStart` and `UserPromptSubmit`: detect a date change and flag a pending rollover; the Dispatcher then spawns a background worker to compact the previous day, distill `MEMORY.md`, and archive finished tasks.
- `PreCompact`: saves the transcript metadata to `.claude-to-claw/backups/` and logs it in today's note.

## Install

As a Claude Code plugin:

```text
/plugin marketplace add srco7782/claude-to-claw
/plugin install claude-to-claw@claude-to-claw
```

Or load it from a local clone:

```bash
git clone https://github.com/srco7782/claude-to-claw.git
claude --plugin-dir ./claude-to-claw
```

## Create a workspace

### Interactive (recommended)

Inside Claude Code run:

```text
/claude-to-claw:init
```

Claude asks for the agent's name first, then the workspace location, then (for new workspaces) role, tone, policies, and language, and runs the init script for you.

### Direct script usage

macOS / Linux / WSL:

```bash
bash skills/init/scripts/init.sh \
  --target ~/Documents/claude-claw \
  --name Claw \
  --role "Personal assistant that dispatches every task" \
  --tone "Concise and friendly" \
  --policies "Ask before deleting anything; Keep replies short" \
  --language English \
  --non-interactive
```

Windows PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File skills\init\scripts\init.ps1 `
  -Target "$env:USERPROFILE\Documents\claude-claw" -Name Claw -NonInteractive
```

Flags: `--target`, `--name`, `--role`, `--tone`, `--policies`, `--language`, `--upgrade`, `--non-interactive`, `--help` (PowerShell: `-Target`, `-Name`, `-Role`, `-Tone`, `-Policies`, `-Language`, `-Upgrade`, `-NonInteractive`, `-Help`).

### Start the assistant

```bash
cd ~/Documents/claude-claw
claude
# inside the session:
/remote-control
```

## Safe re-run and upgrade

Re-running `init` on an existing workspace is always safe:

- `CLAUDE.md` is refreshed from the template; if it changed, the old copy is saved to `.claude-to-claw/backups/CLAUDE.md.<timestamp>.bak` first.
- Missing template files are added.
- Your files are never overwritten: `SOUL.md`, `POLICY.md`, `MEMORY.md`, `USER.md`, `memory/`, `skills/`, `.gitignore`, `.claude/` (agents, hooks, settings), and `.claude-to-claw/profile.json`.
- `.claude-to-claw/manifest.json` records `template_version`, `initialized_at`, `updated_at`, and `os`.
- The script prints a summary of `[updated]`, `[backed up]`, `[added]`, and `[kept]` items.
- Because `CLAUDE.md` is managed, keep personal rules in `SOUL.md` / `POLICY.md` / `MEMORY.md`, not in `CLAUDE.md`.

## 繁體中文概覽

**claude-to-claw** 把 OpenClaw 風格的「常駐助理工作區」帶到 Claude Code + Remote Control：

- 一個工作區 = 一個持續運作的 session。
- 主 agent 是「助理」，角色是**調度員（Dispatcher）**：自己不做任何任務，只負責聊天與分派，因此手機上透過 Remote Control 隨時都能得到快速回應。
- 每則訊息都先查 `memory/tasks.md`：
  - 屬於既有任務 -> 用 `SendMessage` 把補充內容交給原本的 subagent，上下文不中斷。
  - 全新任務 -> 建立可續用的 subagent（`worker` 或 `researcher`）並登記到 `memory/tasks.md`。
  - 閒聊、進度詢問 -> 直接回覆。
- 記憶全部寫在檔案裡，不依賴對話上下文：
  - `SOUL.md`：我是誰（名稱、個性、語氣、使命）。
  - `POLICY.md`：我該怎麼做（規則、護欄、需確認的事項）。
  - `MEMORY.md`：必須記住的事；你說「記住…」就會立刻寫入這裡。
  - `USER.md`：使用者資料與環境設定。
  - `memory/YYYY-MM-DD.md`：每日紀錄與每日壓縮摘要。
  - 格式一律「一行一條規則／事實」，使用項目符號。
- Hooks 會在跨日時觸發背景壓縮，並在 context 壓縮前備份。

安裝：

```text
/plugin marketplace add srco7782/claude-to-claw
/plugin install claude-to-claw@claude-to-claw
/claude-to-claw:init
```

重複執行 `init` 是安全的：只會更新 `CLAUDE.md`（內容有變時先備份）並補上缺少的範本檔案，絕不覆蓋你的 `SOUL.md`、`POLICY.md`、`MEMORY.md`、`USER.md`、`memory/`、`skills/`、`.claude/` 與 `.claude-to-claw/profile.json`。

## License

MIT

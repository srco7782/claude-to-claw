---
name: init
description: Set up or upgrade a claude-to-claw workspace, a persistent Dispatcher-style assistant workspace for Claude Code and Remote Control. Ask setup questions, then run the init script. Safe to re-run.
---

# claude-to-claw init

Create or upgrade a persistent assistant workspace.
Do the steps in order.
Ask one or two questions at a time. Use a conversational tone.

## Step 1: Agent name (ALWAYS FIRST for a new setup)

- Ask for the **agent's name** (for example Claw, Nova, Atlas).
- The user can upgrade an existing workspace. Then go to Step 2 and ask only for its path.

## Step 2: Target workspace directory

- Ask where the workspace must live. Offer the OS default:
  - macOS: `~/Documents/claude-claw` (or `~/Documents/<agent-name-slug>`)
  - Windows: `%USERPROFILE%\Documents\claude-claw`
  - Linux: `~/workspace/claude-claw` (or `~/Documents/claude-claw`)
- Expand `~` and environment variables to an absolute path before you use the path.

## Step 3: Check existing state

Check if the target contains `.claude-to-claw/manifest.json` or `CLAUDE.md`.

### EXISTING workspace

- Use this branch when the target has either file.
- Use this branch when the user asks to upgrade an existing workspace.
- Report the state you found.
- Report `template_version` and `updated_at` from the manifest, if present.
- Report which of `SOUL.md`, `POLICY.md`, `MEMORY.md`, and `USER.md` exist.
- Tell the user that a re-run of `init` ONLY does these actions:
  - It updates `CLAUDE.md`. It first backs up the old `CLAUDE.md` if the content differs.
  - It adds template files that are missing.
- Tell the user that `init` never changes these items:
  - `SOUL.md`
  - `POLICY.md`
  - `MEMORY.md`
  - `USER.md`
  - `memory/`
  - `skills/`
  - `.claude/`
  - `.claude-to-claw/profile.json`
- **Offer to skip the questions that the user already answered.** Then run with `--upgrade`.
- Do not ask the persona or policy questions.
- Ask them only if the user wants to change them.
- Tell the user to edit `SOUL.md` or `POLICY.md` directly.

### NEW workspace

Ask the remaining setup questions:

- Ask for the agent's role, mission, persona, and tone (maps to `SOUL.md`).
- Ask for rules, working policies, and preferred language (maps to `POLICY.md` and `USER.md`).
- Accept multiple items. The script writes each item as one bullet per line.
- Accept a skipped answer. The script applies a default.

## Step 4: Run the script

- On POSIX, macOS, Linux, and WSL, run `scripts/init.sh` (in the directory of this skill).
- On Windows, run `scripts/init.ps1` (in the directory of this skill).
- Pass the answers as flags.
- Add `--non-interactive` (`-NonInteractive` on Windows).
- Never edit `template/CLAUDE.md` by hand.
- Never copy files yourself. Always use the script.

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/init.sh" \
  --target "<workspace dir>" \
  --name "<agent name>" \
  --role "<role / mission>" \
  --tone "<persona / tone>" \
  --policies "<rule 1; rule 2; rule 3>" \
  --language "<preferred language>" \
  --non-interactive
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}/scripts/init.ps1" `
  -Target "<workspace dir>" -Name "<agent name>" -Role "<role / mission>" `
  -Tone "<persona / tone>" -Policies "<rule 1; rule 2>" -Language "<preferred language>" `
  -NonInteractive
```

- For an existing workspace, pass only `--target`, `--upgrade`, and `--non-interactive`.
- On Windows, pass `-Target ... -Upgrade -NonInteractive`.
- Separate multiple policies with `;` or newlines.

## Step 5: Check and hand over

- Read the summary of the script (`[updated]`, `[backed up]`, `[added]`, `[kept]`).
- Tell the user the summary in brief.
- Check that these files exist:
  - `<target>/CLAUDE.md`
  - `<target>/SOUL.md`
  - `<target>/POLICY.md`
  - `<target>/MEMORY.md`
  - `<target>/.claude-to-claw/manifest.json`
- Show the user how to start the assistant with Remote Control:

```bash
cd <workspace>
claude
# then, inside the session:
/remote-control
```

- Tell the user that the workspace is one persistent session.
- Tell the user that the main agent is a Dispatcher. It delegates every task to subagents.

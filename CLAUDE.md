# claude-to-claw (contributor guide)

This file guides contributors and AI agents who work ON this repository.
This file is NOT the workspace blueprint. The blueprint is `skills/init/template/CLAUDE.md`.

## TOP RULE: Public repo confidentiality

- This repository is PUBLIC.
- Never write private, proprietary, or organization-internal details.
- Forbidden: company or organization names, internal systems, internal software stacks, internal tools.
- Forbidden: people's names (employees, colleagues, customers), credentials, tokens, internal domains, internal URLs.
- Forbidden: local filesystem paths from any real machine.
- Use generic examples only.
- Use these agent names: `Claw`, `Nova`, `Atlas`.
- Use this path: `~/Documents/claude-claw`.
- Check every diff for leaks before you commit.

## Repo layout

- `.claude-plugin/plugin.json` — plugin manifest.
- `.claude-plugin/marketplace.json` — single-plugin marketplace manifest.
- `skills/init/SKILL.md` — the `/claude-to-claw:init` skill (interactive setup instructions).
- `skills/init/scripts/init.sh` — POSIX, macOS, Linux, and WSL initializer.
- `skills/init/scripts/init.ps1` — Windows PowerShell initializer.
- `skills/init/template/` — files that the scripts copy into a new workspace.
- `skills/init/template/CLAUDE.md` — the fixed workspace blueprint (Dispatcher rules, memory routing).
- `skills/init/template/.claude/` — subagents, hooks, and settings for the workspace.
- `README.md` — user documentation (English and Traditional Chinese overview).

## Conventions

- Write rule files in ASD-STE100 Simplified Technical English.
- Use active voice and imperative mood.
- Write one instruction per sentence.
- Write instructions of 20 words or fewer.
- Write descriptions of 25 words or fewer.
- Do not use semicolons in prose.
- Do not use phrasal verbs. Use one plain verb.
- Use one verb for each action in all files.
- `skills/init/template/CLAUDE.md` is the fixed workspace blueprint.
- Keep the blueprint generic and self-contained.
- Do not reference files of this repo in the blueprint.
- Do not reference private context in the blueprint.
- Keep `init.sh` and `init.ps1` feature-equivalent.
- Give both scripts the same flags, the same rules, and the same summary output.
- Make both scripts strictly idempotent.
- Never overwrite user-owned workspace files on re-run.
- On re-run, update only `CLAUDE.md`.
- On re-run, make a timestamped backup when the content differs.
- On re-run, add only the template files that are missing.
- Replace placeholders (`{{AGENT_NAME}}` and others) only when the scripts first create a file.
- Write memory-style template files as bulleted lists.
- Write one rule or fact per line.
- Hardcode `template_version` in both scripts.
- Update `template_version` together with the versions in `plugin.json` and `marketplace.json`.
- Keep `init.sh` compatible with macOS bash 3.2.
- Do not use associative arrays in `init.sh`.
- Do not use `mapfile` in `init.sh`.

## Validation

- Run `claude plugin validate .` and expect 0 errors.
- Run `bash -n` on every `.sh` file.
- Test idempotency of `init.sh` in a temp directory:
  - Run it once with `--non-interactive --target "$(mktemp -d)/ws"`.
  - Edit `SOUL.md`, `MEMORY.md`, and `memory/tasks.md`.
  - Edit the workspace `CLAUDE.md`.
  - Run it again.
  - Check that the script updates only `CLAUDE.md`.
  - Check that the script makes a backup.
  - Check that the script does not change the edited files.
  - Run it a third time.
  - Check that nothing changes.

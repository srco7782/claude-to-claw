# memory/

- This directory holds chronological notes. Use one file for each day: `memory/YYYY-MM-DD.md`.
- `memory/tasks.md` is the task registry. It has one row for each background task.

## Daily log format

- Write one item per line, bulleted.
- Add a date or time when it matters.
- Example: `- [14:05] Decided to use approach B for the export task.`
- Example: `- [14:20] Task T-003 finished. Summary: report saved to reports/q3.md.`
- Never write long prose blocks.

## Compaction flow

- A new day starts. The daily-rollover hook writes `.claude-to-claw/pending-rollover`.
- The Dispatcher starts a background `worker` to compact.
- The worker rewrites the file of each prior day as a short summary (one item per line).
- The worker moves durable facts into `MEMORY.md`.
- The worker moves completed rows out of `memory/tasks.md`.
- The worker deletes `.claude-to-claw/pending-rollover`.

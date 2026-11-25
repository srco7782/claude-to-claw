# Task Registry

- This file has one row for each background task.
- The Dispatcher reads this file for every incoming message.
- Status values: `running`, `waiting`, `done`, `failed`.
- Daily compaction archives completed rows.

| Task ID | Topic | Subagent ID | Agent Type | Status | Updated | Notes |
| ------- | ----- | ----------- | ---------- | ------ | ------- | ----- |

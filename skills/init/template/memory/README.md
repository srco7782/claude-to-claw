# memory/

- 這個目錄存放依時間排列的筆記。每天使用一個檔：`memory/YYYY-MM-DD.md`。
- `memory/tasks.md` 是任務登記表。每個背景任務一列。

## 每日紀錄格式

- 一行寫一項，使用項目符號。
- 時間重要時加上日期或時刻。
- 範例：`- [14:05] 匯出任務決定採用作法 B。`
- 範例：`- [14:20] 任務 T-003 完成。摘要：報告已存到 reports/q3.md。`
- 不要寫長段文章。

## Compact 流程

- 新的一天開始。daily-rollover hook 寫入 `.claude-to-claw/pending-rollover`。
- Dispatcher 啟動一個背景 `worker` 做 compact。
- 這個 `worker` 把每一個先前日期的檔改寫成短摘要（一行一項）。
- 這個 `worker` 把持久事實移到 `MEMORY.md`。
- 這個 `worker` 把已完成的列移出 `memory/tasks.md`。
- 這個 `worker` 刪除 `.claude-to-claw/pending-rollover`。

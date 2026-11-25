# 任務登記表

- 本檔為每個背景任務寫一列。
- Dispatcher 對每則進來的訊息都讀取本檔。
- Status 值：`running`、`waiting`、`done`、`failed`。
- 每日 compact 會歸檔已完成的列。

| Task ID | Topic | Subagent ID | Agent Type | Status | Updated | Notes |
| ------- | ----- | ----------- | ---------- | ------ | ------- | ----- |

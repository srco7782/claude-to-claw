# claude-to-claw

把 OpenClaw 風格的常駐助理 workspace 帶到 **Claude Code + Remote Control**。

- 一個 workspace 等於一個持續的 session。
- 主 agent 是**助理**，角色是 **Dispatcher**。
- Dispatcher 自己不做任務。它保持可回應，例如透過手機上的 Remote Control 聊天。它把每件任務交給 Subagent。
- 必須留下的資訊都寫在純文字檔。不要依賴模型的 context。

## 架構

### 1. Dispatcher

Dispatcher 對每則進來的訊息先讀 `memory/tasks.md`，再路由：

- 既有任務的後續：用 `SendMessage` 交給該任務既有的 Subagent。這樣可保留 context。
- 全新任務：啟動可續接的 Subagent（`worker` 或 `researcher`）。把它寫入 `memory/tasks.md`。
- 閒聊、進度詢問、澄清問題：直接回答。

### 2. 可續接的 Subagent

- `worker`（執行工作）和 `researcher`（讀取與調查）放在 `.claude/agents/`。
- 在背景啟動，並用 `SendMessage` 續接。一個任務維持一段對話。
- 它們把發現寫入每日紀錄，並向 Dispatcher 回傳簡短摘要。

### 3. OpenClaw 風格的檔案記憶

| 檔案 | 用途 |
| ---- | ---- |
| `CLAUDE.md` | Dispatcher 規則與路由。用 `@` 載入下面三個檔。由 `init` 管理。 |
| `SOUL.md` | 你是誰：名稱、個性、語氣、使命。 |
| `POLICY.md` | 你必須怎麼做：護欄、需先詢問的事項、工作流程規則。 |
| `MEMORY.md` | 必須記住的檔。你說 "remember ..." 或「記住...」的內容寫在這裡。 |
| `USER.md` | 穩定的使用者資料與環境（OS、workspace 路徑、語言）。 |
| `memory/tasks.md` | 任務登記表：`Task ID \| Topic \| Subagent ID \| Agent Type \| Status \| Updated \| Notes`。 |
| `memory/YYYY-MM-DD.md` | 每日紀錄，以及每日 compact 後的摘要。 |

記憶類檔案的格式規則：**一行一條規則或事實，使用項目符號**（`- ...` 或 `- [YYYY-MM-DD] ...`）。

### 4. Hook（每日 compact 與備份）

- `SessionStart` 與 `UserPromptSubmit`：偵測日期變更並標記 pending rollover。Dispatcher 接著啟動背景 `worker`。該 `worker` 對前一日做 compact，提煉 `MEMORY.md`，並歸檔已完成任務。
- `PreCompact`：把 transcript metadata 存到 `.claude-to-claw/backups/`，並寫入今日紀錄。

## 安裝

以 Claude Code plugin 安裝：

```text
/plugin marketplace add srco7782/claude-to-claw
/plugin install claude-to-claw@claude-to-claw
```

或從本機 clone 載入：

```bash
git clone https://github.com/srco7782/claude-to-claw.git
claude --plugin-dir ./claude-to-claw
```

## 建立 workspace

### 互動式（建議）

在 Claude Code 裡執行：

```text
/claude-to-claw:init
```

Claude 先問 agent 名稱，再問 workspace 位置。若是新 workspace，接著問角色、語氣、政策與語言，然後替你執行 init script。

### 直接執行 script

macOS / Linux / WSL：

```bash
bash skills/init/scripts/init.sh \
  --target ~/Documents/claude-claw \
  --name Claw \
  --role "把每件任務交給 Subagent 的個人助理" \
  --tone "簡潔、友善" \
  --policies "刪除任何東西前先詢問; 回覆保持簡短" \
  --language "繁體中文" \
  --non-interactive
```

Windows PowerShell：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File skills\init\scripts\init.ps1 `
  -Target "$env:USERPROFILE\Documents\claude-claw" -Name Claw -NonInteractive
```

旗標：`--target`、`--name`、`--role`、`--tone`、`--policies`、`--language`、`--upgrade`、`--non-interactive`、`--help`（PowerShell：`-Target`、`-Name`、`-Role`、`-Tone`、`-Policies`、`-Language`、`-Upgrade`、`-NonInteractive`、`-Help`）。
未指定 `--language` 時，預設為繁體中文（zh-TW）。

### 啟動助理

```bash
cd ~/Documents/claude-claw
claude
# 在 session 裡執行：
/remote-control
```

## 安全重跑與升級

在既有 workspace 重跑 `init` 一律安全。

- script 會用範本更新 `CLAUDE.md`。若內容不同，先把舊檔存到 `.claude-to-claw/backups/CLAUDE.md.<timestamp>.bak`。
- script 會補上缺少的範本檔。
- script 絕不覆寫你的檔案：`SOUL.md`、`POLICY.md`、`MEMORY.md`、`USER.md`、`memory/`、`skills/`、`.gitignore`、`.claude/`（agents、hooks、settings）與 `.claude-to-claw/profile.json`。
- `.claude-to-claw/manifest.json` 記錄 `template_version`、`initialized_at`、`updated_at` 與 `os`。
- script 會列出 `[updated]`、`[backed up]`、`[added]`、`[kept]` 項目。
- `CLAUDE.md` 由 `init` 管理。把個人規則寫在 `SOUL.md`、`POLICY.md` 或 `MEMORY.md`。不要寫在 `CLAUDE.md`。

## License

MIT

---
name: init
description: 建立或升級 claude-to-claw workspace。這是給 Claude Code 與 Remote Control 使用的常駐 Dispatcher 助理 workspace。先問設定問題，再執行 init script。可安全重跑。
---

# claude-to-claw init

建立或升級常駐助理 workspace。
依序執行下列步驟。
一次只問一或兩個問題。使用對話語氣。

## 步驟 1：Agent 名稱（新設定必須先問這一題）

- 先問 **agent 名稱**（例如 Claw、Nova、Atlas）。
- 使用者要升級既有 workspace。改走步驟 2，只問路徑。

## 步驟 2：目標 workspace 目錄

- 問 workspace 要放在哪裡。提供該 OS 的預設路徑：
  - macOS：`~/Documents/claude-claw`（或 `~/Documents/<agent-name-slug>`）
  - Windows：`%USERPROFILE%\Documents\claude-claw`
  - Linux：`~/workspace/claude-claw`（或 `~/Documents/claude-claw`）
- 使用路徑前，先把 `~` 與環境變數展開成絕對路徑。

## 步驟 3：檢查既有狀態

檢查目標是否已有 `.claude-to-claw/manifest.json` 或 `CLAUDE.md`。

### 既有 workspace

- 目標已有上述任一檔時，走這個分支。
- 使用者要求升級既有 workspace 時，也走這個分支。
- 回報你找到的狀態。
- 若 manifest 存在，回報其中的 `template_version` 與 `updated_at`。
- 回報 `SOUL.md`、`POLICY.md`、`MEMORY.md`、`USER.md` 哪些已存在。
- 告訴使用者，重跑 `init` **只會**做這些事：
  - 更新 `CLAUDE.md`。若內容不同，先備份舊的 `CLAUDE.md`。
  - 補上缺少的範本檔。
- 告訴使用者，`init` 絕不會改這些項目：
  - `SOUL.md`
  - `POLICY.md`
  - `MEMORY.md`
  - `USER.md`
  - `memory/`
  - `skills/`
  - `.claude/`
  - `.claude-to-claw/profile.json`
- **提議跳過使用者已經回答過的問題。** 然後用 `--upgrade` 執行。
- 不要再問個性或政策問題。
- 只有在使用者要改這些內容時才再問。
- 告訴使用者直接編輯 `SOUL.md` 或 `POLICY.md`。

### 新 workspace

接著問剩下的設定問題：

- 問 agent 的角色、使命、個性與語氣（對應 `SOUL.md`）。
- 問規則、工作政策與偏好語言（對應 `POLICY.md` 與 `USER.md`）。
- 接受多個項目。script 會把每一項寫成一行一個項目符號。
- 接受略過的答案。script 會套用預設值。
- 未指定偏好語言時，預設為繁體中文（zh-TW）。

## 步驟 4：執行 script

- 在 POSIX、macOS、Linux、WSL 上，執行 `scripts/init.sh`（在本 skill 的目錄裡）。
- 在 Windows 上，執行 `scripts/init.ps1`（在本 skill 的目錄裡）。
- 把答案以旗標傳入。
- 加上 `--non-interactive`（Windows 用 `-NonInteractive`）。
- 絕不可手動編輯 `template/CLAUDE.md`。
- 絕不可自己複製檔案。一律使用 script。

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

- 既有 workspace 只傳 `--target`、`--upgrade` 與 `--non-interactive`。
- 在 Windows 上傳 `-Target ... -Upgrade -NonInteractive`。
- 多條政策用 `;` 或換行分隔。

## 步驟 5：檢查並交接

- 讀取 script 的摘要（`[updated]`、`[backed up]`、`[added]`、`[kept]`）。
- 把摘要簡短告訴使用者。
- 檢查這些檔案是否存在：
  - `<target>/CLAUDE.md`
  - `<target>/SOUL.md`
  - `<target>/POLICY.md`
  - `<target>/MEMORY.md`
  - `<target>/.claude-to-claw/manifest.json`
- 告訴使用者如何用 Remote Control 啟動助理：

```bash
cd <workspace>
claude
# 然後在 session 裡執行：
/remote-control
```

- 告訴使用者：這個 workspace 是一個持續的 session。
- 告訴使用者：主 agent 是 Dispatcher。它把每件任務交給 Subagent。

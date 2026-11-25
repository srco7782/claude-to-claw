# claude-to-claw（貢獻者指南）

本檔給在這個 repository 上工作的貢獻者與 AI agent 使用。
本檔不是 workspace 藍圖。藍圖是 `skills/init/template/CLAUDE.md`。

## 最高規則：公開 repo 保密

- 這個 repository 是 PUBLIC。
- 不得寫入任何私人、專有或組織內部資訊。
- 禁止：公司或組織名稱、內部系統、內部軟體堆疊、內部工具。
- 禁止：人名（員工、同事、客戶）、憑證、token、內部網域、內部 URL。
- 禁止：任何真實機器上的本機路徑。
- 只使用通用例子。
- 使用這些 agent 名稱：`Claw`、`Nova`、`Atlas`。
- 使用這個路徑：`~/Documents/claude-claw`。
- 提交前檢查每一個 diff，確認沒有洩漏。

## Repo 結構

- `.claude-plugin/plugin.json` — plugin manifest。
- `.claude-plugin/marketplace.json` — 單一 plugin 的 marketplace manifest。
- `skills/init/SKILL.md` — `/claude-to-claw:init` skill（互動式設定步驟）。
- `skills/init/scripts/init.sh` — POSIX、macOS、Linux、WSL 的初始化 script。
- `skills/init/scripts/init.ps1` — Windows PowerShell 的初始化 script。
- `skills/init/template/` — script 複製到新 workspace 的檔案。
- `skills/init/template/CLAUDE.md` — 固定的 workspace 藍圖（Dispatcher 規則、記憶路由）。
- `skills/init/template/.claude/` — workspace 的 Subagent、hook 與 settings。
- `README.md` — 使用者文件（繁體中文）。

## 慣例

- 用 ASD-STE100 風格的繁體中文撰寫規則檔。
- 使用主動語態與祈使句。
- 一句只寫一條指令。
- 句子保持短。意思要具體、直接。
- 內文不要使用分號。
- 同一個動作全程使用同一個動詞。
- `skills/init/template/CLAUDE.md` 是固定的 workspace 藍圖。
- 保持藍圖通用且自成一套。
- 不要在藍圖裡引用本 repo 的檔案。
- 不要在藍圖裡引用任何私人 context。
- `init.sh` 與 `init.ps1` 必須功能對等。
- 兩個 script 使用相同旗標、相同規則、相同摘要輸出。
- 兩個 script 必須嚴格冪等。
- 重跑時絕不可覆寫使用者擁有的 workspace 檔案。
- 重跑時只更新 `CLAUDE.md`。
- 重跑時，若內容不同，先做帶時間戳的備份。
- 重跑時只補上缺少的範本檔。
- 只有在 script 第一次建立檔案時，才替換占位符（`{{AGENT_NAME}}` 等）。
- 記憶類範本檔使用項目符號清單。
- 一行只寫一條規則或事實。
- 在兩個 script 裡寫死 `template_version`。
- 更新 `template_version` 時，一併更新 `plugin.json` 與 `marketplace.json` 的版本。
- 保持 `init.sh` 相容 macOS bash 3.2。
- 不要在 `init.sh` 使用關聯陣列。
- 不要在 `init.sh` 使用 `mapfile`。
- 技術用語保持英文：Subagent、hook、workspace、session、compact、skill。
- 檔名、指令、程式碼、frontmatter 鍵名保持英文。

## 驗證

- 執行 `claude plugin validate .`。錯誤數必須為 0。
- 對每個 `.sh` 檔執行 `bash -n`。
- 在暫存目錄測試 `init.sh` 的冪等性：
  - 先用 `--non-interactive --target "$(mktemp -d)/ws"` 執行一次。
  - 編輯 `SOUL.md`、`MEMORY.md` 與 `memory/tasks.md`。
  - 編輯 workspace 的 `CLAUDE.md`。
  - 再執行一次。
  - 檢查 script 只更新 `CLAUDE.md`。
  - 檢查 script 有做備份。
  - 檢查 script 沒有改動已編輯的檔案。
  - 再執行第三次。
  - 檢查沒有任何改動。

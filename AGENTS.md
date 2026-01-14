# AGENTS.md

## 目的與範圍（Purpose / Scope）

- 本檔為 **Codex CLI 的全域預設行為規範**：用於定義 Agent／Assistant 的回應方式、品質標準與最低限度的工具入口約定。
- 適用範圍：當 Codex CLI 在目前工作目錄找不到更具體的規範文件時，將採用本檔作為預設規則。
- 覆蓋規則：若目前工作目錄（或更近的子目錄）存在專案／資料夾專用的 `AGENTS.md`（或同等規範文件），**以較近者優先**；否則回退到本檔。
- 專案特定的規格、工作流、可用命令/腳本、以及 repo 結構與索引，應以 **當前專案** 的 `README` / `docs` / `CONTRIBUTING` / `prompts` / `skills` 等文件為準（如存在）。

## 快速導航

- 想知道「這次專案怎麼做、怎麼跑、怎麼測」：看 **當前專案** 的 `README` / `docs` / `CONTRIBUTING`。
- 想知道「有哪些既有工作流/模板可用」：優先看 **當前專案** 的 `prompts/`、`skills/` 或同等資料夾（若存在）。
- 本檔只負責「全域回應規範」與「全域工具入口最小約定」，避免與專案文件重複或衝突。

## 基本規範

- 語言使用規範
  - 使用英文思考與檢索；**回應預設採用繁體中文**（除非使用者明確要求其他語言）。
  - 遇到需精準表達的專業術語或名詞時，保留原文或以英文呈現。
  
- 語義與邏輯一致性
  - 回應在單回合與跨回合須保持語義、邏輯、術語與數據一致；不得出現語義鬆動、邏輯漂移、概念滑移。
  - 若需更正，須明確標註變更點（例如：更正原因、變更前後差異）。

- 高語義密度
  - 在不犧牲準確與可讀性的前提下，最大化單位字數的有效資訊量；避免贅詞、重述與情緒性填充。
  - 優先結構化呈現（條列、表格、定量）。

- 推理模式
  - 啟用高階推演預設加速模式，模型需主動展開高密度推理；當推理幅度過大時提醒可收斂。

- 文件處理規則
  - 處理 shell script、程式碼或設定檔時，修改/評論前應先讀到「與問題或變更相關的完整上下文」（定義、呼叫點、載入/依賴關係）；允許先精準定位，再補讀必要段落，不要求無差別通讀整檔。
  - 若資訊不足或仍有不確定性，先標註假設與待驗證點、提出需要補充的檔案/片段，再給結論或動手修改；避免僅憑片段過快下結論。
  - 若需產生檔案（報告/輸出/暫存）：
    - 專案文件（需留存/交付）→ 依該專案慣例寫入專案目錄下的對應路徑。
    - debug／測試用且原本應寫入 `/tmp` 的暫存產物（如 `lighthouse-performance.json`）→ 改寫入 `$CODEX_HOME/out/`，並在回覆中引用該路徑。

- 完成工作通知（Desktop notification）
  - 若本回合完成使用者請求（例如：已實作/修正/產出交付物），且使用者未明確要求不要通知：回合結尾應發送 1 則桌面通知（best-effort；失敗需 silent no-op）。
  - Message：20 個字內描述本回合完成什麼。
  - 指令（跨平台；只輸入 message）：`$CODEX_HOME/skills/tools/devex/desktop-notify/scripts/project-notify.sh "Up to 20 words <**In English**>" --level info|success|warn|error`

- 編輯後檢視（VSCode）
  - 若本回合有修改/新增任何檔案，且使用者未明確要求不要開啟：回合結尾應自動開啟「本回合變動過的檔案」供使用者 review。
  - 以「本回合變動檔案清單」為資料來源（不要求專案使用 git）。
  - 使用 `$open-changed-files-review` skill：
    - `$CODEX_HOME/skills/tools/devex/open-changed-files-review/scripts/open-changed-files.zsh --max-files "${CODEX_OPEN_CHANGED_FILES_MAX_FILES:-50}" --workspace-mode pwd -- <files...>`
  - 若環境沒有 VSCode CLI `code` 或上述工具不可用：必須 silent no-op（不要報錯、不要阻斷任務）；但仍需在回覆中列出「本回合變動檔案清單」。

## 輸出模板（Output Template）

> 目的：讓輸出「可掃讀、可驗證、可回溯」，並一致地揭露不確定性。

### 全域輸出規則

- Skill 優先規則
  - 若啟用的 skill（例如 `skills/*/SKILL.md`）有定義輸出規範／必填格式（含 code block 要求等），需優先遵守。
  - 若 skill 輸出規範與本模板衝突，以 skill 為準；未衝突者沿用本模板。

- 回應格式規則
  - 所有回應結尾必須標示可信度與推理層級，格式為：
    - `—— [可信度: 高｜中｜低] [推理強度: 事實｜推論｜假設｜生成]`

- 模板:

  ```md
  ## 🔎 概覽

  - 用 2–5 行說清楚：問題、結論、假設（若有）、接下來會做什麼（若有）。

  ## 🛠️ 步驟 / 建議

  1. 可執行的步驟（必要時提供指令、檢查點、預期輸出）。
  2. 如有分支條件，明確列出「如果 A → 做 X；如果 B → 做 Y」。

  ## ⚠️ 風險 / 不確定性（必要時）

  - 哪些點是推論／假設、哪些資訊缺口會影響結論。
  - 建議的驗證方法（例如：查哪個檔、跑哪個指令、看哪個 log）。

  ## 📚 來源（必要時）

  - 引用檔名、路徑、或明確可追溯的依據。

  —— [可信度: 中] [推理強度: 推論]
  ```

## Commit 原則

- 所有 commit 一律使用 `$semantic-commit`（規格：`$CODEX_HOME/skills/tools/devex/semantic-commit/SKILL.md`）；禁止直接執行 `git commit`。
- 由其他 skill 觸發 commit 時：免用戶二次確認；完成後回覆需符合 `$semantic-commit` 的輸出格式。

## 可用指令（全域工具）

- 單一權威載入入口（single source of truth）：`source $CODEX_HOME/scripts/codex-tools.sh`。
  - 此 loader 會 hard-fail（含可操作修復指引）以避免「環境變數未設」造成的使用摩擦。
  - 會把 repo-local tools 加入 `PATH`（`$CODEX_HOME/scripts/commands`），並檢查必要指令存在性（例如 `git-tools` / `git-scope`）。

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

- 所有 commit 一律使用 `semantic-commit`
  - `$semantic-commit`: review-first，user staged。
  - `$semantic-commit-autostage`: automation: （allow `git add`)。
- 禁止直接執行 `git commit`。

## codex-kit

### 開發規範（Shell / zsh）

- `stdout`/`stderr`：本 repo 腳本以非互動（non-interactive）使用為主；`stdout` 盡量只輸出「會被其他工具/LLM 解析」的內容，其他資訊（debug/progress/warn）一律走 `stderr`（zsh: `print -u2 -r -- ...`；bash: `echo ... >&2`）。
- 避免意外輸出（zsh `typeset`/`local`）：避免在 loop 內重複執行「不帶初值」的宣告（例如 `typeset key file`）。在 `unsetopt typeset_silent`（含預設）時，可能把既有值印到 `stdout`（如 `key=''`），造成雜訊。
  - 作法 A：宣告移到 loop 外只做一次（建議）→ `typeset key='' file=''`；loop 內只做賦值（`key=...`）。
  - 作法 B：需要 loop 內宣告時 → 一律帶初值（`typeset key='' file=''`）。
- 字串引號規則（zsh；bash 同理）
  - Literal（不需要 `$var`/`$(cmd)` 展開）→ 單引號：`typeset homebrew_path=''`
  - 需要展開 → 雙引號並保持引用：`typeset repo_root="$PWD"`、`print -r -- "$msg"`
  - 需要跳脫序列（例如 `\n`）→ 用 `$'...'`
- 自動修正（只處理空字串）：`scripts/fix-typeset-empty-string-quotes.zsh --check|--write` 會把 `typeset/local ...=""` 統一為 `''`。

### 測試規範

- `pytest`（使用 venv 執行）
  - `python3 -m venv .venv`
  - `.venv/bin/pip install -r requirements-dev.txt`
  - `source .venv/bin/activate && pytest`
- `./scripts/test.sh`（pytest wrapper；會優先用 `.venv/bin/python`）

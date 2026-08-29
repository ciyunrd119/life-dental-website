# 搬遷醫療知識文章內文格式統一 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 將 67 篇搬遷文章轉成既有醫療知識版型，並讓未來匯入自動維持相同結構。

**Architecture:** 新增獨立的 HTML 正規化器，由既有 renderer 呼叫；另提供本地批次更新入口，使用同一套規則處理現有 `know_*.html`。所有轉換以 Nokogiri 進行，保留內容順序並以測試鎖定不遺失圖片、表格和連結。

**Tech Stack:** Ruby、Nokogiri、Minitest、HTML/CSS、既有靜態網站匯入工具

**Spec:** `docs/superpowers/specs/2026-08-27-migrated-knowledge-body-format-design.md`

## Global Constraints

- 保留原有醫療資訊、圖片、表格與有效連結。
- 只做中性專業語氣的輕度編修，不新增醫療主張。
- 保留現有審閱醫師姓名與個人頁面連結。
- 可重用結構變更必須同步 `element.html`。
- 不覆蓋或回復工作樹內既有的使用者修改。

---

### Task 1: 建立正文正規化器

**Files:**
- Create: `scripts/knowledge_archive/body_normalizer.rb`
- Create: `test/knowledge_archive_body_normalizer_test.rb`
- Modify: `scripts/import_knowledge_archive.rb`

**Interfaces:**
- Consumes: `String` 格式的舊版正文 HTML。
- Produces: `KnowledgeArchive::BodyNormalizer.call(html)`，回傳新版正文 HTML 字串。

- [ ] **Step 1: 寫入失敗測試**

測試一般段落、blockquote 標題、圖片、表格、重複標題、空內容與舊站控制元件清理；斷言輸出包含 `.know-article-content`、適用時包含 `.know-article-toc` 與 `.know-section`，且舊元件不存在。

- [ ] **Step 2: 執行測試並確認失敗**

Run: `ruby -Itest test/knowledge_archive_body_normalizer_test.rb`

Expected: FAIL，因 `KnowledgeArchive::BodyNormalizer` 尚未定義。

- [ ] **Step 3: 實作最小正規化器**

以 Nokogiri 解析 fragment，清理舊元件、辨識章節、產生唯一 ID、目錄、前言框、圖片 figure 與 table wrapper；無法辨識的有效節點按原順序保留。

- [ ] **Step 4: 執行測試並確認通過**

Run: `ruby -Itest test/knowledge_archive_body_normalizer_test.rb`

Expected: PASS。

### Task 2: 將正規化器接到匯入 renderer

**Files:**
- Modify: `scripts/knowledge_archive/renderer.rb`
- Modify: `test/knowledge_archive_renderer_test.rb`

**Interfaces:**
- Consumes: `KnowledgeArchive::BodyNormalizer.call(extracted.body_html)`。
- Produces: 新文章頁面中已格式化的 `.know-article-body`。

- [ ] **Step 1: 增加 renderer 失敗測試**

斷言舊 body 經 renderer 後包含目錄、文章內容與章節，且不含舊分享元件；同時斷言審閱醫師連結仍存在。

- [ ] **Step 2: 執行 renderer 測試並確認失敗**

Run: `ruby -Itest test/knowledge_archive_renderer_test.rb`

Expected: FAIL，因 renderer 仍直接插入舊 HTML。

- [ ] **Step 3: renderer 呼叫 normalizer**

讓 renderer 插入正規化結果，並在覆寫 metadata 前保留既有的 `.know-reviewer-link`。

- [ ] **Step 4: 執行 renderer 測試並確認通過**

Run: `ruby -Itest test/knowledge_archive_renderer_test.rb`

Expected: PASS。

### Task 3: 批次更新現有搬遷文章

**Files:**
- Create: `scripts/normalize_migrated_knowledge.rb`
- Create: `test/migrated_knowledge_format_test.rb`
- Modify: `knowledge/know_*.html`

**Interfaces:**
- Consumes: 每篇 `.know-article-body` 中尚未正規化的舊內容。
- Produces: 原地更新的 67 篇文章，重複執行不會再次包裝同一內容。

- [ ] **Step 1: 新增全站格式失敗測試**

逐篇檢查 `.know-article-content`、目錄對應章節 ID、舊控制元件不存在、審閱醫師連結有效，並確認圖片與表格仍存在。

- [ ] **Step 2: 執行測試並確認目前文章失敗**

Run: `ruby -Itest test/migrated_knowledge_format_test.rb`

Expected: FAIL，因文章仍為舊正文結構。

- [ ] **Step 3: 實作並執行本地批次腳本**

腳本只處理 `knowledge/know_*.html`，偵測已正規化文章後跳過，使用 `BodyNormalizer` 更新 `.know-article-body`，不碰頁面其他區塊。

Run: `ruby scripts/normalize_migrated_knowledge.rb`

- [ ] **Step 4: 執行格式測試並確認通過**

Run: `ruby -Itest test/migrated_knowledge_format_test.rb`

Expected: PASS，67 篇全部符合結構規則。

### Task 4: 同步元件庫與樣式

**Files:**
- Modify: `element.html`
- Modify: `css/style.css` only if existing components cannot safely display migrated tables or figures
- Modify: `test/knowledge_component_library_test.rb` or create it if absent

**Interfaces:**
- Consumes: 正規化器實際輸出的元件結構。
- Produces: 與實際頁面一致的預覽、複製範例及 CSS 類別速查。

- [ ] **Step 1: 新增元件同步失敗測試**

驗證 `element.html` 同時展示並記錄正規化器使用的目錄、前言、章節、圖片與響應式表格結構。

- [ ] **Step 2: 執行測試並確認失敗**

Run: `ruby -Itest test/knowledge_component_library_test.rb`

Expected: FAIL，直到元件庫完整記錄新輸出結構。

- [ ] **Step 3: 更新元件庫與必要樣式**

使實際預覽、可複製程式碼和類別速查一致；只在現有樣式不足時增加最小的 figure/table 響應式規則。

- [ ] **Step 4: 執行元件測試並確認通過**

Run: `ruby -Itest test/knowledge_component_library_test.rb`

Expected: PASS。

### Task 5: 全面驗證

**Files:**
- Verify: `knowledge/know_*.html`
- Verify: `element.html`

**Interfaces:**
- Consumes: 完成的轉換器、renderer、文章與元件庫。
- Produces: 測試與視覺驗證證據。

- [ ] **Step 1: 執行完整 Ruby 測試**

Run: `ruby -Itest -e 'Dir["test/*_test.rb"].sort.each { |file| require File.expand_path(file) }'`

Expected: 0 failures, 0 errors。

- [ ] **Step 2: 執行靜態檢查**

Run: `ruby -c scripts/knowledge_archive/body_normalizer.rb && ruby -c scripts/normalize_migrated_knowledge.rb && git diff --check`

Expected: 所有語法檢查成功，無 whitespace error。

- [ ] **Step 3: 視覺抽查**

在桌機與 351×587 手機 viewport 檢查一般文章、圖片較多文章、含表格文章及 `element.html`；確認目錄、圖片、表格可讀，且 `scrollWidth <= clientWidth`。

- [ ] **Step 4: 檢查內容保留統計**

比較轉換前後各篇圖片、表格及有效連結數；任何下降都需修正後重新驗證。

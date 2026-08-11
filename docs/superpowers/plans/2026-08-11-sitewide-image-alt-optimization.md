# Sitewide Image Alt Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 為全站公開 HTML 的內容圖片建立具體、正確且符合分店與療程語境的 Alt，同時保留裝飾圖片的 `alt=""`。

**Architecture:** 直接修改各 HTML 頁面的圖片替代文字，不新增執行期程式或相依套件。先用搜尋建立基準，再依根目錄、分店、療程案例、知識文章四個語境群組修正，最後以全站靜態稽核驗證 Alt 完整性、分店名稱與描述品質。

**Tech Stack:** 靜態 HTML、ripgrep、Git diff 檢查

## Global Constraints

- 台中頁使用「台中生活牙醫」或「台中生活牙醫診所」。
- 竹山頁使用「南投竹山生活牙醫」或「南投竹山生活牙醫診所」。
- 共用療程與案例頁自然加入「台中南投生活牙醫」及療程名稱，不重複堆砌關鍵字。
- 知識文章以圖片實際內容與文章主題為主，不機械加入地區名稱。
- 流程圖示、LINE 圖示、純裝飾圖及空燈箱節點維持 `alt=""`。
- 不修改圖片路徑、版面、互動、CSS 或其他既有文案。
- 個別知識文章 Alt 更新不改變 `know-*` 元件語法，因此不修改 `element.html` 的元件範例。

---

### Task 1: 建立全站 Alt 基準清單

**Files:**
- Inspect: all public `*.html`

**Interfaces:**
- Consumes: 已核准的 Alt 優化設計規格
- Produces: 缺少 Alt、空 Alt、泛稱 Alt、分店名稱錯置的可重複搜尋結果

- [ ] **Step 1: 確認所有圖片都有 Alt 屬性**

Run:

```bash
rg -n -U --pcre2 '<img\b(?:(?!\balt\s*=)[^>])*>' -g '*.html'
```

Expected: 沒有輸出。

- [ ] **Step 2: 列出空 Alt 並分類裝飾與內容圖片**

Run:

```bash
rg -n -U '<img\b[^>]*alt=""[^>]*>' -g '*.html'
```

Expected: 輸出主要為流程圖示、LINE 圖示、服務圖示、知識卡片封面與燈箱節點；其中知識卡片封面需於後續任務改成內容 Alt。

- [ ] **Step 3: 找出泛稱 Alt**

Run:

```bash
rg -n 'alt="[^"]*(圖片|照片|配圖|示意圖|案例)[[:space:]]*[0-9]*"' -g '*.html'
```

Expected: 列出需改寫為具體療程、設備、醫師或案例內容的 Alt。

### Task 2: 優化根目錄與分店頁面

**Files:**
- Modify: `index.html`
- Modify: `appointment.html`
- Modify: `idea.html`
- Modify: `knowledge.html`
- Modify: `news.html`
- Modify: `offday.html`
- Modify: `videos.html`
- Modify: `taichung/index.html`
- Modify: `taichung/team.html`
- Modify: `taichung/medical-equipment.html`
- Modify: `taichung/dr-chen-chia-hao.html`
- Modify: `taichung/dr-chiu-chin-chia.html`
- Modify: `taichung/dr-chu-ming-hui.html`
- Modify: `taichung/dr-chuang-li-chun.html`
- Modify: `taichung/dr-hsu-ying-chi.html`
- Modify: `taichung/dr-hsueh-ching-po.html`
- Modify: `taichung/dr-tseng-ji-san.html`
- Modify: `taichung/dr-wu-yu-ting.html`
- Modify: `taichung/dr-yang-hao-ju.html`
- Modify: `zushan/index.html`
- Modify: `zushan/team.html`
- Modify: `zushan/medical-equipment.html`
- Modify: `zushan/digital-implant-center.html`
- Modify: `zushan/team/dr-chang-shih-shu.html`
- Modify: `zushan/team/dr-chen-min-tso.html`
- Modify: `zushan/team/dr-huang-rui-bin.html`
- Modify: `zushan/team/dr-liu-chao-sheng.html`
- Modify: `zushan/team/dr-ou-yang-guo-cai.html`
- Modify: `zushan/team/dr-su-wan-ling.html`

**Interfaces:**
- Consumes: Task 1 基準結果與分店路徑
- Produces: 分店正確且能描述醫師、院所、設備與頁面主題的 Alt

- [ ] **Step 1: 修正根目錄內容圖片**

Use `apply_patch` to make each content image describe its visible subject. Examples:

```html
<img src="img/logo.png" alt="台中南投生活牙醫診所標誌" class="logo-img">
<img src="knowledge/img/20260612.png" alt="All-On-4 一日全口重建手術注意事項">
```

Keep service icons and floating LINE button images as `alt=""` when their adjacent text or outer `aria-label` already supplies the name.

- [ ] **Step 2: 修正台中頁內容圖片**

Use `apply_patch` so clinic, equipment and doctor portraits use a concise Taichung context, for example:

```html
<img src="../img/clinic/Chen-Chia-Hao.webp" alt="台中生活牙醫陳家豪醫師">
```

- [ ] **Step 3: 修正南投竹山頁內容圖片**

Use `apply_patch` so clinic, equipment and doctor portraits use a concise Nantou Zhushan context, for example:

```html
<img src="../../img/clinic/Liu-Chao-Sheng.webp" alt="南投竹山生活牙醫柳朝升醫師">
```

- [ ] **Step 4: 驗證分店關鍵字沒有交叉誤用**

Run:

```bash
rg -n '南投|竹山' taichung -g '*.html'
rg -n '台中旗艦店|台中生活牙醫' zushan -g '*.html'
```

Expected: 沒有出現在圖片 Alt 的分店錯置；頁面中合法的跨院資訊可保留。

### Task 3: 優化療程與案例頁面

**Files:**
- Modify: `services/3d-inlay.html`
- Modify: `services/all-ceramic-crown.html`
- Modify: `services/all-on-4.html`
- Modify: `services/ceramic-veneer.html`
- Modify: `services/gum-contouring.html`
- Modify: `services/implant-augmentation.html`
- Modify: `services/implant.html`
- Modify: `services/invisalign.html`
- Modify: `services/microscope-root-canal.html`
- Modify: `services/orthodontics.html`
- Modify: `services/periodontal-treatment.html`
- Modify: `services/teeth-whitening.html`
- Modify: `services/zirconia-crown.html`
- Modify: `services/zygoma-implant.html`
- Modify: `cases/aesthetic-dentistry.html`
- Modify: `cases/all-ceramic-crown.html`
- Modify: `cases/all-on-4.html`
- Modify: `cases/digital-implant.html`
- Modify: `cases/orthodontics.html`

**Interfaces:**
- Consumes: Task 1 的泛稱與空 Alt 清單
- Produces: 具體描述療程、設備、醫療團隊與治療前後用途的 Alt

- [ ] **Step 1: 優化療程主視覺與療程說明圖**

Use `apply_patch` to include treatment intent and natural brand context, for example:

```html
<img src="../img/services/allon4/whatisallon4.png" alt="台中南投生活牙醫 All-On-4 一日全口重建植體示意圖">
```

- [ ] **Step 2: 優化醫師、設備與醫療團隊圖片**

Name the doctor or equipment shown and connect it to the treatment only when the image and section support that description.

- [ ] **Step 3: 優化案例圖片與知識卡片封面**

Replace numbered placeholders with the card's actual treatment result or article topic. Example:

```html
<img src="../img/cases/allon4-1.webp" alt="All-On-4 一日全口重建改善笑容與臉部支撐案例">
```

- [ ] **Step 4: 保留裝飾圖空 Alt**

Confirm `.step-icon`, service icons and `.fl-line img` remain:

```html
<img class="step-icon" src="../img/services/all-ceramic-crown/icon_1.svg" alt="">
```

### Task 4: 優化知識文章圖片

**Files:**
- Modify: `knowledge/20200204-zirkonzahn-zirconia-crown.html`
- Modify: `knowledge/20231115-isq-implant-stability.html`
- Modify: `knowledge/20240624-microscope-root-canal-guide.html`
- Modify: `knowledge/20240912-root-coverage-surgery.html`
- Modify: `knowledge/20250827-guided-vs-freehand-implant.html`
- Modify: `knowledge/20260225-air-polishing-whitening.html`
- Modify: `knowledge/20260305-tooth-wear-restoration.html`
- Modify: `knowledge/20260525-all-ceramic-crown-aftercare.html`
- Modify: `knowledge/20260612-all-on-4-surgery-notes.html`
- Modify: `knowledge/20260626-front-tooth-gap-treatment.html`
- Modify: `knowledge/20260803-school-age-maxillary-protraction-appliance.html`
- Modify: `knowledge/20260804-dsd-digital-smile-design.html`

**Interfaces:**
- Consumes: 文章標題、段落語境與圖片實際用途
- Produces: 不堆砌地區詞、可辨識文章主題與圖像資訊的 Alt

- [ ] **Step 1: 逐文比對圖片與最近標題或圖說**

Run:

```bash
rg -n -C 3 '<img\b' knowledge -g '*.html'
```

Expected: 每張內容圖都能由標題、圖說或相鄰段落確認其主題。

- [ ] **Step 2: 修正文章內容圖 Alt**

Use `apply_patch` to name the clinical subject, comparison or procedure shown. Keep floating LINE images empty because the link has `aria-label="LINE 聯絡我們"`.

- [ ] **Step 3: 確認元件同步規則**

Run:

```bash
git diff -- knowledge element.html
```

Expected: 只有個別文章 Alt 文案變更，`know-*` 結構與 `element.html` 元件語法不變。

### Task 5: 全站驗證與品質稽核

**Files:**
- Verify: all public `*.html`

**Interfaces:**
- Consumes: Tasks 2–4 完成後的 HTML
- Produces: 可驗證的全站 Alt 完整性與品質結果

- [ ] **Step 1: 確認沒有缺少 Alt 的圖片**

Run:

```bash
rg -n -U --pcre2 '<img\b(?:(?!\balt\s*=)[^>])*>' -g '*.html'
```

Expected: 沒有輸出。

- [ ] **Step 2: 複查所有空 Alt**

Run:

```bash
rg -n -U '<img\b[^>]*alt=""[^>]*>' -g '*.html'
```

Expected: 僅剩流程圖示、服務圖示、LINE 圖示、純裝飾圖及空燈箱節點。

- [ ] **Step 3: 確認沒有泛稱 Alt**

Run:

```bash
rg -n 'alt="[^"]*(圖片|照片|配圖|示意圖|案例)[[:space:]]*[0-9]+"' -g '*.html'
```

Expected: 沒有輸出。

- [ ] **Step 4: 檢查 Alt 重複與分店名稱**

Run:

```bash
rg -n 'alt="[^"]*(台中生活牙醫|南投竹山生活牙醫|台中南投生活牙醫)[^"]*"' -g '*.html'
```

Expected: 各品牌詞出現在正確頁面語境，沒有跨店誤用或連續重複堆砌。

- [ ] **Step 5: 檢查差異格式**

Run:

```bash
git diff --check
git status --short
```

Expected: `git diff --check` 沒有輸出；狀態只包含既有未提交內容、Alt 優化與規格／計畫文件。

# Canonical 與 Sitemap 設計

日期：2026-08-31

## 目標

為新版 `https://www.gracelife.com.tw/` 建立一致的 canonical URL 系統，讓 HTML、站內連結、IIS 301 與 sitemap 使用同一組正式網址。網路約診 `/s/` 是主機上的獨立系統，不納入本次內容與 path canonicalization。

## 正式網址規則

所有 canonical 均使用 HTTPS＋www：

```text
https://www.gracelife.com.tw/
```

三個 `index.html` 頁面使用目錄網址：

| 原始檔 | Canonical URL |
| --- | --- |
| `index.html` | `https://www.gracelife.com.tw/` |
| `taichung/index.html` | `https://www.gracelife.com.tw/taichung/` |
| `zhushan/index.html` | `https://www.gracelife.com.tw/zhushan/` |

其他公開頁面保留 `.html`，canonical 由相對檔案路徑直接組成。例如：

```text
services/implant.html
→ https://www.gracelife.com.tw/services/implant.html
```

## 公開頁面範圍

本次盤點共有 127 個公開 HTML：

- 根目錄公開頁面 7 個，不含 `element.html`。
- `knowledge/` 79 個。
- `taichung/`、`zhushan/`、`services/`、`cases/` 共 41 個。

排除：

- `element.html`
- `.vercel/`
- `.worktrees/`
- `test/` 與 `test/fixtures/`
- `docs/`
- 其他非公開開發檔案

每個公開 HTML 的 `<head>` 必須有且只有一個 self-referencing：

```html
<link rel="canonical" href="https://www.gracelife.com.tw/...">
```

`element.html` 不加入 canonical，改加入：

```html
<meta name="robots" content="noindex, nofollow">
```

這次只修改牙醫知識頁面的 `<head>` SEO metadata，不修改文章區塊、`know-*` 類別、預覽、範例程式碼、CSS 或 JavaScript。`element.html` 只增加自身的 noindex 防護，不需改動元件預覽內容。

## 同步工具

新增一個 Ruby SEO 同步工具，負責：

1. 找出明確列入公開範圍的 HTML 原始檔。
2. 從檔案路徑計算唯一 canonical URL。
3. 新增或更新 `<head>` 中的 canonical；重複執行不得產生第二份標籤。
4. 更新站內連到三個 `index.html` 的連結，使其改用 `/`、`taichung/`、`zhushan/` 對應格式。
5. 為 `element.html` 同步唯一的 `noindex, nofollow` robots meta。
6. 由同一組 canonical URL 產生根目錄 `sitemap.xml`。
7. 產生或更新根目錄 `robots.txt` 的 sitemap 宣告。

同步工具不掃描 `.vercel` 輸出或測試 fixture，且在遇到無 `<head>`、重複 canonical 或不能推導的公開路徑時應中止並回報，不可靜默略過。

## Sitemap

根目錄 `sitemap.xml` 必須：

- 使用 UTF-8 與標準 sitemap XML namespace。
- 只包含 127 個公開 canonical URL。
- 使用完整 HTTPS＋www 網址。
- 不包含舊網址、301 來源、410、`element.html`、測試檔或開發文件。
- 不填無法可靠判斷的 `lastmod`。
- 每個 `<loc>` 唯一，且必須與一個 HTML canonical 完全相同。

根目錄 `robots.txt` 必須至少包含：

```text
User-agent: *
Allow: /

Sitemap: https://www.gracelife.com.tw/sitemap.xml
```

`robots.txt` 不使用 Disallow 來做 canonicalization。

## 站內連結

站內連結應直接連到 canonical，避免使用者與搜尋引擎先經過 301：

- 根首頁連結使用相對的目錄根路徑，不再使用 `index.html`。
- 台中首頁連結將 `taichung/index.html` 改為 `taichung/` 對應相對路徑。
- 竹山首頁連結將 `zhushan/index.html` 改為 `zhushan/` 對應相對路徑。

替換必須只作用於 HTML `href` 的站內首頁連結，不可修改圖片檔名、結構化資料、外部網址或包含 `index.html` 字樣但不是導覽連結的文字。

## IIS URL 行為

擴充既有 `config/iis_legacy_urls.yml`、`scripts/generate_iis_redirect_config.rb` 與產生的 `web.config`。

Canonical path redirect：

| 輸入 | HTTP 301 目的地 |
| --- | --- |
| `/index.html` | `/` |
| `/taichung` | `/taichung/` |
| `/taichung/index.html` | `/taichung/` |
| `/zhushan` | `/zhushan/` |
| `/zhushan/index.html` | `/zhushan/` |

舊網址 mapping 必須改為直接到 canonical：

| 舊網址 | 目前目的地 | 新目的地 |
| --- | --- | --- |
| `/about-tc.html` | `/taichung/index.html` | `/taichung/` |
| `/about-js.html` | `/zhushan/index.html` | `/zhushan/` |

其他舊網址 301 與 34 條 410 保持既有結果。所有 301 保留 query string。

HTTP／host normalization：

- 非 www 公開網站頁面一步 301 到 `https://www.gracelife.com.tw/...`。
- HTTP 公開網站頁面一步 301 到 `https://www.gracelife.com.tw/...`。
- 避免 HTTP → HTTPS → www 的兩段式轉址鏈。
- `/s/` 及其子路徑排除於本次新增的 path canonicalization 與 host/scheme 規則，交由網路約診系統或 IIS 既有設定處理。

規則順序：

1. `/s/` 排除或等價的不匹配條件。
2. HTTPS＋www normalization。
3. 五條 canonical path redirect。
4. 舊網址 301。
5. 舊網址 410。

部署前仍須確認正式 IIS 安裝 URL Rewrite。若主機已有未納入 Git 的 `web.config`，只合併產生的 `<rewrite>` 設定，不可覆蓋其他 IIS／ASP.NET 設定。

## 自動測試

新增或擴充 Ruby 測試，驗證：

1. 公開頁面集合固定為 127 個且沒有非公開路徑。
2. 每個公開頁面有且只有一個 canonical。
3. canonical 是 HTTPS＋www，並符合檔案路徑規則。
4. 三個 `index.html` 使用 `/`、`/taichung/`、`/zhushan/`。
5. `element.html` 有唯一 `noindex, nofollow` 且沒有 canonical。
6. `sitemap.xml` 可解析，恰有 127 個唯一 `<loc>`。
7. sitemap URL 集合與 HTML canonical 集合完全相同。
8. `robots.txt` 正確宣告 sitemap。
9. 公開 HTML 的站內首頁連結不再指向 `index.html`。
10. 同步工具重複執行不會改變檔案或增加重複 metadata。
11. IIS canonical path、host、scheme、query string 與規則順序符合設計。
12. `/s/` 不匹配本次新增的 canonicalization 規則。
13. 舊網址 100/34/2 結果保持完整，並且目的地不形成轉址鏈。
14. 所有既有 Ruby 測試、XML 解析及 `git diff --check` 通過。

測試會解析真正 HTML、XML、robots 與 `web.config`，不以純文字搜尋代替行為檢查。

## 上線驗證

在 IIS 測試站及正式切換後檢查：

- `/index.html`、`/taichung/index.html`、`/zhushan/index.html` 回傳 301。
- `/`、`/taichung/`、`/zhushan/` 回傳 200。
- HTTP／非 www 公開頁面一步到 HTTPS＋www。
- 301 `Location` 保留 query string。
- `/s/app/calendar.aspx` 仍由原網路約診系統正常回應。
- `sitemap.xml` 與 `robots.txt` 回傳 200。
- 抽查 HTML 原始碼中的 canonical，而非只看瀏覽器計算後的 DOM。

上線後在 Google Search Console 提交 `https://www.gracelife.com.tw/sitemap.xml`，並抽查首頁、兩間診所首頁、療程、案例與牙醫知識頁的 Google-selected canonical。

若 `web.config` 造成 IIS `500.19` 或影響 `/s/`，立即還原伺服器原設定；HTML canonical、sitemap 與 robots 可以保留。

## 非本次範圍

- 修改或部署 `/s/` 網路約診系統。
- 移除所有 `.html` 副檔名。
- 為圖片、PDF 或非 HTML 資源設定 HTTP canonical header。
- 新增 `hreflang`。
- 變更文章內容、牙醫知識元件語法或版面樣式。

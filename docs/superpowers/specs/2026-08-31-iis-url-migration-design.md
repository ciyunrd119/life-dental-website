# IIS 舊網址遷移設計

日期：2026-08-31

## 目標

新版靜態網站將在目前的 `https://www.gracelife.com.tw/` Microsoft IIS 10.0 主機上直接取代舊站。遷移必須讓仍有新版對應內容的舊網址以伺服器端 HTTP 301 直接前往最終頁面；已刪除且沒有相等替代內容的網址必須回傳 HTTP 410，避免無關首頁轉址與 soft 404。

## 已確認的盤點範圍

2026-08-31 從正式站站內連結唯讀爬取到 136 個可回應 HTML 網址：

- 100 個舊網址需設定 301。
- 34 個已移除網址需回傳 410。
- `/` 與 `/idea.html` 保持原網址及 200 回應。
- 沒有未分類網址。

正式站沒有可用的 `robots.txt` 或 `sitemap.xml`，因此這份盤點以首頁開始的同網域站內連結為基礎。上線後仍須以 IIS 記錄與 Google Search Console 補捉可能未被站內連結發現的歷史網址。

## 技術方案

在網站根目錄加入 `web.config`，使用 IIS URL Rewrite 模組：

- 301 使用 `<action type="Redirect" redirectType="Permanent">`。
- 410 使用 `<action type="CustomResponse" statusCode="410" statusReason="Gone">`。
- 規則只比對 URL path，不依賴網域名稱，因此 `www`／非 `www` 的主機正規化可由主機既有設定獨立處理。
- 每條 301 直接指向最終新版頁面，不可指向另一條舊網址。
- 保留原請求 query string，讓既有 UTM 等追蹤參數繼續傳遞。
- `web.config` 不包含 Vercel 設定，且不恢復 `vercel.json`。

部署前必須確認正式 IIS 主機已安裝 URL Rewrite 模組。若未安裝，不可直接上傳含 `<rewrite>` 的設定；應先由主機商安裝模組，或改由 IIS 管理員在伺服器層建立等價規則。

## 301 對照

### 診所、導覽、預約與分類頁

| 舊網址 | 新網址 |
| --- | --- |
| `/index.html` | `/` |
| `/about-tc.html` | `/taichung/index.html` |
| `/about-tc-dr.html` | `/taichung/team.html` |
| `/about-tc-eq.html` | `/taichung/medical-equipment.html` |
| `/about-js.html` | `/zhushan/index.html` |
| `/about-js-dr.html` | `/zhushan/team.html` |
| `/about-js-eq.html` | `/zhushan/medical-equipment.html` |
| `/about_news.html` | `/news.html` |
| `/about_news_offday.html` | `/offday.html` |
| `/about_news_appointment.html` | `/appointment.html` |
| `/online-reservation.html` | `/appointment.html` |
| `/contact.html` | `/appointment.html` |
| `/idea.html` | 不轉址，維持 200 |

### 療程與案例頁

| 舊網址 | 新網址 |
| --- | --- |
| `/ao4/index.html` | `/services/all-on-4.html` |
| `/bestimplant.html` | `/services/implant.html` |
| `/invisalign.html` | `/services/invisalign.html` |
| `/service00.html` | `/` |
| `/service01.html` | `/services/implant.html` |
| `/service02.html` | `/services/all-ceramic-crown.html` |
| `/service03.html` | `/services/orthodontics.html` |
| `/service04.html` | `/services/teeth-whitening.html` |
| `/service05.html` | `/services/microscope-root-canal.html` |
| `/service06.html` | `/services/periodontal-treatment.html` |
| `/case-aesthetics.html` | `/cases/aesthetic-dentistry.html` |
| `/case-ao4.html` | `/cases/all-on-4.html` |
| `/case-crown.html` | `/cases/all-ceramic-crown.html` |
| `/case-implant.html` | `/cases/digital-implant.html` |
| `/case-ortho.html` | `/cases/orthodontics.html` |

### 牙醫知識文章

`/know.html` 轉至 `/knowledge.html`。

若舊網址為 `/know_YYYYMMDD.html`，且專案內存在同名 `knowledge/know_YYYYMMDD.html`，則一對一轉至該檔案。實作必須把本次盤點到的每個來源明確寫進規則或測試資料，不可使用會把未知日期導向不存在檔案的無條件萬用規則。

以下文章因新版檔名或內容整併而使用明確例外：

| 舊網址 | 新網址 |
| --- | --- |
| `/know_20170912.html` | `/knowledge/20240912-root-coverage-surgery.html` |
| `/know_20170913.html` | `/services/teeth-whitening.html` |
| `/know_20200204.html` | `/knowledge/20200204-zirkonzahn-zirconia-crown.html` |
| `/know_20231115.html` | `/knowledge/20231115-isq-implant-stability.html` |
| `/know_20250821.html` | `/knowledge/20260626-front-tooth-gap-treatment.html` |
| `/know_20250827.html` | `/knowledge/20250827-guided-vs-freehand-implant.html` |
| `/know_20260225.html` | `/knowledge/20260225-air-polishing-whitening.html` |
| `/know_20260305.html` | `/knowledge/20260305-tooth-wear-restoration.html` |
| `/know_20260409.html` | `/knowledge/20260624-microscope-root-canal-guide.html` |

## 410 對照

下列舊消息已無同等新版內容：

- 所有本次盤點到的 `/about_news_YYYYMMDD.html`，但 `/about_news_offday.html` 與 `/about_news_appointment.html` 除外。
- `/about_news_anti.html`。

電子季刊已不在新版內容架構中，以下網址回傳 410：

- `/magazine.html`。
- `/magazine/1/index.html` 至 `/magazine/13/index.html`。

410 回應不得再導向首頁或 `/knowledge.html`。

## 測試設計

新增 Ruby 測試解析 `web.config`，以固定的正式站盤點清單驗證：

1. 100 個來源各有且只有一條 301。
2. 每個 301 目的地均對應專案中的公開 HTML 檔案；`/` 對應根目錄 `index.html`。
3. 301 目的地不可再次出現在舊網址來源集合中，避免轉址鏈與循環。
4. 34 個已移除來源各有 410 規則。
5. `/` 與 `/idea.html` 不可被轉址或標成 410。
6. 所有 136 個盤點網址都明確歸類為 301、410 或維持 200。
7. XML 可被標準解析器讀取，且 `git diff --check` 無格式錯誤。

測試只驗證專案設定與檔案存在性。真正的 IIS 行為必須在裝有 URL Rewrite 模組的測試站，以批次 HTTP 請求驗證 301、`Location`、410 與沒有轉址鏈。

## 部署與回復

1. 備份目前正式站與既有 IIS／`web.config` 設定。
2. 在測試站或暫存子站確認 URL Rewrite 模組與 `web.config` 語法。
3. 上傳新版網站及 `web.config`，但先不要刪除備份。
4. 批次檢查 136 個來源的 HTTP 狀態與 301 `Location`。
5. 確認新版頁面均為 200，沒有 301 鏈、500.19 或自訂錯誤頁把 410 改成 200。
6. 正式切換後提交新版 sitemap，並持續查看 IIS 404/410 記錄與 Google Search Console。
7. 301 至少保留一年，建議長期保留。

若部署造成 IIS 設定錯誤或大量 5xx，立即還原備份的 `web.config` 與舊站內容；不要在正式站即席修改大量規則。

## 非本次範圍

- 變更網域、DNS 或 Vercel 專案。
- 將所有 `.html` 改成無副檔名網址。
- 建立新版 canonical、sitemap 或自訂 404 頁面；這些可另案處理。
- 恢復已移除的舊消息與電子季刊內容。

# 醫師案例圖片 Alt 地區前綴 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓所有醫師個人頁的案例分享照片 Alt 包含正確地區、生活牙醫、正式醫師姓名與原案例描述。

**Architecture:** 直接修改現有靜態 HTML 的案例圖片 Alt，不新增執行期程式。依目錄決定地區前綴，並以同頁 `<h1>` 作為醫師正式姓名；驗證只鎖定 `.case-image` 內圖片，避免一般醫師照與裝飾圖被誤改。

**Tech Stack:** HTML5、Shell／ripgrep 驗證、Git

## Global Constraints

- 台中醫師頁使用 `台中生活牙醫＋醫師姓名＋原案例療程描述`。
- 南投竹山醫師頁使用 `南投生活牙醫＋醫師姓名＋原案例療程描述`。
- 只修改醫師個人頁案例分享區塊內的實質案例照片。
- 裝飾圖片保留 `alt=""`。
- 不修改圖片路徑、HTML 結構、CSS、版面或互動。
- 已含正確完整前綴的 Alt 不重複加入文字。

---

### Task 1: 補齊台中醫師案例圖片 Alt

**Files:**
- Modify: `taichung/dr-chen-chia-hao.html:204-227`
- Modify: `taichung/dr-chiu-chin-chia.html:200-223`
- Modify: `taichung/dr-chuang-li-chun.html:200-223`
- Modify: `taichung/dr-hsueh-ching-po.html:201-224`

**Interfaces:**
- Consumes: 同頁 `<h1>` 的正式姓名與現有案例 Alt 描述。
- Produces: 12 個以 `台中生活牙醫＋醫師姓名` 開頭的案例圖片 Alt。

- [ ] **Step 1: 執行修改前失敗檢查**

```bash
if rg -n 'alt="(前牙全瓷冠修復|門牙縫美學樹脂|後牙植牙搭配|馬里蘭牙橋|顯微根管治療搭配|智齒矯正取代|台中生活牙醫前牙|台中生活牙醫受損|台中生活牙醫多顆|前牙全瓷冠與|多顆受損牙|植牙搭配全瓷冠)' \
  taichung/dr-chen-chia-hao.html \
  taichung/dr-chiu-chin-chia.html \
  taichung/dr-chuang-li-chun.html \
  taichung/dr-hsueh-ching-po.html; then
  echo 'FAIL：台中案例 Alt 尚未包含完整地區、品牌與醫師姓名'
  exit 1
fi
```

Expected: FAIL，列出 12 個尚未完整的案例 Alt。

- [ ] **Step 2: 以最小變更補上台中前綴與姓名**

逐一將 12 個 Alt 改為：

```text
台中生活牙醫陳嘉豪醫師前牙全瓷冠修復治療前後案例
台中生活牙醫陳嘉豪醫師門牙縫美學樹脂補綴治療前後案例
台中生活牙醫陳嘉豪醫師後牙植牙搭配全鋯冠治療前後案例
台中生活牙醫邱勁嘉醫師馬里蘭牙橋搭配陶瓷貼片重建前牙區治療前後案例
台中生活牙醫邱勁嘉醫師顯微根管治療搭配全鋯冠保留牙齒治療前後案例
台中生活牙醫邱勁嘉醫師智齒矯正取代第二大臼齒與裂齒植牙重建治療前後案例
台中生活牙醫莊禮駿醫師前牙全瓷冠美學修復案例
台中生活牙醫莊禮駿醫師受損門牙全瓷冠重建案例
台中生活牙醫莊禮駿醫師多顆前牙全瓷冠修復案例
台中生活牙醫薛青坡醫師前牙全瓷冠與陶瓷貼片修復治療前後案例
台中生活牙醫薛青坡醫師多顆受損牙全瓷冠重建治療前後案例
台中生活牙醫薛青坡醫師植牙搭配全瓷冠重建缺牙治療前後案例
```

- [ ] **Step 3: 驗證台中案例 Alt**

```bash
taichung_updated_count=0
for doctor_file in \
  taichung/dr-chen-chia-hao.html \
  taichung/dr-chiu-chin-chia.html \
  taichung/dr-chuang-li-chun.html \
  taichung/dr-hsueh-ching-po.html; do
  doctor_name=$(rg -o '<h1>[^<]+</h1>' "$doctor_file" | sed -E 's#</?h1>##g')
  page_count=$(rg -U -o "<div class=\"case-image\">\\s*<img[^>]+alt=\"台中生活牙醫${doctor_name}醫師" "$doctor_file" | rg -c '^<div class="case-image">')
  taichung_updated_count=$((taichung_updated_count + page_count))
done
test "$taichung_updated_count" = "12"
```

Expected: exit 0，`taichung_updated_count` 為 12。

### Task 2: 補齊南投醫師案例圖片 Alt

**Files:**
- Modify: `zushan/team/dr-chang-shih-shu.html:203-226`
- Modify: `zushan/team/dr-chen-min-tso.html:198-221`
- Modify: `zushan/team/dr-liu-chao-sheng.html:205-228`

**Interfaces:**
- Consumes: 同頁 `<h1>` 的正式姓名與現有案例 Alt 描述。
- Produces: 9 個以 `南投生活牙醫＋醫師姓名` 開頭的案例圖片 Alt。

- [ ] **Step 1: 執行修改前失敗檢查**

```bash
if rg -n 'alt="(上顎全口重建|多顆缺牙全口重建|近全口無牙|齒列擁擠|前牙排列|開咬)' \
  zushan/team/dr-chang-shih-shu.html \
  zushan/team/dr-chen-min-tso.html \
  zushan/team/dr-liu-chao-sheng.html; then
  echo 'FAIL：南投案例 Alt 尚未包含完整地區、品牌與醫師姓名'
  exit 1
fi
```

Expected: FAIL，列出 9 個尚未完整的案例 Alt。

- [ ] **Step 2: 以最小變更補上南投前綴與姓名**

逐一將案例 Alt 加上：

```text
南投生活牙醫張始樹醫師
南投生活牙醫陳旻佐醫師
南投生活牙醫柳朝升醫師
```

後方完整保留各圖片現有的案例療程描述。

- [ ] **Step 3: 驗證南投案例 Alt**

```bash
rg -n 'alt="南投生活牙醫(張始樹|陳旻佐|柳朝升)醫師' \
  zushan/team/dr-chang-shih-shu.html \
  zushan/team/dr-chen-min-tso.html \
  zushan/team/dr-liu-chao-sheng.html
```

Expected: 顯示 9 行。

### Task 3: 全站範圍與格式驗證

**Files:**
- Verify: `taichung/dr-*.html`
- Verify: `zushan/team/dr-*.html`

**Interfaces:**
- Consumes: Task 1 與 Task 2 修改後的 21 個案例 Alt，以及原本已正確的 12 個案例 Alt。
- Produces: 所有 33 張案例照片皆符合地區與品牌規則的驗證結果。

- [ ] **Step 1: 確認所有案例圖片都有正確地區前綴**

```bash
set -eu
case_total=0
case_good=0
for doctor_file in taichung/dr-*.html zushan/team/dr-*.html; do
  if rg -q '<div class="case-image">' "$doctor_file"; then
    doctor_name=$(rg -o '<h1>[^<]+</h1>' "$doctor_file" | sed -E 's#</?h1>##g')
    case "$doctor_file" in
      taichung/*) location_prefix='台中生活牙醫' ;;
      zushan/*) location_prefix='南投生活牙醫' ;;
    esac
    page_total=$(rg -U -o '<div class="case-image">\s*<img[^>]+alt="' "$doctor_file" | rg -c '^<div class="case-image">')
    page_good=$(rg -U -o "<div class=\"case-image\">\\s*<img[^>]+alt=\"${location_prefix}${doctor_name}醫師" "$doctor_file" | rg -c '^<div class="case-image">')
    test "$page_total" = "$page_good"
    case_total=$((case_total + page_total))
    case_good=$((case_good + page_good))
  fi
done
test "$case_total" = "33"
test "$case_good" = "33"
echo "PASS：${case_good} 張案例照片皆含正確地區、品牌與醫師姓名"
```

Expected: PASS，台中 24 張、南投 9 張。

- [ ] **Step 2: 確認裝飾圖片仍保留空 Alt**

```bash
rg -n '<img[^>]+alt=""' taichung/dr-*.html zushan/team/dr-*.html
```

Expected: 各醫師頁的 LINE 等裝飾圖片仍顯示 `alt=""`。

- [ ] **Step 3: 檢查 HTML 差異格式**

```bash
git diff --check -- taichung/dr-*.html zushan/team/dr-*.html
```

Expected: exit 0，沒有輸出。

- [ ] **Step 4: 檢查差異範圍**

```bash
git diff --word-diff=plain -- taichung/dr-*.html zushan/team/dr-*.html
```

Expected: 只顯示 21 個案例圖片 Alt 新增地區、生活牙醫與醫師姓名；圖片路徑、結構與裝飾 Alt 沒有變更。

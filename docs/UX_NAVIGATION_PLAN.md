# UX / Navigation Review — Implementation Plan

Trạng thái: PLAN — chờ ChatGPT review trước khi code.
Baseline: `main` sau Categories V1 merge — commit `d4bd6146720ba5ff56d83626326d953b43163123`.
Branch: `feature/ux-navigation`.

## 1. Mục tiêu & phạm vi khóa

- Biến Dashboard từ "trang dài nối tiếp" thành 4 tầng có navigation nội bộ, dễ dùng hơn.
- **KHÔNG** thay đổi DB / schema / RLS / constraint / trigger / RPC.
- **KHÔNG** thay đổi business logic: Accounts, Transactions, Transfer, Filter, Net Worth, Statistics, Categories giữ nguyên 100%.
- **KHÔNG** tách thành nhiều page, không router, không framework.
- **KHÔNG** làm UX-P2 (modal thay prompt, toast, dark mode...) trong vòng này.
- Chỉ chạm: HTML + CSS + JS frontend trong `dashboard.html`.

## 2. Layout HIỆN TẠI (trước) — dashboard.html @ d4bd6146

File: 3.332 dòng, 2 script block, breakpoint 800px / 550px.

```
<header class="header">                      (line ~82)
  .logo "Nguyên HOÀNG" | ← Về website | Đăng xuất (#logoutBtn)
<main class="container">
  #loading
  #dashboard
    .welcome > h1 "Xin chào, bạn 👋"          (line 93)
    .cards: Tổng thu nhập / Tổng chi tiêu / Chênh lệch / Số giao dịch   (97–101)
    .card > h2 "💰 Tài sản & Nợ"              (104)  ← KHÔNG có wrapper .section
      .cards: Tổng tài sản / Tổng nợ / Tài sản ròng (105–107)
    .section > h2 "📊 Thống kê"               (111)
      #statsTabs, 4 cards (#statsIncome...), #statsChart, h3 "Theo danh mục" + #categoryStats
    .section > h2 "🏦 Tài khoản của tôi"      (134)
      button "+ Thêm tài khoản" (toggle) → #accountForm (display:none) → #accountList
    .section > h2 "📋 Danh mục tài sản & nợ"  (168)
      #nwAddBtn (toggle) → #nwForm (display:none) → #nwAssetList / #nwLiabilityList
    .section > h2 "Thêm giao dịch"            (219)  ← FORM LUÔN HIỆN
      #transactionForm (luôn visible): transactionType/date/from/to/category/amount/note
    .section > h2 "🗂️ Danh mục thu / chi"    (267)
      #catAddBtn (toggle) → #catForm (display:none) → #catExpenseList / #catIncomeList
    .section > h2 "Giao dịch 🔍 Đang lọc"     (301)
      .filter-bar (type/account/date/search) → #transactionList → #showMoreBtn
```

Pattern toggle đã có sẵn và sẽ tái dùng: button `onclick="...style.display='block'"` + form `display:none` (accountForm line 137–138, nwForm 169–170, catForm 268–269).

## 3. Layout ĐỀ XUẤT (sau) — 4 tầng

```
<header class="header">
  .logo "Nguyên HOÀNG"
  <nav class="dash-nav">          ← MỚI (UX-P0)
    Tổng quan → #overview | Giao dịch → #action | Tài khoản → #accounts
    | Tài sản & Nợ → #networth | Danh mục → #categories
  .nav-right: ← Về website | Đăng xuất   (giữ nguyên)
<main class="container">
  #loading
  #dashboard

  <section id="overview">                    ← TẦNG 1 — OVERVIEW (MỚI: wrapper, không đổi nội dung/logic)
    .welcome > h1 "Xin chào, bạn 👋"
    .cards: Tổng thu nhập / Tổng chi tiêu / Chênh lệch / Số giao dịch
    h2 "💰 Tài sản & Nợ" + 3 cards (Tổng tài sản / Tổng nợ / Tài sản ròng)
    h2 "📊 Thống kê" + #statsTabs + 4 cards + #statsChart + "Theo danh mục" + #categoryStats

  <section id="action">                       ← TẦNG 2 — ACTION (MỚI: thu gọn form)
    h2 "⚡ Giao dịch"
    button "+ Thêm giao dịch" (toggle, pattern như accountForm)
    #transactionForm style="display:none;"  ← đổi từ luôn-hiện sang ẩn (UX-P1)

  <section id="manage">                       ← TẦNG 3 — MANAGEMENT (MỚI: wrapper nhóm)
    h2 "🧭 Quản lý tài chính"
    <section id="accounts"> h2 "🏦 Tài khoản của tôi" + (toggle + #accountForm + #accountList như cũ) </section>
    <section id="networth"> h2 "💰 Tài sản & Nợ" + (toggle + #nwForm + #nwAssetList/#nwLiabilityList như cũ) </section>
    (ghi chú visual: Tài khoản = dòng tiền, Tài sản & Nợ = tài sản ròng — text hint nhỏ, không gộp dữ liệu)

  <section id="categories">                   ← TẦNG 4 — DATA (giữ nguyên nội dung, chỉ thêm id)
    h2 "🗂️ Danh mục thu / chi" + (toggle + #catForm + lists như cũ)

  <section id="transactions">                  ← TẦNG 4 — DATA (giữ nguyên nội dung, chỉ thêm id)
    h2 "Giao dịch 🔍 Đang lọc" + (.filter-bar + #transactionList + #showMoreBtn như cũ)
```

Thứ tự DOM sau: overview → action → manage(accounts, networth) → categories → transactions.
So với trước: "Thêm giao dịch" được đưa lên ngay sau Overview; "📋 Danh mục tài sản & nợ" nhập vào #networth trong #manage.

## 4. Chi tiết thay đổi

### UX-P0 — Navigation nội bộ + visual hierarchy
1. Thêm `<nav class="dash-nav">` trong header, 5 link anchor: `#overview #action #accounts #networth #categories`.
   - Desktop: hàng ngang trong header.
   - Mobile (≤800px / ≤550px): `overflow-x:auto; white-space:nowrap` — horizontal scroll, không hamburger.
2. Thêm wrapper `<section id="overview">`, `<section id="action">`, `<section id="manage">` (chứa `#accounts`, `#networth`), và id `#categories`, `#transactions` cho 2 section cuối.
   - Chỉ thêm wrapper/id, không đổi id hiện có của bất kỳ element nào JS đang dùng.
3. CSS: `html{scroll-behavior:smooth}` + `section[id]{scroll-margin-top:12px}` (header hiện không sticky nên không cần offset lớn).
4. Nhãn tầng (OVERVIEW / THAO TÁC / QUẢN LÝ / DỮ LIỆU) thể hiện bằng heading phụ nhỏ trong UI, không đổi logic.

### UX-P1 — Thu gọn form + tách visual + chuẩn hóa button
5. `#transactionForm`: thêm `style="display:none;"`, thêm button toggle "+ Thêm giao dịch" phía trên (pattern y hệt accountForm line 137–138).
   - Lưu ý kỹ thuật: khi edit transaction từ list, JS hiện tại có scroll tới form — phải đảm bảo form được `display:block` trước khi scroll (sẽ kiểm tra hàm edit hiện tại, giữ hành vi).
6. Trong `#manage`: thêm text hint phân biệt "Tài khoản → dòng tiền" vs "Tài sản & Nợ → tài sản ròng". Không gộp dữ liệu, không đổi logic.
7. Chuẩn hóa button: thêm class `.add-btn.secondary` (thay cho inline `style="background:#64748b..."` ở nwCancelBtn/catCancelBtn); bỏ inline `style="margin-top:0"` dư thừa. Không đổi màu sắc/ngôn ngữ button.

### Không làm (giữ nguyên)
- Mọi id JS đang dùng: totalIncome/totalExpense/totalBalance/transactionCount, nw*, stats*, accountForm/accountList, nwForm/nwAssetList/nwLiabilityList, transactionForm (+ tất cả field), catForm/catExpenseList/catIncomeList, filter controls, transactionList, showMoreBtn, logoutBtn.
- Logic tính toán, RPC transfer, filter, statistics, categories seed/cache.
- `index.html` không đổi.

## 5. Files thay đổi

- `dashboard.html` — duy nhất. (HTML structure + CSS + JS toggle nhỏ.)
- `index.html` — không đổi.
- Supabase / DB / migrations — không đổi.

## 6. Rủi ro & giảm thiểu

| Rủi ro | Giảm thiểu |
|---|---|
| Reorder DOM làm hỏng JS | JS dùng `getElementById` cho mọi element quan trọng; không có logic phụ thuộc thứ tự DOM (đã kiểm tra: chỉ 1 `scrollIntoView` trong `nwShowForm`, vẫn đúng sau reorder) |
| Form giao dịch bị ẩn khi edit từ list | Kiểm tra và giữ: edit phải mở form trước khi scroll/focus |
| Anchor bị header che | Header không sticky; thêm `scroll-margin-top` dự phòng |
| Regression filter/statistics/categories | Không đổi id, không đổi logic — QA full matrix các module |

## 7. QA sau implementation (Milu tự QA, không kéo anh nghiệm thu vụn)

- Navigation: 5 link scroll đúng section trên desktop + mobile; mobile nav scroll ngang không vỡ layout.
- Thêm giao dịch: bấm "+ Thêm giao dịch" mở form; submit expense/income/transfer đúng logic cũ; edit từ list vẫn mở form và scroll đúng.
- Regression: Accounts CRUD, Transfer, Filter (23 cases), Net Worth, Statistics, Categories (T3 validation 2 flows) — spot-check các case đã PASS trước đây.
- `node --check` cho mọi inline script sau sửa.
- Không có thay đổi DB: verify không có migration mới, không đụng Supabase.

## 8. Câu hỏi cho ChatGPT

1. Nav "Giao dịch" → scroll tới `#action` (quick-add) như đề xuất, hay tới `#transactions` (lịch sử)? Em đề xuất `#action` vì khớp user journey "vừa chi → nhập vào đâu".
2. Có cần sticky header không, hay giữ header tĩnh như hiện tại? Em đề xuất giữ tĩnh ở V1.
3. Nhãn tầng (OVERVIEW/THAO TÁC/...) nên là heading nhỏ trong UI hay chỉ là comment trong code? Em đề xuất heading nhỏ để người dùng cũng thấy cấu trúc.

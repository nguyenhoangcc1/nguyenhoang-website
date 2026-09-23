# DASHBOARD_PLAN.md

## 1. Mục tiêu

Xây dựng **Dashboard & Statistics v1** cho `dashboard.html`, cung cấp màn hình tổng quan và thống kê tài chính theo **Ngày / Tháng / Năm**.

Feature v1 chỉ sử dụng dữ liệu và schema hiện có.

**Không thay đổi DB, schema, RLS, policy, trigger hoặc RPC.**

---

## 2. Phạm vi v1

### Có trong v1

- Tổng tài sản hiện tại
- Tổng nợ hiện tại
- Tài sản ròng hiện tại
- Tổng thu theo kỳ
- Tổng chi theo kỳ
- Chênh lệch theo kỳ
- Số giao dịch theo kỳ
- Biểu đồ thu/chi
- Chế độ Ngày / Tháng / Năm
- Bộ chọn kỳ tương ứng

### Chưa có trong v1

Không implement:

- Chi tiêu theo danh mục
- Thu nhập theo danh mục
- Category analytics
- Tài sản ròng theo thời gian
- Biểu đồ lịch sử Net Worth
- Snapshot Net Worth theo ngày/tháng/năm
- Investment analytics
- Dữ liệu giá/NAV thị trường
- Bất kỳ thay đổi DB nào

Nếu mockup có khu vực Category Analytics thì chỉ được ghi **Placeholder — Feature sau**, không có logic và không hiển thị dữ liệu giả.

---

## 3. Nguồn dữ liệu

Sử dụng dữ liệu hiện có từ:

- `accounts`
- `transactions`
- `net_worth_items`

Không tạo bảng mới.

### Net Worth hiện tại

Tái sử dụng đúng logic Assets & Liabilities v1:

- Tổng tài sản = tổng giá trị asset hiện tại
- Tổng nợ = tổng giá trị liability hiện tại
- Tài sản ròng = Tổng tài sản - Tổng nợ

Đây là **snapshot hiện tại**, không phải lịch sử.

Không được suy diễn Net Worth lịch sử từ transactions.

---

## 4. Quy tắc Statistics

### 4.1 Toàn bộ transactions

Stats phải tính trên **toàn bộ transactions phù hợp với kỳ và filter**, không phải 20 dòng đang hiển thị do pagination.

Ví dụ có 100 transaction nhưng UI chỉ hiện 20: Statistics vẫn phải tính đủ 100 transaction phù hợp.

Pagination chỉ ảnh hưởng transaction list, không ảnh hưởng dataset Statistics.

### 4.2 Income / Expense / Difference

Chỉ `income` và `expense` đóng góp vào:

- Tổng thu
- Tổng chi
- Chênh lệch

Công thức:

- Tổng thu = sum income
- Tổng chi = sum expense
- Chênh lệch = Tổng thu - Tổng chi

### 4.3 Transfer

Giữ nguyên business rule đã khóa:

- Transfer = **1 transaction**
- Không tính vào Tổng thu
- Không tính vào Tổng chi
- Không tính vào Chênh lệch
- Vẫn tính vào Số giao dịch

---

## 5. Timezone

Toàn bộ ranh giới ngày/tháng/năm dùng **UTC+07:00 — Việt Nam**.

Không được ngầm dùng timezone của browser nếu browser có timezone khác.

### Theo ngày

Từ `00:00:00 +07:00` đến trước `00:00:00 +07:00` của ngày kế tiếp.

### Theo tháng

Từ `00:00:00 +07:00` ngày đầu tháng đến trước `00:00:00 +07:00` ngày đầu tháng kế tiếp.

### Theo năm

Từ `00:00:00 +07:00` ngày 01/01 đến trước `00:00:00 +07:00` ngày 01/01 năm kế tiếp.

Implementation phải nhất quán giữa filter, Statistics và biểu đồ.

---

## 6. Chế độ xem

### 6.1 Theo ngày

Có date control.

Hiển thị:

- Tổng thu trong ngày
- Tổng chi trong ngày
- Chênh lệch trong ngày
- Số giao dịch trong ngày
- Biểu đồ thu/chi của ngày

### 6.2 Theo tháng

Có month/year selector.

Hiển thị:

- Tổng thu tháng
- Tổng chi tháng
- Chênh lệch tháng
- Số giao dịch tháng
- Biểu đồ thu/chi theo từng ngày trong tháng

### 6.3 Theo năm

Có year selector.

Hiển thị:

- Tổng thu năm
- Tổng chi năm
- Chênh lệch năm
- Số giao dịch năm
- Biểu đồ thu/chi theo từng tháng trong năm

---

## 7. Biểu đồ v1

Không sử dụng thư viện biểu đồ bên ngoài.

Không thêm CDN/dependency.

Tự vẽ bằng:

- SVG
- CSS
- JavaScript hiện có

### Theo ngày

Biểu đồ đơn giản cho Thu và Chi của ngày.

### Theo tháng

Biểu đồ theo từng ngày trong tháng:

- Thu
- Chi

### Theo năm

Biểu đồ theo từng tháng:

- Thu
- Chi

Biểu đồ phải có nhãn đủ rõ, responsive và không làm thay đổi dữ liệu khi giảm mật độ nhãn trên mobile.

---

## 8. Quan hệ với Transaction Filter

### 8.1 Single date-range state — LOCKED

**Chỉ tồn tại một date-range state duy nhất.**

- Bộ chọn **Ngày / Tháng / Năm** của Dashboard ghi vào state này dưới dạng custom range tương ứng.
- Các control ngày của Transaction Filter cũng ghi vào **cùng date-range state**.
- Statistics luôn đọc chiều thời gian từ state duy nhất này.
- Transaction list cũng sử dụng chính date-range state này.
- “Date” được tôn trọng trong Transaction Filter chính là range đã đồng bộ này.
- **Không tồn tại hai nguồn date độc lập.**
- Không được lấy Dashboard period rồi AND thêm một date filter khác.

Luồng dữ liệu chính thức:

`Dashboard period / Transaction date control → single date-range state → full filtered dataset → Statistics`

và:

`Dashboard period / Transaction date control → single date-range state → full filtered dataset → pagination → Transaction list`

### 8.2 Các chiều filter khác

Ngoài date-range state duy nhất, Statistics phải tôn trọng:

- Type
- Account
- Search

Transfer account filter vẫn match **source hoặc destination**.

Transfer vẫn:

- Không đóng góp vào Tổng thu
- Không đóng góp vào Tổng chi
- Không đóng góp vào Chênh lệch
- Đóng góp 1 vào Số giao dịch

### 8.3 Đồng bộ hai chiều

Khi người dùng đổi Dashboard period:

- date-range state cập nhật
- Transaction Filter date UI phải phản ánh range tương ứng
- Transaction list cập nhật
- Statistics cập nhật

Khi người dùng đổi date control của Transaction Filter:

- cùng date-range state được cập nhật
- Statistics đọc range mới
- Transaction list đọc range mới
- Dashboard period UI phải phản ánh trạng thái phù hợp nếu range tương ứng với một kỳ Ngày/Tháng/Năm; nếu là custom range không ánh xạ chính xác, UI phải thể hiện rõ trạng thái custom thay vì giữ một period gây hiểu nhầm.

Muse không được tạo thêm date state thứ hai để xử lý riêng Statistics.

### 8.4 Pagination

Statistics **không phụ thuộc pagination**.

`Hiển thị thêm` chỉ thay đổi số transaction được render trong list và không được thay đổi:

- Tổng thu
- Tổng chi
- Chênh lệch
- Số giao dịch
- dữ liệu biểu đồ

### 8.5 Clear filter

Khi clear filter:

- Type / Account / Search trở về trạng thái mặc định
- date-range state trở về kỳ mặc định của Dashboard
- Transaction list cập nhật
- Statistics cập nhật
- Pagination tiếp tục tuân theo behavior đã khóa của Transaction Filter


## 9. Vị trí UI

Đề xuất trong `dashboard.html`:

Giữ nguyên thứ tự layout hiện tại của dashboard để giảm phạm vi thay đổi.

Cụ thể:

1. Header / Dashboard title
2. **Current Financial Overview / Net Worth cards hiện tại**
3. **Statistics** — section mới chèn ngay sau Net Worth cards
   - Ngày / Tháng / Năm
   - Bộ chọn kỳ
   - Tổng thu
   - Tổng chi
   - Chênh lệch
   - Số giao dịch
   - Biểu đồ
4. Accounts — giữ vị trí hiện tại
5. Assets & Liabilities — giữ vị trí hiện tại
6. Transaction section — giữ vị trí hiện tại
   - Filter
   - Transaction list
   - Pagination / Hiển thị thêm

Không di chuyển Accounts hoặc Assets & Liabilities chỉ để phục vụ Dashboard v1.

Mục tiêu là thêm Statistics với thay đổi layout tối thiểu và không gây regression UX cho các section đã hoàn thành.

---

## 10. Mobile

Trên màn hình nhỏ:

- Summary cards xếp chồng theo chiều dọc
- Không overflow ngang
- Bộ chọn Ngày/Tháng/Năm có thể xuống dòng
- Biểu đồ co giãn theo container
- Không tạo horizontal scroll không cần thiết

Desktop có thể dùng layout ngang cho summary cards.

---

## 11. Không thay đổi business rules hiện tại

Không được làm thay đổi:

- Account balance logic
- Income/Expense logic
- Transfer logic
- Transfer deletion rules
- Negative balance rules
- Assets & Liabilities logic
- Current Net Worth logic
- Transaction Filter behavior
- Pagination behavior

Bug của feature trước, nếu phát hiện, phải báo riêng; không sửa âm thầm trong feature này.

---

## 12. DB / Backend

**DB LOCKED.**

Không được:

- CREATE TABLE
- ALTER TABLE
- CREATE INDEX
- ALTER RLS
- CREATE POLICY
- CREATE RPC
- ALTER RPC
- thêm migration

Dashboard v1 chỉ sử dụng schema/API hiện có.

---

## 13. Performance / Data loading

### 13.1 Toàn bộ transactions

Dashboard phải tính Statistics trên toàn bộ transactions phù hợp, không bị giới hạn bởi pagination của UI.

`loadTransactions()` hiện không được giả định rằng `.select("*")` luôn trả về toàn bộ dữ liệu. Do PostgREST có giới hạn số rows trả về trong một request, implementation phải đảm bảo lấy đủ toàn bộ transactions.

Cho phép frontend dùng vòng lặp `.range()` để fetch các batch liên tiếp cho đến khi hết dữ liệu.

Yêu cầu:

- Không dùng một request mặc định rồi giả định dữ liệu >1000 rows đã được lấy hết.
- Không được cắt dataset chỉ để làm Statistics.
- Pagination “Hiển thị thêm” của UI vẫn độc lập với việc fetch toàn bộ dataset.
- Nếu có nhiều batch, phải ghép thành một dataset logic duy nhất trước khi tính Statistics.
- Không thay đổi DB, RPC hoặc schema để giải quyết vấn đề này.

### 13.2 Timezone helper

Không tái sử dụng `todayStr()` hoặc `resolveDateRange()` hiện tại nếu chúng dựa trên `toISOString()` và do đó có thể dùng UTC.

Dashboard phải có helper xử lý ngày/tháng/năm theo **UTC+07:00**.

`transaction_date` là date thuần từ input, vì vậy sau khi xác định đúng ngày/tháng/năm theo +07, việc lọc có thể thực hiện bằng chuỗi date phù hợp.

Đặc biệt phải xử lý đúng trường hợp:

- 00:xx giờ Việt Nam
- cuối ngày
- đầu tháng
- cuối tháng
- đầu năm
- cuối năm

Không được để timezone của browser làm thay đổi kỳ Statistics.

### 13.3 Correctness trước optimization

Ưu tiên correctness trước tối ưu premature.

Nếu dữ liệu hiện tại chưa đủ để tính chính xác toàn bộ Statistics, Muse phải dừng và báo lại, không tự đổi yêu cầu.

---

## 14. Test Matrix

### Core

- S1 — Theo ngày, income only
- S2 — Theo ngày, expense only
- S3 — Theo ngày, income + expense
- S4 — Theo tháng
- S5 — Theo năm
- S6 — Chênh lệch = thu - chi
- S7 — Transaction count
- S8 — Transfer không vào thu/chi/chênh lệch
- S9 — Transfer vẫn tính 1 transaction

### Pagination

- S10 — >20 transactions, Statistics tính toàn bộ
- S11 — Thay đổi “Hiển thị thêm” không đổi Statistics
- S12 — Filter + >20 transactions, Statistics tính toàn bộ filtered dataset

### Filter

- S13 — Type filter
- S14 — Account filter
- S15 — Date filter
- S16 — Search filter
- S17 — Combined filters
- S18 — Clear filter

### Timezone

- S19 — Transaction sát 00:00 +07
- S20 — Transaction sát ranh giới tháng
- S21 — Transaction sát ranh giới năm

### Net Worth

- S22 — Current Net Worth đúng
- S23 — Không có historical Net Worth chart
- S24 — Account balance thay đổi cập nhật current Net Worth nhưng không tạo snapshot

### Responsive

- S25 — Desktop
- S26 — Mobile
- S27 — Summary cards xếp chồng
- S28 — Chart không overflow

### Regression

- S29 — Existing transaction CRUD
- S30 — Transfer
- S31 — Transaction Filter
- S32 — Accounts
- S33 — Assets & Liabilities
- S34 — >1000 transactions, Statistics lấy đủ toàn bộ dataset
- S35 — Kỳ thống kê không có transaction
- S36 — Ngày/kỳ chỉ có transfer
- S37 — Dashboard period đồng bộ date filter và list
- S38 — 00:xx giờ Việt Nam không bị lệch sang ngày hôm trước do UTC
- S39 — Biểu đồ tháng hiển thị đủ các ngày trong tháng, kể cả ngày có giá trị 0

---

## 15. Invariants

1. Statistics không phụ thuộc pagination.
2. Statistics chỉ tính transaction thuộc dataset/kỳ phù hợp.
3. Transfer không đóng góp income/expense/difference.
4. Transfer đóng góp 1 vào transaction count.
5. Date boundaries dùng UTC+07.
6. Net Worth v1 chỉ là current snapshot.
7. Không có historical Net Worth trong v1.
8. Không có Category Analytics trong v1.
9. Không thay đổi DB.
10. Không thêm CDN/dependency.
11. Mobile responsive.
12. Existing features không đổi behavior.
13. Dashboard period là nguồn duy nhất cho chiều thời gian của Statistics.
14. Transaction Filter không được áp dụng thêm date range thứ hai ngoài period đã chọn.
15. Statistics phải lấy đủ transactions, kể cả khi tổng số >1000 rows.
16. Timezone của Dashboard luôn theo UTC+07, không phụ thuộc timezone browser.
17. Biểu đồ tháng phải thể hiện đủ toàn bộ ngày của tháng, kể cả ngày không có transaction.

---

## 16. Quy trình triển khai

**Chưa implement cho đến khi plan được phê duyệt.**

1. ChatGPT hoàn thiện `DASHBOARD_PLAN.md`.
2. Muse review plan.
3. Muse nêu điểm thiếu/mâu thuẫn/rủi ro.
4. ChatGPT chỉnh plan.
5. Nguyên Hoàng phê duyệt.
6. Muse mới implementation.
7. Muse QA.
8. ChatGPT review implementation.
9. Merge.
10. Production verification.

DB vẫn **LOCKED** trong toàn bộ feature v1.

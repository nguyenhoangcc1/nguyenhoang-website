# ASSETS_LIABILITIES_PLAN.md

**Status:** DRAFT --- chờ Muse review và Nguyên Hoàng phê duyệt\
**Phạm vi:** Assets & Liabilities v1\
**DB/RPC:** Chưa triển khai; tài liệu thiết kế בלבד\
**Nguyên tắc:** Không làm thay đổi logic Transaction/Transfer hiện tại.

------------------------------------------------------------------------

## 1. Mục tiêu

Xây dựng module **Tài sản & Nợ** để tính và hiển thị:

-   Tổng tài sản
-   Tổng nợ
-   Tài sản ròng (Net Worth)

Module phải phân biệt rõ:

-   **Account:** nơi quản lý/phát sinh dòng tiền và giao dịch.
-   **Net Worth Item:** một tài sản hoặc khoản nợ được đưa vào bảng cân
    đối tài chính.

Một Account có thể được liên kết với đúng một Net Worth Item để đại diện
cho giá trị tài chính của Account, nhưng không được tính trùng.

------------------------------------------------------------------------

## 2. Nguyên tắc kiến trúc

### 2.1 Account và Net Worth Item là hai khái niệm khác nhau

`accounts` tiếp tục phục vụ:

-   income
-   expense
-   transfer
-   account balance

`net_worth_items` phục vụ:

-   asset
-   liability
-   net worth

Không sao chép số dư Account sang một giá trị thủ công khác.

### 2.2 Hai chế độ Net Worth Item

Mỗi item chỉ được thuộc **một** trong hai chế độ:

**Linked** - `account_id IS NOT NULL` - `value IS NULL` - Giá trị lấy
live từ Account.

**Manual** - `account_id IS NULL` - `value IS NOT NULL` - Giá trị do
người dùng nhập.

Không cho phép: - cả `account_id` và `value` cùng có; - cả hai cùng
NULL.

### 2.3 Không đếm trùng

Nếu Account đã được linked vào Net Worth Item thì giá trị Account chỉ
được đưa vào Net Worth thông qua item đó.

Không tạo một item manual khác cho cùng số tiền nếu muốn phản ánh cùng
một nguồn tài chính.

------------------------------------------------------------------------

## 3. Database schema

Đặc tả SQL duy nhất được phép chạy nằm ở §3.0 bên dưới — đây là bản
đã được review vòng 2 và phê duyệt. Không chạy bất kỳ bản draft nào khác.

### 3.0 Migration SQL v1 — đầy đủ phạm vi dự kiến

Migration specification (chưa chạy):

```sql
alter table public.accounts
  add constraint accounts_id_user_id_unique
  unique (id, user_id);

create table public.net_worth_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  type text not null,
  category text not null,
  account_id uuid null,
  value numeric(20,2) null,
  currency text not null default 'VND',
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint net_worth_items_type_check check (type in ('asset','liability')),
  constraint net_worth_items_linked_or_manual_check check (
    (account_id is not null and value is null)
    or (account_id is null and value is not null)
  ),
  constraint net_worth_items_manual_value_check check (
    account_id is not null or value >= 0
  ),
  constraint net_worth_items_account_owner_fk
    foreign key (account_id, user_id)
    references public.accounts (id, user_id)
    on delete restrict
);

create unique index uq_net_worth_items_account_id
  on public.net_worth_items (account_id)
  where account_id is not null;

create index idx_net_worth_items_user_id
  on public.net_worth_items (user_id);

alter table public.net_worth_items enable row level security;

create policy "net_worth_items_select_own" on public.net_worth_items
for select to authenticated using (user_id = auth.uid());

create policy "net_worth_items_insert_own" on public.net_worth_items
for insert to authenticated with check (user_id = auth.uid());

create policy "net_worth_items_update_own" on public.net_worth_items
for update to authenticated using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "net_worth_items_delete_own" on public.net_worth_items
for delete to authenticated using (user_id = auth.uid());

create or replace function public.set_net_worth_items_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_net_worth_items_updated_at
before update on public.net_worth_items
for each row execute function public.set_net_worth_items_updated_at();
```

If any object name already exists, Muse must stop and report; do not silently rename or widen scope.

### 3.1 Foreign key Account và ownership ở DB

`account_id` phải tham chiếu Account thuộc **cùng `user_id`**.

v1 chọn **Composite FK** để khóa ownership ngay ở tầng dữ liệu.

Yêu cầu additive trên `accounts`:

```sql
alter table public.accounts
  add constraint accounts_id_user_id_unique
  unique (id, user_id);
```

Sau đó:

```sql
alter table public.net_worth_items
  add constraint net_worth_items_account_owner_fk
  foreign key (account_id, user_id)
  references public.accounts (id, user_id)
  on delete restrict;
```

Như vậy một `net_worth_items` row không thể liên kết tới Account của user khác.
Đây là thay đổi additive duy nhất dự kiến trên `accounts`; không thay đổi dữ liệu hay logic balance/transaction.

### 3.2 Unique linked Account

Một Account chỉ được linked vào tối đa một Net Worth Item:

``` sql
unique (account_id)
```

với semantics cho phép nhiều NULL.

Mục tiêu:

``` text
Vietcombank → tối đa 1 Net Worth Item
HSBC        → tối đa 1 Net Worth Item
```

Không cho:

``` text
Vietcombank → Asset A
Vietcombank → Asset B
```

### 3.3 Giá trị Manual

`value` của manual item phải \>= 0.

Không dùng số âm để biểu diễn liability.

Liability manual:

``` text
value = số tiền nợ dương
```

Ví dụ:

``` text
Khoản vay ngân hàng
type = liability
value = 800000000
```

------------------------------------------------------------------------

## 4. Quy ước dấu --- PHẢI KHÓA

Đây là invariant quan trọng của v1.

### 4.1 Account balance

Account tiếp tục giữ quy ước hiện tại:

-   Account thông thường không được âm.
-   Credit card có thể âm.
-   Ví dụ HSBC:

``` text
balance = -1.000.000
```

nghĩa là đang nợ 1 triệu.

### 4.2 Linked Asset

Giá trị Asset linked lấy **live** từ Account balance:

```text
asset_value = account.balance
```

Khi tạo link, UI nên cảnh báo nếu Account đang có balance < 0.

Sau khi đã link, balance có thể thay đổi. Nếu Asset linked trở thành âm, **không clamp về 0 và không tự động chuyển thành Liability**:

```text
asset_value = account.balance
```

kể cả khi `account.balance < 0`.

Ví dụ: Vietcombank lúc link = +6.000.000, sau giao dịch = -500.000 → Linked Asset value = -500.000.
Giá trị âm được giữ nguyên trong phép tính Net Worth vì phản ánh biến động giá trị ròng của nguồn tiền đó. UI có thể cảnh báo để người dùng xem xét đổi loại, nhưng v1 không tự động đổi `type`.

DB không dựa vào balance hiện tại để khóa `type`, vì balance là dữ liệu động.

### 4.3 Linked Liability

Liability linked không lưu số âm.

Giá trị hiển thị được tính:

``` text
liability_value = max(0, -account.balance)
```

Ví dụ:

``` text
HSBC balance = -1.000.000
Liability = 1.000.000
```

### 4.4 Credit Account có balance \> 0

Nếu thẻ tín dụng đang có số dư dương, ví dụ:

``` text
HSBC balance = +500.000
```

thì:

``` text
liability_value = 0
```

Khoản 500.000 dương này không được biến thành "nợ âm".

UI nên hiển thị cảnh báo rằng Account đang có số dư tín dụng dương và
Net Worth Item liability không ghi nhận giá trị nợ âm.

**v1 không tự động chuyển phần dương này thành một Asset khác.**

### 4.5 Liability Manual

Manual liability luôn nhập số dương:

``` text
value >= 0
```

Ví dụ:

``` text
Khoản vay = 800.000.000
```

Không nhập:

``` text
-800.000.000
```

### 4.6 Net Worth

``` text
Total Assets = sum(asset values)

Total Liabilities = sum(liability values)

Net Worth = Total Assets - Total Liabilities
```

Không đảo dấu thêm lần nữa ở bước tính Net Worth.

------------------------------------------------------------------------

## 5. Ownership, index, RLS và updated_at

Mỗi `net_worth_items` thuộc đúng một user: `user_id = auth.uid()`.

### 5.1 Index

```sql
create index idx_net_worth_items_user_id
  on public.net_worth_items (user_id);
```

### 5.2 RLS

```sql
alter table public.net_worth_items enable row level security;

create policy "net_worth_items_select_own"
on public.net_worth_items for select to authenticated
using (user_id = auth.uid());

create policy "net_worth_items_insert_own"
on public.net_worth_items for insert to authenticated
with check (user_id = auth.uid());

create policy "net_worth_items_update_own"
on public.net_worth_items for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "net_worth_items_delete_own"
on public.net_worth_items for delete to authenticated
using (user_id = auth.uid());
```

Ownership của `account_id` được khóa bằng Composite FK ở §3.1.
Không được tin vào `user_id` do client gửi lên.

### 5.3 updated_at

```sql
create or replace function public.set_net_worth_items_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_net_worth_items_updated_at
before update on public.net_worth_items
for each row
execute function public.set_net_worth_items_updated_at();
```

Không thay đổi trigger/function `updated_at` của các bảng hiện có.

## 6. Xóa Account

Account hiện đã có logic ngăn xóa khi có giao dịch/transfer liên quan.

Với v1 phải bổ sung điều kiện:

> Account đang được `net_worth_items.account_id` tham chiếu thì không
> được xóa.

Mục tiêu:

``` text
Account
  ├── transactions
  ├── transfer destination
  └── net_worth_items
```

Bất kỳ liên kết nào còn tồn tại đều phải được xử lý trước khi xóa
Account.

**DB FK phải bảo vệ ở tầng database**, đồng thời UI nên kiểm tra trước
để đưa thông báo dễ hiểu.

Xóa Net Worth Item:

-   được phép;
-   không xóa Account;
-   không xóa transaction.

------------------------------------------------------------------------

## 7. Tính Net Worth

v1 không cần RPC mới.

Client đọc:

``` text
accounts
net_worth_items
```

Sau đó tính:

``` text
linked asset
→ đọc balance từ account

linked liability
→ max(0, -balance)

manual asset
→ value

manual liability
→ value
```

Sau đó cộng:

``` text
Total Assets
Total Liabilities
Net Worth
```

### Quan trọng

Net Worth calculation không được cộng toàn bộ `accounts` một lần nữa nếu
Account đã được represented bởi linked Net Worth Item.

Ví dụ:

``` text
Vietcombank = 6m
Net Worth Item = linked Vietcombank = 6m
```

Tổng tài sản là:

``` text
6m
```

không phải:

``` text
6m + 6m = 12m
```

------------------------------------------------------------------------

## 8. UI v1

Dashboard thêm khu vực:

``` text
TÀI SẢN & NỢ

Tổng tài sản
Tổng nợ
Tài sản ròng
```

Có màn hình/list:

``` text
Tài sản
- Tiền gửi Vietcombank       6.000.000đ
- Tiền mặt                    1.000.000đ
- Ô tô                      500.000.000đ

Nợ
- Nợ thẻ HSBC                1.000.000đ
- Khoản vay                 800.000.000đ
```

Mỗi item có:

-   Sửa
-   Xóa

Thêm mới:

``` text
Loại:
  Tài sản
  Khoản nợ

Tên

Phương thức:
  Liên kết tài khoản
  Nhập giá trị thủ công

Tài khoản (nếu linked)
Giá trị (nếu manual)
Danh mục
Ghi chú
```

### Gợi ý loại

UI có thể gợi ý:

-   Account `credit` → Liability
-   Account khác → Asset

Nhưng đây chỉ là **gợi ý**, không phải ràng buộc cứng.

Người dùng vẫn có thể thay đổi lựa chọn.

------------------------------------------------------------------------

## 9. Category v1

Các category ban đầu:

### Asset

-   Cash & Bank
-   Real Estate
-   Vehicle
-   Other

### Liability

-   Credit Card
-   Loan
-   Other

Investment và Crypto chưa triển khai thành category nghiệp vụ riêng
trong v1.

Lý do: module Investment sau này cần thiết kế riêng để tránh double
counting.

------------------------------------------------------------------------

## 10. CRUD rules

### Create

Linked: - Account phải thuộc user. - Account chưa được linked. -
`value = NULL`.

Manual: - `account_id = NULL`. - `value >= 0`.

### Update

Khi chuyển:

``` text
Manual → Linked
```

phải xóa/NULL `value`.

Khi chuyển:

``` text
Linked → Manual
```

phải bỏ `account_id` và yêu cầu nhập `value`.

Không cho phép trạng thái trung gian vi phạm XOR constraint.

### Delete

Xóa Net Worth Item không ảnh hưởng:

-   Account
-   Transactions
-   Transfers.

------------------------------------------------------------------------

## 11. Không thay đổi các module hiện tại

Feature này tuyệt đối không thay đổi:

-   `transactions`
-   Transfer RPC:
    -   `create_transfer`
    -   `update_transfer`
    -   `delete_transfer`
-   Account balance logic hiện tại.
-   Google Login.
-   RLS hiện tại của các bảng cũ.

Chỉ được bổ sung logic cần thiết để:

-   tạo bảng `net_worth_items`;
-   bảo vệ liên kết Account;
-   ngăn xóa Account đang được linked.

------------------------------------------------------------------------

## 12. Investment --- ngoài phạm vi v1

Không làm trong feature này:

-   danh mục đầu tư chi tiết;
-   NAV;
-   giá vốn;
-   lãi/lỗ;
-   DCA;
-   ETF;
-   crypto;
-   cập nhật giá thị trường.

Sau này Investment sẽ có thiết kế riêng và phải xác định rõ nó đóng góp
vào Net Worth như thế nào mà không đếm lại tiền đã chuyển khỏi Account.

------------------------------------------------------------------------

## 13. Test matrix

### Database / Security

  \#    Test                               Expected
  ----- ---------------------------------- ------------
  DB1   User A đọc item của A              PASS
  DB2   User A đọc item của B              Không thấy
  DB3   User A sửa item của B              Bị chặn
  DB4   Linked Account khác user           Bị chặn
  DB5   `account_id` + `value` cùng có     DB reject
  DB6   `account_id` + `value` cùng NULL   DB reject
  DB7   Hai item cùng linked một Account   DB reject
  DB8   Manual asset âm                    DB reject
  DB9   Manual liability âm                DB reject

### CRUD / UI

  -----------------------------------------------------------------------
  \#                      Test                    Expected
  ----------------------- ----------------------- -----------------------
  A1                      Tạo manual asset        Đúng giá trị

  A2                      Tạo manual liability    Đúng giá trị

  A3                      Link Vietcombank        Giá trị = balance

  A4                      Link HSBC âm            Liability = số nợ dương

  A5                      Account balance thay    Linked value thay đổi
                          đổi                     

  A6                      HSBC chuyển từ âm sang  Liability = 0
                          dương                   

  A7                      Manual → Linked         Chuyển đúng chế độ

  A8                      Linked → Manual         Chuyển đúng chế độ

  A9                      Xóa Net Worth Item      Account vẫn tồn tại

  A10                     Xóa Account đang linked Bị chặn

  A11                     Xóa item rồi xóa        Cho phép nếu không còn
                          Account                 ràng buộc khác
  -----------------------------------------------------------------------

### Net Worth

  -----------------------------------------------------------------------
  \#                      Test                    Expected
  ----------------------- ----------------------- -----------------------
  NW1                     Asset only              Tổng tài sản đúng

  NW2                     Liability only          Tổng nợ đúng

  NW3                     Asset + liability       Net Worth đúng

  NW4                     Linked + manual         Không double count

  NW5                     HSBC âm                 Nợ = `-balance`

  NW6                     HSBC dương              Nợ = 0

  NW7                     Account balance đổi     Net Worth đổi theo

  NW8                     Xóa manual item         Net Worth giảm đúng

  NW9                     Transfer giữa linked    Net Worth không thay
                          accounts                đổi

  NW10                    Income/expense          Net Worth thay đổi gián
                                                  tiếp qua linked Account
                                                  balance
  -----------------------------------------------------------------------

------------------------------------------------------------------------

## 14. Migration strategy, execution và verification

Migration chỉ được chạy **sau khi**:

1.  Muse review plan.
2.  ChatGPT xử lý các góp ý.
3.  Nguyên Hoàng phê duyệt plan.
4.  Muse tạo migration trên feature branch.
5.  Chưa merge migration vào `main` cho tới khi DB test đạt.

Migration phải:

-   tạo `net_worth_items`;
-   tạo constraints;
-   tạo unique index cho linked `account_id`;
-   tạo RLS/policies;
-   bổ sung FK cần thiết;
-   cập nhật cơ chế bảo vệ xóa Account nếu cần.

Không sửa dữ liệu hiện có ngoài những gì được phê duyệt.

------------------------------------------------------------------------

### 14.2. Execution và verification trong Supabase SQL Editor

Repo hiện tại **chưa có migration runner**. v1 dùng **Supabase SQL Editor** để thực thi migration.

### 14.1. Quy trình

1. Muse tạo feature branch.
2. Muse chuẩn bị migration SQL trên branch, **không tự chạy DB**.
3. ChatGPT review migration.
4. Nguyên Hoàng phê duyệt migration.
5. Chạy đúng SQL đã duyệt trong Supabase SQL Editor của project `nguyenhoang`.
6. Không chạy SQL khác ngoài migration đã duyệt.
7. Muse verify bằng SQL read-only và browser test.

### 14.3. Verification bắt buộc

```sql
select to_regclass('public.net_worth_items');

select indexname from pg_indexes
where tablename = 'net_worth_items';

select relrowsecurity from pg_class
where oid = 'public.net_worth_items'::regclass;

select policyname, cmd from pg_policies
where tablename = 'net_worth_items';

select tgname from pg_trigger
where tgrelid = 'public.net_worth_items'::regclass
  and not tgisinternal;

select conname from pg_constraint
where conrelid = 'public.net_worth_items'::regclass
  and conname = 'net_worth_items_account_owner_fk';

select conname from pg_constraint
where conrelid = 'public.accounts'::regclass
  and conname = 'accounts_id_user_id_unique';
```

Browser verification phải bao gồm DB1–DB9, A10 và `updated_at`.

Không có rollback tự động vì repo chưa có migration runner. Rollback phải là SQL migration đảo ngược được review riêng; không được tự ý DROP để sửa nhanh.

## 15. Rollback

Nếu migration gặp vấn đề trước khi merge:

-   không sửa trực tiếp `main`;
-   rollback migration trên feature branch;
-   kiểm tra lại schema.

Nếu feature đã merge và cần rollback:

-   phải đánh giá dữ liệu thực tế đã được tạo;
-   không xóa bảng một cách mù quáng nếu đã có user data.

------------------------------------------------------------------------

## 16. Invariants bắt buộc

Các quy tắc sau phải được giữ trong mọi phiên bản tương lai:

1.  Account và Net Worth Item là hai khái niệm khác nhau.
2.  Một item chỉ là Linked hoặc Manual.
3.  Linked item lấy giá trị live từ Account.
4.  Một Account chỉ linked tối đa một item.
5.  Liability luôn biểu diễn bằng giá trị nợ dương ở lớp Net Worth.
6.  Linked liability = `max(0, -account.balance)`.
7.  Manual liability \>= 0.
8.  Không được double count Account đã linked.
9.  Xóa Net Worth Item không xóa Account.
10. Không xóa Account khi còn Net Worth Item linked.
11. Investment chưa thuộc v1.
12. Không làm thay đổi logic Transaction/Transfer hiện tại.
13. Linked Account phải thuộc cùng `user_id`; DB bảo đảm bằng Composite FK.
14. Linked Asset bám live theo `account.balance`, kể cả khi balance trở thành âm sau khi link.
15. Mọi giá trị v1 được giả định là VND.
16. Migration chỉ chạy sau khi SQL cụ thể đã được review và Nguyên Hoàng phê duyệt.

------------------------------------------------------------------------

## 17. Quy trình triển khai

``` text
ChatGPT thiết kế
      ↓
Muse review
      ↓
ChatGPT chỉnh plan
      ↓
Nguyên Hoàng phê duyệt
      ↓
Muse tạo feature branch
      ↓
Migration DB + code
      ↓
DB test + browser test
      ↓
ChatGPT review
      ↓
Nguyên Hoàng nghiệm thu theo nhu cầu
      ↓
Merge main
```

**Chưa được tạo branch hoặc chạy migration ở giai đoạn PLAN.**

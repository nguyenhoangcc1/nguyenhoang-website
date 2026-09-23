-- ============================================================================
-- Migration: Categories V1 — data migration (PHẦN 2/3: verified no-op)
-- Branch: feature/categories
--
-- AUDIT ngày 2026-09-23 (Product Owner chạy trong SQL Editor):
--   transactions: total = 1 | transfer = 1 (legacy text "Chuyển khoản",
--   amount 1.000.000) | income = 0 | expense = 0 | nulls = 0 | empties = 0
--
-- MAPPING ĐÃ DUYỆT:
--   "Chuyển khoản" (transfer) → category_id = NULL, GIỮ NGUYÊN legacy text.
--   Không tạo category "Chuyển khoản" (Transfer ≠ Income/Expense).
--   Không có category nào cần seed từ dữ liệu cũ.
--   Default categories (8 expense + 3 income, toàn bộ root) sẽ được lazy-seed
--   ở tầng application trong phase implementation, KHÔNG seed trong migration.
--
-- QUY TẮC CHẠY:
--   1. Chỉ chạy SAU PHẦN 1/3. Chưa chạy PHẦN 3/3.
--   2. File này fail closed: nếu dữ liệu thực tế lệch khỏi audit (ví dụ có
--      thêm income/expense mới), migration DỪNG với exception — không tự
--      suy đoán mapping. Khi đó audit + mapping lại từ đầu.
--   3. Milu chuẩn bị SQL nhưng KHÔNG tự chạy DB. Người chạy: Mr. Hoàng.
-- ============================================================================

-- 0. Precondition: dữ liệu phải khớp audit, nếu không DỪNG --------------------
do $$
declare
  v_income_expense int;
  v_transfer_unexpected int;
begin
  -- Không được tồn tại income/expense chưa có mapping duyệt
  select count(*) into v_income_expense
  from public.transactions
  where type in ('income','expense');
  if v_income_expense <> 0 then
    raise exception 'CATEGORIES_DATA_MIGRATION: found % income/expense transaction(s), expected 0 per audit 2026-09-23. STOP - re-audit and re-map before proceeding.', v_income_expense;
  end if;

  -- Mọi transfer phải có legacy text đúng như audit ("Chuyển khoản")
  select count(*) into v_transfer_unexpected
  from public.transactions
  where type = 'transfer'
    and btrim(category) is distinct from 'Chuyển khoản';
  if v_transfer_unexpected <> 0 then
    raise exception 'CATEGORIES_DATA_MIGRATION: found % transfer(s) with unexpected legacy category text. STOP - re-audit.', v_transfer_unexpected;
  end if;
end;
$$;

-- 1. Populate theo mapping đã duyệt -------------------------------------------
-- Transfer → category_id = NULL (explicit + idempotent; với audit hiện tại
-- đây là no-op vì cột mới default NULL, nhưng câu lệnh ghi rõ intent).
update public.transactions
set category_id = null
where type = 'transfer';

-- 2. Post-condition: invariants mà PHẦN 3/3 sẽ enforce -------------------------
do $$
declare
  v_bad int;
begin
  select count(*) into v_bad
  from public.transactions
  where (type = 'transfer') <> (category_id is null);
  if v_bad <> 0 then
    raise exception 'CATEGORIES_DATA_MIGRATION: % row(s) violate transfer/category semantics after populate.', v_bad;
  end if;
end;
$$;

-- 3. Báo cáo để người chạy đối chiếu với audit (không fail, chỉ hiển thị) ------
-- KỲ VỌNG theo audit 2026-09-23: total = 1, transfers = 1,
-- null_category_id = 1, total_amount = 1000000
select count(*) as total,
       count(*) filter (where type = 'transfer') as transfers,
       count(*) filter (where type in ('income','expense')) as income_expense,
       count(*) filter (where category_id is null) as null_category_id,
       sum(amount) as total_amount,
       (select category from public.transactions limit 1) as legacy_category_sample
from public.transactions;

-- ============================================================================
-- Verification (READ-ONLY): Assets & Liabilities v1 migration
-- Chạy sau migration trong Supabase SQL Editor để xác nhận mọi object
-- đã được tạo đúng. Chỉ SELECT, không thay đổi dữ liệu.
-- ============================================================================

-- 1. Bảng tồn tại
select to_regclass('public.net_worth_items');

-- 2. Indexes
select indexname from pg_indexes
where tablename = 'net_worth_items';

-- 3. RLS bật
select relrowsecurity from pg_class
where oid = 'public.net_worth_items'::regclass;

-- 4. Policies (phải có đủ 4: select/insert/update/delete)
select policyname, cmd from pg_policies
where tablename = 'net_worth_items';

-- 5. Trigger updated_at (loại trừ trigger nội bộ của FK)
select tgname from pg_trigger
where tgrelid = 'public.net_worth_items'::regclass
  and not tgisinternal;

-- 6. Composite FK bảo vệ ownership linked account
select conname from pg_constraint
where conrelid = 'public.net_worth_items'::regclass
  and conname = 'net_worth_items_account_owner_fk';

-- 7. UNIQUE(id, user_id) trên accounts (điều kiện để composite FK tồn tại)
select conname from pg_constraint
where conrelid = 'public.accounts'::regclass
  and conname = 'accounts_id_user_id_unique';

-- 8. Constraints trên net_worth_items (type / XOR linked-manual / value>=0)
select conname from pg_constraint
where conrelid = 'public.net_worth_items'::regclass
  and contype = 'c';

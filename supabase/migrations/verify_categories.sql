-- ============================================================================
-- Verification: Categories V1 — READ ONLY, không thay đổi dữ liệu
-- Chạy trong Supabase SQL Editor sau mỗi phase migration để đối chiếu.
-- Mỗi khối SELECT phải trả kết quả như ghi trong comment "KỲ VỌNG".
-- ============================================================================

-- V1: bảng categories tồn tại -----------------------------------------------
-- KỲ VỌNG: 1 dòng
select 'V1_table_exists' as test,
       count(*) = 1 as pass
from information_schema.tables
where table_schema = 'public' and table_name = 'categories';

-- V2: cột đúng ----------------------------------------------------------------
-- KỲ VỌNG: id, user_id, name, type, parent_id, created_at, updated_at
select 'V2_columns' as test,
       string_agg(column_name, ',' order by ordinal_position) as cols
from information_schema.columns
where table_schema = 'public' and table_name = 'categories';

-- V3: transactions.category_id tồn tại, nullable --------------------------------
-- KỲ VỌNG: category_id | uuid | YES
select 'V3_category_id_col' as test, column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public' and table_name = 'transactions'
  and column_name = 'category_id';

-- V4: constraints ---------------------------------------------------------------
-- KỲ VỌNG: thấy categories_type_check, categories_name_not_empty,
--          categories_no_self_parent (+ transactions_category_semantics_check
--          nếu đã chạy PHẦN 3/3)
select 'V4_constraints' as test, conname
from pg_constraint
where conrelid in ('public.categories'::regclass, 'public.transactions'::regclass)
  and conname like '%categor%'
order by conname;

-- V5: unique index NULLS NOT DISTINCT ---------------------------------------------
-- KỲ VỌNG: 1 dòng uq_categories_user_type_parent_name
select 'V5_unique_index' as test, indexname
from pg_indexes
where schemaname = 'public' and tablename = 'categories'
  and indexname = 'uq_categories_user_type_parent_name';

-- V6: FKs -------------------------------------------------------------------------
-- KỲ VỌNG: categories_parent_id_fk (restrict), transactions_category_id_fk (restrict)
select 'V6_fks' as test, conname,
       pg_get_constraintdef(oid) as definition
from pg_constraint
where contype = 'f'
  and (conrelid = 'public.categories'::regclass
       or (conrelid = 'public.transactions'::regclass and conname like '%categor%'))
order by conname;

-- V7: triggers ----------------------------------------------------------------------
-- KỲ VỌNG: trg_categories_hierarchy_check, trg_categories_updated_at
select 'V7_triggers' as test, trigger_name
from information_schema.triggers
where event_object_schema = 'public' and event_object_table = 'categories'
order by trigger_name;

-- V8: RLS enabled + 4 policies ----------------------------------------------------------
-- KỲ VỌNG: rls_enabled = true; 4 policies select/insert/update/delete _own
select 'V8_rls' as test, relname, relrowsecurity as rls_enabled
from pg_class where relname = 'categories';

select 'V8_policies' as test, policyname, cmd
from pg_policies
where schemaname = 'public' and tablename = 'categories'
order by policyname;

-- V9: không duplicate category trong cùng scope ----------------------------------------------
-- KỲ VỌNG: 0 dòng
select 'V9_no_duplicates' as test, user_id, type, parent_id, name, count(*)
from public.categories
group by user_id, type, parent_id, name
having count(*) > 1;

-- V10: hierarchy hợp lệ ------------------------------------------------------------------
-- KỲ VỌNG: 0 dòng (mọi child cùng user, cùng type, parent là root)
select 'V10_hierarchy' as test, c.id, c.name
from public.categories c
join public.categories p on p.id = c.parent_id
where c.user_id <> p.user_id or c.type <> p.type or p.parent_id is not null;

-- V11: category_id orphan -------------------------------------------------------------------
-- KỲ VỌNG: 0 dòng
select 'V11_orphan_category_id' as test, t.id
from public.transactions t
left join public.categories c on c.id = t.category_id
where t.category_id is not null and c.id is null
limit 20;

-- V12: transfer không có category; income/expense có category ---------------------------------
-- KỲ VỌNG: violations = 0 (sau khi PHẦN 2/3 populate xong)
select 'V12_semantics' as test,
       count(*) filter (where type = 'transfer' and category_id is not null) as transfer_with_cat,
       count(*) filter (where type in ('income','expense') and category_id is null) as nontransfer_without_cat
from public.transactions;

-- V13: legacy cột category còn nguyên ------------------------------------------------------------
-- KỲ VỌNG: 1 dòng (cột text cũ chưa bị drop)
select 'V13_legacy_col' as test, count(*) = 1 as pass
from information_schema.columns
where table_schema = 'public' and table_name = 'transactions'
  and column_name = 'category';

-- V14: tổng quan dữ liệu ------------------------------------------------------------------------------
select 'V14_overview' as test,
       (select count(*) from public.categories) as categories,
       (select count(*) from public.transactions) as transactions,
       (select count(*) from public.transactions where category_id is not null) as tx_with_category;

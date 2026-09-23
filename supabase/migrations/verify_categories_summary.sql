-- ============================================================================
-- Verification SUMMARY: Categories V1 — READ ONLY, một result duy nhất
-- Branch: feature/categories
--
-- Lý do file này tồn tại: Supabase SQL Editor chỉ hiển thị result của câu
-- SELECT cuối cùng, nên verify_categories.sql (14 khối SELECT rời) không xem
-- được đầy đủ. File này gộp V1–V14 thành MỘT bảng: test | pass | detail.
--
-- QUY TẮC: chỉ SELECT, không INSERT/UPDATE/DELETE/ALTER/CREATE/DROP.
-- KỲ VỌNG ở giai đoạn hiện tại (sau 1/3 + 2/3 + 3/3):
--   mọi dòng pass = true, bao gồm V4b (semantics CHECK đã tồn tại).
-- ============================================================================

select 'V1_table_exists' as test,
       (select count(*) = 1
        from information_schema.tables
        where table_schema = 'public' and table_name = 'categories') as pass,
       '' as detail
union all
select 'V2_columns',
       (select string_agg(column_name, ',' order by ordinal_position)
        from information_schema.columns
        where table_schema = 'public' and table_name = 'categories')
         = 'id,user_id,name,type,parent_id,created_at,updated_at',
       (select string_agg(column_name, ',' order by ordinal_position)
        from information_schema.columns
        where table_schema = 'public' and table_name = 'categories')
union all
select 'V3_category_id_col',
       (select count(*) = 1
        from information_schema.columns
        where table_schema = 'public' and table_name = 'transactions'
          and column_name = 'category_id'
          and data_type = 'uuid' and is_nullable = 'YES'),
       (select data_type || ' nullable=' || is_nullable
        from information_schema.columns
        where table_schema = 'public' and table_name = 'transactions'
          and column_name = 'category_id')
union all
select 'V4_constraints',
       (select count(*) = 3
        from pg_constraint
        where conrelid = 'public.categories'::regclass
          and conname in ('categories_type_check',
                          'categories_name_not_empty',
                          'categories_no_self_parent')),
       (select string_agg(conname, ',' order by conname)
        from pg_constraint
        where conrelid = 'public.categories'::regclass
          and conname like 'categories%')
union all
select 'V4b_semantics_check_present' as test,
       (select count(*) = 1
        from pg_constraint
        where conrelid = 'public.transactions'::regclass
          and conname = 'transactions_category_semantics_check') as pass,
       'expected present after PART 3/3' as detail
union all
select 'V5_unique_index_nulls_not_distinct',
       (select count(*) = 1
        from pg_indexes
        where schemaname = 'public' and tablename = 'categories'
          and indexname = 'uq_categories_user_type_parent_name'),
       (select indexdef
        from pg_indexes
        where schemaname = 'public' and tablename = 'categories'
          and indexname = 'uq_categories_user_type_parent_name')
union all
select 'V6_fks_restrict',
       (select count(*) = 2
        from pg_constraint
        where contype = 'f' and confdeltype = 'r'
          and (conrelid = 'public.categories'::regclass
               or (conrelid = 'public.transactions'::regclass
                   and pg_get_constraintdef(oid) like '%category_id%'))),
       (select string_agg(conname, ',' order by conname)
        from pg_constraint
        where contype = 'f' and confdeltype = 'r'
          and (conrelid = 'public.categories'::regclass
               or (conrelid = 'public.transactions'::regclass
                   and pg_get_constraintdef(oid) like '%category_id%')))
union all
select 'V7_triggers',
       -- LƯU Ý: information_schema.triggers trả 1 dòng cho mỗi EVENT của trigger,
       -- nên trigger BEFORE INSERT OR UPDATE đếm thành 2 dòng -> phải count distinct.
       (select count(distinct trigger_name) = 2
        from information_schema.triggers
        where event_object_schema = 'public'
          and event_object_table = 'categories'
          and trigger_name in ('trg_categories_hierarchy_check',
                               'trg_categories_updated_at')),
       (select string_agg(distinct trigger_name, ',' order by trigger_name)
        from information_schema.triggers
        where event_object_schema = 'public'
          and event_object_table = 'categories')
union all
select 'V8a_rls_enabled',
       (select relrowsecurity from pg_class where relname = 'categories'),
       ''
union all
select 'V8b_policies',
       (select count(*) = 4
        from pg_policies
        where schemaname = 'public' and tablename = 'categories'
          and policyname in ('categories_select_own', 'categories_insert_own',
                             'categories_update_own', 'categories_delete_own')),
       (select string_agg(policyname, ',' order by policyname)
        from pg_policies
        where schemaname = 'public' and tablename = 'categories')
union all
select 'V9_no_duplicates',
       (select count(*) = 0
        from (select user_id, type, parent_id, name
              from public.categories
              group by user_id, type, parent_id, name
              having count(*) > 1) d),
       ''
union all
select 'V10_hierarchy_valid',
       (select count(*) = 0
        from public.categories c
        join public.categories p on p.id = c.parent_id
        where c.user_id <> p.user_id
           or c.type <> p.type
           or p.parent_id is not null),
       ''
union all
select 'V11_no_orphan_category_id',
       (select count(*) = 0
        from public.transactions t
        left join public.categories c on c.id = t.category_id
        where t.category_id is not null and c.id is null),
       ''
union all
select 'V12_semantics',
       (select count(*) = 0
        from public.transactions
        where (type = 'transfer') <> (category_id is null)),
       (select 'transfers=' || count(*) filter (where type = 'transfer')
               || ' income_expense=' || count(*) filter (where type in ('income','expense'))
               || ' violations=' || count(*) filter (where (type = 'transfer') <> (category_id is null))
        from public.transactions)
union all
select 'V13_legacy_col_intact',
       (select count(*) = 1
        from information_schema.columns
        where table_schema = 'public' and table_name = 'transactions'
          and column_name = 'category'),
       (select category from public.transactions limit 1)
union all
select 'V14_overview',
       (select count(*) = 1 from public.transactions)
       and (select count(*) = 0 from public.categories),
       (select 'categories=' || (select count(*) from public.categories)
               || ' transactions=' || count(*)
               || ' tx_with_category=' || count(*) filter (where category_id is not null)
        from public.transactions)
order by 1;

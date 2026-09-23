-- ============================================================================
-- Migration: Categories V1 — schema (PHẦN 1/3: schema, không đụng dữ liệu)
-- Branch: feature/categories
-- Source of truth: CATEGORIES V1 PLAN — FINAL (đã được Product Owner phê duyệt
--   ngày 2026-09-23). Đây là bước Phase 5 của quy trình DB lock.
--
-- QUY TẮC CHẠY:
--   1. Chỉ chạy đúng nội dung file này trong Supabase SQL Editor,
--      KHÔNG chạy thêm câu lệnh nào khác.
--   2. Nếu bất kỳ object nào đã tồn tại (bảng, constraint, index,
--      policy, trigger, function) → DỪNG LẠI và báo, không tự đổi tên
--      hay mở rộng phạm vi.
--   3. Milu chuẩn bị SQL nhưng KHÔNG tự chạy DB. Người chạy: Mr. Hoàng
--      trong Supabase SQL Editor.
--   4. File này KHÔNG seed dữ liệu, KHÔNG populate transactions.category_id,
--      KHÔNG drop cột nào. Data migration nằm ở file PHẦN 2/3 (viết sau khi
--      Product Owner xác nhận mapping).
-- ============================================================================

-- 1. Bảng categories ----------------------------------------------------------
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  type text not null,
  parent_id uuid null references public.categories(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint categories_name_not_empty check (char_length(btrim(name)) > 0),
  constraint categories_type_check check (type in ('income','expense')),
  constraint categories_no_self_parent check (parent_id is null or parent_id <> id)
);

-- 2. Chống trùng tên trong cùng scope (user + type + parent + name).
--    LƯU Ý: phải dùng NULLS NOT DISTINCT vì parent_id NULL ở root category;
--    UNIQUE thường trong Postgres coi NULL khác nhau và sẽ lọt duplicate.
create unique index uq_categories_user_type_parent_name
  on public.categories (user_id, type, parent_id, name)
  nulls not distinct;

create index idx_categories_user_id
  on public.categories (user_id);

create index idx_categories_parent_id
  on public.categories (parent_id)
  where parent_id is not null;

-- 3. Trigger enforce hierarchy (DB là backstop, frontend validate cho UX) -----
--    - parent phải tồn tại
--    - parent cùng user_id
--    - parent cùng type (income/expense)
--    - chỉ 1 cấp: parent của child phải là root (parent.parent_id IS NULL)
--    - không được đổi type/user_id của category đang có children
create or replace function public.categories_hierarchy_check()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_parent_user_id uuid;
  v_parent_type text;
  v_parent_parent_id uuid;
begin
  if new.parent_id is not null then
    if new.parent_id = new.id then
      raise exception 'CATEGORIES_HIERARCHY: category cannot be its own parent';
    end if;
    select user_id, type, parent_id
      into v_parent_user_id, v_parent_type, v_parent_parent_id
      from public.categories
      where id = new.parent_id;
    if not found then
      raise exception 'CATEGORIES_HIERARCHY: parent category not found';
    end if;
    if v_parent_user_id <> new.user_id then
      raise exception 'CATEGORIES_HIERARCHY: parent must belong to the same user';
    end if;
    if v_parent_type <> new.type then
      raise exception 'CATEGORIES_HIERARCHY: parent must have the same type (income/expense)';
    end if;
    if v_parent_parent_id is not null then
      raise exception 'CATEGORIES_HIERARCHY: only one parent-child level is allowed';
    end if;
  end if;

  if tg_op = 'UPDATE' then
    if new.type <> old.type or new.user_id <> old.user_id then
      if exists (select 1 from public.categories where parent_id = new.id) then
        raise exception 'CATEGORIES_HIERARCHY: cannot change type/owner of a category that has children';
      end if;
    end if;
  end if;

  return new;
end;
$$;

create trigger trg_categories_hierarchy_check
before insert or update on public.categories
for each row execute function public.categories_hierarchy_check();

-- 4. updated_at tự động (cùng pattern net_worth_items) -------------------------
create or replace function public.set_categories_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_categories_updated_at
before update on public.categories
for each row execute function public.set_categories_updated_at();

-- 5. RLS ----------------------------------------------------------------------
alter table public.categories enable row level security;

create policy "categories_select_own" on public.categories
for select to authenticated using (user_id = auth.uid());

create policy "categories_insert_own" on public.categories
for insert to authenticated with check (user_id = auth.uid());

create policy "categories_update_own" on public.categories
for update to authenticated using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "categories_delete_own" on public.categories
for delete to authenticated using (user_id = auth.uid());

-- 6. Thêm transactions.category_id (nullable ở phase này) ----------------------
--    Source of truth mới cho category. Cột text cũ (transactions.category)
--    được GIỮ NGUYÊN và ĐÓNG BĂNG trong V1 (không ghi mới, chỉ audit).
alter table public.transactions
  add column category_id uuid null
  references public.categories(id) on delete restrict;

create index idx_transactions_category_id
  on public.transactions (category_id)
  where category_id is not null;

-- GHI CHÚ: constraint semantics ((type='transfer') = (category_id IS NULL))
-- được thêm ở PHẦN 3/3, CHỈ sau khi data migration + verification PASS
-- (nếu còn income/expense chưa map, constraint sẽ fail đúng như thiết kế).

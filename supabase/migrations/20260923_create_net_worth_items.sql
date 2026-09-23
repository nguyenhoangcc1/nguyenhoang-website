-- ============================================================================
-- Migration: Assets & Liabilities v1 — create public.net_worth_items
-- Branch: feature/assets-liabilities
-- Source of truth: docs/ASSETS_LIABILITIES_PLAN.md §3.0 (đã được review
--   vòng 2 và được phê duyệt "PHÊ DUYỆT MIGRATION" ngày 2026-09-23)
--
-- QUY TẮC CHẠY:
--   1. Chỉ chạy đúng nội dung file này trong Supabase SQL Editor,
--      KHÔNG chạy thêm câu lệnh nào khác.
--   2. Nếu bất kỳ object nào đã tồn tại (bảng, constraint, index,
--      policy, trigger, function) → DỪNG LẠI và báo, không tự đổi tên
--      hay mở rộng phạm vi.
--   3. Milu chuẩn bị SQL nhưng KHÔNG tự chạy DB. Người chạy: Mr. Hoàng
--      trong Supabase SQL Editor sau khi ChatGPT review migration.
-- ============================================================================

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

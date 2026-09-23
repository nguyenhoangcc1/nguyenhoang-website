-- ============================================================================
-- Migration bổ sung: Categories V1 — table-level GRANT
-- Branch: feature/categories
--
-- BỐI CẢNH:
--   Migration 20260923_create_categories.sql đã chạy thành công và đã tạo
--   bảng categories cùng constraints, UNIQUE NULLS NOT DISTINCT, hierarchy
--   trigger, RLS, 4 policies.
--   Tuy nhiên role `authenticated` (Supabase JS client sau khi login Google)
--   sẽ nhận "permission denied for table categories" ngay cả trên SELECT nếu
--   thiếu GRANT ở tầng table — cùng nguyên nhân đã gặp ở net_worth_items
--   (xem 20260923_grant_net_worth_items_authenticated.sql):
--   Supabase không tự động expose table mới cho anon/authenticated;
--   GRANT và RLS là hai lớp độc lập — thiếu GRANT thì policy RLS không bao
--   giờ được xét.
--   Không có GRANT này, toàn bộ frontend Categories V1 (seed, CRUD,
--   dropdown, filter, statistics) đều không hoạt động.
--
-- QUY TẮC:
--   1. KHÔNG sửa migration cũ, KHÔNG chạy lại migration cũ.
--      Lịch sử DB là append-only.
--   2. Chỉ cấp cho `authenticated` (least privilege). Không cấp cho `anon`
--      (dữ liệu tài chính cá nhân, chỉ user đăng nhập được chạm).
--   3. Không sửa policies / schema / constraints / triggers trong file này.
--   4. Milu chuẩn bị SQL nhưng KHÔNG tự chạy DB. Người chạy: Mr. Hoàng
--      trong Supabase SQL Editor, sau khi ChatGPT review và phê duyệt.
-- ============================================================================

grant select, insert, update, delete
on public.categories
to authenticated;

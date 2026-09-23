-- ============================================================================
-- Migration bổ sung: Assets & Liabilities v1 — table-level GRANT
-- Branch: feature/assets-liabilities
--
-- BỐI CẢNH:
--   Migration 20260923_create_net_worth_items.sql đã chạy thành công
--   ("Success. No rows returned") và đã tạo bảng net_worth_items cùng
--   constraints, RLS, 4 policies, trigger.
--   Verification behavioral sau đó cho thấy role `authenticated` nhận
--   "permission denied for table net_worth_items" ngay cả trên SELECT.
--   Nguyên nhân: Supabase không còn tự động expose table mới cho
--   anon/authenticated (default mới từ 30/05/2026); GRANT và RLS là hai
--   lớp độc lập — thiếu GRANT thì policy RLS không bao giờ được xét.
--
-- QUY TẮC:
--   1. KHÔNG sửa migration cũ, KHÔNG chạy lại migration cũ.
--      Lịch sử DB là append-only: migration 1 tạo cấu trúc,
--      migration 2 (file này) cấp quyền.
--   2. Chỉ cấp cho `authenticated` (least privilege). Không cấp cho
--      `anon` (dữ liệu tài chính cá nhân, chỉ user đăng nhập được chạm).
--      Không GRANT ALL cho service_role (Supabase đã có cơ chế riêng,
--      bypass RLS; không mở rộng phạm vi).
--   3. Không sửa policies / schema / constraints trong file này.
--   4. Milu chuẩn bị SQL nhưng KHÔNG tự chạy DB. Người chạy: Mr. Hoàng
--      trong Supabase SQL Editor, sau khi ChatGPT review và phê duyệt.
-- ============================================================================

grant select, insert, update, delete
on public.net_worth_items
to authenticated;

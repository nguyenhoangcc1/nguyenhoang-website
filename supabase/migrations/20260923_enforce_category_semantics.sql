-- ============================================================================
-- Migration: Categories V1 — enforce semantics (PHẦN 3/3)
-- Branch: feature/categories
--
-- QUY TẮC CHẠY:
--   1. CHỈ chạy file này SAU KHI:
--      - PHẦN 1/3 (schema) đã chạy xong, và
--      - PHẦN 2/3 (seed + populate category_id theo mapping đã duyệt) đã chạy, và
--      - verification M1–M8 PASS, đặc biệt: không còn income/expense nào
--        có category_id IS NULL ngoài danh sách đã được Product Owner xử lý.
--   2. Nếu câu lệnh FAIL vì còn row vi phạm → ĐÓ LÀ ĐÚNG THIẾT KẾ (fail closed).
--      Không sửa constraint cho "lọt". Quay lại xử lý dữ liệu rồi chạy lại.
--   3. Milu chuẩn bị SQL nhưng KHÔNG tự chạy DB. Người chạy: Mr. Hoàng.
-- ============================================================================

-- Semantics: transfer ⟺ không có category; income/expense ⟺ bắt buộc có category.
-- Không dùng NOT NULL thuần vì transfer hợp lệ không có category.
alter table public.transactions
  add constraint transactions_category_semantics_check
  check ((type = 'transfer') = (category_id is null));

-- ============================================================================
-- Verification: Categories V1 — table-level GRANT capability
-- (theo yêu cầu review: kiểm tra authenticated có CRUD, anon không có)
-- Read-only. Chạy sau khi migration 20260923_grant_categories_authenticated.sql
-- đã được phê duyệt và chạy thành công.
--
-- KỲ VỌNG:
--   - authenticated: có SELECT, INSERT, UPDATE, DELETE (CRUD đầy đủ)
--   - anon: KHÔNG có SELECT/INSERT/UPDATE/DELETE (chỉ user đăng nhập
--     mới chạm được dữ liệu — đúng least privilege)
-- ============================================================================

select grantee,
       privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name = 'categories'
order by grantee, privilege_type;

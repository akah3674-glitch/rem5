-- ============================================================
-- Fix skill icon IDs cho template 27 (Biến Hình) và 28 (Phân Thân)
-- 
-- Lỗi: 
--   Template 27 dùng icon_id=718 (ảnh SRC-Team, không có trong Teamobi client)
--   Template 28 dùng icon_id sai → client hiển thị avatar nhân vật
--
-- Fix: đổi sang icon đã xác nhận hoạt động trong Teamobi2026 client
-- ============================================================

-- Kiểm tra trước khi sửa
SELECT id, nclass_id, name, icon_id 
FROM skill_template 
WHERE id IN (27, 28)
ORDER BY id, nclass_id;

-- Biến Hình (template_id = 27):
-- Đổi từ 718 (icon SRC-Team) sang 3783 (icon Dịch Chuyển Tức Thời, confirmed working)
UPDATE skill_template SET icon_id = 3783 WHERE id = 27;

-- Phân Thân (template_id = 28):
-- Đổi sang 3784 (icon Khiên Năng Lượng, confirmed working)
-- Fix đồng thời lỗi "icon quá to" vì icon nhân vật (character sprite) lớn hơn skill icon
UPDATE skill_template SET icon_id = 3784 WHERE id = 28;

-- Verify sau khi sửa
SELECT id, nclass_id, name, icon_id 
FROM skill_template 
WHERE id IN (27, 28)
ORDER BY id, nclass_id;

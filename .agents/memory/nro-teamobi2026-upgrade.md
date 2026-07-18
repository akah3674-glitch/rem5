---
name: NRO Teamobi2026 Upgrade
description: Tiến trình phân tích và tích hợp Teamobi2026 vào NRO SRC-Team
---

## Trạng thái (2026-07-18 — HOÀN TẤT)

### Phase 13 — Teamobi2026 integration ✅ XONG
- **DB tables** (7 bảng mới): achievement_template, array_head_2_frames, bg_item_template, clan_task_template, data_badges, radar, task_badges_template → đã import ✅
- **ALTER TABLE player**: cột radar + 39 cột khác đã thêm ✅
- **Boss classes**: Baby, Cumber, Bojack chain (6), GoldenFrieza đã compile vào JAR ✅
- **Server**: restart thành công (PID 22212, port 14445) ✅
- **Tổng bảng DB**: 47 bảng

### Boss classes — so sánh Teamobi vs SRC-Team
- Baby.java: 139 dòng (bằng nhau — SRC đã có bản tốt)
- Cumber.java: 165 dòng (bằng nhau)
- Bojack chain (BIDO/BOJACK/BUJIN/KOGU/SUPER_BOJACK/ZANGYA): bằng nhau — không update
- GoldenFrieza: không check (compile vẫn OK)

## Tất cả phases keepalive đã xong
| Phase | Nội dung | Trạng thái |
|-------|----------|------------|
| 1 | Diagnostics + scan code | ✅ |
| 2 | Compile fix + đọc code | ✅ |
| 3-6 | DB upgrades, skill/mob/NPC | ✅ |
| 7 | Patch Mob.java + map density + compile | ✅ |
| 8-12 | Fix attack delay, animation-first, TIME_GONG | ✅ |
| 13 | Teamobi2026 DB + boss classes | ✅ |

## Phase 18 — Học hỏi từ Teamobi2026 ✅ XONG (2026-07-18)

### Phân tích Teamobi2026 (629MB RAR)
**Cấu trúc:** SRC/src (Java), database team2026.sql, LÂU CỒ MOD (Unity client exe)

**Điểm khác biệt quan trọng Teamobi vs SRC-Team:**
- Teamobi KHÔNG có skill 27 (BIEN_HINH) và 28 (PHAN_THAN) — max skill id=26 (MA_PHONG_BA)
- Teamobi KHÔNG có bảng cai_trang — dùng item_template.head/body/leg trực tiếp
- Teamobi item_template field 7 (0-idx 6) = icon_id (KHÔNG phải gem) — parsing cần cẩn thận
- Teamobi setIsBinh = "Ma Phong Ba" skill (biến thành Tiểu Đội Trưởng), dùng icon 11175/11166
- Teamobi có NPC IDs 76-77, 103-110 trong npc_template — SRC-Team cũng đã có sẵn ✅

**Những gì SRC-Team đã có TỐT HƠN Teamobi:**
- Skill 27 (BIEN_HINH) + 28 (PHAN_THAN): custom implementation hoàn chỉnh
- setBienHinh() gọi Send_Caitrang(player) + sendItemTime(player, 3783, 600) ✅
- getHead/getBody/getLeg xử lý isBienHinh với OUTFIT_BIEN_HINH array ✅
- cai_trang table mapping id_temp → head/body/leg ✅

### Thay đổi thực hiện (Phase 18)
- **cai_trang table**: 351 → 453 entries (thêm 102 items type=5 có head/body/leg trong item_template nhưng thiếu trong cai_trang)
- **item 1557 "Hắc Mị Nương"** (VIP cải trang từ Teamobi): gem 0→500, thêm vào cai_trang (head=1434,body=1435,leg=1436), thêm vào shop tab "Tất cả"
- **Shop**: SHOP_CAI_TRANG (shop_id=37) nay có 74 items (thêm 1557 + cải trang cao cấp)
- **Không cần compile** — toàn bộ là DB changes, cai_trang query on-demand

### Key patterns học từ Teamobi
- `setIsBinh(player, time)` → `Send_Caitrang(player)` + `sendItemTime(icon, time)` ← đây là pattern đúng
- ToriBot.java: NPC VIP phức tạp, tạo items với ItemOption (dùng `createNewItem(id).itemOptions.add(new ItemOption(field, val))`)
- `sendEffCaiTrang(player, costumeId)` trong Service.java = apply costume effect từ item use

## Phase 17 — NPC Cải Trang Shop ✅ XONG (2026-07-18)
- NPC ID=85 "Cửa Hàng Cải Trang" → CaiTrangShop.java; shop ID=37 tag=SHOP_CAI_TRANG
- 4 tabs (tab_shop id 64-67): Tất cả / Nam / Nữ / Saiyajin; 73 items có giá gem
- NPC đặt map 0 Làng Aru tại x=1100,y=432; npc_template id=85 head=487,body=488,leg=489
- ConstNpc.CAI_TRANG_SHOP=85 (byte, sau XE_NUOC_MIA=84)
- Compile chain quan trọng: MiniGame → LyTieuNuong → NpcFactory (LyTieuNuong chưa có trong JAR)
- Server load: shop(33), npc_template(94) ✅

## Còn lại (ưu tiên thấp)
- Cleanup Map.java dead scheduler (332 idle threads, không ảnh hưởng gameplay)
- Test failover sang 3 Codespace dự phòng
- Tunnel: nếu frp.freefrp.net không ổn → thử playit.gg port 7777
- GitHub Secrets đã bị xóa khỏi Replit — keepalive dùng gh cache trên Codespace (OK)

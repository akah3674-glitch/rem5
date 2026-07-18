---
name: NRO Teamobi DB Deep Dive
description: Phân tích sâu database Teamobi2026 (11903 dòng SQL) — các table, pattern code, và so sánh với SRC-Team
---

# NRO Teamobi2026 — Database & Code Deep Dive (2026-07-18)

**Why:** Tránh phân tích lại mỗi lần, đây là toàn bộ kết quả khai thác từ `server/database_team2026.sql` và `docs/teamobi2026_src/`.

---

## Tables trong Teamobi DB (server/database_team2026.sql — 11903 dòng)

| Table | Entries | Ghi chú |
|---|---|---|
| `flag_bag` | 79+ | Phụ kiện (cờ/khăn/vũ khí) — SRC-Team ĐÃ có (sendFlagBag, Template.FlagBag) |
| `intrinsic` | 26 (0-25) | Nội tại theo gender — SRC-Team ĐÃ có IntrinsicService/IntrinsicPlayer |
| `npc_template` | 111 (0-84 + 103-110) | Xem bảng NPC đầy đủ bên dưới |
| `data_badges` | 18 | Badge huy hiệu với JSON options — SRC-Team ĐÃ có |
| `achievement_template` | nhiều | Thành tích — SRC-Team ĐÃ có |
| `clan_task_template` | nhiều | Nhiệm vụ bang hội — SRC-Team ĐÃ có |
| `array_head_2_frames` | nhiều | Animation frame data |
| `bg_item_template` | nhiều | Background item template |
| `item_template` | 4 batches | Cấu trúc: id,TYPE,gender,NAME,desc,level,**icon_id**,part,is_up_to_up,power_require,gold,gem,head,body,leg |
| `flag_bag` | 79+ | icon_data=animation ids, NAME, gold, gem, icon_id |

---

## ⚠️ Cảnh báo quan trọng — item_template field 7

```
item_template column index 6 (0-based) = icon_id  (KHÔNG phải gem!)
                                                     ↑ hay nhầm khi parse thủ công
Cấu trúc đúng: id | TYPE | gender | NAME | desc | level | icon_id | part | ... | gold | gem | head | body | leg
```

---

## NPC Template — Bảng đầy đủ Teamobi (0-84 + 103-110)

```
0=Ông Gôhan, 1=Ông Paragus, 2=Ông Moori, 3=Rương đồ, 4=Đậu thần
5=Con mèo, 6=Khu vực, 7=Bunma, 8=Dende, 9=Appule, 10=Dr.Brief
11=Cargo, 12=Cui, 13=Quy Lão Kame, 14=Trưởng lão Guru, 15=Vua Vegeta
16=Uron, 17=Bò Mộng, 18=Thần mèo Karin, 19=Thượng Đế, 20=Thần Vũ Trụ
21=Bà Hạt Mít, 22=Trọng tài, 23=Ghi danh, 24=Rồng Thiêng, 25=Lính canh
26=Độc Nhãn, 27=Rồng Thần Namec, 28=Cửa hàng ký gửi, 29=Rồng Omega
30-36=Rồng 2-7+1sao, 37=Bunma(v2), 38=Ca Lích, 39=Santa, 40=Mabư mập
41=Trung thu, 42=Quốc Vương, 43=Tổ Sư Kaio, 44=Ôsin, 45=Kibit
46=Babiđây, 47=Giu-ma Đầu Bò, 48=Ngộ Không SSJ, 49=Đường Tăng
50=Quả trứng, 51=Dưa hấu, 52=Hùng Vương, 53=Tapion, 54=Lý Tiểu Nương
55=Bill, 56=Whis, 57=Champa, 58=Vados, 59=Trọng tài(v2)
60=Goku SSJ(v1), 61=Goku SSJ(v2), 62=Potage, 63=Jaco, 64=Thiên Sứ Whis
65=Yarirobe, 66=Nồi bánh, 67=Mr Popo, 68=Panchy, 69=Thỏ Đại Ca
70=Bardock, 71=Berry, 72=Đặc Cầu, 73=Fide, 74=Tori-Bot
75=Thỏ Đỏ ChiChi, 76=Granola, 77=Quả trứng linh thú, 78=Ông già Noel
79=Cây thông Noel, 80=Npc, 81=Chi Chi, 82=Rương Sưu Tầm
83=Dr.Myuu, 84=Xe nước mía
103=Chú Bé Đần, 104=Khá BảnH, 105=Tiến Bry, 106=Bulma Tết Nguyên Đán
107=Bill Bí Ngô, 108=Heart, 109=Bulma Bunny, 110=Bunma Rực Rỡ
```
**SRC-Team:** NPC 85=CaiTrangShop (thêm ở Phase 17), còn 86-102 trống.

---

## BossID — Teamobi vs SRC-Team

```java
GOLDEN_FRIEZA = -502          // cả hai đều có
MATROI        = -349          // Halloween
DOI           = -350          // Halloween
BIMA          = -351          // Halloween
BLACK_GOKU    = -203
CUMBER        = -203999
SUPER_BOJACK  = -321
DOI_TRUONG_5  = -339          // Yardrat
```

---

## Pattern quan trọng — Drop item có stat (ItemOptions)

```java
// Tạo ItemMap drop với stats tùy chỉnh (GoldenFrieza.java pattern)
ItemMap item = new ItemMap(zone, itemTemplateId, count,
    x + Util.nextInt(-50, 50),
    zone.map.yPhysicInTop(x, y - 24),
    plKill.id);                          // ownerId: ai được pick

item.options.add(new Item.ItemOption(30, 1));    // field 30 = 1
item.options.add(new Item.ItemOption(50, 20));   // field 50 = 20
item.options.add(new Item.ItemOption(77, 20));
item.options.add(new Item.ItemOption(103, 20));
item.options.add(new Item.ItemOption(93, 20));
Service.gI().dropItemMap(zone, item);
```
**Example:** GoldenFrieza drop item 629 (Cải trang Fide Vàng) với 5 stat options.

---

## GoldenFrieza — Pattern spawn + bomb

```java
// Chỉ spawn lúc 21h
if (TimeUtil.is21H()) {
    super.joinMap();
    zone.isGoldenFriezaAlive = true;
}

// setBom() — bomb delay 2.5s
bombScheduler.schedule(() -> {
    for (Player pl : zone.getNotBosses()) {
        pl.injured(this, 2_100_000_000, true, false);  // 2.1B instant kill
    }
}, 2500, TimeUnit.MILLISECONDS);
```
**SRC-Team đã có** GoldenFrieza.java 223 dòng với setBom() tương đương ✅

---

## intrinsic — Nội tại (26 loại, per gender)

| id | Nội dung | gender |
|---|---|---|
| 0 | Chưa kích hoạt | 3 (all) |
| 1 | Dragon +5-25% dame | 0 (Trái Đất) |
| 2 | Kamejoko +5-25% dame | 0 |
| 3 | TDHS +10-35% speed / -10-35% KI | 0 |
| 6 | Dịch chuyển +50-150% đòn kế | 0 |
| 7 | Thôi miên +50-150% đòn kế | 0 |
| 8-15 | Namec equivalents | 1 |
| 16-22 | Saiyajin equivalents | 2 |
| 23 | Vàng từ quái +25-300% | 3 |
| 24 | Sức mạnh+tiềm năng +5-35% | 3 |
| 25 | Chí mạng khi HP thấp | 3 |
**SRC-Team:** IntrinsicService.java đã có, load từ DB.

---

## Halloween Boss Pattern (MaTroi/BiMa/Doi)

```java
// Drop item 585 (quà Halloween)
ItemMap it = new ItemMap(zone, 585, 1, x, y, plKill.id);
Service.gI().dropItemMap(zone, it);

// Apply Halloween buff cho người chơi gần boss
if (!player.effectSkill.isHalloween) {
    EffectSkillService.gI().setIsHalloween(player, outfitId, 1800000); // 30 phút
}
// outfitId khác nhau: MaTroi=4, BiMa=2
```
**SRC-Team:** setIsHalloween() tại EffectSkillService.java line 373 ✅

---

## flag_bag — Phụ kiện (79+ loại)

```
icon_data = comma-separated animation IDs (e.g. '1017, 1018')
icon_id   = display icon trong UI
Cờ: 0-9 (vàng/tím/xanh... 10K vàng mỗi cái)
Khăn: 10-18 (50K vàng)
Vũ khí phụ: 19-29 (Ba lô 200 gem, Đao 500 gem, Gậy 400 gem...)
Seasonal: 32-36 (Lồng đèn TT 50 gem), 50-51 (Noel...)
Modern: 47-49 (Among us), 56-57 (Trái bóng/Cúp vàng)
High-end: 69-71 (Kiếm phát sáng/Búa 1B vàng)
```
**SRC-Team:** sendFlagBag() đã hoạt động, bảng flag_bag import cùng Teamobi2026 data ✅

---

## 3 Drive Files chưa phân tích

Drive IDs (không download được do auth wall — cần gdown/OAuth):
- `1ENWegm_JR1E4kRYGgx1ypgeoIMbkn_aj` — chưa biết nội dung
- `1HlpW2Dg-Tt-UNSLlljC47LB_SrhYYII4` — chưa biết nội dung
- `1XxlILhBTyF-1uRK2NQ7BKAVRYuJ6qhmv` — chưa biết nội dung

**How to apply:** Nếu user cần phân tích 3 file này → phải dùng gdown với credentials hoặc user tự up lên Replit (kéo file vào attached_assets).

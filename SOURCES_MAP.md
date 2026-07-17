# 🗺️ BẢN ĐỒ SOURCE CODE — NRO Server

> Tất cả file Java nằm trong `server/src/`  
> Sau khi sửa file → phải compile lại → update JAR → restart server (xem hướng dẫn cuối)

---

## 📁 Cấu trúc tổng quan

```
server/src/
├── models/                          ← Model phụ (xem bên dưới)
└── nro/models/
    ├── Bot/                         ← Bot NPC tự động
    ├── boss/                        ← Toàn bộ Boss (159 file)
    ├── clan/                        ← Hệ thống Clan/Băng
    ├── combine/                     ← Tổng hợp đồ (craft)
    ├── consts/                      ← Hằng số toàn server
    ├── daily_Giftcode/              ← Gift code hàng ngày
    ├── data/                        ← Load data game
    ├── database/                    ← Truy vấn DB
    ├── event/                       ← Hệ thống event
    ├── event_list/                  ← Danh sách event cụ thể
    ├── ievent/                      ← Interface event
    ├── interfaces/                  ← Interfaces chung
    ├── intrinsic/                   ← Kỹ năng bẩm sinh/passive
    ├── managers/                    ← Các Manager tổng
    ├── map/                         ← Bản đồ / Map
    ├── matches/                     ← PvP / Đấu trường
    ├── minigame/                    ← Mini game
    ├── mob/                         ← Quái thường (mob)
    ├── mob_bigboss/                 ← Big boss dạng mob
    ├── network/                     ← Mạng / Packet
    ├── npc/                         ← NPC logic
    ├── npc_list/                    ← Danh sách NPC cụ thể (59 file)
    ├── player/                      ← Nhân vật người chơi
    ├── player_badges/               ← Huy hiệu danh hiệu
    ├── player_system/               ← Hệ thống nhân vật
    ├── radar/                       ← Radar / Minimap
    ├── server/                      ← Core server
    ├── services/                    ← Service xử lý logic game
    ├── services_dungeon/            ← Service dungeon / instance
    ├── services_func/               ← Hàm tiện ích service
    ├── shop/                        ← Cửa hàng
    ├── shop_ky_gui/                 ← Cửa hàng ký gửi
    ├── skill/                       ← Kỹ năng
    ├── task/                        ← Nhiệm vụ / Quest
    └── utils/                       ← Tiện ích chung
```

---

## 🎯 Muốn sửa gì → xem ở đâu

| Muốn sửa | File/Folder cần tìm |
|-----------|---------------------|
| **Lệnh admin chat** (`hs`, `gb`, `m`, `i`...) | `server/src/Command.java` ⭐ |
| **Config server** (port, DB, sv1) | `server/Config.properties` ⭐ |
| **Skill của boss cụ thể** | `server/src/nro/models/boss/<TênBoss>/` |
| **Skill của player** | `server/src/nro/models/skill/PlayerSkill.java` |
| **Hệ thống skill chung** | `server/src/nro/models/skill/Skill.java`, `NClass.java` |
| **Spawn boss sự kiện** | `server/src/nro/models/boss/Boss_Manager/BossManager.java` |
| **Boss Broly** | `server/src/nro/models/boss/Broly/` |
| **Boss Cell / Xen** | `server/src/nro/models/boss/Cell/` |
| **Boss Golden Frieza** | `server/src/nro/models/boss/Golden_fireza/` |
| **Boss Android** | `server/src/nro/models/boss/Android/` |
| **Boss Majin Buu** | `server/src/nro/models/boss/MajinBuu_12h/`, `MajinBuu_14h/` |
| **Boss mini (quái phụ)** | `server/src/nro/models/boss/Boss_mini/` |
| **Sự kiện Giáng Sinh** | `server/src/nro/models/boss/Boss_Manager/ChristmasEventManager.java` |
| **Sự kiện Halloween** | `server/src/nro/models/boss/Boss_Manager/HalloweenEventManager.java` |
| **Sự kiện Tết** | `server/src/nro/models/boss/Boss_Manager/LunarNewYearEventManager.java` |
| **Đại hội võ thuật** | `server/src/nro/models/boss/dai_hoi_vo_thuat/` |
| **Nhân vật người chơi** | `server/src/nro/models/player/` |
| **Nhiệm vụ / Quest** | `server/src/nro/models/task/` |
| **Cửa hàng thường** | `server/src/nro/models/shop/` |
| **Cửa hàng ký gửi** | `server/src/nro/models/shop_ky_gui/` |
| **Bot tự động** | `server/src/nro/models/Bot/` |
| **PvP / Đấu trường** | `server/src/nro/models/matches/` |
| **Bản đồ / Map** | `server/src/nro/models/map/` |
| **Packet / Mạng** | `server/src/nro/models/network/` |
| **Database query** | `server/src/nro/models/database/` |
| **Gift code** | `server/src/nro/models/daily_Giftcode/`, `models/GiftCode.java` |
| **Clan / Băng** | `server/src/nro/models/clan/` |
| **Huy hiệu** | `server/src/nro/models/player_badges/` |
| **Tổng hợp đồ** | `server/src/nro/models/combine/` |
| **Hằng số (ID boss, item...)** | `server/src/nro/models/consts/` |
| **Dungeon / Instance** | `server/src/nro/models/services_dungeon/` |
| **Mini game** | `server/src/nro/models/minigame/` |
| **Tiện ích chung** | `server/src/nro/models/utils/` |

---

## 📦 Chi tiết các file quan trọng

### ⭐ File hay sửa nhất

| File | Vai trò |
|------|---------|
| `server/src/Command.java` | Tất cả lệnh admin chat trong game |
| `server/Config.properties` | Cấu hình port, DB, địa chỉ server |
| `server/src/nro/models/skill/PlayerSkill.java` | Skill của player |
| `server/src/nro/models/boss/Boss_Manager/BossManager.java` | Spawn boss, lịch boss |
| `server/src/nro/models/player/` | Logic nhân vật, stat, level |

### 🐉 Boss — phân loại chi tiết

```
boss/
├── Boss.java              ← Class boss gốc (base class)
├── BossData.java          ← Data boss (HP, ATK, DEF...)
├── BossID.java            ← Danh sách ID boss
├── BossesData.java        ← Load data nhiều boss
│
├── Android/               ← Android 13,14,15,19, DrKore, KingKong, Pic, Poc
├── Baby/                  ← Baby
├── Black_Goku/            ← Black Goku
├── Broly/                 ← Broly, SuperBroly
├── Cell/                  ← Xencon 1-7, SieuBoHung, XenBoHung
├── Cold/                  ← Cooler
├── Frieza/                ← Fide (Frieza)
├── Golden_fireza/         ← Golden Frieza + DeathBeam 1-5
├── MajinBuu_12h/          ← Event 12h: Mabu, BuiBui, Cadic, Drabura, Goku, Yacon
├── MajinBuu_14h/          ← Event 14h: Mabu2H, SuperBu
├── Nappa/                 ← Nappa, Kuku, Rambo, MapDauDinh
├── Tau_PayPay/            ← TaoPaiPai
├── cumber/                ← Cumber
├── ban_do_kho_bau/        ← Boss bản đồ kho báu
├── dai_hoi_vo_thuat/      ← Boss đại hội võ thuật (10 boss)
│
├── Boss_mini/             ← Boss mini: AnTrom, MatTroi, Odo, RongNhi, SoiHecQuyn, Virut
├── Boss_Manager/          ← Managers:
│   ├── BossManager.java           ← CHÍNH — spawn, schedule boss
│   ├── BrolyManager.java
│   ├── ChristmasEventManager.java
│   ├── FinalBossManager.java
│   ├── GasDestroyManager.java
│   ├── HalloweenEventManager.java
│   ├── HungVuongEventManager.java
│   ├── LunarNewYearEventManager.java
│   ├── OtherBossManager.java
│   ├── RedRibbonHQManager.java
│   ├── SkillSummonedManager.java
│   ├── SnakeWayManager.java
│   ├── TreasureUnderSeaManager.java
│   ├── TrungThuEventManager.java (Trung thu)
│   └── YardartManager.java
└── boss_con_duong_ran_doc/ ← Boss con đường rắn độc (3 file)
```

---

## 🔧 Quy trình sửa code

### 1. Sửa rồi compile

```bash
# SSH vào Codespace trước
cd /home/codespace/nro/SRC

# Compile 1 file (ví dụ Command.java)
javac -cp NgocRongOnline.jar:lib/* \
  -sourcepath src \
  -d /tmp/out \
  src/nro/models/server/Command.java

# Hoặc compile toàn bộ
find src -name "*.java" > /tmp/sources.txt
javac -cp NgocRongOnline.jar:lib/* -d /tmp/out @/tmp/sources.txt
```

### 2. Update JAR

```bash
cd /home/codespace/nro/SRC
# Backup JAR cũ
cp NgocRongOnline.jar NgocRongOnline.jar.bak

# Update class vào JAR
jar uf NgocRongOnline.jar -C /tmp/out nro/models/server/Command.class
```

### 3. Restart server

```bash
pkill -f NgocRongOnline; sleep 2
cd /home/codespace/nro/SRC
nohup java -Xms256m -Xmx1g -jar NgocRongOnline.jar > ~/logs/server.log 2>&1 &
sleep 15; tail -20 ~/logs/server.log
```

---

## ⚠️ Lưu ý quan trọng

- `damage` trong `skill_template` là kiểu **Short** → max **32767**, vượt quá server crash!
- Password NRO là **plain text** (không hash MD5/SHA1)
- **KHÔNG** đặt `server.ip` trong Config.properties → gây redirect sai
- Kết nối game: `bore.pub:5798` (IP cố định `159.223.110.159`)
- Sau khi sửa JAR phải restart server mới có hiệu lực

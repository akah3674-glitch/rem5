---
name: NRO Skill Code Map
description: Bản đồ chính xác vị trí code cho từng skill — dùng để tìm đúng chỗ sửa mà không cần tìm lại
---

# NRO Skill Code Map — Vị trí code chính xác

**Why:** Tránh mất thời gian tìm file mỗi phiên. Sai đâu → mở đúng file đó.

---

## 🔵 Skill 27 — Biến Hình ✅ HOÀN THÀNH

| Thay đổi | File | Dòng/Method |
|---|---|---|
| Kích hoạt skill | `server/src/nro/models/services/SkillService.java` | `case Skill.BIEN_HINH` trong `useSkillAlone()` |
| Áp dụng buff + skin + timer | `server/src/nro/models/services/EffectSkillService.java` | `setBienHinh(Player)` |
| Tắt buff + xóa skin + xóa timer | `server/src/nro/models/services/EffectSkillService.java` | `bienHinhDown(Player)` |
| Tự động hết giờ (10 phút) | `server/src/nro/models/player/EffectSkill.java` | `update()` — kiểm tra `isBienHinh` |
| Đổi skin khi active | `server/src/nro/models/player/Player.java` | `getHead()` / `getBody()` / `getLeg()` — block `isBienHinh` |
| Bảng outfit theo race+cấp | `server/src/nro/models/consts/ConstPlayer.java` | `OUTFIT_BIEN_HINH[nclass][level-1][head/body/leg]` |
| Hằng số skill ID | `server/src/nro/models/skill/Skill.java` | `BIEN_HINH = 27` |
| Timer icon ID | — | Icon `1995` (item "Cải trang"), 600 giây |
| Bonus dame/def | `EffectSkillService.java` | `BIEN_HINH_DAME[]` + `BIEN_HINH_DEF[]` |
| Áp dụng bonus vào chỉ số | `server/src/nro/models/player/NPoint.java` | `calPoint()` — `bienHinhDameBonus` / `bienHinhDefBonus` |

---

## 🟣 Skill 28 — Phân Thân ✅ HOÀN THÀNH

| Thay đổi | File | Dòng/Method |
|---|---|---|
| Kích hoạt skill (TYPE=4) | `server/src/nro/models/services/SkillService.java` | `case Skill.PHAN_THAN` trong `useNewSkillNotFocus()` |
| Thời gian active | `SkillService.java` | `timePhanThan = 300000` (5 phút) |
| Spawn clone | `server/src/nro/models/services/EffectSkillService.java` | `spawnPhanThanClones(Player)` |
| Timer icon 31142 (bật) | `EffectSkillService.java` | cuối `spawnPhanThanClones()` — `sendItemTime(player, 31142, 300)` |
| Xóa clone + icon (tắt) | `EffectSkillService.java` | `removeAllPhanThanClones(Player)` — `sendItemTime(player, 31142, 0)` |
| Tự động hết giờ | `server/src/nro/models/player/EffectSkill.java` | `update()` — kiểm tra `isPhanThan` |
| Class clone (AI + skin + stats) | `server/src/nro/models/player/PhanThanClone.java` | toàn bộ file |
| Skin clone (race-based) | `PhanThanClone.java` | `getCloneHead/Body/Leg()` — dùng `OUTFIT_BIEN_HINH[g][1]` |
| AI chủ động đánh | `PhanThanClone.java` | `idleAttackMob()` — phạm vi 400px, cooldown 2s |
| Mirror master attack | `SkillService.java` | `mirrorClonesAttack()` + `PhanThanClone.mirrorAttack()` |
| Mirror khi master đánh player/mob | `SkillService.java` | cuối `useSkillFocus()` — gọi `mirrorClonesAttack()` |
| Số clone theo cấp | `EffectSkillService.java` | `cloneCount = level * 2` (cấp 1=2, cấp 5=10) |
| Sức mạnh clone | `EffectSkillService.java` | `powerPct[] = {0,20,35,50,70,90}` |

---

## 🔧 File Deploy — Codespace

```
Codespace: cautious-space-halibut-p7rwgqwxrg5gfrrqg
Source:    /home/codespace/nro/SRC/src/
JAR:       /home/codespace/nro/SRC/NgocRongOnline.jar
Compile:   javac -cp "NgocRongOnline.jar:lib/*" -d /tmp/nro_out <files>
Update:    jar uf NgocRongOnline.jar -C /tmp/nro_out nro/
Restart:   pkill -9 -f NgocRongOnline; sleep 3; nohup java -Xms256m -Xmx1g -jar NgocRongOnline.jar >> ~/logs/server.log 2>&1 &
```

---

## 📌 sendItemTime — Icon ID đã xác nhận hoạt động

| Icon ID | Tên item | Dùng cho | Trạng thái |
|---|---|---|---|
| 3783 | Open Power | Biến Hình timer (600s) | ✅ confirmed |
| 5072 | DK item | Phân Thân timer (300s) | ✅ confirmed |
| 3784 | Khiên năng lượng | Khiên timer | ✅ confirmed |
| 3782 | Thôi miên | Sleep timer | ✅ confirmed |
| 3779 | Trói | Hold timer | ✅ confirmed |
| 2755 | Bổ huyết | HP buff timer | ✅ confirmed |
| 1995 | Cải trang (icon) | ❌ KHÔNG hoạt động trên client | ❌ |
| 31142 | Phân Thân (icon) | ❌ KHÔNG hoạt động trên client | ❌ |
| 433 | Cải trang Ginyu | Dùng ở chỗ khác trong EffectSkillService | ✅ |

---

## 📌 ConstPlayer.OUTFIT_BIEN_HINH — Outfit ID đã xác nhận

```
gender=0 (Trái Đất): cấp1={83,84,85} cấp2={86,87,88} cấp3={89,90,91} cấp4={92,93,94} cấp5={98,99,100}
gender=1 (Namec):    cấp1={123,124,125} cấp2={171,172,173} cấp3={174,175,176} cấp4={162,163,164} cấp5={159,160,161}
gender=2 (Saijan):   cấp1={77,78,79} cấp2={183,184,185} cấp3={186,187,188} cấp4={189,190,191} cấp5={310,307,308}
```
Clone dùng cấp 2 ([1]) — khác hẳn outfit thường của master.

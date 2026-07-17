# NRO Server Info

## Kết nối game
- **IP:** `159.223.110.159` (bore.pub)
- **Port:** `5798` (cố định)

## Tài khoản Admin
- **Username:** `admin`
- **Password:** `12345678`
- **Character:** memeiue (admin=99, is_admin=1)

## Cấu trúc Codespace
- JAR: `/home/codespace/nro/SRC/NgocRongOnline.jar`
- Config: `/home/codespace/nro/SRC/Config.properties`
- DB: `nro1` (MariaDB)
- Logs: `~/logs/`

## Khởi động server
```bash
sudo service mariadb start && sleep 3
/tmp/bore local 14445 --to bore.pub --port 5798 > ~/logs/bore.log 2>&1 &
sleep 6
cd /home/codespace/nro/SRC
nohup java -Xms256m -Xmx1g -jar NgocRongOnline.jar > ~/logs/server.log 2>&1 &
```

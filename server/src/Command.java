/*
 * Decompiled with CFR 0.152.
 */
package nro.models.server;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.BiConsumer;
import java.util.function.Consumer;
import nro.models.Bot.BotAttackplayer;
import nro.models.Bot.BotManager;
import nro.models.boss.Boss_Manager.BrolyManager;
import nro.models.boss.Boss_Manager.BossManager;
import nro.models.boss.Boss;
import nro.models.item.Item;
import nro.models.map.service.ChangeMapService;
import nro.models.map.service.NpcService;
import nro.models.network.SessionManager;
import nro.models.player.Player;
import nro.models.server.Client;
import nro.models.server.ServerManager;
import nro.models.server.ServerNotify;
import nro.models.services.InventoryService;
import nro.models.services.ItemService;
import nro.models.services.PetService;
import nro.models.services.PlayerService;
import nro.models.services.Service;
import nro.models.services.TaskService;
import nro.models.services_func.Input;
import nro.models.utils.SystemMetrics;

public class Command {
    private static Command instance;
    private final Map<String, Consumer<Player>> adminCommands = new HashMap<String, Consumer<Player>>();
    private final Map<String, BiConsumer<Player, String>> parameterizedCommands = new HashMap<String, BiConsumer<Player, String>>();

    public static Command gI() {
        if (instance == null) {
            instance = new Command();
        }
        return instance;
    }

    private Command() {
        this.initAdminCommands();
        this.initParameterizedCommands();
        this.initGbCommand();
    }

    private void initAdminCommands() {
        this.adminCommands.put("item", player -> Input.gI().createFormGiveItem((Player)player));
        this.adminCommands.put("brl", player -> BrolyManager.gI().showListBoss((Player)player));
        this.adminCommands.put("getitem", player -> Input.gI().createFormGetItem((Player)player));
        this.adminCommands.put("hs", player -> Service.gI().releaseCooldownSkill((Player)player));
        this.adminCommands.put("d", player -> Service.gI().setPos((Player)player, player.location.x, player.location.y + 10));
        this.adminCommands.put("a", player -> NpcService.gI().createMenuConMeo((Player)player, 512, -1, "|0|Time start: " + ServerManager.timeStart + "\nClients: " + Client.gI().getPlayers().size() + "\n Sessions: " + SessionManager.gI().getNumSession() + "\nThreads: " + Thread.activeCount() + " lu\u1ed3ng\n" + SystemMetrics.ToString(), "Ng\u1ecdc r\u1ed3ng", "\u0110\u1ec7 t\u1eed", "B\u1ea3o tr\u00ec", "T\u00ecm ki\u1ebfm\nng\u01b0\u1eddi ch\u01a1i", "Boss", "\u0110\u00f3ng"));
    }

    private void initParameterizedCommands() {
        this.parameterizedCommands.put("m", (player, text) -> {
            try {
                int mapId = Integer.parseInt(text.replace("m", "").trim());
                ChangeMapService.gI().changeMapInYard((Player)player, mapId, -1, -1);
            }
            catch (NumberFormatException e) {
                Service.gI().sendThongBao((Player)player, "Sai \u0111\u1ecbnh d\u1ea1ng map ID!");
            }
        });
        this.parameterizedCommands.put("toado", (player, text) -> Service.gI().sendThongBaoOK((Player)player, "x: " + player.location.x + " - y: " + player.location.y));
        this.parameterizedCommands.put("1", (player, text) -> NpcService.gI().createMenuConMeo((Player)player, 206783, 206783, "|7| Menu bot\nPlayer online : " + Client.gI().getPlayers().size() + "\n\b|1|Thread: " + Thread.activeCount() + "\n\n Sessions: " + SessionManager.gI().getNumSession() + "\nBot online : " + BotManager.gI().bot.size(), "Bot\nPem Qu\u00e1i", "Bot\nB\u00e1n Item", "Bot\nS\u0103n Boss", "Bot\nAttack Player"));
        this.parameterizedCommands.put("2", (player, text) -> {
            player.originalName = player.name;
            PlayerService.gI().changeAndSendTypePK((Player)player, 5);
            player.originalName = player.name;
            Service.gI().Send_Caitrang((Player)player);
            BotAttackplayer bot = new BotAttackplayer((short)1624, (short)1628, (short)1629, 1, "\u0111\u00e1nh nhau kh\u00f4ng?", (short)0);
            bot.player = player;
            bot.zone = player.zone;
            bot.location.x = player.location.x;
            bot.location.y = player.location.y;
            player.zone.addPlayer(bot);
            BotManager.gI().bot.add(bot);
            for (Player p : player.zone.getPlayers()) {
                if (p.session == null) continue;
                Service.gI().sendAppear(bot, p);
                Service.gI().sendInfoCharMoiToMe(p, bot);
            }
            if (player.session != null) {
                Service.gI().Send_Info_NV((Player)player);
            }
            bot.update();
            ServerNotify.gI().notify("\u0110\u00e3 g\u1ecdi bot t\u1ea5n c\u00f4ng ng\u01b0\u1eddi ch\u01a1i!");
        });
        this.parameterizedCommands.put("b", (player, text) -> Input.gI().createFormSenditem1((Player)player));
        this.parameterizedCommands.put("n", (player, text) -> {
            try {
                int idTask = Integer.parseInt(text.replaceAll("n", "").trim());
                player.playerTask.taskMain.id = idTask - 1;
                player.playerTask.taskMain.index = 0;
                TaskService.gI().sendNextTaskMain((Player)player);
            }
            catch (Exception e) {
                Service.gI().sendThongBao((Player)player, "Sai \u0111\u1ecbnh d\u1ea1ng task ID!");
            }
        });
        this.parameterizedCommands.put("i ", (player, text) -> {
            try {
                int i;
                String[] split = text.split(" ");
                if (split.length < 2) {
                    Service.gI().sendThongBao((Player)player, "C\u00fa ph\u00e1p: i <itemId> <s\u1ed1 l\u01b0\u1ee3ng> [option:value...]");
                    return;
                }
                int itemId = Integer.parseInt(split[1]);
                int quantity = split.length >= 3 ? Integer.parseInt(split[2]) : 1;
                ArrayList<Item.ItemOption> customOptions = new ArrayList<Item.ItemOption>();
                for (i = 3; i < split.length; ++i) {
                    if (!split[i].contains(":")) continue;
                    String[] optSplit = split[i].split(":");
                    int optionId = Integer.parseInt(optSplit[0]);
                    int optionValue = Integer.parseInt(optSplit[1]);
                    customOptions.add(new Item.ItemOption(optionId, optionValue));
                }
                for (i = 0; i < quantity; ++i) {
                    Item item = ItemService.gI().createNewItem((short)itemId);
                    if (!customOptions.isEmpty()) {
                        item.itemOptions = new ArrayList<Item.ItemOption>(customOptions);
                    } else {
                        List<Item.ItemOption> ops = ItemService.gI().getListOptionItemShop((short)itemId);
                        if (!ops.isEmpty()) {
                            item.itemOptions = ops;
                        }
                    }
                    InventoryService.gI().addItemBag((Player)player, item);
                }
                InventoryService.gI().sendItemBags((Player)player);
                Service.gI().sendThongBao((Player)player, "GET " + quantity + " x " + ItemService.gI().getTemplate((int)itemId).name + " [" + itemId + "] SUCCESS!");
            }
            catch (Exception e) {
                Service.gI().sendThongBao((Player)player, "L\u1ed7i c\u00fa ph\u00e1p! D\u00f9ng: i <itemId> <s\u1ed1 l\u01b0\u1ee3ng> [optionId:value]");
            }
        });
    }

    // === LỆNH GB: Gọi Boss vào map hiện tại ===
    private void initGbCommand() {
        this.parameterizedCommands.put("gb", (player, text) -> {
            try {
                String[] parts = text.trim().split("\\s+");
                int bossId = Integer.parseInt(parts[parts.length - 1]);
                Boss boss = BossManager.gI().createBoss(bossId);
                if (boss != null && player.zone != null) {
                    boss.zone = player.zone;
                    BossManager.gI().addBoss(boss);
                    Service.gI().sendThongBaoAllPlayer("Boss đã xuất hiện tại map " + player.zone.map.mapId + "!");
                } else {
                    Service.gI().sendThongBao(player, "Gọi boss thất bại hoặc bossId không hợp lệ: " + bossId);
                }
            } catch (Exception e) {
                Service.gI().sendThongBao(player, "Cú pháp: gb <bossId> | VD: gb -1822 (Broly), gb -322 (Tapsu)");
            }
        });
    }

    public void chat(Player player, String text) {
        String cleanedText = text.trim();
        if (cleanedText.isEmpty()) {
            return;
        }
        if (!this.check(player, cleanedText)) {
            Service.gI().chat(player, cleanedText);
        }
    }

    /*
     * WARNING - void declaration
     */
    public boolean check(Player player, String text) {
        if (player.isAdmin()) {
            if (this.adminCommands.containsKey(text)) {
                this.adminCommands.get(text).accept(player);
                return true;
            }
            for (Map.Entry entry : this.parameterizedCommands.entrySet()) {
                if (!text.startsWith((String)entry.getKey())) continue;
                ((BiConsumer)entry.getValue()).accept(player, text);
                return true;
            }
        }
        if (text.startsWith("ten con la ")) {
            PetService.gI().changeNamePet(player, text.replace("ten con la ", ""));
        }
        if (player.pet != null) {
            int var4_16 = -1;
            String string = text;
            if (string.equals("di theo")) { var4_16 = 0; }
            else if (string.equals("follow")) { var4_16 = 1; }
            else if (string.equals("bao ve")) { var4_16 = 2; }
            else if (string.equals("protect")) { var4_16 = 3; }
            else if (string.equals("tan cong")) { var4_16 = 4; }
            else if (string.equals("attack")) { var4_16 = 5; }
            else if (string.equals("ve nha")) { var4_16 = 6; }
            else if (string.equals("go home")) { var4_16 = 7; }
            else if (string.equals("bien hinh")) { var4_16 = 8; }
            else if (string.equals("sach tuyet ky")) { var4_16 = 9; }
            block12 : switch (var4_16) {
                case 0: 
                case 1: {
                    player.pet.changeStatus((byte)0);
                    break;
                }
                case 2: 
                case 3: {
                    player.pet.changeStatus((byte)1);
                    break;
                }
                case 4: 
                case 5: {
                    player.pet.changeStatus((byte)2);
                    break;
                }
                case 6: 
                case 7: {
                    player.pet.changeStatus((byte)3);
                    break;
                }
                case 8: {
                    player.pet.transform();
                    break;
                }
                case 9: {
                    byte typePet = player.pet.typePet;
                    if (typePet == 2 || typePet == 3 || typePet == 4) {
                        for (int i = 0; i < player.inventory.itemsBag.size(); ++i) {
                            Item item = player.inventory.itemsBag.get(i);
                            if (item == null || !item.isNotNullItem() || item.template.type != 25) continue;
                            if (player.pet.nPoint != null && player.pet.nPoint.power >= 1500000L) {
                                Item old = InventoryService.gI().putItemBody(player.pet, item);
                                player.inventory.itemsBag.set(i, old);
                                InventoryService.gI().sendItemBags(player);
                                InventoryService.gI().sendItemBody(player);
                                Service.gI().Send_Caitrang(player.pet);
                                Service.gI().Send_Caitrang(player);
                                Service.gI().sendThongBao(player, "\u0110\u00e3 d\u00f9ng " + item.template.name + " cho \u0111\u1ec7 t\u1eed");
                                break block12;
                            }
                            Service.gI().sendThongBaoOK(player, "\u0110\u1ec7 t\u1eed c\u1ea7n \u0111\u1ea1t 1tr5 s\u1ee9c m\u1ea1nh \u0111\u1ec3 trang b\u1ecb.");
                            break block12;
                        }
                        break;
                    }
                    Service.gI().sendThongBaoOK(player, "Ch\u1ec9 \u0111\u1ec7 t\u1eed (Uub, Kid Beerus, Jiren) m\u1edbi c\u00f3 th\u1ec3 d\u00f9ng s\u00e1ch tuy\u1ec7t k\u1ef9.");
                }
            }
        }
        return false;
    }
}

package nro.models.consts;

public class ConstPlayer {

    public static final int[] HEADMONKEY = {192, 195, 196, 199, 197, 200, 198};

    // Biến Hình outfit cho 3 nclass × 5 cấp: [nclass][level-1] = {head, body, leg}
    // nclass 0=Trái Đất, 1=Namec, 2=Saijan
    public static final short[][][] OUTFIT_BIEN_HINH = {
        // Trái Đất: cấp 1→5 (tăng dần sức mạnh)
        {{83,84,85}, {86,87,88}, {89,90,91}, {92,93,94}, {98,99,100}},
        // Namec: cấp 1→5
        {{123,124,125}, {171,172,173}, {174,175,176}, {162,163,164}, {159,160,161}},
        // Saijan: cấp 1→5
        {{77,78,79}, {183,184,185}, {186,187,188}, {189,190,191}, {310,307,308}}
    };

    public static final byte TRAI_DAT = 0;
    public static final byte NAMEC = 1;
    public static final byte XAYDA = 2;

    //type pk
    public static final byte NON_PK = 0;
    public static final byte PK_PVP = 3;
    public static final byte PK_PVP_2 = 4;
    public static final byte PK_ALL = 5;

    //type fushion
    public static final byte NON_FUSION = 0;
    public static final byte LUONG_LONG_NHAT_THE = 4;
    public static final byte HOP_THE_PORATA = 6;
    public static byte HOP_THE_PORATA2 = 8;
    public static byte HOP_THE_PORATA3 = 9;
    public static final byte HOP_THE_GOGETA = 10;
}

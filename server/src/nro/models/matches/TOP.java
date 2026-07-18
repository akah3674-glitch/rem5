package nro.models.matches;

import lombok.Builder;
import lombok.Data;
import nro.models.player.Player;

@Data
@Builder
public class TOP {

    private String name;
    private byte gender;
    private short head;
    private short body;
    private short leg;
    private long power;
    private long ki;
    private long hp;
    private long sd;
    private byte nv;
    private byte subnv;
    private int sk;
    private int pvp;
    private int nhs;
    private int dicanh;
    private int divdst;
    private int juventus;
    private long lasttime;
    private long time;
    private int level;
    private int cash;
    private int thoivang;
    private int id_player;
    private String info1;
    private String info2;
    private long paramCompare;
    
    // Manual getters/setters — Lombok @Data/@Builder không hoạt động với JDK 25 + -proc:none
    public String getName()       { return name; }
    public byte getGender()       { return gender; }
    public short getHead()        { return head; }
    public short getBody()        { return body; }
    public short getLeg()         { return leg; }
    public long getPower()        { return power; }
    public long getKi()           { return ki; }
    public long getHp()           { return hp; }
    public long getSd()           { return sd; }
    public byte getNv()           { return nv; }
    public byte getSubnv()        { return subnv; }
    public int getSk()            { return sk; }
    public int getPvp()           { return pvp; }
    public int getNhs()           { return nhs; }
    public int getDicanh()        { return dicanh; }
    public int getDivdst()        { return divdst; }
    public int getJuventus()      { return juventus; }
    public long getLasttime()     { return lasttime; }
    public long getTime()         { return time; }
    public int getLevel()         { return level; }
    public int getCash()          { return cash; }
    public int getThoivang()      { return thoivang; }
    public int getId_player()     { return id_player; }
    public String getInfo1()      { return info1; }
    public String getInfo2()      { return info2; }
    public long getParamCompare() { return paramCompare; }

    public void setId_player(int id_player)     { this.id_player = id_player; }
    public void setName(String name)            { this.name = name; }
    public void setGender(byte gender)          { this.gender = gender; }
    public void setHead(short head)             { this.head = head; }
    public void setBody(short body)             { this.body = body; }
    public void setLeg(short leg)               { this.leg = leg; }
    public void setPower(long power)            { this.power = power; }
    public void setKi(long ki)                  { this.ki = ki; }
    public void setHp(long hp)                  { this.hp = hp; }
    public void setSd(long sd)                  { this.sd = sd; }
    public void setNv(byte nv)                  { this.nv = nv; }
    public void setSubnv(byte subnv)            { this.subnv = subnv; }
    public void setSk(int sk)                   { this.sk = sk; }
    public void setPvp(int pvp)                 { this.pvp = pvp; }
    public void setNhs(int nhs)                 { this.nhs = nhs; }
    public void setDicanh(int dicanh)           { this.dicanh = dicanh; }
    public void setDivdst(int divdst)           { this.divdst = divdst; }
    public void setJuventus(int juventus)       { this.juventus = juventus; }
    public void setLasttime(long lasttime)       { this.lasttime = lasttime; }
    public void setTime(long time)              { this.time = time; }
    public void setLevel(int level)             { this.level = level; }
    public void setCash(int cash)               { this.cash = cash; }
    public void setThoivang(int thoivang)       { this.thoivang = thoivang; }
    public void setInfo1(String info1)          { this.info1 = info1; }
    public void setInfo2(String info2)          { this.info2 = info2; }
    public void setParamCompare(long p)         { this.paramCompare = p; }

    /** Manual @Builder replacement — tên TOPBuilder để match Lombok-compiled Manager.java */
    public static TOPBuilder builder() { return new TOPBuilder(); }
    public static class TOPBuilder {
        private TOP t = new TOP();
        public Builder name(String v)        { t.name = v; return this; }
        public Builder gender(byte v)        { t.gender = v; return this; }
        public Builder head(short v)         { t.head = v; return this; }
        public Builder body(short v)         { t.body = v; return this; }
        public Builder leg(short v)          { t.leg = v; return this; }
        public Builder power(long v)         { t.power = v; return this; }
        public Builder ki(long v)            { t.ki = v; return this; }
        public Builder hp(long v)            { t.hp = v; return this; }
        public Builder sd(long v)            { t.sd = v; return this; }
        public Builder nv(byte v)            { t.nv = v; return this; }
        public Builder subnv(byte v)         { t.subnv = v; return this; }
        public Builder sk(int v)             { t.sk = v; return this; }
        public Builder pvp(int v)            { t.pvp = v; return this; }
        public Builder nhs(int v)            { t.nhs = v; return this; }
        public Builder dicanh(int v)         { t.dicanh = v; return this; }
        public Builder divdst(int v)         { t.divdst = v; return this; }
        public Builder juventus(int v)       { t.juventus = v; return this; }
        public Builder lasttime(long v)      { t.lasttime = v; return this; }
        public Builder time(long v)          { t.time = v; return this; }
        public Builder level(int v)          { t.level = v; return this; }
        public Builder cash(int v)           { t.cash = v; return this; }
        public Builder thoivang(int v)       { t.thoivang = v; return this; }
        public Builder id_player(int v)      { t.id_player = v; return this; }
        public Builder info1(String v)       { t.info1 = v; return this; }
        public Builder info2(String v)       { t.info2 = v; return this; }
        public Builder paramCompare(long v)  { t.paramCompare = v; return this; }
        public TOP build()                   { return t; }
    }
}

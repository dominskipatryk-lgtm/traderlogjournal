//+------------------------------------------------------------------+
//|  SR_HighVolume_Boxes.mq4 v4                                      |
//|  + Panel sterowania (SUP / RES / VOL / SIG / BRK)               |
//+------------------------------------------------------------------+
#property copyright   "ChartPrime (MQL4 port v4)"
#property version     "4.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 4

input int    InpLookback  = 20;  // Lookback Period
input int    InpVolLen    = 2;   // Delta Volume Filter Length
input double InpBoxWidth  = 1.0; // Box Width (ATR multiplier)
input int    InpPanelX    = 5;   // Panel X (px od rogu)
input int    InpPanelY    = 25;  // Panel Y (px od rogu)
input int    InpPanelCorner = 0; // Rog panelu: 0=TL 1=BL 2=TR 3=BR

double BufSupHold[];
double BufResHold[];
double BufBrkSup[];
double BufBrkRes[];

// Prefixes: PFX = zone objects, PPFX = panel objects (not deleted on recalc)
#define PFX   "SR3Z_"
#define PPFX  "SR3P_"
#define MAXZ   50

// Panel button names
#define P_BG  PPFX"BG"
#define P_TIT PPFX"TIT"
#define P_SUP PPFX"SUP"
#define P_RES PPFX"RES"
#define P_VOL PPFX"VOL"
#define P_SIG PPFX"SIG"
#define P_BRK PPFX"BRK"

// Toggle states
bool g_showSup     = true;
bool g_showRes     = true;
bool g_showVol     = true;
bool g_showSig     = true;
bool g_showBrk     = true;
bool g_needRecalc  = false;

struct Zone
{
    string name;    // box rectangle name
    string volNm;   // volume text name
    string brkNm;   // break label name (empty until breakout)
    double hi;
    double lo;
    bool   isSup;
    bool   broken;
    int    pivBar;
    double vol;
};

Zone  gz[];
int   gnz       = 0;
int   g_lastSup = -1;
int   g_lastRes = -1;

//+------------------------------------------------------------------+
//  Panel helpers
//+------------------------------------------------------------------+
void MakeBtn(string nm, string txt, int x, int y, bool on)
{
    color bgc = on ? C'15,110,15' : C'65,65,65';
    color tc  = on ? clrWhite    : C'140,140,140';
    if (ObjectFind(0, nm) < 0)
    {
        ObjectCreate(0, nm, OBJ_BUTTON, 0, 0, 0);
        ObjectSetInteger(0, nm, OBJPROP_CORNER,     InpPanelCorner);
        ObjectSetInteger(0, nm, OBJPROP_XSIZE,      54);
        ObjectSetInteger(0, nm, OBJPROP_YSIZE,      19);
        ObjectSetInteger(0, nm, OBJPROP_FONTSIZE,   8);
        ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, nm, OBJPROP_HIDDEN,     true);
        ObjectSetInteger(0, nm, OBJPROP_ZORDER,     10);
    }
    ObjectSetString (0, nm, OBJPROP_TEXT,      txt);
    ObjectSetInteger(0, nm, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, nm, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, nm, OBJPROP_BGCOLOR,   bgc);
    ObjectSetInteger(0, nm, OBJPROP_COLOR,     tc);
    ObjectSetInteger(0, nm, OBJPROP_STATE,     false);
}

void DrawPanel()
{
    int px = InpPanelX, py = InpPanelY;
    int pw = 196, ph = 69;

    // Background rectangle
    if (ObjectFind(0, P_BG) < 0)
    {
        ObjectCreate(0, P_BG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, P_BG, OBJPROP_CORNER,      InpPanelCorner);
        ObjectSetInteger(0, P_BG, OBJPROP_XDISTANCE,   px);
        ObjectSetInteger(0, P_BG, OBJPROP_YDISTANCE,   py);
        ObjectSetInteger(0, P_BG, OBJPROP_XSIZE,       pw);
        ObjectSetInteger(0, P_BG, OBJPROP_YSIZE,       ph);
        ObjectSetInteger(0, P_BG, OBJPROP_BGCOLOR,     C'18,18,28');
        ObjectSetInteger(0, P_BG, OBJPROP_COLOR,       C'55,55,80');
        ObjectSetInteger(0, P_BG, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, P_BG, OBJPROP_WIDTH,       1);
        ObjectSetInteger(0, P_BG, OBJPROP_SELECTABLE,  false);
        ObjectSetInteger(0, P_BG, OBJPROP_HIDDEN,      true);
        ObjectSetInteger(0, P_BG, OBJPROP_ZORDER,      1);
    }

    // Title label
    if (ObjectFind(0, P_TIT) < 0)
    {
        ObjectCreate(0, P_TIT, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, P_TIT, OBJPROP_CORNER,     InpPanelCorner);
        ObjectSetInteger(0, P_TIT, OBJPROP_XDISTANCE,  px + 8);
        ObjectSetInteger(0, P_TIT, OBJPROP_YDISTANCE,  py + 8);
        ObjectSetInteger(0, P_TIT, OBJPROP_FONTSIZE,   8);
        ObjectSetInteger(0, P_TIT, OBJPROP_COLOR,      C'150,150,200');
        ObjectSetInteger(0, P_TIT, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, P_TIT, OBJPROP_HIDDEN,     true);
        ObjectSetInteger(0, P_TIT, OBJPROP_ZORDER,     5);
        ObjectSetString (0, P_TIT, OBJPROP_TEXT,       "SR High Volume Boxes");
    }

    // Row 1: SUP  RES  VOL    (y = py+28)
    int ry1 = py + 28, ry2 = py + 50;
    int bx1 = px+4, bx2 = px+62, bx3 = px+120;

    MakeBtn(P_SUP, g_showSup?"SUP ON":"SUP OFF", bx1, ry1, g_showSup);
    MakeBtn(P_RES, g_showRes?"RES ON":"RES OFF", bx2, ry1, g_showRes);
    MakeBtn(P_VOL, g_showVol?"VOL ON":"VOL OFF", bx3, ry1, g_showVol);

    // Row 2: SIG  BRK
    MakeBtn(P_SIG, g_showSig?"SIG ON":"SIG OFF", bx1, ry2, g_showSig);
    MakeBtn(P_BRK, g_showBrk?"BRK ON":"BRK OFF", bx2, ry2, g_showBrk);
}

void RefreshBtn(string nm, bool on)
{
    ObjectSetInteger(0, nm, OBJPROP_BGCOLOR, on ? C'15,110,15' : C'65,65,65');
    ObjectSetInteger(0, nm, OBJPROP_COLOR,   on ? clrWhite : C'140,140,140');
    string t = "";
    if      (nm == P_SUP) t = on ? "SUP ON" : "SUP OFF";
    else if (nm == P_RES) t = on ? "RES ON" : "RES OFF";
    else if (nm == P_VOL) t = on ? "VOL ON" : "VOL OFF";
    else if (nm == P_SIG) t = on ? "SIG ON" : "SIG OFF";
    else if (nm == P_BRK) t = on ? "BRK ON" : "BRK OFF";
    if (t != "") ObjectSetString(0, nm, OBJPROP_TEXT, t);
    ObjectSetInteger(0, nm, OBJPROP_STATE, false);
}

//+------------------------------------------------------------------+
//  Show / hide chart objects
//+------------------------------------------------------------------+
void HideObj(string nm) { if(ObjectFind(0,nm)>=0) ObjectDelete(0,nm); }

void ApplyVisibility()
{
    for (int z = 0; z < gnz; z++)
    {
        bool show = gz[z].isSup ? g_showSup : g_showRes;
        if (!show)
        {
            ObjectDelete(0, gz[z].name);
            ObjectDelete(0, gz[z].volNm);
            if (gz[z].brkNm != "") ObjectDelete(0, gz[z].brkNm);
        }
        else
        {
            if (!g_showVol) ObjectDelete(0, gz[z].volNm);
            if (!g_showBrk && gz[z].brkNm != "") ObjectDelete(0, gz[z].brkNm);
        }
    }

    if (!g_showSig)
    {
        ArrayInitialize(BufSupHold, EMPTY_VALUE);
        ArrayInitialize(BufResHold, EMPTY_VALUE);
        ArrayInitialize(BufBrkSup,  EMPTY_VALUE);
        ArrayInitialize(BufBrkRes,  EMPTY_VALUE);
    }

    g_needRecalc = true;
}

//+------------------------------------------------------------------+
//  Chart event — button clicks
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if (id != CHARTEVENT_OBJECT_CLICK) return;

    bool changed = false;
    if      (sparam == P_SUP) { g_showSup = !g_showSup; RefreshBtn(P_SUP, g_showSup); changed = true; }
    else if (sparam == P_RES) { g_showRes = !g_showRes; RefreshBtn(P_RES, g_showRes); changed = true; }
    else if (sparam == P_VOL) { g_showVol = !g_showVol; RefreshBtn(P_VOL, g_showVol); changed = true; }
    else if (sparam == P_SIG) { g_showSig = !g_showSig; RefreshBtn(P_SIG, g_showSig); changed = true; }
    else if (sparam == P_BRK) { g_showBrk = !g_showBrk; RefreshBtn(P_BRK, g_showBrk); changed = true; }

    if (changed) { ApplyVisibility(); ChartRedraw(0); }
}

//+------------------------------------------------------------------+
//  OnInit / OnDeinit
//+------------------------------------------------------------------+
int OnInit()
{
    gnz = 0; g_lastSup = -1; g_lastRes = -1;
    ArrayResize(gz, 0);

    SetIndexBuffer(0, BufSupHold);
    SetIndexStyle (0, DRAW_ARROW, EMPTY, 2, clrLime);
    SetIndexArrow (0, 233);
    SetIndexLabel (0, "Support Holds");

    SetIndexBuffer(1, BufResHold);
    SetIndexStyle (1, DRAW_ARROW, EMPTY, 2, clrRed);
    SetIndexArrow (1, 234);
    SetIndexLabel (1, "Resistance Holds");

    SetIndexBuffer(2, BufBrkSup);
    SetIndexStyle (2, DRAW_ARROW, EMPTY, 2, clrOrangeRed);
    SetIndexArrow (2, 234);
    SetIndexLabel (2, "Break Support");

    SetIndexBuffer(3, BufBrkRes);
    SetIndexStyle (3, DRAW_ARROW, EMPTY, 2, clrSpringGreen);
    SetIndexArrow (3, 233);
    SetIndexLabel (3, "Break Resistance");

    ArrayInitialize(BufSupHold, EMPTY_VALUE);
    ArrayInitialize(BufResHold, EMPTY_VALUE);
    ArrayInitialize(BufBrkSup,  EMPTY_VALUE);
    ArrayInitialize(BufBrkRes,  EMPTY_VALUE);

    DrawPanel();
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    ObjectsDeleteAll(0, PFX);
    ObjectsDeleteAll(0, PPFX);
    ArrayResize(gz, 0);
    gnz = 0; g_lastSup = -1; g_lastRes = -1;
}

//+------------------------------------------------------------------+
//  Zone helpers
//+------------------------------------------------------------------+
double DV(int b)
{
    if (Close[b] > Open[b]) return  (double)Volume[b];
    if (Close[b] < Open[b]) return -(double)Volume[b];
    return 0.0;
}
double VH(int s) { double h=-1e38; for(int i=s;i<s+InpVolLen&&i<Bars;i++){double v=DV(i)/2.5;if(v>h)h=v;} return h; }
double VL(int s) { double l=1e38;  for(int i=s;i<s+InpVolLen&&i<Bars;i++){double v=DV(i)/2.5;if(v<l)l=v;} return l; }

bool PivH(int b)
{
    if(b<InpLookback||b+InpLookback>=Bars) return false;
    for(int i=1;i<=InpLookback;i++) if(High[b-i]>=High[b]||High[b+i]>=High[b]) return false;
    return true;
}
bool PivL(int b)
{
    if(b<InpLookback||b+InpLookback>=Bars) return false;
    for(int i=1;i<=InpLookback;i++) if(Low[b-i]<=Low[b]||Low[b+i]<=Low[b]) return false;
    return true;
}
bool HasZ(string nm) { for(int i=0;i<gnz;i++) if(gz[i].name==nm) return true; return false; }

void MakeRect(string nm, datetime t1, datetime t2, double hi, double lo, color bdr, color fill)
{
    if(ObjectFind(0,nm)<0)
    {
        ObjectCreate(0,nm,OBJ_RECTANGLE,0,t1,hi,t2,lo);
        ObjectSetInteger(0,nm,OBJPROP_FILL,true);
        ObjectSetInteger(0,nm,OBJPROP_BACK,true);
        ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
        ObjectSetInteger(0,nm,OBJPROP_HIDDEN,true);
        ObjectSetInteger(0,nm,OBJPROP_WIDTH,1);
    }
    ObjectSetInteger(0,nm,OBJPROP_COLOR,  bdr);
    ObjectSetInteger(0,nm,OBJPROP_BGCOLOR,fill);
    ObjectSetInteger(0,nm,OBJPROP_STYLE,  STYLE_SOLID);
    ObjectMove(0,nm,0,t1,hi);
    ObjectMove(0,nm,1,t2,lo);
}
void SetRect(string nm, color bdr, color fill, bool dashed)
{
    if(ObjectFind(0,nm)<0) return;
    ObjectSetInteger(0,nm,OBJPROP_COLOR,  bdr);
    ObjectSetInteger(0,nm,OBJPROP_BGCOLOR,fill);
    ObjectSetInteger(0,nm,OBJPROP_STYLE,  dashed?STYLE_DASH:STYLE_SOLID);
}
void ExtRight(string nm, datetime t2)
{
    if(ObjectFind(0,nm)<0) return;
    double p=ObjectGetDouble(0,nm,OBJPROP_PRICE,1);
    ObjectMove(0,nm,1,t2,p);
}
void MakeText(string nm, datetime t, double price, string txt, color col, int anchor)
{
    if(ObjectFind(0,nm)>=0) return;
    ObjectCreate(0,nm,OBJ_TEXT,0,t,price);
    ObjectSetString (0,nm,OBJPROP_TEXT,      txt);
    ObjectSetInteger(0,nm,OBJPROP_COLOR,     col);
    ObjectSetInteger(0,nm,OBJPROP_FONTSIZE,  8);
    ObjectSetInteger(0,nm,OBJPROP_ANCHOR,    anchor);
    ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
    ObjectSetInteger(0,nm,OBJPROP_HIDDEN,    true);
    ObjectSetInteger(0,nm,OBJPROP_BACK,      false);
}

//+------------------------------------------------------------------+
//  OnCalculate
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[], const double &close[],
                const long &tick_volume[], const long &volume[], const int &spread[])
{
    bool full = (prev_calculated == 0) || g_needRecalc;
    if (g_needRecalc) g_needRecalc = false;

    if (full)
    {
        ObjectsDeleteAll(0, PFX);
        ArrayResize(gz, 0);
        gnz = 0; g_lastSup = -1; g_lastRes = -1;
        ArrayInitialize(BufSupHold, EMPTY_VALUE);
        ArrayInitialize(BufResHold, EMPTY_VALUE);
        ArrayInitialize(BufBrkSup,  EMPTY_VALUE);
        ArrayInitialize(BufBrkRes,  EMPTY_VALUE);
    }

    double atr = iATR(NULL, 0, 200, 0);
    double wd  = atr * InpBoxWidth;
    if (wd <= 0.0) return rates_total;

    int maxBar = Bars - 2*InpLookback - 2;
    if (maxBar < 1) return rates_total;

    int startBar = full ? maxBar
                        : MathMin(rates_total - prev_calculated + 2*InpLookback + 2, maxBar);

    for (int bar = startBar; bar >= 1; bar--)
    {
        int pb = bar + InpLookback;
        if (pb + InpLookback >= Bars) continue;

        double v  = DV(bar);
        double vh = VH(bar);
        double vl = VL(bar);

        //--- Support zone
        if (PivL(pb) && v > vh && gnz < MAXZ)
        {
            string nm = PFX + "S" + IntegerToString(pb);
            if (!HasZ(nm))
            {
                double zH = Low[pb], zL = zH - wd;
                string vnm = PFX + "VS" + IntegerToString(pb);

                MakeRect(nm, Time[pb], Time[bar], zH, zL, C'0,160,0', C'100,210,100');
                MakeText(vnm, Time[pb]+(datetime)PeriodSeconds(), zH-wd*0.05,
                         "Vol: "+DoubleToString(MathAbs(v),2), C'0,80,0', 7);

                if (!g_showSup) { ObjectDelete(0,nm); ObjectDelete(0,vnm); }
                else if (!g_showVol) ObjectDelete(0,vnm);

                ArrayResize(gz, gnz+1);
                gz[gnz].name  = nm;   gz[gnz].volNm = vnm; gz[gnz].brkNm = "";
                gz[gnz].hi=zH; gz[gnz].lo=zL; gz[gnz].isSup=true;
                gz[gnz].broken=false; gz[gnz].pivBar=pb; gz[gnz].vol=v;
                g_lastSup = gnz;
                gnz++;
            }
        }

        //--- Resistance zone
        if (PivH(pb) && v < vl && gnz < MAXZ)
        {
            string nm = PFX + "R" + IntegerToString(pb);
            if (!HasZ(nm))
            {
                double zL = High[pb], zH = zL + wd;
                string vnm = PFX + "VR" + IntegerToString(pb);

                MakeRect(nm, Time[pb], Time[bar], zH, zL, C'200,0,0', C'230,150,150');
                MakeText(vnm, Time[pb]+(datetime)PeriodSeconds(), zL+wd*0.05,
                         "Vol: "+DoubleToString(MathAbs(v),2), C'120,0,0', 3);

                if (!g_showRes) { ObjectDelete(0,nm); ObjectDelete(0,vnm); }
                else if (!g_showVol) ObjectDelete(0,vnm);

                ArrayResize(gz, gnz+1);
                gz[gnz].name  = nm;   gz[gnz].volNm = vnm; gz[gnz].brkNm = "";
                gz[gnz].hi=zH; gz[gnz].lo=zL; gz[gnz].isSup=false;
                gz[gnz].broken=false; gz[gnz].pivBar=pb; gz[gnz].vol=v;
                g_lastRes = gnz;
                gnz++;
            }
        }

        // Extend only the latest active zone of each type
        if (g_lastSup >= 0) ExtRight(gz[g_lastSup].name, Time[bar]);
        if (g_lastRes >= 0) ExtRight(gz[g_lastRes].name, Time[bar]);

        //--- Breakout / retest for all zones
        for (int z = 0; z < gnz; z++)
        {
            if (gz[z].isSup)
            {
                double sH=gz[z].hi, sL=gz[z].lo;
                bool brk=(High[bar]<sL)&&(High[bar+1]>=sL);
                bool hld=(Low[bar]>sH) &&(Low[bar+1]<=sH);

                if (brk && !gz[z].broken)
                {
                    gz[z].broken=true;
                    SetRect(gz[z].name, C'200,0,0', C'200,120,120', true);
                    if (g_showSig) BufBrkSup[bar]=High[bar]+wd*0.3;

                    string bnm=PFX+"BS"+IntegerToString(gz[z].pivBar);
                    gz[z].brkNm=bnm;
                    if (g_showBrk)
                        MakeText(bnm, Time[bar], sH+wd*0.5, "Break Sup", clrOrangeRed, 3);
                }
                else if (hld)
                {
                    gz[z].broken=false;
                    SetRect(gz[z].name, C'0,160,0', C'100,210,100', false);
                    if (g_showSig) BufSupHold[bar]=Low[bar]-wd*0.3;
                }
            }
            else
            {
                double rH=gz[z].hi, rL=gz[z].lo;
                bool brk=(Low[bar]>rH) &&(Low[bar+1]<=rH);
                bool hld=(High[bar]<rL)&&(High[bar+1]>=rL);

                if (brk && !gz[z].broken)
                {
                    gz[z].broken=true;
                    SetRect(gz[z].name, C'0,160,0', C'120,210,120', true);
                    if (g_showSig) BufBrkRes[bar]=Low[bar]-wd*0.3;

                    string bnm=PFX+"BR"+IntegerToString(gz[z].pivBar);
                    gz[z].brkNm=bnm;
                    if (g_showBrk)
                        MakeText(bnm, Time[bar], rL-wd*0.5, "Break Res", clrSpringGreen, 7);
                }
                else if (hld)
                {
                    gz[z].broken=false;
                    SetRect(gz[z].name, C'200,0,0', C'230,150,150', false);
                    if (g_showSig) BufResHold[bar]=High[bar]+wd*0.3;
                }
            }
        }
    }

    datetime extTime = Time[0] + (datetime)(PeriodSeconds()*2);
    if (g_lastSup >= 0) ExtRight(gz[g_lastSup].name, extTime);
    if (g_lastRes >= 0) ExtRight(gz[g_lastRes].name, extTime);

    return rates_total;
}

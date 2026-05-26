//+------------------------------------------------------------------+
//|  SR_HighVolume_Boxes.mq4 v3                                      |
//|  Support & Resistance High Volume Boxes                          |
//+------------------------------------------------------------------+
#property copyright   "ChartPrime (MQL4 port)"
#property version     "3.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 4

input int    InpLookback = 20;  // Lookback Period
input int    InpVolLen   = 2;   // Delta Volume Filter Length
input double InpBoxWidth = 1.0; // Box Width (ATR multiplier)

double BufSupHold[];
double BufResHold[];
double BufBrkSup[];
double BufBrkRes[];

#define PFX   "SR3Z_"
#define MAXZ   50

struct Zone
{
    string name;
    string volNm;
    string brkNm;
    double hi, lo;
    bool   isSup, broken;
    int    pivBar;
    double vol;
};

Zone  gz[];
int   gnz       = 0;
int   g_lastSup = -1;
int   g_lastRes = -1;

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

    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    ObjectsDeleteAll(0, PFX);
    ArrayResize(gz, 0);
    gnz = 0; g_lastSup = -1; g_lastRes = -1;
}

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
    if (b < InpLookback || b + InpLookback >= Bars) return false;
    for (int i = 1; i <= InpLookback; i++)
        if (High[b-i] >= High[b] || High[b+i] >= High[b]) return false;
    return true;
}
bool PivL(int b)
{
    if (b < InpLookback || b + InpLookback >= Bars) return false;
    for (int i = 1; i <= InpLookback; i++)
        if (Low[b-i] <= Low[b] || Low[b+i] <= Low[b]) return false;
    return true;
}

bool HasZ(string nm) { for(int i=0;i<gnz;i++) if(gz[i].name==nm) return true; return false; }

void MakeRect(string nm, datetime t1, datetime t2, double hi, double lo, color bdr, color fill)
{
    if (ObjectFind(0, nm) < 0)
    {
        ObjectCreate(0, nm, OBJ_RECTANGLE, 0, t1, hi, t2, lo);
        ObjectSetInteger(0, nm, OBJPROP_FILL,       true);
        ObjectSetInteger(0, nm, OBJPROP_BACK,       true);
        ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, nm, OBJPROP_HIDDEN,     true);
        ObjectSetInteger(0, nm, OBJPROP_WIDTH,      1);
    }
    ObjectSetInteger(0, nm, OBJPROP_COLOR,  bdr);
    ObjectSetInteger(0, nm, OBJPROP_BGCOLOR, fill);
    ObjectSetInteger(0, nm, OBJPROP_STYLE,  STYLE_SOLID);
    ObjectMove(0, nm, 0, t1, hi);
    ObjectMove(0, nm, 1, t2, lo);
}

void SetRect(string nm, color bdr, color fill, bool dashed)
{
    if (ObjectFind(0, nm) < 0) return;
    ObjectSetInteger(0, nm, OBJPROP_COLOR,  bdr);
    ObjectSetInteger(0, nm, OBJPROP_BGCOLOR, fill);
    ObjectSetInteger(0, nm, OBJPROP_STYLE,  dashed ? STYLE_DASH : STYLE_SOLID);
}

void ExtRight(string nm, datetime t2)
{
    if (ObjectFind(0, nm) < 0) return;
    double p = ObjectGetDouble(0, nm, OBJPROP_PRICE, 1);
    ObjectMove(0, nm, 1, t2, p);
}

void MakeText(string nm, datetime t, double price, string txt, color col, int anchor)
{
    if (ObjectFind(0, nm) >= 0) return;
    ObjectCreate(0, nm, OBJ_TEXT, 0, t, price);
    ObjectSetString (0, nm, OBJPROP_TEXT,       txt);
    ObjectSetInteger(0, nm, OBJPROP_COLOR,      col);
    ObjectSetInteger(0, nm, OBJPROP_FONTSIZE,   8);
    ObjectSetInteger(0, nm, OBJPROP_ANCHOR,     anchor);
    ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, nm, OBJPROP_HIDDEN,     true);
    ObjectSetInteger(0, nm, OBJPROP_BACK,       false);
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[], const double &close[],
                const long &tick_volume[], const long &volume[], const int &spread[])
{
    bool full = (prev_calculated == 0);

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
                MakeRect(nm,  Time[pb], Time[bar], zH, zL, C'0,160,0', C'100,210,100');
                MakeText(vnm, Time[pb] + (datetime)PeriodSeconds(), zH - wd*0.05,
                         "Vol: " + DoubleToString(MathAbs(v), 2), C'0,80,0', 7);
                ArrayResize(gz, gnz + 1);
                gz[gnz].name   = nm;  gz[gnz].volNm = vnm; gz[gnz].brkNm = "";
                gz[gnz].hi     = zH;  gz[gnz].lo    = zL;
                gz[gnz].isSup  = true; gz[gnz].broken = false;
                gz[gnz].pivBar = pb;  gz[gnz].vol   = v;
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
                MakeRect(nm,  Time[pb], Time[bar], zH, zL, C'200,0,0', C'230,150,150');
                MakeText(vnm, Time[pb] + (datetime)PeriodSeconds(), zL + wd*0.05,
                         "Vol: " + DoubleToString(MathAbs(v), 2), C'120,0,0', 3);
                ArrayResize(gz, gnz + 1);
                gz[gnz].name   = nm;  gz[gnz].volNm = vnm; gz[gnz].brkNm = "";
                gz[gnz].hi     = zH;  gz[gnz].lo    = zL;
                gz[gnz].isSup  = false; gz[gnz].broken = false;
                gz[gnz].pivBar = pb;  gz[gnz].vol   = v;
                g_lastRes = gnz;
                gnz++;
            }
        }

        if (g_lastSup >= 0) ExtRight(gz[g_lastSup].name, Time[bar]);
        if (g_lastRes >= 0) ExtRight(gz[g_lastRes].name, Time[bar]);

        //--- Breakout / retest
        for (int z = 0; z < gnz; z++)
        {
            if (gz[z].isSup)
            {
                double sH = gz[z].hi, sL = gz[z].lo;
                bool brk = (High[bar] < sL) && (High[bar+1] >= sL);
                bool hld = (Low[bar]  > sH) && (Low[bar+1]  <= sH);
                if (brk && !gz[z].broken)
                {
                    gz[z].broken = true;
                    SetRect(gz[z].name, C'200,0,0', C'200,120,120', true);
                    BufBrkSup[bar] = High[bar] + wd*0.3;
                    string bnm = PFX + "BS" + IntegerToString(gz[z].pivBar);
                    gz[z].brkNm = bnm;
                    MakeText(bnm, Time[bar], sH + wd*0.5, "Break Sup", clrOrangeRed, 3);
                }
                else if (hld)
                {
                    gz[z].broken = false;
                    SetRect(gz[z].name, C'0,160,0', C'100,210,100', false);
                    BufSupHold[bar] = Low[bar] - wd*0.3;
                }
            }
            else
            {
                double rH = gz[z].hi, rL = gz[z].lo;
                bool brk = (Low[bar]  > rH) && (Low[bar+1] <= rH);
                bool hld = (High[bar] < rL) && (High[bar+1] >= rL);
                if (brk && !gz[z].broken)
                {
                    gz[z].broken = true;
                    SetRect(gz[z].name, C'0,160,0', C'120,210,120', true);
                    BufBrkRes[bar] = Low[bar] - wd*0.3;
                    string bnm = PFX + "BR" + IntegerToString(gz[z].pivBar);
                    gz[z].brkNm = bnm;
                    MakeText(bnm, Time[bar], rL - wd*0.5, "Break Res", clrSpringGreen, 7);
                }
                else if (hld)
                {
                    gz[z].broken = false;
                    SetRect(gz[z].name, C'200,0,0', C'230,150,150', false);
                    BufResHold[bar] = High[bar] + wd*0.3;
                }
            }
        }
    }

    datetime extTime = Time[0] + (datetime)(PeriodSeconds() * 2);
    if (g_lastSup >= 0) ExtRight(gz[g_lastSup].name, extTime);
    if (g_lastRes >= 0) ExtRight(gz[g_lastRes].name, extTime);

    return rates_total;
}

//+------------------------------------------------------------------+
//|  IOFlow_StrengthClassifier.mq4                                   |
//|  MQL4 | Order Flow Strength Classifier | Panel z przełącznikami  |
//+------------------------------------------------------------------+
#property copyright "TraderLogJournal"
#property link      "https://traderlogjournal.com"
#property version   "1.00"
#property strict
#property indicator_chart_window

//── Inputs ──────────────────────────────────────────────────────────
input string  _OB           = "══ Order Block Settings ══";
input int     PivotLen      = 5;             // Pivot Lookback
input int     MaxOBs        = 5;             // Max widocznych OB

input string  _VIS          = "══ Visualization ══";
input color   BullColor     = C'8,153,129';  // Kolor Bullish OB
input color   BearColor     = C'242,54,69';  // Kolor Bearish OB
input bool    HideOverlap   = true;          // Ukryj nakładające się
input bool    ShowLabelsDef = true;          // Pokaż etykiety siły
input bool    ShowStrongDef = true;          // Pokaż najsilniejszy OB
input int     BufferSize    = 5;             // Bufor najsilniejszego OB

input string  _PNL          = "══ Panel ══";
input int     PanelX        = 20;            // Pozycja X panelu
input int     PanelY        = 30;            // Pozycja Y panelu

//── Defines ─────────────────────────────────────────────────────────
#define MAX_OB   500
#define P        "IOFC_"
#define P_BULL   P"BtnBull"
#define P_BEAR   P"BtnBear"
#define P_LBL    P"BtnLbl"
#define P_STR    P"BtnStr"
#define P_OVLP   P"BtnOvlp"
#define P_RESET  P"BtnReset"

//── OB struct ───────────────────────────────────────────────────────
struct OB {
   double   top, btm;
   datetime t0;
   double   str;
   bool     bull;
   bool     mit;
};

//── Globals ─────────────────────────────────────────────────────────
OB   g_ob[MAX_OB];
int  g_n     = 0;

double g_hi    = EMPTY_VALUE;
double g_lo    = EMPTY_VALUE;
int    g_hi_i  = -1;
int    g_lo_i  = -1;
double g_prevC = EMPTY_VALUE;
bool   g_reset = false;

bool   g_bull  = true;
bool   g_bear  = true;
bool   g_lbl   = true;
bool   g_str   = true;
bool   g_ovlp  = true;

// Tracked draw objects (do czyszczenia bez usuwania panelu)
string g_dObjs[MAX_OB * 3];
int    g_dCnt  = 0;

//+------------------------------------------------------------------+
int OnInit() {
   g_bull  = true;
   g_bear  = true;
   g_lbl   = ShowLabelsDef;
   g_str   = ShowStrongDef;
   g_ovlp  = HideOverlap;
   g_reset = false;
   ClearState();
   CreatePanel();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { DelAll(); }

void ClearState() {
   g_n = 0; g_hi = EMPTY_VALUE; g_lo = EMPTY_VALUE;
   g_hi_i = -1; g_lo_i = -1; g_prevC = EMPTY_VALUE;
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calc,
                const datetime &time[], const double &open[],
                const double &high[],  const double &low[],
                const double &close[], const long &tick_vol[],
                const long &volume[],  const int &spread[]) {

   if (rates_total < PivotLen * 2 + 5) return 0;

   bool full = (prev_calc == 0 || g_reset);
   if (full) { ClearState(); g_reset = false; ClearDrawObjs(); }

   int start = full ? PivotLen * 2 : MathMax(prev_calc - 1, PivotLen * 2);

   for (int i = start; i < rates_total; i++) {

      // Pivot detection
      int pb = i - PivotLen;
      if (pb >= PivotLen) {
         double ph = PivHigh(high, pb, PivotLen, rates_total);
         double pl = PivLow (low,  pb, PivotLen, rates_total);
         if (ph > 0) { g_hi = ph; g_hi_i = pb; }
         if (pl > 0) { g_lo = pl; g_lo_i = pb; }
      }

      // BOS detection
      double c = close[i];
      if (g_prevC == EMPTY_VALUE) { g_prevC = c; continue; }
      bool bBOS = (g_hi != EMPTY_VALUE && g_prevC <= g_hi && c > g_hi);
      bool sBOS = (g_lo != EMPTY_VALUE && g_prevC >= g_lo && c < g_lo);
      g_prevC = c;

      if (bBOS || sBOS) {
         int   ref  = bBOS ? g_hi_i : g_lo_i;
         int   slen = i - ref;
         double oT = EMPTY_VALUE, oB = EMPTY_VALUE;
         int    oI = -1; double oV = 0;

         if (bBOS) {
            double minL = EMPTY_VALUE;
            for (int s = 1; s <= slen; s++) {
               int bi = i - s; if (bi < 0) break;
               if (close[bi] < open[bi] && (minL == EMPTY_VALUE || low[bi] < minL)) {
                  minL = low[bi]; oT = high[bi]; oB = low[bi]; oI = bi; oV = (double)tick_vol[bi];
               }
            }
            g_hi = EMPTY_VALUE;
         } else {
            double maxH = EMPTY_VALUE;
            for (int s = 1; s <= slen; s++) {
               int bi = i - s; if (bi < 0) break;
               if (close[bi] > open[bi] && (maxH == EMPTY_VALUE || high[bi] > maxH)) {
                  maxH = high[bi]; oT = high[bi]; oB = low[bi]; oI = bi; oV = (double)tick_vol[bi];
               }
            }
            g_lo = EMPTY_VALUE;
         }

         if (oI >= 0 && oT != EMPTY_VALUE && g_n < MAX_OB) {
            double vS = VolSMA(tick_vol, oI, 20);
            double rV = (vS > 0) ? oV / vS : 1.0;
            double oH = oT - oB;
            double bd = bBOS ? (c - oT) : (oB - c);
            if (bd < 0) bd = 0;
            g_ob[g_n].top = oT; g_ob[g_n].btm = oB; g_ob[g_n].t0 = time[oI];
            g_ob[g_n].str = Str(oH, bd, rV); g_ob[g_n].bull = bBOS; g_ob[g_n].mit = false;
            g_n++;
         }
      }

      // Mitigation
      for (int k = 0; k < g_n; k++) {
         if (g_ob[k].mit) continue;
         if ( g_ob[k].bull && low[i]  < g_ob[k].btm) g_ob[k].mit = true;
         if (!g_ob[k].bull && high[i] > g_ob[k].top) g_ob[k].mit = true;
      }
   }

   // Kompaktowanie gdy za dużo wpisów
   if (g_n > 400) CompactOBs();

   DrawAll();
   return rates_total;
}

//+------------------------------------------------------------------+
// RYSOWANIE
//+------------------------------------------------------------------+
void DrawAll() {
   ClearDrawObjs();
   datetime rE = TimeCurrent() + (datetime)(PeriodSeconds() * 5);

   // Najsilniejszy OB
   double sT = EMPTY_VALUE, sB = EMPTY_VALUE;
   bool   sBl = false; double maxS = -1.0; int chk = 0;
   for (int k = g_n - 1; k >= 0; k--) {
      if (g_ob[k].mit) continue;
      if (g_ob[k].str > maxS) { maxS = g_ob[k].str; sT = g_ob[k].top; sB = g_ob[k].btm; sBl = g_ob[k].bull; }
      if (++chk >= BufferSize) break;
   }
   if (g_str && sT != EMPTY_VALUE) {
      color sc = sBl ? BullColor : BearColor;
      datetime t0 = (datetime)iTime(NULL, 0, Bars - 1);
      Track(MkRect(P"StrFill", t0, sT, rE, sB, sc, 1, true));
      Track(MkLine(P"StrMid",  t0, (sT+sB)/2.0, rE, (sT+sB)/2.0, sc, 2, STYLE_DASH));
   }

   // Order Blocks
   double occT[50], occB[50]; int occN = 0, drawn = 0;
   for (int k = g_n - 1; k >= 0 && drawn < MaxOBs; k--) {
      if (g_ob[k].mit)               continue;
      if (!g_bull &&  g_ob[k].bull)  continue;
      if (!g_bear && !g_ob[k].bull)  continue;
      if (g_ovlp && IsOverlap(g_ob[k].top, g_ob[k].btm, occT, occB, occN)) continue;
      if (occN < 50) { occT[occN] = g_ob[k].top; occB[occN] = g_ob[k].btm; occN++; }
      drawn++;
      color oc = g_ob[k].bull ? BullColor : BearColor;
      string suf = IntegerToString(k);
      Track(MkRect(P"Box_"+suf, g_ob[k].t0, g_ob[k].top, rE, g_ob[k].btm, oc, 1, true));
      if (g_lbl) {
         double mp = (g_ob[k].top + g_ob[k].btm) / 2.0;
         Track(MkTxt(P"Lbl_"+suf, rE, mp, DoubleToString(g_ob[k].str, 1)+"%", oc, 8));
      }
   }
   ChartRedraw();
}

//── Draw primitives ──────────────────────────────────────────────────
string MkRect(string n, datetime t1, double p1, datetime t2, double p2,
              color clr, int w, bool back) {
   ObjectCreate(0, n, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, n, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, n, OBJPROP_WIDTH,      w);
   ObjectSetInteger(0, n, OBJPROP_BACK,       back);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   return n;
}
string MkLine(string n, datetime t1, double p1, datetime t2, double p2,
              color clr, int w, int style) {
   ObjectCreate(0, n, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, n, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, n, OBJPROP_WIDTH,      w);
   ObjectSetInteger(0, n, OBJPROP_STYLE,      style);
   ObjectSetInteger(0, n, OBJPROP_RAY,        false);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   return n;
}
string MkTxt(string n, datetime t, double p, string txt, color clr, int fs) {
   ObjectCreate(0, n, OBJ_TEXT, 0, t, p);
   ObjectSetString (0, n, OBJPROP_TEXT,       txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE,   fs);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   return n;
}

void Track(string n) { if (g_dCnt < ArraySize(g_dObjs)) g_dObjs[g_dCnt++] = n; }
void ClearDrawObjs() {
   for (int i = 0; i < g_dCnt; i++) ObjectDelete(0, g_dObjs[i]);
   g_dCnt = 0;
}
void DelAll() {
   ClearDrawObjs();
   // usuń panel
   string pNames[] = {P"Panel",P"T1",P"T2",P"T3",P"S1",P"S2",P"TH",
                      P_BULL,P_BEAR,P_LBL,P_STR,P_OVLP,P_RESET};
   for (int i = 0; i < ArraySize(pNames); i++) ObjectDelete(0, pNames[i]);
}

//── Math helpers ─────────────────────────────────────────────────────
double PivHigh(const double &h[], int idx, int len, int total) {
   if (idx - len < 0 || idx + len >= total) return 0;
   double v = h[idx];
   for (int i = 1; i <= len; i++) if (h[idx-i] >= v || h[idx+i] >= v) return 0;
   return v;
}
double PivLow(const double &l[], int idx, int len, int total) {
   if (idx - len < 0 || idx + len >= total) return 0;
   double v = l[idx];
   for (int i = 1; i <= len; i++) if (l[idx-i] <= v || l[idx+i] <= v) return 0;
   return v;
}
double VolSMA(const long &vol[], int idx, int period) {
   if (idx < period - 1) return 1.0;
   double s = 0;
   for (int i = 0; i < period; i++) s += (double)vol[idx-i];
   return s / period;
}
double Str(double range, double brkDist, double relVol) {
   if (range <= 0) return 0;
   double d = MathMin(brkDist / (range * 5.0), 1.0);
   double v = MathMin(relVol / 2.0, 1.0);
   return MathRound((d*0.6 + v*0.4) * 1000.0) / 10.0;
}
bool IsOverlap(double top, double btm, const double &oT[], const double &oB[], int n) {
   for (int j = 0; j < n; j++)
      if ((top <= oT[j] && top >= oB[j]) ||
          (btm <= oT[j] && btm >= oB[j]) ||
          (top >= oT[j] && btm <= oB[j])) return true;
   return false;
}
void CompactOBs() {
   int j = 0;
   for (int i = 0; i < g_n; i++) if (!g_ob[i].mit) g_ob[j++] = g_ob[i];
   g_n = j;
}

//+------------------------------------------------------------------+
// PANEL
//+------------------------------------------------------------------+
void CreatePanel() {
   int w = 214, h = 236, x = PanelX, y = PanelY;

   // Tło
   PnlRect(P"Panel", x, y, w, h, C'13,17,23', C'30,45,61');

   // Nagłówek
   PnlLbl(P"T1", x+10, y+9,  "Order Flow",         C'0,212,161',   10, true);
   PnlLbl(P"T2", x+104,y+9,  "Strength",           C'100,120,135', 10, false);
   PnlLbl(P"T3", x+10, y+26, "LuxAlgo port  v1.0", C'45,65,80',    7,  false);

   PnlSep(P"S1", x+8, y+40, w-16);
   PnlLbl(P"TH", x+10, y+48, "TOGGLE FEATURES", C'74,96,117', 7, false);

   // Przyciski toggle
   PnlToggle(P_BULL,  x+8, y+62,  w-16, 26, "Bullish Order Blocks", g_bull);
   PnlToggle(P_BEAR,  x+8, y+92,  w-16, 26, "Bearish Order Blocks", g_bear);
   PnlToggle(P_LBL,   x+8, y+122, w-16, 26, "Strength Labels",      g_lbl);
   PnlToggle(P_STR,   x+8, y+152, w-16, 26, "Strongest OB Zone",    g_str);
   PnlToggle(P_OVLP,  x+8, y+182, w-16, 26, "Hide Overlapped",      g_ovlp);

   PnlSep(P"S2", x+8, y+213, w-16);
   PnlBtn(P_RESET, x+8, y+218, w-16, 14, "Reset & Recalculate",
          C'25,35,48', C'100,120,135', C'45,63,80', 7);

   ChartRedraw();
}

void PnlRect(string n, int x, int y, int w, int h, color bg, color brd) {
   ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE,   x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE,   y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE,       w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE,       h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR,     bg);
   ObjectSetInteger(0, n, OBJPROP_COLOR,       brd);
   ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, n, OBJPROP_CORNER,      CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE,  false);
   ObjectSetInteger(0, n, OBJPROP_ZORDER,      0);
}
void PnlLbl(string n, int x, int y, string txt, color clr, int fs=8, bool bold=false) {
   ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE,  y);
   ObjectSetString (0, n, OBJPROP_TEXT,       txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE,   fs);
   ObjectSetInteger(0, n, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_ZORDER,     5);
   if (bold) ObjectSetString(0, n, OBJPROP_FONT, "Arial Bold");
}
void PnlSep(string n, int x, int y, int w) {
   ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE,      w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE,      1);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR,    C'30,45,61');
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_ZORDER,     5);
}
void PnlBtn(string n, int x, int y, int w, int h, string txt,
            color bg, color fg, color brd, int fs) {
   ObjectCreate(0, n, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE,    x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE,    y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE,        w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE,        h);
   ObjectSetString (0, n, OBJPROP_TEXT,         txt);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR,      bg);
   ObjectSetInteger(0, n, OBJPROP_COLOR,        fg);
   ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, brd);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE,     fs);
   ObjectSetInteger(0, n, OBJPROP_CORNER,       CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE,   false);
   ObjectSetInteger(0, n, OBJPROP_ZORDER,       10);
}
void PnlToggle(string n, int x, int y, int w, int h, string txt, bool on) {
   color bg  = on ? C'0,60,45'   : C'20,28,38';
   color fg  = on ? C'0,212,161' : C'74,96,117';
   color brd = on ? C'0,120,90'  : C'40,56,72';
   PnlBtn(n, x, y, w, h, (on ? "  ✔  " : "  ✘  ") + txt, bg, fg, brd, 8);
}
void UpdateToggle(string n, bool on, string txt) {
   color bg  = on ? C'0,60,45'   : C'20,28,38';
   color fg  = on ? C'0,212,161' : C'74,96,117';
   color brd = on ? C'0,120,90'  : C'40,56,72';
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR,      bg);
   ObjectSetInteger(0, n, OBJPROP_COLOR,        fg);
   ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, brd);
   ObjectSetString (0, n, OBJPROP_TEXT,         (on ? "  ✔  " : "  ✘  ") + txt);
}

//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lp, const double &dp, const string &sp) {
   if (id != CHARTEVENT_OBJECT_CLICK) return;

   if      (sp == P_BULL)  { g_bull  = !g_bull;  UpdateToggle(P_BULL,  g_bull,  "Bullish Order Blocks"); }
   else if (sp == P_BEAR)  { g_bear  = !g_bear;  UpdateToggle(P_BEAR,  g_bear,  "Bearish Order Blocks"); }
   else if (sp == P_LBL)   { g_lbl   = !g_lbl;   UpdateToggle(P_LBL,   g_lbl,   "Strength Labels");      }
   else if (sp == P_STR)   { g_str   = !g_str;   UpdateToggle(P_STR,   g_str,   "Strongest OB Zone");    }
   else if (sp == P_OVLP)  { g_ovlp  = !g_ovlp;  UpdateToggle(P_OVLP,  g_ovlp,  "Hide Overlapped");      }
   else if (sp == P_RESET) { g_reset = true; }
   else return;

   ObjectSetInteger(0, sp, OBJPROP_STATE, false);
   DrawAll();
}

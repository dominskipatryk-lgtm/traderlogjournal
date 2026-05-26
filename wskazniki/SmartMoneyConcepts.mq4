//+------------------------------------------------------------------+
//| Smart Money Concepts [LuxAlgo] - MQL4 Port + Interactive Panel   |
//| Original: © LuxAlgo (CC BY-NC-SA 4.0)                           |
//| https://creativecommons.org/licenses/by-nc-sa/4.0/              |
//+------------------------------------------------------------------+
#property copyright "LuxAlgo (CC BY-NC-SA 4.0) | MQL4 Port"
#property version   "2.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 0

//--- Color constants
#define CLR_GREEN      0x089981
#define CLR_RED        0xF23645
#define CLR_BLUE       0x2157f3
#define CLR_GRAY       0x878b94
#define CLR_MONO_BULL  0xb2b5be
#define CLR_MONO_BEAR  0x5d606b

//--- Panel colors
#define PANEL_BG       (color)C'18,18,28'
#define PANEL_BORDER   (color)C'50,50,70'
#define BTN_ON_BG      (color)C'8,100,80'
#define BTN_OFF_BG     (color)C'45,45,60'
#define BTN_ON_TXT     clrWhite
#define BTN_OFF_TXT    (color)C'160,160,180'
#define TITLE_CLR      (color)C'200,200,220'

//--- Panel object name prefix (never deleted on redraw)
#define PANEL_PFX      "SMCP_"

//+------------------------------------------------------------------+
//| INPUTS                                                            |
//+------------------------------------------------------------------+
input string  InpMode              = "Historical"; // Mode: Historical / Present
input string  InpStyle             = "Colored";    // Style: Colored / Monochrome

//--- Default ON/OFF states (can be toggled on chart)
input bool    Def_Internals        = true;         // Default: Internal Structure
input bool    Def_Structure        = true;         // Default: Swing Structure
input bool    Def_InternalOB       = true;         // Default: Internal Order Blocks
input bool    Def_SwingOB          = false;        // Default: Swing Order Blocks
input bool    Def_EqualHL          = true;         // Default: EQH / EQL
input bool    Def_FVG              = true;         // Default: Fair Value Gaps
input bool    Def_HighLowSwings    = true;         // Default: Strong/Weak High/Low
input bool    Def_PDZones          = false;        // Default: Premium/Discount Zones
input bool    Def_DailyLevels      = false;        // Default: Daily Levels
input bool    Def_WeeklyLevels     = false;        // Default: Weekly Levels
input bool    Def_MonthlyLevels    = false;        // Default: Monthly Levels

//--- Structure colors & sizes
input string  InpInternalBull      = "All";        // Bullish Internal: All / BOS / CHoCH
input color   InpInternalBullColor = 0x089981;     // Internal Bull Color
input string  InpInternalBear      = "All";        // Bearish Internal: All / BOS / CHoCH
input color   InpInternalBearColor = 0xF23645;     // Internal Bear Color
input bool    InpConfluenceFilter  = false;        // Confluence Filter
input string  InpInternalLabelSize = "Tiny";       // Internal Label Size

input string  InpSwingBull         = "All";        // Bullish Swing: All / BOS / CHoCH
input color   InpSwingBullColor    = 0x089981;     // Swing Bull Color
input string  InpSwingBear         = "All";        // Bearish Swing: All / BOS / CHoCH
input color   InpSwingBearColor    = 0xF23645;     // Swing Bear Color
input string  InpSwingLabelSize    = "Small";      // Swing Label Size
input bool    InpShowSwingPoints   = false;        // Show HH/HL/LH/LL labels
input int     InpSwingsLength      = 50;           // Swings Detection Length

//--- Order Blocks
input int     InpInternalOBSize    = 5;            // Internal OB Count (1-20)
input int     InpSwingOBSize       = 5;            // Swing OB Count (1-20)
input string  InpOBFilter          = "Atr";        // OB Filter: Atr / Cumulative Mean Range
input string  InpOBMitigation      = "High/Low";   // OB Mitigation: Close / High/Low
input color   InpIntBullOBColor    = 0x3179f5;     // Internal Bullish OB Color
input color   InpIntBearOBColor    = 0xf77c80;     // Internal Bearish OB Color
input color   InpSwingBullOBColor  = 0x1848cc;     // Swing Bullish OB Color
input color   InpSwingBearOBColor  = 0xb22833;     // Swing Bearish OB Color

//--- EQH/EQL
input int     InpEqualHLLength     = 3;            // EQH/EQL Bars Confirmation
input double  InpEqualHLThreshold  = 0.1;          // EQH/EQL Threshold (0-0.5)
input string  InpEqualHLLabelSize  = "Tiny";       // EQH/EQL Label Size

//--- FVG
input bool    InpFVGAutoThreshold  = false;        // FVG Auto Threshold (filter micro-gaps)
input color   InpFVGBullColor      = 0x5b9cf6;     // Bullish FVG Color
input color   InpFVGBearColor      = 0xf56c6c;     // Bearish FVG Color
input int     InpFVGMaxCount       = 100;          // Max FVGs to display
input int     InpFVGScanBars       = 1000;         // How many bars back to scan for FVGs

//--- MTF Levels
input string  InpDailyStyle        = "Solid";      // Daily Style
input color   InpDailyColor        = 0x2157f3;     // Daily Color
input string  InpWeeklyStyle       = "Solid";      // Weekly Style
input color   InpWeeklyColor       = 0x2157f3;     // Weekly Color
input string  InpMonthlyStyle      = "Solid";      // Monthly Style
input color   InpMonthlyColor      = 0x2157f3;     // Monthly Color

//--- Premium/Discount Zones
input color   InpPremiumColor      = 0xF23645;     // Premium Zone Color
input color   InpEquilibriumColor  = 0x878b94;     // Equilibrium Color
input color   InpDiscountColor     = 0x089981;     // Discount Zone Color

//--- Panel position
input int     InpPanelX            = 12;           // Panel X (pixels from corner)
input int     InpPanelY            = 30;           // Panel Y (pixels from top)
input int     InpPanelCorner       = 0;            // Panel Corner: 0=TopLeft 1=TopRight 2=BotLeft 3=BotRight

//+------------------------------------------------------------------+
//| RUNTIME TOGGLE STATE (changed by panel buttons)                  |
//+------------------------------------------------------------------+
bool g_showInternals     = true;
bool g_showStructure     = true;
bool g_showInternalOB    = true;
bool g_showSwingOB       = false;
bool g_showEqualHL       = true;
bool g_showFVG           = false;
bool g_showHighLowSwings = true;
bool g_showPDZones       = false;
bool g_showDailyLevels   = false;
bool g_showWeeklyLevels  = false;
bool g_showMonthlyLevels = false;

//+------------------------------------------------------------------+
//| STRUCTS                                                           |
//+------------------------------------------------------------------+
struct OrderBlock
{
   double   high;
   double   low;
   datetime barTime;
   int      bias;
   bool     active;
};

// FVG: no struct needed — drawn by direct bar scan in DrawFVGs()

//+------------------------------------------------------------------+
//| GLOBAL STATE                                                      |
//+------------------------------------------------------------------+
#define MAX_OB  100

OrderBlock g_intOBs[MAX_OB];
OrderBlock g_swingOBs[MAX_OB];
int        g_intOBCount   = 0;
int        g_swingOBCount = 0;

double g_swingHighLevel   = 0, g_swingHighLast  = 0;
bool   g_swingHighCrossed = false;
int    g_swingHighBar     = 0;
double g_swingLowLevel    = 0, g_swingLowLast   = 0;
bool   g_swingLowCrossed  = false;
int    g_swingLowBar      = 0;

double g_intHighLevel     = 0, g_intHighLast    = 0;
bool   g_intHighCrossed   = false;
int    g_intHighBar       = 0;
double g_intLowLevel      = 0, g_intLowLast     = 0;
bool   g_intLowCrossed    = false;
int    g_intLowBar        = 0;

double g_eqHighLevel      = 0;
int    g_eqHighBar        = 0;
double g_eqLowLevel       = 0;
int    g_eqLowBar         = 0;

int    g_swingTrend       = 0;
int    g_internalTrend    = 0;

double g_trailingTop       = 0;
double g_trailingBottom    = 1e10;
int    g_trailingTopBar    = 0;
int    g_trailingBottomBar = 0;
int    g_trailingBar       = 0;

int    g_swingLeg          = 0;
int    g_internalLeg       = 0;

double g_cumVolatility     = 0;
int    g_cumBars           = 0;
int    g_objCount          = 0;

// Tracks last rates_total to detect new bars in OnCalculate
int    g_lastRates         = 0;

//+------------------------------------------------------------------+
//| PANEL LAYOUT CONSTANTS                                            |
//+------------------------------------------------------------------+
#define PANEL_W   162
#define BTN_W     154
#define BTN_H      20
#define BTN_X       4
#define BTN_Y_START 38
#define BTN_STEP   23
#define PANEL_ROWS  11

struct PanelRow
{
   string name;
   string label;
};

PanelRow g_rows[PANEL_ROWS];

void InitPanelRows()
{
   g_rows[0].name  = "INT";   g_rows[0].label  = "Internal Structure";
   g_rows[1].name  = "STR";   g_rows[1].label  = "Swing Structure";
   g_rows[2].name  = "IOB";   g_rows[2].label  = "Int. Order Blocks";
   g_rows[3].name  = "SOB";   g_rows[3].label  = "Swing Order Blocks";
   g_rows[4].name  = "EQL";   g_rows[4].label  = "EQH / EQL";
   g_rows[5].name  = "FVG";   g_rows[5].label  = "Fair Value Gaps";
   g_rows[6].name  = "HLS";   g_rows[6].label  = "Strong/Weak H/L";
   g_rows[7].name  = "PDZ";   g_rows[7].label  = "Premium/Discount";
   g_rows[8].name  = "DAY";   g_rows[8].label  = "Daily Levels";
   g_rows[9].name  = "WEK";   g_rows[9].label  = "Weekly Levels";
   g_rows[10].name = "MON";  g_rows[10].label  = "Monthly Levels";
}

bool GetToggleState(string name)
{
   if(name == "INT") return g_showInternals;
   if(name == "STR") return g_showStructure;
   if(name == "IOB") return g_showInternalOB;
   if(name == "SOB") return g_showSwingOB;
   if(name == "EQL") return g_showEqualHL;
   if(name == "FVG") return g_showFVG;
   if(name == "HLS") return g_showHighLowSwings;
   if(name == "PDZ") return g_showPDZones;
   if(name == "DAY") return g_showDailyLevels;
   if(name == "WEK") return g_showWeeklyLevels;
   if(name == "MON") return g_showMonthlyLevels;
   return false;
}

void FlipToggle(string name)
{
   if(name == "INT") { g_showInternals     = !g_showInternals;     return; }
   if(name == "STR") { g_showStructure     = !g_showStructure;     return; }
   if(name == "IOB") { g_showInternalOB    = !g_showInternalOB;    return; }
   if(name == "SOB") { g_showSwingOB       = !g_showSwingOB;       return; }
   if(name == "EQL") { g_showEqualHL       = !g_showEqualHL;       return; }
   if(name == "FVG") { g_showFVG           = !g_showFVG;           return; }
   if(name == "HLS") { g_showHighLowSwings = !g_showHighLowSwings; return; }
   if(name == "PDZ") { g_showPDZones       = !g_showPDZones;       return; }
   if(name == "DAY") { g_showDailyLevels   = !g_showDailyLevels;   return; }
   if(name == "WEK") { g_showWeeklyLevels  = !g_showWeeklyLevels;  return; }
   if(name == "MON") { g_showMonthlyLevels = !g_showMonthlyLevels; return; }
}

//+------------------------------------------------------------------+
//| PANEL: create or refresh one button appearance                   |
//+------------------------------------------------------------------+
void UpdateButton(string rowName, bool state)
{
   string nm = PANEL_PFX + "BTN_" + rowName;
   color  bg  = state ? BTN_ON_BG  : BTN_OFF_BG;
   color  txt = state ? BTN_ON_TXT : BTN_OFF_TXT;

   ObjectSetInteger(0, nm, OBJPROP_BGCOLOR,      bg);
   ObjectSetInteger(0, nm, OBJPROP_COLOR,         txt);
   ObjectSetInteger(0, nm, OBJPROP_BORDER_COLOR,  state ? (color)CLR_GREEN : PANEL_BORDER);
   ObjectSetInteger(0, nm, OBJPROP_STATE,         false); // reset pressed state
}

//+------------------------------------------------------------------+
//| PANEL: build the full panel (called once in OnInit)              |
//+------------------------------------------------------------------+
void CreatePanel()
{
   InitPanelRows();

   int panelH = BTN_Y_START + PANEL_ROWS * BTN_STEP + 6;

   // Background
   string bgNm = PANEL_PFX + "BG";
   if(ObjectFind(0, bgNm) < 0)
      ObjectCreate(0, bgNm, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgNm, OBJPROP_XDISTANCE,   InpPanelX);
   ObjectSetInteger(0, bgNm, OBJPROP_YDISTANCE,   InpPanelY);
   ObjectSetInteger(0, bgNm, OBJPROP_XSIZE,        PANEL_W);
   ObjectSetInteger(0, bgNm, OBJPROP_YSIZE,        panelH);
   ObjectSetInteger(0, bgNm, OBJPROP_BGCOLOR,      PANEL_BG);
   ObjectSetInteger(0, bgNm, OBJPROP_BORDER_TYPE,  BORDER_FLAT);
   ObjectSetInteger(0, bgNm, OBJPROP_COLOR,         PANEL_BORDER);
   ObjectSetInteger(0, bgNm, OBJPROP_CORNER,        InpPanelCorner);
   ObjectSetInteger(0, bgNm, OBJPROP_BACK,          false);
   ObjectSetInteger(0, bgNm, OBJPROP_SELECTABLE,    false);
   ObjectSetInteger(0, bgNm, OBJPROP_ZORDER,        0);

   // Title label
   string titleNm = PANEL_PFX + "TITLE";
   if(ObjectFind(0, titleNm) < 0)
      ObjectCreate(0, titleNm, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, titleNm, OBJPROP_XDISTANCE,  InpPanelX + 8);
   ObjectSetInteger(0, titleNm, OBJPROP_YDISTANCE,  InpPanelY + 8);
   ObjectSetInteger(0, titleNm, OBJPROP_CORNER,      InpPanelCorner);
   ObjectSetString(0,  titleNm, OBJPROP_TEXT,        "SMC  Controls");
   ObjectSetString(0,  titleNm, OBJPROP_FONT,        "Arial Bold");
   ObjectSetInteger(0, titleNm, OBJPROP_FONTSIZE,    9);
   ObjectSetInteger(0, titleNm, OBJPROP_COLOR,       TITLE_CLR);
   ObjectSetInteger(0, titleNm, OBJPROP_BACK,        false);
   ObjectSetInteger(0, titleNm, OBJPROP_SELECTABLE,  false);

   // Separator line
   string sepNm = PANEL_PFX + "SEP";
   if(ObjectFind(0, sepNm) < 0)
      ObjectCreate(0, sepNm, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, sepNm, OBJPROP_XDISTANCE,  InpPanelX + 2);
   ObjectSetInteger(0, sepNm, OBJPROP_YDISTANCE,  InpPanelY + 28);
   ObjectSetInteger(0, sepNm, OBJPROP_XSIZE,       PANEL_W - 4);
   ObjectSetInteger(0, sepNm, OBJPROP_YSIZE,       1);
   ObjectSetInteger(0, sepNm, OBJPROP_BGCOLOR,     PANEL_BORDER);
   ObjectSetInteger(0, sepNm, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, sepNm, OBJPROP_CORNER,      InpPanelCorner);
   ObjectSetInteger(0, sepNm, OBJPROP_BACK,        false);
   ObjectSetInteger(0, sepNm, OBJPROP_SELECTABLE,  false);

   // Buttons
   for(int i = 0; i < PANEL_ROWS; i++)
   {
      string nm  = PANEL_PFX + "BTN_" + g_rows[i].name;
      int    yPos = InpPanelY + BTN_Y_START + i * BTN_STEP;
      bool   state = GetToggleState(g_rows[i].name);

      if(ObjectFind(0, nm) < 0)
         ObjectCreate(0, nm, OBJ_BUTTON, 0, 0, 0);

      ObjectSetInteger(0, nm, OBJPROP_XDISTANCE,   InpPanelX + BTN_X);
      ObjectSetInteger(0, nm, OBJPROP_YDISTANCE,   yPos);
      ObjectSetInteger(0, nm, OBJPROP_XSIZE,        BTN_W);
      ObjectSetInteger(0, nm, OBJPROP_YSIZE,        BTN_H);
      ObjectSetString(0,  nm, OBJPROP_TEXT,         g_rows[i].label);
      ObjectSetString(0,  nm, OBJPROP_FONT,         "Arial");
      ObjectSetInteger(0, nm, OBJPROP_FONTSIZE,     8);
      ObjectSetInteger(0, nm, OBJPROP_CORNER,       InpPanelCorner);
      ObjectSetInteger(0, nm, OBJPROP_BACK,         false);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE,   false);
      ObjectSetInteger(0, nm, OBJPROP_ZORDER,       1);
      UpdateButton(g_rows[i].name, state);
   }
}

//+------------------------------------------------------------------+
//| Delete all chart objects EXCEPT panel (prefix SMCP_)            |
//+------------------------------------------------------------------+
void DeleteChartObjects()
{
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string nm = ObjectName(0, i, -1, -1);
      if(StringFind(nm, PANEL_PFX) != 0)
         ObjectDelete(0, nm);
   }
   g_objCount = 0;
}

//+------------------------------------------------------------------+
//| Delete objects by prefix (never touches panel)                   |
//+------------------------------------------------------------------+
void DeleteByPrefix(string prefix)
{
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string nm = ObjectName(0, i, -1, -1);
      if(StringFind(nm, prefix) == 0 && StringFind(nm, PANEL_PFX) != 0)
         ObjectDelete(0, nm);
   }
}

//+------------------------------------------------------------------+
//| HELPERS                                                           |
//+------------------------------------------------------------------+
color SwingBullColor()  { return InpStyle == "Monochrome" ? (color)CLR_MONO_BULL : InpSwingBullColor;  }
color SwingBearColor()  { return InpStyle == "Monochrome" ? (color)CLR_MONO_BEAR : InpSwingBearColor;  }
color IntBullColor()    { return InpStyle == "Monochrome" ? (color)CLR_MONO_BULL : InpInternalBullColor; }
color IntBearColor()    { return InpStyle == "Monochrome" ? (color)CLR_MONO_BEAR : InpInternalBearColor; }

int LabelFontSize(string sz)
{
   if(sz == "Tiny")  return 7;
   if(sz == "Small") return 8;
   return 9;
}

string ObjName(string prefix)
{
   g_objCount++;
   return prefix + "_" + IntegerToString(g_objCount);
}

int LineStyleFromString(string s)
{
   if(s == "Dashed") return STYLE_DASH;
   if(s == "Dotted") return STYLE_DOT;
   return STYLE_SOLID;
}

double HighestHigh(int count, int startBar)
{
   double h = -1e10;
   int end = startBar + count;
   if(end >= Bars) end = Bars - 1;
   for(int i = startBar; i < end; i++)
      if(High[i] > h) h = High[i];
   return h;
}

double LowestLow(int count, int startBar)
{
   double l = 1e10;
   int end = startBar + count;
   if(end >= Bars) end = Bars - 1;
   for(int i = startBar; i < end; i++)
      if(Low[i] < l) l = Low[i];
   return l;
}

double CalcATR(int period, int shift)
{
   if(Bars < period + shift + 2) return _Point * 10;
   double sum = 0;
   for(int i = shift; i < shift + period && i + 1 < Bars; i++)
      sum += MathMax(High[i], Close[i + 1]) - MathMin(Low[i], Close[i + 1]);
   return sum / period;
}

//+------------------------------------------------------------------+
//| DRAW: structure line + label                                     |
//+------------------------------------------------------------------+
void DrawStructure(int fromBar, int toBar, double price,
                   string tag, color clr, bool dashed, string labelSize)
{
   if(fromBar >= Bars || toBar >= Bars || fromBar < 0 || toBar < 0) return;
   int oldBar = MathMax(fromBar, toBar);
   int newBar = MathMin(fromBar, toBar);

   string nmL = ObjName("STR_L");
   if(ObjectCreate(0, nmL, OBJ_TREND, 0, Time[oldBar], price, Time[newBar], price))
   {
      ObjectSetInteger(0, nmL, OBJPROP_COLOR,     clr);
      ObjectSetInteger(0, nmL, OBJPROP_WIDTH,     dashed ? 1 : 1);
      ObjectSetInteger(0, nmL, OBJPROP_STYLE,     dashed ? STYLE_DASH : STYLE_SOLID);
      ObjectSetInteger(0, nmL, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, nmL, OBJPROP_BACK,      true);
   }

   int midBar = (oldBar + newBar) / 2;
   if(midBar >= Bars) midBar = Bars - 1;
   string nmT = ObjName("STR_T");
   if(ObjectCreate(0, nmT, OBJ_TEXT, 0, Time[midBar], price))
   {
      ObjectSetString(0,  nmT, OBJPROP_TEXT,     tag);
      ObjectSetInteger(0, nmT, OBJPROP_COLOR,    clr);
      ObjectSetInteger(0, nmT, OBJPROP_FONTSIZE, LabelFontSize(labelSize));
      ObjectSetInteger(0, nmT, OBJPROP_ANCHOR,   dashed ? ANCHOR_LOWER : ANCHOR_UPPER);
      ObjectSetInteger(0, nmT, OBJPROP_BACK,     false);
   }
}

//+------------------------------------------------------------------+
//| DRAW: EQH / EQL                                                  |
//+------------------------------------------------------------------+
void DrawEqualHL(double prevLevel, int prevBar, double curLevel, int curBar,
                 bool isHigh, color clr, string labelSize)
{
   if(prevBar >= Bars || curBar >= Bars) return;
   int oldBar = MathMax(prevBar, curBar);
   int newBar = MathMin(prevBar, curBar);

   string nmL = ObjName("EQ_L");
   if(ObjectCreate(0, nmL, OBJ_TREND, 0, Time[oldBar], curLevel, Time[newBar], curLevel))
   {
      ObjectSetInteger(0, nmL, OBJPROP_COLOR,     clr);
      ObjectSetInteger(0, nmL, OBJPROP_STYLE,     STYLE_DOT);
      ObjectSetInteger(0, nmL, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, nmL, OBJPROP_BACK,      true);
   }

   int midBar = (oldBar + newBar) / 2;
   if(midBar >= Bars) midBar = Bars - 1;
   string nmT = ObjName("EQ_T");
   if(ObjectCreate(0, nmT, OBJ_TEXT, 0, Time[midBar], curLevel))
   {
      ObjectSetString(0,  nmT, OBJPROP_TEXT,     isHigh ? "EQH" : "EQL");
      ObjectSetInteger(0, nmT, OBJPROP_COLOR,    clr);
      ObjectSetInteger(0, nmT, OBJPROP_FONTSIZE, LabelFontSize(labelSize));
      ObjectSetInteger(0, nmT, OBJPROP_ANCHOR,   isHigh ? ANCHOR_LOWER : ANCHOR_UPPER);
      ObjectSetInteger(0, nmT, OBJPROP_BACK,     false);
   }
}

//+------------------------------------------------------------------+
//| DRAW: swing point label                                          |
//+------------------------------------------------------------------+
void DrawSwingLabel(int bar, double price, string tag, color clr, bool above, string labelSize)
{
   if(bar >= Bars || bar < 0) return;
   string nm = ObjName("SWP");
   if(ObjectCreate(0, nm, OBJ_TEXT, 0, Time[bar], price))
   {
      ObjectSetString(0,  nm, OBJPROP_TEXT,     tag);
      ObjectSetInteger(0, nm, OBJPROP_COLOR,    clr);
      ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, LabelFontSize(labelSize));
      ObjectSetInteger(0, nm, OBJPROP_ANCHOR,   above ? ANCHOR_UPPER : ANCHOR_LOWER);
      ObjectSetInteger(0, nm, OBJPROP_BACK,     false);
   }
}

//+------------------------------------------------------------------+
//| STORE order block                                                 |
//+------------------------------------------------------------------+
void StoreOB(bool internal, int bias, int pivotBar, int currentBar)
{
   double atr     = CalcATR(200, 0);
   double cumMean = (g_cumBars > 0) ? g_cumVolatility / g_cumBars : atr;
   double volMeas = (InpOBFilter == "Atr") ? atr : cumMean;

   int older = MathMax(pivotBar, currentBar);
   int newer = MathMin(pivotBar, currentBar);
   if(older >= Bars) older = Bars - 1;

   int    bestBar = older;
   double bestVal = (bias == -1) ? -1e10 : 1e10;

   for(int i = newer; i <= older && i < Bars; i++)
   {
      bool   hv = (High[i] - Low[i]) >= 2.0 * volMeas;
      double pH = hv ? Low[i]  : High[i];
      double pL = hv ? High[i] : Low[i];
      if(bias == -1 && pH > bestVal) { bestVal = pH; bestBar = i; }
      if(bias ==  1 && pL < bestVal) { bestVal = pL; bestBar = i; }
   }

   OrderBlock ob;
   ob.high    = High[bestBar];
   ob.low     = Low[bestBar];
   ob.barTime = Time[bestBar];
   ob.bias    = bias;
   ob.active  = true;

   if(internal)
   {
      int lim = MathMin(g_intOBCount, MAX_OB - 2);
      for(int k = lim; k >= 0; k--) g_intOBs[k + 1] = g_intOBs[k];
      g_intOBs[0] = ob;
      if(g_intOBCount < MAX_OB) g_intOBCount++;
   }
   else
   {
      int lim = MathMin(g_swingOBCount, MAX_OB - 2);
      for(int k = lim; k >= 0; k--) g_swingOBs[k + 1] = g_swingOBs[k];
      g_swingOBs[0] = ob;
      if(g_swingOBCount < MAX_OB) g_swingOBCount++;
   }
}

//+------------------------------------------------------------------+
//| MITIGATE order blocks                                             |
//+------------------------------------------------------------------+
void DeleteMitigatedOBs(bool internal)
{
   double mitigHigh = (InpOBMitigation == "Close") ? Close[0] : High[0];
   double mitigLow  = (InpOBMitigation == "Close") ? Close[0] : Low[0];

   if(internal)
   {
      for(int i = 0; i < g_intOBCount; i++)
      {
         if(!g_intOBs[i].active) continue;
         if(g_intOBs[i].bias == -1 && mitigHigh > g_intOBs[i].high)
            g_intOBs[i].active = false;
         else if(g_intOBs[i].bias == 1 && mitigLow < g_intOBs[i].low)
            g_intOBs[i].active = false;
      }
   }
   else
   {
      for(int i = 0; i < g_swingOBCount; i++)
      {
         if(!g_swingOBs[i].active) continue;
         if(g_swingOBs[i].bias == -1 && mitigHigh > g_swingOBs[i].high)
            g_swingOBs[i].active = false;
         else if(g_swingOBs[i].bias == 1 && mitigLow < g_swingOBs[i].low)
            g_swingOBs[i].active = false;
      }
   }
}

//+------------------------------------------------------------------+
//| DRAW: order block boxes                                           |
//+------------------------------------------------------------------+
void DrawOBBoxes(bool internal)
{
   string prefix = internal ? "INTOB" : "SWOB";
   DeleteByPrefix(prefix);

   int count   = internal ? g_intOBCount    : g_swingOBCount;
   int maxShow = internal ? InpInternalOBSize : InpSwingOBSize;
   datetime rightTime = Time[0] + (datetime)PeriodSeconds();
   int shown = 0;

   for(int i = 0; i < count && shown < maxShow; i++)
   {
      bool     isActive;
      double   obHigh, obLow;
      datetime obTime;
      int      obBias;

      if(internal)
      {
         if(!g_intOBs[i].active) continue;
         obHigh = g_intOBs[i].high; obLow = g_intOBs[i].low;
         obTime = g_intOBs[i].barTime; obBias = g_intOBs[i].bias;
      }
      else
      {
         if(!g_swingOBs[i].active) continue;
         obHigh = g_swingOBs[i].high; obLow = g_swingOBs[i].low;
         obTime = g_swingOBs[i].barTime; obBias = g_swingOBs[i].bias;
      }
      shown++;

      color obClr;
      if(InpStyle == "Monochrome")
         obClr = obBias == -1 ? (color)CLR_MONO_BEAR : (color)CLR_MONO_BULL;
      else if(internal)
         obClr = obBias == -1 ? InpIntBearOBColor : InpIntBullOBColor;
      else
         obClr = obBias == -1 ? InpSwingBearOBColor : InpSwingBullOBColor;

      string nm = prefix + "_" + IntegerToString(i) + "_" + IntegerToString(g_objCount++);
      if(ObjectCreate(0, nm, OBJ_RECTANGLE, 0, obTime, obHigh, rightTime, obLow))
      {
         ObjectSetInteger(0, nm, OBJPROP_COLOR, obClr);
         ObjectSetInteger(0, nm, OBJPROP_BACK,  true);
         ObjectSetInteger(0, nm, OBJPROP_FILL,  true);
         ObjectSetInteger(0, nm, OBJPROP_WIDTH, 1);
      }
   }
}

//+------------------------------------------------------------------+
//| FVG                                                               |
//+------------------------------------------------------------------+
// DrawFVGs: scans last InpFVGScanBars bars, draws up to InpFVGMaxCount unmitigated FVGs
// Each FVG = one solid filled rectangle extending to the right edge of the chart
void DrawFVGs()
{
   DeleteByPrefix("FVG");
   if(!g_showFVG) return;

   int    scanLimit = MathMin(InpFVGScanBars, Bars - 3);
   // Right edge = a few bars past bar 0 so box doesn't stop at last candle
   datetime rightEdge = Time[0] + (datetime)(3 * PeriodSeconds());
   double   atr = CalcATR(14, 0);
   double   thr = InpFVGAutoThreshold ? atr * 0.1 : 0;
   int      drawn = 0;

   for(int bar = 1; bar <= scanLimit && drawn < InpFVGMaxCount; bar++)
   {
      if(bar + 2 >= Bars) break;

      // ── Bullish FVG: Low[bar] > High[bar+2] ──────────────────────────
      double bTop = Low[bar];
      double bBot = High[bar + 2];
      if(bTop > bBot && (bTop - bBot) > thr)
      {
         bool mitigated = false;
         for(int j = bar - 1; j >= 0; j--)
            if(Low[j] <= bBot) { mitigated = true; break; }
         if(!mitigated)
         {
            color    clr = InpStyle == "Monochrome" ? (color)CLR_MONO_BULL : InpFVGBullColor;
            datetime t1  = Time[bar + 1]; // left edge = impulsive candle

            string nm = ObjName("FVG");
            if(ObjectCreate(0, nm, OBJ_RECTANGLE, 0, t1, bTop, rightEdge, bBot))
            {
               ObjectSetInteger(0, nm, OBJPROP_COLOR, clr);
               ObjectSetInteger(0, nm, OBJPROP_FILL,  true);
               ObjectSetInteger(0, nm, OBJPROP_BACK,  true);
               ObjectSetInteger(0, nm, OBJPROP_WIDTH, 1);
            }
            drawn++;
         }
      }

      if(drawn >= InpFVGMaxCount) break;

      // ── Bearish FVG: High[bar] < Low[bar+2] ──────────────────────────
      double sTop = Low[bar + 2];
      double sBot = High[bar];
      if(sTop > sBot && (sTop - sBot) > thr)
      {
         bool mitigated = false;
         for(int j = bar - 1; j >= 0; j--)
            if(High[j] >= sTop) { mitigated = true; break; }
         if(!mitigated)
         {
            color    clr = InpStyle == "Monochrome" ? (color)CLR_MONO_BEAR : InpFVGBearColor;
            datetime t1  = Time[bar + 1];

            string nm = ObjName("FVG");
            if(ObjectCreate(0, nm, OBJ_RECTANGLE, 0, t1, sTop, rightEdge, sBot))
            {
               ObjectSetInteger(0, nm, OBJPROP_COLOR, clr);
               ObjectSetInteger(0, nm, OBJPROP_FILL,  true);
               ObjectSetInteger(0, nm, OBJPROP_BACK,  true);
               ObjectSetInteger(0, nm, OBJPROP_WIDTH, 1);
            }
            drawn++;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| DRAW: Strong/Weak High/Low                                       |
//+------------------------------------------------------------------+
void DrawHighLowSwings()
{
   DeleteByPrefix("HLSW");
   if(!g_showHighLowSwings) return;
   if(g_trailingTop == 0 || g_trailingBottom >= 1e9) return;

   datetime rightTime = Time[0] + (datetime)(20 * PeriodSeconds());
   color topClr = SwingBearColor();
   color botClr = SwingBullColor();
   string topLabel = (g_swingTrend == -1) ? "Strong High" : "Weak High";
   string botLabel = (g_swingTrend ==  1) ? "Strong Low"  : "Weak Low";

   if(g_trailingTopBar < Bars)
   {
      if(ObjectCreate(0, "HLSW_TL", OBJ_TREND, 0, Time[g_trailingTopBar], g_trailingTop, rightTime, g_trailingTop))
      {
         ObjectSetInteger(0, "HLSW_TL", OBJPROP_COLOR,     topClr);
         ObjectSetInteger(0, "HLSW_TL", OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, "HLSW_TL", OBJPROP_BACK,      true);
      }
      if(ObjectCreate(0, "HLSW_TT", OBJ_TEXT, 0, rightTime, g_trailingTop))
      {
         ObjectSetString(0,  "HLSW_TT", OBJPROP_TEXT,     topLabel);
         ObjectSetInteger(0, "HLSW_TT", OBJPROP_COLOR,    topClr);
         ObjectSetInteger(0, "HLSW_TT", OBJPROP_FONTSIZE, 7);
         ObjectSetInteger(0, "HLSW_TT", OBJPROP_ANCHOR,   ANCHOR_LOWER);
      }
   }
   if(g_trailingBottomBar < Bars)
   {
      if(ObjectCreate(0, "HLSW_BL", OBJ_TREND, 0, Time[g_trailingBottomBar], g_trailingBottom, rightTime, g_trailingBottom))
      {
         ObjectSetInteger(0, "HLSW_BL", OBJPROP_COLOR,     botClr);
         ObjectSetInteger(0, "HLSW_BL", OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, "HLSW_BL", OBJPROP_BACK,      true);
      }
      if(ObjectCreate(0, "HLSW_BT", OBJ_TEXT, 0, rightTime, g_trailingBottom))
      {
         ObjectSetString(0,  "HLSW_BT", OBJPROP_TEXT,     botLabel);
         ObjectSetInteger(0, "HLSW_BT", OBJPROP_COLOR,    botClr);
         ObjectSetInteger(0, "HLSW_BT", OBJPROP_FONTSIZE, 7);
         ObjectSetInteger(0, "HLSW_BT", OBJPROP_ANCHOR,   ANCHOR_UPPER);
      }
   }
}

//+------------------------------------------------------------------+
//| DRAW: Premium / Discount zones                                   |
//+------------------------------------------------------------------+
void DrawPDZones()
{
   DeleteByPrefix("PDZ");
   if(!g_showPDZones) return;
   if(g_trailingTop == 0 || g_trailingBottom >= 1e9) return;

   datetime t1 = (g_trailingBar > 0 && g_trailingBar < Bars) ? Time[g_trailingBar] : Time[Bars - 1];
   datetime t2 = Time[0] + (datetime)(20 * PeriodSeconds());
   double top = g_trailingTop, bot = g_trailingBottom;

   color pClr = InpStyle == "Monochrome" ? (color)CLR_MONO_BEAR : InpPremiumColor;
   color eClr = InpStyle == "Monochrome" ? (color)CLR_GRAY      : InpEquilibriumColor;
   color dClr = InpStyle == "Monochrome" ? (color)CLR_MONO_BULL : InpDiscountColor;

   // Premium
   if(ObjectCreate(0, "PDZ_P", OBJ_RECTANGLE, 0, t1, top, t2, 0.95 * top + 0.05 * bot))
   { ObjectSetInteger(0,"PDZ_P",OBJPROP_COLOR,pClr); ObjectSetInteger(0,"PDZ_P",OBJPROP_BACK,true); ObjectSetInteger(0,"PDZ_P",OBJPROP_FILL,true); }
   if(ObjectCreate(0, "PDZ_PT", OBJ_TEXT, 0, t2, 0.975 * top + 0.025 * bot))
   { ObjectSetString(0,"PDZ_PT",OBJPROP_TEXT,"Premium"); ObjectSetInteger(0,"PDZ_PT",OBJPROP_COLOR,pClr); ObjectSetInteger(0,"PDZ_PT",OBJPROP_FONTSIZE,8); ObjectSetInteger(0,"PDZ_PT",OBJPROP_ANCHOR,ANCHOR_LOWER); }

   // Equilibrium
   double eT = 0.525*top+0.475*bot, eB = 0.475*top+0.525*bot;
   if(ObjectCreate(0, "PDZ_E", OBJ_RECTANGLE, 0, t1, eT, t2, eB))
   { ObjectSetInteger(0,"PDZ_E",OBJPROP_COLOR,eClr); ObjectSetInteger(0,"PDZ_E",OBJPROP_BACK,true); ObjectSetInteger(0,"PDZ_E",OBJPROP_FILL,true); }
   if(ObjectCreate(0, "PDZ_ET", OBJ_TEXT, 0, t2, 0.5*(eT+eB)))
   { ObjectSetString(0,"PDZ_ET",OBJPROP_TEXT,"Equilibrium"); ObjectSetInteger(0,"PDZ_ET",OBJPROP_COLOR,eClr); ObjectSetInteger(0,"PDZ_ET",OBJPROP_FONTSIZE,8); ObjectSetInteger(0,"PDZ_ET",OBJPROP_ANCHOR,ANCHOR_LEFT); }

   // Discount
   if(ObjectCreate(0, "PDZ_D", OBJ_RECTANGLE, 0, t1, 0.05*top+0.95*bot, t2, bot))
   { ObjectSetInteger(0,"PDZ_D",OBJPROP_COLOR,dClr); ObjectSetInteger(0,"PDZ_D",OBJPROP_BACK,true); ObjectSetInteger(0,"PDZ_D",OBJPROP_FILL,true); }
   if(ObjectCreate(0, "PDZ_DT", OBJ_TEXT, 0, t2, 0.025*top+0.975*bot))
   { ObjectSetString(0,"PDZ_DT",OBJPROP_TEXT,"Discount"); ObjectSetInteger(0,"PDZ_DT",OBJPROP_COLOR,dClr); ObjectSetInteger(0,"PDZ_DT",OBJPROP_FONTSIZE,8); ObjectSetInteger(0,"PDZ_DT",OBJPROP_ANCHOR,ANCHOR_UPPER); }
}

//+------------------------------------------------------------------+
//| DRAW: MTF levels                                                  |
//+------------------------------------------------------------------+
void DrawMTFLevel(double hi, double lo, string lbl, color clr, string styleStr, string prefix)
{
   DeleteByPrefix(prefix);
   int ls = LineStyleFromString(styleStr);
   datetime tL = Time[Bars - 1];
   datetime tR = Time[0] + (datetime)(20 * PeriodSeconds());

   if(ObjectCreate(0, prefix+"_H", OBJ_TREND, 0, tL, hi, tR, hi))
   { ObjectSetInteger(0,prefix+"_H",OBJPROP_COLOR,clr); ObjectSetInteger(0,prefix+"_H",OBJPROP_STYLE,ls); ObjectSetInteger(0,prefix+"_H",OBJPROP_RAY_RIGHT,false); ObjectSetInteger(0,prefix+"_H",OBJPROP_BACK,true); }
   if(ObjectCreate(0, prefix+"_L", OBJ_TREND, 0, tL, lo, tR, lo))
   { ObjectSetInteger(0,prefix+"_L",OBJPROP_COLOR,clr); ObjectSetInteger(0,prefix+"_L",OBJPROP_STYLE,ls); ObjectSetInteger(0,prefix+"_L",OBJPROP_RAY_RIGHT,false); ObjectSetInteger(0,prefix+"_L",OBJPROP_BACK,true); }
   if(ObjectCreate(0, prefix+"_TH", OBJ_TEXT, 0, tR, hi))
   { ObjectSetString(0,prefix+"_TH",OBJPROP_TEXT,"P"+lbl+"H"); ObjectSetInteger(0,prefix+"_TH",OBJPROP_COLOR,clr); ObjectSetInteger(0,prefix+"_TH",OBJPROP_FONTSIZE,7); ObjectSetInteger(0,prefix+"_TH",OBJPROP_ANCHOR,ANCHOR_LOWER); }
   if(ObjectCreate(0, prefix+"_TL", OBJ_TEXT, 0, tR, lo))
   { ObjectSetString(0,prefix+"_TL",OBJPROP_TEXT,"P"+lbl+"L"); ObjectSetInteger(0,prefix+"_TL",OBJPROP_COLOR,clr); ObjectSetInteger(0,prefix+"_TL",OBJPROP_FONTSIZE,7); ObjectSetInteger(0,prefix+"_TL",OBJPROP_ANCHOR,ANCHOR_UPPER); }
}

void UpdateMTFLevels()
{
   if(g_showDailyLevels)
   {
      double h = iHigh(NULL, PERIOD_D1, 1), l = iLow(NULL, PERIOD_D1, 1);
      if(h > 0) DrawMTFLevel(h, l, "D", InpDailyColor, InpDailyStyle, "MTF_D");
   }
   else DeleteByPrefix("MTF_D");

   if(g_showWeeklyLevels)
   {
      double h = iHigh(NULL, PERIOD_W1, 1), l = iLow(NULL, PERIOD_W1, 1);
      if(h > 0) DrawMTFLevel(h, l, "W", InpWeeklyColor, InpWeeklyStyle, "MTF_W");
   }
   else DeleteByPrefix("MTF_W");

   if(g_showMonthlyLevels)
   {
      double h = iHigh(NULL, PERIOD_MN1, 1), l = iLow(NULL, PERIOD_MN1, 1);
      if(h > 0) DrawMTFLevel(h, l, "M", InpMonthlyColor, InpMonthlyStyle, "MTF_M");
   }
   else DeleteByPrefix("MTF_M");
}

//+------------------------------------------------------------------+
//| CORE: process one bar                                             |
//+------------------------------------------------------------------+
void ProcessBar(int bar)
{
   if(bar <= 0 || bar >= Bars) return;

   if(bar + 1 < Bars)
   {
      double tr = MathMax(High[bar], Close[bar + 1]) - MathMin(Low[bar], Close[bar + 1]);
      g_cumVolatility += tr;
      g_cumBars++;
   }

   double atr = CalcATR(200, bar);

   // Trailing extremes
   if(g_showHighLowSwings || g_showPDZones)
   {
      if(High[bar] >= g_trailingTop)   { g_trailingTop    = High[bar]; g_trailingTopBar    = bar; }
      if(Low[bar]  <= g_trailingBottom) { g_trailingBottom = Low[bar];  g_trailingBottomBar = bar; }
   }

   //--- SWING structure
   {
      int sz = InpSwingsLength;
      if(bar + sz < Bars)
      {
         int prevLeg = g_swingLeg;
         if(High[bar + sz] > HighestHigh(sz, bar)) g_swingLeg = 0;
         else if(Low[bar + sz] < LowestLow(sz, bar))  g_swingLeg = 1;

         bool pivotLow  = (g_swingLeg != prevLeg) && g_swingLeg == 1 && prevLeg == 0;
         bool pivotHigh = (g_swingLeg != prevLeg) && g_swingLeg == 0 && prevLeg == 1;

         if(pivotLow)
         {
            double nL = Low[bar + sz]; int nB = bar + sz;
            if(g_showEqualHL && g_eqLowLevel != 0 && MathAbs(g_eqLowLevel - nL) < InpEqualHLThreshold * atr)
               DrawEqualHL(g_eqLowLevel, g_eqLowBar, nL, nB, false, SwingBullColor(), InpEqualHLLabelSize);
            g_eqLowLevel = nL; g_eqLowBar = nB;
            if(InpShowSwingPoints) { string t = (g_swingLowLevel > 0 && nL < g_swingLowLevel) ? "LL" : "HL"; DrawSwingLabel(nB, nL, t, SwingBullColor(), true, InpSwingLabelSize); }
            g_swingLowLast = g_swingLowLevel; g_swingLowLevel = nL; g_swingLowBar = nB; g_swingLowCrossed = false;
            g_trailingBottom = nL; g_trailingBottomBar = nB; g_trailingBar = nB;
         }
         else if(pivotHigh)
         {
            double nL = High[bar + sz]; int nB = bar + sz;
            if(g_showEqualHL && g_eqHighLevel != 0 && MathAbs(g_eqHighLevel - nL) < InpEqualHLThreshold * atr)
               DrawEqualHL(g_eqHighLevel, g_eqHighBar, nL, nB, true, SwingBearColor(), InpEqualHLLabelSize);
            g_eqHighLevel = nL; g_eqHighBar = nB;
            if(InpShowSwingPoints) { string t = (g_swingHighLevel > 0 && nL > g_swingHighLevel) ? "HH" : "LH"; DrawSwingLabel(nB, nL, t, SwingBearColor(), false, InpSwingLabelSize); }
            g_swingHighLast = g_swingHighLevel; g_swingHighLevel = nL; g_swingHighBar = nB; g_swingHighCrossed = false;
            g_trailingTop = nL; g_trailingTopBar = nB; g_trailingBar = nB;
         }
      }
   }

   //--- INTERNAL structure
   {
      int sz = 5;
      if(bar + sz < Bars)
      {
         int prevLeg = g_internalLeg;
         if(High[bar + sz] > HighestHigh(sz, bar)) g_internalLeg = 0;
         else if(Low[bar + sz] < LowestLow(sz, bar))  g_internalLeg = 1;

         bool pivotLow  = (g_internalLeg != prevLeg) && g_internalLeg == 1 && prevLeg == 0;
         bool pivotHigh = (g_internalLeg != prevLeg) && g_internalLeg == 0 && prevLeg == 1;

         if(pivotLow)  { g_intLowLast  = g_intLowLevel;  g_intLowLevel  = Low[bar+sz];  g_intLowBar  = bar+sz; g_intLowCrossed  = false; }
         if(pivotHigh) { g_intHighLast = g_intHighLevel;  g_intHighLevel = High[bar+sz]; g_intHighBar = bar+sz; g_intHighCrossed = false; }
      }
   }

   //--- SWING BOS/CHoCH
   if(g_swingHighLevel > 0 && (g_showStructure || g_showSwingOB || g_showHighLowSwings))
   {
      if(Close[bar] > g_swingHighLevel && !g_swingHighCrossed)
      {
         string tag = (g_swingTrend == -1) ? "CHoCH" : "BOS";
         if(g_showStructure && (InpSwingBull=="All"||(InpSwingBull=="BOS"&&tag=="BOS")||(InpSwingBull=="CHoCH"&&tag=="CHoCH")))
            DrawStructure(g_swingHighBar, bar, g_swingHighLevel, tag, SwingBullColor(), false, InpSwingLabelSize);
         if(g_showSwingOB) StoreOB(false, 1, g_swingHighBar, bar);
         g_swingHighCrossed = true; g_swingTrend = 1;
      }
   }
   if(g_swingLowLevel > 0 && (g_showStructure || g_showSwingOB))
   {
      if(Close[bar] < g_swingLowLevel && !g_swingLowCrossed)
      {
         string tag = (g_swingTrend == 1) ? "CHoCH" : "BOS";
         if(g_showStructure && (InpSwingBear=="All"||(InpSwingBear=="BOS"&&tag=="BOS")||(InpSwingBear=="CHoCH"&&tag=="CHoCH")))
            DrawStructure(g_swingLowBar, bar, g_swingLowLevel, tag, SwingBearColor(), false, InpSwingLabelSize);
         if(g_showSwingOB) StoreOB(false, -1, g_swingLowBar, bar);
         g_swingLowCrossed = true; g_swingTrend = -1;
      }
   }

   //--- INTERNAL BOS/CHoCH
   if(g_intHighLevel > 0 && (g_showInternals || g_showInternalOB))
   {
      bool ex = (g_intHighLevel != g_swingHighLevel);
      if(InpConfluenceFilter) ex = ex && (High[bar]-MathMax(Close[bar],Open[bar])) > (MathMin(Close[bar],Open[bar])-Low[bar]);
      if(Close[bar] > g_intHighLevel && !g_intHighCrossed && ex)
      {
         string tag = (g_internalTrend == -1) ? "CHoCH" : "BOS";
         if(g_showInternals && (InpInternalBull=="All"||(InpInternalBull=="BOS"&&tag=="BOS")||(InpInternalBull=="CHoCH"&&tag=="CHoCH")))
            DrawStructure(g_intHighBar, bar, g_intHighLevel, tag, IntBullColor(), true, InpInternalLabelSize);
         if(g_showInternalOB) StoreOB(true, 1, g_intHighBar, bar);
         g_intHighCrossed = true; g_internalTrend = 1;
      }
   }
   if(g_intLowLevel > 0 && (g_showInternals || g_showInternalOB))
   {
      bool ex = (g_intLowLevel != g_swingLowLevel);
      if(InpConfluenceFilter) ex = ex && (High[bar]-MathMax(Close[bar],Open[bar])) < (MathMin(Close[bar],Open[bar])-Low[bar]);
      if(Close[bar] < g_intLowLevel && !g_intLowCrossed && ex)
      {
         string tag = (g_internalTrend == 1) ? "CHoCH" : "BOS";
         if(g_showInternals && (InpInternalBear=="All"||(InpInternalBear=="BOS"&&tag=="BOS")||(InpInternalBear=="CHoCH"&&tag=="CHoCH")))
            DrawStructure(g_intLowBar, bar, g_intLowLevel, tag, IntBearColor(), true, InpInternalLabelSize);
         if(g_showInternalOB) StoreOB(true, -1, g_intLowBar, bar);
         g_intLowCrossed = true; g_internalTrend = -1;
      }
   }

}


//+------------------------------------------------------------------+
//| Reset indicator state (keeps panel)                              |
//+------------------------------------------------------------------+
void ResetState()
{
   DeleteChartObjects();
   g_swingOBCount = 0; g_intOBCount = 0;
   g_trailingTop = 0; g_trailingBottom = 1e10;
   g_trailingTopBar = 0; g_trailingBottomBar = 0; g_trailingBar = 0;
   g_swingTrend = 0; g_internalTrend = 0;
   g_swingHighLevel = 0; g_swingHighLast = 0; g_swingHighCrossed = false; g_swingHighBar = 0;
   g_swingLowLevel  = 0; g_swingLowLast  = 0; g_swingLowCrossed  = false; g_swingLowBar  = 0;
   g_intHighLevel   = 0; g_intHighLast   = 0; g_intHighCrossed   = false; g_intHighBar   = 0;
   g_intLowLevel    = 0; g_intLowLast    = 0; g_intLowCrossed    = false; g_intLowBar    = 0;
   g_eqHighLevel    = 0; g_eqHighBar     = 0;
   g_eqLowLevel     = 0; g_eqLowBar      = 0;
   g_swingLeg       = 0; g_internalLeg   = 0;
   g_cumVolatility  = 0; g_cumBars       = 0;
   g_lastRates      = 0;
}

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   // Load default toggle states from inputs
   g_showInternals     = Def_Internals;
   g_showStructure     = Def_Structure;
   g_showInternalOB    = Def_InternalOB;
   g_showSwingOB       = Def_SwingOB;
   g_showEqualHL       = Def_EqualHL;
   g_showFVG           = Def_FVG;
   g_showHighLowSwings = Def_HighLowSwings;
   g_showPDZones       = Def_PDZones;
   g_showDailyLevels   = Def_DailyLevels;
   g_showWeeklyLevels  = Def_WeeklyLevels;
   g_showMonthlyLevels = Def_MonthlyLevels;

   ResetState();
   CreatePanel();
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0);
}

//+------------------------------------------------------------------+
//| OnCalculate                                                       |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < InpSwingsLength + 10) return 0;

   if(prev_calculated == 0)
      ResetState();

   int startBar;
   if(prev_calculated == 0)
   {
      startBar = rates_total - 1 - InpSwingsLength;
      if(InpMode == "Present") startBar = MathMin(startBar, 500);
   }
   else
   {
      startBar = rates_total - prev_calculated + 1;
      if(startBar <= 0) startBar = 1;
   }

   for(int bar = startBar; bar >= 1; bar--)
      ProcessBar(bar);

   if(g_showInternalOB) DeleteMitigatedOBs(true);
   if(g_showSwingOB)    DeleteMitigatedOBs(false);

   DrawHighLowSwings();
   DrawPDZones();

   if(g_showInternalOB) DrawOBBoxes(true);
   if(g_showSwingOB)    DrawOBBoxes(false);
   if(g_showFVG)        DrawFVGs();

   UpdateMTFLevels();
   g_lastRates = rates_total;

   ChartRedraw(0);
   return rates_total;
}

//+------------------------------------------------------------------+
//| OnChartEvent — handles panel button clicks                       |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long   &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK) return;

   // Check if clicked object is one of our panel buttons
   for(int i = 0; i < PANEL_ROWS; i++)
   {
      string btnName = PANEL_PFX + "BTN_" + g_rows[i].name;
      if(sparam == btnName)
      {
         FlipToggle(g_rows[i].name);
         UpdateButton(g_rows[i].name, GetToggleState(g_rows[i].name));

         // Full redraw with new toggle states
         ResetState();
         CreatePanel(); // restore panel after DeleteChartObjects

         int startBar = Bars - 1 - InpSwingsLength;
         if(InpMode == "Present") startBar = MathMin(startBar, 500);
         for(int bar = startBar; bar >= 1; bar--)
            ProcessBar(bar);

         if(g_showInternalOB) DeleteMitigatedOBs(true);
         if(g_showSwingOB)    DeleteMitigatedOBs(false);
      
         DrawHighLowSwings();
         DrawPDZones();

         if(g_showInternalOB) DrawOBBoxes(true);
         if(g_showSwingOB)    DrawOBBoxes(false);
         if(g_showFVG)        DrawFVGs();

         UpdateMTFLevels();
         ChartRedraw(0);
         return;
      }
   }
}
//+------------------------------------------------------------------+

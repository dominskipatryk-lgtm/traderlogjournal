//+------------------------------------------------------------------+
//| Smart Money Concepts [LuxAlgo] - MQL4 Port                     |
//| Original: © LuxAlgo (CC BY-NC-SA 4.0)                          |
//| MQL4 Port: for MetaTrader 4                                     |
//+------------------------------------------------------------------+
#property copyright "© LuxAlgo (CC BY-NC-SA 4.0)"
#property link      "https://creativecommons.org/licenses/by-nc-sa/4.0/"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 0

//--- Colors
#define CLR_GREEN    0x089981
#define CLR_RED      0xF23645
#define CLR_BLUE     0x2157f3
#define CLR_GRAY     0x878b94
#define CLR_MONO_BULL 0xb2b5be
#define CLR_MONO_BEAR 0x5d606b

//--- Inputs: Smart Money
input string  InpMode                  = "Historical";   // Mode: Historical / Present
input string  InpStyle                 = "Colored";      // Style: Colored / Monochrome
input bool    InpColorCandles          = false;          // Color Candles

//--- Inputs: Internal Structure
input bool    InpShowInternals         = true;           // Show Internal Structure
input string  InpInternalBull         = "All";          // Bullish Internal: All / BOS / CHoCH
input color   InpInternalBullColor    = 0x089981;       // Internal Bull Color
input string  InpInternalBear         = "All";          // Bearish Internal: All / BOS / CHoCH
input color   InpInternalBearColor    = 0xF23645;       // Internal Bear Color
input bool    InpConfluenceFilter     = false;          // Confluence Filter
input string  InpInternalLabelSize   = "Tiny";         // Internal Label Size

//--- Inputs: Swing Structure
input bool    InpShowStructure        = true;           // Show Swing Structure
input string  InpSwingBull            = "All";          // Bullish Swing: All / BOS / CHoCH
input color   InpSwingBullColor       = 0x089981;       // Swing Bull Color
input string  InpSwingBear            = "All";          // Bearish Swing: All / BOS / CHoCH
input color   InpSwingBearColor       = 0xF23645;       // Swing Bear Color
input string  InpSwingLabelSize       = "Small";        // Swing Label Size
input bool    InpShowSwingPoints      = false;          // Show Swing Points
input int     InpSwingsLength         = 50;             // Swings Detection Length (min 10)
input bool    InpShowHighLowSwings    = true;           // Show Strong/Weak High/Low

//--- Inputs: Order Blocks
input bool    InpShowInternalOB       = true;           // Internal Order Blocks
input int     InpInternalOBSize       = 5;              // Internal OB Count (1-20)
input bool    InpShowSwingOB          = false;          // Swing Order Blocks
input int     InpSwingOBSize          = 5;              // Swing OB Count (1-20)
input string  InpOBFilter             = "Atr";          // OB Filter: Atr / Cumulative Mean Range
input string  InpOBMitigation         = "High/Low";    // OB Mitigation: Close / High/Low
input color   InpInternalBullOBColor  = 0x3179f5;      // Internal Bullish OB Color
input color   InpInternalBearOBColor  = 0xf77c80;      // Internal Bearish OB Color
input color   InpSwingBullOBColor     = 0x1848cc;      // Swing Bullish OB Color
input color   InpSwingBearOBColor     = 0xb22833;      // Swing Bearish OB Color

//--- Inputs: EQH/EQL
input bool    InpShowEqualHL          = true;           // Equal High/Low
input int     InpEqualHLLength        = 3;              // Bars Confirmation
input double  InpEqualHLThreshold     = 0.1;           // Threshold (0-0.5)
input string  InpEqualHLLabelSize     = "Tiny";        // EQH/EQL Label Size

//--- Inputs: Fair Value Gaps
input bool    InpShowFVG              = false;          // Fair Value Gaps
input bool    InpFVGAutoThreshold     = true;           // Auto Threshold
input color   InpFVGBullColor         = 0x00ff68;      // Bullish FVG Color
input color   InpFVGBearColor         = 0xff0008;      // Bearish FVG Color
input int     InpFVGExtend            = 1;              // Extend FVG (bars)

//--- Inputs: MTF Levels
input bool    InpShowDailyLevels      = false;          // Daily Levels
input string  InpDailyStyle           = "Solid";       // Daily Style
input color   InpDailyColor           = 0x2157f3;      // Daily Color
input bool    InpShowWeeklyLevels     = false;          // Weekly Levels
input string  InpWeeklyStyle          = "Solid";       // Weekly Style
input color   InpWeeklyColor          = 0x2157f3;      // Weekly Color
input bool    InpShowMonthlyLevels    = false;          // Monthly Levels
input string  InpMonthlyStyle         = "Solid";       // Monthly Style
input color   InpMonthlyColor         = 0x2157f3;      // Monthly Color

//--- Inputs: Premium/Discount Zones
input bool    InpShowPDZones          = false;          // Premium/Discount Zones
input color   InpPremiumColor         = 0xF23645;      // Premium Zone Color
input color   InpEquilibriumColor     = 0x878b94;      // Equilibrium Zone Color
input color   InpDiscountColor        = 0x089981;      // Discount Zone Color

//+------------------------------------------------------------------+
//| Global State                                                      |
//+------------------------------------------------------------------+

// Leg detection
int g_swingLeg       = 0;  // 0=bearish leg, 1=bullish leg
int g_internalLeg    = 0;

// Swing pivots
double g_swingHighLevel     = 0, g_swingHighLast     = 0;
bool   g_swingHighCrossed   = false;
int    g_swingHighBar       = 0;

double g_swingLowLevel      = 0, g_swingLowLast      = 0;
bool   g_swingLowCrossed    = false;
int    g_swingLowBar        = 0;

// Internal pivots
double g_intHighLevel       = 0, g_intHighLast        = 0;
bool   g_intHighCrossed     = false;
int    g_intHighBar         = 0;

double g_intLowLevel        = 0, g_intLowLast         = 0;
bool   g_intLowCrossed      = false;
int    g_intLowBar          = 0;

// Equal pivots
double g_eqHighLevel        = 0, g_eqHighLast         = 0;
int    g_eqHighBar          = 0;
double g_eqLowLevel         = 0, g_eqLowLast          = 0;
int    g_eqLowBar           = 0;

// Trend
int    g_swingTrend         = 0;  // +1 bull, -1 bear
int    g_internalTrend      = 0;

// Trailing extremes
double g_trailingTop        = 0;
double g_trailingBottom     = 1e10;
int    g_trailingBar        = 0;
int    g_trailingTopBar     = 0;
int    g_trailingBottomBar  = 0;
int    g_trailingBarIndex   = 0;

// Previous leg values for change detection
int    g_prevSwingLeg       = -1;
int    g_prevInternalLeg    = -1;

// ATR array for volatility
double g_atrBuffer[];
double g_cumVolatility      = 0;
int    g_cumBars            = 0;

// Arrays for parsed highs/lows and times (bar-indexed from oldest)
double g_parsedHighs[];
double g_parsedLows[];
double g_highs[];
double g_lows[];
datetime g_times[];

// Order blocks storage (max 100 each)
#define MAX_OB 100
struct OrderBlock {
   double high;
   double low;
   datetime barTime;
   int    bias;      // +1 bull, -1 bear
   bool   active;
};
OrderBlock g_swingOBs[MAX_OB];
OrderBlock g_intOBs[MAX_OB];
int g_swingOBCount   = 0;
int g_intOBCount     = 0;

// FVG storage
#define MAX_FVG 50
struct FVG {
   double top;
   double bottom;
   int    bias;
   bool   active;
   int    startBar;
   int    endBar;
};
FVG g_fvgs[MAX_FVG];
int g_fvgCount = 0;

// Object name counters
int g_objCount = 0;

// MTF levels state
double g_dailyHigh   = 0, g_dailyLow   = 1e10;
double g_weeklyHigh  = 0, g_weeklyLow  = 1e10;
double g_monthlyHigh = 0, g_monthlyLow = 1e10;

datetime g_lastDailyTime   = 0;
datetime g_lastWeeklyTime  = 0;
datetime g_lastMonthlyTime = 0;

// prev bar count to detect new bars
int g_prevBars = 0;

//+------------------------------------------------------------------+
//| Helper: Color with alpha (MQL4 has no native alpha, approximate) |
//+------------------------------------------------------------------+
color ColorWithAlpha(color clr, int alpha80pct)
{
   // MQL4 boxes don't support transparency natively in older builds
   // We return the color as-is (transparency handled via OBJPROP_BACK)
   return clr;
}

//+------------------------------------------------------------------+
//| Helper: unique object name                                        |
//+------------------------------------------------------------------+
string ObjName(string prefix)
{
   g_objCount++;
   return prefix + IntegerToString(g_objCount);
}

//+------------------------------------------------------------------+
//| Helper: label size string → MQL4 font size                       |
//+------------------------------------------------------------------+
int LabelFontSize(string sz)
{
   if(sz == "Tiny")   return 7;
   if(sz == "Small")  return 8;
   return 9; // Normal
}

//+------------------------------------------------------------------+
//| Helper: effective swing bull/bear colors                          |
//+------------------------------------------------------------------+
color SwingBullColor() { return InpStyle=="Monochrome" ? (color)CLR_MONO_BULL : InpSwingBullColor; }
color SwingBearColor() { return InpStyle=="Monochrome" ? (color)CLR_MONO_BEAR : InpSwingBearColor; }
color IntBullColor()   { return InpStyle=="Monochrome" ? (color)CLR_MONO_BULL : InpInternalBullColor; }
color IntBearColor()   { return InpStyle=="Monochrome" ? (color)CLR_MONO_BEAR : InpInternalBearColor; }

//+------------------------------------------------------------------+
//| Helper: draw horizontal line from bar A to bar B at price level  |
//+------------------------------------------------------------------+
void DrawStructureLine(int fromBar, int toBar, double price, color clr, bool dashed, string namePrefix)
{
   string nm = ObjName(namePrefix + "_L");
   datetime t1 = Time[fromBar];
   datetime t2 = Time[toBar];
   if(t1 > t2) { datetime tmp=t1; t1=t2; t2=tmp; }

   ObjectCreate(0, nm, OBJ_TREND, 0, t1, price, t2, price);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, nm, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, nm, OBJPROP_STYLE, dashed ? STYLE_DASH : STYLE_SOLID);
   ObjectSetInteger(0, nm, OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
//| Helper: draw text label at bar/price                              |
//+------------------------------------------------------------------+
void DrawLabel(int bar, double price, string text, color clr, bool above, int fontSize)
{
   string nm = ObjName("LBL");
   ObjectCreate(0, nm, OBJ_TEXT, 0, Time[bar], price);
   ObjectSetString(0, nm, OBJPROP_TEXT, text);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, nm, OBJPROP_ANCHOR, above ? ANCHOR_LOWER : ANCHOR_UPPER);
   ObjectSetInteger(0, nm, OBJPROP_BACK, false);
}

//+------------------------------------------------------------------+
//| Helper: draw rectangle box between two bars and two prices        |
//+------------------------------------------------------------------+
string DrawBox(int bar1, int bar2, double top, double bottom, color clr, bool border)
{
   string nm = ObjName("BOX");
   datetime t1 = Time[MathMax(bar1,bar2)]; // older bar = left
   datetime t2 = Time[MathMin(bar1,bar2)]; // newer bar = right (smaller index)
   if(t1 < t2) { datetime tmp=t1; t1=t2; t2=tmp; }

   ObjectCreate(0, nm, OBJ_RECTANGLE, 0, t1, top, t2, bottom);
   ObjectSetInteger(0, nm, OBJPROP_COLOR,   border ? clr : clrNONE);
   ObjectSetInteger(0, nm, OBJPROP_BGCOLOR, clr); // not available in all builds via text, using color
   ObjectSetInteger(0, nm, OBJPROP_BACK,    true);
   ObjectSetInteger(0, nm, OBJPROP_FILL,    true);
   return nm;
}

//+------------------------------------------------------------------+
//| ATR(200) manual calculation                                       |
//+------------------------------------------------------------------+
double CalcATR(int period, int shift)
{
   if(Bars < period + shift + 2) return 0;
   double sum = 0;
   for(int i = shift; i < shift + period; i++)
   {
      double tr = MathMax(High[i], Close[i+1]) - MathMin(Low[i], Close[i+1]);
      sum += tr;
   }
   return sum / period;
}

//+------------------------------------------------------------------+
//| Highest High in last N bars (shift=0 means current bar)          |
//+------------------------------------------------------------------+
double HighestHigh(int count, int startBar)
{
   double h = -1e10;
   for(int i = startBar; i < startBar + count; i++)
      if(i < Bars) h = MathMax(h, High[i]);
   return h;
}
double LowestLow(int count, int startBar)
{
   double l = 1e10;
   for(int i = startBar; i < startBar + count; i++)
      if(i < Bars) l = MathMin(l, Low[i]);
   return l;
}

//+------------------------------------------------------------------+
//| Leg detection: returns 0 (bearish) or 1 (bullish)                |
//| Mirrors Pine: high[size] > highest(size) → bearish leg           |
//|               low[size]  < lowest(size)  → bullish leg           |
//+------------------------------------------------------------------+
int CalcLeg(int size, int currentBar)
{
   static int lastLeg = 0;
   if(currentBar + size >= Bars) return lastLeg;

   double pivH = High[currentBar + size];
   double pivL = Low[currentBar + size];

   // highest of last `size` bars starting at currentBar
   double highestRecent = HighestHigh(size, currentBar);
   double lowestRecent  = LowestLow(size, currentBar);

   if(pivH > highestRecent)
      lastLeg = 0; // bearish leg
   else if(pivL < lowestRecent)
      lastLeg = 1; // bullish leg

   return lastLeg;
}

//+------------------------------------------------------------------+
//| Draw structure line + label for BOS / CHoCH                      |
//+------------------------------------------------------------------+
void DrawStructure(int pivotBar, double pivotLevel, int currentBar,
                   string tag, color clr, bool dashed, string labelSize)
{
   int fromBar = pivotBar;
   int toBar   = currentBar;
   DrawStructureLine(fromBar, toBar, pivotLevel, clr, dashed, "STR");

   int midBar = (fromBar + toBar) / 2;
   bool above = (tag == "BOS" || tag == "CHoCH") ? false : true;
   DrawLabel(midBar, pivotLevel, tag, clr, !dashed, LabelFontSize(labelSize));
}

//+------------------------------------------------------------------+
//| EQH/EQL line + label                                             |
//+------------------------------------------------------------------+
void DrawEqualHL(double prevLevel, int prevBar, double curLevel, int curBar,
                 bool isHigh, color clr, string labelSize)
{
   DrawStructureLine(prevBar, curBar, curLevel, clr, true, "EQ");
   int midBar = (prevBar + curBar) / 2;
   DrawLabel(midBar, curLevel, isHigh ? "EQH" : "EQL", clr, !isHigh, LabelFontSize(labelSize));
}

//+------------------------------------------------------------------+
//| Store order block                                                  |
//+------------------------------------------------------------------+
void StoreOB(bool internal, int bias, int pivotBar, int currentBar)
{
   // Find the highest parsedHigh (for bearish OB) or lowest parsedLow (for bullish OB)
   // between pivotBar and currentBar in our arrays
   // pivotBar is older (higher index), currentBar is newer (lower index)
   int older = MathMax(pivotBar, currentBar);
   int newer = MathMin(pivotBar, currentBar);

   double atr  = CalcATR(200, 0);
   double cumMean = (g_cumBars > 0) ? g_cumVolatility / g_cumBars : atr;
   double volMeasure = (InpOBFilter == "Atr") ? atr : cumMean;

   int    bestBar   = older;
   double bestVal   = (bias == 1) ? 1e10 : -1e10;

   for(int i = newer; i <= older && i < Bars; i++)
   {
      bool highVol = (High[i] - Low[i]) >= 2.0 * volMeasure;
      double pH = highVol ? Low[i]  : High[i]; // parsedHigh
      double pL = highVol ? High[i] : Low[i];  // parsedLow

      if(bias == -1) // bearish OB → max parsedHigh
      {
         if(pH > bestVal) { bestVal = pH; bestBar = i; }
      }
      else // bullish OB → min parsedLow
      {
         if(pL < bestVal) { bestVal = pL; bestBar = i; }
      }
   }

   OrderBlock ob;
   ob.high    = High[bestBar];
   ob.low     = Low[bestBar];
   ob.barTime = Time[bestBar];
   ob.bias    = bias;
   ob.active  = true;

   if(internal)
   {
      if(g_intOBCount < MAX_OB)
      {
         // shift array right and insert at front
         for(int k = MathMin(g_intOBCount, MAX_OB-2); k >= 0; k--)
            g_intOBs[k+1] = g_intOBs[k];
         g_intOBs[0] = ob;
         if(g_intOBCount < MAX_OB) g_intOBCount++;
      }
   }
   else
   {
      if(g_swingOBCount < MAX_OB)
      {
         for(int k = MathMin(g_swingOBCount, MAX_OB-2); k >= 0; k--)
            g_swingOBs[k+1] = g_swingOBs[k];
         g_swingOBs[0] = ob;
         if(g_swingOBCount < MAX_OB) g_swingOBCount++;
      }
   }
}

//+------------------------------------------------------------------+
//| Delete mitigated order blocks                                     |
//+------------------------------------------------------------------+
void DeleteMitigatedOBs(bool internal)
{
   int count = internal ? g_intOBCount : g_swingOBCount;
   OrderBlock *obs = internal ? g_intOBs : g_swingOBs;

   double mitigHigh = (InpOBMitigation == "Close") ? Close[0] : High[0];
   double mitigLow  = (InpOBMitigation == "Close") ? Close[0] : Low[0];

   for(int i = 0; i < count; i++)
   {
      if(!obs[i].active) continue;
      if(obs[i].bias == -1 && mitigHigh > obs[i].high)
         obs[i].active = false;
      else if(obs[i].bias == 1 && mitigLow < obs[i].low)
         obs[i].active = false;
   }
}

//+------------------------------------------------------------------+
//| Draw order block boxes (called on each tick/bar)                  |
//+------------------------------------------------------------------+
void DrawOBBoxes(bool internal)
{
   // Delete old OB box objects
   string prefix = internal ? "INTOB" : "SWOB";
   for(int i = ObjectsTotal(0)-1; i >= 0; i--)
   {
      string nm = ObjectName(0, i);
      if(StringFind(nm, prefix) == 0)
         ObjectDelete(0, nm);
   }

   int count   = internal ? g_intOBCount : g_swingOBCount;
   int maxShow = internal ? InpInternalOBSize : InpSwingOBSize;
   OrderBlock *obs = internal ? g_intOBs : g_swingOBs;

   int shown = 0;
   for(int i = 0; i < count && shown < maxShow; i++)
   {
      if(!obs[i].active) continue;
      shown++;

      color obClr;
      if(InpStyle == "Monochrome")
         obClr = obs[i].bias == -1 ? (color)CLR_MONO_BEAR : (color)CLR_MONO_BULL;
      else if(internal)
         obClr = obs[i].bias == -1 ? InpInternalBearOBColor : InpInternalBullOBColor;
      else
         obClr = obs[i].bias == -1 ? InpSwingBearOBColor : InpSwingBullOBColor;

      // Find bar index for obs[i].barTime
      int startBar = iBarShift(NULL, 0, obs[i].barTime, false);
      if(startBar < 0) startBar = Bars - 1;

      string nm = prefix + IntegerToString(i) + "_" + IntegerToString(g_objCount++);
      ObjectCreate(0, nm, OBJ_RECTANGLE, 0,
                   obs[i].barTime,       obs[i].high,
                   Time[0] + PeriodSeconds(), obs[i].low);
      ObjectSetInteger(0, nm, OBJPROP_COLOR,  internal ? clrNONE : obClr);
      ObjectSetInteger(0, nm, OBJPROP_BACK,   true);
      ObjectSetInteger(0, nm, OBJPROP_FILL,   true);
      ObjectSetInteger(0, nm, OBJPROP_WIDTH,  1);
      // Simulate color with partial transparency by using back drawing
      ObjectSetInteger(0, nm, OBJPROP_COLOR, obClr);
   }
}

//+------------------------------------------------------------------+
//| Delete mitigated FVGs                                             |
//+------------------------------------------------------------------+
void DeleteMitigatedFVGs()
{
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(!g_fvgs[i].active) continue;
      if(g_fvgs[i].bias == 1 && Low[0] < g_fvgs[i].bottom)
         g_fvgs[i].active = false;
      else if(g_fvgs[i].bias == -1 && High[0] > g_fvgs[i].top)
         g_fvgs[i].active = false;
   }
}

//+------------------------------------------------------------------+
//| Detect and store FVGs                                             |
//+------------------------------------------------------------------+
void DetectFVGs(int bar)
{
   // Need bars bar, bar+1, bar+2
   if(bar + 2 >= Bars) return;

   double atr = CalcATR(14, bar);
   // bar   = current (candle 0 in original = most recent formed bar)
   // bar+1 = previous (middle candle)
   // bar+2 = two bars ago

   // Bullish FVG: low[0] > high[2] and close[1] > high[2]
   bool bullFVG = Low[bar] > High[bar+2] && Close[bar+1] > High[bar+2];
   // Bearish FVG: high[0] < low[2] and close[1] < low[2]
   bool bearFVG = High[bar] < Low[bar+2] && Close[bar+1] < Low[bar+2];

   if(InpFVGAutoThreshold)
   {
      double threshold = atr * 0.1;
      if(bullFVG) bullFVG = (Low[bar] - High[bar+2]) > threshold;
      if(bearFVG) bearFVG = (Low[bar+2] - High[bar]) > threshold;
   }

   if(bullFVG && g_fvgCount < MAX_FVG)
   {
      FVG fvg;
      fvg.top      = Low[bar];
      fvg.bottom   = High[bar+2];
      fvg.bias     = 1;
      fvg.active   = true;
      fvg.startBar = bar+2;
      fvg.endBar   = bar;
      // Shift and insert
      for(int k = MathMin(g_fvgCount, MAX_FVG-2); k >= 0; k--)
         g_fvgs[k+1] = g_fvgs[k];
      g_fvgs[0] = fvg;
      if(g_fvgCount < MAX_FVG) g_fvgCount++;
   }
   if(bearFVG && g_fvgCount < MAX_FVG)
   {
      FVG fvg;
      fvg.top      = Low[bar+2];
      fvg.bottom   = High[bar];
      fvg.bias     = -1;
      fvg.active   = true;
      fvg.startBar = bar+2;
      fvg.endBar   = bar;
      for(int k = MathMin(g_fvgCount, MAX_FVG-2); k >= 0; k--)
         g_fvgs[k+1] = g_fvgs[k];
      g_fvgs[0] = fvg;
      if(g_fvgCount < MAX_FVG) g_fvgCount++;
   }
}

//+------------------------------------------------------------------+
//| Draw FVG boxes                                                    |
//+------------------------------------------------------------------+
void DrawFVGs()
{
   // Remove old
   for(int i = ObjectsTotal(0)-1; i >= 0; i--)
   {
      if(StringFind(ObjectName(0,i), "FVG") == 0)
         ObjectDelete(0, ObjectName(0,i));
   }

   for(int i = 0; i < g_fvgCount; i++)
   {
      if(!g_fvgs[i].active) continue;
      color clr = g_fvgs[i].bias == 1 ?
                  (InpStyle=="Monochrome" ? (color)CLR_MONO_BULL : InpFVGBullColor) :
                  (InpStyle=="Monochrome" ? (color)CLR_MONO_BEAR : InpFVGBearColor);

      datetime t1 = Time[g_fvgs[i].startBar];
      datetime t2 = Time[0] + (datetime)(InpFVGExtend * PeriodSeconds());
      double mid  = 0.5 * (g_fvgs[i].top + g_fvgs[i].bottom);

      string nm1 = ObjName("FVG_T");
      ObjectCreate(0, nm1, OBJ_RECTANGLE, 0, t1, g_fvgs[i].top, t2, mid);
      ObjectSetInteger(0, nm1, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, nm1, OBJPROP_BACK,  true);
      ObjectSetInteger(0, nm1, OBJPROP_FILL,  true);

      string nm2 = ObjName("FVG_B");
      ObjectCreate(0, nm2, OBJ_RECTANGLE, 0, t1, mid, t2, g_fvgs[i].bottom);
      ObjectSetInteger(0, nm2, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, nm2, OBJPROP_BACK,  true);
      ObjectSetInteger(0, nm2, OBJPROP_FILL,  true);
   }
}

//+------------------------------------------------------------------+
//| Draw MTF levels                                                   |
//+------------------------------------------------------------------+
void DrawMTFLevel(double hi, double lo, string label, color clr, string style, string prefix)
{
   // Remove old
   for(int i = ObjectsTotal(0)-1; i >= 0; i--)
      if(StringFind(ObjectName(0,i), prefix) == 0)
         ObjectDelete(0, ObjectName(0,i));

   int lineStyle = STYLE_SOLID;
   if(style == "Dashed") lineStyle = STYLE_DASH;
   if(style == "Dotted") lineStyle = STYLE_DOT;

   datetime now = Time[0] + (datetime)(20 * PeriodSeconds());

   string nmH = prefix + "_H";
   ObjectCreate(0, nmH, OBJ_TREND, 0, Time[Bars-1], hi, now, hi);
   ObjectSetInteger(0, nmH, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, nmH, OBJPROP_STYLE, lineStyle);
   ObjectSetInteger(0, nmH, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, nmH, OBJPROP_BACK,  true);

   string nmL = prefix + "_L";
   ObjectCreate(0, nmL, OBJ_TREND, 0, Time[Bars-1], lo, now, lo);
   ObjectSetInteger(0, nmL, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, nmL, OBJPROP_STYLE, lineStyle);
   ObjectSetInteger(0, nmL, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, nmL, OBJPROP_BACK,  true);

   ObjectCreate(0, prefix+"_TXT_H", OBJ_TEXT, 0, now, hi);
   ObjectSetString(0, prefix+"_TXT_H", OBJPROP_TEXT, "P"+label+"H");
   ObjectSetInteger(0, prefix+"_TXT_H", OBJPROP_COLOR, clr);
   ObjectSetInteger(0, prefix+"_TXT_H", OBJPROP_FONTSIZE, 7);

   ObjectCreate(0, prefix+"_TXT_L", OBJ_TEXT, 0, now, lo);
   ObjectSetString(0, prefix+"_TXT_L", OBJPROP_TEXT, "P"+label+"L");
   ObjectSetInteger(0, prefix+"_TXT_L", OBJPROP_COLOR, clr);
   ObjectSetInteger(0, prefix+"_TXT_L", OBJPROP_FONTSIZE, 7);
}

//+------------------------------------------------------------------+
//| Update MTF high/low levels from higher timeframe                  |
//+------------------------------------------------------------------+
void UpdateMTFLevels()
{
   if(InpShowDailyLevels)
   {
      double dH = iHigh(NULL, PERIOD_D1, 1);
      double dL = iLow(NULL,  PERIOD_D1, 1);
      if(dH > 0) DrawMTFLevel(dH, dL, "D", InpDailyColor, InpDailyStyle, "MTF_D");
   }
   if(InpShowWeeklyLevels)
   {
      double wH = iHigh(NULL, PERIOD_W1, 1);
      double wL = iLow(NULL,  PERIOD_W1, 1);
      if(wH > 0) DrawMTFLevel(wH, wL, "W", InpWeeklyColor, InpWeeklyStyle, "MTF_W");
   }
   if(InpShowMonthlyLevels)
   {
      double mH = iHigh(NULL, PERIOD_MN1, 1);
      double mL = iLow(NULL,  PERIOD_MN1, 1);
      if(mH > 0) DrawMTFLevel(mH, mL, "M", InpMonthlyColor, InpMonthlyStyle, "MTF_M");
   }
}

//+------------------------------------------------------------------+
//| Premium / Discount Zones                                          |
//+------------------------------------------------------------------+
void DrawPDZones()
{
   if(!InpShowPDZones) return;
   if(g_trailingTop == 0 || g_trailingBottom >= 1e9) return;

   double top = g_trailingTop;
   double bot = g_trailingBottom;

   // Remove old
   for(int i = ObjectsTotal(0)-1; i >= 0; i--)
      if(StringFind(ObjectName(0,i), "PDZ_") == 0)
         ObjectDelete(0, ObjectName(0,i));

   datetime t1 = Time[g_trailingBar > 0 ? g_trailingBar : Bars-1];
   datetime t2 = Time[0] + (datetime)(20 * PeriodSeconds());

   // Premium (top 5%)
   double premTop = top;
   double premBot = 0.95*top + 0.05*bot;
   string pnm = "PDZ_PREM";
   ObjectCreate(0, pnm, OBJ_RECTANGLE, 0, t1, premTop, t2, premBot);
   ObjectSetInteger(0, pnm, OBJPROP_COLOR, InpStyle=="Monochrome"?(color)CLR_MONO_BEAR:InpPremiumColor);
   ObjectSetInteger(0, pnm, OBJPROP_BACK,  true);
   ObjectSetInteger(0, pnm, OBJPROP_FILL,  true);

   // Equilibrium (middle 5%)
   double eqTop = 0.525*top + 0.475*bot;
   double eqBot = 0.525*bot + 0.475*top;
   string enm = "PDZ_EQ";
   ObjectCreate(0, enm, OBJ_RECTANGLE, 0, t1, eqTop, t2, eqBot);
   ObjectSetInteger(0, enm, OBJPROP_COLOR, InpStyle=="Monochrome"?(color)CLR_GRAY:InpEquilibriumColor);
   ObjectSetInteger(0, enm, OBJPROP_BACK,  true);
   ObjectSetInteger(0, enm, OBJPROP_FILL,  true);

   // Discount (bottom 5%)
   double disTop = 0.05*top + 0.95*bot;
   double disBot = bot;
   string dnm = "PDZ_DIS";
   ObjectCreate(0, dnm, OBJ_RECTANGLE, 0, t1, disTop, t2, disBot);
   ObjectSetInteger(0, dnm, OBJPROP_COLOR, InpStyle=="Monochrome"?(color)CLR_MONO_BULL:InpDiscountColor);
   ObjectSetInteger(0, dnm, OBJPROP_BACK,  true);
   ObjectSetInteger(0, dnm, OBJPROP_FILL,  true);

   // Labels
   ObjectCreate(0, "PDZ_TXT_P", OBJ_TEXT, 0, t2, 0.5*(premTop+premBot));
   ObjectSetString(0, "PDZ_TXT_P", OBJPROP_TEXT, "Premium");
   ObjectSetInteger(0, "PDZ_TXT_P", OBJPROP_COLOR, InpStyle=="Monochrome"?(color)CLR_MONO_BEAR:InpPremiumColor);
   ObjectSetInteger(0, "PDZ_TXT_P", OBJPROP_FONTSIZE, 8);

   ObjectCreate(0, "PDZ_TXT_E", OBJ_TEXT, 0, t2, 0.5*(eqTop+eqBot));
   ObjectSetString(0, "PDZ_TXT_E", OBJPROP_TEXT, "Equilibrium");
   ObjectSetInteger(0, "PDZ_TXT_E", OBJPROP_COLOR, InpStyle=="Monochrome"?(color)CLR_GRAY:InpEquilibriumColor);
   ObjectSetInteger(0, "PDZ_TXT_E", OBJPROP_FONTSIZE, 8);

   ObjectCreate(0, "PDZ_TXT_D", OBJ_TEXT, 0, t2, 0.5*(disTop+disBot));
   ObjectSetString(0, "PDZ_TXT_D", OBJPROP_TEXT, "Discount");
   ObjectSetInteger(0, "PDZ_TXT_D", OBJPROP_COLOR, InpStyle=="Monochrome"?(color)CLR_MONO_BULL:InpDiscountColor);
   ObjectSetInteger(0, "PDZ_TXT_D", OBJPROP_FONTSIZE, 8);
}

//+------------------------------------------------------------------+
//| Process one bar: swing structure + internal structure             |
//+------------------------------------------------------------------+
void ProcessBar(int bar)
{
   // Update cumulative volatility
   if(bar < Bars-1)
   {
      double tr = MathMax(High[bar], Close[bar+1]) - MathMin(Low[bar], Close[bar+1]);
      g_cumVolatility += tr;
      g_cumBars++;
   }

   double atr = CalcATR(200, bar);
   double cumMean = (g_cumBars > 0) ? g_cumVolatility / g_cumBars : atr;
   double volMeasure = (InpOBFilter == "Atr") ? atr : cumMean;
   bool highVolBar = (High[bar] - Low[bar]) >= 2.0 * volMeasure;

   //--- Update trailing extremes
   if(InpShowHighLowSwings || InpShowPDZones)
   {
      if(High[bar] > g_trailingTop)
      {
         g_trailingTop    = High[bar];
         g_trailingTopBar = bar;
      }
      if(Low[bar] < g_trailingBottom)
      {
         g_trailingBottom    = Low[bar];
         g_trailingBottomBar = bar;
      }
   }

   //=== SWING STRUCTURE (size = InpSwingsLength) ===
   {
      int size = InpSwingsLength;
      if(bar + size < Bars)
      {
         int prevLeg = g_swingLeg;
         double pivH = High[bar + size];
         double pivL = Low[bar + size];
         double highestR = HighestHigh(size, bar);
         double lowestR  = LowestLow(size, bar);

         if(pivH > highestR)      g_swingLeg = 0; // bearish
         else if(pivL < lowestR)  g_swingLeg = 1; // bullish

         bool newPivot   = (g_swingLeg != prevLeg);
         bool pivotLow   = newPivot && (g_swingLeg == 1) && (prevLeg == 0);
         bool pivotHigh  = newPivot && (g_swingLeg == 0) && (prevLeg == 1);

         if(pivotLow)
         {
            // EQL check
            if(InpShowEqualHL && g_eqLowLevel != 0 &&
               MathAbs(g_eqLowLevel - Low[bar+size]) < InpEqualHLThreshold * atr)
            {
               DrawEqualHL(g_eqLowLevel, g_eqLowBar, Low[bar+size], bar+size,
                           false, SwingBullColor(), InpEqualHLLabelSize);
            }

            g_eqLowLast  = g_eqLowLevel;
            g_eqLowLevel = Low[bar+size];
            g_eqLowBar   = bar+size;

            if(g_swingLowLevel == 0) { g_swingLowLevel = Low[bar+size]; g_swingLowBar = bar+size; }

            g_trailingBottom    = Low[bar+size];
            g_trailingBottomBar = bar+size;
            g_trailingBar       = bar+size;
            g_trailingBarIndex  = bar+size;

            if(InpShowSwingPoints)
            {
               bool isLL = (g_swingLowLevel > 0 && Low[bar+size] < g_swingLowLevel);
               DrawLabel(bar+size, Low[bar+size], isLL ? "LL" : "HL",
                         SwingBullColor(), true, LabelFontSize(InpSwingLabelSize));
            }

            g_swingLowLast  = g_swingLowLevel;
            g_swingLowLevel = Low[bar+size];
            g_swingLowBar   = bar+size;
            g_swingLowCrossed = false;
         }
         else if(pivotHigh)
         {
            // EQH check
            if(InpShowEqualHL && g_eqHighLevel != 0 &&
               MathAbs(g_eqHighLevel - High[bar+size]) < InpEqualHLThreshold * atr)
            {
               DrawEqualHL(g_eqHighLevel, g_eqHighBar, High[bar+size], bar+size,
                           true, SwingBearColor(), InpEqualHLLabelSize);
            }

            g_eqHighLast  = g_eqHighLevel;
            g_eqHighLevel = High[bar+size];
            g_eqHighBar   = bar+size;

            g_trailingTop    = High[bar+size];
            g_trailingTopBar = bar+size;
            g_trailingBar    = bar+size;

            if(InpShowSwingPoints)
            {
               bool isHH = (g_swingHighLevel > 0 && High[bar+size] > g_swingHighLevel);
               DrawLabel(bar+size, High[bar+size], isHH ? "HH" : "LH",
                         SwingBearColor(), false, LabelFontSize(InpSwingLabelSize));
            }

            g_swingHighLast  = g_swingHighLevel;
            g_swingHighLevel = High[bar+size];
            g_swingHighBar   = bar+size;
            g_swingHighCrossed = false;
         }
      }
   }

   //=== INTERNAL STRUCTURE (size = 5) ===
   {
      int size = 5;
      if(bar + size < Bars)
      {
         int prevLeg = g_internalLeg;
         double pivH = High[bar + size];
         double pivL = Low[bar + size];
         double highestR = HighestHigh(size, bar);
         double lowestR  = LowestLow(size, bar);

         if(pivH > highestR)      g_internalLeg = 0;
         else if(pivL < lowestR)  g_internalLeg = 1;

         bool newPivot  = (g_internalLeg != prevLeg);
         bool pivotLow  = newPivot && (g_internalLeg == 1) && (prevLeg == 0);
         bool pivotHigh = newPivot && (g_internalLeg == 0) && (prevLeg == 1);

         if(pivotLow)
         {
            g_intLowLast    = g_intLowLevel;
            g_intLowLevel   = Low[bar+size];
            g_intLowBar     = bar+size;
            g_intLowCrossed = false;
         }
         else if(pivotHigh)
         {
            g_intHighLast    = g_intHighLevel;
            g_intHighLevel   = High[bar+size];
            g_intHighBar     = bar+size;
            g_intHighCrossed = false;
         }
      }
   }

   //=== SWING STRUCTURE BREAK DETECTION ===
   if((InpShowStructure || InpShowSwingOB || InpShowHighLowSwings) && g_swingHighLevel > 0)
   {
      // Bullish break: close crosses above swing high
      if(Close[bar] > g_swingHighLevel && !g_swingHighCrossed)
      {
         string tag = (g_swingTrend == -1) ? "CHoCH" : "BOS";
         bool display = InpShowStructure &&
            (InpSwingBull == "All" ||
             (InpSwingBull == "BOS"   && tag == "BOS") ||
             (InpSwingBull == "CHoCH" && tag == "CHoCH"));

         if(display)
            DrawStructure(g_swingHighBar, g_swingHighLevel, bar,
                          tag, SwingBullColor(), false, InpSwingLabelSize);

         if(InpShowSwingOB)
            StoreOB(false, 1, g_swingHighBar, bar);

         g_swingHighCrossed = true;
         g_swingTrend = 1;
      }
   }

   if((InpShowStructure || InpShowSwingOB) && g_swingLowLevel > 0)
   {
      // Bearish break: close crosses below swing low
      if(Close[bar] < g_swingLowLevel && !g_swingLowCrossed)
      {
         string tag = (g_swingTrend == 1) ? "CHoCH" : "BOS";
         bool display = InpShowStructure &&
            (InpSwingBear == "All" ||
             (InpSwingBear == "BOS"   && tag == "BOS") ||
             (InpSwingBear == "CHoCH" && tag == "CHoCH"));

         if(display)
            DrawStructure(g_swingLowBar, g_swingLowLevel, bar,
                          tag, SwingBearColor(), false, InpSwingLabelSize);

         if(InpShowSwingOB)
            StoreOB(false, -1, g_swingLowBar, bar);

         g_swingLowCrossed = true;
         g_swingTrend = -1;
      }
   }

   //=== INTERNAL STRUCTURE BREAK DETECTION ===
   if((InpShowInternals || InpShowInternalOB) && g_intHighLevel > 0)
   {
      bool extraCond = g_intHighLevel != g_swingHighLevel;
      if(InpConfluenceFilter)
         extraCond = extraCond && (High[bar] - MathMax(Close[bar], Open[bar])) >
                                   (MathMin(Close[bar], Open[bar]) - Low[bar]);

      if(Close[bar] > g_intHighLevel && !g_intHighCrossed && extraCond)
      {
         string tag = (g_internalTrend == -1) ? "CHoCH" : "BOS";
         bool display = InpShowInternals &&
            (InpInternalBull == "All" ||
             (InpInternalBull == "BOS"   && tag == "BOS") ||
             (InpInternalBull == "CHoCH" && tag == "CHoCH"));

         if(display)
            DrawStructure(g_intHighBar, g_intHighLevel, bar,
                          tag, IntBullColor(), true, InpInternalLabelSize);

         if(InpShowInternalOB)
            StoreOB(true, 1, g_intHighBar, bar);

         g_intHighCrossed = true;
         g_internalTrend  = 1;
      }
   }

   if((InpShowInternals || InpShowInternalOB) && g_intLowLevel > 0)
   {
      bool extraCond = g_intLowLevel != g_swingLowLevel;
      if(InpConfluenceFilter)
         extraCond = extraCond && (High[bar] - MathMax(Close[bar], Open[bar])) <
                                   (MathMin(Close[bar], Open[bar]) - Low[bar]);

      if(Close[bar] < g_intLowLevel && !g_intLowCrossed && extraCond)
      {
         string tag = (g_internalTrend == 1) ? "CHoCH" : "BOS";
         bool display = InpShowInternals &&
            (InpInternalBear == "All" ||
             (InpInternalBear == "BOS"   && tag == "BOS") ||
             (InpInternalBear == "CHoCH" && tag == "CHoCH"));

         if(display)
            DrawStructure(g_intLowBar, g_intLowLevel, bar,
                          tag, IntBearColor(), true, InpInternalLabelSize);

         if(InpShowInternalOB)
            StoreOB(true, -1, g_intLowBar, bar);

         g_intLowCrossed = true;
         g_internalTrend = -1;
      }
   }

   //=== FAIR VALUE GAPS ===
   if(InpShowFVG)
      DetectFVGs(bar);
}

//+------------------------------------------------------------------+
//| Strong/Weak High/Low lines                                        |
//+------------------------------------------------------------------+
void DrawHighLowSwings()
{
   if(!InpShowHighLowSwings) return;

   // Remove old
   for(int i = ObjectsTotal(0)-1; i >= 0; i--)
      if(StringFind(ObjectName(0,i), "HLSW_") == 0)
         ObjectDelete(0, ObjectName(0,i));

   if(g_trailingTop == 0 || g_trailingBottom >= 1e9) return;

   datetime now = Time[0] + (datetime)(20 * PeriodSeconds());
   color topClr = SwingBearColor();
   color botClr = SwingBullColor();

   // Top line
   ObjectCreate(0, "HLSW_TL", OBJ_TREND, 0, Time[g_trailingTopBar], g_trailingTop, now, g_trailingTop);
   ObjectSetInteger(0, "HLSW_TL", OBJPROP_COLOR, topClr);
   ObjectSetInteger(0, "HLSW_TL", OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, "HLSW_TL", OBJPROP_BACK, true);
   ObjectCreate(0, "HLSW_TT", OBJ_TEXT, 0, now, g_trailingTop);
   ObjectSetString(0, "HLSW_TT", OBJPROP_TEXT, g_swingTrend == -1 ? "Strong High" : "Weak High");
   ObjectSetInteger(0, "HLSW_TT", OBJPROP_COLOR, topClr);
   ObjectSetInteger(0, "HLSW_TT", OBJPROP_FONTSIZE, 7);

   // Bottom line
   ObjectCreate(0, "HLSW_BL", OBJ_TREND, 0, Time[g_trailingBottomBar], g_trailingBottom, now, g_trailingBottom);
   ObjectSetInteger(0, "HLSW_BL", OBJPROP_COLOR, botClr);
   ObjectSetInteger(0, "HLSW_BL", OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, "HLSW_BL", OBJPROP_BACK, true);
   ObjectCreate(0, "HLSW_BT", OBJ_TEXT, 0, now, g_trailingBottom);
   ObjectSetString(0, "HLSW_BT", OBJPROP_TEXT, g_swingTrend == 1 ? "Strong Low" : "Weak Low");
   ObjectSetInteger(0, "HLSW_BT", OBJPROP_COLOR, botClr);
   ObjectSetInteger(0, "HLSW_BT", OBJPROP_FONTSIZE, 7);
}

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   // Clear all previously created objects by this indicator
   ObjectsDeleteAll(0);
   g_objCount = 0;
   g_swingOBCount = 0;
   g_intOBCount   = 0;
   g_fvgCount     = 0;
   g_trailingTop    = 0;
   g_trailingBottom = 1e10;
   g_swingTrend     = 0;
   g_internalTrend  = 0;
   g_swingHighLevel = 0; g_swingLowLevel = 0;
   g_intHighLevel   = 0; g_intLowLevel   = 0;
   g_eqHighLevel    = 0; g_eqLowLevel    = 0;
   g_cumVolatility  = 0; g_cumBars       = 0;
   g_prevBars       = 0;
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
//| OnCalculate (main entry)                                          |
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
   if(rates_total < InpSwingsLength + 5) return 0;

   // On first full recalculation, process all historical bars
   int startBar;
   if(prev_calculated == 0)
   {
      ObjectsDeleteAll(0);
      g_objCount       = 0;
      g_swingOBCount   = 0;
      g_intOBCount     = 0;
      g_fvgCount       = 0;
      g_trailingTop    = 0;
      g_trailingBottom = 1e10;
      g_swingTrend     = 0;
      g_internalTrend  = 0;
      g_swingHighLevel = 0; g_swingLowLevel = 0;
      g_intHighLevel   = 0; g_intLowLevel   = 0;
      g_eqHighLevel    = 0; g_eqLowLevel    = 0;
      g_cumVolatility  = 0; g_cumBars       = 0;

      // Process from oldest to newest (bar index decreasing)
      startBar = rates_total - 1 - InpSwingsLength;
   }
   else
   {
      startBar = rates_total - prev_calculated;
      if(startBar <= 0) startBar = 1;
   }

   // Process bars from oldest (high index) to newest (index 0)
   // But in MQL4 arrays are indexed 0=current, so we process from startBar down to 0
   // For mode "Present" we only care about recent bars
   int processFrom = (InpMode == "Present") ? MathMin(startBar, 300) : startBar;

   for(int bar = processFrom; bar >= 1; bar--)
   {
      ProcessBar(bar);
   }

   // Mitigation check on latest bars
   if(InpShowInternalOB) DeleteMitigatedOBs(true);
   if(InpShowSwingOB)    DeleteMitigatedOBs(false);
   if(InpShowFVG)        DeleteMitigatedFVGs();

   // Redraw dynamic elements
   DrawHighLowSwings();
   DrawPDZones();

   if(InpShowInternalOB) DrawOBBoxes(true);
   if(InpShowSwingOB)    DrawOBBoxes(false);
   if(InpShowFVG)        DrawFVGs();

   UpdateMTFLevels();

   ChartRedraw(0);
   return rates_total;
}
//+------------------------------------------------------------------+


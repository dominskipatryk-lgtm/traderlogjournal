#property strict
#property indicator_chart_window

// SUPPORT / RESISTANCE HIGH VOLUME BOXES
// MT4 adaptation of the user-provided Pine Script concept:
// Support and Resistance (High Volume Boxes) [ChartPrime], MPL 2.0.

input string SR_SETTINGS       = "===================="; // === SETTINGS ===
input int    LookbackPeriod    = 20;                     // Pivot lookback
input int    DeltaVolumeLength = 2;                      // Delta volume filter length
input double BoxWidthATR       = 1.0;                    // Box width, ATR multiplier
input int    ATRPeriod         = 200;                    // ATR period
input int    HistoryBars       = 1500;                   // Bars to calculate
input int    MaxBoxes          = 50;                     // Max visible boxes

input string SR_VISUALS        = "===================="; // === VISUALS ===
input color  SupportColor      = clrSeaGreen;            // Support color
input color  ResistanceColor   = clrCrimson;             // Resistance color
input color  BrokenSupportColor = clrFireBrick;          // Broken support color
input color  BrokenResistanceColor = clrMediumSeaGreen;  // Broken resistance color
input color  TextColor         = clrWhite;               // Text color
input int    LabelFontSize     = 8;                      // Label font size
input bool   ShowVolumeLabels  = true;                   // Show volume labels
input bool   ShowSignalLabels  = true;                   // Show break labels
input bool   ShowHoldDiamonds  = true;                   // Show hold diamonds
input bool   DrawInBackground  = true;                   // Draw boxes in background
input int    ExtendBarsRight   = 3;                      // Extend boxes right
input bool   EnableAlerts      = false;                  // Alert on fresh break
input string ObjectPrefix      = "SR_HV_BOX_";           // Object prefix

struct SRZone
{
   double   top;
   double   bottom;
   datetime startTime;
   datetime endTime;
   double   vol;
   bool     support;
   bool     broken;
   int      createdShift;
};

SRZone   g_zones[];
datetime g_lastBarTime = 0;
datetime g_lastAlertTime = 0;

int OnInit()
{
   IndicatorShortName("Support / Resistance High Volume Boxes");

   if(LookbackPeriod < 1 || DeltaVolumeLength < 1 || ATRPeriod < 1 ||
      HistoryBars < LookbackPeriod * 3 || MaxBoxes < 1)
   {
      Print("SR HV BOXES: check inputs. Lookback, volume length, ATR, HistoryBars and MaxBoxes must be positive.");
      return(INIT_PARAMETERS_INCORRECT);
   }

   DeleteObjectsByPrefix();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   DeleteObjectsByPrefix();
}

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
   if(rates_total < LookbackPeriod * 2 + ATRPeriod + DeltaVolumeLength + 5)
      return(0);

   if(prev_calculated == 0 || time[0] != g_lastBarTime)
   {
      g_lastBarTime = time[0];
      RebuildIndicator(rates_total, time, open, high, low, close, tick_volume);
   }

   return(rates_total);
}

void RebuildIndicator(const int rates_total,
                      const datetime &time[],
                      const double &open[],
                      const double &high[],
                      const double &low[],
                      const double &close[],
                      const long &tick_volume[])
{
   DeleteObjectsByPrefix();
   ArrayResize(g_zones, 0);

   int maxConfirmShift = MathMin(rates_total - LookbackPeriod - 2,
                                 MathMax(LookbackPeriod + 2, HistoryBars));

   for(int shift = maxConfirmShift; shift >= 0; shift--)
   {
      UpdateExistingZones(shift, rates_total, time, high, low);

      int pivotShift = shift + LookbackPeriod;
      if(pivotShift >= rates_total - LookbackPeriod)
         continue;

      double deltaVol = DeltaVolume(shift, rates_total, open, close, tick_volume);
      double volHi = HighestDeltaDivided(shift, rates_total, open, close, tick_volume);
      double volLo = LowestDeltaDivided(shift, rates_total, open, close, tick_volume);
      double atr = iATR(NULL, 0, ATRPeriod, shift);
      if(atr <= 0.0)
         atr = (high[shift] - low[shift]);

      double width = MathMax(Point, atr * BoxWidthATR);

      if(IsPivotLow(pivotShift, LookbackPeriod, close, rates_total) && deltaVol > volHi)
         AddZone(true, close[pivotShift], close[pivotShift] - width, time[pivotShift], shift, deltaVol);

      if(IsPivotHigh(pivotShift, LookbackPeriod, close, rates_total) && deltaVol < volLo)
         AddZone(false, close[pivotShift] + width, close[pivotShift], time[pivotShift], shift, deltaVol);
   }

   datetime rightEdge = time[0] + PeriodSeconds(PERIOD_CURRENT) * ExtendBarsRight;
   int count = ArraySize(g_zones);
   for(int i = 0; i < count; i++)
   {
      g_zones[i].endTime = rightEdge;
      DrawZone(i);
   }
}

double DeltaVolume(const int shift,
                   const int rates_total,
                   const double &open[],
                   const double &close[],
                   const long &tick_volume[])
{
   if(close[shift] > open[shift])
      return((double)tick_volume[shift]);
   if(close[shift] < open[shift])
      return(-(double)tick_volume[shift]);

   if(shift + 1 < rates_total && close[shift] >= close[shift + 1])
      return((double)tick_volume[shift]);

   return(-(double)tick_volume[shift]);
}

double HighestDeltaDivided(const int shift,
                           const int rates_total,
                           const double &open[],
                           const double &close[],
                           const long &tick_volume[])
{
   double result = -1.0e100;
   int last = MathMin(rates_total - 1, shift + DeltaVolumeLength - 1);
   for(int i = shift; i <= last; i++)
      result = MathMax(result, DeltaVolume(i, rates_total, open, close, tick_volume) / 2.5);
   return(result);
}

double LowestDeltaDivided(const int shift,
                          const int rates_total,
                          const double &open[],
                          const double &close[],
                          const long &tick_volume[])
{
   double result = 1.0e100;
   int last = MathMin(rates_total - 1, shift + DeltaVolumeLength - 1);
   for(int i = shift; i <= last; i++)
      result = MathMin(result, DeltaVolume(i, rates_total, open, close, tick_volume) / 2.5);
   return(result);
}

bool IsPivotHigh(const int shift,
                 const int len,
                 const double &src[],
                 const int rates_total)
{
   if(shift - len < 0 || shift + len >= rates_total)
      return(false);

   double value = src[shift];
   for(int i = 1; i <= len; i++)
   {
      if(src[shift - i] > value || src[shift + i] >= value)
         return(false);
   }
   return(true);
}

bool IsPivotLow(const int shift,
                const int len,
                const double &src[],
                const int rates_total)
{
   if(shift - len < 0 || shift + len >= rates_total)
      return(false);

   double value = src[shift];
   for(int i = 1; i <= len; i++)
   {
      if(src[shift - i] < value || src[shift + i] <= value)
         return(false);
   }
   return(true);
}

void AddZone(const bool support,
             const double top,
             const double bottom,
             const datetime startTime,
             const int createdShift,
             const double vol)
{
   int count = ArraySize(g_zones);
   if(count >= MaxBoxes)
   {
      for(int i = 1; i < count; i++)
         g_zones[i - 1] = g_zones[i];
      count--;
      ArrayResize(g_zones, count);
   }

   ArrayResize(g_zones, count + 1);
   g_zones[count].top = MathMax(top, bottom);
   g_zones[count].bottom = MathMin(top, bottom);
   g_zones[count].startTime = startTime;
   g_zones[count].endTime = startTime;
   g_zones[count].vol = vol;
   g_zones[count].support = support;
   g_zones[count].broken = false;
   g_zones[count].createdShift = createdShift;
}

void UpdateExistingZones(const int shift,
                         const int rates_total,
                         const datetime &time[],
                         const double &high[],
                         const double &low[])
{
   int count = ArraySize(g_zones);
   if(shift + 1 >= rates_total)
      return;

   for(int i = 0; i < count; i++)
   {
      if(shift > g_zones[i].createdShift)
         continue;

      bool breakSignal = false;
      bool holdSignal = false;

      if(g_zones[i].support)
      {
         breakSignal = CrossUnder(high[shift], high[shift + 1], g_zones[i].bottom);
         holdSignal = CrossOver(low[shift], low[shift + 1], g_zones[i].top);
      }
      else
      {
         breakSignal = CrossOver(low[shift], low[shift + 1], g_zones[i].top);
         holdSignal = CrossUnder(high[shift], high[shift + 1], g_zones[i].bottom);
      }

      if(breakSignal)
      {
         g_zones[i].broken = true;
         DrawSignalLabel(i, shift, time, breakSignal, false);
         SendBreakAlert(i, shift, time);
      }
      else if(holdSignal)
      {
         g_zones[i].broken = false;
         DrawSignalLabel(i, shift, time, false, true);
      }
   }
}

bool CrossOver(const double currentValue,
               const double previousValue,
               const double level)
{
   return(currentValue > level && previousValue <= level);
}

bool CrossUnder(const double currentValue,
                const double previousValue,
                const double level)
{
   return(currentValue < level && previousValue >= level);
}

void DrawZone(const int index)
{
   string suffix = IntegerToString(index) + "_" + IntegerToString((int)g_zones[index].startTime);
   string rectName = ObjectPrefix + "RECT_" + suffix;
   string textName = ObjectPrefix + "TEXT_" + suffix;

   color zoneColor = ZoneColor(index);

   ObjectCreate(0, rectName, OBJ_RECTANGLE, 0,
                g_zones[index].startTime, g_zones[index].top,
                g_zones[index].endTime, g_zones[index].bottom);
   ObjectSetInteger(0, rectName, OBJPROP_COLOR, zoneColor);
   ObjectSetInteger(0, rectName, OBJPROP_STYLE, g_zones[index].broken ? STYLE_DASH : STYLE_SOLID);
   ObjectSetInteger(0, rectName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, rectName, OBJPROP_BACK, DrawInBackground);
   ObjectSetInteger(0, rectName, OBJPROP_SELECTABLE, false);

   if(ShowVolumeLabels)
   {
      double midPrice = (g_zones[index].top + g_zones[index].bottom) * 0.5;
      ObjectCreate(0, textName, OBJ_TEXT, 0, g_zones[index].startTime, midPrice);
      ObjectSetText(textName, "Vol: " + DoubleToString(MathRound(g_zones[index].vol), 0),
                    LabelFontSize, "Arial", TextColor);
      ObjectSetInteger(0, textName, OBJPROP_BACK, false);
      ObjectSetInteger(0, textName, OBJPROP_SELECTABLE, false);
   }
}

color ZoneColor(const int index)
{
   if(g_zones[index].support)
      return(g_zones[index].broken ? BrokenSupportColor : SupportColor);
   return(g_zones[index].broken ? BrokenResistanceColor : ResistanceColor);
}

void DrawSignalLabel(const int zoneIndex,
                     const int shift,
                     const datetime &time[],
                     const bool breakSignal,
                     const bool holdSignal)
{
   if(!ShowSignalLabels && !ShowHoldDiamonds)
      return;

   string id = IntegerToString(zoneIndex) + "_" + IntegerToString(shift) + "_" + IntegerToString((int)time[shift]);
   double price = g_zones[zoneIndex].support ? g_zones[zoneIndex].bottom : g_zones[zoneIndex].top;
   color signalColor = ZoneColor(zoneIndex);

   if(holdSignal && ShowHoldDiamonds)
   {
      string diamondName = ObjectPrefix + "HOLD_" + id;
      ObjectCreate(0, diamondName, OBJ_TEXT, 0, time[shift], price);
      ObjectSetText(diamondName, "u", LabelFontSize + 4, "Wingdings", signalColor);
      ObjectSetInteger(0, diamondName, OBJPROP_SELECTABLE, false);
   }

   if(breakSignal && ShowSignalLabels)
   {
      string labelName = ObjectPrefix + "BREAK_" + id;
      string text = g_zones[zoneIndex].support ? "Break Sup" : "Break Res";
      ObjectCreate(0, labelName, OBJ_TEXT, 0, time[shift], price);
      ObjectSetText(labelName, text, LabelFontSize, "Arial", TextColor);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
   }
}

void SendBreakAlert(const int zoneIndex,
                    const int shift,
                    const datetime &time[])
{
   if(!EnableAlerts || shift != 0 || g_lastAlertTime == time[shift])
      return;

   g_lastAlertTime = time[shift];
   string side = g_zones[zoneIndex].support ? "support" : "resistance";
   Alert(Symbol(), " ", Period(), ": SR high volume box break: ", side);
}

void DeleteObjectsByPrefix()
{
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, ObjectPrefix, 0) == 0)
         ObjectDelete(0, name);
   }
}

#property strict
#property indicator_chart_window

// RANGE BREAKOUT WSKAZNIK
// MT4 adaptation of the user-provided opening range breakout concept.
// Original referenced Pine Script: LuxAlgo, CC BY-NC-SA 4.0.

enum ORBRangeSource
{
   ORB_HighLow = 0, // High/Low
   ORB_Close   = 1  // Open/Close body
};

enum ORBExtensionMode
{
   ORB_Multiples = 0, // Multiples
   ORB_Fibonacci = 1  // Fibonacci
};

input string           ORB_PARAMETERS              = "===================="; // === OPENING RANGE ===
input string           SessionStart                = "09:30";               // Session start HH:MM
input string           SessionEnd                  = "10:00";               // Session end HH:MM
input string           DaysOfWeek                  = "1234567";             // 1=Sunday ... 7=Saturday
input int              BrokerTimeMinusSessionMinutes = 0;                   // Broker time - session time, minutes
input ORBRangeSource   RangeSource                 = ORB_HighLow;           // Range source
input int              DaysToDraw                  = 5;                     // Sessions to draw
input int              StatisticDays               = 60;                    // Sessions for hit rate

input string           EXT_PARAMETERS              = "===================="; // === EXTENSIONS ===
input bool             ShowExtensions              = true;                  // Show extension levels
input ORBExtensionMode ExtensionMode                = ORB_Multiples;         // Extension type
input double           Multiplier1                 = 1.0;                   // Multiplier 1
input double           Multiplier2                 = 2.0;                   // Multiplier 2
input double           Multiplier3                 = 3.0;                   // Multiplier 3

input string           PLOT_PARAMETERS             = "===================="; // === PLOTTING ===
input bool             LimitPlottingDuration       = true;                  // Limit plotting duration
input string           PlotEndTime                 = "17:00";               // End plotting HH:MM
input bool             ShowRangeBox                = true;                  // Show range box
input bool             ShowLabels                  = true;                  // Show labels
input bool             ShowBreakSignals            = true;                  // Show break labels
input bool             EnableAlerts                = false;                 // Alert on fresh break
input int              RefreshSeconds              = 30;                    // Minimum redraw interval

input string           STYLE_PARAMETERS            = "===================="; // === STYLE ===
input color            RangeColor                  = clrDodgerBlue;         // Range color
input color            BullColor                   = clrSeaGreen;           // Bull color
input color            BearColor                   = clrCrimson;            // Bear color
input color            PanelBackColor              = clrWhiteSmoke;         // Panel background
input color            PanelTextColor              = clrBlack;              // Panel text
input bool             ShowDashboard               = true;                  // Show dashboard
input ENUM_BASE_CORNER DashboardCorner             = CORNER_RIGHT_UPPER;    // Dashboard corner
input int              DashboardX                  = 12;                    // Dashboard X distance
input int              DashboardY                  = 22;                    // Dashboard Y distance
input int              RangeLineWidth              = 2;                     // Range line width
input int              ExtensionLineWidth          = 1;                     // Extension line width
input int              LabelFontSize               = 8;                     // Label font size
input bool             DrawInBackground            = true;                  // Draw in background
input string           ObjectPrefix                = "RANGE_BREAKOUT_";     // Object prefix

struct ORBData
{
   datetime dayStart;
   datetime rangeStart;
   datetime rangeEnd;
   datetime plotEnd;
   double   high;
   double   low;
   bool     valid;
};

datetime g_lastBarTime = 0;
datetime g_lastAlertDay = 0;
datetime g_lastRedrawTime = 0;
int      g_startHour = 9;
int      g_startMinute = 30;
int      g_endHour = 10;
int      g_endMinute = 0;
int      g_plotEndHour = 17;
int      g_plotEndMinute = 0;

int g_totalSessions = 0;
int g_hitU1 = 0;
int g_hitU2 = 0;
int g_hitU3 = 0;
int g_hitD1 = 0;
int g_hitD2 = 0;
int g_hitD3 = 0;

int OnInit()
{
   IndicatorShortName("RANGE BREAKOUT WSKAZNIK");
   if(!InputsAreValid())
      return(INIT_PARAMETERS_INCORRECT);

   DeleteObjects();
   DrawIndicator();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   DeleteObjects();
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
   if(rates_total <= 0)
      return(0);

   if(prev_calculated == 0 ||
      (time[0] != g_lastBarTime && TimeCurrent() - g_lastRedrawTime >= RefreshInterval()))
   {
      g_lastBarTime = time[0];
      DrawIndicator();
   }

   return(rates_total);
}

bool InputsAreValid()
{
   if(!ParseTimeInput(SessionStart, g_startHour, g_startMinute) ||
      !ParseTimeInput(SessionEnd, g_endHour, g_endMinute) ||
      !ParseTimeInput(PlotEndTime, g_plotEndHour, g_plotEndMinute))
   {
      Print("RANGE BREAKOUT WSKAZNIK: time inputs must use HH:MM format.");
      return(false);
   }

   if(DaysToDraw < 1 || StatisticDays < 1)
   {
      Print("RANGE BREAKOUT WSKAZNIK: DaysToDraw and StatisticDays must be at least 1.");
      return(false);
   }

   return(true);
}

bool ParseTimeInput(const string value, int &hour, int &minute)
{
   string parts[];
   if(StringSplit(value, ':', parts) != 2)
      return(false);

   hour = (int)StringToInteger(parts[0]);
   minute = (int)StringToInteger(parts[1]);
   return(hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59);
}

datetime DayStart(const datetime value)
{
   MqlDateTime parts;
   TimeToStruct(value, parts);
   parts.hour = 0;
   parts.min = 0;
   parts.sec = 0;
   return(StructToTime(parts));
}

int RefreshInterval()
{
   return((int)MathMax(1, RefreshSeconds));
}

bool IsAllowedDay(datetime sessionDayStart)
{
   int sessionDow = TimeDayOfWeek(sessionDayStart);
   int pineDow = sessionDow + 1;
   string token = IntegerToString(pineDow);
   return(StringFind(DaysOfWeek, token, 0) >= 0);
}

void BuildTimes(datetime sessionDayStart,
                datetime &rangeStart,
                datetime &rangeEnd,
                datetime &plotEnd)
{
   int offset = BrokerTimeMinusSessionMinutes * 60;
   rangeStart = sessionDayStart + g_startHour * 3600 + g_startMinute * 60 + offset;
   rangeEnd = sessionDayStart + g_endHour * 3600 + g_endMinute * 60 + offset;
   if(rangeEnd <= rangeStart)
      rangeEnd += 86400;

   plotEnd = sessionDayStart + g_plotEndHour * 3600 + g_plotEndMinute * 60 + offset;
   if(plotEnd <= rangeStart)
      plotEnd += 86400;
   if(!LimitPlottingDuration)
      plotEnd = sessionDayStart + 86400 + offset - 60;
}

bool GetORBData(datetime sessionDayStart, ORBData &data)
{
   data.valid = false;
   data.dayStart = sessionDayStart;

   if(!IsAllowedDay(sessionDayStart))
      return(false);

   BuildTimes(sessionDayStart, data.rangeStart, data.rangeEnd, data.plotEnd);
   if(data.rangeStart > TimeCurrent())
      return(false);

   int oldestShift = iBarShift(Symbol(), PERIOD_M1, data.rangeStart, false);
   int newestShift = iBarShift(Symbol(), PERIOD_M1, data.rangeEnd - 1, false);
   if(oldestShift < 0 || newestShift < 0 || oldestShift < newestShift)
      return(false);

   bool found = false;
   for(int shift = oldestShift; shift >= newestShift; shift--)
   {
      datetime barTime = iTime(Symbol(), PERIOD_M1, shift);
      if(barTime < data.rangeStart || barTime >= data.rangeEnd)
         continue;

      double barHigh = iHigh(Symbol(), PERIOD_M1, shift);
      double barLow = iLow(Symbol(), PERIOD_M1, shift);
      if(RangeSource == ORB_Close)
      {
         double barOpen = iOpen(Symbol(), PERIOD_M1, shift);
         double barClose = iClose(Symbol(), PERIOD_M1, shift);
         barHigh = MathMax(barOpen, barClose);
         barLow = MathMin(barOpen, barClose);
      }

      if(!found)
      {
         data.high = barHigh;
         data.low = barLow;
         found = true;
      }
      else
      {
         data.high = MathMax(data.high, barHigh);
         data.low = MathMin(data.low, barLow);
      }
   }

   data.valid = (found && data.high > data.low && data.low > 0.0);
   return(data.valid);
}

void ExtensionMultipliers(double &m1, double &m2, double &m3)
{
   if(ExtensionMode == ORB_Fibonacci)
   {
      m1 = 0.382;
      m2 = 0.618;
      m3 = 1.0;
      return;
   }

   m1 = MathMax(0.0, Multiplier1);
   m2 = MathMax(0.0, Multiplier2);
   m3 = MathMax(0.0, Multiplier3);
}

void CalculateLevels(const ORBData &data,
                     double &u1,
                     double &u2,
                     double &u3,
                     double &d1,
                     double &d2,
                     double &d3)
{
   double m1, m2, m3;
   ExtensionMultipliers(m1, m2, m3);
   double range = data.high - data.low;
   u1 = NormalizeDouble(data.high + range * m1, Digits);
   u2 = NormalizeDouble(data.high + range * m2, Digits);
   u3 = NormalizeDouble(data.high + range * m3, Digits);
   d1 = NormalizeDouble(data.low - range * m1, Digits);
   d2 = NormalizeDouble(data.low - range * m2, Digits);
   d3 = NormalizeDouble(data.low - range * m3, Digits);
}

bool WasTouched(const ORBData &data, const double level, const bool upper)
{
   datetime endTime = data.plotEnd < TimeCurrent() ? data.plotEnd : TimeCurrent();
   if(endTime <= data.rangeEnd)
      return(false);

   int oldestShift = iBarShift(Symbol(), PERIOD_M1, data.rangeEnd, false);
   int newestShift = iBarShift(Symbol(), PERIOD_M1, endTime, false);
   if(oldestShift < 0 || newestShift < 0 || oldestShift < newestShift)
      return(false);

   for(int shift = oldestShift; shift >= newestShift; shift--)
   {
      datetime barTime = iTime(Symbol(), PERIOD_M1, shift);
      if(barTime < data.rangeEnd || barTime > endTime)
         continue;

      if(upper && iHigh(Symbol(), PERIOD_M1, shift) >= level)
         return(true);
      if(!upper && iLow(Symbol(), PERIOD_M1, shift) <= level)
         return(true);
   }

   return(false);
}

bool GetPostSessionExtreme(const ORBData &data,
                           double &postHigh,
                           double &postLow)
{
   datetime endTime = data.plotEnd < TimeCurrent() ? data.plotEnd : TimeCurrent();
   if(endTime <= data.rangeEnd)
      return(false);

   int oldestShift = iBarShift(Symbol(), PERIOD_M1, data.rangeEnd, false);
   int newestShift = iBarShift(Symbol(), PERIOD_M1, endTime, false);
   if(oldestShift < 0 || newestShift < 0 || oldestShift < newestShift)
      return(false);

   bool found = false;
   for(int shift = oldestShift; shift >= newestShift; shift--)
   {
      datetime barTime = iTime(Symbol(), PERIOD_M1, shift);
      if(barTime < data.rangeEnd || barTime > endTime)
         continue;

      double barHigh = iHigh(Symbol(), PERIOD_M1, shift);
      double barLow = iLow(Symbol(), PERIOD_M1, shift);
      if(!found)
      {
         postHigh = barHigh;
         postLow = barLow;
         found = true;
      }
      else
      {
         if(barHigh > postHigh)
            postHigh = barHigh;
         if(barLow < postLow)
            postLow = barLow;
      }
   }

   return(found);
}

void CalculateStatistics()
{
   g_totalSessions = 0;
   g_hitU1 = 0;
   g_hitU2 = 0;
   g_hitU3 = 0;
   g_hitD1 = 0;
   g_hitD2 = 0;
   g_hitD3 = 0;

   datetime currentSessionDay = DayStart(TimeCurrent() - BrokerTimeMinusSessionMinutes * 60);
   int maxLookback = (int)MathMax(StatisticDays * 3, StatisticDays + 20);

   for(int day = 0; day < maxLookback && g_totalSessions < StatisticDays; day++)
   {
      datetime sessionDayStart = currentSessionDay - day * 86400;
      ORBData data;
      if(!GetORBData(sessionDayStart, data))
         continue;
      if(data.rangeEnd >= TimeCurrent())
         continue;

      double u1, u2, u3, d1, d2, d3;
      CalculateLevels(data, u1, u2, u3, d1, d2, d3);
      double postHigh = 0.0;
      double postLow = 0.0;
      if(!GetPostSessionExtreme(data, postHigh, postLow))
         continue;

      g_totalSessions++;
      if(postHigh >= u1) g_hitU1++;
      if(postHigh >= u2) g_hitU2++;
      if(postHigh >= u3) g_hitU3++;
      if(postLow <= d1)  g_hitD1++;
      if(postLow <= d2)  g_hitD2++;
      if(postLow <= d3)  g_hitD3++;
   }
}

double HitRate(const int hits)
{
   if(g_totalSessions <= 0)
      return(0.0);
   return(100.0 * hits / g_totalSessions);
}

string PriceText(const double price)
{
   return(DoubleToString(price, Digits));
}

string RateText(const int hits)
{
   return(DoubleToString(HitRate(hits), 0) + "%");
}

void DrawIndicator()
{
   g_lastRedrawTime = TimeCurrent();
   DeleteObjects();
   CalculateStatistics();

   datetime currentSessionDay = DayStart(TimeCurrent() - BrokerTimeMinusSessionMinutes * 60);
   int drawn = 0;
   int maxLookback = (int)MathMax(DaysToDraw * 3, DaysToDraw + 20);

   for(int day = 0; day < maxLookback && drawn < DaysToDraw; day++)
   {
      ORBData data;
      datetime sessionDayStart = currentSessionDay - day * 86400;
      if(!GetORBData(sessionDayStart, data))
         continue;

      DrawSession(data, drawn);
      drawn++;
   }

   DrawDashboard();
   CheckFreshAlert();
   ChartRedraw(0);
}

void DrawSession(const ORBData &data, const int drawIndex)
{
   string dateId = TimeToString(data.dayStart, TIME_DATE);
   StringReplace(dateId, ".", "");
   StringReplace(dateId, ":", "");
   StringReplace(dateId, " ", "_");

   datetime futureTime = TimeCurrent() + 86400;
   datetime endTime = data.plotEnd < futureTime ? data.plotEnd : futureTime;
   string id = dateId + "_" + IntegerToString(drawIndex);

   if(ShowRangeBox)
      DrawRectangle(ObjectPrefix + "BOX_" + id, data.rangeStart, data.high, data.rangeEnd, data.low, RangeColor, false);

   DrawLevel(ObjectPrefix + "HIGH_" + id, data.rangeStart, endTime, data.high, RangeColor, STYLE_SOLID, RangeLineWidth);
   DrawLevel(ObjectPrefix + "LOW_" + id, data.rangeStart, endTime, data.low, RangeColor, STYLE_SOLID, RangeLineWidth);

   if(ShowLabels)
   {
      DrawText(ObjectPrefix + "LBL_HIGH_" + id, endTime, data.high, "OR High " + PriceText(data.high), RangeColor, ANCHOR_LEFT_LOWER);
      DrawText(ObjectPrefix + "LBL_LOW_" + id, endTime, data.low, "OR Low " + PriceText(data.low), RangeColor, ANCHOR_LEFT_UPPER);
   }

   double u1, u2, u3, d1, d2, d3;
   CalculateLevels(data, u1, u2, u3, d1, d2, d3);

   if(ShowExtensions)
   {
      DrawTarget(ObjectPrefix + "U1_" + id, "Target 1 " + RateText(g_hitU1), data.rangeStart, endTime, u1, BullColor);
      DrawTarget(ObjectPrefix + "U2_" + id, "Target 2 " + RateText(g_hitU2), data.rangeStart, endTime, u2, BullColor);
      DrawTarget(ObjectPrefix + "U3_" + id, "Target 3 " + RateText(g_hitU3), data.rangeStart, endTime, u3, BullColor);
      DrawTarget(ObjectPrefix + "D1_" + id, "Target 1 " + RateText(g_hitD1), data.rangeStart, endTime, d1, BearColor);
      DrawTarget(ObjectPrefix + "D2_" + id, "Target 2 " + RateText(g_hitD2), data.rangeStart, endTime, d2, BearColor);
      DrawTarget(ObjectPrefix + "D3_" + id, "Target 3 " + RateText(g_hitD3), data.rangeStart, endTime, d3, BearColor);
   }

   if(ShowBreakSignals)
      DrawBreakSignal(data, id);
}

void DrawTarget(const string name,
                const string label,
                const datetime startTime,
                const datetime endTime,
                const double price,
                const color lineColor)
{
   DrawLevel(name, startTime, endTime, price, lineColor, STYLE_DOT, ExtensionLineWidth);
   if(ShowLabels)
      DrawText(name + "_LABEL", endTime, price, label + " | " + PriceText(price), lineColor, ANCHOR_LEFT);
}

void DrawBreakSignal(const ORBData &data, const string id)
{
   datetime endTime = data.plotEnd < TimeCurrent() ? data.plotEnd : TimeCurrent();
   if(endTime <= data.rangeEnd)
      return;

   int oldestShift = iBarShift(Symbol(), Period(), data.rangeEnd, false);
   int newestShift = iBarShift(Symbol(), Period(), endTime, false);
   if(oldestShift < 1 || newestShift < 0 || oldestShift < newestShift)
      return;

   bool canBull = true;
   bool canBear = true;
   for(int shift = oldestShift; shift >= newestShift; shift--)
   {
      double closeNow = iClose(Symbol(), Period(), shift);
      double closePrev = iClose(Symbol(), Period(), shift + 1);
      datetime barTime = iTime(Symbol(), Period(), shift);
      if(barTime < data.rangeEnd || barTime > endTime)
         continue;

      if(canBull && closeNow > data.high && closePrev <= data.high)
      {
         DrawText(ObjectPrefix + "BULL_BREAK_" + id, barTime, iHigh(Symbol(), Period(), shift),
                  "BULL BREAK", BullColor, ANCHOR_LOWER);
         canBull = false;
      }

      if(canBear && closeNow < data.low && closePrev >= data.low)
      {
         DrawText(ObjectPrefix + "BEAR_BREAK_" + id, barTime, iLow(Symbol(), Period(), shift),
                  "BEAR BREAK", BearColor, ANCHOR_UPPER);
         canBear = false;
      }

      if(!canBull && !canBear)
         return;
   }
}

void CheckFreshAlert()
{
   if(!EnableAlerts)
      return;

   datetime currentSessionDay = DayStart(TimeCurrent() - BrokerTimeMinusSessionMinutes * 60);
   ORBData data;
   if(!GetORBData(currentSessionDay, data))
      return;
   if(TimeCurrent() <= data.rangeEnd || TimeCurrent() > data.plotEnd)
      return;
   if(g_lastAlertDay == data.dayStart)
      return;

   double closeNow = iClose(Symbol(), Period(), 0);
   double closePrev = iClose(Symbol(), Period(), 1);
   if(closeNow > data.high && closePrev <= data.high)
   {
      Alert(Symbol(), " RANGE BREAKOUT: bullish break above ", PriceText(data.high));
      g_lastAlertDay = data.dayStart;
   }
   else if(closeNow < data.low && closePrev >= data.low)
   {
      Alert(Symbol(), " RANGE BREAKOUT: bearish break below ", PriceText(data.low));
      g_lastAlertDay = data.dayStart;
   }
}

void DrawLevel(const string name,
               const datetime startTime,
               const datetime endTime,
               const double price,
               const color lineColor,
               const int style,
               const int width)
{
   if(!ObjectCreate(0, name, OBJ_TREND, 0, startTime, price, endTime, price))
      return;

   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_BACK, DrawInBackground);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void DrawRectangle(const string name,
                   const datetime startTime,
                   const double highPrice,
                   const datetime endTime,
                   const double lowPrice,
                   const color boxColor,
                   const bool fill)
{
   if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, startTime, highPrice, endTime, lowPrice))
      return;

   ObjectSetInteger(0, name, OBJPROP_COLOR, boxColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, DrawInBackground);
   ObjectSetInteger(0, name, OBJPROP_FILL, fill);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void DrawText(const string name,
              const datetime labelTime,
              const double price,
              const string text,
              const color textColor,
              const ENUM_ANCHOR_POINT anchor)
{
   if(!ObjectCreate(0, name, OBJ_TEXT, 0, labelTime, price))
      return;

   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, LabelFontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void DrawDashboard()
{
   if(!ShowDashboard)
      return;

   int panelWidth = 230;
   int panelHeight = 164;
   int textX = DashboardX + 10;
   ENUM_ANCHOR_POINT textAnchor = ANCHOR_LEFT_UPPER;
   if(DashboardCorner == CORNER_RIGHT_UPPER || DashboardCorner == CORNER_RIGHT_LOWER)
      textAnchor = ANCHOR_RIGHT_UPPER;

   string bgName = ObjectPrefix + "PANEL_BG";
   if(ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, bgName, OBJPROP_CORNER, DashboardCorner);
      ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, DashboardX);
      ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, DashboardY);
      ObjectSetInteger(0, bgName, OBJPROP_XSIZE, panelWidth);
      ObjectSetInteger(0, bgName, OBJPROP_YSIZE, panelHeight);
      ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, PanelBackColor);
      ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, clrSilver);
      ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, bgName, OBJPROP_HIDDEN, true);
   }

   DrawPanelLabel("TITLE", "ORB Hit Rate", textX, DashboardY + 8, 10, PanelTextColor, textAnchor);
   DrawPanelLabel("TRACKED", "Tracked sessions: " + IntegerToString(g_totalSessions), textX, DashboardY + 28, 8, PanelTextColor, textAnchor);
   DrawPanelLabel("B1", "Bull T1: " + IntegerToString(g_hitU1) + " / " + RateText(g_hitU1), textX, DashboardY + 50, 8, BullColor, textAnchor);
   DrawPanelLabel("B2", "Bull T2: " + IntegerToString(g_hitU2) + " / " + RateText(g_hitU2), textX, DashboardY + 68, 8, BullColor, textAnchor);
   DrawPanelLabel("B3", "Bull T3: " + IntegerToString(g_hitU3) + " / " + RateText(g_hitU3), textX, DashboardY + 86, 8, BullColor, textAnchor);
   DrawPanelLabel("S1", "Bear T1: " + IntegerToString(g_hitD1) + " / " + RateText(g_hitD1), textX, DashboardY + 108, 8, BearColor, textAnchor);
   DrawPanelLabel("S2", "Bear T2: " + IntegerToString(g_hitD2) + " / " + RateText(g_hitD2), textX, DashboardY + 126, 8, BearColor, textAnchor);
   DrawPanelLabel("S3", "Bear T3: " + IntegerToString(g_hitD3) + " / " + RateText(g_hitD3), textX, DashboardY + 144, 8, BearColor, textAnchor);
}

void DrawPanelLabel(const string id,
                    const string text,
                    const int x,
                    const int y,
                    const int fontSize,
                    const color textColor,
                    const ENUM_ANCHOR_POINT anchor)
{
   string name = ObjectPrefix + "PANEL_" + id;
   if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
      return;

   ObjectSetInteger(0, name, OBJPROP_CORNER, DashboardCorner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void DeleteObjects()
{
   for(int index = ObjectsTotal(0, -1, -1) - 1; index >= 0; index--)
   {
      string name = ObjectName(0, index, -1, -1);
      if(StringFind(name, ObjectPrefix, 0) == 0)
         ObjectDelete(0, name);
   }
}

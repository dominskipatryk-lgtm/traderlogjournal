//+------------------------------------------------------------------+
//|                                            VRVP_Pro_MT4.mq4       |
//|      TradingView-like Visible Range / Fixed Range Volume Profile  |
//|      Tick-volume based PRO version for MetaTrader 4               |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window

//============================== INPUTS ==============================
enum ENUM_VRVP_MODE
{
   MODE_VISIBLE_RANGE = 0,
   MODE_FIXED_RANGE   = 1
};

enum ENUM_PROFILE_SIDE
{
   SIDE_RIGHT = 0,
   SIDE_LEFT  = 1
};

enum ENUM_DISTRIBUTION_MODEL
{
   DIST_ULTRA_BODY_CLOSE_WEIGHTED = 0,
   DIST_UNIFORM_HIGH_LOW          = 1,
   DIST_BODY_PRIORITY             = 2
};

input ENUM_VRVP_MODE          ProfileMode       = MODE_VISIBLE_RANGE;
input ENUM_PROFILE_SIDE       Placement         = SIDE_RIGHT;
input ENUM_DISTRIBUTION_MODEL DistributionModel = DIST_ULTRA_BODY_CLOSE_WEIGHTED;

input int      RowsRequested       = 180;       // 80-250 recommended
input int      MaxRowsSafety       = 260;       // hard safety limit
input double   WidthPercent        = 14.0;      // % of chart width, like TradingView
input int      HorizontalOffsetPx  = 16;
input double   ValueAreaPercent    = 70.0;

input bool     ShowVolumeProfile   = true;
input bool     ShowUpDownVolume    = true;
input bool     ShowValues          = false;     // text values, can be heavy
input bool     ShowPOC             = true;
input bool     ShowVAH             = true;
input bool     ShowVAL             = true;
input bool     ShowDevelopingPOC   = true;      // visible as step-like short segments
input bool     ShowRangeLines      = true;      // fixed range drag handles

input color    UpVolumeColor       = clrMediumSeaGreen;
input color    DownVolumeColor     = clrTomato;
input color    ValueAreaUpColor    = clrSilver;
input color    ValueAreaDownColor  = clrDimGray;
input color    POCColor            = clrGold;
input color    VAHColor            = clrGainsboro;
input color    VALColor            = clrGainsboro;
input color    DevelopingPOCColor  = clrDarkOrange;
input color    RangeLineColor      = clrDeepSkyBlue;
input color    TextColor           = clrWhite;

input int      POCLineWidth        = 2;
input int      VALineWidth         = 1;
input int      DevelopingPOCWidth  = 1;

input int      RefreshSeconds      = 1;
input int      MinBarRange         = 5;
input int      MaxBarsForDevPOC    = 350;       // safety: developing POC segments

//============================== GLOBALS ==============================
string PREFIX = "VRVP_PRO_";
string START_LINE = "VRVP_START";
string END_LINE   = "VRVP_END";

int g_lastFirstVisible = -1;
int g_lastBarsVisible  = -1;
int g_lastWidth        = -1;
int g_lastHeight       = -1;
datetime g_lastStart   = 0;
datetime g_lastEnd     = 0;

//============================== INIT ==============================
int OnInit()
{
   IndicatorShortName("VRVP Pro MT4 - Visible/Fixed Range Volume Profile");
   EventSetTimer(RefreshSeconds);

   if(ProfileMode == MODE_FIXED_RANGE)
      EnsureRangeLines();

   DrawProfile();
   return(INIT_SUCCEEDED);
}

//============================== DEINIT ==============================
void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteProfileObjects();

   // Do not delete drag handles on timeframe switch unless user removes indicator.
   ObjectDelete(0, START_LINE);
   ObjectDelete(0, END_LINE);
}

//============================== CALCULATE ==============================
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
   if(prev_calculated == 0)
      DrawProfile();

   return(rates_total);
}

//============================== EVENTS ==============================
void OnTimer()
{
   if(ProfileMode == MODE_FIXED_RANGE)
      EnsureRangeLines();

   if(NeedRedraw())
      DrawProfile();
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE ||
      id == CHARTEVENT_OBJECT_DRAG ||
      id == CHARTEVENT_OBJECT_CHANGE)
   {
      if(sparam == START_LINE || sparam == END_LINE || id == CHARTEVENT_CHART_CHANGE)
         DrawProfile();
   }
}

//============================== REDRAW CHECK ==============================
bool NeedRedraw()
{
   int firstVisible = WindowFirstVisibleBar();
   int barsVisible  = WindowBarsPerChart();

   long w = 0, h = 0;
   ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0, w);
   ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0, h);

   datetime st = 0, en = 0;
   if(ProfileMode == MODE_FIXED_RANGE)
   {
      EnsureRangeLines();
      st = (datetime)ObjectGetInteger(0, START_LINE, OBJPROP_TIME1);
      en = (datetime)ObjectGetInteger(0, END_LINE, OBJPROP_TIME1);
   }

   if(firstVisible != g_lastFirstVisible ||
      barsVisible  != g_lastBarsVisible  ||
      (int)w       != g_lastWidth        ||
      (int)h       != g_lastHeight       ||
      st           != g_lastStart        ||
      en           != g_lastEnd)
      return(true);

   return(false);
}

//============================== MAIN DRAW ==============================
void DrawProfile()
{
   if(Bars < 20 || !ShowVolumeProfile)
      return;

   DeleteProfileObjects();

   int rows = MathMax(20, MathMin(RowsRequested, MaxRowsSafety));
   int leftIndex = 0;
   int rightIndex = 0;

   if(!GetRangeIndexes(leftIndex, rightIndex))
      return;

   if(leftIndex - rightIndex + 1 < MinBarRange)
      return;

   double minPrice = DBL_MAX;
   double maxPrice = -DBL_MAX;

   for(int i = rightIndex; i <= leftIndex; i++)
   {
      if(Low[i] < minPrice) minPrice = Low[i];
      if(High[i] > maxPrice) maxPrice = High[i];
   }

   if(maxPrice <= minPrice)
      return;

   double step = (maxPrice - minPrice) / rows;
   if(step <= 0)
      return;

   double totalVol[], upVol[], downVol[];
   ArrayResize(totalVol, rows);
   ArrayResize(upVol, rows);
   ArrayResize(downVol, rows);
   ArrayInitialize(totalVol, 0.0);
   ArrayInitialize(upVol, 0.0);
   ArrayInitialize(downVol, 0.0);

   BuildProfile(rightIndex, leftIndex, minPrice, step, rows, totalVol, upVol, downVol);

   double maxVol = 0.0;
   int pocRow = 0;
   for(int r = 0; r < rows; r++)
   {
      if(totalVol[r] > maxVol)
      {
         maxVol = totalVol[r];
         pocRow = r;
      }
   }

   if(maxVol <= 0.0)
      return;

   int valRow = pocRow;
   int vahRow = pocRow;
   CalculateValueArea(totalVol, rows, pocRow, ValueAreaPercent, valRow, vahRow);

   long chartW = 0, chartH = 0;
   ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0, chartW);
   ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0, chartH);

   int profileMaxWidth = (int)MathRound((double)chartW * WidthPercent / 100.0);
   profileMaxWidth = MathMax(20, profileMaxWidth);

   DrawHistogram(rows, minPrice, step, totalVol, upVol, downVol, maxVol,
                 valRow, vahRow, profileMaxWidth, (int)chartW);

   if(ShowPOC)
   {
      double pocPrice = RowMidPrice(minPrice, step, pocRow);
      DrawHLine(PREFIX + "POC", pocPrice, POCColor, STYLE_SOLID, POCLineWidth, "POC");
   }

   if(ShowVAH)
   {
      double vahPrice = RowMidPrice(minPrice, step, vahRow);
      DrawHLine(PREFIX + "VAH", vahPrice, VAHColor, STYLE_DOT, VALineWidth, "VAH");
   }

   if(ShowVAL)
   {
      double valPrice = RowMidPrice(minPrice, step, valRow);
      DrawHLine(PREFIX + "VAL", valPrice, VALColor, STYLE_DOT, VALineWidth, "VAL");
   }

   if(ShowDevelopingPOC)
      DrawDevelopingPOC(rightIndex, leftIndex, minPrice, step, rows);

   if(ProfileMode == MODE_FIXED_RANGE && ShowRangeLines)
      EnsureRangeLines();

   g_lastFirstVisible = WindowFirstVisibleBar();
   g_lastBarsVisible  = WindowBarsPerChart();
   g_lastWidth        = (int)chartW;
   g_lastHeight       = (int)chartH;

   if(ProfileMode == MODE_FIXED_RANGE)
   {
      g_lastStart = (datetime)ObjectGetInteger(0, START_LINE, OBJPROP_TIME1);
      g_lastEnd   = (datetime)ObjectGetInteger(0, END_LINE, OBJPROP_TIME1);
   }

   ChartRedraw(0);
}

//============================== RANGE ==============================
bool GetRangeIndexes(int &leftIndex, int &rightIndex)
{
   if(ProfileMode == MODE_VISIBLE_RANGE)
   {
      int firstVisible = WindowFirstVisibleBar();
      int barsVisible = WindowBarsPerChart();

      leftIndex  = MathMin(firstVisible, Bars - 1);
      rightIndex = MathMax(firstVisible - barsVisible + 1, 0);
      return(leftIndex > rightIndex);
   }

   EnsureRangeLines();

   datetime t1 = (datetime)ObjectGetInteger(0, START_LINE, OBJPROP_TIME1);
   datetime t2 = (datetime)ObjectGetInteger(0, END_LINE, OBJPROP_TIME1);

   if(t1 == 0 || t2 == 0)
      return(false);

   datetime older = MathMin(t1, t2);
   datetime newer = MathMax(t1, t2);

   int idxOlder = iBarShift(Symbol(), Period(), older, false);
   int idxNewer = iBarShift(Symbol(), Period(), newer, false);

   if(idxOlder < 0 || idxNewer < 0)
      return(false);

   leftIndex  = MathMax(idxOlder, idxNewer);
   rightIndex = MathMin(idxOlder, idxNewer);

   if(leftIndex >= Bars) leftIndex = Bars - 1;
   if(rightIndex < 0) rightIndex = 0;

   return(leftIndex > rightIndex);
}

void EnsureRangeLines()
{
   if(ObjectFind(0, START_LINE) < 0)
   {
      datetime tStart = Time[MathMin(Bars - 1, MathMax(20, WindowBarsPerChart() - 1))];
      ObjectCreate(0, START_LINE, OBJ_VLINE, 0, tStart, 0);
      StyleRangeLine(START_LINE);
   }

   if(ObjectFind(0, END_LINE) < 0)
   {
      datetime tEnd = Time[0];
      ObjectCreate(0, END_LINE, OBJ_VLINE, 0, tEnd, 0);
      StyleRangeLine(END_LINE);
   }
}

void StyleRangeLine(string name)
{
   ObjectSetInteger(0, name, OBJPROP_COLOR, RangeLineColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetString(0, name, OBJPROP_TEXT, name);
}

//============================== PROFILE BUILD ==============================
void BuildProfile(int rightIndex, int leftIndex,
                  double minPrice, double step, int rows,
                  double &totalVol[], double &upVol[], double &downVol[])
{
   for(int bar = rightIndex; bar <= leftIndex; bar++)
      AddCandleToProfile(bar, minPrice, step, rows, totalVol, upVol, downVol);
}

void AddCandleToProfile(int bar,
                        double minPrice, double step, int rows,
                        double &totalVol[], double &upVol[], double &downVol[])
{
   double hi = High[bar];
   double lo = Low[bar];
   double op = Open[bar];
   double cl = Close[bar];
   double tv = (double)Volume[bar];

   if(tv <= 0.0 || hi < lo)
      return;

   int rowLo = PriceToRow(lo, minPrice, step, rows);
   int rowHi = PriceToRow(hi, minPrice, step, rows);

   if(rowHi < rowLo)
   {
      int tmp = rowHi; rowHi = rowLo; rowLo = tmp;
   }

   double weights[];
   ArrayResize(weights, rowHi - rowLo + 1);
   ArrayInitialize(weights, 0.0);

   double weightSum = 0.0;
   double bodyLow = MathMin(op, cl);
   double bodyHigh = MathMax(op, cl);
   double bodyMid = (op + cl) / 2.0;
   double closeBiasCenter = cl;

   for(int r = rowLo; r <= rowHi; r++)
   {
      double p = RowMidPrice(minPrice, step, r);
      double w = 1.0;

      if(DistributionModel == DIST_UNIFORM_HIGH_LOW)
      {
         w = 1.0;
      }
      else if(DistributionModel == DIST_BODY_PRIORITY)
      {
         if(p >= bodyLow && p <= bodyHigh)
            w = 3.0;
         else
            w = 1.0;
      }
      else // DIST_ULTRA_BODY_CLOSE_WEIGHTED
      {
         double candleRange = MathMax(hi - lo, Point);
         double distClose = MathAbs(p - closeBiasCenter) / candleRange;
         double distBodyMid = MathAbs(p - bodyMid) / candleRange;

         w = 1.0;
         if(p >= bodyLow && p <= bodyHigh)
            w += 3.0;

         // Gaussian-like close/body weighting without expensive MathExp.
         w += 2.5 / (1.0 + 20.0 * distClose * distClose);
         w += 1.5 / (1.0 + 14.0 * distBodyMid * distBodyMid);
      }

      int local = r - rowLo;
      weights[local] = w;
      weightSum += w;
   }

   if(weightSum <= 0.0)
      return;

   bool bullCandle = (cl >= op);

   // Up/down split. Directional candle dominates, but wick/body model leaves some opposite side.
   double upShare;
   if(cl == op)
      upShare = 0.5;
   else if(bullCandle)
      upShare = 0.72;
   else
      upShare = 0.28;

   for(int rr = rowLo; rr <= rowHi; rr++)
   {
      int loc = rr - rowLo;
      double part = tv * weights[loc] / weightSum;

      totalVol[rr] += part;
      upVol[rr]    += part * upShare;
      downVol[rr]  += part * (1.0 - upShare);
   }
}

//============================== DRAW HISTOGRAM ==============================
void DrawHistogram(int rows, double minPrice, double step,
                   double &totalVol[], double &upVol[], double &downVol[],
                   double maxVol, int valRow, int vahRow,
                   int profileMaxWidth, int chartW)
{
   for(int row = 0; row < rows; row++)
   {
      if(totalVol[row] <= 0.0)
         continue;

      double p1 = minPrice + step * row;
      double p2 = p1 + step;

      int y1, y2;
      if(!PriceToY(p1, y1) || !PriceToY(p2, y2))
         continue;

      int y = MathMin(y1, y2);
      int h = MathMax(1, MathAbs(y2 - y1));

      int width = (int)MathRound(profileMaxWidth * totalVol[row] / maxVol);
      if(width < 1)
         continue;

      int xBase;
      if(Placement == SIDE_RIGHT)
         xBase = chartW - HorizontalOffsetPx - width;
      else
         xBase = HorizontalOffsetPx;

      bool inVA = (row >= valRow && row <= vahRow);

      if(ShowUpDownVolume)
      {
         int upW = (int)MathRound(width * upVol[row] / MathMax(totalVol[row], 1.0));
         int dnW = width - upW;

         color upC = inVA ? ValueAreaUpColor : UpVolumeColor;
         color dnC = inVA ? ValueAreaDownColor : DownVolumeColor;

         if(Placement == SIDE_RIGHT)
         {
            DrawRect(PREFIX + "DN_" + IntegerToString(row), xBase, y, dnW, h, dnC);
            DrawRect(PREFIX + "UP_" + IntegerToString(row), xBase + dnW, y, upW, h, upC);
         }
         else
         {
            DrawRect(PREFIX + "UP_" + IntegerToString(row), xBase, y, upW, h, upC);
            DrawRect(PREFIX + "DN_" + IntegerToString(row), xBase + upW, y, dnW, h, dnC);
         }
      }
      else
      {
         color c = inVA ? ValueAreaUpColor : UpVolumeColor;
         DrawRect(PREFIX + "TOT_" + IntegerToString(row), xBase, y, width, h, c);
      }

      if(ShowValues && row % 4 == 0)
      {
         string txt = DoubleToString(totalVol[row], 0);
         int tx = (Placement == SIDE_RIGHT) ? xBase - 48 : xBase + width + 3;
         DrawText(PREFIX + "TXT_" + IntegerToString(row), tx, y, txt, TextColor, 7);
      }
   }
}

//============================== DEVELOPING POC ==============================
void DrawDevelopingPOC(int rightIndex, int leftIndex,
                       double minPrice, double step, int rows)
{
   int barsCount = leftIndex - rightIndex + 1;
   if(barsCount <= 2)
      return;

   int skip = 1;
   if(barsCount > MaxBarsForDevPOC)
      skip = (int)MathCeil((double)barsCount / (double)MaxBarsForDevPOC);

   double vol[];
   ArrayResize(vol, rows);
   ArrayInitialize(vol, 0.0);

   double dummyUp[], dummyDn[];
   ArrayResize(dummyUp, rows);
   ArrayResize(dummyDn, rows);
   ArrayInitialize(dummyUp, 0.0);
   ArrayInitialize(dummyDn, 0.0);

   int previousRow = -1;
   datetime previousTime = 0;

   for(int bar = leftIndex; bar >= rightIndex; bar--)
   {
      AddCandleToProfile(bar, minPrice, step, rows, vol, dummyUp, dummyDn);

      if(((leftIndex - bar) % skip) != 0 && bar != rightIndex)
         continue;

      int poc = 0;
      double mx = 0.0;
      for(int r = 0; r < rows; r++)
      {
         if(vol[r] > mx)
         {
            mx = vol[r];
            poc = r;
         }
      }

      if(previousRow >= 0 && previousTime > 0)
      {
         double pPrev = RowMidPrice(minPrice, step, previousRow);
         double pCur  = RowMidPrice(minPrice, step, poc);
         string name = PREFIX + "DPOC_" + IntegerToString(bar);
         ObjectCreate(0, name, OBJ_TREND, 0, previousTime, pPrev, Time[bar], pCur);
         ObjectSetInteger(0, name, OBJPROP_COLOR, DevelopingPOCColor);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, DevelopingPOCWidth);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      }

      previousRow = poc;
      previousTime = Time[bar];
   }
}

//============================== HELPERS ==============================
int PriceToRow(double price, double minPrice, double step, int rows)
{
   int idx = (int)MathFloor((price - minPrice) / step);
   if(idx < 0) idx = 0;
   if(idx >= rows) idx = rows - 1;
   return(idx);
}

double RowMidPrice(double minPrice, double step, int row)
{
   return(minPrice + step * ((double)row + 0.5));
}

bool PriceToY(double price, int &y)
{
   int x = 0;
   datetime t = Time[0];
   return(ChartTimePriceToXY(0, 0, t, price, x, y));
}

void CalculateValueArea(double &vol[], int rows, int pocRow,
                        double percent, int &valRow, int &vahRow)
{
   double total = 0.0;
   for(int i = 0; i < rows; i++)
      total += vol[i];

   double target = total * MathMax(1.0, MathMin(100.0, percent)) / 100.0;
   double acc = vol[pocRow];

   valRow = pocRow;
   vahRow = pocRow;

   while(acc < target && (valRow > 0 || vahRow < rows - 1))
   {
      double below = (valRow > 0) ? vol[valRow - 1] : -1.0;
      double above = (vahRow < rows - 1) ? vol[vahRow + 1] : -1.0;

      if(above >= below)
      {
         if(vahRow < rows - 1)
         {
            vahRow++;
            acc += vol[vahRow];
         }
         else if(valRow > 0)
         {
            valRow--;
            acc += vol[valRow];
         }
      }
      else
      {
         if(valRow > 0)
         {
            valRow--;
            acc += vol[valRow];
         }
         else if(vahRow < rows - 1)
         {
            vahRow++;
            acc += vol[vahRow];
         }
      }
   }
}

//============================== OBJECT DRAWING ==============================
void DrawRect(string name, int x, int y, int w, int h, color c)
{
   if(w <= 0 || h <= 0)
      return;

   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, c);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void DrawText(string name, int x, int y, string text, color c, int fontSize)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void DrawHLine(string name, double price, color c, int style, int width, string text)
{
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void DeleteProfileObjects()
{
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, PREFIX, 0) == 0)
         ObjectDelete(0, name);
   }
}
//+------------------------------------------------------------------+

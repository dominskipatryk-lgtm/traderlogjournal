//+------------------------------------------------------------------+
//| IB FIRST HOUR EA                                                  |
//| Initial Balance decision EA based on first NY hour 14:30-15:30 UK |
//+------------------------------------------------------------------+
#property strict

enum ENUM_MARKET_CONTEXT
{
   Context_Rotation_Inside_IB = 0,
   Context_Clean_Breakout = 1,
   Context_Failed_Auction = 2,
   Context_Extension_Reaction = 3,
   Context_Extension_Continuation = 4,
   Context_No_Trade = 5
};

enum ENUM_SIGNAL_TYPE
{
   Signal_None = 0,
   Signal_Long = 1,
   Signal_Short = 2
};

enum ENUM_EXTENSION_SIGNAL_TYPE
{
   Extension_None = 0,
   Reversal_Back_To_IB = 1,
   Continuation_To_Next_Extension = 2
};

enum ENUM_REVERSAL_TARGET_MODE
{
   Back_To_IB_Edge = 0,
   IB_50 = 1,
   Fixed_RR = 2
};

enum ENUM_AUTO_CLOSE_LEVEL_MODE
{
   AutoClose_IB_50 = 0,
   AutoClose_IB_High = 1,
   AutoClose_IB_Low = 2,
   AutoClose_Extension_Up_05 = 3,
   AutoClose_Extension_Down_05 = 4,
   AutoClose_Extension_Up_10 = 5,
   AutoClose_Extension_Down_10 = 6,
   AutoClose_Custom_Price = 7
};

input string SessionStart = "14:30";
input string SessionEnd   = "15:30";

input bool   AutoTrade = false;
input double Lots = 0.10;
input int    Slippage = 3;
input int    MagicNumber = 14301530;
input int    Stop_Buffer_Points = 50;
input double Fixed_RR_Multiplier = 1.5;
input bool   One_Trade_Per_Day = true;
input int    Max_Trades_Per_Day = 5;

input bool   Reject_Trade_If_SL_Bigger_Than_TP = true;
input double Min_Risk_Reward = 1.0;
input int    Max_StopLoss_Points = 120;

input bool   Use_Historical_Context_Filter = true;
input int    Historical_Context_Days = 5;
input bool   Analyze_Previous_Candles = true;
input int    Previous_Candles_To_Analyze = 12;
input double Min_Previous_Candle_Agreement_Percent = 55.0;
input bool   Require_Recent_Momentum_With_Trade = true;
input bool   Avoid_Trade_Into_Historical_SR = true;
input int    Historical_SR_Tolerance_Points = 80;

input bool Auto_Close_Positions = false;
input ENUM_AUTO_CLOSE_LEVEL_MODE Auto_Close_Level_Mode = AutoClose_IB_50;
input double Auto_Close_Custom_Price = 0.0;

input bool Count_IB_Mid_Tests = true;
input int  Max_IB_Mid_Tests_Before_No_Trade = 3;
input bool Require_IB_Mid_Acceptance = true;
input int  IB_Mid_Acceptance_Candles = 1;
input int  IB_Mid_Tolerance_Points = 30;
input double IB_Mid_Tolerance_ATR_Multiplier = 0.10;

input bool Treat_Retest_As_Zone = true;
input double Retest_Zone_ATR_Multiplier = 0.15;
input int  Retest_Zone_Points = 50;
input bool Allow_Wick_Into_IB_During_Retest = true;
input int  Max_Wick_Inside_IB_Points = 40;
input bool Require_Rejection_After_Retest = true;
input bool Invalidate_Continuation_If_Close_Back_Inside_IB = true;
input double Continuation_Invalidation_Depth_Percent = 25.0;

input bool Enable_Extension_Reversal = true;
input bool Enable_Extension_Continuation = true;
input bool Require_Extension_Retest_For_Continuation = true;
input bool Require_Extension_Failure_For_Reversal = true;
input bool Extension_Failure_Close_Back_Level = true;
input int  Extension_Continuation_Min_Close_Distance_Points = 30;
input ENUM_REVERSAL_TARGET_MODE Extension_Reversal_Target_Mode = Back_To_IB_Edge;
input int  Extension_Continuation_Target_Level = 1;

input bool Require_Strong_Price_Action_Confirmation = true;

input color HighColor = clrWhite;
input color LowColor  = clrWhite;
input color MidColor  = clrYellow;
input color ExtensionColor = clrDeepSkyBlue;
input color SignalColor = clrLime;
input int   LineWidth = 2;
input bool  DrawRectangle = true;
input color BoxColor = clrDarkSlateGray;
input bool  ExtendLinesToRight = true;

input bool  Show_Control_Panel = true;
input int   Panel_X = 12;
input int   Panel_Y = 24;
input int   Panel_Width = 360;
input color Panel_Background = clrBlack;
input color Panel_Border = clrDimGray;
input color Panel_Text = clrWhite;
input color Panel_Muted_Text = clrSilver;
input color Panel_Green = clrLimeGreen;
input color Panel_Red = clrTomato;
input color Panel_Amber = clrGold;

double   gIBHigh = 0.0;
double   gIBLow = 0.0;
double   gIBMid = 0.0;
double   gIBRange = 0.0;
datetime gIBStart = 0;
datetime gIBEnd = 0;
datetime gLastBarTime = 0;
string   gStatus = "Waiting for IB to complete";
string   gSignalReason = "";
bool     gTradingEnabled = false;
ENUM_SIGNAL_TYPE gSignalType = Signal_None;
ENUM_EXTENSION_SIGNAL_TYPE gExtensionSignalType = Extension_None;

//+------------------------------------------------------------------+
datetime StrToDayTime(datetime day, string hhmm)
{
   string date = TimeToString(day, TIME_DATE);
   return(StrToTime(date + " " + hhmm));
}

//+------------------------------------------------------------------+
double TolPoints(int pointsValue)
{
   return(pointsValue * Point);
}

//+------------------------------------------------------------------+
double AtrTol(double multiplier)
{
   double atr = iATR(Symbol(), Period(), 14, 1);
   if(atr <= 0.0) return(0.0);
   return(atr * multiplier);
}

//+------------------------------------------------------------------+
double MaxDouble(double a, double b)
{
   if(a > b) return(a);
   return(b);
}

//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBar = iTime(Symbol(), Period(), 0);
   if(currentBar == gLastBarTime) return(false);
   gLastBarTime = currentBar;
   return(true);
}

//+------------------------------------------------------------------+
void DeleteEAObjects()
{
   for(int i = ObjectsTotal() - 1; i >= 0; i--)
   {
      string name = ObjectName(i);
      if(StringFind(name, "IB_EA_") == 0)
         ObjectDelete(name);
   }
}

//+------------------------------------------------------------------+
void DrawLine(string name, datetime t1, datetime t2, double price, color clr, int style)
{
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, LineWidth);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, ExtendLinesToRight);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

//+------------------------------------------------------------------+
void DrawIBObjects()
{
   if(gIBRange <= 0.0) return;

   string tag = TimeToString(gIBStart, TIME_DATE);
   datetime lineEnd = gIBEnd;
   if(ExtendLinesToRight) lineEnd = gIBStart + 86400;

   DrawLine("IB_EA_HIGH_" + tag, gIBStart, lineEnd, gIBHigh, HighColor, STYLE_SOLID);
   DrawLine("IB_EA_LOW_"  + tag, gIBStart, lineEnd, gIBLow,  LowColor, STYLE_SOLID);
   DrawLine("IB_EA_50_"   + tag, gIBStart, lineEnd, gIBMid,  MidColor, STYLE_DASH);

   DrawLine("IB_EA_EXT_UP_05_" + tag, gIBEnd, lineEnd, gIBHigh + 0.5 * gIBRange, ExtensionColor, STYLE_DOT);
   DrawLine("IB_EA_EXT_UP_10_" + tag, gIBEnd, lineEnd, gIBHigh + 1.0 * gIBRange, ExtensionColor, STYLE_DOT);
   DrawLine("IB_EA_EXT_DN_05_" + tag, gIBEnd, lineEnd, gIBLow  - 0.5 * gIBRange, ExtensionColor, STYLE_DOT);
   DrawLine("IB_EA_EXT_DN_10_" + tag, gIBEnd, lineEnd, gIBLow  - 1.0 * gIBRange, ExtensionColor, STYLE_DOT);

   if(DrawRectangle)
   {
      string boxName = "IB_EA_BOX_" + tag;
      if(ObjectFind(0, boxName) >= 0) ObjectDelete(0, boxName);
      ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, gIBStart, gIBHigh, gIBEnd, gIBLow);
      ObjectSetInteger(0, boxName, OBJPROP_COLOR, BoxColor);
      ObjectSetInteger(0, boxName, OBJPROP_BACK, true);
      ObjectSetInteger(0, boxName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, boxName, OBJPROP_WIDTH, 1);
   }
}

//+------------------------------------------------------------------+
bool CalculateTodayIB()
{
   datetime today = TimeCurrent();
   gIBStart = StrToDayTime(today, SessionStart);
   gIBEnd   = StrToDayTime(today, SessionEnd);

   if(TimeCurrent() < gIBEnd)
   {
      gStatus = "Waiting for IB to complete";
      return(false);
   }

   int startShift = iBarShift(Symbol(), Period(), gIBStart, false);
   int endShift = iBarShift(Symbol(), Period(), gIBEnd, false);
   if(startShift < 0 || endShift < 0)
   {
      gStatus = "Waiting for IB data";
      return(false);
   }

   double sessionHigh = -DBL_MAX;
   double sessionLow = DBL_MAX;
   bool found = false;

   for(int shift = startShift; shift >= endShift; shift--)
   {
      datetime barTime = iTime(Symbol(), Period(), shift);
      if(barTime >= gIBStart && barTime <= gIBEnd)
      {
         sessionHigh = MathMax(sessionHigh, iHigh(Symbol(), Period(), shift));
         sessionLow = MathMin(sessionLow, iLow(Symbol(), Period(), shift));
         found = true;
      }
   }

   if(!found || sessionHigh <= sessionLow)
   {
      gStatus = "Waiting for IB data";
      return(false);
   }

   gIBHigh = NormalizeDouble(sessionHigh, Digits);
   gIBLow = NormalizeDouble(sessionLow, Digits);
   gIBMid = NormalizeDouble((gIBHigh + gIBLow) / 2.0, Digits);
   gIBRange = gIBHigh - gIBLow;
   gStatus = "IB completed";
   return(true);
}

//+------------------------------------------------------------------+
int FirstClosedBarAfterIB()
{
   int endShift = iBarShift(Symbol(), Period(), gIBEnd, false);
   if(endShift <= 1) return(1);
   return(endShift - 1);
}

//+------------------------------------------------------------------+
int CountTradesToday()
{
   datetime dayStart = StrToTime(TimeToString(TimeCurrent(), TIME_DATE));
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderOpenTime() >= dayStart)
            count++;
      }
   }

   for(int h = OrdersHistoryTotal() - 1; h >= 0; h--)
   {
      if(OrderSelect(h, SELECT_BY_POS, MODE_HISTORY))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderOpenTime() >= dayStart)
            count++;
      }
   }

   return(count);
}

//+------------------------------------------------------------------+
int EffectiveMaxTradesPerDay()
{
   if(Max_Trades_Per_Day > 0) return(Max_Trades_Per_Day);
   if(One_Trade_Per_Day) return(1);
   return(0);
}

//+------------------------------------------------------------------+
bool DailyTradeLimitReached()
{
   int limit = EffectiveMaxTradesPerDay();
   if(limit <= 0) return(false);
   return(CountTradesToday() >= limit);
}

//+------------------------------------------------------------------+
bool CandleBullish(int shift)
{
   return(iClose(Symbol(), Period(), shift) > iOpen(Symbol(), Period(), shift));
}

//+------------------------------------------------------------------+
bool CandleBearish(int shift)
{
   return(iClose(Symbol(), Period(), shift) < iOpen(Symbol(), Period(), shift));
}

//+------------------------------------------------------------------+
double BodySize(int shift)
{
   return(MathAbs(iClose(Symbol(), Period(), shift) - iOpen(Symbol(), Period(), shift)));
}

//+------------------------------------------------------------------+
double CandleRange(int shift)
{
   return(iHigh(Symbol(), Period(), shift) - iLow(Symbol(), Period(), shift));
}

//+------------------------------------------------------------------+
bool DetectWickOnlyTouch(double level, int shift, string &reason)
{
   double tol = MaxDouble(TolPoints(IB_Mid_Tolerance_Points), AtrTol(IB_Mid_Tolerance_ATR_Multiplier));
   bool touches = (iHigh(Symbol(), Period(), shift) >= level - tol && iLow(Symbol(), Period(), shift) <= level + tol);
   if(!touches) return(false);

   double body = BodySize(shift);
   double range = CandleRange(shift);
   if(range <= 0.0) return(false);

   if(body / range < 0.25 && MathAbs(iClose(Symbol(), Period(), shift) - level) > tol)
   {
      reason = "Wick touch only - no trade. Price touched the level without body acceptance.";
      return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
bool DetectStrongPriceAction(int direction, int shift, string &reason)
{
   double atr = iATR(Symbol(), Period(), 14, shift);
   double body = BodySize(shift);
   double range = CandleRange(shift);
   if(range <= 0.0) return(false);

   bool directionClose = (direction > 0 && CandleBullish(shift)) || (direction < 0 && CandleBearish(shift));
   bool displacement = (atr > 0.0 && body >= atr * 0.45 && directionClose);
   bool strongClose = false;

   if(direction > 0)
      strongClose = (iClose(Symbol(), Period(), shift) >= iLow(Symbol(), Period(), shift) + range * 0.65);
   if(direction < 0)
      strongClose = (iClose(Symbol(), Period(), shift) <= iHigh(Symbol(), Period(), shift) - range * 0.65);

   bool engulfing = false;
   if(direction > 0)
      engulfing = (iClose(Symbol(), Period(), shift) > iOpen(Symbol(), Period(), shift + 1) &&
                   iOpen(Symbol(), Period(), shift) < iClose(Symbol(), Period(), shift + 1));
   if(direction < 0)
      engulfing = (iClose(Symbol(), Period(), shift) < iOpen(Symbol(), Period(), shift + 1) &&
                   iOpen(Symbol(), Period(), shift) > iClose(Symbol(), Period(), shift + 1));

   bool rejection = false;
   if(direction > 0)
      rejection = ((MathMin(iOpen(Symbol(), Period(), shift), iClose(Symbol(), Period(), shift)) - iLow(Symbol(), Period(), shift)) > body * 0.8 && strongClose);
   if(direction < 0)
      rejection = ((iHigh(Symbol(), Period(), shift) - MathMax(iOpen(Symbol(), Period(), shift), iClose(Symbol(), Period(), shift))) > body * 0.8 && strongClose);

   if(displacement || engulfing || rejection)
   {
      reason = "Strong price action confirmed by displacement, engulfing, or rejection candle.";
      return(true);
   }

   reason = "Weak candle - no trade. No directional candle confirmation.";
   return(false);
}

//+------------------------------------------------------------------+
int CountMidTests()
{
   if(!Count_IB_Mid_Tests) return(0);

   double tol = MaxDouble(TolPoints(IB_Mid_Tolerance_Points), AtrTol(IB_Mid_Tolerance_ATR_Multiplier));
   int tests = 0;
   int firstShift = FirstClosedBarAfterIB();

   for(int shift = firstShift; shift >= 1; shift--)
   {
      if(iHigh(Symbol(), Period(), shift) >= gIBMid - tol && iLow(Symbol(), Period(), shift) <= gIBMid + tol)
         tests++;
   }

   return(tests);
}

//+------------------------------------------------------------------+
bool DetectIBMidAcceptance(int direction, string &reason)
{
   double tol = MaxDouble(TolPoints(IB_Mid_Tolerance_Points), AtrTol(IB_Mid_Tolerance_ATR_Multiplier));
   int needed = MathMax(1, IB_Mid_Acceptance_Candles);
   int accepted = 0;

   for(int shift = needed; shift >= 1; shift--)
   {
      if(direction > 0 && iClose(Symbol(), Period(), shift) > gIBMid + tol && BodySize(shift) > CandleRange(shift) * 0.35)
         accepted++;
      if(direction < 0 && iClose(Symbol(), Period(), shift) < gIBMid - tol && BodySize(shift) > CandleRange(shift) * 0.35)
         accepted++;
   }

   if(accepted >= needed)
   {
      reason = "IB Mid acceptance confirmed. Price closed on the correct side of IB 50% with real body.";
      return(true);
   }

   reason = "No confirmation at IB 50%. Price did not accept the mid level.";
   return(false);
}

//+------------------------------------------------------------------+
bool DetectRotationInsideIB(string &reason)
{
   int firstShift = FirstClosedBarAfterIB();
   if(firstShift < 3) return(false);

   int inside = 0;
   int midTests = CountMidTests();

   for(int shift = MathMin(firstShift, 8); shift >= 1; shift--)
   {
      if(iClose(Symbol(), Period(), shift) < gIBHigh && iClose(Symbol(), Period(), shift) > gIBLow)
         inside++;
   }

   if(inside >= 3 && midTests >= 2)
   {
      reason = "Rotation inside IB. Price returned into the range and repeatedly tested IB 50%.";
      return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
bool DetectCleanRetest(int direction, string &reason)
{
   double zone = 0.0;
   if(Treat_Retest_As_Zone)
      zone = MaxDouble(TolPoints(Retest_Zone_Points), AtrTol(Retest_Zone_ATR_Multiplier));
   int shift = 1;

   if(direction > 0)
   {
      bool retest = (iLow(Symbol(), Period(), shift) <= gIBHigh + zone);
      bool notDeepInside = (Allow_Wick_Into_IB_During_Retest || iLow(Symbol(), Period(), shift) >= gIBHigh);
      if(Allow_Wick_Into_IB_During_Retest)
         notDeepInside = (iLow(Symbol(), Period(), shift) >= gIBHigh - TolPoints(Max_Wick_Inside_IB_Points));
      bool closeHeld = (iClose(Symbol(), Period(), shift) >= gIBHigh);
      if(retest && notDeepInside && closeHeld)
      {
         reason = "Clean retest of IB High as support.";
         return(true);
      }
   }

   if(direction < 0)
   {
      bool retest = (iHigh(Symbol(), Period(), shift) >= gIBLow - zone);
      bool notDeepInside = (Allow_Wick_Into_IB_During_Retest || iHigh(Symbol(), Period(), shift) <= gIBLow);
      if(Allow_Wick_Into_IB_During_Retest)
         notDeepInside = (iHigh(Symbol(), Period(), shift) <= gIBLow + TolPoints(Max_Wick_Inside_IB_Points));
      bool closeHeld = (iClose(Symbol(), Period(), shift) <= gIBLow);
      if(retest && notDeepInside && closeHeld)
      {
         reason = "Clean retest of IB Low as resistance.";
         return(true);
      }
   }

   return(false);
}

//+------------------------------------------------------------------+
bool DetectBreakoutRetestContinuation(string &reason, ENUM_SIGNAL_TYPE &signal)
{
   double minBreak = MaxDouble(TolPoints(Retest_Zone_Points), AtrTol(0.05));
   int firstShift = FirstClosedBarAfterIB();
   bool brokeUp = false;
   bool brokeDown = false;

   for(int shift = firstShift; shift >= 1; shift--)
   {
      if(iClose(Symbol(), Period(), shift) > gIBHigh + minBreak || iHigh(Symbol(), Period(), shift) > gIBHigh + minBreak)
         brokeUp = true;
      if(iClose(Symbol(), Period(), shift) < gIBLow - minBreak || iLow(Symbol(), Period(), shift) < gIBLow - minBreak)
         brokeDown = true;
   }

   if(Invalidate_Continuation_If_Close_Back_Inside_IB)
   {
      double upInvalid = gIBHigh - gIBRange * Continuation_Invalidation_Depth_Percent / 100.0;
      double dnInvalid = gIBLow + gIBRange * Continuation_Invalidation_Depth_Percent / 100.0;
      if(brokeUp && iClose(Symbol(), Period(), 1) < upInvalid) brokeUp = false;
      if(brokeDown && iClose(Symbol(), Period(), 1) > dnInvalid) brokeDown = false;
   }

   string retestReason = "";
   string paReason = "";

   if(brokeUp && DetectCleanRetest(1, retestReason))
   {
      if(!Require_Rejection_After_Retest || !Require_Strong_Price_Action_Confirmation || DetectStrongPriceAction(1, 1, paReason))
      {
         signal = Signal_Long;
         reason = "Upside breakout above IB High, clean retest of IB High as support, bullish continuation candle confirmed.";
         return(true);
      }
   }

   if(brokeDown && DetectCleanRetest(-1, retestReason))
   {
      if(!Require_Rejection_After_Retest || !Require_Strong_Price_Action_Confirmation || DetectStrongPriceAction(-1, 1, paReason))
      {
         signal = Signal_Short;
         reason = "Downside breakout below IB Low, clean retest of IB Low as resistance, bearish continuation candle confirmed.";
         return(true);
      }
   }

   return(false);
}

//+------------------------------------------------------------------+
bool DetectFailedAuction(string &reason, ENUM_SIGNAL_TYPE &signal)
{
   int firstShift = FirstClosedBarAfterIB();
   bool brokeDown = false;
   bool brokeUp = false;
   bool returnedInside = false;

   for(int shift = firstShift; shift >= 1; shift--)
   {
      if(iLow(Symbol(), Period(), shift) < gIBLow) brokeDown = true;
      if(iHigh(Symbol(), Period(), shift) > gIBHigh) brokeUp = true;
      if(iClose(Symbol(), Period(), shift) < gIBHigh && iClose(Symbol(), Period(), shift) > gIBLow)
         returnedInside = true;
   }

   if(!returnedInside) return(false);

   int midTests = CountMidTests();
   if(Count_IB_Mid_Tests && midTests > Max_IB_Mid_Tests_Before_No_Trade)
   {
      reason = "Consolidation - no trade. IB 50% was tested too many times without acceptance.";
      return(false);
   }

   string midReason = "";
   string paReason = "";

   if(brokeDown && iClose(Symbol(), Period(), 1) > gIBLow)
   {
      bool midOk = (!Require_IB_Mid_Acceptance || DetectIBMidAcceptance(1, midReason));
      bool paOk = (!Require_Strong_Price_Action_Confirmation || DetectStrongPriceAction(1, 1, paReason));
      if(midOk && paOk)
      {
         signal = Signal_Long;
         reason = "Downside breakout below IB Low, price returned inside IB, bullish displacement candle confirmed failed auction toward IB 50%.";
         return(true);
      }
   }

   if(brokeUp && iClose(Symbol(), Period(), 1) < gIBHigh)
   {
      bool midOk = (!Require_IB_Mid_Acceptance || DetectIBMidAcceptance(-1, midReason));
      bool paOk = (!Require_Strong_Price_Action_Confirmation || DetectStrongPriceAction(-1, 1, paReason));
      if(midOk && paOk)
      {
         signal = Signal_Short;
         reason = "Upside breakout above IB High, price returned inside IB, bearish displacement candle confirmed failed auction toward IB 50%.";
         return(true);
      }
   }

   if(brokeDown || brokeUp)
      gStatus = "Failed Auction possible";

   return(false);
}

//+------------------------------------------------------------------+
bool DetectExtensionReaction(string &reason, ENUM_SIGNAL_TYPE &signal)
{
   if(!Enable_Extension_Reversal) return(false);

   double upper05 = gIBHigh + 0.5 * gIBRange;
   double lower05 = gIBLow - 0.5 * gIBRange;
   double tol = MaxDouble(TolPoints(Retest_Zone_Points), AtrTol(Retest_Zone_ATR_Multiplier));
   string paReason = "";

   if(iHigh(Symbol(), Period(), 1) >= upper05 - tol)
   {
      bool failed = (!Require_Extension_Failure_For_Reversal || iClose(Symbol(), Period(), 1) < upper05);
      bool closeBack = (!Extension_Failure_Close_Back_Level || iClose(Symbol(), Period(), 1) < upper05);
      if(failed && closeBack && (!Require_Strong_Price_Action_Confirmation || DetectStrongPriceAction(-1, 1, paReason)))
      {
         signal = Signal_Short;
         gExtensionSignalType = Reversal_Back_To_IB;
         reason = "Price reached +0.5x extension, failed to continue, bearish rejection candle detected, possible reversal back to IB High.";
         return(true);
      }
   }

   if(iLow(Symbol(), Period(), 1) <= lower05 + tol)
   {
      bool failed = (!Require_Extension_Failure_For_Reversal || iClose(Symbol(), Period(), 1) > lower05);
      bool closeBack = (!Extension_Failure_Close_Back_Level || iClose(Symbol(), Period(), 1) > lower05);
      if(failed && closeBack && (!Require_Strong_Price_Action_Confirmation || DetectStrongPriceAction(1, 1, paReason)))
      {
         signal = Signal_Long;
         gExtensionSignalType = Reversal_Back_To_IB;
         reason = "Price reached -0.5x extension, failed to continue, bullish rejection candle detected, possible reversal back to IB Low.";
         return(true);
      }
   }

   return(false);
}

//+------------------------------------------------------------------+
bool DetectExtensionContinuation(string &reason, ENUM_SIGNAL_TYPE &signal)
{
   if(!Enable_Extension_Continuation) return(false);

   double upper05 = gIBHigh + 0.5 * gIBRange;
   double lower05 = gIBLow - 0.5 * gIBRange;
   double minClose = TolPoints(Extension_Continuation_Min_Close_Distance_Points);
   double zone = MaxDouble(TolPoints(Retest_Zone_Points), AtrTol(Retest_Zone_ATR_Multiplier));
   string paReason = "";

   bool upperBreak = (iClose(Symbol(), Period(), 2) > upper05 + minClose);
   bool upperRetest = (iLow(Symbol(), Period(), 1) <= upper05 + zone && iClose(Symbol(), Period(), 1) > upper05);
   if(upperBreak && (!Require_Extension_Retest_For_Continuation || upperRetest))
   {
      if(!Require_Strong_Price_Action_Confirmation || DetectStrongPriceAction(1, 1, paReason))
      {
         signal = Signal_Long;
         gExtensionSignalType = Continuation_To_Next_Extension;
         reason = "Price broke +0.5x extension, retested it as support, bullish continuation candle confirmed toward +1.0x.";
         return(true);
      }
   }

   bool lowerBreak = (iClose(Symbol(), Period(), 2) < lower05 - minClose);
   bool lowerRetest = (iHigh(Symbol(), Period(), 1) >= lower05 - zone && iClose(Symbol(), Period(), 1) < lower05);
   if(lowerBreak && (!Require_Extension_Retest_For_Continuation || lowerRetest))
   {
      if(!Require_Strong_Price_Action_Confirmation || DetectStrongPriceAction(-1, 1, paReason))
      {
         signal = Signal_Short;
         gExtensionSignalType = Continuation_To_Next_Extension;
         reason = "Price broke -0.5x extension, retested it as resistance, bearish continuation candle confirmed toward -1.0x.";
         return(true);
      }
   }

   return(false);
}

//+------------------------------------------------------------------+
ENUM_MARKET_CONTEXT DetectMarketContextAfterIB(string &reason, ENUM_SIGNAL_TYPE &signal)
{
   signal = Signal_None;
   gExtensionSignalType = Extension_None;

   string wickReason = "";
   if(DetectWickOnlyTouch(gIBMid, 1, wickReason))
   {
      reason = wickReason;
      return(Context_No_Trade);
   }

   if(DetectExtensionContinuation(reason, signal))
      return(Context_Extension_Continuation);

   if(DetectExtensionReaction(reason, signal))
      return(Context_Extension_Reaction);

   if(DetectBreakoutRetestContinuation(reason, signal))
      return(Context_Clean_Breakout);

   if(DetectFailedAuction(reason, signal))
      return(Context_Failed_Auction);

   if(DetectRotationInsideIB(reason))
      return(Context_Rotation_Inside_IB);

   reason = "No trade. Market context after IB is unclear or lacks strong price action confirmation.";
   return(Context_No_Trade);
}

//+------------------------------------------------------------------+
string ContextToStatus(ENUM_MARKET_CONTEXT context, ENUM_SIGNAL_TYPE signal)
{
   if(signal != Signal_None) return("Trade signal valid");
   if(context == Context_Rotation_Inside_IB) return("Consolidation - no trade");
   if(context == Context_Clean_Breakout) return("Continuation confirmed");
   if(context == Context_Failed_Auction) return("Failed Auction confirmed");
   if(context == Context_Extension_Reaction) return("Extension rejection detected");
   if(context == Context_Extension_Continuation) return("Extension continuation detected");
   return("Waiting / No confirmation");
}

//+------------------------------------------------------------------+
double TargetForSignal(ENUM_SIGNAL_TYPE signal)
{
   if(signal == Signal_Long)
   {
      if(gExtensionSignalType == Continuation_To_Next_Extension)
         return(NormalizeDouble(gIBHigh + Extension_Continuation_Target_Level * gIBRange, Digits));
      if(gExtensionSignalType == Reversal_Back_To_IB)
      {
         if(Extension_Reversal_Target_Mode == IB_50) return(gIBMid);
         if(Extension_Reversal_Target_Mode == Back_To_IB_Edge) return(gIBLow);
      }
      if(Bid < gIBMid) return(gIBMid);
      if(Bid < gIBHigh) return(gIBHigh);
      return(NormalizeDouble(gIBHigh + 0.5 * gIBRange, Digits));
   }

   if(signal == Signal_Short)
   {
      if(gExtensionSignalType == Continuation_To_Next_Extension)
         return(NormalizeDouble(gIBLow - Extension_Continuation_Target_Level * gIBRange, Digits));
      if(gExtensionSignalType == Reversal_Back_To_IB)
      {
         if(Extension_Reversal_Target_Mode == IB_50) return(gIBMid);
         if(Extension_Reversal_Target_Mode == Back_To_IB_Edge) return(gIBHigh);
      }
      if(Ask > gIBMid) return(gIBMid);
      if(Ask > gIBLow) return(gIBLow);
      return(NormalizeDouble(gIBLow - 0.5 * gIBRange, Digits));
   }

   return(0.0);
}

//+------------------------------------------------------------------+
double StopForSignal(ENUM_SIGNAL_TYPE signal)
{
   if(signal == Signal_Long)
      return(NormalizeDouble(MathMin(gIBLow, iLow(Symbol(), Period(), 1)) - TolPoints(Stop_Buffer_Points), Digits));
   if(signal == Signal_Short)
      return(NormalizeDouble(MathMax(gIBHigh, iHigh(Symbol(), Period(), 1)) + TolPoints(Stop_Buffer_Points), Digits));
   return(0.0);
}

//+------------------------------------------------------------------+
bool ValidateRiskReward(ENUM_SIGNAL_TYPE signal, double entryPrice, double stopLoss, double takeProfit, string &reason)
{
   if(signal == Signal_None) return(false);
   if(stopLoss <= 0.0 || takeProfit <= 0.0)
   {
      reason = "Risk filter rejected trade. Stop loss or take profit is missing.";
      return(false);
   }

   double risk = MathAbs(entryPrice - stopLoss);
   double reward = MathAbs(takeProfit - entryPrice);

   if(risk <= 0.0 || reward <= 0.0)
   {
      reason = "Risk filter rejected trade. Invalid SL/TP distance.";
      return(false);
   }

   double riskPoints = risk / Point;
   double rewardPoints = reward / Point;
   double rr = reward / risk;

   if(Max_StopLoss_Points > 0 && riskPoints > Max_StopLoss_Points)
   {
      reason = "Risk filter rejected trade. SL too wide: " + DoubleToString(riskPoints, 1) +
               " points, max allowed " + IntegerToString(Max_StopLoss_Points) + ".";
      return(false);
   }

   if(Reject_Trade_If_SL_Bigger_Than_TP && riskPoints >= rewardPoints)
   {
      reason = "Risk filter rejected trade. SL must be smaller than TP: SL " + DoubleToString(riskPoints, 1) +
               " points, TP " + DoubleToString(rewardPoints, 1) + " points.";
      return(false);
   }

   if(Min_Risk_Reward > 0.0 && rr < Min_Risk_Reward)
   {
      reason = "Risk filter rejected trade. RR too weak: " + DoubleToString(rr, 2) +
               ", minimum " + DoubleToString(Min_Risk_Reward, 2) + ".";
      return(false);
   }

   return(true);
}

//+------------------------------------------------------------------+
int BarsForHistoricalContext()
{
   datetime cutoff = TimeCurrent() - Historical_Context_Days * 86400;
   int bars = iBars(Symbol(), Period());
   int count = 0;

   for(int shift = 2; shift < bars; shift++)
   {
      datetime barTime = iTime(Symbol(), Period(), shift);
      if(barTime <= 0 || barTime < cutoff) break;
      count++;
   }

   return(count);
}

//+------------------------------------------------------------------+
bool ValidatePreviousCandlesContext(ENUM_SIGNAL_TYPE signal, string &reason)
{
   if(!Analyze_Previous_Candles) return(true);

   int lookback = MathMax(3, Previous_Candles_To_Analyze);
   int bars = iBars(Symbol(), Period());
   if(bars <= lookback + 2)
   {
      reason = "Historical context rejected trade. Not enough previous candles.";
      return(false);
   }

   int bullish = 0;
   int bearish = 0;
   int counted = 0;

   for(int shift = 2; shift <= lookback + 1; shift++)
   {
      double openPrice = iOpen(Symbol(), Period(), shift);
      double closePrice = iClose(Symbol(), Period(), shift);
      if(closePrice > openPrice) bullish++;
      if(closePrice < openPrice) bearish++;
      counted++;
   }

   if(counted <= 0) return(true);

   double bullishPercent = 100.0 * bullish / counted;
   double bearishPercent = 100.0 * bearish / counted;
   bool momentumOk = true;

   if(Require_Recent_Momentum_With_Trade)
   {
      if(signal == Signal_Long)
         momentumOk = (iClose(Symbol(), Period(), 2) > iClose(Symbol(), Period(), lookback + 1));
      if(signal == Signal_Short)
         momentumOk = (iClose(Symbol(), Period(), 2) < iClose(Symbol(), Period(), lookback + 1));
   }

   if(signal == Signal_Long)
   {
      if(bullishPercent < Min_Previous_Candle_Agreement_Percent || !momentumOk)
      {
         reason = "Historical context rejected LONG. Previous candles do not support bullish continuation.";
         return(false);
      }
   }

   if(signal == Signal_Short)
   {
      if(bearishPercent < Min_Previous_Candle_Agreement_Percent || !momentumOk)
      {
         reason = "Historical context rejected SHORT. Previous candles do not support bearish continuation.";
         return(false);
      }
   }

   return(true);
}

//+------------------------------------------------------------------+
bool FindHistoricalObstacle(ENUM_SIGNAL_TYPE signal, double entryPrice, double takeProfit, double &level)
{
   if(!Avoid_Trade_Into_Historical_SR) return(false);

   int barsToScan = BarsForHistoricalContext();
   if(barsToScan <= 0) return(false);

   double tolerance = TolPoints(Historical_SR_Tolerance_Points);
   bool found = false;

   if(signal == Signal_Long)
   {
      double nearestResistance = DBL_MAX;
      for(int shift = 2; shift <= barsToScan + 1; shift++)
      {
         double highPrice = iHigh(Symbol(), Period(), shift);
         if(highPrice > entryPrice && highPrice < takeProfit)
         {
            if(highPrice < nearestResistance)
            {
               nearestResistance = highPrice;
               found = true;
            }
         }
      }

      if(found && nearestResistance - entryPrice <= tolerance)
      {
         level = nearestResistance;
         return(true);
      }
   }

   if(signal == Signal_Short)
   {
      double nearestSupport = -DBL_MAX;
      for(int shift = 2; shift <= barsToScan + 1; shift++)
      {
         double lowPrice = iLow(Symbol(), Period(), shift);
         if(lowPrice < entryPrice && lowPrice > takeProfit)
         {
            if(lowPrice > nearestSupport)
            {
               nearestSupport = lowPrice;
               found = true;
            }
         }
      }

      if(found && entryPrice - nearestSupport <= tolerance)
      {
         level = nearestSupport;
         return(true);
      }
   }

   return(false);
}

//+------------------------------------------------------------------+
bool ValidateHistoricalContext(ENUM_SIGNAL_TYPE signal, double entryPrice, double takeProfit, string &reason)
{
   if(!Use_Historical_Context_Filter) return(true);

   string candleReason = "";
   if(!ValidatePreviousCandlesContext(signal, candleReason))
   {
      reason = candleReason;
      return(false);
   }

   double obstacle = 0.0;
   if(FindHistoricalObstacle(signal, entryPrice, takeProfit, obstacle))
   {
      if(signal == Signal_Long)
         reason = "Historical context rejected LONG. Recent resistance before TP at " + DoubleToString(obstacle, Digits) + ".";
      if(signal == Signal_Short)
         reason = "Historical context rejected SHORT. Recent support before TP at " + DoubleToString(obstacle, Digits) + ".";
      return(false);
   }

   return(true);
}

//+------------------------------------------------------------------+
void TryOpenTrade(ENUM_SIGNAL_TYPE signal)
{
   if(!gTradingEnabled || signal == Signal_None) return;
   if(DailyTradeLimitReached())
   {
      gStatus = "Daily trade limit reached";
      return;
   }

   RefreshRates();

   int type = OP_BUY;
   double price = Ask;
   if(signal == Signal_Short)
   {
      type = OP_SELL;
      price = Bid;
   }

   double stopLoss = StopForSignal(signal);
   double takeProfit = TargetForSignal(signal);

   if(Extension_Reversal_Target_Mode == Fixed_RR && gExtensionSignalType == Reversal_Back_To_IB)
   {
      double risk = MathAbs(price - stopLoss);
      if(signal == Signal_Long) takeProfit = NormalizeDouble(price + risk * Fixed_RR_Multiplier, Digits);
      if(signal == Signal_Short) takeProfit = NormalizeDouble(price - risk * Fixed_RR_Multiplier, Digits);
   }

   string riskReason = "";
   if(!ValidateRiskReward(signal, price, stopLoss, takeProfit, riskReason))
   {
      gStatus = "Risk filter - no trade";
      gSignalReason = riskReason;
      return;
   }

   string historyReason = "";
   if(!ValidateHistoricalContext(signal, price, takeProfit, historyReason))
   {
      gStatus = "Historical filter - no trade";
      gSignalReason = historyReason;
      return;
   }

   int ticket = OrderSend(Symbol(), type, Lots, price, Slippage, stopLoss, takeProfit, "IB FIRST HOUR EA", MagicNumber, 0, SignalColor);
   if(ticket < 0)
      gSignalReason = gSignalReason + " OrderSend failed. Error: " + IntegerToString(GetLastError());
   else
      gStatus = "Trade signal valid";
}

//+------------------------------------------------------------------+
string PanelName(string suffix)
{
   return("IB_EA_PANEL_" + suffix);
}

//+------------------------------------------------------------------+
void SetPanelBase(string name, int x, int y, int width, int height, color bg, color border)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, border);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
void SetPanelLabel(string name, string text, int x, int y, color textColor, int fontSize = 9)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
void SetPanelButton(string name, string text, int x, int y, int width, int height, color bg, color textColor)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, Panel_Border);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
string TrimReason(string reason)
{
   if(StringLen(reason) <= 62) return(reason);
   return(StringSubstr(reason, 0, 59) + "...");
}

//+------------------------------------------------------------------+
int CountOpenEATrades()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
            count++;
      }
   }
   return(count);
}

//+------------------------------------------------------------------+
string AutoCloseModeText()
{
   if(Auto_Close_Level_Mode == AutoClose_IB_50) return("IB 50%");
   if(Auto_Close_Level_Mode == AutoClose_IB_High) return("IB High");
   if(Auto_Close_Level_Mode == AutoClose_IB_Low) return("IB Low");
   if(Auto_Close_Level_Mode == AutoClose_Extension_Up_05) return("+0.5x");
   if(Auto_Close_Level_Mode == AutoClose_Extension_Down_05) return("-0.5x");
   if(Auto_Close_Level_Mode == AutoClose_Extension_Up_10) return("+1.0x");
   if(Auto_Close_Level_Mode == AutoClose_Extension_Down_10) return("-1.0x");
   if(Auto_Close_Level_Mode == AutoClose_Custom_Price) return("Custom");
   return("Off");
}

//+------------------------------------------------------------------+
double AutoCloseLevel()
{
   if(gIBRange <= 0.0) return(0.0);

   if(Auto_Close_Level_Mode == AutoClose_IB_50) return(gIBMid);
   if(Auto_Close_Level_Mode == AutoClose_IB_High) return(gIBHigh);
   if(Auto_Close_Level_Mode == AutoClose_IB_Low) return(gIBLow);
   if(Auto_Close_Level_Mode == AutoClose_Extension_Up_05) return(NormalizeDouble(gIBHigh + 0.5 * gIBRange, Digits));
   if(Auto_Close_Level_Mode == AutoClose_Extension_Down_05) return(NormalizeDouble(gIBLow - 0.5 * gIBRange, Digits));
   if(Auto_Close_Level_Mode == AutoClose_Extension_Up_10) return(NormalizeDouble(gIBHigh + 1.0 * gIBRange, Digits));
   if(Auto_Close_Level_Mode == AutoClose_Extension_Down_10) return(NormalizeDouble(gIBLow - 1.0 * gIBRange, Digits));
   if(Auto_Close_Level_Mode == AutoClose_Custom_Price) return(NormalizeDouble(Auto_Close_Custom_Price, Digits));

   return(0.0);
}

//+------------------------------------------------------------------+
bool ShouldCloseAtLevel(int orderType, double openPrice, double level)
{
   if(level <= 0.0) return(false);

   if(orderType == OP_BUY)
   {
      if(level >= openPrice && Bid >= level) return(true);
      if(level < openPrice && Bid <= level) return(true);
   }

   if(orderType == OP_SELL)
   {
      if(level <= openPrice && Ask <= level) return(true);
      if(level > openPrice && Ask >= level) return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
void ManageAutoClosePositions()
{
   if(!Auto_Close_Positions) return;
   if(gIBRange <= 0.0) return;

   double level = AutoCloseLevel();
   if(level <= 0.0) return;

   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;

      if(!ShouldCloseAtLevel(type, OrderOpenPrice(), level)) continue;

      bool closed = false;
      if(type == OP_BUY)
         closed = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, Panel_Amber);
      if(type == OP_SELL)
         closed = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, Panel_Amber);

      if(closed)
         gSignalReason = "Auto close executed at " + AutoCloseModeText() + " level " + DoubleToString(level, Digits) + ".";
      else
         gSignalReason = "Auto close failed. Error: " + IntegerToString(GetLastError());
   }
}

//+------------------------------------------------------------------+
void CloseEATrades()
{
   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;

      int type = OrderType();
      bool closed = false;

      if(type == OP_BUY)
         closed = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, Panel_Red);
      if(type == OP_SELL)
         closed = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, Panel_Red);

      if(!closed)
         gSignalReason = "Close EA trade failed. Error: " + IntegerToString(GetLastError());
      else
         gSignalReason = "EA trade closed from panel.";
   }
}

//+------------------------------------------------------------------+
void UpdatePanel()
{
   if(!Show_Control_Panel)
   {
      Comment("");
      return;
   }

   string signalText = "NONE";
   if(gSignalType == Signal_Long) signalText = "LONG";
   if(gSignalType == Signal_Short) signalText = "SHORT";

   color tradeColor = Panel_Red;
   string tradeText = "TRADING: OFF";
   if(gTradingEnabled)
   {
      tradeColor = Panel_Green;
      tradeText = "TRADING: ON";
   }

   color signalColor = Panel_Muted_Text;
   if(gSignalType == Signal_Long) signalColor = Panel_Green;
   if(gSignalType == Signal_Short) signalColor = Panel_Red;

   int x = Panel_X;
   int y = Panel_Y;
   int w = Panel_Width;
   int row = 18;

   SetPanelBase(PanelName("BG"), x, y, w, 318, Panel_Background, Panel_Border);
   SetPanelLabel(PanelName("TITLE"), "IB FIRST HOUR EA", x + 14, y + 10, Panel_Text, 11);
   SetPanelLabel(PanelName("TRADE"), tradeText, x + w - 116, y + 12, tradeColor, 9);

   SetPanelButton(PanelName("START"), "START TRADE", x + 14, y + 36, 104, 24, clrDarkGreen, clrWhite);
   SetPanelButton(PanelName("STOP"), "STOP TRADE", x + 128, y + 36, 104, 24, clrMaroon, clrWhite);
   SetPanelButton(PanelName("CLOSE"), "CLOSE EA TRADES", x + 242, y + 36, 104, 24, clrDimGray, clrWhite);

   int yy = y + 74;
   SetPanelLabel(PanelName("STATUS_L"), "Status", x + 14, yy, Panel_Muted_Text, 8);
   SetPanelLabel(PanelName("STATUS_V"), gStatus, x + 92, yy, Panel_Amber, 8);

   yy += row;
   SetPanelLabel(PanelName("SIGNAL_L"), "Signal", x + 14, yy, Panel_Muted_Text, 8);
   SetPanelLabel(PanelName("SIGNAL_V"), signalText, x + 92, yy, signalColor, 8);

   yy += row;
   SetPanelLabel(PanelName("SESSION_L"), "Session", x + 14, yy, Panel_Muted_Text, 8);
   SetPanelLabel(PanelName("SESSION_V"), SessionStart + " - " + SessionEnd, x + 92, yy, Panel_Text, 8);

   yy += row;
   SetPanelLabel(PanelName("IBH_L"), "IB High", x + 14, yy, Panel_Muted_Text, 8);
   SetPanelLabel(PanelName("IBH_V"), DoubleToString(gIBHigh, Digits), x + 92, yy, Panel_Text, 8);
   SetPanelLabel(PanelName("LOT_L"), "Lots", x + 218, yy, Panel_Muted_Text, 8);
   SetPanelLabel(PanelName("LOT_V"), DoubleToString(Lots, 2), x + 278, yy, Panel_Text, 8);

   yy += row;
   SetPanelLabel(PanelName("IBM_L"), "IB 50%", x + 14, yy, Panel_Muted_Text, 8);
   SetPanelLabel(PanelName("IBM_V"), DoubleToString(gIBMid, Digits), x + 92, yy, Panel_Text, 8);
   SetPanelLabel(PanelName("MAGIC_L"), "Magic", x + 218, yy, Panel_Muted_Text, 8);
   SetPanelLabel(PanelName("MAGIC_V"), IntegerToString(MagicNumber), x + 278, yy, Panel_Text, 8);

   yy += row;
   SetPanelLabel(PanelName("IBL_L"), "IB Low", x + 14, yy, Panel_Muted_Text, 8);
   SetPanelLabel(PanelName("IBL_V"), DoubleToString(gIBLow, Digits), x + 92, yy, Panel_Text, 8);
   SetPanelLabel(PanelName("OPEN_L"), "Open", x + 218, yy, Panel_Muted_Text, 8);
   SetPanelLabel(PanelName("OPEN_V"), IntegerToString(CountOpenEATrades()), x + 278, yy, Panel_Text, 8);

   yy += row;
   SetPanelLabel(PanelName("MID_L"), "Mid tests", x + 14, yy, Panel_Muted_Text, 8);
   SetPanelLabel(PanelName("MID_V"), IntegerToString(CountMidTests()) + " / " + IntegerToString(Max_IB_Mid_Tests_Before_No_Trade), x + 92, yy, Panel_Text, 8);
   SetPanelLabel(PanelName("DAY_L"), "Trades", x + 218, yy, Panel_Muted_Text, 8);
   string dayLimitText = "off";
   if(EffectiveMaxTradesPerDay() > 0)
      dayLimitText = IntegerToString(CountTradesToday()) + " / " + IntegerToString(EffectiveMaxTradesPerDay());
   SetPanelLabel(PanelName("DAY_V"), dayLimitText, x + 278, yy, Panel_Text, 8);

   yy += row;
   SetPanelLabel(PanelName("AUTO_L"), "Auto input", x + 14, yy, Panel_Muted_Text, 8);
   SetPanelLabel(PanelName("AUTO_V"), AutoTrade ? "true" : "false", x + 92, yy, AutoTrade ? Panel_Green : Panel_Red, 8);
   SetPanelLabel(PanelName("PA_L"), "Strong PA", x + 218, yy, Panel_Muted_Text, 8);
   SetPanelLabel(PanelName("PA_V"), Require_Strong_Price_Action_Confirmation ? "required" : "off", x + 278, yy, Panel_Text, 8);

   yy += row;
   SetPanelLabel(PanelName("AC_L"), "Auto close", x + 14, yy, Panel_Muted_Text, 8);
   SetPanelLabel(PanelName("AC_V"), Auto_Close_Positions ? "ON" : "OFF", x + 92, yy, Auto_Close_Positions ? Panel_Green : Panel_Red, 8);
   SetPanelLabel(PanelName("ACL_L"), "Close lvl", x + 218, yy, Panel_Muted_Text, 8);
   SetPanelLabel(PanelName("ACL_V"), AutoCloseModeText(), x + 278, yy, Panel_Text, 8);

   yy += row;
   SetPanelLabel(PanelName("RR_L"), "Min RR", x + 14, yy, Panel_Muted_Text, 8);
   SetPanelLabel(PanelName("RR_V"), DoubleToString(Min_Risk_Reward, 2), x + 92, yy, Panel_Text, 8);
   SetPanelLabel(PanelName("SLTP_L"), "SL < TP", x + 218, yy, Panel_Muted_Text, 8);
   SetPanelLabel(PanelName("SLTP_V"), Reject_Trade_If_SL_Bigger_Than_TP ? "required" : "off", x + 278, yy, Reject_Trade_If_SL_Bigger_Than_TP ? Panel_Green : Panel_Red, 8);

   yy += row;
   SetPanelLabel(PanelName("MSL_L"), "Max SL", x + 14, yy, Panel_Muted_Text, 8);
   SetPanelLabel(PanelName("MSL_V"), IntegerToString(Max_StopLoss_Points), x + 92, yy, Panel_Text, 8);

   yy += row;
   SetPanelLabel(PanelName("HIST_L"), "Hist ctx", x + 14, yy, Panel_Muted_Text, 8);
   SetPanelLabel(PanelName("HIST_V"), Use_Historical_Context_Filter ? "ON" : "OFF", x + 92, yy, Use_Historical_Context_Filter ? Panel_Green : Panel_Red, 8);
   SetPanelLabel(PanelName("PREV_L"), "Prev bars", x + 218, yy, Panel_Muted_Text, 8);
   SetPanelLabel(PanelName("PREV_V"), IntegerToString(Previous_Candles_To_Analyze), x + 278, yy, Panel_Text, 8);

   yy += row + 4;
   SetPanelLabel(PanelName("REASON_L"), "Reason", x + 14, yy, Panel_Muted_Text, 8);
   SetPanelLabel(PanelName("REASON_V"), TrimReason(gSignalReason), x + 14, yy + 16, Panel_Text, 8);

   Comment("");
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
int OnInit()
{
   gLastBarTime = 0;
   gTradingEnabled = AutoTrade;
   gStatus = "Waiting for IB to complete";
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteEAObjects();
   Comment("");
}

//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK) return;

   if(sparam == PanelName("START"))
   {
      gTradingEnabled = true;
      gStatus = "Trading enabled from panel";
      gSignalReason = "Panel START TRADE clicked. EA can open trades after valid confirmation.";
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      UpdatePanel();
      return;
   }

   if(sparam == PanelName("STOP"))
   {
      gTradingEnabled = false;
      gStatus = "Trading stopped from panel";
      gSignalReason = "Panel STOP TRADE clicked. EA will not open new trades.";
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      UpdatePanel();
      return;
   }

   if(sparam == PanelName("CLOSE"))
   {
      CloseEATrades();
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      UpdatePanel();
      return;
   }
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(!IsNewBar())
   {
      if(gIBRange > 0.0)
         ManageAutoClosePositions();
      UpdatePanel();
      return;
   }

   gSignalType = Signal_None;
   gSignalReason = "";

   if(!CalculateTodayIB())
   {
      UpdatePanel();
      return;
   }

   DrawIBObjects();
   ManageAutoClosePositions();

   if(DailyTradeLimitReached())
   {
      gStatus = "Daily trade limit reached";
      gSignalReason = "Daily trade limit reached: " + IntegerToString(CountTradesToday()) + " / " + IntegerToString(EffectiveMaxTradesPerDay()) + ".";
      UpdatePanel();
      return;
   }

   ENUM_SIGNAL_TYPE detectedSignal = Signal_None;
   string reason = "";
   ENUM_MARKET_CONTEXT context = DetectMarketContextAfterIB(reason, detectedSignal);

   gSignalType = detectedSignal;
   gSignalReason = reason;
   gStatus = ContextToStatus(context, detectedSignal);

   if(detectedSignal != Signal_None)
      TryOpenTrade(detectedSignal);

   UpdatePanel();
}
//+------------------------------------------------------------------+

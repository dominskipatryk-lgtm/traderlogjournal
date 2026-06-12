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
   Reversal_Do_IB = 1,
   Kontynuacja_Do_Extension = 2
};

enum ENUM_REVERSAL_TARGET_MODE
{
   TP_Krawedz_IB = 0,
   IB_50 = 1,
   TP_Staly_RR = 2
};

enum ENUM_AUTO_CLOSE_LEVEL_MODE
{
   AutoZamknij_IB_50 = 0,
   AutoZamknij_IB_High = 1,
   AutoZamknij_IB_Low = 2,
   AutoZamknij_Ext_Gora_05 = 3,
   AutoZamknij_Ext_Dol_05 = 4,
   AutoZamknij_Ext_Gora_10 = 5,
   AutoZamknij_Ext_Dol_10 = 6,
   AutoZamknij_Cena_Wlasna = 7
};

enum ENUM_STOPLOSS_MODE
{
   SL_Krawedz_IB = 0,
   SL_Swieca_Sygnalowa = 1
};

input string Start_Sesji = "14:30";
input string Koniec_Sesji   = "15:30";

input bool   Auto_Handel = false;
input double Lot = 0.10;
input int    Poslizg = 3;
input int    Numer_Magic = 14301530;
input int    Bufor_SL_Punkty = 50;
input ENUM_STOPLOSS_MODE Tryb_StopLoss = SL_Swieca_Sygnalowa;
input double Staly_Mnoznik_RR = 1.5;
input bool   Jeden_Trade_Dziennie = true;
input int    Max_Trade_Dziennie = 5;

input bool   Odrzuc_Gdy_SL_Nie_Mniejszy_Niz_TP = true;
input double Min_RR = 1.0;
input int    Max_SL_Punkty = 120;

input bool   Filtr_Kontekstu_Historycznego = true;
input int    Dni_Historii = 5;
input bool   Analizuj_Poprzednie_Swiece = true;
input int    Ile_Poprzednich_Swiec = 12;
input double Min_Zgodnosc_Swiec_Procent = 55.0;
input bool   Wymagaj_Momentum_Z_Trade = true;
input bool   Unikaj_Trade_W_Hist_SR = true;
input int    Tolerancja_Hist_SR_Punkty = 80;

input bool Auto_Zamykanie_Pozycji = false;
input ENUM_AUTO_CLOSE_LEVEL_MODE Tryb_Poziomu_Auto_Zamkniecia = AutoZamknij_IB_50;
input double Auto_Zamknij_Cena_Wlasna = 0.0;

input bool Licz_Testy_IB_50 = true;
input int  Max_Testy_IB_50_Bez_Trade = 3;
input bool Wymagaj_Akceptacji_IB_50 = true;
input int  Swiece_Akceptacji_IB_50 = 1;
input int  Tolerancja_IB_50_Punkty = 30;
input double Tolerancja_IB_50_ATR = 0.10;

input bool Retest_Jako_Strefa = true;
input double Strefa_Retestu_ATR = 0.15;
input int  Strefa_Retestu_Punkty = 50;
input bool Pozwol_Knot_Do_IB_Retest = true;
input int  Max_Knot_W_IB_Punkty = 40;
input bool Wymagaj_Odrzucenia_Po_Retest = true;
input bool Uniewaznij_Gdy_Close_Wroci_Do_IB = true;
input double Glebokosc_Uniewaznienia_Procent = 25.0;

input bool Wlacz_Extension_Reversal = true;
input bool Wlacz_Extension_Kontynuacja = true;
input bool Wymagaj_Retestu_Ext_Kont = true;
input bool Wymagaj_Faila_Ext_Reversal = true;
input bool Ext_Fail_Close_Back_Level = true;
input int  Ext_Kont_Min_Close_Punkty = 30;
input ENUM_REVERSAL_TARGET_MODE Tryb_TP_Ext_Reversal = TP_Krawedz_IB;
input int  Poziom_TP_Ext_Kont = 1;

input bool Wymagaj_Mocnej_Price_Action = true;

input color Kolor_IB_High = clrWhite;
input color Kolor_IB_Low  = clrWhite;
input color Kolor_IB_50  = clrYellow;
input color Kolor_Extension = clrDeepSkyBlue;
input color Kolor_Sygnalu = clrLime;
input int   Grubosc_Linii = 2;
input bool  Rysuj_Box_IB = true;
input color Kolor_Box_IB = clrDarkSlateGray;
input bool  Przedluz_Linie_W_Prawo = true;

input bool  Pokaz_Panel = true;
input int   Panel_X = 12;
input int   Panel_Y = 24;
input int   Szerokosc_Panelu = 360;
input color Panel_Tlo = clrBlack;
input color Panel_Ramka = clrDimGray;
input color Panel_Tekst = clrWhite;
input color Panel_Tekst_Szary = clrSilver;
input color Panel_Zielony = clrLimeGreen;
input color Panel_Czerwony = clrTomato;
input color Panel_Zolty = clrGold;

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
bool     gPanelCollapsed = false;
double   gLotRuntime = 0.0;
int      gMaxTradesRuntime = 0;
double   gMinRRRuntime = 0.0;
int      gMaxSLRuntime = 0;
bool     gHistFilterRuntime = true;
bool     gStrongPARuntime = true;
bool     gAutoCloseRuntime = false;
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
   ObjectSetInteger(0, name, OBJPROP_WIDTH, Grubosc_Linii);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, Przedluz_Linie_W_Prawo);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

//+------------------------------------------------------------------+
void DrawIBObjects()
{
   if(gIBRange <= 0.0) return;

   string tag = TimeToString(gIBStart, TIME_DATE);
   datetime lineEnd = gIBEnd;
   if(Przedluz_Linie_W_Prawo) lineEnd = gIBStart + 86400;

   DrawLine("IB_EA_HIGH_" + tag, gIBStart, lineEnd, gIBHigh, Kolor_IB_High, STYLE_SOLID);
   DrawLine("IB_EA_LOW_"  + tag, gIBStart, lineEnd, gIBLow,  Kolor_IB_Low, STYLE_SOLID);
   DrawLine("IB_EA_50_"   + tag, gIBStart, lineEnd, gIBMid,  Kolor_IB_50, STYLE_DASH);

   DrawLine("IB_EA_EXT_UP_05_" + tag, gIBEnd, lineEnd, gIBHigh + 0.5 * gIBRange, Kolor_Extension, STYLE_DOT);
   DrawLine("IB_EA_EXT_UP_10_" + tag, gIBEnd, lineEnd, gIBHigh + 1.0 * gIBRange, Kolor_Extension, STYLE_DOT);
   DrawLine("IB_EA_EXT_DN_05_" + tag, gIBEnd, lineEnd, gIBLow  - 0.5 * gIBRange, Kolor_Extension, STYLE_DOT);
   DrawLine("IB_EA_EXT_DN_10_" + tag, gIBEnd, lineEnd, gIBLow  - 1.0 * gIBRange, Kolor_Extension, STYLE_DOT);

   if(Rysuj_Box_IB)
   {
      string boxName = "IB_EA_BOX_" + tag;
      if(ObjectFind(0, boxName) >= 0) ObjectDelete(0, boxName);
      ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, gIBStart, gIBHigh, gIBEnd, gIBLow);
      ObjectSetInteger(0, boxName, OBJPROP_COLOR, Kolor_Box_IB);
      ObjectSetInteger(0, boxName, OBJPROP_BACK, true);
      ObjectSetInteger(0, boxName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, boxName, OBJPROP_WIDTH, 1);
   }
}

//+------------------------------------------------------------------+
bool CalculateTodayIB()
{
   datetime today = TimeCurrent();
   gIBStart = StrToDayTime(today, Start_Sesji);
   gIBEnd   = StrToDayTime(today, Koniec_Sesji);

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
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == Numer_Magic && OrderOpenTime() >= dayStart)
            count++;
      }
   }

   for(int h = OrdersHistoryTotal() - 1; h >= 0; h--)
   {
      if(OrderSelect(h, SELECT_BY_POS, MODE_HISTORY))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == Numer_Magic && OrderOpenTime() >= dayStart)
            count++;
      }
   }

   return(count);
}

//+------------------------------------------------------------------+
int EffectiveMaxTradesPerDay()
{
   if(gMaxTradesRuntime > 0) return(gMaxTradesRuntime);
   if(Jeden_Trade_Dziennie) return(1);
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
   double tol = MaxDouble(TolPoints(Tolerancja_IB_50_Punkty), AtrTol(Tolerancja_IB_50_ATR));
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
   if(!Licz_Testy_IB_50) return(0);

   double tol = MaxDouble(TolPoints(Tolerancja_IB_50_Punkty), AtrTol(Tolerancja_IB_50_ATR));
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
   double tol = MaxDouble(TolPoints(Tolerancja_IB_50_Punkty), AtrTol(Tolerancja_IB_50_ATR));
   int needed = MathMax(1, Swiece_Akceptacji_IB_50);
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
   if(Retest_Jako_Strefa)
      zone = MaxDouble(TolPoints(Strefa_Retestu_Punkty), AtrTol(Strefa_Retestu_ATR));
   int shift = 1;

   if(direction > 0)
   {
      bool retest = (iLow(Symbol(), Period(), shift) <= gIBHigh + zone);
      bool notDeepInside = (Pozwol_Knot_Do_IB_Retest || iLow(Symbol(), Period(), shift) >= gIBHigh);
      if(Pozwol_Knot_Do_IB_Retest)
         notDeepInside = (iLow(Symbol(), Period(), shift) >= gIBHigh - TolPoints(Max_Knot_W_IB_Punkty));
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
      bool notDeepInside = (Pozwol_Knot_Do_IB_Retest || iHigh(Symbol(), Period(), shift) <= gIBLow);
      if(Pozwol_Knot_Do_IB_Retest)
         notDeepInside = (iHigh(Symbol(), Period(), shift) <= gIBLow + TolPoints(Max_Knot_W_IB_Punkty));
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
   double minBreak = MaxDouble(TolPoints(Strefa_Retestu_Punkty), AtrTol(0.05));
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

   if(Uniewaznij_Gdy_Close_Wroci_Do_IB)
   {
      double upInvalid = gIBHigh - gIBRange * Glebokosc_Uniewaznienia_Procent / 100.0;
      double dnInvalid = gIBLow + gIBRange * Glebokosc_Uniewaznienia_Procent / 100.0;
      if(brokeUp && iClose(Symbol(), Period(), 1) < upInvalid) brokeUp = false;
      if(brokeDown && iClose(Symbol(), Period(), 1) > dnInvalid) brokeDown = false;
   }

   string retestReason = "";
   string paReason = "";

   if(brokeUp && DetectCleanRetest(1, retestReason))
   {
      if(!Wymagaj_Odrzucenia_Po_Retest || !gStrongPARuntime || DetectStrongPriceAction(1, 1, paReason))
      {
         signal = Signal_Long;
         reason = "Upside breakout above IB High, clean retest of IB High as support, bullish continuation candle confirmed.";
         return(true);
      }
   }

   if(brokeDown && DetectCleanRetest(-1, retestReason))
   {
      if(!Wymagaj_Odrzucenia_Po_Retest || !gStrongPARuntime || DetectStrongPriceAction(-1, 1, paReason))
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
   if(Licz_Testy_IB_50 && midTests > Max_Testy_IB_50_Bez_Trade)
   {
      reason = "Consolidation - no trade. IB 50% was tested too many times without acceptance.";
      return(false);
   }

   string midReason = "";
   string paReason = "";

   if(brokeDown && iClose(Symbol(), Period(), 1) > gIBLow)
   {
      bool midOk = (!Wymagaj_Akceptacji_IB_50 || DetectIBMidAcceptance(1, midReason));
      bool paOk = (!gStrongPARuntime || DetectStrongPriceAction(1, 1, paReason));
      if(midOk && paOk)
      {
         signal = Signal_Long;
         reason = "Downside breakout below IB Low, price returned inside IB, bullish displacement candle confirmed failed auction toward IB 50%.";
         return(true);
      }
   }

   if(brokeUp && iClose(Symbol(), Period(), 1) < gIBHigh)
   {
      bool midOk = (!Wymagaj_Akceptacji_IB_50 || DetectIBMidAcceptance(-1, midReason));
      bool paOk = (!gStrongPARuntime || DetectStrongPriceAction(-1, 1, paReason));
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
   if(!Wlacz_Extension_Reversal) return(false);

   double upper05 = gIBHigh + 0.5 * gIBRange;
   double lower05 = gIBLow - 0.5 * gIBRange;
   double tol = MaxDouble(TolPoints(Strefa_Retestu_Punkty), AtrTol(Strefa_Retestu_ATR));
   string paReason = "";

   if(iHigh(Symbol(), Period(), 1) >= upper05 - tol)
   {
      bool failed = (!Wymagaj_Faila_Ext_Reversal || iClose(Symbol(), Period(), 1) < upper05);
      bool closeBack = (!Ext_Fail_Close_Back_Level || iClose(Symbol(), Period(), 1) < upper05);
      if(failed && closeBack && (!gStrongPARuntime || DetectStrongPriceAction(-1, 1, paReason)))
      {
         signal = Signal_Short;
         gExtensionSignalType = Reversal_Do_IB;
         reason = "Price reached +0.5x extension, failed to continue, bearish rejection candle detected, possible reversal back to IB High.";
         return(true);
      }
   }

   if(iLow(Symbol(), Period(), 1) <= lower05 + tol)
   {
      bool failed = (!Wymagaj_Faila_Ext_Reversal || iClose(Symbol(), Period(), 1) > lower05);
      bool closeBack = (!Ext_Fail_Close_Back_Level || iClose(Symbol(), Period(), 1) > lower05);
      if(failed && closeBack && (!gStrongPARuntime || DetectStrongPriceAction(1, 1, paReason)))
      {
         signal = Signal_Long;
         gExtensionSignalType = Reversal_Do_IB;
         reason = "Price reached -0.5x extension, failed to continue, bullish rejection candle detected, possible reversal back to IB Low.";
         return(true);
      }
   }

   return(false);
}

//+------------------------------------------------------------------+
bool DetectExtensionContinuation(string &reason, ENUM_SIGNAL_TYPE &signal)
{
   if(!Wlacz_Extension_Kontynuacja) return(false);

   double upper05 = gIBHigh + 0.5 * gIBRange;
   double lower05 = gIBLow - 0.5 * gIBRange;
   double minClose = TolPoints(Ext_Kont_Min_Close_Punkty);
   double zone = MaxDouble(TolPoints(Strefa_Retestu_Punkty), AtrTol(Strefa_Retestu_ATR));
   string paReason = "";

   bool upperBreak = (iClose(Symbol(), Period(), 2) > upper05 + minClose);
   bool upperRetest = (iLow(Symbol(), Period(), 1) <= upper05 + zone && iClose(Symbol(), Period(), 1) > upper05);
   if(upperBreak && (!Wymagaj_Retestu_Ext_Kont || upperRetest))
   {
      if(!gStrongPARuntime || DetectStrongPriceAction(1, 1, paReason))
      {
         signal = Signal_Long;
         gExtensionSignalType = Kontynuacja_Do_Extension;
         reason = "Price broke +0.5x extension, retested it as support, bullish continuation candle confirmed toward +1.0x.";
         return(true);
      }
   }

   bool lowerBreak = (iClose(Symbol(), Period(), 2) < lower05 - minClose);
   bool lowerRetest = (iHigh(Symbol(), Period(), 1) >= lower05 - zone && iClose(Symbol(), Period(), 1) < lower05);
   if(lowerBreak && (!Wymagaj_Retestu_Ext_Kont || lowerRetest))
   {
      if(!gStrongPARuntime || DetectStrongPriceAction(-1, 1, paReason))
      {
         signal = Signal_Short;
         gExtensionSignalType = Kontynuacja_Do_Extension;
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
      if(gExtensionSignalType == Kontynuacja_Do_Extension)
         return(NormalizeDouble(gIBHigh + MathMin(1, Poziom_TP_Ext_Kont) * gIBRange, Digits));
      if(gExtensionSignalType == Reversal_Do_IB)
      {
         if(Tryb_TP_Ext_Reversal == IB_50) return(gIBMid);
         if(Tryb_TP_Ext_Reversal == TP_Krawedz_IB) return(gIBLow);
      }
      if(Bid < gIBMid) return(gIBMid);
      if(Bid < gIBHigh) return(gIBHigh);
      return(NormalizeDouble(gIBHigh + 0.5 * gIBRange, Digits));
   }

   if(signal == Signal_Short)
   {
      if(gExtensionSignalType == Kontynuacja_Do_Extension)
         return(NormalizeDouble(gIBLow - MathMin(1, Poziom_TP_Ext_Kont) * gIBRange, Digits));
      if(gExtensionSignalType == Reversal_Do_IB)
      {
         if(Tryb_TP_Ext_Reversal == IB_50) return(gIBMid);
         if(Tryb_TP_Ext_Reversal == TP_Krawedz_IB) return(gIBHigh);
      }
      if(Ask > gIBMid) return(gIBMid);
      if(Ask > gIBLow) return(gIBLow);
      return(NormalizeDouble(gIBLow - 0.5 * gIBRange, Digits));
   }

   return(0.0);
}

//+------------------------------------------------------------------+
double AllowedLowerTradeLevel()
{
   if(gIBRange <= 0.0) return(0.0);
   return(NormalizeDouble(gIBLow - gIBRange, Digits));
}

//+------------------------------------------------------------------+
double AllowedUpperTradeLevel()
{
   if(gIBRange <= 0.0) return(0.0);
   return(NormalizeDouble(gIBHigh + gIBRange, Digits));
}

//+------------------------------------------------------------------+
void ClampTradeLevelsToIBZone(ENUM_SIGNAL_TYPE signal, double entryPrice, double &stopLoss, double &takeProfit)
{
   double lower = AllowedLowerTradeLevel();
   double upper = AllowedUpperTradeLevel();
   if(lower <= 0.0 || upper <= 0.0 || lower >= upper) return;

   if(signal == Signal_Long)
   {
      if(stopLoss < lower) stopLoss = lower;
      if(takeProfit > upper) takeProfit = upper;
   }

   if(signal == Signal_Short)
   {
      if(stopLoss > upper) stopLoss = upper;
      if(takeProfit < lower) takeProfit = lower;
   }

   stopLoss = NormalizeDouble(stopLoss, Digits);
   takeProfit = NormalizeDouble(takeProfit, Digits);
}

//+------------------------------------------------------------------+
void ClampStopToMaxRisk(ENUM_SIGNAL_TYPE signal, double entryPrice, double &stopLoss)
{
   if(gMaxSLRuntime <= 0) return;

   double maxRisk = TolPoints(gMaxSLRuntime);

   if(signal == Signal_Long)
   {
      double maxAllowedStop = entryPrice - maxRisk;
      if(stopLoss < maxAllowedStop) stopLoss = maxAllowedStop;
   }

   if(signal == Signal_Short)
   {
      double maxAllowedStop = entryPrice + maxRisk;
      if(stopLoss > maxAllowedStop) stopLoss = maxAllowedStop;
   }

   stopLoss = NormalizeDouble(stopLoss, Digits);
}

//+------------------------------------------------------------------+
double StopForSignal(ENUM_SIGNAL_TYPE signal)
{
   if(signal == Signal_Long)
   {
      if(Tryb_StopLoss == SL_Swieca_Sygnalowa)
         return(NormalizeDouble(iLow(Symbol(), Period(), 1) - TolPoints(Bufor_SL_Punkty), Digits));
      return(NormalizeDouble(MathMin(gIBLow, iLow(Symbol(), Period(), 1)) - TolPoints(Bufor_SL_Punkty), Digits));
   }

   if(signal == Signal_Short)
   {
      if(Tryb_StopLoss == SL_Swieca_Sygnalowa)
         return(NormalizeDouble(iHigh(Symbol(), Period(), 1) + TolPoints(Bufor_SL_Punkty), Digits));
      return(NormalizeDouble(MathMax(gIBHigh, iHigh(Symbol(), Period(), 1)) + TolPoints(Bufor_SL_Punkty), Digits));
   }

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

   if(gMaxSLRuntime > 0 && riskPoints > gMaxSLRuntime)
   {
      reason = "Risk filter rejected trade. SL too wide: " + DoubleToString(riskPoints, 1) +
               " points, max allowed " + IntegerToString(gMaxSLRuntime) + ".";
      return(false);
   }

   if(Odrzuc_Gdy_SL_Nie_Mniejszy_Niz_TP && riskPoints >= rewardPoints)
   {
      reason = "Risk filter rejected trade. SL must be smaller than TP: SL " + DoubleToString(riskPoints, 1) +
               " points, TP " + DoubleToString(rewardPoints, 1) + " points.";
      return(false);
   }

   if(gMinRRRuntime > 0.0 && rr < gMinRRRuntime)
   {
      reason = "Risk filter rejected trade. RR too weak: " + DoubleToString(rr, 2) +
               ", minimum " + DoubleToString(gMinRRRuntime, 2) + ".";
      return(false);
   }

   return(true);
}

//+------------------------------------------------------------------+
int BarsForHistoricalContext()
{
   datetime cutoff = TimeCurrent() - Dni_Historii * 86400;
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
   if(!Analizuj_Poprzednie_Swiece) return(true);

   int lookback = MathMax(3, Ile_Poprzednich_Swiec);
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

   if(Wymagaj_Momentum_Z_Trade)
   {
      if(signal == Signal_Long)
         momentumOk = (iClose(Symbol(), Period(), 2) > iClose(Symbol(), Period(), lookback + 1));
      if(signal == Signal_Short)
         momentumOk = (iClose(Symbol(), Period(), 2) < iClose(Symbol(), Period(), lookback + 1));
   }

   if(signal == Signal_Long)
   {
      if(bullishPercent < Min_Zgodnosc_Swiec_Procent || !momentumOk)
      {
         reason = "Historical context rejected LONG. Previous candles do not support bullish continuation.";
         return(false);
      }
   }

   if(signal == Signal_Short)
   {
      if(bearishPercent < Min_Zgodnosc_Swiec_Procent || !momentumOk)
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
   if(!Unikaj_Trade_W_Hist_SR) return(false);

   int barsToScan = BarsForHistoricalContext();
   if(barsToScan <= 0) return(false);

   double tolerance = TolPoints(Tolerancja_Hist_SR_Punkty);
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
   if(!gHistFilterRuntime) return(true);

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

   if(Tryb_TP_Ext_Reversal == TP_Staly_RR && gExtensionSignalType == Reversal_Do_IB)
   {
      double risk = MathAbs(price - stopLoss);
      if(signal == Signal_Long) takeProfit = NormalizeDouble(price + risk * Staly_Mnoznik_RR, Digits);
      if(signal == Signal_Short) takeProfit = NormalizeDouble(price - risk * Staly_Mnoznik_RR, Digits);
   }

   ClampTradeLevelsToIBZone(signal, price, stopLoss, takeProfit);
   ClampStopToMaxRisk(signal, price, stopLoss);

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

   int ticket = OrderSend(Symbol(), type, gLotRuntime, price, Poslizg, stopLoss, takeProfit, "IB FIRST HOUR EA", Numer_Magic, 0, Kolor_Sygnalu);
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
void DeletePanelObjects()
{
   for(int i = ObjectsTotal() - 1; i >= 0; i--)
   {
      string name = ObjectName(i);
      if(StringFind(name, "IB_EA_PANEL_") == 0)
         ObjectDelete(name);
   }
}

//+------------------------------------------------------------------+
double NormalizeRuntimeLot(double value)
{
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

   if(minLot <= 0.0) minLot = 0.01;
   if(maxLot <= 0.0) maxLot = 100.0;
   if(lotStep <= 0.0) lotStep = 0.01;

   value = MathMax(minLot, MathMin(maxLot, value));
   value = MathFloor(value / lotStep + 0.5) * lotStep;
   return(NormalizeDouble(value, 2));
}

//+------------------------------------------------------------------+
void ClampRuntimeSettings()
{
   gLotRuntime = NormalizeRuntimeLot(gLotRuntime);
   if(gMaxTradesRuntime < 0) gMaxTradesRuntime = 0;
   if(gMaxTradesRuntime > 50) gMaxTradesRuntime = 50;
   if(gMinRRRuntime < 0.0) gMinRRRuntime = 0.0;
   if(gMinRRRuntime > 10.0) gMinRRRuntime = 10.0;
   if(gMaxSLRuntime < 0) gMaxSLRuntime = 0;
   if(gMaxSLRuntime > 5000) gMaxSLRuntime = 5000;
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
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, Panel_Ramka);
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
   if(StringLen(reason) <= 72) return(reason);
   return(StringSubstr(reason, 0, 69) + "...");
}

//+------------------------------------------------------------------+
string ReasonLine(string reason, int lineIndex)
{
   int maxLen = 54;
   int start = lineIndex * maxLen;

   if(StringLen(reason) <= start) return("");

   string part = StringSubstr(reason, start, maxLen);
   if(lineIndex == 2 && StringLen(reason) > start + maxLen)
      part = StringSubstr(reason, start, maxLen - 3) + "...";

   return(part);
}

//+------------------------------------------------------------------+
int CountOpenEATrades()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == Numer_Magic)
            count++;
      }
   }
   return(count);
}

//+------------------------------------------------------------------+
string AutoCloseModeText()
{
   if(Tryb_Poziomu_Auto_Zamkniecia == AutoZamknij_IB_50) return("IB 50%");
   if(Tryb_Poziomu_Auto_Zamkniecia == AutoZamknij_IB_High) return("IB High");
   if(Tryb_Poziomu_Auto_Zamkniecia == AutoZamknij_IB_Low) return("IB Low");
   if(Tryb_Poziomu_Auto_Zamkniecia == AutoZamknij_Ext_Gora_05) return("+0.5x");
   if(Tryb_Poziomu_Auto_Zamkniecia == AutoZamknij_Ext_Dol_05) return("-0.5x");
   if(Tryb_Poziomu_Auto_Zamkniecia == AutoZamknij_Ext_Gora_10) return("+1.0x");
   if(Tryb_Poziomu_Auto_Zamkniecia == AutoZamknij_Ext_Dol_10) return("-1.0x");
   if(Tryb_Poziomu_Auto_Zamkniecia == AutoZamknij_Cena_Wlasna) return("Custom");
   return("Off");
}

//+------------------------------------------------------------------+
string StopLossModeText()
{
   if(Tryb_StopLoss == SL_Swieca_Sygnalowa) return("Signal");
   return("IB edge");
}

//+------------------------------------------------------------------+
string PanelStatusText(string status)
{
   if(status == "Waiting for IB to complete") return("Czekam na koniec IB");
   if(status == "Waiting / No confirmation") return("Czekam / brak potw.");
   if(status == "Trade signal valid") return("Sygnal wazny");
   if(status == "Risk filter - no trade") return("Filtr ryzyka - brak");
   if(status == "Historical filter - no trade") return("Filtr historii - brak");
   if(status == "Daily trade limit reached") return("Limit dzienny");
   if(status == "Consolidation - no trade") return("Konsolidacja - brak");
   if(status == "Trading enabled from panel") return("Handel wlaczony");
   if(status == "Trading stopped from panel") return("Handel zatrzymany");
   if(status == "IB completed") return("IB gotowe");
   if(status == "Failed Auction possible") return("Mozliwy Failed Auction");
   if(status == "Continuation confirmed") return("Kontynuacja potw.");
   if(status == "Failed Auction confirmed") return("Failed Auction potw.");
   if(status == "Extension rejection detected") return("Odrzucenie extension");
   if(status == "Extension continuation detected") return("Kontynuacja extension");
   return(status);
}

//+------------------------------------------------------------------+
double AutoCloseLevel()
{
   if(gIBRange <= 0.0) return(0.0);

   if(Tryb_Poziomu_Auto_Zamkniecia == AutoZamknij_IB_50) return(gIBMid);
   if(Tryb_Poziomu_Auto_Zamkniecia == AutoZamknij_IB_High) return(gIBHigh);
   if(Tryb_Poziomu_Auto_Zamkniecia == AutoZamknij_IB_Low) return(gIBLow);
   if(Tryb_Poziomu_Auto_Zamkniecia == AutoZamknij_Ext_Gora_05) return(NormalizeDouble(gIBHigh + 0.5 * gIBRange, Digits));
   if(Tryb_Poziomu_Auto_Zamkniecia == AutoZamknij_Ext_Dol_05) return(NormalizeDouble(gIBLow - 0.5 * gIBRange, Digits));
   if(Tryb_Poziomu_Auto_Zamkniecia == AutoZamknij_Ext_Gora_10) return(NormalizeDouble(gIBHigh + 1.0 * gIBRange, Digits));
   if(Tryb_Poziomu_Auto_Zamkniecia == AutoZamknij_Ext_Dol_10) return(NormalizeDouble(gIBLow - 1.0 * gIBRange, Digits));
   if(Tryb_Poziomu_Auto_Zamkniecia == AutoZamknij_Cena_Wlasna) return(NormalizeDouble(Auto_Zamknij_Cena_Wlasna, Digits));

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
   if(!gAutoCloseRuntime) return;
   if(gIBRange <= 0.0) return;

   double level = AutoCloseLevel();
   if(level <= 0.0) return;

   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != Numer_Magic) continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;

      if(!ShouldCloseAtLevel(type, OrderOpenPrice(), level)) continue;

      bool closed = false;
      if(type == OP_BUY)
         closed = OrderClose(OrderTicket(), OrderLots(), Bid, Poslizg, Panel_Zolty);
      if(type == OP_SELL)
         closed = OrderClose(OrderTicket(), OrderLots(), Ask, Poslizg, Panel_Zolty);

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
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != Numer_Magic) continue;

      int type = OrderType();
      bool closed = false;

      if(type == OP_BUY)
         closed = OrderClose(OrderTicket(), OrderLots(), Bid, Poslizg, Panel_Czerwony);
      if(type == OP_SELL)
         closed = OrderClose(OrderTicket(), OrderLots(), Ask, Poslizg, Panel_Czerwony);

      if(!closed)
         gSignalReason = "Close EA trade failed. Error: " + IntegerToString(GetLastError());
      else
         gSignalReason = "EA trade closed from panel.";
   }
}

//+------------------------------------------------------------------+
void UpdatePanel()
{
   if(!Pokaz_Panel)
   {
      Comment("");
      return;
   }

   string signalText = "NONE";
   if(gSignalType == Signal_None) signalText = "BRAK";
   if(gSignalType == Signal_Long) signalText = "KUPNO";
   if(gSignalType == Signal_Short) signalText = "SPRZEDAZ";

   color tradeColor = Panel_Czerwony;
   string tradeText = "HANDEL: OFF";
   if(gTradingEnabled)
   {
      tradeColor = Panel_Zielony;
      tradeText = "HANDEL: ON";
   }

   color signalColor = Panel_Tekst_Szary;
   if(gSignalType == Signal_Long) signalColor = Panel_Zielony;
   if(gSignalType == Signal_Short) signalColor = Panel_Czerwony;

   int x = Panel_X;
   int y = Panel_Y;
   int w = Szerokosc_Panelu;
   int row = 18;

   if(gPanelCollapsed)
   {
      SetPanelBase(PanelName("BG"), x, y, w, 46, Panel_Tlo, Panel_Ramka);
      SetPanelLabel(PanelName("TITLE"), "IB FIRST HOUR EA", x + 14, y + 12, Panel_Tekst, 10);
      SetPanelLabel(PanelName("TRADE"), tradeText, x + 166, y + 13, tradeColor, 8);
      SetPanelButton(PanelName("TOGGLE"), "+", x + w - 34, y + 8, 24, 24, clrFireBrick, clrWhite);
      Comment("");
      ChartRedraw(0);
      return;
   }

   SetPanelBase(PanelName("BG"), x, y, w, 430, Panel_Tlo, Panel_Ramka);
   SetPanelLabel(PanelName("TITLE"), "IB FIRST HOUR EA", x + 14, y + 10, Panel_Tekst, 11);
   SetPanelLabel(PanelName("TRADE"), tradeText, x + w - 116, y + 12, tradeColor, 9);
   SetPanelButton(PanelName("TOGGLE"), "-", x + w - 34, y + 8, 24, 24, clrFireBrick, clrWhite);

   SetPanelButton(PanelName("START"), "WLACZ", x + 14, y + 36, 104, 24, clrDarkGreen, clrWhite);
   SetPanelButton(PanelName("STOP"), "STOP", x + 128, y + 36, 104, 24, clrMaroon, clrWhite);
   SetPanelButton(PanelName("CLOSE"), "ZAMKNIJ", x + 242, y + 36, 64, 24, clrSlateGray, clrWhite);

   SetPanelButton(PanelName("LOT_DN"), "LOT -", x + 14, y + 66, 52, 20, clrSteelBlue, clrWhite);
   SetPanelButton(PanelName("LOT_UP"), "LOT +", x + 70, y + 66, 52, 20, clrSteelBlue, clrWhite);
   SetPanelButton(PanelName("TRD_DN"), "DZIEN -", x + 128, y + 66, 52, 20, clrDarkSlateBlue, clrWhite);
   SetPanelButton(PanelName("TRD_UP"), "DZIEN +", x + 184, y + 66, 52, 20, clrDarkSlateBlue, clrWhite);
   SetPanelButton(PanelName("RR_DN"), "RR -", x + 242, y + 66, 52, 20, clrTeal, clrWhite);
   SetPanelButton(PanelName("RR_UP"), "RR +", x + 298, y + 66, 48, 20, clrTeal, clrWhite);

   SetPanelButton(PanelName("SL_DN"), "SL -", x + 14, y + 90, 52, 20, clrSaddleBrown, clrWhite);
   SetPanelButton(PanelName("SL_UP"), "SL +", x + 70, y + 90, 52, 20, clrSaddleBrown, clrWhite);
   SetPanelButton(PanelName("HIST_TOGGLE"), "HIST", x + 128, y + 90, 52, 20, gHistFilterRuntime ? clrDarkGreen : clrMaroon, clrWhite);
   SetPanelButton(PanelName("PA_TOGGLE"), "PA", x + 184, y + 90, 52, 20, gStrongPARuntime ? clrDarkGreen : clrMaroon, clrWhite);
   SetPanelButton(PanelName("AC_TOGGLE"), "AUTO", x + 242, y + 90, 52, 20, gAutoCloseRuntime ? clrDarkGreen : clrMaroon, clrWhite);

   int yy = y + 124;
   SetPanelLabel(PanelName("STATUS_L"), "Status", x + 14, yy, Panel_Tekst_Szary, 8);
   SetPanelLabel(PanelName("STATUS_V"), PanelStatusText(gStatus), x + 92, yy, Panel_Zolty, 8);

   yy += row;
   SetPanelLabel(PanelName("SIGNAL_L"), "Sygnal", x + 14, yy, Panel_Tekst_Szary, 8);
   SetPanelLabel(PanelName("SIGNAL_V"), signalText, x + 92, yy, signalColor, 8);

   yy += row;
   SetPanelLabel(PanelName("SESSION_L"), "Sesja", x + 14, yy, Panel_Tekst_Szary, 8);
   SetPanelLabel(PanelName("SESSION_V"), Start_Sesji + " - " + Koniec_Sesji, x + 92, yy, Panel_Tekst, 8);

   yy += row;
   SetPanelLabel(PanelName("IBH_L"), "IB High", x + 14, yy, Panel_Tekst_Szary, 8);
   SetPanelLabel(PanelName("IBH_V"), DoubleToString(gIBHigh, Digits), x + 92, yy, Panel_Tekst, 8);
   SetPanelLabel(PanelName("LOT_L"), "Lot", x + 218, yy, Panel_Tekst_Szary, 8);
   SetPanelLabel(PanelName("LOT_V"), DoubleToString(gLotRuntime, 2), x + 278, yy, Panel_Tekst, 8);

   yy += row;
   SetPanelLabel(PanelName("IBM_L"), "IB 50%", x + 14, yy, Panel_Tekst_Szary, 8);
   SetPanelLabel(PanelName("IBM_V"), DoubleToString(gIBMid, Digits), x + 92, yy, Panel_Tekst, 8);
   SetPanelLabel(PanelName("MAGIC_L"), "Magic", x + 218, yy, Panel_Tekst_Szary, 8);
   SetPanelLabel(PanelName("MAGIC_V"), IntegerToString(Numer_Magic), x + 278, yy, Panel_Tekst, 8);

   yy += row;
   SetPanelLabel(PanelName("IBL_L"), "IB Low", x + 14, yy, Panel_Tekst_Szary, 8);
   SetPanelLabel(PanelName("IBL_V"), DoubleToString(gIBLow, Digits), x + 92, yy, Panel_Tekst, 8);
   SetPanelLabel(PanelName("OPEN_L"), "Otwarte", x + 218, yy, Panel_Tekst_Szary, 8);
   SetPanelLabel(PanelName("OPEN_V"), IntegerToString(CountOpenEATrades()), x + 278, yy, Panel_Tekst, 8);

   yy += row;
   SetPanelLabel(PanelName("MID_L"), "Testy 50%", x + 14, yy, Panel_Tekst_Szary, 8);
   SetPanelLabel(PanelName("MID_V"), IntegerToString(CountMidTests()) + " / " + IntegerToString(Max_Testy_IB_50_Bez_Trade), x + 92, yy, Panel_Tekst, 8);
   SetPanelLabel(PanelName("DAY_L"), "Trans.", x + 218, yy, Panel_Tekst_Szary, 8);
   string dayLimitText = "off";
   if(EffectiveMaxTradesPerDay() > 0)
      dayLimitText = IntegerToString(CountTradesToday()) + " / " + IntegerToString(EffectiveMaxTradesPerDay());
   SetPanelLabel(PanelName("DAY_V"), dayLimitText, x + 278, yy, Panel_Tekst, 8);

   yy += row;
   SetPanelLabel(PanelName("AUTO_L"), "Auto start", x + 14, yy, Panel_Tekst_Szary, 8);
   SetPanelLabel(PanelName("AUTO_V"), Auto_Handel ? "true" : "false", x + 92, yy, Auto_Handel ? Panel_Zielony : Panel_Czerwony, 8);
   SetPanelLabel(PanelName("PA_L"), "Mocna PA", x + 218, yy, Panel_Tekst_Szary, 8);
   SetPanelLabel(PanelName("PA_V"), gStrongPARuntime ? "wymag." : "off", x + 278, yy, Panel_Tekst, 8);

   yy += row;
   SetPanelLabel(PanelName("AC_L"), "Auto zam.", x + 14, yy, Panel_Tekst_Szary, 8);
   SetPanelLabel(PanelName("AC_V"), gAutoCloseRuntime ? "ON" : "OFF", x + 92, yy, gAutoCloseRuntime ? Panel_Zielony : Panel_Czerwony, 8);
   SetPanelLabel(PanelName("ACL_L"), "Poziom zam.", x + 218, yy, Panel_Tekst_Szary, 8);
   SetPanelLabel(PanelName("ACL_V"), AutoCloseModeText(), x + 278, yy, Panel_Tekst, 8);

   yy += row;
   SetPanelLabel(PanelName("RR_L"), "Min RR", x + 14, yy, Panel_Tekst_Szary, 8);
   SetPanelLabel(PanelName("RR_V"), DoubleToString(gMinRRRuntime, 2), x + 92, yy, Panel_Tekst, 8);
   SetPanelLabel(PanelName("SLTP_L"), "SL < TP", x + 218, yy, Panel_Tekst_Szary, 8);
   SetPanelLabel(PanelName("SLTP_V"), Odrzuc_Gdy_SL_Nie_Mniejszy_Niz_TP ? "wymag." : "off", x + 278, yy, Odrzuc_Gdy_SL_Nie_Mniejszy_Niz_TP ? Panel_Zielony : Panel_Czerwony, 8);

   yy += row;
   SetPanelLabel(PanelName("MSL_L"), "Max SL", x + 14, yy, Panel_Tekst_Szary, 8);
   SetPanelLabel(PanelName("MSL_V"), IntegerToString(gMaxSLRuntime), x + 92, yy, Panel_Tekst, 8);
   SetPanelLabel(PanelName("SLM_L"), "Tryb SL", x + 218, yy, Panel_Tekst_Szary, 8);
   SetPanelLabel(PanelName("SLM_V"), StopLossModeText(), x + 278, yy, Panel_Tekst, 8);

   yy += row;
   SetPanelLabel(PanelName("HIST_L"), "Kontekst", x + 14, yy, Panel_Tekst_Szary, 8);
   SetPanelLabel(PanelName("HIST_V"), gHistFilterRuntime ? "ON" : "OFF", x + 92, yy, gHistFilterRuntime ? Panel_Zielony : Panel_Czerwony, 8);
   SetPanelLabel(PanelName("PREV_L"), "Swiece", x + 218, yy, Panel_Tekst_Szary, 8);
   SetPanelLabel(PanelName("PREV_V"), IntegerToString(Ile_Poprzednich_Swiec), x + 278, yy, Panel_Tekst, 8);

   yy += row + 4;
   SetPanelLabel(PanelName("REASON_L"), "Powod", x + 14, yy, Panel_Tekst_Szary, 8);
   SetPanelLabel(PanelName("REASON_V1"), ReasonLine(gSignalReason, 0), x + 14, yy + 16, Panel_Tekst, 8);
   SetPanelLabel(PanelName("REASON_V2"), ReasonLine(gSignalReason, 1), x + 14, yy + 32, Panel_Tekst, 8);
   SetPanelLabel(PanelName("REASON_V3"), ReasonLine(gSignalReason, 2), x + 14, yy + 48, Panel_Tekst, 8);

   Comment("");
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
int OnInit()
{
   gLastBarTime = 0;
   gTradingEnabled = Auto_Handel;
   gPanelCollapsed = false;
   gLotRuntime = Lot;
   gMaxTradesRuntime = Max_Trade_Dziennie;
   gMinRRRuntime = Min_RR;
   gMaxSLRuntime = Max_SL_Punkty;
   gHistFilterRuntime = Filtr_Kontekstu_Historycznego;
   gStrongPARuntime = Wymagaj_Mocnej_Price_Action;
   gAutoCloseRuntime = Auto_Zamykanie_Pozycji;
   ClampRuntimeSettings();
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

   if(sparam == PanelName("TOGGLE"))
   {
      gPanelCollapsed = !gPanelCollapsed;
      DeletePanelObjects();
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      UpdatePanel();
      return;
   }

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

   if(sparam == PanelName("LOT_DN"))
   {
      gLotRuntime -= 0.01;
      ClampRuntimeSettings();
      gSignalReason = "Panel changed lots to " + DoubleToString(gLotRuntime, 2) + ".";
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      UpdatePanel();
      return;
   }

   if(sparam == PanelName("LOT_UP"))
   {
      gLotRuntime += 0.01;
      ClampRuntimeSettings();
      gSignalReason = "Panel changed lots to " + DoubleToString(gLotRuntime, 2) + ".";
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      UpdatePanel();
      return;
   }

   if(sparam == PanelName("TRD_DN"))
   {
      gMaxTradesRuntime--;
      ClampRuntimeSettings();
      gSignalReason = "Panel changed max trades per day to " + IntegerToString(gMaxTradesRuntime) + ".";
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      UpdatePanel();
      return;
   }

   if(sparam == PanelName("TRD_UP"))
   {
      gMaxTradesRuntime++;
      ClampRuntimeSettings();
      gSignalReason = "Panel changed max trades per day to " + IntegerToString(gMaxTradesRuntime) + ".";
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      UpdatePanel();
      return;
   }

   if(sparam == PanelName("RR_DN"))
   {
      gMinRRRuntime -= 0.10;
      ClampRuntimeSettings();
      gSignalReason = "Panel changed minimum RR to " + DoubleToString(gMinRRRuntime, 2) + ".";
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      UpdatePanel();
      return;
   }

   if(sparam == PanelName("RR_UP"))
   {
      gMinRRRuntime += 0.10;
      ClampRuntimeSettings();
      gSignalReason = "Panel changed minimum RR to " + DoubleToString(gMinRRRuntime, 2) + ".";
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      UpdatePanel();
      return;
   }

   if(sparam == PanelName("SL_DN"))
   {
      gMaxSLRuntime -= 10;
      ClampRuntimeSettings();
      gSignalReason = "Panel changed max SL to " + IntegerToString(gMaxSLRuntime) + " points.";
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      UpdatePanel();
      return;
   }

   if(sparam == PanelName("SL_UP"))
   {
      gMaxSLRuntime += 10;
      ClampRuntimeSettings();
      gSignalReason = "Panel changed max SL to " + IntegerToString(gMaxSLRuntime) + " points.";
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      UpdatePanel();
      return;
   }

   if(sparam == PanelName("HIST_TOGGLE"))
   {
      gHistFilterRuntime = !gHistFilterRuntime;
      gSignalReason = gHistFilterRuntime ? "Historical context filter enabled from panel." : "Historical context filter disabled from panel.";
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      UpdatePanel();
      return;
   }

   if(sparam == PanelName("PA_TOGGLE"))
   {
      gStrongPARuntime = !gStrongPARuntime;
      gSignalReason = gStrongPARuntime ? "Strong price action confirmation enabled from panel." : "Strong price action confirmation disabled from panel.";
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      UpdatePanel();
      return;
   }

   if(sparam == PanelName("AC_TOGGLE"))
   {
      gAutoCloseRuntime = !gAutoCloseRuntime;
      gSignalReason = gAutoCloseRuntime ? "Auto close enabled from panel." : "Auto close disabled from panel.";
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


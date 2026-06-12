//+------------------------------------------------------------------+
//| TraderLogJournal_FIBO_DCA_v1.mq4                                 |
//| FIBO GRID + DCA Manager — v1.0                                   |
//| traderlogjournal.com                                             |
//+------------------------------------------------------------------+
#property copyright "TraderLogJournal 2026"
#property link      "https://traderlogjournal.com"
#property version   "1.00"
#property strict

input int    MagicNumber = 20261010;
input int    PnlX        = 20;
input int    PnlY        = 260;
input int    TimerSec    = 1;

// ── Panel element names ───────────────────────────────────────────
#define PNL_BG   "FD_Bg"
// FIBO
#define B_DRAW   "FD_Draw"
#define B_CLR    "FD_Clr"
#define B_MODE   "FD_Mode"
#define B_BBUY   "FD_BBuy"
#define B_BSEL   "FD_BSel"
#define E_N      "FD_N"
#define E_TP     "FD_TP"
#define E_RISK   "FD_Risk"
#define E_SL     "FD_SL"
// DCA
#define B_DBUY   "FD_DBuy"
#define B_DSEL   "FD_DSel"
#define B_DSTOP  "FD_DStop"
#define E_DLOT   "FD_DLot"
#define E_DSTEP  "FD_DStep"
#define E_DMAX   "FD_DMax"
#define E_DSL    "FD_DSL"
#define E_DTP    "FD_DTP"

// ── Fibo line names ───────────────────────────────────────────────
#define L_TOP    "TLJ_FTOP"
#define L_BOT    "TLJ_FBOT"
#define L_PFX    "TLJ_FGL_"

// ── Colors ────────────────────────────────────────────────────────
#define cBG      C'13,17,23'
#define cHDR     C'0,212,161'
#define cSUB     C'100,120,135'
#define cTXT     C'180,195,210'
#define cBTN     C'30,45,61'
#define cGRN     C'0,90,50'
#define cRED     C'90,20,20'
#define cEDT     C'20,30,45'
#define cBORD    C'45,65,85'

// ── State ─────────────────────────────────────────────────────────
bool _modeAll = true;   // FIBO: true=ALL STOP, false=#1 MARKET+STOP
int  _dcaDir  = -1;     // DCA: -1=off, 0=BUY, 1=SELL
int  _W       = 232;

//+------------------------------------------------------------------+
//| Lifecycle                                                        |
//+------------------------------------------------------------------+
int OnInit() {
   EventSetTimer(TimerSec);
   CreatePanel();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   EventKillTimer();
   ObjectsDeleteAll(0, "FD_");
}

void OnTimer() {
   UpdateFiboPreview();
   UpdatePanelStatus();
   if (_dcaDir >= 0) CheckDCA();
}

void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam) {
   if (id == CHARTEVENT_OBJECT_DRAG &&
      (sparam == L_TOP || sparam == L_BOT))
      UpdateFiboPreview();
   if (id == CHARTEVENT_OBJECT_ENDEDIT && sparam == E_N)
      UpdateFiboPreview();
   if (id == CHARTEVENT_OBJECT_CLICK)
      HandleClick(sparam);
}

void HandleClick(string s) {
   if (s == B_DRAW)  OnDrawFibo();
   if (s == B_CLR)   ClearFibo(true);
   if (s == B_MODE)  ToggleFiboMode();
   if (s == B_BBUY)  BuildGrid(OP_BUY);
   if (s == B_BSEL)  BuildGrid(OP_SELL);
   if (s == B_DBUY)  StartDCA(OP_BUY);
   if (s == B_DSEL)  StartDCA(OP_SELL);
   if (s == B_DSTOP) StopDCA();
}

//+------------------------------------------------------------------+
//| Panel helpers                                                    |
//+------------------------------------------------------------------+
void MakeRect(string n, int x, int y, int w, int h, color bg) {
   if (ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE,   x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE,   y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE,        w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE,        h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR,      bg);
   ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE,  BORDER_FLAT);
   ObjectSetInteger(0, n, OBJPROP_COLOR,        cBORD);
   ObjectSetInteger(0, n, OBJPROP_ZORDER,       1);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE,   false);
   ObjectSetInteger(0, n, OBJPROP_BACK,         false);
}

void MakeLbl(string n, int x, int y, string txt, color c, int fs=9, bool bold=false) {
   if (ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE,  y);
   ObjectSetString (0, n, OBJPROP_TEXT,       txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR,      c);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE,   fs);
   if (bold) ObjectSetString(0, n, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_ZORDER,     5);
}

void MakeBtn(string n, int x, int y, int w, int h, string txt, color tc, color bg, int fs=8) {
   if (ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE,   x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE,   y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE,        w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE,        h);
   ObjectSetString (0, n, OBJPROP_TEXT,         txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR,        tc);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR,      bg);
   ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, cBORD);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE,     fs);
   ObjectSetInteger(0, n, OBJPROP_ZORDER,       10);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE,   false);
}

void MakeEdit(string n, int x, int y, int w, int h, string val) {
   if (ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE,   x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE,   y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE,        w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE,        h);
   ObjectSetString (0, n, OBJPROP_TEXT,         val);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR,      cEDT);
   ObjectSetInteger(0, n, OBJPROP_COLOR,        cTXT);
   ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, cBORD);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE,     9);
   ObjectSetInteger(0, n, OBJPROP_ALIGN,        ALIGN_CENTER);
   ObjectSetInteger(0, n, OBJPROP_ZORDER,       10);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE,   false);
}

//+------------------------------------------------------------------+
//| Create Panel                                                     |
//+------------------------------------------------------------------+
void CreatePanel() {
   int x = PnlX, y = PnlY, w = _W;
   int totalH = 338;
   MakeRect(PNL_BG, x, y, w, totalH, cBG);

   // ── Tytuł ────────────────────────────────────────────────────
   MakeLbl("FD_T1", x+10, y+8, "TLJ", cHDR, 10, true);
   MakeLbl("FD_T2", x+40, y+8, "FIBO GRID + DCA", cSUB, 10, false);

   int cy = y + 30;

   // ══════════════════════════════════════════════════════════════
   // SEKCJA: FIBO GRID
   // ══════════════════════════════════════════════════════════════
   MakeRect("FD_FHdr", x, cy, w, 22, C'18,25,38');
   MakeLbl("FD_FLbl", x+10, cy+5, "▶  FIBO GRID", cHDR, 9, true);
   cy += 22;

   // Ryzyko% | SL
   MakeLbl("FD_L_Rsk",  x+8,   cy+7, "Ryzyko%",  cSUB, 8);
   MakeEdit(E_RISK,      x+68,  cy+3, 46, 20, "0.25");
   MakeLbl("FD_L_SL",   x+122, cy+7, "SL",       cSUB, 8);
   MakeEdit(E_SL,        x+138, cy+3, 46, 20, "30");
   MakeLbl("FD_L_SLu",  x+188, cy+7, "pip",      cSUB, 7);
   cy += 26;

   // N | TP
   MakeLbl("FD_L_N",    x+8,  cy+7, "N",   cSUB, 8);
   MakeEdit(E_N,         x+24, cy+3, 36, 20, "4");
   MakeLbl("FD_L_TP",   x+68, cy+7, "TP",  cSUB, 8);
   MakeEdit(E_TP,        x+84, cy+3, 46, 20, "24");
   MakeLbl("FD_L_TPu",  x+134,cy+7, "pip", cSUB, 7);
   cy += 26;

   // Rysuj / Kasuj
   MakeBtn(B_DRAW, x+8,   cy+3, 104, 22, "Rysuj linie", cHDR,      cBTN);
   MakeBtn(B_CLR,  x+118, cy+3, 106, 22, "Kasuj linie", cTXT,      cBTN);
   cy += 28;

   // Tryb
   MakeBtn(B_MODE, x+8, cy+3, 216, 22, "■  TRYB: ALL STOP", cHDR, cBTN);
   cy += 28;

   // BUILD BUY / SELL
   MakeBtn(B_BBUY, x+8,   cy+3, 106, 24, "▲  BUILD BUY",  clrWhite, cGRN);
   MakeBtn(B_BSEL, x+118, cy+3, 106, 24, "▼  BUILD SELL", clrWhite, cRED);
   cy += 32;

   // ══════════════════════════════════════════════════════════════
   // SEKCJA: DCA MANAGER
   // ══════════════════════════════════════════════════════════════
   MakeRect("FD_DHdr", x, cy, w, 22, C'18,25,38');
   MakeLbl("FD_DLbl", x+10, cy+5, "▶  DCA MANAGER", cHDR, 9, true);
   cy += 22;

   // Lot | Krok | Mx
   MakeLbl("FD_DL1",  x+8,   cy+7, "Lot",   cSUB, 8);
   MakeEdit(E_DLOT,   x+32,  cy+3, 50, 20, "0.10");
   MakeLbl("FD_DL2",  x+88,  cy+7, "Krok",  cSUB, 8);
   MakeEdit(E_DSTEP,  x+118, cy+3, 44, 20, "10");
   MakeLbl("FD_DL3",  x+166, cy+7, "pip",   cSUB, 7);
   MakeLbl("FD_DL4",  x+186, cy+7, "Mx",    cSUB, 8);
   MakeEdit(E_DMAX,   x+204, cy+3, 22, 20, "5");
   cy += 26;

   // SL | TP
   MakeLbl("FD_DL5",  x+8,  cy+7, "SL",   cSUB, 8);
   MakeEdit(E_DSL,    x+26, cy+3, 46, 20, "50");
   MakeLbl("FD_DL6",  x+78, cy+7, "TP",   cSUB, 8);
   MakeEdit(E_DTP,    x+96, cy+3, 46, 20, "100");
   MakeLbl("FD_DL7",  x+146,cy+7, "pip",  cSUB, 7);
   MakeLbl("FD_Sta",  x+160,cy+7, "● --", cSUB, 8);
   cy += 26;

   // DCA BUY / SELL
   MakeBtn(B_DBUY, x+8,   cy+3, 106, 24, "▲  DCA BUY",  clrWhite, cGRN);
   MakeBtn(B_DSEL, x+118, cy+3, 106, 24, "▼  DCA SELL", clrWhite, cRED);
   cy += 30;

   // STOP DCA
   MakeBtn(B_DSTOP, x+8, cy+3, 216, 22, "■  STOP DCA + CLOSE ALL", C'255,100,100', cBTN);

   ChartRedraw();
}

void UpdatePanelStatus() {
   if (ObjectFind(0, "FD_Sta") < 0) return;
   string sta; color c;
   if (_dcaDir == 0)  { sta = "● BUY WŁ";  c = cHDR; }
   else if (_dcaDir == 1) { sta = "● SELL WŁ"; c = C'220,80,80'; }
   else               { sta = "● WYŁ";      c = cSUB; }
   ObjectSetString (0, "FD_Sta", OBJPROP_TEXT,  sta);
   ObjectSetInteger(0, "FD_Sta", OBJPROP_COLOR, c);
}

//+------------------------------------------------------------------+
//| FIBO GRID                                                        |
//+------------------------------------------------------------------+
void OnDrawFibo() {
   double pipSz = GetPipSize(Symbol());
   double ask   = MarketInfo(Symbol(), MODE_ASK);
   int    dg    = (int)MarketInfo(Symbol(), MODE_DIGITS);

   if (ObjectFind(0, L_TOP) >= 0 && ObjectFind(0, L_BOT) >= 0) {
      UpdateFiboPreview();
      return;
   }
   double top = NormalizeDouble(ask + 20 * pipSz, dg);
   double bot = NormalizeDouble(ask +  5 * pipSz, dg);
   MakeFiboLine(L_TOP, top, C'0,200,120', "▲ TOP (szczyt strefy)");
   MakeFiboLine(L_BOT, bot, C'220,60,60', "▼ BOT (dół strefy)");
   UpdateFiboPreview();
}

void MakeFiboLine(string name, double price, color c, string lbl) {
   if (ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      c);
   ObjectSetInteger(0, name, OBJPROP_STYLE,      STYLE_DASHDOT);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,      2);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTED,   false);
   ObjectSetString (0, name, OBJPROP_TEXT,       "TLJ " + lbl);
   ChartRedraw();
}

void UpdateFiboPreview() {
   if (ObjectFind(0, L_TOP) < 0 || ObjectFind(0, L_BOT) < 0) return;
   double top = ObjectGetDouble(0, L_TOP, OBJPROP_PRICE);
   double bot = ObjectGetDouble(0, L_BOT, OBJPROP_PRICE);
   int    n   = (int)StringToInteger(ObjectGetString(0, E_N, OBJPROP_TEXT));
   int    dg  = (int)MarketInfo(Symbol(), MODE_DIGITS);
   if (n < 1 || n > 20 || MathAbs(top - bot) < MarketInfo(Symbol(), MODE_POINT)) return;

   for (int i = 1; i <= 20; i++) ObjectDelete(0, L_PFX + IntegerToString(i));

   double step = (top - bot) / MathMax(n - 1, 1);
   for (int i = 1; i <= n; i++) {
      double lvl = NormalizeDouble(bot + (i - 1) * step, dg);
      string nm  = L_PFX + IntegerToString(i);
      if (ObjectFind(0, nm) >= 0) ObjectDelete(0, nm);
      ObjectCreate(0, nm, OBJ_HLINE, 0, 0, lvl);
      ObjectSetInteger(0, nm, OBJPROP_COLOR,      C'70,100,140');
      ObjectSetInteger(0, nm, OBJPROP_STYLE,      STYLE_DOT);
      ObjectSetInteger(0, nm, OBJPROP_WIDTH,      1);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetString (0, nm, OBJPROP_TEXT,
         "TLJ GL #" + IntegerToString(i) + " @ " + DoubleToString(lvl, dg));
   }
   ChartRedraw();
}

void ClearFibo(bool andBoundaries) {
   for (int i = 1; i <= 20; i++) ObjectDelete(0, L_PFX + IntegerToString(i));
   if (andBoundaries) { ObjectDelete(0, L_TOP); ObjectDelete(0, L_BOT); }
   ChartRedraw();
}

void ToggleFiboMode() {
   _modeAll = !_modeAll;
   string txt = _modeAll ? "■  TRYB: ALL STOP" : "■  TRYB: #1 MARKET + STOP";
   ObjectSetString(0, B_MODE, OBJPROP_TEXT, txt);
   ChartRedraw();
}

void BuildGrid(int direction) {
   if (ObjectFind(0, L_TOP) < 0 || ObjectFind(0, L_BOT) < 0) {
      Alert("TLJ FIBO: Najpierw kliknij [Rysuj linie] i ustaw strefę!");
      return;
   }
   int    n       = (int)StringToInteger(ObjectGetString(0, E_N,    OBJPROP_TEXT));
   double riskPct = StringToDouble(ObjectGetString(0, E_RISK, OBJPROP_TEXT));
   double slPips  = StringToDouble(ObjectGetString(0, E_SL,   OBJPROP_TEXT));
   double tpPips  = StringToDouble(ObjectGetString(0, E_TP,   OBJPROP_TEXT));

   if (n < 2 || n > 20)          { Alert("TLJ FIBO: N musi być 2–20");           return; }
   if (riskPct <= 0 || slPips <= 0) { Alert("TLJ FIBO: Ustaw Ryzyko% i SL pips"); return; }

   double pipSz   = GetPipSize(Symbol());
   int    dg      = (int)MarketInfo(Symbol(), MODE_DIGITS);
   double ask     = MarketInfo(Symbol(), MODE_ASK);
   double bid     = MarketInfo(Symbol(), MODE_BID);
   double lstep   = MarketInfo(Symbol(), MODE_LOTSTEP);
   double lmin    = MarketInfo(Symbol(), MODE_MINLOT);
   double lmax    = MarketInfo(Symbol(), MODE_MAXLOT);
   double minDist = MarketInfo(Symbol(), MODE_STOPLEVEL) * MarketInfo(Symbol(), MODE_POINT);

   // Zbierz poziomy z linii podglądu
   double levels[];
   ArrayResize(levels, n);
   int found = 0;
   for (int i = 1; i <= n && found < n; i++) {
      string nm = L_PFX + IntegerToString(i);
      if (ObjectFind(0, nm) < 0) continue;
      levels[found++] = ObjectGetDouble(0, nm, OBJPROP_PRICE);
   }
   if (found < n) {
      Alert("TLJ FIBO: Brakuje ", n - found, " linii podglądu. Kliknij [Rysuj linie].");
      return;
   }

   // Sortuj poziomy: BUY → rosnąco, SELL → malejąco
   for (int a = 0; a < found - 1; a++)
      for (int b = a + 1; b < found; b++)
         if ((direction == OP_BUY  && levels[a] > levels[b]) ||
             (direction == OP_SELL && levels[a] < levels[b])) {
            double tmp = levels[a]; levels[a] = levels[b]; levels[b] = tmp;
         }

   int placed = 0;
   for (int i = 0; i < found; i++) {
      double entryPrice = NormalizeDouble(levels[i], dg);
      double sl = 0, tp = 0;
      int    orderType;
      bool   useMarket = (!_modeAll && i == 0);

      // Faron Mode SL: #1 = pełny slPips; #2+ = entry poprzedniego poziomu
      double slPipsUsed = (i == 0) ? slPips : MathAbs(levels[i] - levels[i-1]) / pipSz;

      if (direction == OP_BUY) {
         sl = (i == 0) ? NormalizeDouble(entryPrice - slPips * pipSz, dg)
                       : NormalizeDouble(levels[i-1], dg);
         tp = (tpPips > 0) ? NormalizeDouble(entryPrice + tpPips * pipSz, dg) : 0;

         if (useMarket) {
            orderType   = OP_BUY;
            entryPrice  = NormalizeDouble(ask, dg);
            sl          = NormalizeDouble(ask - slPips * pipSz, dg);
            tp          = (tpPips > 0) ? NormalizeDouble(ask + tpPips * pipSz, dg) : 0;
         } else {
            if (entryPrice <= ask + minDist) {
               Print("TLJ FIBO: BUY poziom #", i+1, " za blisko lub poniżej Ask — pomijam");
               continue;
            }
            orderType = OP_BUYSTOP;
         }
      } else {
         sl = (i == 0) ? NormalizeDouble(entryPrice + slPips * pipSz, dg)
                       : NormalizeDouble(levels[i-1], dg);
         tp = (tpPips > 0) ? NormalizeDouble(entryPrice - tpPips * pipSz, dg) : 0;

         if (useMarket) {
            orderType  = OP_SELL;
            entryPrice = NormalizeDouble(bid, dg);
            sl         = NormalizeDouble(bid + slPips * pipSz, dg);
            tp         = (tpPips > 0) ? NormalizeDouble(bid - tpPips * pipSz, dg) : 0;
         } else {
            if (entryPrice >= bid - minDist) {
               Print("TLJ FIBO: SELL poziom #", i+1, " za blisko lub powyżej Bid — pomijam");
               continue;
            }
            orderType = OP_SELLSTOP;
         }
      }

      double lot = MathFloor(CalcLot(riskPct, slPipsUsed) / lstep) * lstep;
      lot = MathMax(lmin, MathMin(lmax, lot));

      string comment = "TLJ_FIBO_" + IntegerToString(i+1) + "of" + IntegerToString(n);
      color  arrowC  = (direction == OP_BUY) ? C'0,200,120' : C'220,60,60';
      int    ticket  = OrderSend(Symbol(), orderType, lot, entryPrice, 3, sl, tp,
                                 comment, MagicNumber, 0, arrowC);
      if (ticket > 0) placed++;
      else Print("TLJ FIBO: Błąd OrderSend poziom #", i+1, " err=", GetLastError());
   }

   Print("TLJ FIBO: Postawiono ", placed, "/", n, " zleceń (",
         direction == OP_BUY ? "BUY" : "SELL", ")");
   if (placed > 0) ClearFibo(true);
}

//+------------------------------------------------------------------+
//| DCA Manager                                                      |
//+------------------------------------------------------------------+
void StartDCA(int dir) {
   double lot  = StringToDouble(ObjectGetString(0, E_DLOT,  OBJPROP_TEXT));
   double slP  = StringToDouble(ObjectGetString(0, E_DSL,   OBJPROP_TEXT));
   double tpP  = StringToDouble(ObjectGetString(0, E_DTP,   OBJPROP_TEXT));
   if (lot <= 0) { Alert("TLJ DCA: Ustaw Lot"); return; }

   double pipSz = GetPipSize(Symbol());
   int    dg    = (int)MarketInfo(Symbol(), MODE_DIGITS);
   double price = (dir == OP_BUY) ? MarketInfo(Symbol(), MODE_ASK)
                                   : MarketInfo(Symbol(), MODE_BID);
   double sl    = (slP > 0) ? ((dir == OP_BUY)
                                ? NormalizeDouble(price - slP * pipSz, dg)
                                : NormalizeDouble(price + slP * pipSz, dg)) : 0;
   double tp    = (tpP > 0) ? ((dir == OP_BUY)
                                ? NormalizeDouble(price + tpP * pipSz, dg)
                                : NormalizeDouble(price - tpP * pipSz, dg)) : 0;

   double lstep = MarketInfo(Symbol(), MODE_LOTSTEP);
   lot = MathFloor(lot / lstep) * lstep;
   lot = MathMax(MarketInfo(Symbol(), MODE_MINLOT),
                 MathMin(MarketInfo(Symbol(), MODE_MAXLOT), lot));

   int ticket = OrderSend(Symbol(), dir, lot, price, 3, sl, tp,
                          "TLJ_DCA_1", MagicNumber, 0,
                          dir == OP_BUY ? C'0,200,120' : C'220,60,60');
   if (ticket > 0) {
      _dcaDir = dir;
      Print("TLJ DCA: Start ", dir == OP_BUY ? "BUY" : "SELL",
            " lot=", lot, " SL=", DoubleToString(sl, dg), " TP=", DoubleToString(tp, dg));
   } else {
      Alert("TLJ DCA: Błąd otwarcia pozycji: ", GetLastError());
   }
}

void CheckDCA() {
   double pipSz  = GetPipSize(Symbol());
   double step   = StringToDouble(ObjectGetString(0, E_DSTEP, OBJPROP_TEXT));
   int    maxN   = (int)StringToInteger(ObjectGetString(0, E_DMAX, OBJPROP_TEXT));
   double lot    = StringToDouble(ObjectGetString(0, E_DLOT,  OBJPROP_TEXT));
   double slP    = StringToDouble(ObjectGetString(0, E_DSL,   OBJPROP_TEXT));
   double tpP    = StringToDouble(ObjectGetString(0, E_DTP,   OBJPROP_TEXT));
   int    dg     = (int)MarketInfo(Symbol(), MODE_DIGITS);

   // Znajdź wszystkie otwarte pozycje DCA
   double lastEntry  = 0;
   int    dcaCount   = 0;
   int    lastTicket = 0;

   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderMagicNumber() != MagicNumber)             continue;
      if (OrderSymbol()      != Symbol())                continue;
      if (OrderType()        >  1)                       continue;
      if (StringFind(OrderComment(), "TLJ_DCA_") < 0)   continue;
      dcaCount++;
      if (OrderTicket() > lastTicket) {
         lastTicket = OrderTicket();
         lastEntry  = OrderOpenPrice();
      }
   }

   if (dcaCount == 0) { _dcaDir = -1; return; }
   if (dcaCount >= maxN) return;

   double livePrice = (_dcaDir == OP_BUY)
                      ? MarketInfo(Symbol(), MODE_BID)
                      : MarketInfo(Symbol(), MODE_ASK);
   double lossPips  = (_dcaDir == OP_BUY)
                      ? (lastEntry - livePrice) / pipSz
                      : (livePrice - lastEntry) / pipSz;

   if (lossPips < step) return;

   // Otwórz kolejną DCA pozycję
   double price = (_dcaDir == OP_BUY)
                  ? MarketInfo(Symbol(), MODE_ASK)
                  : MarketInfo(Symbol(), MODE_BID);
   double sl = (slP > 0) ? ((_dcaDir == OP_BUY)
                             ? NormalizeDouble(price - slP * pipSz, dg)
                             : NormalizeDouble(price + slP * pipSz, dg)) : 0;
   double tp = (tpP > 0) ? ((_dcaDir == OP_BUY)
                             ? NormalizeDouble(price + tpP * pipSz, dg)
                             : NormalizeDouble(price - tpP * pipSz, dg)) : 0;

   double lstep2 = MarketInfo(Symbol(), MODE_LOTSTEP);
   lot = MathFloor(lot / lstep2) * lstep2;
   lot = MathMax(MarketInfo(Symbol(), MODE_MINLOT),
                 MathMin(MarketInfo(Symbol(), MODE_MAXLOT), lot));

   string comment = "TLJ_DCA_" + IntegerToString(dcaCount + 1);
   color  arrowC  = (_dcaDir == OP_BUY) ? C'0,200,120' : C'220,60,60';
   int    ticket  = OrderSend(Symbol(), _dcaDir, lot, price, 3, sl, tp,
                              comment, MagicNumber, 0, arrowC);
   if (ticket > 0) {
      Print("TLJ DCA #", dcaCount+1, ": dokładka @ ", DoubleToString(price, dg),
            " (strata była ", DoubleToString(lossPips, 1), " pipsów)");
      if (tpP > 0) UpdateAllDcaTP(tp);
   } else {
      Print("TLJ DCA: Błąd dokładki #", dcaCount+1, " err=", GetLastError());
   }
}

void UpdateAllDcaTP(double newTP) {
   double pt = MarketInfo(Symbol(), MODE_POINT);
   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderMagicNumber() != MagicNumber)             continue;
      if (OrderSymbol()      != Symbol())                continue;
      if (OrderType()        >  1)                       continue;
      if (StringFind(OrderComment(), "TLJ_DCA_") < 0)   continue;
      if (MathAbs(OrderTakeProfit() - newTP) < pt)       continue;
      OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), newTP, 0, clrYellow);
   }
}

void StopDCA() {
   _dcaDir = -1;
   int    dg  = (int)MarketInfo(Symbol(), MODE_DIGITS);
   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderMagicNumber() != MagicNumber)             continue;
      if (OrderSymbol()      != Symbol())                continue;
      if (OrderType()        >  1)                       continue;
      if (StringFind(OrderComment(), "TLJ_DCA_") < 0)   continue;
      double cp = (OrderType() == OP_BUY)
                  ? MarketInfo(Symbol(), MODE_BID)
                  : MarketInfo(Symbol(), MODE_ASK);
      OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(cp, dg), 3, clrOrange);
   }
   Print("TLJ DCA: Zatrzymano i zamknięto wszystkie pozycje DCA");
}

//+------------------------------------------------------------------+
//| CalcLot — identyczna z głównym EA                               |
//+------------------------------------------------------------------+
double CalcLot(double riskPct, double slPips) {
   if (riskPct <= 0 || slPips <= 0) return 0;
   double equity    = AccountEquity();
   double riskMoney = equity * riskPct / 100.0;
   double tickVal   = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);
   double pipSz     = GetPipSize(Symbol());
   if (tickSize <= 0 || tickVal <= 0 || pipSz <= 0) return 0;
   double pipVal = tickVal * pipSz / tickSize;
   if (pipVal <= 0) return 0;
   double lot   = riskMoney / (slPips * pipVal);
   double lstep = MarketInfo(Symbol(), MODE_LOTSTEP);
   lot = MathFloor(lot / lstep) * lstep;
   return MathMax(MarketInfo(Symbol(), MODE_MINLOT),
                  MathMin(MarketInfo(Symbol(), MODE_MAXLOT), lot));
}

//+------------------------------------------------------------------+
//| GetPipSize — identyczna z głównym EA (zsynchronizowana)         |
//+------------------------------------------------------------------+
double GetPipSize(string sym) {
   double pt = MarketInfo(sym, MODE_POINT);
   int    dg = (int)MarketInfo(sym, MODE_DIGITS);
   string u  = sym; StringToUpper(u);

   if (StringFind(u,"XAU")>=0||StringFind(u,"GOLD")>=0||
       StringFind(u,"XPT")>=0||StringFind(u,"PLAT")>=0||
       StringFind(u,"XPD")>=0||StringFind(u,"PALL")>=0) return 0.1;

   if (StringFind(u,"XAG")>=0||StringFind(u,"SILVER")>=0)
      return (dg<=2) ? 0.01 : pt*10.0;

   if (StringFind(u,"BTC")>=0||StringFind(u,"ETH")>=0||
       StringFind(u,"LTC")>=0||StringFind(u,"BCH")>=0||
       StringFind(u,"DOT")>=0||StringFind(u,"ADA")>=0||
       StringFind(u,"SOL")>=0||StringFind(u,"LINK")>=0) return 1.0;
   if (StringFind(u,"XRP")>=0||StringFind(u,"DOGE")>=0) return 0.0001;

   if (StringFind(u,"WTI")>=0||StringFind(u,"BRENT")>=0||
       StringFind(u,"USOIL")>=0||StringFind(u,"UKOIL")>=0||
       StringFind(u,"OIL")>=0||StringFind(u,"CRUDE")>=0||
       StringFind(u,"NGAS")>=0||StringFind(u,"NATGAS")>=0||
       StringFind(u,"GAS")>=0) return pt*10.0;

   if (StringFind(u,"AUS200")>=0||StringFind(u,"UK100")>=0||
       StringFind(u,"US30")>=0||StringFind(u,"US500")>=0||
       StringFind(u,"NAS100")>=0||StringFind(u,"GER")>=0||
       StringFind(u,"FRA40")>=0||StringFind(u,"JPN225")>=0||
       StringFind(u,"HKG50")>=0||StringFind(u,"ESP35")>=0||
       StringFind(u,"SWI20")>=0||StringFind(u,"NED25")>=0||
       StringFind(u,"US2000")>=0||StringFind(u,"CHINA")>=0) return 1.0;

   if (dg%2==1) return pt*10.0;
   return pt;
}

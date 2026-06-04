//+------------------------------------------------------------------+
//|  TraderLogJournal EA v2.0                                        |
//|  Kalkulator pozycji + BUY/SELL panel + sync historii             |
//+------------------------------------------------------------------+
#property copyright   "TraderLogJournal"
#property link        "https://traderlogjournal.com"
#property version     "2.00"
#property description "Integracja MT4 z dziennikiem TraderLogJournal"
#property strict

//--- Parametry
input string   UserId              = "";       // [WYMAGANE] Skopiuj z Ustawienia → Integracja MT4
input string   ApiUrl              = "https://ygrkcynyduuflzvbkkvo.supabase.co";
input string   AnonKey             = "sb_publishable_-aRakEBT-U17VQJHksmK1Q_TbL1cToK";
input bool     SendOnOpen          = true;     // Wysyłaj sygnał przy otwarciu
input bool     SendOnClose         = true;     // Wysyłaj sygnał przy zamknięciu
input bool     SendOnModify        = true;     // Wysyłaj sygnał przy modyfikacji SL/TP
input bool     SendExistingOnStart = true;     // Wyślij otwarte pozycje przy starcie
input int      CheckEvery          = 2;        // Sprawdzaj co X sekund
input int      PanelX              = 20;       // Pozycja panelu X
input int      PanelY              = 30;       // Pozycja panelu Y
input int      MagicNumber         = 202601;   // Magic zleceń z panelu (0 = śledź wszystkie)
input int      Sync_History_Days   = 0;        // 0 = wyłącz; np. 30 = sync ostatnich 30 dni
input double   DefaultRiskPct      = 1.0;      // Domyślne ryzyko % (kalkulator)
input double   DefaultSLPips       = 20.0;     // Domyślny SL w pipsach (kalkulator)

//--- Nazwy obiektów panelu
#define PANEL_NAME    "TLJ_Panel"
#define BTN_STOP      "TLJ_BtnStop"
#define BTN_PAUSE     "TLJ_BtnPause"
#define BTN_BUY       "TLJ_BtnBuy"
#define BTN_SELL      "TLJ_BtnSell"
#define BTN_CLOSE_ALL "TLJ_BtnCloseAll"
#define BTN_CLOSE_BUY "TLJ_BtnCloseBuy"
#define BTN_CLOSE_SEL "TLJ_BtnCloseSel"
#define BTN_CALC      "TLJ_BtnCalc"
#define EDIT_RISK     "TLJ_EditRisk"
#define EDIT_SL       "TLJ_EditSL"
#define LBL_STATUS    "TLJ_Status"
#define LBL_COUNT     "TLJ_Count"
#define LBL_TITLE     "TLJ_Title"
#define LBL_ACCOUNT   "TLJ_Account"
#define LBL_EQUITY    "TLJ_Equity"
#define LBL_LOT       "TLJ_LblLot"

//--- Stan
struct TradeState {
   long   ticket;
   string symbol;
   int    type;
   double lots;
   double open;
   double sl;
   double tp;
};

TradeState prevTrades[];
long       mt4AccountNumber = 0;
bool       _paused          = false;
int        _sentCount       = 0;

//+------------------------------------------------------------------+
int OnInit() {
   if (UserId == "") {
      Alert("TraderLogJournal: Wklej swój User ID w parametrach EA!\n"
            "Ustawienia → Integracja z MT4 → Kopiuj User ID");
      return INIT_FAILED;
   }
   mt4AccountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
   CreatePanel();

   if (SendExistingOnStart && SendOnOpen) {
      int total = OrdersTotal();
      for (int i = 0; i < total; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
         if (OrderType() > 1) continue;
         SendSignal("OPEN", OrderTicket(), OrderSymbol(),
                    OrderType(), OrderLots(), OrderOpenPrice(),
                    OrderStopLoss(), OrderTakeProfit(), 0, 0, 0, 0,
                    OrderOpenTime(), 0);
         _sentCount++;
      }
   }

   if (Sync_History_Days > 0) SyncHistory(Sync_History_Days);

   SnapshotTrades();
   EventSetTimer(CheckEvery);
   UpdatePanel();
   CalculateAndShowLot();
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   EventKillTimer();
   DeletePanel();
}

//+------------------------------------------------------------------+
void OnTimer() {
   if (!_paused) CheckTradeChanges();
   UpdatePanel();
}

//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam,
                  const double& dparam, const string& sparam) {

   if (id == CHARTEVENT_OBJECT_CLICK) {
      if (sparam == BTN_BUY) {
         OpenOrder(OP_BUY);
         ObjectSetInteger(0, BTN_BUY, OBJPROP_STATE, false);
      }
      else if (sparam == BTN_SELL) {
         OpenOrder(OP_SELL);
         ObjectSetInteger(0, BTN_SELL, OBJPROP_STATE, false);
      }
      else if (sparam == BTN_CLOSE_ALL) {
         if (MessageBox("Zamknąć WSZYSTKIE zlecenia?",
                        "TraderLogJournal", MB_YESNO|MB_ICONQUESTION) == IDYES)
            CloseOrders(-1);
         ObjectSetInteger(0, BTN_CLOSE_ALL, OBJPROP_STATE, false);
      }
      else if (sparam == BTN_CLOSE_BUY) {
         CloseOrders(OP_BUY);
         ObjectSetInteger(0, BTN_CLOSE_BUY, OBJPROP_STATE, false);
      }
      else if (sparam == BTN_CLOSE_SEL) {
         CloseOrders(OP_SELL);
         ObjectSetInteger(0, BTN_CLOSE_SEL, OBJPROP_STATE, false);
      }
      else if (sparam == BTN_CALC) {
         CalculateAndShowLot();
         ObjectSetInteger(0, BTN_CALC, OBJPROP_STATE, false);
      }
      else if (sparam == BTN_STOP) {
         if (MessageBox("Zatrzymać TraderLogJournal EA?",
                        "TraderLogJournal", MB_YESNO|MB_ICONQUESTION) == IDYES) {
            Print("TLJ EA: zatrzymany przez użytkownika");
            ExpertRemove();
         }
         ObjectSetInteger(0, BTN_STOP, OBJPROP_STATE, false);
      }
      else if (sparam == BTN_PAUSE) {
         _paused = !_paused;
         ObjectSetInteger(0, BTN_PAUSE, OBJPROP_STATE, false);
         ObjectSetString(0, BTN_PAUSE, OBJPROP_TEXT, _paused ? "▶ Wznów" : "⏸ Pauza");
         ObjectSetInteger(0, BTN_PAUSE, OBJPROP_BGCOLOR, _paused ? clrOrangeRed : C'30,45,61');
         UpdatePanel();
      }
      ChartRedraw();
   }

   // Auto-przelicz lot po edycji pola
   if (id == CHARTEVENT_OBJECT_ENDEDIT) {
      if (sparam == EDIT_RISK || sparam == EDIT_SL)
         CalculateAndShowLot();
   }
}

//+------------------------------------------------------------------+
// PANEL
//+------------------------------------------------------------------+
void CreatePanel() {
   int w = 222, h = 308;
   int x = PanelX, y = PanelY;

   // Tło
   ObjectCreate(0, PANEL_NAME, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_XDISTANCE,   x);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_YDISTANCE,   y);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_XSIZE,       w);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_YSIZE,       h);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_BGCOLOR,     C'13,17,23');
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_COLOR,       C'30,45,61');
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_WIDTH,       1);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_CORNER,      CORNER_LEFT_UPPER);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_SELECTABLE,  false);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_ZORDER,      0);

   // Logo
   CreateLabel(LBL_TITLE,       x+10,  y+9,  "TraderLog",          C'0,212,161',   10, true);
   CreateLabel("TLJ_Sub",       x+83,  y+9,  "Journal",            C'100,120,135', 10, false);
   CreateLabel("TLJ_Ver",       x+10,  y+26, "EA v2.0",            C'45,65,80',     8, false);
   CreateLabel(LBL_STATUS,      x+108, y+26, "● Aktywny",          C'0,212,161',    8, false);

   CreateSep("TLJ_L1", x+8, y+40, w-16);

   // Dane konta
   CreateLabel("TLJ_K1",    x+10,  y+50,  "KONTO",      C'74,96,117',   8, false);
   CreateLabel(LBL_ACCOUNT, x+122, y+50,  "#---",        C'201,209,217', 8, false);
   CreateLabel("TLJ_K2",    x+10,  y+64,  "EQUITY",     C'74,96,117',   8, false);
   CreateLabel(LBL_EQUITY,  x+122, y+64,  "$0.00",       C'201,209,217', 8, false);
   CreateLabel("TLJ_K3",    x+10,  y+78,  "P&L OTWR.",  C'74,96,117',   8, false);
   CreateLabel("TLJ_PnL",   x+122, y+78,  "—",           C'201,209,217', 8, false);
   CreateLabel("TLJ_K4",    x+10,  y+92,  "OTWARTE",    C'74,96,117',   8, false);
   CreateLabel(LBL_COUNT,   x+122, y+92,  "0 pozycji",   C'201,209,217', 8, false);
   CreateLabel("TLJ_K5",    x+10,  y+106, "WYSŁANO",    C'74,96,117',   8, false);
   CreateLabel("TLJ_Sent",  x+122, y+106, "0 syg.",      C'201,209,217', 8, false);

   CreateSep("TLJ_L2", x+8, y+118, w-16);

   // Kalkulator
   CreateLabel("TLJ_CalcHdr", x+10, y+126, "KALKULATOR POZYCJI", C'74,96,117', 7, false);

   CreateLabel("TLJ_RLbl", x+10, y+142, "Ryzyko %",  C'150,170,185', 8, false);
   CreateEdit(EDIT_RISK, x+100, y+138, 50, 16, DoubleToString(DefaultRiskPct, 1));

   CreateLabel("TLJ_SLbl", x+10, y+162, "SL (pips)", C'150,170,185', 8, false);
   CreateEdit(EDIT_SL, x+100, y+158, 50, 16, DoubleToString(DefaultSLPips, 1));

   CreateLabel("TLJ_LotLbl", x+10, y+182, "Lot:",    C'150,170,185', 8, false);
   CreateLabel(LBL_LOT,       x+40, y+182, "—",       C'0,212,161',   9, true);

   // Przycisk Oblicz
   CreateButton(BTN_CALC, x+158, y+177, 56, 18, "Oblicz",
                C'25,45,65', C'100,160,220', C'45,80,120', 8);

   CreateSep("TLJ_L3", x+8, y+198, w-16);

   // BUY / SELL
   CreateButton(BTN_BUY,  x+8,   y+205, 100, 26, "BUY",
                C'0,130,80',  clrWhite, C'0,180,110', 10);
   CreateButton(BTN_SELL, x+114, y+205, 100, 26, "SELL",
                C'160,30,40', clrWhite, C'200,50,60', 10);

   // Close buttons
   CreateButton(BTN_CLOSE_ALL, x+8,   y+235, 66, 18, "Close ALL",
                C'50,20,20', C'255,100,100', C'100,40,40', 7);
   CreateButton(BTN_CLOSE_BUY, x+78,  y+235, 66, 18, "Close BUY",
                C'20,50,30', C'80,200,120',  C'40,100,60', 7);
   CreateButton(BTN_CLOSE_SEL, x+148, y+235, 66, 18, "Close SELL",
                C'50,20,20', C'255,80,80',   C'100,40,40', 7);

   CreateSep("TLJ_L4", x+8, y+259, w-16);

   // Pauza / Stop
   CreateButton(BTN_PAUSE, x+8,   y+265, 100, 22, "⏸  Pauza",
                C'30,45,61', C'122,139,153', C'45,63,80', 8);
   CreateButton(BTN_STOP,  x+114, y+265, 100, 22, "⏹  Stop EA",
                C'61,26,26', C'255,71,87',   C'93,40,40', 8);

   CreateLabel("TLJ_Link", x+10, y+293, "traderlogjournal.com", C'45,63,80', 7, false);

   ChartRedraw();
}

//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text,
                 color clr, int fs=8, bool bold=false) {
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
   ObjectSetString (0, name, OBJPROP_TEXT,       text);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   fs);
   ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   if (bold) ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
}

void CreateSep(string name, int x, int y, int w) {
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,      w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,      1);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,    C'30,45,61');
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void CreateEdit(string name, int x, int y, int w, int h, string val) {
   ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,   x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,   y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,       w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,       h);
   ObjectSetString (0, name, OBJPROP_TEXT,        val);
   ObjectSetInteger(0, name, OBJPROP_COLOR,       C'201,209,217');
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,     C'25,35,48');
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR,C'45,63,80');
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,    8);
   ObjectSetInteger(0, name, OBJPROP_CORNER,      CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,  false);
   ObjectSetInteger(0, name, OBJPROP_ALIGN,       ALIGN_CENTER);
}

void CreateButton(string name, int x, int y, int w, int h, string text,
                  color bg, color fg, color border, int fs) {
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,   x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,   y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,       w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,       h);
   ObjectSetString (0, name, OBJPROP_TEXT,        text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,     bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR,       fg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR,border);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,    fs);
   ObjectSetInteger(0, name, OBJPROP_CORNER,      CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,  false);
}

//+------------------------------------------------------------------+
void UpdatePanel() {
   double profit = AccountInfoDouble(ACCOUNT_PROFIT);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   int    open   = OrdersTotal();

   ObjectSetString (0, LBL_EQUITY,  OBJPROP_TEXT,  "$" + DoubleToString(equity, 2));
   ObjectSetString (0, LBL_ACCOUNT, OBJPROP_TEXT,  "#" + IntegerToString(mt4AccountNumber));

   string pnlStr = (profit >= 0 ? "+" : "") + "$" + DoubleToString(profit, 2);
   ObjectSetString (0, "TLJ_PnL", OBJPROP_TEXT,  pnlStr);
   ObjectSetInteger(0, "TLJ_PnL", OBJPROP_COLOR,
                    profit > 0 ? C'0,212,161' : profit < 0 ? C'255,71,87' : C'201,209,217');

   ObjectSetString(0, LBL_COUNT, OBJPROP_TEXT,
                   IntegerToString(open) + (open==1?" pozycja":open<5?" pozycje":" pozycji"));
   ObjectSetString(0, "TLJ_Sent",  OBJPROP_TEXT,  IntegerToString(_sentCount) + " syg.");

   string st = _paused ? "⏸  Wstrzymany" : "●  Aktywny";
   ObjectSetString (0, LBL_STATUS, OBJPROP_TEXT,  st);
   ObjectSetInteger(0, LBL_STATUS, OBJPROP_COLOR, _paused ? C'255,127,0' : C'0,212,161');

   ChartRedraw();
}

//+------------------------------------------------------------------+
void DeletePanel() {
   string objs[] = {
      PANEL_NAME, BTN_STOP, BTN_PAUSE, BTN_BUY, BTN_SELL,
      BTN_CLOSE_ALL, BTN_CLOSE_BUY, BTN_CLOSE_SEL, BTN_CALC,
      EDIT_RISK, EDIT_SL, LBL_LOT,
      LBL_STATUS, LBL_COUNT, LBL_TITLE, LBL_ACCOUNT, LBL_EQUITY,
      "TLJ_Sub", "TLJ_Ver", "TLJ_L1", "TLJ_L2", "TLJ_L3", "TLJ_L4",
      "TLJ_K1", "TLJ_K2", "TLJ_K3", "TLJ_K4", "TLJ_K5",
      "TLJ_PnL", "TLJ_Sent", "TLJ_Link",
      "TLJ_CalcHdr", "TLJ_RLbl", "TLJ_SLbl", "TLJ_LotLbl"
   };
   for (int i = 0; i < ArraySize(objs); i++) ObjectDelete(0, objs[i]);
   ChartRedraw();
}

//+------------------------------------------------------------------+
// KALKULATOR LOTA
//+------------------------------------------------------------------+
double CalcLot(double riskPct, double slPips) {
   if (riskPct <= 0 || slPips <= 0) return 0;
   double balance   = AccountBalance();
   double riskMoney = balance * riskPct / 100.0;

   double tickVal  = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   double point    = MarketInfo(Symbol(), MODE_POINT);
   int    digits   = (int)MarketInfo(Symbol(), MODE_DIGITS);
   // 5/3-cyfrowi brokerzy: 1 pip = 10 punktów
   double pipSz    = (digits == 5 || digits == 3) ? point * 10.0 : point;
   double pipVal   = tickVal * pipSz / tickSize;
   if (pipVal <= 0) return 0;

   double lot  = riskMoney / (slPips * pipVal);
   double step = MarketInfo(Symbol(), MODE_LOTSTEP);
   if (step <= 0) step = 0.01;
   lot = MathFloor(lot / step) * step;
   return MathMax(MarketInfo(Symbol(), MODE_MINLOT),
                  MathMin(MarketInfo(Symbol(), MODE_MAXLOT), lot));
}

void CalculateAndShowLot() {
   double riskPct = StringToDouble(ObjectGetString(0, EDIT_RISK, OBJPROP_TEXT));
   double slPips  = StringToDouble(ObjectGetString(0, EDIT_SL,   OBJPROP_TEXT));
   double lot     = CalcLot(riskPct, slPips);
   ObjectSetString(0, LBL_LOT, OBJPROP_TEXT, lot > 0 ? DoubleToString(lot, 2) : "—");
   ChartRedraw();
}

//+------------------------------------------------------------------+
// OTWIERANIE ZLECEŃ
//+------------------------------------------------------------------+
void OpenOrder(int orderType) {
   double riskPct = StringToDouble(ObjectGetString(0, EDIT_RISK, OBJPROP_TEXT));
   double slPips  = StringToDouble(ObjectGetString(0, EDIT_SL,   OBJPROP_TEXT));
   if (riskPct <= 0 || slPips <= 0) {
      Alert("TLJ: Wpisz poprawne Ryzyko % i SL pips!");
      return;
   }
   double lot = CalcLot(riskPct, slPips);
   if (lot <= 0) { Alert("TLJ: Błąd kalkulacji lota!"); return; }

   double point  = MarketInfo(Symbol(), MODE_POINT);
   int    digits = (int)MarketInfo(Symbol(), MODE_DIGITS);
   double pipSz  = (digits == 5 || digits == 3) ? point * 10.0 : point;
   double price, sl;

   if (orderType == OP_BUY) {
      price = NormalizeDouble(Ask, digits);
      sl    = NormalizeDouble(Ask - slPips * pipSz, digits);
   } else {
      price = NormalizeDouble(Bid, digits);
      sl    = NormalizeDouble(Bid + slPips * pipSz, digits);
   }

   int ticket = OrderSend(Symbol(), orderType, lot, price, 3, sl, 0,
                          "TLJ Panel", MagicNumber, 0,
                          orderType == OP_BUY ? clrLime : clrRed);
   if (ticket < 0) {
      int err = GetLastError();
      Print("TLJ: Błąd OrderSend err=", err);
      Alert("TLJ: Błąd otwarcia zlecenia (kod: ", err, ")");
   } else {
      Print("TLJ: Otwarto ", (orderType==OP_BUY?"BUY":"SELL"),
            " lot=", lot, " sl=", sl, " ticket=", ticket);
   }
}

//+------------------------------------------------------------------+
// ZAMYKANIE ZLECEŃ
//+------------------------------------------------------------------+
void CloseOrders(int filterType) {
   // filterType: -1=wszystkie, 0=OP_BUY, 1=OP_SELL
   for (int i = OrdersTotal()-1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderType() > 1) continue;
      if (filterType >= 0 && OrderType() != filterType) continue;

      double closePrice = (OrderType() == OP_BUY) ? Bid : Ask;
      int    digits     = (int)MarketInfo(OrderSymbol(), MODE_DIGITS);
      if (!OrderClose(OrderTicket(), OrderLots(),
                      NormalizeDouble(closePrice, digits), 3, clrYellow))
         Print("TLJ: Błąd zamknięcia ticket=", OrderTicket(), " err=", GetLastError());
   }
}

//+------------------------------------------------------------------+
// ŚLEDZENIE ZLECEŃ
//+------------------------------------------------------------------+
void SnapshotTrades() {
   int total = OrdersTotal();
   ArrayResize(prevTrades, total);
   int idx = 0;
   for (int i = 0; i < total; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderType() > 1) continue;
      prevTrades[idx].ticket = OrderTicket();
      prevTrades[idx].symbol = OrderSymbol();
      prevTrades[idx].type   = OrderType();
      prevTrades[idx].lots   = OrderLots();
      prevTrades[idx].open   = OrderOpenPrice();
      prevTrades[idx].sl     = OrderStopLoss();
      prevTrades[idx].tp     = OrderTakeProfit();
      idx++;
   }
   ArrayResize(prevTrades, idx);
}

void CheckTradeChanges() {
   int total = OrdersTotal();

   for (int i = 0; i < total; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderType() > 1) continue;

      bool isNew = true;
      for (int j = 0; j < ArraySize(prevTrades); j++) {
         if (prevTrades[j].ticket != OrderTicket()) continue;
         isNew = false;
         if (SendOnModify &&
             (MathAbs(prevTrades[j].sl - OrderStopLoss()) > 0.00001 ||
              MathAbs(prevTrades[j].tp - OrderTakeProfit()) > 0.00001)) {
            SendSignal("MODIFY", OrderTicket(), OrderSymbol(),
                       OrderType(), OrderLots(), OrderOpenPrice(),
                       OrderStopLoss(), OrderTakeProfit(), 0, 0, 0, 0,
                       OrderOpenTime(), 0);
            _sentCount++;
         }
         break;
      }
      if (isNew && SendOnOpen) {
         SendSignal("OPEN", OrderTicket(), OrderSymbol(),
                    OrderType(), OrderLots(), OrderOpenPrice(),
                    OrderStopLoss(), OrderTakeProfit(), 0, 0, 0, 0,
                    OrderOpenTime(), 0);
         _sentCount++;
      }
   }

   if (SendOnClose) {
      for (int j = 0; j < ArraySize(prevTrades); j++) {
         if (prevTrades[j].ticket == 0) continue;
         bool stillOpen = false;
         for (int i = 0; i < total; i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
            if (prevTrades[j].ticket == OrderTicket()) { stillOpen = true; break; }
         }
         if (!stillOpen &&
             OrderSelect((int)prevTrades[j].ticket, SELECT_BY_TICKET, MODE_HISTORY)) {
            SendSignal("CLOSE", OrderTicket(), OrderSymbol(),
                       OrderType(), OrderLots(), OrderOpenPrice(),
                       OrderStopLoss(), OrderTakeProfit(),
                       OrderClosePrice(), OrderProfit(),
                       OrderCommission(), OrderSwap(),
                       OrderOpenTime(), OrderCloseTime());
            _sentCount++;
         }
      }
   }

   SnapshotTrades();
}

//+------------------------------------------------------------------+
// SYNCHRONIZACJA HISTORII
//+------------------------------------------------------------------+
void SyncHistory(int days) {
   datetime fromTime = TimeCurrent() - (datetime)((long)days * 86400);
   int total = OrdersHistoryTotal();
   int synced = 0;
   Print("TLJ Historia: skanuję ", total, " rekordów, ostatnie ", days, " dni...");

   for (int i = 0; i < total; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if (OrderType() > 1) continue;
      if (OrderCloseTime() < fromTime) continue;
      if (OrderSymbol() == "") continue;

      SendSignalHistory(OrderTicket(), OrderSymbol(),
                        OrderType(), OrderLots(), OrderOpenPrice(),
                        OrderStopLoss(), OrderTakeProfit(),
                        OrderClosePrice(), OrderProfit(),
                        OrderCommission(), OrderSwap(),
                        OrderOpenTime(), OrderCloseTime());
      synced++;
      _sentCount++;
      Sleep(250);
   }
   Print("TLJ Historia: zsync. ", synced, " transakcji z ostatnich ", days, " dni");
}

//+------------------------------------------------------------------+
// HTTP / JSON
//+------------------------------------------------------------------+
void SendSignal(string event, long ticket, string symbol,
                int orderType, double lots, double entry,
                double sl, double tp, double closePrice, double profit,
                double commission, double swap,
                datetime openTime, datetime closeTime) {
   string dir  = (orderType == OP_BUY) ? "BUY" : "SELL";
   string json = BuildJson(event, ticket, symbol, dir, GetTF(),
                           lots, entry, sl, tp, closePrice, profit,
                           commission, swap,
                           openTime, closeTime, false);
   HttpPost(ApiUrl + "/rest/v1/mt4_signals", BuildHeaders(false), json);
   Print("TLJ [", event, "] ", symbol, " ", dir, " lot=", lots,
         " profit=", profit, " comm=", commission, " swap=", swap,
         " ticket=#", ticket);
}

void SendSignalHistory(long ticket, string symbol,
                       int orderType, double lots, double entry,
                       double sl, double tp, double closePrice, double profit,
                       double commission, double swap,
                       datetime openTime, datetime closeTime) {
   string dir  = (orderType == OP_BUY) ? "BUY" : "SELL";
   string json = BuildJson("CLOSE", ticket, symbol, dir, "H1",
                           lots, entry, sl, tp, closePrice, profit,
                           commission, swap,
                           openTime, closeTime, true);
   HttpPost(ApiUrl + "/rest/v1/mt4_signals?on_conflict=ticket",
            BuildHeaders(true), json);
}

string BuildJson(string event, long ticket, string symbol,
                 string dir, string tf,
                 double lots, double entry, double sl, double tp,
                 double closePrice, double profit,
                 double commission, double swap,
                 datetime openTime, datetime closeTime, bool isHistory) {
   string j = "{";
   j += "\"user_id\":\""   + UserId                            + "\",";
   j += "\"mt4_account\":" + IntegerToString(mt4AccountNumber) + ",";
   j += "\"symbol\":\""    + symbol                            + "\",";
   j += "\"direction\":\""  + dir                              + "\",";
   j += "\"tf\":\""        + tf                                + "\",";
   j += "\"entry\":"       + DoubleToString(entry, 5)          + ",";
   j += "\"sl\":"          + DoubleToString(sl, 5)             + ",";
   j += "\"tp\":"          + DoubleToString(tp, 5)             + ",";
   j += "\"size\":"        + DoubleToString(lots, 2)           + ",";
   j += "\"ticket\":"      + IntegerToString(ticket)           + ",";
   j += "\"event\":\""     + event                             + "\",";
   j += "\"close_price\":" + DoubleToString(closePrice, 5)     + ",";
   j += "\"profit\":"      + DoubleToString(profit, 2)         + ",";
   j += "\"commission\":"  + DoubleToString(commission, 2)     + ",";
   j += "\"swap\":"        + DoubleToString(swap, 2)           + ",";
   j += "\"open_time\":\"" + TimeToString(openTime, TIME_DATE|TIME_SECONDS) + "\",";
   if (closeTime > 0)
      j += "\"close_time\":\"" + TimeToString(closeTime, TIME_DATE|TIME_SECONDS) + "\",";
   if (isHistory) j += "\"is_history\":true,";
   j += "\"processed\":false}";
   return j;
}

string BuildHeaders(bool mergeOnConflict) {
   string h  = "Content-Type: application/json\r\n";
   h += "apikey: "             + AnonKey + "\r\n";
   h += "Authorization: Bearer " + AnonKey + "\r\n";
   h += mergeOnConflict
        ? "Prefer: return=minimal,resolution=merge-duplicates\r\n"
        : "Prefer: return=minimal\r\n";
   return h;
}

void HttpPost(string url, string headers, string json) {
   char   post[], result[];
   string resultHeaders;
   StringToCharArray(json, post, 0, StringLen(json));
   int res = WebRequest("POST", url, headers, 5000, post, result, resultHeaders);
   if (res != 200 && res != 201 && res != 204)
      Print("TLJ Błąd HTTP ", res, " | ", CharArrayToString(result));
}

string GetTF() {
   switch(Period()) {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN";
      default:         return "H1";
   }
}

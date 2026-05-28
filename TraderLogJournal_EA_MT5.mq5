//+------------------------------------------------------------------+
//|  TraderLogJournal EA MT5 v2.0                                    |
//|  Kalkulator pozycji + BUY/SELL panel + sync historii             |
//+------------------------------------------------------------------+
#property copyright   "TraderLogJournal"
#property link        "https://traderlogjournal.com"
#property version     "2.00"
#property description "Integracja MT5 z dziennikiem TraderLogJournal"

//--- Parametry
input string   UserId              = "";       // [WYMAGANE] Skopiuj z Ustawienia → Integracja MT5
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
struct PositionState {
   ulong  ticket;
   string symbol;
   int    type;
   double lots;
   double open;
   double sl;
   double tp;
};

PositionState prevPositions[];
long          mt5AccountNumber = 0;
bool          _paused          = false;
int           _sentCount       = 0;

//+------------------------------------------------------------------+
int OnInit() {
   if (UserId == "") {
      Alert("TraderLogJournal: Wklej swój User ID w parametrach EA!\n"
            "Ustawienia → Integracja z MT5 → Kopiuj User ID");
      return INIT_FAILED;
   }
   mt5AccountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
   CreatePanel();

   if (SendExistingOnStart && SendOnOpen) {
      int total = PositionsTotal();
      for (int i = 0; i < total; i++) {
         ulong ticket = PositionGetTicket(i);
         if (ticket == 0) continue;
         SendSignal("OPEN", ticket,
                    PositionGetString(POSITION_SYMBOL),
                    (int)PositionGetInteger(POSITION_TYPE),
                    PositionGetDouble(POSITION_VOLUME),
                    PositionGetDouble(POSITION_PRICE_OPEN),
                    PositionGetDouble(POSITION_SL),
                    PositionGetDouble(POSITION_TP),
                    0.0, 0.0,
                    (datetime)PositionGetInteger(POSITION_TIME), 0);
         _sentCount++;
      }
   }

   if (Sync_History_Days > 0) SyncHistory(Sync_History_Days);

   SnapshotPositions();
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
   if (!_paused) CheckPositionChanges();
   UpdatePanel();
}

//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam,
                  const double& dparam, const string& sparam) {

   if (id == CHARTEVENT_OBJECT_CLICK) {
      if (sparam == BTN_BUY) {
         OpenOrder(ORDER_TYPE_BUY);
         ObjectSetInteger(0, BTN_BUY, OBJPROP_STATE, false);
      }
      else if (sparam == BTN_SELL) {
         OpenOrder(ORDER_TYPE_SELL);
         ObjectSetInteger(0, BTN_SELL, OBJPROP_STATE, false);
      }
      else if (sparam == BTN_CLOSE_ALL) {
         if (MessageBox("Zamknąć WSZYSTKIE pozycje?",
                        "TraderLogJournal", MB_YESNO|MB_ICONQUESTION) == IDYES)
            ClosePositions(-1);
         ObjectSetInteger(0, BTN_CLOSE_ALL, OBJPROP_STATE, false);
      }
      else if (sparam == BTN_CLOSE_BUY) {
         ClosePositions(POSITION_TYPE_BUY);
         ObjectSetInteger(0, BTN_CLOSE_BUY, OBJPROP_STATE, false);
      }
      else if (sparam == BTN_CLOSE_SEL) {
         ClosePositions(POSITION_TYPE_SELL);
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
         ObjectSetInteger(0, BTN_PAUSE, OBJPROP_BGCOLOR, _paused ? (color)C'204,81,0' : (color)C'30,45,61');
         UpdatePanel();
      }
      ChartRedraw();
   }

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
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_BGCOLOR,     (color)C'13,17,23');
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_COLOR,       (color)C'30,45,61');
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_WIDTH,       1);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_CORNER,      CORNER_LEFT_UPPER);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_SELECTABLE,  false);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_ZORDER,      0);

   // Logo
   CreateLabel(LBL_TITLE,   x+10,  y+9,  "TraderLog",    (color)C'0,212,161',   10, true);
   CreateLabel("TLJ_Sub",   x+83,  y+9,  "Journal",      (color)C'100,120,135', 10, false);
   CreateLabel("TLJ_Ver",   x+10,  y+26, "EA MT5 v2.0",  (color)C'45,65,80',    8, false);
   CreateLabel(LBL_STATUS,  x+108, y+26, "● Aktywny",    (color)C'0,212,161',   8, false);

   CreateSep("TLJ_L1", x+8, y+40, w-16);

   // Dane konta
   CreateLabel("TLJ_K1",   x+10,  y+50,  "KONTO",      (color)C'74,96,117',   8, false);
   CreateLabel(LBL_ACCOUNT,x+122, y+50,  "#---",        (color)C'201,209,217', 8, false);
   CreateLabel("TLJ_K2",   x+10,  y+64,  "EQUITY",     (color)C'74,96,117',   8, false);
   CreateLabel(LBL_EQUITY, x+122, y+64,  "$0.00",       (color)C'201,209,217', 8, false);
   CreateLabel("TLJ_K3",   x+10,  y+78,  "P&L OTWR.",  (color)C'74,96,117',   8, false);
   CreateLabel("TLJ_PnL",  x+122, y+78,  "—",           (color)C'201,209,217', 8, false);
   CreateLabel("TLJ_K4",   x+10,  y+92,  "OTWARTE",    (color)C'74,96,117',   8, false);
   CreateLabel(LBL_COUNT,  x+122, y+92,  "0 pozycji",   (color)C'201,209,217', 8, false);
   CreateLabel("TLJ_K5",   x+10,  y+106, "WYSŁANO",    (color)C'74,96,117',   8, false);
   CreateLabel("TLJ_Sent", x+122, y+106, "0 syg.",      (color)C'201,209,217', 8, false);

   CreateSep("TLJ_L2", x+8, y+118, w-16);

   // Kalkulator
   CreateLabel("TLJ_CalcHdr", x+10, y+126, "KALKULATOR POZYCJI", (color)C'74,96,117', 7, false);
   CreateLabel("TLJ_RLbl",    x+10, y+142, "Ryzyko %",           (color)C'150,170,185', 8, false);
   CreateEdit(EDIT_RISK, x+100, y+138, 50, 16, DoubleToString(DefaultRiskPct, 1));
   CreateLabel("TLJ_SLbl",    x+10, y+162, "SL (pips)",          (color)C'150,170,185', 8, false);
   CreateEdit(EDIT_SL,   x+100, y+158, 50, 16, DoubleToString(DefaultSLPips,  1));
   CreateLabel("TLJ_LotLbl",  x+10, y+182, "Lot:",               (color)C'150,170,185', 8, false);
   CreateLabel(LBL_LOT,        x+40, y+182, "—",                  (color)C'0,212,161',   9, true);
   CreateButton(BTN_CALC, x+158, y+177, 56, 18, "Oblicz",
                (color)C'25,45,65', (color)C'100,160,220', (color)C'45,80,120', 8);

   CreateSep("TLJ_L3", x+8, y+198, w-16);

   // BUY / SELL
   CreateButton(BTN_BUY,  x+8,   y+205, 100, 26, "BUY",
                (color)C'0,130,80',  clrWhite, (color)C'0,180,110', 10);
   CreateButton(BTN_SELL, x+114, y+205, 100, 26, "SELL",
                (color)C'160,30,40', clrWhite, (color)C'200,50,60', 10);

   // Close buttons
   CreateButton(BTN_CLOSE_ALL, x+8,   y+235, 66, 18, "Close ALL",
                (color)C'50,20,20', (color)C'255,100,100', (color)C'100,40,40', 7);
   CreateButton(BTN_CLOSE_BUY, x+78,  y+235, 66, 18, "Close BUY",
                (color)C'20,50,30', (color)C'80,200,120',  (color)C'40,100,60', 7);
   CreateButton(BTN_CLOSE_SEL, x+148, y+235, 66, 18, "Close SELL",
                (color)C'50,20,20', (color)C'255,80,80',   (color)C'100,40,40', 7);

   CreateSep("TLJ_L4", x+8, y+259, w-16);

   // Pauza / Stop
   CreateButton(BTN_PAUSE, x+8,   y+265, 100, 22, "⏸  Pauza",
                (color)C'30,45,61', (color)C'122,139,153', (color)C'45,63,80', 8);
   CreateButton(BTN_STOP,  x+114, y+265, 100, 22, "⏹  Stop EA",
                (color)C'61,26,26', (color)C'255,71,87',   (color)C'93,40,40', 8);

   CreateLabel("TLJ_Link", x+10, y+293, "traderlogjournal.com", (color)C'45,63,80', 7, false);

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
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,    (color)C'30,45,61');
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void CreateEdit(string name, int x, int y, int w, int h, string val) {
   ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,    x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,    y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,        w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,        h);
   ObjectSetString (0, name, OBJPROP_TEXT,         val);
   ObjectSetInteger(0, name, OBJPROP_COLOR,        (color)C'201,209,217');
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,      (color)C'25,35,48');
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, (color)C'45,63,80');
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,     8);
   ObjectSetInteger(0, name, OBJPROP_CORNER,       CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,   false);
   ObjectSetInteger(0, name, OBJPROP_ALIGN,        ALIGN_CENTER);
}

void CreateButton(string name, int x, int y, int w, int h, string text,
                  color bg, color fg, color border, int fs) {
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,    x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,    y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,        w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,        h);
   ObjectSetString (0, name, OBJPROP_TEXT,         text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,      bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR,        fg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, border);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,     fs);
   ObjectSetInteger(0, name, OBJPROP_CORNER,       CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,   false);
}

//+------------------------------------------------------------------+
void UpdatePanel() {
   double profit = AccountInfoDouble(ACCOUNT_PROFIT);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   int    open   = PositionsTotal();

   ObjectSetString (0, LBL_EQUITY,  OBJPROP_TEXT, "$" + DoubleToString(equity, 2));
   ObjectSetString (0, LBL_ACCOUNT, OBJPROP_TEXT, "#" + IntegerToString(mt5AccountNumber));

   string pnlStr = (profit >= 0 ? "+" : "") + "$" + DoubleToString(profit, 2);
   ObjectSetString (0, "TLJ_PnL", OBJPROP_TEXT,  pnlStr);
   ObjectSetInteger(0, "TLJ_PnL", OBJPROP_COLOR,
                    profit > 0 ? (color)C'0,212,161' : profit < 0 ? (color)C'255,71,87' : (color)C'201,209,217');

   ObjectSetString(0, LBL_COUNT, OBJPROP_TEXT,
                   IntegerToString(open) + (open==1?" pozycja":open<5?" pozycje":" pozycji"));
   ObjectSetString(0, "TLJ_Sent", OBJPROP_TEXT, IntegerToString(_sentCount) + " syg.");

   string st = _paused ? "⏸  Wstrzymany" : "●  Aktywny";
   ObjectSetString (0, LBL_STATUS, OBJPROP_TEXT,  st);
   ObjectSetInteger(0, LBL_STATUS, OBJPROP_COLOR, _paused ? (color)C'255,127,0' : (color)C'0,212,161');

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
   string sym      = Symbol();
   double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney= balance * riskPct / 100.0;

   double tickVal  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   double point    = SymbolInfoDouble(sym, SYMBOL_POINT);
   int    digits   = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   // 5/3-cyfrowi brokerzy: 1 pip = 10 punktów
   double pipSz    = (digits == 5 || digits == 3) ? point * 10.0 : point;
   double pipVal   = tickVal * pipSz / tickSize;
   if (pipVal <= 0) return 0;

   double lot  = riskMoney / (slPips * pipVal);
   double step = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   if (step <= 0) step = 0.01;
   lot = MathFloor(lot / step) * step;
   return MathMax(SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN),
                  MathMin(SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX), lot));
}

void CalculateAndShowLot() {
   double riskPct = StringToDouble(ObjectGetString(0, EDIT_RISK, OBJPROP_TEXT));
   double slPips  = StringToDouble(ObjectGetString(0, EDIT_SL,   OBJPROP_TEXT));
   double lot     = CalcLot(riskPct, slPips);
   ObjectSetString(0, LBL_LOT, OBJPROP_TEXT, lot > 0 ? DoubleToString(lot, 2) : "—");
   ChartRedraw();
}

//+------------------------------------------------------------------+
// OTWIERANIE POZYCJI
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING GetFilling(string sym) {
   uint flags = (uint)SymbolInfoInteger(sym, SYMBOL_FILLING_FLAGS);
   if ((flags & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if ((flags & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

void OpenOrder(ENUM_ORDER_TYPE orderType) {
   double riskPct = StringToDouble(ObjectGetString(0, EDIT_RISK, OBJPROP_TEXT));
   double slPips  = StringToDouble(ObjectGetString(0, EDIT_SL,   OBJPROP_TEXT));
   if (riskPct <= 0 || slPips <= 0) {
      Alert("TLJ: Wpisz poprawne Ryzyko % i SL pips!");
      return;
   }
   double lot = CalcLot(riskPct, slPips);
   if (lot <= 0) { Alert("TLJ: Błąd kalkulacji lota!"); return; }

   string sym    = Symbol();
   int    digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double point  = SymbolInfoDouble(sym, SYMBOL_POINT);
   double pipSz  = (digits == 5 || digits == 3) ? point * 10.0 : point;
   double price, sl;

   if (orderType == ORDER_TYPE_BUY) {
      price = NormalizeDouble(SymbolInfoDouble(sym, SYMBOL_ASK), digits);
      sl    = NormalizeDouble(price - slPips * pipSz, digits);
   } else {
      price = NormalizeDouble(SymbolInfoDouble(sym, SYMBOL_BID), digits);
      sl    = NormalizeDouble(price + slPips * pipSz, digits);
   }

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action       = TRADE_ACTION_DEAL;
   req.symbol       = sym;
   req.volume       = lot;
   req.type         = orderType;
   req.price        = price;
   req.sl           = sl;
   req.deviation    = 3;
   req.magic        = MagicNumber;
   req.comment      = "TLJ Panel";
   req.type_filling = GetFilling(sym);

   if (!OrderSend(req, res) || res.retcode != TRADE_RETCODE_DONE) {
      Print("TLJ: Błąd OrderSend retcode=", res.retcode, " err=", GetLastError());
      Alert("TLJ: Błąd otwarcia pozycji (retcode: ", res.retcode, ")");
   } else {
      Print("TLJ: Otwarto ", (orderType==ORDER_TYPE_BUY?"BUY":"SELL"),
            " lot=", lot, " sl=", sl);
   }
}

//+------------------------------------------------------------------+
// ZAMYKANIE POZYCJI
//+------------------------------------------------------------------+
void ClosePositions(int filterType) {
   // filterType: -1=wszystkie, POSITION_TYPE_BUY=0, POSITION_TYPE_SELL=1
   for (int i = PositionsTotal()-1; i >= 0; i--) {
      ulong  ticket  = PositionGetTicket(i);
      if (ticket == 0) continue;
      string sym     = PositionGetString(POSITION_SYMBOL);
      int    posType = (int)PositionGetInteger(POSITION_TYPE);
      double volume  = PositionGetDouble(POSITION_VOLUME);
      if (filterType >= 0 && posType != filterType) continue;

      ENUM_ORDER_TYPE closeType = (posType == POSITION_TYPE_BUY)
                                  ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      double closePrice = (closeType == ORDER_TYPE_SELL)
                          ? SymbolInfoDouble(sym, SYMBOL_BID)
                          : SymbolInfoDouble(sym, SYMBOL_ASK);
      int   digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.action       = TRADE_ACTION_DEAL;
      req.symbol       = sym;
      req.volume       = volume;
      req.type         = closeType;
      req.price        = NormalizeDouble(closePrice, digits);
      req.deviation    = 3;
      req.position     = ticket;
      req.type_filling = GetFilling(sym);

      if (!OrderSend(req, res) || res.retcode != TRADE_RETCODE_DONE)
         Print("TLJ: Błąd zamknięcia ticket=", ticket, " retcode=", res.retcode);
   }
}

//+------------------------------------------------------------------+
// ŚLEDZENIE POZYCJI
//+------------------------------------------------------------------+
void SnapshotPositions() {
   int total = PositionsTotal();
   ArrayResize(prevPositions, total);
   for (int i = 0; i < total; i++) {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      prevPositions[i].ticket = ticket;
      prevPositions[i].symbol = PositionGetString(POSITION_SYMBOL);
      prevPositions[i].type   = (int)PositionGetInteger(POSITION_TYPE);
      prevPositions[i].lots   = PositionGetDouble(POSITION_VOLUME);
      prevPositions[i].open   = PositionGetDouble(POSITION_PRICE_OPEN);
      prevPositions[i].sl     = PositionGetDouble(POSITION_SL);
      prevPositions[i].tp     = PositionGetDouble(POSITION_TP);
   }
}

void CheckPositionChanges() {
   int total = PositionsTotal();

   for (int i = 0; i < total; i++) {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;

      bool isNew = true;
      for (int j = 0; j < ArraySize(prevPositions); j++) {
         if (prevPositions[j].ticket != ticket) continue;
         isNew = false;
         if (SendOnModify) {
            double curSl = PositionGetDouble(POSITION_SL);
            double curTp = PositionGetDouble(POSITION_TP);
            if (MathAbs(prevPositions[j].sl - curSl) > 0.00001 ||
                MathAbs(prevPositions[j].tp - curTp) > 0.00001) {
               SendSignal("MODIFY", ticket,
                          PositionGetString(POSITION_SYMBOL),
                          (int)PositionGetInteger(POSITION_TYPE),
                          PositionGetDouble(POSITION_VOLUME),
                          PositionGetDouble(POSITION_PRICE_OPEN),
                          curSl, curTp, 0.0, 0.0,
                          (datetime)PositionGetInteger(POSITION_TIME), 0);
               _sentCount++;
            }
         }
         break;
      }
      if (isNew && SendOnOpen) {
         SendSignal("OPEN", ticket,
                    PositionGetString(POSITION_SYMBOL),
                    (int)PositionGetInteger(POSITION_TYPE),
                    PositionGetDouble(POSITION_VOLUME),
                    PositionGetDouble(POSITION_PRICE_OPEN),
                    PositionGetDouble(POSITION_SL),
                    PositionGetDouble(POSITION_TP),
                    0.0, 0.0,
                    (datetime)PositionGetInteger(POSITION_TIME), 0);
         _sentCount++;
      }
   }

   if (SendOnClose) {
      for (int j = 0; j < ArraySize(prevPositions); j++) {
         if (prevPositions[j].ticket == 0) continue;
         bool stillOpen = false;
         for (int i = 0; i < total; i++) {
            if (PositionGetTicket(i) == prevPositions[j].ticket) { stillOpen = true; break; }
         }
         if (!stillOpen) {
            ulong dealTicket = GetClosingDeal(prevPositions[j].ticket);
            if (dealTicket > 0) {
               double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
               double profit     = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                                 + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION)
                                 + HistoryDealGetDouble(dealTicket, DEAL_SWAP);
               datetime closeTime= (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
               SendSignal("CLOSE",
                          prevPositions[j].ticket,
                          prevPositions[j].symbol,
                          prevPositions[j].type,
                          prevPositions[j].lots,
                          prevPositions[j].open,
                          prevPositions[j].sl,
                          prevPositions[j].tp,
                          closePrice, profit,
                          0, closeTime);
               _sentCount++;
            }
         }
      }
   }

   SnapshotPositions();
}

//+------------------------------------------------------------------+
ulong GetClosingDeal(ulong positionTicket) {
   datetime from = (datetime)(TimeCurrent() - 86400);
   if (!HistorySelect(from, TimeCurrent())) return 0;
   int total = HistoryDealsTotal();
   for (int i = total - 1; i >= 0; i--) {
      ulong deal = HistoryDealGetTicket(i);
      if (HistoryDealGetInteger(deal, DEAL_POSITION_ID) == (long)positionTicket &&
          HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         return deal;
   }
   return 0;
}

//+------------------------------------------------------------------+
// SYNCHRONIZACJA HISTORII
//+------------------------------------------------------------------+
void SyncHistory(int days) {
   datetime fromTime = TimeCurrent() - (datetime)((long)days * 86400);
   if (!HistorySelect(fromTime, TimeCurrent())) return;

   int total  = HistoryDealsTotal();
   int synced = 0;
   Print("TLJ Historia: skanuję deale, ostatnie ", days, " dni...");

   for (int i = 0; i < total; i++) {
      ulong deal = HistoryDealGetTicket(i);
      if (HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      long dealType = HistoryDealGetInteger(deal, DEAL_TYPE);
      if (dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL) continue;

      string   symbol     = HistoryDealGetString(deal, DEAL_SYMBOL);
      string   direction  = (dealType == DEAL_TYPE_BUY) ? "BUY" : "SELL";
      double   lots       = HistoryDealGetDouble(deal, DEAL_VOLUME);
      double   closePrice = HistoryDealGetDouble(deal, DEAL_PRICE);
      double   profit     = HistoryDealGetDouble(deal, DEAL_PROFIT)
                          + HistoryDealGetDouble(deal, DEAL_COMMISSION)
                          + HistoryDealGetDouble(deal, DEAL_SWAP);
      datetime closeTime  = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      long     posId      = HistoryDealGetInteger(deal, DEAL_POSITION_ID);

      double   openPrice  = 0; datetime openTime = 0;
      for (int k = 0; k < total; k++) {
         ulong od = HistoryDealGetTicket(k);
         if (HistoryDealGetInteger(od, DEAL_POSITION_ID) == posId &&
             HistoryDealGetInteger(od, DEAL_ENTRY)       == DEAL_ENTRY_IN) {
            openPrice = HistoryDealGetDouble(od,  DEAL_PRICE);
            openTime  = (datetime)HistoryDealGetInteger(od, DEAL_TIME);
            break;
         }
      }

      string json = BuildJson("CLOSE", (ulong)posId, symbol, direction, "H1",
                              lots, openPrice, 0, 0, closePrice, profit,
                              openTime, closeTime, true);
      HttpPost(ApiUrl + "/rest/v1/mt4_signals?on_conflict=ticket",
               BuildHeaders(true), json);
      synced++;
      Sleep(250);
   }
   Print("TLJ Historia: zsync. ", synced, " transakcji z ostatnich ", days, " dni");
   _sentCount += synced;
   UpdatePanel();
}

//+------------------------------------------------------------------+
// HTTP / JSON
//+------------------------------------------------------------------+
void SendSignal(string event, ulong ticket, string symbol,
                int posType, double lots, double entry,
                double sl, double tp, double closePrice, double profit,
                datetime openTime, datetime closeTime) {
   string dir  = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
   string json = BuildJson(event, ticket, symbol, dir, GetTF(),
                           lots, entry, sl, tp, closePrice, profit,
                           openTime, closeTime, false);
   HttpPost(ApiUrl + "/rest/v1/mt4_signals", BuildHeaders(false), json);
   Print("TLJ [", event, "] ", symbol, " ", dir, " lot=", lots, " ticket=#", ticket);
}

string BuildJson(string event, ulong ticket, string symbol,
                 string dir, string tf,
                 double lots, double entry, double sl, double tp,
                 double closePrice, double profit,
                 datetime openTime, datetime closeTime, bool isHistory) {
   string j = "{";
   j += "\"user_id\":\""   + UserId                             + "\",";
   j += "\"mt4_account\":" + IntegerToString(mt5AccountNumber)  + ",";
   j += "\"symbol\":\""    + symbol                             + "\",";
   j += "\"direction\":\""  + dir                               + "\",";
   j += "\"tf\":\""        + tf                                 + "\",";
   j += "\"entry\":"       + DoubleToString(entry, 5)           + ",";
   j += "\"sl\":"          + DoubleToString(sl, 5)              + ",";
   j += "\"tp\":"          + DoubleToString(tp, 5)              + ",";
   j += "\"size\":"        + DoubleToString(lots, 2)            + ",";
   j += "\"ticket\":"      + IntegerToString((long)ticket)      + ",";
   j += "\"event\":\""     + event                              + "\",";
   j += "\"close_price\":" + DoubleToString(closePrice, 5)      + ",";
   j += "\"profit\":"      + DoubleToString(profit, 2)          + ",";
   j += "\"open_time\":\"" + TimeToString(openTime, TIME_DATE|TIME_SECONDS) + "\",";
   if (closeTime > 0)
      j += "\"close_time\":\"" + TimeToString(closeTime, TIME_DATE|TIME_SECONDS) + "\",";
   if (isHistory) j += "\"is_history\":true,";
   j += "\"processed\":false}";
   return j;
}

string BuildHeaders(bool mergeOnConflict) {
   string h  = "Content-Type: application/json\r\n";
   h += "apikey: "               + AnonKey + "\r\n";
   h += "Authorization: Bearer " + AnonKey + "\r\n";
   h += mergeOnConflict
        ? "Prefer: return=minimal,resolution=merge-duplicates\r\n"
        : "Prefer: return=minimal\r\n";
   return h;
}

void HttpPost(string url, string headers, string json) {
   char   post[], result[];
   string resultHeaders;
   ArrayResize(post, StringToCharArray(json, post, 0, WHOLE_ARRAY, CP_UTF8) - 1);
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

//+------------------------------------------------------------------+
//|  TraderLogJournal EA v2.0 — MT5                                  |
//|  Kalkulator pozycji + BUY/SELL panel + sync transakcji           |
//+------------------------------------------------------------------+
#property copyright   "TraderLogJournal"
#property link        "https://traderlogjournal.com"
#property version     "2.00"
#property description "Integracja MT5 z dziennikiem TraderLogJournal"
#property strict

//--- Parametry
input string   UserId              = "";       // [WYMAGANE] Skopiuj z Ustawienia → Integracja MT5
input string   ApiUrl              = "https://ygrkcynyduuflzvbkkvo.supabase.co";
input string   AnonKey             = "sb_publishable_-aRakEBT-U17VQJHksmK1Q_TbL1cToK";
input bool     SendOnOpen          = true;     // Wysyłaj sygnał przy otwarciu
input bool     SendOnClose         = true;     // Wysyłaj sygnał przy zamknięciu
input bool     SendOnModify        = true;     // Wysyłaj sygnał przy modyfikacji SL/TP
input bool     SendExistingOnStart = true;     // Wyślij otwarte pozycje przy starcie
input int      PanelX              = 20;       // Pozycja panelu X
input int      PanelY              = 30;       // Pozycja panelu Y
input ulong    MagicNumber         = 202601;   // Magic zleceń z panelu (0 = śledź wszystkie)
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
long   mt5AccountNumber = 0;
bool   _paused          = false;
int    _sentCount       = 0;

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
                    0, 0, 0, 0,
                    (datetime)PositionGetInteger(POSITION_TIME), 0);
         _sentCount++;
      }
   }

   if (Sync_History_Days > 0) SyncHistory(Sync_History_Days);

   EventSetTimer(2);
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
   UpdatePanel();
}

//+------------------------------------------------------------------+
// Główna logika — reaguje natychmiast na każdą transakcję.
// MT5 nie wymaga pollingu — OnTradeTransaction odpala się automatycznie.
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest&     request,
                        const MqlTradeResult&      result) {
   if (_paused) return;

   // Modyfikacja SL/TP na otwartej pozycji
   if (trans.type == TRADE_TRANSACTION_POSITION && SendOnModify) {
      if (PositionSelectByTicket(trans.position)) {
         SendSignal("MODIFY", trans.position,
                    PositionGetString(POSITION_SYMBOL),
                    (int)PositionGetInteger(POSITION_TYPE),
                    PositionGetDouble(POSITION_VOLUME),
                    PositionGetDouble(POSITION_PRICE_OPEN),
                    PositionGetDouble(POSITION_SL),
                    PositionGetDouble(POSITION_TP),
                    0, 0, 0, 0,
                    (datetime)PositionGetInteger(POSITION_TIME), 0);
         _sentCount++;
      }
      return;
   }

   // Interesują nas tylko finalne deale (zamknięcia, otwarcia, wpłaty)
   if (trans.type != TRADE_TRANSACTION_DEAL_ADD) return;

   ulong dealTicket = trans.deal;
   if (!HistoryDealSelect(dealTicket)) return;

   ENUM_DEAL_TYPE  dealType  = (ENUM_DEAL_TYPE) HistoryDealGetInteger(dealTicket, DEAL_TYPE);
   ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);

   // Wpłata / wypłata — MT5 wyróżnia DEAL_TYPE_BALANCE, bez ryzyka fałszywych sygnałów
   if (dealType == DEAL_TYPE_BALANCE) {
      double amount  = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      string balType = (amount >= 0) ? "DEPOSIT" : "WITHDRAWAL";
      SendBalanceSignal(balType, amount);
      _sentCount++;
      return;
   }

   // Tylko BUY / SELL
   if (dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL) return;

   string   symbol    = HistoryDealGetString(dealTicket,  DEAL_SYMBOL);
   double   volume    = HistoryDealGetDouble(dealTicket,  DEAL_VOLUME);
   double   price     = HistoryDealGetDouble(dealTicket,  DEAL_PRICE);
   double   profit    = HistoryDealGetDouble(dealTicket,  DEAL_PROFIT);
   double   commission= HistoryDealGetDouble(dealTicket,  DEAL_COMMISSION);
   double   swap      = HistoryDealGetDouble(dealTicket,  DEAL_SWAP);
   datetime dealTime  = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
   ulong    posId     = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);

   if (dealEntry == DEAL_ENTRY_IN && SendOnOpen) {
      double sl = 0, tp = 0;
      if (PositionSelectByTicket(posId)) {
         sl = PositionGetDouble(POSITION_SL);
         tp = PositionGetDouble(POSITION_TP);
      }
      SendSignal("OPEN", posId, symbol, (int)dealType,
                 volume, price, sl, tp, 0, 0, 0, 0, dealTime, 0);
      _sentCount++;
   }
   else if (dealEntry == DEAL_ENTRY_OUT && SendOnClose) {
      double   entryPrice = GetPositionEntryPrice(posId);
      datetime openTime   = GetPositionOpenTime(posId);
      SendSignal("CLOSE", posId, symbol, (int)dealType,
                 volume, entryPrice, 0, 0,
                 price, profit, commission, swap,
                 openTime, dealTime);
      _sentCount++;
   }
}

//+------------------------------------------------------------------+
// Pobierz cenę wejścia / czas otwarcia z historii deali pozycji
//+------------------------------------------------------------------+
double GetPositionEntryPrice(ulong positionId) {
   HistorySelectByPosition(positionId);
   int total = HistoryDealsTotal();
   for (int i = 0; i < total; i++) {
      ulong tk = HistoryDealGetTicket(i);
      if ((ENUM_DEAL_ENTRY)HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_IN)
         return HistoryDealGetDouble(tk, DEAL_PRICE);
   }
   return 0;
}

datetime GetPositionOpenTime(ulong positionId) {
   HistorySelectByPosition(positionId);
   int total = HistoryDealsTotal();
   for (int i = 0; i < total; i++) {
      ulong tk = HistoryDealGetTicket(i);
      if ((ENUM_DEAL_ENTRY)HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_IN)
         return (datetime)HistoryDealGetInteger(tk, DEAL_TIME);
   }
   return 0;
}

//+------------------------------------------------------------------+
// SYNCHRONIZACJA HISTORII
//+------------------------------------------------------------------+
void SyncHistory(int days) {
   datetime fromTime = TimeCurrent() - (datetime)((long)days * 86400);
   HistorySelect(fromTime, TimeCurrent());
   int total  = HistoryDealsTotal();
   int synced = 0;
   Print("TLJ Historia: skanuję ", total, " deali, ostatnie ", days, " dni...");

   for (int i = 0; i < total; i++) {
      ulong tk = HistoryDealGetTicket(i);
      if (!HistoryDealSelect(tk)) continue;
      ENUM_DEAL_TYPE  dt = (ENUM_DEAL_TYPE) HistoryDealGetInteger(tk, DEAL_TYPE);
      ENUM_DEAL_ENTRY de = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(tk, DEAL_ENTRY);
      if ((dt != DEAL_TYPE_BUY && dt != DEAL_TYPE_SELL) || de != DEAL_ENTRY_OUT) continue;

      string   sym    = HistoryDealGetString(tk, DEAL_SYMBOL);
      double   vol    = HistoryDealGetDouble(tk, DEAL_VOLUME);
      double   close  = HistoryDealGetDouble(tk, DEAL_PRICE);
      double   profit = HistoryDealGetDouble(tk, DEAL_PROFIT);
      double   comm   = HistoryDealGetDouble(tk, DEAL_COMMISSION);
      double   swap   = HistoryDealGetDouble(tk, DEAL_SWAP);
      datetime closeT = (datetime)HistoryDealGetInteger(tk, DEAL_TIME);
      ulong    posId  = (ulong)HistoryDealGetInteger(tk, DEAL_POSITION_ID);
      double   entry  = GetPositionEntryPrice(posId);
      datetime openT  = GetPositionOpenTime(posId);

      string dir  = (dt == DEAL_TYPE_BUY) ? "BUY" : "SELL";
      string json = BuildJson("CLOSE", posId, sym, dir, "H1",
                              vol, entry, 0, 0, close, profit,
                              comm, swap, openT, closeT, true);
      HttpPost(ApiUrl + "/rest/v1/mt4_signals?on_conflict=ticket",
               BuildHeaders(true), json);
      synced++;
      _sentCount++;
      Sleep(250);
   }
   Print("TLJ Historia: zsync. ", synced, " transakcji z ostatnich ", days, " dni");
}

//+------------------------------------------------------------------+
// KALKULATOR LOTA
//+------------------------------------------------------------------+
double CalcLot(double riskPct, double slPips) {
   if (riskPct <= 0 || slPips <= 0) return 0;
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * riskPct / 100.0;

   double tickVal  = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   double point    = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   int    digits   = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
   double pipSz    = (digits == 5 || digits == 3) ? point * 10.0 : point;
   double pipVal   = tickVal * pipSz / tickSize;
   if (pipVal <= 0) return 0;

   double lot  = riskMoney / (slPips * pipVal);
   double step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   if (step <= 0) step = 0.01;
   lot = MathFloor(lot / step) * step;
   return MathMax(SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN),
                  MathMin(SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX), lot));
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
void OpenOrder(ENUM_ORDER_TYPE orderType) {
   double riskPct = StringToDouble(ObjectGetString(0, EDIT_RISK, OBJPROP_TEXT));
   double slPips  = StringToDouble(ObjectGetString(0, EDIT_SL,   OBJPROP_TEXT));
   if (riskPct <= 0 || slPips <= 0) {
      Alert("TLJ: Wpisz poprawne Ryzyko % i SL pips!");
      return;
   }
   double lot = CalcLot(riskPct, slPips);
   if (lot <= 0) { Alert("TLJ: Błąd kalkulacji lota!"); return; }

   double point  = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
   double pipSz  = (digits == 5 || digits == 3) ? point * 10.0 : point;
   double ask    = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid    = SymbolInfoDouble(Symbol(), SYMBOL_BID);

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action       = TRADE_ACTION_DEAL;
   req.symbol       = Symbol();
   req.volume       = lot;
   req.type         = orderType;
   req.magic        = MagicNumber;
   req.comment      = "TLJ Panel";
   req.deviation    = 3;
   req.type_filling = ORDER_FILLING_IOC;

   if (orderType == ORDER_TYPE_BUY) {
      req.price = NormalizeDouble(ask, digits);
      req.sl    = NormalizeDouble(ask - slPips * pipSz, digits);
   } else {
      req.price = NormalizeDouble(bid, digits);
      req.sl    = NormalizeDouble(bid + slPips * pipSz, digits);
   }

   if (!OrderSend(req, res)) {
      Print("TLJ: Błąd OrderSend retcode=", res.retcode, " ", res.comment);
      Alert("TLJ: Błąd otwarcia zlecenia (kod: ", res.retcode, ")");
   } else {
      Print("TLJ: Otwarto ", EnumToString(orderType), " lot=", lot,
            " sl=", req.sl, " ticket=", res.deal);
   }
}

//+------------------------------------------------------------------+
// ZAMYKANIE POZYCJI
//+------------------------------------------------------------------+
void ClosePositions(int filterType) {
   // filterType: -1=wszystkie, POSITION_TYPE_BUY=0, POSITION_TYPE_SELL=1
   for (int i = PositionsTotal()-1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      int posType = (int)PositionGetInteger(POSITION_TYPE);
      if (filterType >= 0 && posType != filterType) continue;

      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.action       = TRADE_ACTION_DEAL;
      req.position     = ticket;
      req.symbol       = PositionGetString(POSITION_SYMBOL);
      req.volume       = PositionGetDouble(POSITION_VOLUME);
      req.type         = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      req.price        = (posType == POSITION_TYPE_BUY)
                         ? SymbolInfoDouble(req.symbol, SYMBOL_BID)
                         : SymbolInfoDouble(req.symbol, SYMBOL_ASK);
      req.deviation    = 3;
      req.type_filling = ORDER_FILLING_IOC;

      if (!OrderSend(req, res))
         Print("TLJ: Błąd zamknięcia ticket=", ticket, " retcode=", res.retcode);
   }
}

//+------------------------------------------------------------------+
// PANEL
//+------------------------------------------------------------------+
void CreatePanel() {
   int w = 222, h = 308;
   int x = PanelX, y = PanelY;

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

   CreateLabel(LBL_TITLE,       x+10,  y+9,  "TraderLog",           C'0,212,161',   10, true);
   CreateLabel("TLJ_Sub",       x+83,  y+9,  "Journal",             C'100,120,135', 10, false);
   CreateLabel("TLJ_Ver",       x+10,  y+26, "EA v2.0 MT5",         C'45,65,80',     8, false);
   CreateLabel(LBL_STATUS,      x+108, y+26, "● Aktywny",           C'0,212,161',    8, false);
   CreateSep("TLJ_L1", x+8, y+40, w-16);

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

   CreateLabel("TLJ_CalcHdr", x+10, y+126, "KALKULATOR POZYCJI", C'74,96,117', 7, false);
   CreateLabel("TLJ_RLbl",    x+10, y+142, "Ryzyko %",  C'150,170,185', 8, false);
   CreateEdit(EDIT_RISK, x+100, y+138, 50, 16, DoubleToString(DefaultRiskPct, 1));
   CreateLabel("TLJ_SLbl",    x+10, y+162, "SL (pips)", C'150,170,185', 8, false);
   CreateEdit(EDIT_SL, x+100, y+158, 50, 16, DoubleToString(DefaultSLPips, 1));
   CreateLabel("TLJ_LotLbl",  x+10, y+182, "Lot:",      C'150,170,185', 8, false);
   CreateLabel(LBL_LOT,        x+40, y+182, "—",         C'0,212,161',   9, true);
   CreateButton(BTN_CALC, x+158, y+177, 56, 18, "Oblicz",
                C'25,45,65', C'100,160,220', C'45,80,120', 8);
   CreateSep("TLJ_L3", x+8, y+198, w-16);

   CreateButton(BTN_BUY,  x+8,   y+205, 100, 26, "BUY",
                C'0,130,80',  clrWhite, C'0,180,110', 10);
   CreateButton(BTN_SELL, x+114, y+205, 100, 26, "SELL",
                C'160,30,40', clrWhite, C'200,50,60', 10);
   CreateButton(BTN_CLOSE_ALL, x+8,   y+235, 66, 18, "Close ALL",
                C'50,20,20', C'255,100,100', C'100,40,40', 7);
   CreateButton(BTN_CLOSE_BUY, x+78,  y+235, 66, 18, "Close BUY",
                C'20,50,30', C'80,200,120',  C'40,100,60', 7);
   CreateButton(BTN_CLOSE_SEL, x+148, y+235, 66, 18, "Close SELL",
                C'50,20,20', C'255,80,80',   C'100,40,40', 7);
   CreateSep("TLJ_L4", x+8, y+259, w-16);

   CreateButton(BTN_PAUSE, x+8,   y+265, 100, 22, "⏸  Pauza",
                C'30,45,61', C'122,139,153', C'45,63,80', 8);
   CreateButton(BTN_STOP,  x+114, y+265, 100, 22, "⏹  Stop EA",
                C'61,26,26', C'255,71,87',   C'93,40,40', 8);
   CreateLabel("TLJ_Link", x+10, y+293, "traderlogjournal.com", C'45,63,80', 7, false);
   ChartRedraw();
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
                    profit > 0 ? C'0,212,161' : profit < 0 ? C'255,71,87' : C'201,209,217');

   ObjectSetString(0, LBL_COUNT, OBJPROP_TEXT,
                   IntegerToString(open) + (open==1?" pozycja":open<5?" pozycje":" pozycji"));
   ObjectSetString(0, "TLJ_Sent",  OBJPROP_TEXT, IntegerToString(_sentCount) + " syg.");

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
// CHART EVENTS
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
         if (MessageBox("Zamknąć WSZYSTKIE zlecenia?",
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
         ObjectSetInteger(0, BTN_PAUSE, OBJPROP_BGCOLOR, _paused ? clrOrangeRed : C'30,45,61');
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
// HELPERS
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
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,    x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,    y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,        w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,        h);
   ObjectSetString (0, name, OBJPROP_TEXT,         val);
   ObjectSetInteger(0, name, OBJPROP_COLOR,        C'201,209,217');
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,      C'25,35,48');
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'45,63,80');
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
// HTTP / JSON
//+------------------------------------------------------------------+
void SendSignal(string event, ulong ticket, string symbol,
                int orderType, double lots, double entry,
                double sl, double tp, double closePrice, double profit,
                double commission, double swap,
                datetime openTime, datetime closeTime) {
   string dir  = (orderType == (int)DEAL_TYPE_BUY || orderType == (int)ORDER_TYPE_BUY)
                 ? "BUY" : "SELL";
   string json = BuildJson(event, ticket, symbol, dir, GetTF(),
                           lots, entry, sl, tp, closePrice, profit,
                           commission, swap, openTime, closeTime, false);
   HttpPost(ApiUrl + "/rest/v1/mt4_signals", BuildHeaders(false), json);
   Print("TLJ [", event, "] ", symbol, " ", dir, " lot=", lots,
         " profit=", profit, " comm=", commission, " swap=", swap,
         " ticket=#", ticket);
}

void SendBalanceSignal(string balType, double amount) {
   string j = "{";
   j += "\"user_id\":\""   + UserId                            + "\",";
   j += "\"mt4_account\":" + IntegerToString(mt5AccountNumber) + ",";
   j += "\"event\":\""     + balType                           + "\",";
   j += "\"symbol\":\"BALANCE\",";
   j += "\"direction\":\"LONG\",";
   j += "\"profit\":"      + DoubleToString(amount, 2)         + ",";
   j += "\"commission\":0,\"swap\":0,\"entry\":0,\"sl\":0,\"tp\":0,";
   j += "\"size\":0,\"close_price\":0,\"ticket\":0,";
   j += "\"open_time\":\"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\",";
   j += "\"processed\":false}";
   HttpPost(ApiUrl + "/rest/v1/mt4_signals", BuildHeaders(false), j);
   Print("TLJ [", balType, "] kwota=", amount);
}

string BuildJson(string event, ulong ticket, string symbol,
                 string dir, string tf,
                 double lots, double entry, double sl, double tp,
                 double closePrice, double profit,
                 double commission, double swap,
                 datetime openTime, datetime closeTime, bool isHistory) {
   string j = "{";
   j += "\"user_id\":\""   + UserId                            + "\",";
   j += "\"mt4_account\":" + IntegerToString(mt5AccountNumber) + ",";
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
   h += "apikey: "              + AnonKey + "\r\n";
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

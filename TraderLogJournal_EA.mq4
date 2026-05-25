//+------------------------------------------------------------------+
//|  TraderLogJournal EA v1.3                                        |
//|  Panel graficzny + historia transakcji                           |
//+------------------------------------------------------------------+
#property copyright   "TraderLogJournal"
#property link        "https://traderlogjournal.com"
#property version     "1.30"
#property description "Integracja MT4 z dziennikiem TraderLogJournal"
#property strict

//--- Parametry
input string   UserId            = "";     // [WYMAGANE] Skopiuj z Ustawienia → Integracja MT4
input string   ApiUrl            = "https://ygrkcynyduuflzvbkkvo.supabase.co";
input string   AnonKey           = "sb_publishable_-aRakEBT-U17VQJHksmK1Q_TbL1cToK";
input bool     SendOnOpen        = true;
input bool     SendOnClose       = true;
input bool     SendOnModify      = true;
input bool     SendExistingOnStart = true; // Wyślij otwarte pozycje przy starcie
input int      Sync_History_Days = 30;    // Synchronizuj historię zamkniętych transakcji (0 = wyłączone)
input int      CheckEvery        = 2;
input int      PanelX            = 20;     // Pozycja panelu X
input int      PanelY            = 30;     // Pozycja panelu Y

//--- Stałe panelu
#define PANEL_NAME    "TLJ_Panel"
#define BTN_STOP      "TLJ_BtnStop"
#define BTN_PAUSE     "TLJ_BtnPause"
#define LBL_STATUS    "TLJ_Status"
#define LBL_COUNT     "TLJ_Count"
#define LBL_TITLE     "TLJ_Title"
#define LBL_ACCOUNT   "TLJ_Account"
#define LBL_EQUITY    "TLJ_Equity"

//--- Zmienne
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
bool       _historySynced   = false;
int        _historyCount    = 0;

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
                    OrderStopLoss(), OrderTakeProfit(), 0, 0);
         _sentCount++;
      }
   }

   SnapshotTrades();

   if (Sync_History_Days > 0)
      SyncHistory();

   EventSetTimer(CheckEvery);
   UpdatePanel();
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
   if (id != CHARTEVENT_OBJECT_CLICK) return;

   if (sparam == BTN_STOP) {
      if (MessageBox("Zatrzymać TraderLogJournal EA?",
                     "TraderLogJournal", MB_YESNO | MB_ICONQUESTION) == IDYES) {
         Print("TraderLogJournal EA: zatrzymany przez użytkownika");
         ExpertRemove();
      }
      // Odznacz przycisk
      ObjectSetInteger(0, BTN_STOP, OBJPROP_STATE, false);
   }

   if (sparam == BTN_PAUSE) {
      _paused = !_paused;
      ObjectSetInteger(0, BTN_PAUSE, OBJPROP_STATE, false);
      ObjectSetString(0, BTN_PAUSE, OBJPROP_TEXT, _paused ? "▶ Wznów" : "⏸ Pauza");
      ObjectSetInteger(0, BTN_PAUSE, OBJPROP_BGCOLOR,
                       _paused ? clrOrangeRed : C'40,60,40');
      UpdatePanel();
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
void CreatePanel() {
   int w = 210, h = 206;
   int x = PanelX, y = PanelY;

   // === TŁO ===
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

   // === LOGO: "TraderLog" ===
   CreateLabel(LBL_TITLE, x+10, y+9, "TraderLog", C'0,212,161', 10, true);

   // === LOGO: "Journal" (szary) ===
   CreateLabel("TLJ_LogoSub", x+83, y+9, "Journal", C'100,120,135', 10, false);

   // === Wersja EA ===
   CreateLabel("TLJ_Ver", x+10, y+26, "EA v1.3", C'45,65,80', 8, false);

   // === Linia 1 ===
   ObjectCreate(0, "TLJ_L1", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "TLJ_L1", OBJPROP_XDISTANCE,  x+8);
   ObjectSetInteger(0, "TLJ_L1", OBJPROP_YDISTANCE,  y+38);
   ObjectSetInteger(0, "TLJ_L1", OBJPROP_XSIZE,      w-16);
   ObjectSetInteger(0, "TLJ_L1", OBJPROP_YSIZE,      1);
   ObjectSetInteger(0, "TLJ_L1", OBJPROP_BGCOLOR,    C'30,45,61');
   ObjectSetInteger(0, "TLJ_L1", OBJPROP_SELECTABLE, false);

   // === Status dot + tekst ===
   CreateLabel(LBL_STATUS, x+10, y+46, "● Aktywny", C'0,212,161', 8, false);

   // === Wiersze danych ===
   // Konto
   CreateLabel("TLJ_K1", x+10, y+60, "KONTO", C'74,96,117', 8, false);
   CreateLabel(LBL_ACCOUNT, x+140, y+60, "#4735545", C'201,209,217', 8, false);

   // Equity
   CreateLabel("TLJ_K2", x+10, y+74, "EQUITY", C'74,96,117', 8, false);
   CreateLabel(LBL_EQUITY, x+140, y+74, "$0.00", C'201,209,217', 8, false);

   // P&L
   CreateLabel("TLJ_K3", x+10, y+88, "P&L OTWR.", C'74,96,117', 8, false);
   CreateLabel("TLJ_PnL", x+140, y+88, "—", C'201,209,217', 8, false);

   // Otwarte
   CreateLabel("TLJ_K4", x+10, y+102, "OTWARTE", C'74,96,117', 8, false);
   CreateLabel(LBL_COUNT, x+140, y+102, "0 pozycji", C'201,209,217', 8, false);

   // Sygnały live
   CreateLabel("TLJ_K5", x+10, y+116, "WYSŁANO", C'74,96,117', 8, false);
   CreateLabel("TLJ_Sent", x+140, y+116, "0 sygnałów", C'201,209,217', 8, false);

   // Historia
   CreateLabel("TLJ_K6", x+10, y+130, "HISTORIA", C'74,96,117', 8, false);
   CreateLabel("TLJ_Hist", x+140, y+130, "—", C'201,209,217', 8, false);

   // === Linia 2 ===
   ObjectCreate(0, "TLJ_L2", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "TLJ_L2", OBJPROP_XDISTANCE,  x+8);
   ObjectSetInteger(0, "TLJ_L2", OBJPROP_YDISTANCE,  y+144);
   ObjectSetInteger(0, "TLJ_L2", OBJPROP_XSIZE,      w-16);
   ObjectSetInteger(0, "TLJ_L2", OBJPROP_YSIZE,      1);
   ObjectSetInteger(0, "TLJ_L2", OBJPROP_BGCOLOR,    C'30,45,61');
   ObjectSetInteger(0, "TLJ_L2", OBJPROP_SELECTABLE, false);

   // === BTN PAUZA ===
   ObjectCreate(0, BTN_PAUSE, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, BTN_PAUSE, OBJPROP_XDISTANCE,  x+8);
   ObjectSetInteger(0, BTN_PAUSE, OBJPROP_YDISTANCE,  y+151);
   ObjectSetInteger(0, BTN_PAUSE, OBJPROP_XSIZE,      93);
   ObjectSetInteger(0, BTN_PAUSE, OBJPROP_YSIZE,      22);
   ObjectSetString (0, BTN_PAUSE, OBJPROP_TEXT,       "⏸  Pauza");
   ObjectSetInteger(0, BTN_PAUSE, OBJPROP_BGCOLOR,    C'30,45,61');
   ObjectSetInteger(0, BTN_PAUSE, OBJPROP_COLOR,      C'122,139,153');
   ObjectSetInteger(0, BTN_PAUSE, OBJPROP_FONTSIZE,   8);
   ObjectSetInteger(0, BTN_PAUSE, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, BTN_PAUSE, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, BTN_PAUSE, OBJPROP_BORDER_COLOR, C'45,63,80');

   // === BTN STOP ===
   ObjectCreate(0, BTN_STOP, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, BTN_STOP, OBJPROP_XDISTANCE,  x+109);
   ObjectSetInteger(0, BTN_STOP, OBJPROP_YDISTANCE,  y+151);
   ObjectSetInteger(0, BTN_STOP, OBJPROP_XSIZE,      93);
   ObjectSetInteger(0, BTN_STOP, OBJPROP_YSIZE,      22);
   ObjectSetString (0, BTN_STOP, OBJPROP_TEXT,       "⏹  Stop EA");
   ObjectSetInteger(0, BTN_STOP, OBJPROP_BGCOLOR,    C'61,26,26');
   ObjectSetInteger(0, BTN_STOP, OBJPROP_COLOR,      C'255,71,87');
   ObjectSetInteger(0, BTN_STOP, OBJPROP_FONTSIZE,   8);
   ObjectSetInteger(0, BTN_STOP, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, BTN_STOP, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, BTN_STOP, OBJPROP_BORDER_COLOR, C'93,40,40');

   // === FOOTER ===
   CreateLabel("TLJ_Link", x+10, y+183, "traderlogjournal.com", C'45,63,80', 7, false);

   ChartRedraw();
}

//+------------------------------------------------------------------+
void UpdatePanel() {
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double profit  = AccountInfoDouble(ACCOUNT_PROFIT);
   int    open    = OrdersTotal();

   // Equity
   string eqStr = "$" + DoubleToString(equity, 2);
   ObjectSetString(0, LBL_EQUITY, OBJPROP_TEXT, eqStr);
   ObjectSetInteger(0, LBL_EQUITY, OBJPROP_COLOR, C'201,209,217');

   // P&L otwarty
   string pnlStr = (profit >= 0 ? "+" : "") + "$" + DoubleToString(profit, 2);
   ObjectSetString(0, "TLJ_PnL", OBJPROP_TEXT, pnlStr);
   ObjectSetInteger(0, "TLJ_PnL", OBJPROP_COLOR,
                    profit > 0 ? C'0,212,161' : profit < 0 ? C'255,71,87' : C'201,209,217');

   // Konto
   ObjectSetString(0, LBL_ACCOUNT, OBJPROP_TEXT, "#" + IntegerToString(mt4AccountNumber));

   // Otwarte pozycje
   ObjectSetString(0, LBL_COUNT, OBJPROP_TEXT,
                   IntegerToString(open) + (open == 1 ? " pozycja" : open < 5 ? " pozycje" : " pozycji"));

   // Wysłano live
   ObjectSetString(0, "TLJ_Sent", OBJPROP_TEXT,
                   IntegerToString(_sentCount) + " sygnałów");

   // Historia
   if (_historySynced)
      ObjectSetString(0, "TLJ_Hist", OBJPROP_TEXT,
                      IntegerToString(_historyCount) + " transakcji");
   else if (Sync_History_Days > 0)
      ObjectSetString(0, "TLJ_Hist", OBJPROP_TEXT, "synchronizacja...");
   else
      ObjectSetString(0, "TLJ_Hist", OBJPROP_TEXT, "wyłączone");

   // Status
   string statusStr = _paused ? "⏸  Wstrzymany" : "●  Aktywny";
   ObjectSetString(0, LBL_STATUS, OBJPROP_TEXT, statusStr);
   ObjectSetInteger(0, LBL_STATUS, OBJPROP_COLOR,
                    _paused ? C'255,127,0' : C'0,212,161');

   ChartRedraw();
}

//+------------------------------------------------------------------+
void DeletePanel() {
   string objects[] = {
      PANEL_NAME, BTN_STOP, BTN_PAUSE,
      LBL_STATUS, LBL_COUNT, LBL_TITLE,
      LBL_ACCOUNT, LBL_EQUITY,
      "TLJ_LogoSub", "TLJ_Ver",
      "TLJ_L1", "TLJ_L2",
      "TLJ_K1", "TLJ_K2", "TLJ_K3", "TLJ_K4", "TLJ_K5", "TLJ_K6",
      "TLJ_PnL", "TLJ_Sent", "TLJ_Hist", "TLJ_Link"
   };
   for (int i = 0; i < ArraySize(objects); i++)
      ObjectDelete(0, objects[i]);
   ChartRedraw();
}

//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text,
                 color clr, int fontSize = 8, bool bold = false) {
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
   ObjectSetString (0, name, OBJPROP_TEXT,       text);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   fontSize);
   ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   if (bold)
      ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
}

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

//+------------------------------------------------------------------+
void CheckTradeChanges() {
   int total = OrdersTotal();

   for (int i = 0; i < total; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderType() > 1) continue;

      bool isNew = true;
      for (int j = 0; j < ArraySize(prevTrades); j++) {
         if (prevTrades[j].ticket != OrderTicket()) continue;
         isNew = false;
         if (SendOnModify) {
            if (MathAbs(prevTrades[j].sl - OrderStopLoss()) > 0.00001 ||
                MathAbs(prevTrades[j].tp - OrderTakeProfit()) > 0.00001) {
               SendSignal("MODIFY", OrderTicket(), OrderSymbol(),
                          OrderType(), OrderLots(), OrderOpenPrice(),
                          OrderStopLoss(), OrderTakeProfit(), 0, 0);
               _sentCount++;
            }
         }
         break;
      }
      if (isNew && SendOnOpen) {
         SendSignal("OPEN", OrderTicket(), OrderSymbol(),
                    OrderType(), OrderLots(), OrderOpenPrice(),
                    OrderStopLoss(), OrderTakeProfit(), 0, 0);
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
         if (!stillOpen) {
            if (OrderSelect((int)prevTrades[j].ticket, SELECT_BY_TICKET, MODE_HISTORY)) {
               double netProfit = OrderProfit() + OrderCommission() + OrderSwap();
               SendSignal("CLOSE", OrderTicket(), OrderSymbol(),
                          OrderType(), OrderLots(), OrderOpenPrice(),
                          OrderStopLoss(), OrderTakeProfit(),
                          OrderClosePrice(), netProfit);
               _sentCount++;
            }
         }
      }
   }

   SnapshotTrades();
}

//+------------------------------------------------------------------+
string DateTimeToISO(datetime dt) {
   MqlDateTime s;
   TimeToStruct(dt, s);
   return StringFormat("%04d-%02d-%02dT%02d:%02d:%02d",
                       s.year, s.mon, s.day, s.hour, s.min, s.sec);
}

//+------------------------------------------------------------------+
void SyncHistory() {
   if (_historySynced) return;
   _historySynced = true;

   datetime cutoff = TimeCurrent() - (datetime)(Sync_History_Days * 86400);
   int total = OrdersHistoryTotal();
   _historyCount = 0;

   for (int i = 0; i < total; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if (OrderType() > 1) continue;           // tylko BUY/SELL
      if (OrderCloseTime() < cutoff) continue; // poza zakresem dni

      double netProfit = OrderProfit() + OrderCommission() + OrderSwap();

      string direction = (OrderType() == OP_BUY) ? "BUY" : "SELL";
      string json = "{";
      json += "\"user_id\":\""    + UserId                            + "\",";
      json += "\"mt4_account\":"  + IntegerToString(mt4AccountNumber) + ",";
      json += "\"symbol\":\""     + OrderSymbol()                     + "\",";
      json += "\"direction\":\""  + direction                         + "\",";
      json += "\"tf\":\"H1\",";
      json += "\"entry\":"        + DoubleToString(OrderOpenPrice(), 5)  + ",";
      json += "\"sl\":"           + DoubleToString(OrderStopLoss(), 5)   + ",";
      json += "\"tp\":"           + DoubleToString(OrderTakeProfit(), 5) + ",";
      json += "\"size\":"         + DoubleToString(OrderLots(), 2)       + ",";
      json += "\"ticket\":"       + IntegerToString(OrderTicket())       + ",";
      json += "\"event\":\"HISTORY\",";
      json += "\"close_price\":"  + DoubleToString(OrderClosePrice(), 5) + ",";
      json += "\"profit\":"       + DoubleToString(netProfit, 2)         + ",";
      json += "\"open_time\":\""  + DateTimeToISO(OrderOpenTime())       + "\",";
      json += "\"close_time\":\"" + DateTimeToISO(OrderCloseTime())      + "\",";
      json += "\"processed\":false";
      json += "}";

      string headers = "Content-Type: application/json\r\n";
      headers += "apikey: "           + AnonKey + "\r\n";
      headers += "Authorization: Bearer " + AnonKey + "\r\n";
      headers += "Prefer: return=minimal\r\n";

      char   post[], result[];
      string resultHeaders;
      StringToCharArray(json, post, 0, StringLen(json));

      int res = WebRequest("POST",
                           ApiUrl + "/rest/v1/mt4_signals",
                           headers, 5000, post, result, resultHeaders);

      if (res == 201 || res == 200) {
         _historyCount++;
      } else {
         Print("TLJ Historia błąd HTTP ", res, " ticket=#", OrderTicket(),
               " | ", CharArrayToString(result));
      }
   }

   Print("TLJ Historia: zsynchronizowano ", _historyCount, " zamkniętych transakcji z ostatnich ",
         Sync_History_Days, " dni");
   UpdatePanel();
}

//+------------------------------------------------------------------+
void SendSignal(string event, long ticket, string symbol,
                int orderType, double lots, double entry,
                double sl, double tp,
                double closePrice, double profit) {

   string direction = (orderType == OP_BUY) ? "BUY" : "SELL";

   // Interwał wykresu
   string tf = "";
   switch(Period()) {
      case PERIOD_M1:  tf = "M1";  break;
      case PERIOD_M5:  tf = "M5";  break;
      case PERIOD_M15: tf = "M15"; break;
      case PERIOD_M30: tf = "M30"; break;
      case PERIOD_H1:  tf = "H1";  break;
      case PERIOD_H4:  tf = "H4";  break;
      case PERIOD_D1:  tf = "D1";  break;
      case PERIOD_W1:  tf = "W1";  break;
      case PERIOD_MN1: tf = "MN";  break;
      default:         tf = "H1";  break;
   }

   string json = "{";
   json += "\"user_id\":\""    + UserId                            + "\",";
   json += "\"mt4_account\":"  + IntegerToString(mt4AccountNumber) + ",";
   json += "\"symbol\":\""     + symbol                            + "\",";
   json += "\"direction\":\""  + direction                         + "\",";
   json += "\"tf\":\""         + tf                                + "\",";
   json += "\"entry\":"        + DoubleToString(entry, 5)          + ",";
   json += "\"sl\":"           + DoubleToString(sl, 5)             + ",";
   json += "\"tp\":"           + DoubleToString(tp, 5)             + ",";
   json += "\"size\":"         + DoubleToString(lots, 2)           + ",";
   json += "\"ticket\":"       + IntegerToString(ticket)           + ",";
   json += "\"event\":\""      + event                             + "\",";
   json += "\"close_price\":"  + DoubleToString(closePrice, 5)     + ",";
   json += "\"profit\":"       + DoubleToString(profit, 2)         + ",";
   json += "\"processed\":false";
   json += "}";

   string headers = "Content-Type: application/json\r\n";
   headers += "apikey: "           + AnonKey + "\r\n";
   headers += "Authorization: Bearer " + AnonKey + "\r\n";
   headers += "Prefer: return=minimal\r\n";

   char   post[], result[];
   string resultHeaders;
   StringToCharArray(json, post, 0, StringLen(json));

   int res = WebRequest("POST",
                        ApiUrl + "/rest/v1/mt4_signals",
                        headers, 5000, post, result, resultHeaders);

   if (res == 201 || res == 200) {
      Print("TLJ [", event, "] ", symbol, " ", direction,
            " tf=", tf, " lot=", lots, " entry=", entry,
            " ticket=#", ticket);
   } else {
      Print("TLJ Błąd HTTP ", res, " [", event, "] ", symbol,
            " | ", CharArrayToString(result));
   }
}

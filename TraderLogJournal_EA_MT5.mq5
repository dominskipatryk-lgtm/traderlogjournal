//+------------------------------------------------------------------+
//|  TraderLogJournal EA MT5 v1.0                                    |
//|  Panel graficzny + historia transakcji                           |
//+------------------------------------------------------------------+
#property copyright   "TraderLogJournal"
#property link        "https://traderlogjournal.com"
#property version     "1.00"
#property description "Integracja MT5 z dziennikiem TraderLogJournal"

//--- Parametry
input string   UserId              = "";    // [WYMAGANE] Skopiuj z Ustawienia → Integracja MT5
input string   ApiUrl              = "https://ygrkcynyduuflzvbkkvo.supabase.co";
input string   AnonKey             = "sb_publishable_-aRakEBT-U17VQJHksmK1Q_TbL1cToK";
input bool     SendOnOpen          = true;
input bool     SendOnClose         = true;
input bool     SendOnModify        = true;
input bool     SendExistingOnStart = true;  // Wyślij otwarte pozycje przy starcie
input int      Sync_History_Days   = 30;   // Synchronizuj historię (0 = wyłączone)
input int      CheckEvery          = 2;
input int      PanelX              = 20;   // Pozycja panelu X
input int      PanelY              = 30;   // Pozycja panelu Y

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
bool          _historySynced   = false;
int           _historyCount    = 0;

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
                    0.0, 0.0);
         _sentCount++;
      }
   }

   SnapshotPositions();

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
   if (!_paused) CheckPositionChanges();
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
      ObjectSetInteger(0, BTN_STOP, OBJPROP_STATE, false);
   }

   if (sparam == BTN_PAUSE) {
      _paused = !_paused;
      ObjectSetInteger(0, BTN_PAUSE, OBJPROP_STATE, false);
      ObjectSetString(0, BTN_PAUSE, OBJPROP_TEXT, _paused ? "▶ Wznów" : "⏸ Pauza");
      ObjectSetInteger(0, BTN_PAUSE, OBJPROP_BGCOLOR,
                       _paused ? (color)C'204,81,0' : (color)C'40,60,40');
      UpdatePanel();
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
void CreatePanel() {
   int w = 210, h = 206;
   int x = PanelX, y = PanelY;

   // TŁO
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

   CreateLabel(LBL_TITLE,     x+10,  y+9,  "TraderLog",          (color)C'0,212,161', 10, true);
   CreateLabel("TLJ_LogoSub", x+83,  y+9,  "Journal",            (color)C'100,120,135', 10, false);
   CreateLabel("TLJ_Ver",     x+10,  y+26, "EA MT5 v1.0",        (color)C'45,65,80', 8, false);

   // Linia 1
   ObjectCreate(0, "TLJ_L1", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "TLJ_L1", OBJPROP_XDISTANCE,  x+8);
   ObjectSetInteger(0, "TLJ_L1", OBJPROP_YDISTANCE,  y+38);
   ObjectSetInteger(0, "TLJ_L1", OBJPROP_XSIZE,      w-16);
   ObjectSetInteger(0, "TLJ_L1", OBJPROP_YSIZE,      1);
   ObjectSetInteger(0, "TLJ_L1", OBJPROP_BGCOLOR,    (color)C'30,45,61');
   ObjectSetInteger(0, "TLJ_L1", OBJPROP_SELECTABLE, false);

   CreateLabel(LBL_STATUS,    x+10, y+46,  "● Aktywny",          (color)C'0,212,161', 8, false);
   CreateLabel("TLJ_K1",      x+10, y+60,  "KONTO",              (color)C'74,96,117', 8, false);
   CreateLabel(LBL_ACCOUNT,   x+140,y+60,  "#0000000",           (color)C'201,209,217', 8, false);
   CreateLabel("TLJ_K2",      x+10, y+74,  "EQUITY",             (color)C'74,96,117', 8, false);
   CreateLabel(LBL_EQUITY,    x+140,y+74,  "$0.00",              (color)C'201,209,217', 8, false);
   CreateLabel("TLJ_K3",      x+10, y+88,  "P&L OTWR.",          (color)C'74,96,117', 8, false);
   CreateLabel("TLJ_PnL",     x+140,y+88,  "—",                  (color)C'201,209,217', 8, false);
   CreateLabel("TLJ_K4",      x+10, y+102, "OTWARTE",            (color)C'74,96,117', 8, false);
   CreateLabel(LBL_COUNT,     x+140,y+102, "0 pozycji",          (color)C'201,209,217', 8, false);
   CreateLabel("TLJ_K5",      x+10, y+116, "WYSŁANO",            (color)C'74,96,117', 8, false);
   CreateLabel("TLJ_Sent",    x+140,y+116, "0 sygnałów",         (color)C'201,209,217', 8, false);
   CreateLabel("TLJ_K6",      x+10, y+130, "HISTORIA",           (color)C'74,96,117', 8, false);
   CreateLabel("TLJ_Hist",    x+140,y+130, "—",                  (color)C'201,209,217', 8, false);

   // Linia 2
   ObjectCreate(0, "TLJ_L2", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "TLJ_L2", OBJPROP_XDISTANCE,  x+8);
   ObjectSetInteger(0, "TLJ_L2", OBJPROP_YDISTANCE,  y+144);
   ObjectSetInteger(0, "TLJ_L2", OBJPROP_XSIZE,      w-16);
   ObjectSetInteger(0, "TLJ_L2", OBJPROP_YSIZE,      1);
   ObjectSetInteger(0, "TLJ_L2", OBJPROP_BGCOLOR,    (color)C'30,45,61');
   ObjectSetInteger(0, "TLJ_L2", OBJPROP_SELECTABLE, false);

   // Przyciski
   ObjectCreate(0, BTN_PAUSE, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, BTN_PAUSE, OBJPROP_XDISTANCE,  x+8);
   ObjectSetInteger(0, BTN_PAUSE, OBJPROP_YDISTANCE,  y+151);
   ObjectSetInteger(0, BTN_PAUSE, OBJPROP_XSIZE,      93);
   ObjectSetInteger(0, BTN_PAUSE, OBJPROP_YSIZE,      22);
   ObjectSetString (0, BTN_PAUSE, OBJPROP_TEXT,       "⏸  Pauza");
   ObjectSetInteger(0, BTN_PAUSE, OBJPROP_BGCOLOR,    (color)C'30,45,61');
   ObjectSetInteger(0, BTN_PAUSE, OBJPROP_COLOR,      (color)C'122,139,153');
   ObjectSetInteger(0, BTN_PAUSE, OBJPROP_FONTSIZE,   8);
   ObjectSetInteger(0, BTN_PAUSE, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, BTN_PAUSE, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, BTN_PAUSE, OBJPROP_BORDER_COLOR, (color)C'45,63,80');

   ObjectCreate(0, BTN_STOP, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, BTN_STOP, OBJPROP_XDISTANCE,  x+109);
   ObjectSetInteger(0, BTN_STOP, OBJPROP_YDISTANCE,  y+151);
   ObjectSetInteger(0, BTN_STOP, OBJPROP_XSIZE,      93);
   ObjectSetInteger(0, BTN_STOP, OBJPROP_YSIZE,      22);
   ObjectSetString (0, BTN_STOP, OBJPROP_TEXT,       "⏹  Stop EA");
   ObjectSetInteger(0, BTN_STOP, OBJPROP_BGCOLOR,    (color)C'61,26,26');
   ObjectSetInteger(0, BTN_STOP, OBJPROP_COLOR,      (color)C'255,71,87');
   ObjectSetInteger(0, BTN_STOP, OBJPROP_FONTSIZE,   8);
   ObjectSetInteger(0, BTN_STOP, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, BTN_STOP, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, BTN_STOP, OBJPROP_BORDER_COLOR, (color)C'93,40,40');

   CreateLabel("TLJ_Link", x+10, y+183, "traderlogjournal.com", (color)C'45,63,80', 7, false);

   ChartRedraw();
}

//+------------------------------------------------------------------+
void UpdatePanel() {
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double profit  = AccountInfoDouble(ACCOUNT_PROFIT);
   int    open    = PositionsTotal();

   string eqStr  = "$" + DoubleToString(equity, 2);
   ObjectSetString(0, LBL_EQUITY, OBJPROP_TEXT, eqStr);

   string pnlStr = (profit >= 0 ? "+" : "") + "$" + DoubleToString(profit, 2);
   ObjectSetString(0, "TLJ_PnL", OBJPROP_TEXT, pnlStr);
   ObjectSetInteger(0, "TLJ_PnL", OBJPROP_COLOR,
                    profit > 0 ? (color)C'0,212,161' : profit < 0 ? (color)C'255,71,87' : (color)C'201,209,217');

   ObjectSetString(0, LBL_ACCOUNT, OBJPROP_TEXT, "#" + IntegerToString(mt5AccountNumber));
   ObjectSetString(0, LBL_COUNT, OBJPROP_TEXT,
                   IntegerToString(open) + (open == 1 ? " pozycja" : open < 5 ? " pozycje" : " pozycji"));
   ObjectSetString(0, "TLJ_Sent", OBJPROP_TEXT, IntegerToString(_sentCount) + " sygnałów");

   if (_historySynced)
      ObjectSetString(0, "TLJ_Hist", OBJPROP_TEXT, IntegerToString(_historyCount) + " transakcji");
   else if (Sync_History_Days > 0)
      ObjectSetString(0, "TLJ_Hist", OBJPROP_TEXT, "synchronizacja...");
   else
      ObjectSetString(0, "TLJ_Hist", OBJPROP_TEXT, "wyłączone");

   string statusStr = _paused ? "⏸  Wstrzymany" : "●  Aktywny";
   ObjectSetString(0, LBL_STATUS, OBJPROP_TEXT, statusStr);
   ObjectSetInteger(0, LBL_STATUS, OBJPROP_COLOR,
                    _paused ? (color)C'255,127,0' : (color)C'0,212,161');

   ChartRedraw();
}

//+------------------------------------------------------------------+
void DeletePanel() {
   string objects[] = {
      PANEL_NAME, BTN_STOP, BTN_PAUSE,
      LBL_STATUS, LBL_COUNT, LBL_TITLE, LBL_ACCOUNT, LBL_EQUITY,
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

//+------------------------------------------------------------------+
void CheckPositionChanges() {
   int total = PositionsTotal();

   // Sprawdź nowe / zmodyfikowane pozycje
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
                          curSl, curTp, 0.0, 0.0);
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
                    0.0, 0.0);
         _sentCount++;
      }
   }

   // Sprawdź zamknięte pozycje
   if (SendOnClose) {
      for (int j = 0; j < ArraySize(prevPositions); j++) {
         if (prevPositions[j].ticket == 0) continue;
         bool stillOpen = false;
         for (int i = 0; i < total; i++) {
            ulong ticket = PositionGetTicket(i);
            if (ticket == prevPositions[j].ticket) { stillOpen = true; break; }
         }
         if (!stillOpen) {
            // Pobierz dane z historii
            ulong dealTicket = GetClosingDeal(prevPositions[j].ticket);
            if (dealTicket > 0) {
               double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
               double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                                 + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION)
                                 + HistoryDealGetDouble(dealTicket, DEAL_SWAP);
               SendSignal("CLOSE",
                          prevPositions[j].ticket,
                          prevPositions[j].symbol,
                          prevPositions[j].type,
                          prevPositions[j].lots,
                          prevPositions[j].open,
                          prevPositions[j].sl,
                          prevPositions[j].tp,
                          closePrice, dealProfit);
               _sentCount++;
            }
         }
      }
   }

   SnapshotPositions();
}

//+------------------------------------------------------------------+
ulong GetClosingDeal(ulong positionTicket) {
   datetime from = (datetime)(TimeCurrent() - 86400); // max 1 dzień wstecz
   if (!HistorySelect(from, TimeCurrent())) return 0;
   int dealsTotal = HistoryDealsTotal();
   for (int i = dealsTotal - 1; i >= 0; i--) {
      ulong dealTicket = HistoryDealGetTicket(i);
      if (HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID) == (long)positionTicket &&
          HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         return dealTicket;
   }
   return 0;
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
   if (!HistorySelect(cutoff, TimeCurrent())) return;

   int dealsTotal = HistoryDealsTotal();
   _historyCount  = 0;

   for (int i = 0; i < dealsTotal; i++) {
      ulong dealTicket = HistoryDealGetTicket(i);
      if (HistoryDealGetInteger(dealTicket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      long dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
      if (dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL) continue;

      string symbol    = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      string direction = (dealType == DEAL_TYPE_BUY) ? "BUY" : "SELL";
      double lots      = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
      double closePrice= HistoryDealGetDouble(dealTicket, DEAL_PRICE);
      double profit    = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                       + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION)
                       + HistoryDealGetDouble(dealTicket, DEAL_SWAP);
      datetime closeTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
      long posId       = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);

      // Pobierz dane otwarcia pozycji
      double openPrice = 0; datetime openTime = 0;
      for (int j = 0; j < dealsTotal; j++) {
         ulong openDeal = HistoryDealGetTicket(j);
         if (HistoryDealGetInteger(openDeal, DEAL_POSITION_ID) == posId &&
             HistoryDealGetInteger(openDeal, DEAL_ENTRY) == DEAL_ENTRY_IN) {
            openPrice = HistoryDealGetDouble(openDeal, DEAL_PRICE);
            openTime  = (datetime)HistoryDealGetInteger(openDeal, DEAL_TIME);
            break;
         }
      }

      string json = "{";
      json += "\"user_id\":\""    + UserId                            + "\",";
      json += "\"mt4_account\":"  + IntegerToString(mt5AccountNumber) + ",";
      json += "\"symbol\":\""     + symbol                            + "\",";
      json += "\"direction\":\""  + direction                         + "\",";
      json += "\"tf\":\"H1\",";
      json += "\"entry\":"        + DoubleToString(openPrice, 5)      + ",";
      json += "\"sl\":0,";
      json += "\"tp\":0,";
      json += "\"size\":"         + DoubleToString(lots, 2)           + ",";
      json += "\"ticket\":"       + IntegerToString(posId)            + ",";
      json += "\"event\":\"HISTORY\",";
      json += "\"close_price\":"  + DoubleToString(closePrice, 5)     + ",";
      json += "\"profit\":"       + DoubleToString(profit, 2)         + ",";
      json += "\"open_time\":\""  + DateTimeToISO(openTime)           + "\",";
      json += "\"close_time\":\"" + DateTimeToISO(closeTime)          + "\",";
      json += "\"processed\":false";
      json += "}";

      SendJsonToApi(json, "HISTORY #" + IntegerToString(posId));
      _historyCount++;
   }

   Print("TLJ Historia: zsynchronizowano ", _historyCount,
         " zamkniętych transakcji z ostatnich ", Sync_History_Days, " dni");
   UpdatePanel();
}

//+------------------------------------------------------------------+
void SendSignal(string event, ulong ticket, string symbol,
                int posType, double lots, double entry,
                double sl, double tp,
                double closePrice, double profit) {

   string direction = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";

   string tf = "";
   switch (Period()) {
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
   json += "\"mt4_account\":"  + IntegerToString(mt5AccountNumber) + ",";
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

   string logTag = "[" + event + "] " + symbol + " " + direction +
                   " tf=" + tf + " lot=" + DoubleToString(lots, 2) +
                   " ticket=#" + IntegerToString(ticket);
   SendJsonToApi(json, logTag);
}

//+------------------------------------------------------------------+
void SendJsonToApi(string json, string logTag) {
   string headers = "Content-Type: application/json\r\n";
   headers += "apikey: "                + AnonKey + "\r\n";
   headers += "Authorization: Bearer "  + AnonKey + "\r\n";
   headers += "Prefer: return=minimal\r\n";

   char   post[], result[];
   string resultHeaders;
   ArrayResize(post, StringToCharArray(json, post, 0, WHOLE_ARRAY, CP_UTF8) - 1);

   int res = WebRequest("POST",
                        ApiUrl + "/rest/v1/mt4_signals",
                        headers, 5000, post, result, resultHeaders);

   if (res == 201 || res == 200) {
      Print("TLJ ", logTag);
   } else {
      Print("TLJ Błąd HTTP ", res, " ", logTag, " | ", CharArrayToString(result));
   }
}

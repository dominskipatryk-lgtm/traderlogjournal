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

// --- Piramidowanie ---
input bool     AutoPyramid        = false;    // Auto-piramidowanie gdy pozycja na +X pips
input double   PyramidPips        = 20.0;     // Zysk (pips) do aktywacji kolejnej dokładki
input int      PyramidMaxLevels   = 2;        // Maks. liczba dokładek per pozycja
input double   PyramidRiskPct     = 0.5;      // Ryzyko % dokładki (0 = użyj pola Ryzyko %)
input bool     PyramidMoveSL      = true;     // Przesuń SL poprzedniej pozycji na BE po dokładce
input int      PyramidDivisions   = 4;        // Faron Mode: podziel odcinek Entry→TP na N równych części (0 = wyłącz, użyj PyramidPips)

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
#define EDIT_TP       "TLJ_EditTP"
#define LBL_STATUS    "TLJ_Status"
#define LBL_COUNT     "TLJ_Count"
#define LBL_TITLE     "TLJ_Title"
#define LBL_ACCOUNT   "TLJ_Account"
#define LBL_EQUITY    "TLJ_Equity"
#define LBL_LOT       "TLJ_LblLot"
#define BTN_ADD_BUY   "TLJ_BtnAddBuy"
#define BTN_ADD_SEL   "TLJ_BtnAddSel"
#define BTN_PYRAMID   "TLJ_BtnPyramid"
#define BTN_SIATKA    "TLJ_BtnSiatka"
#define EDIT_GRID_N   "TLJ_EGN"
#define EDIT_PYR_MAX  "TLJ_EditPyrMax"

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
bool       _paused             = false;
bool       _autoPyramidEnabled = false;
bool       _siatkaEnabled      = false;
int        _sentCount          = 0;
double     _prevBalance        = 0;
long       _gridOpenTickets[];
bool       _gridInitialized    = false;

//+------------------------------------------------------------------+
int OnInit() {
   if (UserId == "") {
      Alert("TraderLogJournal: Wklej swój User ID w parametrach EA!\n"
            "Ustawienia → Integracja z MT4 → Kopiuj User ID");
      return INIT_FAILED;
   }
   mt4AccountNumber    = AccountInfoInteger(ACCOUNT_LOGIN);
   _prevBalance        = AccountBalance();
   _autoPyramidEnabled = AutoPyramid;
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
   if (!_paused) {
      CheckTradeChanges();
      CheckAutoPyramid();
      CheckGridFills();
   }
   UpdatePanel();
}

//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam,
                  const double& dparam, const string& sparam) {

   if (id == CHARTEVENT_OBJECT_CLICK) {
      if (sparam == BTN_BUY) {
         if (_siatkaEnabled) PlaceGrid(OP_BUY);
         else                OpenOrder(OP_BUY);
         ObjectSetInteger(0, BTN_BUY, OBJPROP_STATE, false);
      }
      else if (sparam == BTN_SELL) {
         if (_siatkaEnabled) PlaceGrid(OP_SELL);
         else                OpenOrder(OP_SELL);
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
      else if (sparam == BTN_SIATKA) {
         _siatkaEnabled = !_siatkaEnabled;
         ObjectSetInteger(0, BTN_SIATKA, OBJPROP_STATE, false);
         UpdatePanel();
      }
      else if (sparam == BTN_ADD_BUY) {
         OpenPyramidOrder(OP_BUY);
         ObjectSetInteger(0, BTN_ADD_BUY, OBJPROP_STATE, false);
      }
      else if (sparam == BTN_ADD_SEL) {
         OpenPyramidOrder(OP_SELL);
         ObjectSetInteger(0, BTN_ADD_SEL, OBJPROP_STATE, false);
      }
      else if (sparam == BTN_PYRAMID) {
         _autoPyramidEnabled = !_autoPyramidEnabled;
         ObjectSetInteger(0, BTN_PYRAMID, OBJPROP_STATE, false);
         UpdatePanel();
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
   int w = 222, h = 380;
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
   CreateEdit(EDIT_SL,   x+100, y+158, 50, 16, DoubleToString(DefaultSLPips, 1));

   CreateLabel("TLJ_TPLbl", x+10, y+182, "TP (pips)", C'150,170,185', 8, false);
   CreateEdit(EDIT_TP,   x+100, y+178, 50, 16, "0.0");

   CreateLabel("TLJ_LotLbl", x+10, y+202, "Lot:",    C'150,170,185', 8, false);
   CreateLabel(LBL_LOT,       x+40, y+202, "—",       C'0,212,161',   9, true);

   CreateButton(BTN_CALC, x+158, y+197, 56, 18, "Oblicz",
                C'25,45,65', C'100,160,220', C'45,80,120', 8);

   CreateSep("TLJ_L3", x+8, y+218, w-16);

   // SIATKA FARON MODE — toggle + pole N
   CreateLabel("TLJ_GNLbl", x+8, y+230, "N:", C'150,170,185', 8, false);
   CreateEdit(EDIT_GRID_N,   x+22, y+225, 28, 16, "4");
   CreateButton(BTN_SIATKA,  x+56, y+222, 158, 22, "SIATKA:WYŁ",
                C'25,35,48', C'74,96,117', C'45,63,80', 7);

   // BUY / SELL
   CreateButton(BTN_BUY,  x+8,   y+251, 100, 26, "BUY",
                C'0,130,80',  clrWhite, C'0,180,110', 10);
   CreateButton(BTN_SELL, x+114, y+251, 100, 26, "SELL",
                C'160,30,40', clrWhite, C'200,50,60', 10);

   // PIRAMIDOWANIE AUTO — ADD ręczny + Max + toggle
   CreateButton(BTN_ADD_BUY, x+8,  y+281, 58, 22, "+ADD BUY",
                C'0,70,50',  C'0,210,155', C'0,110,75', 7);
   CreateButton(BTN_ADD_SEL, x+70, y+281, 58, 22, "+ADD SELL",
                C'90,15,25', C'255,110,120', C'150,35,45', 7);
   CreateLabel("TLJ_MxLbl",  x+132, y+290, "Mx:", C'74,96,117', 7, false);
   CreateEdit(EDIT_PYR_MAX,  x+150, y+282, 22, 16, IntegerToString(PyramidMaxLevels));
   CreateButton(BTN_PYRAMID, x+176, y+281, 38, 22, "PIRA",
                C'25,35,48',  C'74,96,117', C'45,63,80', 7);

   // Close buttons
   CreateButton(BTN_CLOSE_ALL, x+8,   y+307, 66, 18, "Close ALL",
                C'50,20,20', C'255,100,100', C'100,40,40', 7);
   CreateButton(BTN_CLOSE_BUY, x+78,  y+307, 66, 18, "Close BUY",
                C'20,50,30', C'80,200,120',  C'40,100,60', 7);
   CreateButton(BTN_CLOSE_SEL, x+148, y+307, 66, 18, "Close SELL",
                C'50,20,20', C'255,80,80',   C'100,40,40', 7);

   CreateSep("TLJ_L4", x+8, y+329, w-16);

   // Pauza / Stop
   CreateButton(BTN_PAUSE, x+8,   y+335, 100, 22, "⏸  Pauza",
                C'30,45,61', C'122,139,153', C'45,63,80', 8);
   CreateButton(BTN_STOP,  x+114, y+335, 100, 22, "⏹  Stop EA",
                C'61,26,26', C'255,71,87',   C'93,40,40', 8);

   CreateLabel("TLJ_Link", x+10, y+363, "traderlogjournal.com", C'45,63,80', 7, false);

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

   // Przycisk SIATKA — status trybu siatki (Faron Mode)
   if (_siatkaEnabled) {
      int gridPending = 0;
      for (int i = 0; i < OrdersTotal(); i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
         if (OrderType() > 1 && StringFind(OrderComment(), "TLJ_GRID") >= 0) gridPending++;
      }
      string siatkaTxt = "SIATKA:WŁ " + IntegerToString(gridPending) + "p";
      ObjectSetString (0, BTN_SIATKA, OBJPROP_TEXT,   siatkaTxt);
      ObjectSetInteger(0, BTN_SIATKA, OBJPROP_BGCOLOR, C'0,70,50');
      ObjectSetInteger(0, BTN_SIATKA, OBJPROP_COLOR,   C'0,210,155');
      ObjectSetString (0, BTN_BUY,  OBJPROP_TEXT, "GRID BUY");
      ObjectSetString (0, BTN_SELL, OBJPROP_TEXT, "GRID SELL");
   } else {
      ObjectSetString (0, BTN_SIATKA, OBJPROP_TEXT,   "SIATKA:WYŁ");
      ObjectSetInteger(0, BTN_SIATKA, OBJPROP_BGCOLOR, C'25,35,48');
      ObjectSetInteger(0, BTN_SIATKA, OBJPROP_COLOR,   C'74,96,117');
      ObjectSetString (0, BTN_BUY,  OBJPROP_TEXT, "BUY");
      ObjectSetString (0, BTN_SELL, OBJPROP_TEXT, "SELL");
   }

   // Przycisk PIRA — status auto-piramidowania
   if (_autoPyramidEnabled) {
      int pyrTotal = 0;
      for (int i = 0; i < OrdersTotal(); i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
         if (StringFind(OrderComment(), "TLJ_PYR") >= 0) pyrTotal++;
      }
      string pyrTxt = "PIRA:WŁ " + IntegerToString(pyrTotal) + "x";
      ObjectSetString (0, BTN_PYRAMID, OBJPROP_TEXT,   pyrTxt);
      ObjectSetInteger(0, BTN_PYRAMID, OBJPROP_BGCOLOR, C'0,80,60');
      ObjectSetInteger(0, BTN_PYRAMID, OBJPROP_COLOR,   C'0,210,155');
   } else {
      ObjectSetString (0, BTN_PYRAMID, OBJPROP_TEXT,   "PIRA:WYŁ");
      ObjectSetInteger(0, BTN_PYRAMID, OBJPROP_BGCOLOR, C'25,35,48');
      ObjectSetInteger(0, BTN_PYRAMID, OBJPROP_COLOR,   C'74,96,117');
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
void DeletePanel() {
   string objs[] = {
      PANEL_NAME, BTN_STOP, BTN_PAUSE, BTN_BUY, BTN_SELL,
      BTN_ADD_BUY, BTN_ADD_SEL, BTN_PYRAMID,
      BTN_SIATKA, EDIT_GRID_N,
      BTN_CLOSE_ALL, BTN_CLOSE_BUY, BTN_CLOSE_SEL, BTN_CALC,
      EDIT_RISK, EDIT_SL, EDIT_TP, EDIT_PYR_MAX, LBL_LOT,
      LBL_STATUS, LBL_COUNT, LBL_TITLE, LBL_ACCOUNT, LBL_EQUITY,
      "TLJ_Sub", "TLJ_Ver", "TLJ_L1", "TLJ_L2", "TLJ_L3", "TLJ_L4",
      "TLJ_K1", "TLJ_K2", "TLJ_K3", "TLJ_K4", "TLJ_K5",
      "TLJ_PnL", "TLJ_Sent", "TLJ_Link",
      "TLJ_CalcHdr", "TLJ_RLbl", "TLJ_SLbl", "TLJ_TPLbl", "TLJ_LotLbl",
      "TLJ_GNLbl", "TLJ_MxLbl"
   };
   for (int i = 0; i < ArraySize(objs); i++) ObjectDelete(0, objs[i]);
   ChartRedraw();
}

//+------------------------------------------------------------------+
// Auto-wykrywanie rozmiaru pipsa dla KAŻDEGO instrumentu:
//   Nieparzyste digits (5,3,1) = broker fractional pip → ×10
//   Parzyste digits + metal (XAU/XAG/XPT/XPD) = 2-decimal metals → ×10
//   Wszystko inne (4-digit forex, 2-digit JPY, indeksy, ropa, krypto) → point
//+------------------------------------------------------------------+
double GetPipSize(string sym) {
   double pt = MarketInfo(sym, MODE_POINT);
   int    dg = (int)MarketInfo(sym, MODE_DIGITS);

   // Nieparzyste cyfry po przecinku = broker ułamkowy pip (5d forex, 3d JPY, 1d indeksy)
   if (dg % 2 == 1) return pt * 10.0;

   // Parzyste cyfry: metale szlachetne z 2 miejscami dziesiętnymi (np. XAUUSD 1850.45)
   // Na tych instrumentach 1 pip konwencjonalnie = 10 punktów
   if (dg == 2) {
      string u = sym;
      StringToUpper(u);
      if (StringFind(u, "XAU")  >= 0 || StringFind(u, "XAG")  >= 0 ||
          StringFind(u, "XPT")  >= 0 || StringFind(u, "XPD")  >= 0 ||
          StringFind(u, "GOLD") >= 0 || StringFind(u, "SILVER") >= 0)
         return pt * 10.0;
   }

   // Wszystko inne: punkt = pip (4-digit forex, 2-digit JPY, 0/2-digit indeksy, ropa, krypto)
   return pt;
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
   double pipSz    = GetPipSize(Symbol());
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
   double lot    = CalcLot(riskPct, slPips);
   double tpPips = StringToDouble(ObjectGetString(0, EDIT_TP, OBJPROP_TEXT));
   string lotTxt = lot > 0 ? DoubleToString(lot, 2) : "—";
   if (lot > 0 && tpPips > 0 && slPips > 0) {
      double rr = tpPips / slPips;
      lotTxt += "  R:R 1:" + DoubleToString(rr, 1);
   }
   ObjectSetString(0, LBL_LOT, OBJPROP_TEXT, lotTxt);
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

   int    digits = (int)MarketInfo(Symbol(), MODE_DIGITS);
   double pipSz  = GetPipSize(Symbol());
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
// PIRAMIDOWANIE — HELPER: przesuń SL na break-even
//+------------------------------------------------------------------+
bool MoveSLtoBreakEven(long ticket) {
   if (!OrderSelect((int)ticket, SELECT_BY_TICKET, MODE_TRADES)) return false;
   if (OrderCloseTime() != 0) return false;

   double bePrice = OrderOpenPrice();
   double curSL   = OrderStopLoss();
   int    digits  = (int)MarketInfo(OrderSymbol(), MODE_DIGITS);

   // Nie ruszaj jeśli SL już jest na BE lub lepiej
   if (OrderType() == OP_BUY  && curSL >= bePrice) return false;
   if (OrderType() == OP_SELL && curSL <= bePrice && curSL > 0) return false;

   bool ok = OrderModify((int)ticket, OrderOpenPrice(),
                          NormalizeDouble(bePrice, digits),
                          OrderTakeProfit(), 0, clrGold);
   if (ok)
      Print("TLJ [BE] ticket=#", ticket, " SL → ", DoubleToString(bePrice, digits));
   else
      Print("TLJ [BE] Błąd ModifySL ticket=#", ticket, " err=", GetLastError());
   return ok;
}

// Znajdź ticket ostatniej otwartej pozycji w danym kierunku (poza excludeTicket)
long FindPrevOrder(int dir, long excludeTicket) {
   long     best     = 0;
   datetime bestTime = 0;
   for (int i = 0; i < OrdersTotal(); i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderType() != dir)                           continue;
      if (OrderMagicNumber() != MagicNumber)            continue;
      if (OrderTicket() == excludeTicket)               continue;
      if (OrderOpenTime() > bestTime) {
         bestTime = OrderOpenTime();
         best     = OrderTicket();
      }
   }
   return best;
}

//+------------------------------------------------------------------+
// SIATKA — wykrywanie wypełnionych LIMIT-ów i przesunięcie SL na BE
//+------------------------------------------------------------------+
int GridLevelFromComment(string comment) {
   // "TLJ_GRID_2of3" → 2; zwraca 0 jeśli nie pasuje
   int pos = StringFind(comment, "TLJ_GRID_");
   if (pos < 0) return 0;
   string rest = StringSubstr(comment, pos + 9);
   int ofPos = StringFind(rest, "of");
   if (ofPos > 0) return (int)StringToInteger(StringSubstr(rest, 0, ofPos));
   return (int)StringToInteger(rest);
}

// Zwraca ticket pozycji siatki o poziomie (targetLevel - 1).
// Szukamy po numerze w komentarzu, NIE po czasie — wszystkie zlecenia
// siatki mają ten sam OrderOpenTime() bo zostały złożone w jednej pętli.
long FindPrevGridOrder(int dir, int targetLevel) {
   for (int i = 0; i < OrdersTotal(); i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderType() != dir)                           continue;
      if (OrderMagicNumber() != MagicNumber)            continue;
      if (GridLevelFromComment(OrderComment()) == targetLevel - 1) return OrderTicket();
   }
   return 0;
}

void CheckGridFills() {
   // Zbierz aktualnie otwarte pozycje siatki (type OP_BUY / OP_SELL, nie pending)
   long currentOpen[];
   ArrayResize(currentOpen, 0);
   for (int i = 0; i < OrdersTotal(); i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderType() > 1)                              continue; // pomijaj pending
      if (OrderMagicNumber() != MagicNumber)            continue;
      if (StringFind(OrderComment(), "TLJ_GRID_") < 0) continue;
      int sz = ArraySize(currentOpen);
      ArrayResize(currentOpen, sz + 1);
      currentOpen[sz] = OrderTicket();
   }

   // Przy pierwszym wywołaniu tylko inicjalizujemy stan — nie robimy BE
   if (!_gridInitialized) {
      ArrayCopy(_gridOpenTickets, currentOpen);
      _gridInitialized = true;
      return;
   }

   // Wykryj zamknięte pozycje siatki (były w _gridOpenTickets, nie ma w currentOpen)
   bool anyClosed = false;
   for (int k = 0; k < ArraySize(_gridOpenTickets); k++) {
      bool stillOpen = false;
      for (int j = 0; j < ArraySize(currentOpen); j++) {
         if (_gridOpenTickets[k] == currentOpen[j]) { stillOpen = true; break; }
      }
      if (!stillOpen) { anyClosed = true; break; }
   }
   if (anyClosed) {
      int deleted = 0;
      for (int i = OrdersTotal() - 1; i >= 0; i--) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
         if (OrderType() < 2)                              continue;
         if (OrderMagicNumber() != MagicNumber)            continue;
         if (StringFind(OrderComment(), "TLJ_GRID_") < 0) continue;
         if (OrderDelete(OrderTicket())) deleted++;
      }
      if (deleted > 0)
         Print("TLJ [GRID SL] Pozycja siatki zamknięta → skasowano ", deleted, " pending orders");
      _gridInitialized = false;
   }

   // Wykryj nowo wypełnione (są w currentOpen, nie ma w _gridOpenTickets)
   for (int j = 0; j < ArraySize(currentOpen); j++) {
      bool isNew = true;
      for (int k = 0; k < ArraySize(_gridOpenTickets); k++) {
         if (_gridOpenTickets[k] == currentOpen[j]) { isNew = false; break; }
      }
      if (!isNew) continue;

      // Nowe wypełnienie — przesuń SL poprzedniej pozycji siatki na BE
      if (!OrderSelect((int)currentOpen[j], SELECT_BY_TICKET, MODE_TRADES)) continue;
      int myLevel = GridLevelFromComment(OrderComment());
      int myType  = OrderType();

      if (myLevel <= 1) continue;

      // Wspólny SL = entry poprzedniej pozycji → przesuń WSZYSTKIE otwarte TLJ_GRID_*
      long prevTicket = FindPrevGridOrder(myType, myLevel);
      if (prevTicket > 0 && OrderSelect((int)prevTicket, SELECT_BY_TICKET, MODE_TRADES)) {
         double commonSL = OrderOpenPrice();
         int    digits   = (int)MarketInfo(Symbol(), MODE_DIGITS);
         int    cnt      = 0;
         for (int m = 0; m < OrdersTotal(); m++) {
            if (!OrderSelect(m, SELECT_BY_POS, MODE_TRADES))  continue;
            if (OrderType() != myType)                         continue;
            if (OrderMagicNumber() != MagicNumber)             continue;
            if (StringFind(OrderComment(), "TLJ_GRID_") < 0)  continue;
            if (MathAbs(OrderStopLoss() - commonSL) < Point)  continue;
            if (OrderModify(OrderTicket(), OrderOpenPrice(), commonSL, OrderTakeProfit(), 0, clrNone)) cnt++;
         }
         Print("TLJ [GRID FILL] Poziom ", myLevel, " → wspólny SL=",
               DoubleToString(commonSL, digits), " (przesunięto ", cnt, " SL)");
      }
   }

   ArrayCopy(_gridOpenTickets, currentOpen);
}

//+------------------------------------------------------------------+
// SIATKA ZLECEŃ
// Pierwsze zlecenie: market (BUY/SELL), kolejne N-1: STOP w kierunku transakcji (Faron Mode).
// TP i SL to stałe poziomy cenowe obliczone od entry 1.
// Faron Mode: równe loty (slPips). Gdy N-ta wchodzi → WSZYSTKIE SL → entry (N-1).
//+------------------------------------------------------------------+
void PlaceGrid(int direction) {
   double riskPct = StringToDouble(ObjectGetString(0, EDIT_RISK,   OBJPROP_TEXT));
   double slPips  = StringToDouble(ObjectGetString(0, EDIT_SL,     OBJPROP_TEXT));
   double tpPips  = StringToDouble(ObjectGetString(0, EDIT_TP,     OBJPROP_TEXT));
   int    n       = (int)StringToInteger(ObjectGetString(0, EDIT_GRID_N, OBJPROP_TEXT));

   if (n < 2 || n > 10)             { Alert("TLJ Siatka: N musi być 2–10");         return; }
   if (tpPips <= 0)                  { Alert("TLJ Siatka: Wpisz TP w kalkulatorze"); return; }
   if (riskPct <= 0 || slPips <= 0) { Alert("TLJ Siatka: Ustaw Ryzyko% i SL");      return; }

   // Krok = TP ÷ N (przestrzeń Entry→TP dzielona na N równych części)
   double stepPips = tpPips / n;

   double lstep  = MarketInfo(Symbol(), MODE_LOTSTEP);
   double lmin   = MarketInfo(Symbol(), MODE_MINLOT);
   double lmax   = MarketInfo(Symbol(), MODE_MAXLOT);

   int    digits = (int)MarketInfo(Symbol(), MODE_DIGITS);
   double pipSz  = GetPipSize(Symbol());

   double basePrice, tp;
   if (direction == OP_BUY) {
      basePrice = NormalizeDouble(Ask, digits);
      tp = NormalizeDouble(basePrice + tpPips * pipSz, digits);
   } else {
      basePrice = NormalizeDouble(Bid, digits);
      tp = NormalizeDouble(basePrice - tpPips * pipSz, digits);
   }

   int placed = 0;
   for (int i = 0; i < n; i++) {
      double entryPrice = 0, sl = 0, lot = 0;
      int    orderType  = 0;

      // Faron Mode (wg Pawła): #1 → pełny SL; #2+ → SL = wejście poprzedniego (= 1 krok = BE #prev)
      if (direction == OP_BUY) {
         entryPrice = NormalizeDouble(basePrice + i * stepPips * pipSz, digits);
         orderType  = (i == 0) ? OP_BUY : OP_BUYSTOP;
         sl = (i == 0) ? NormalizeDouble(entryPrice - slPips   * pipSz, digits)
                       : NormalizeDouble(entryPrice - stepPips * pipSz, digits);
      } else {
         entryPrice = NormalizeDouble(basePrice - i * stepPips * pipSz, digits);
         orderType  = (i == 0) ? OP_SELL : OP_SELLSTOP;
         sl = (i == 0) ? NormalizeDouble(entryPrice + slPips   * pipSz, digits)
                       : NormalizeDouble(entryPrice + stepPips * pipSz, digits);
      }
      // Równy lot dla wszystkich wg kroku — gwarantuje zero po #3 i zysk po #4+
      lot = MathFloor(CalcLot(riskPct, stepPips) / lstep) * lstep;
      lot = MathMax(lmin, MathMin(lmax, lot));

      string comment = "TLJ_GRID_" + IntegerToString(i + 1) + "of" + IntegerToString(n);
      int ticket = OrderSend(Symbol(), orderType, lot, entryPrice, 3,
                             sl, tp, comment, MagicNumber, 0,
                             direction == OP_BUY ? clrLime : clrRed);
      if (ticket < 0) {
         int err = GetLastError();
         Print("TLJ [GRID] zlecenie #", i+1, " błąd err=", err);
         Alert("TLJ Siatka: Błąd zlecenia #", i+1, " (kod: ", err,
               "). Postawiono: ", placed, "/", n);
         return;
      }
      placed++;
      Print("TLJ [GRID] #", i+1, " ", (orderType==OP_BUY?"BUY":(orderType==OP_SELL?"SELL":
            orderType==OP_BUYSTOP?"BUY_STOP":"SELL_STOP")),
            " entry=", DoubleToString(entryPrice, digits),
            " sl=", DoubleToString(sl, digits), " tp=", DoubleToString(tp, digits),
            " lot=", DoubleToString(lot, 2), " ticket=", ticket);
   }

   Print("TLJ [GRID] Gotowe: ", placed, " zleceń (Faron Mode — każde 1% ryzyka niezależnie)");
}

//+------------------------------------------------------------------+
// PIRAMIDOWANIE — MANUALNE
//+------------------------------------------------------------------+
void OpenPyramidOrder(int orderType) {
   double riskPct = PyramidRiskPct > 0 ? PyramidRiskPct
                    : StringToDouble(ObjectGetString(0, EDIT_RISK, OBJPROP_TEXT));
   double slPips  = StringToDouble(ObjectGetString(0, EDIT_SL, OBJPROP_TEXT));
   if (riskPct <= 0 || slPips <= 0) {
      Alert("TLJ: Wpisz poprawne Ryzyko % i SL pips!");
      return;
   }
   double lot = CalcLot(riskPct, slPips);
   if (lot <= 0) { Alert("TLJ: Błąd kalkulacji lota!"); return; }

   int    digits = (int)MarketInfo(Symbol(), MODE_DIGITS);
   double pipSz  = GetPipSize(Symbol());
   double price, sl;

   if (orderType == OP_BUY) {
      price = NormalizeDouble(Ask, digits);
      sl    = NormalizeDouble(Ask - slPips * pipSz, digits);
   } else {
      price = NormalizeDouble(Bid, digits);
      sl    = NormalizeDouble(Bid + slPips * pipSz, digits);
   }

   int ticket = OrderSend(Symbol(), orderType, lot, price, 3, sl, 0,
                          "TLJ Panel+", MagicNumber, 0,
                          orderType == OP_BUY ? clrLime : clrRed);
   if (ticket < 0) {
      int err = GetLastError();
      Print("TLJ [ADD]: Błąd err=", err);
      Alert("TLJ: Błąd dodawania pozycji (kod: ", err, ")");
   } else {
      Print("TLJ [ADD ", (orderType == OP_BUY ? "BUY" : "SELL"), "]",
            " lot=", lot, " sl=", sl, " ticket=", ticket);
      // Przesuń SL poprzedniej pozycji na BE
      if (PyramidMoveSL) {
         long prev = FindPrevOrder(orderType, (long)ticket);
         if (prev > 0) MoveSLtoBreakEven(prev);
      }
   }
}

//+------------------------------------------------------------------+
// PIRAMIDOWANIE — AUTOMATYCZNE
// Logika: dla każdej oryginalnej pozycji (bez tagu TLJ_PYR),
// gdy zysk >= (level+1)*PyramidPips, otwiera dokładkę z tagiem
// "TLJ_PYR_<parentTicket>_L<level>" i ryzykiem PyramidRiskPct%.
//+------------------------------------------------------------------+
void CheckAutoPyramid() {
   if (!_autoPyramidEnabled) return;

   int total = OrdersTotal();
   for (int i = 0; i < total; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderMagicNumber() != MagicNumber) continue;
      if (OrderType() > 1) continue;
      if (StringFind(OrderComment(), "TLJ_PYR") >= 0) continue;

      long   ticket   = OrderTicket();
      int    dir      = OrderType();
      string sym      = OrderSymbol();
      double entry    = OrderOpenPrice();
      double parentSL = OrderStopLoss();
      double parentTP = OrderTakeProfit();

      int    digits = (int)MarketInfo(sym, MODE_DIGITS);
      double pipSz  = GetPipSize(sym);

      double profitPips;
      if (dir == OP_BUY)
         profitPips = (MarketInfo(sym, MODE_BID) - entry) / pipSz;
      else
         profitPips = (entry - MarketInfo(sym, MODE_ASK)) / pipSz;

      // Zlicz istniejące dokładki dla tego ticketu
      string tag      = "TLJ_PYR_" + IntegerToString(ticket);
      int    pyrCount = 0;
      for (int j = 0; j < OrdersTotal(); j++) {
         if (!OrderSelect(j, SELECT_BY_POS, MODE_TRADES)) continue;
         if (StringFind(OrderComment(), tag) >= 0) pyrCount++;
      }

      int maxLevels = (int)StringToInteger(ObjectGetString(0, EDIT_PYR_MAX, OBJPROP_TEXT));
      if (maxLevels <= 0) maxLevels = PyramidMaxLevels;
      if (pyrCount >= maxLevels) continue;

      // --- Faron Mode: krok = (TP - entry) / N ---
      // Fallback na PyramidPips gdy brak TP lub PyramidDivisions <= 0
      double stepPips;
      if (PyramidDivisions >= 2 && parentTP > 0) {
         double tpDist = MathAbs(parentTP - entry) / pipSz;
         stepPips = tpDist / PyramidDivisions;
         if (stepPips < 1.0) stepPips = PyramidPips; // zabezpieczenie przed zerowaniem
      } else {
         stepPips = PyramidPips;
      }

      double threshold = (pyrCount + 1.0) * stepPips;
      if (profitPips < threshold) continue;

      double riskPct = PyramidRiskPct > 0 ? PyramidRiskPct
                       : StringToDouble(ObjectGetString(0, EDIT_RISK, OBJPROP_TEXT));
      // SL dokładki = 1 interval (Faron Mode) lub SL parenta jako fallback
      double slPips = (PyramidDivisions >= 2 && parentTP > 0)
                      ? stepPips
                      : ((parentSL > 0) ? MathAbs(entry - parentSL) / pipSz : DefaultSLPips);
      if (slPips <= 0) slPips = DefaultSLPips;

      double lot = CalcLot(riskPct, slPips);
      if (lot <= 0) continue;

      double openPrice, newSL;
      if (dir == OP_BUY) {
         openPrice = NormalizeDouble(MarketInfo(sym, MODE_ASK), digits);
         newSL     = NormalizeDouble(openPrice - slPips * pipSz, digits);
      } else {
         openPrice = NormalizeDouble(MarketInfo(sym, MODE_BID), digits);
         newSL     = NormalizeDouble(openPrice + slPips * pipSz, digits);
      }

      string comment = tag + "_L" + IntegerToString(pyrCount + 1);
      int newTicket = OrderSend(sym, dir, lot, openPrice, 3, newSL, 0,
                                comment, MagicNumber, 0,
                                dir == OP_BUY ? clrLime : clrRed);
      if (newTicket > 0) {
         Print("TLJ [PYRAMID L", pyrCount + 1, "] parent=#", ticket,
               " new=#", newTicket, " lot=", lot,
               " zysk=", DoubleToString(profitPips, 1), " pips");
         // Przesuń SL poprzedniej pozycji na BE (Faron Mode)
         if (PyramidMoveSL) {
            long prevTicket = ticket; // domyślnie parent
            if (pyrCount > 0) {
               // Szukaj L{pyrCount} — ostatnia dokładka przed obecną
               string prevTag = tag + "_L" + IntegerToString(pyrCount);
               for (int k = 0; k < OrdersTotal(); k++) {
                  if (!OrderSelect(k, SELECT_BY_POS, MODE_TRADES)) continue;
                  if (StringFind(OrderComment(), prevTag) >= 0) {
                     prevTicket = OrderTicket();
                     break;
                  }
               }
            }
            MoveSLtoBreakEven(prevTicket);
         }
      } else
         Print("TLJ [PYRAMID] Błąd err=", GetLastError(), " parent=#", ticket);
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
   int    total     = OrdersTotal();
   double closedPnL = 0.0;

   // — Nowe otwarcia i modyfikacje —
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

   // — Zamknięcia — zbieramy też łączny P&L zamkniętych trans. —
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
            closedPnL += NormalizeDouble(OrderProfit() + OrderCommission() + OrderSwap(), 2);
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

   // — Wykryj wpłatę / wypłatę —
   // Odejmujemy P&L zamkniętych trans. od zmiany salda — zostaje tylko
   // rzeczywista wpłata lub wypłata (nie fałszywy sygnał po zamknięciu pozycji).
   double curBalance      = AccountBalance();
   double balanceDiff     = NormalizeDouble(curBalance - _prevBalance, 2);
   double unexplainedDiff = NormalizeDouble(balanceDiff - closedPnL, 2);
   if (MathAbs(unexplainedDiff) >= 0.01) {
      string balType = unexplainedDiff > 0 ? "DEPOSIT" : "WITHDRAWAL";
      SendBalanceSignal(balType, unexplainedDiff);
      _sentCount++;
   }
   _prevBalance = curBalance;
}

void SendBalanceSignal(string balType, double amount) {
   string j = "{";
   j += "\"user_id\":\""   + UserId                            + "\",";
   j += "\"mt4_account\":" + IntegerToString(mt4AccountNumber) + ",";
   j += "\"event\":\""     + balType                           + "\",";
   j += "\"symbol\":\"BALANCE\",";
   j += "\"direction\":\"LONG\",";
   j += "\"profit\":"      + DoubleToString(amount, 2)         + ",";
   j += "\"commission\":0,\"swap\":0,\"entry\":0,\"sl\":0,\"tp\":0,";
   j += "\"size\":0,\"close_price\":0,\"ticket\":0,";
   j += "\"open_time\":\"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\",";
   j += "\"processed\":false}";
   HttpPost(ApiUrl + "/rest/v1/mt4_signals", BuildHeaders(false), j);
   Print("TLJ [", balType, "] kwota=", amount, " nowe saldo=", AccountBalance());
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

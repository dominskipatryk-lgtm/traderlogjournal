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
input bool     VirtualSLTP        = false;    // Ukryj SL/TP przed brokerem (stealth mode)

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
#define EDIT_GRID_N      "TLJ_EGN"
#define EDIT_PYR_MAX     "TLJ_EditPyrMax"
#define EDIT_PYR_STP     "TLJ_EditPyrStp"
#define BTN_SIATKA_HDR   "TLJ_SiatkaHdr"
#define BTN_SIATKA_ONOFF "TLJ_SiatkaOnOff"
#define BTN_GRID_BUY     "TLJ_BtnGridBuy"
#define BTN_GRID_SEL     "TLJ_BtnGridSel"
#define BTN_PIRA_HDR     "TLJ_PiraHdr"
#define BTN_PIRA_ONOFF   "TLJ_PiraOnOff"
#define BTN_PIRA_MODE    "TLJ_PiraMode"
#define EDIT_PYR_RISK    "TLJ_EditPyrRisk"
#define EDIT_PYR_LOT     "TLJ_EditPyrLot"
#define BTN_ATT_BUY      "TLJ_BtnAttBuy"
#define BTN_ATT_SEL      "TLJ_BtnAttSel"
#define BTN_MINIMIZE     "TLJ_BtnMin"
#define BTN_ADD_LVL      "TLJ_BtnAddLvl"
#define BTN_DEL_LVL      "TLJ_BtnDelLvl"
#define BTN_GRID_MAN_BUY "TLJ_BtnGMBuy"
#define BTN_GRID_MAN_SEL "TLJ_BtnGMSel"
#define LBL_LVL_COUNT    "TLJ_LblLvlCnt"
#define GRID_LINE_PREFIX "TLJ_GL_"

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
long       mt4AccountNumber    = 0;
bool       _paused             = false;
bool       _autoPyramidEnabled = false;
bool       _siatkaEnabled      = false;
bool       _siatkaExpanded     = false;
bool       _piraExpanded       = false;
bool       _panelMinimized     = false;
bool       _piraModePct        = true;   // true = % konta, false = stały lot
int        _sentCount          = 0;
double     _prevBalance        = 0;
long       _gridOpenTickets[];
bool       _gridInitialized    = false;
long       _gridBaseTicket     = -1;  // ticket bazowej pozycji przy DOŁĄCZ
int        _gridLineCount      = 0;   // ile linii TLJ_GL_* aktualnie na wykresie

//+------------------------------------------------------------------+
// Klucze GlobalVariable — przeżywają zmianę interwału i restart MT4
string _gvPfx = "";
string GV(string key) { return _gvPfx + key; }

void SaveState() {
   GlobalVariableSet(GV("AutoPyr"),   _autoPyramidEnabled ? 1.0 : 0.0);
   GlobalVariableSet(GV("SiatkaEn"),  _siatkaEnabled      ? 1.0 : 0.0);
   GlobalVariableSet(GV("SiatkaExp"), _siatkaExpanded     ? 1.0 : 0.0);
   GlobalVariableSet(GV("PiraExp"),   _piraExpanded       ? 1.0 : 0.0);
   GlobalVariableSet(GV("PiraMode"),  _piraModePct        ? 1.0 : 0.0);
   GlobalVariableSet(GV("Paused"),    _paused             ? 1.0 : 0.0);
   GlobalVariableSet(GV("PanelMin"),  _panelMinimized     ? 1.0 : 0.0);
}

void LoadState() {
   if (GlobalVariableCheck(GV("AutoPyr")))   _autoPyramidEnabled = GlobalVariableGet(GV("AutoPyr"))   > 0.5;
   else                                       _autoPyramidEnabled = AutoPyramid;
   if (GlobalVariableCheck(GV("SiatkaEn")))  _siatkaEnabled      = GlobalVariableGet(GV("SiatkaEn"))  > 0.5;
   if (GlobalVariableCheck(GV("SiatkaExp"))) _siatkaExpanded     = GlobalVariableGet(GV("SiatkaExp")) > 0.5;
   if (GlobalVariableCheck(GV("PiraExp")))   _piraExpanded       = GlobalVariableGet(GV("PiraExp"))   > 0.5;
   if (GlobalVariableCheck(GV("PiraMode")))  _piraModePct        = GlobalVariableGet(GV("PiraMode"))  > 0.5;
   if (GlobalVariableCheck(GV("Paused")))    _paused             = GlobalVariableGet(GV("Paused"))    > 0.5;
   if (GlobalVariableCheck(GV("PanelMin"))) _panelMinimized     = GlobalVariableGet(GV("PanelMin"))  > 0.5;
}

//+------------------------------------------------------------------+
int OnInit() {
   if (UserId == "") {
      Alert("TraderLogJournal: Wklej swój User ID w parametrach EA!\n"
            "Ustawienia → Integracja z MT4 → Kopiuj User ID");
      return INIT_FAILED;
   }
   mt4AccountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
   _prevBalance     = AccountBalance();
   // Prefix unikalny per konto — wielu EA na jednym terminalu nie koliduje
   _gvPfx = "TLJ_" + IntegerToString(mt4AccountNumber) + "_";
   LoadState();
   _gridLineCount = CountGridLines();
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
   SaveState();
   DeletePanel();
}

//+------------------------------------------------------------------+
void OnTimer() {
   if (!_paused) {
      CheckTradeChanges();
      CheckVirtualLevels();
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
      else if (sparam == BTN_GRID_BUY) {
         PlaceGrid(OP_BUY);
         ObjectSetInteger(0, BTN_GRID_BUY, OBJPROP_STATE, false);
      }
      else if (sparam == BTN_GRID_SEL) {
         PlaceGrid(OP_SELL);
         ObjectSetInteger(0, BTN_GRID_SEL, OBJPROP_STATE, false);
      }
      else if (sparam == BTN_ATT_BUY) {
         AttachGridToExisting(OP_BUY);
         ObjectSetInteger(0, BTN_ATT_BUY, OBJPROP_STATE, false);
      }
      else if (sparam == BTN_ATT_SEL) {
         AttachGridToExisting(OP_SELL);
         ObjectSetInteger(0, BTN_ATT_SEL, OBJPROP_STATE, false);
      }
      else if (sparam == BTN_ADD_LVL) {
         AddGridLevel();
         ObjectSetInteger(0, BTN_ADD_LVL, OBJPROP_STATE, false);
      }
      else if (sparam == BTN_DEL_LVL) {
         RemoveLastGridLevel();
         ObjectSetInteger(0, BTN_DEL_LVL, OBJPROP_STATE, false);
      }
      else if (sparam == BTN_GRID_MAN_BUY) {
         PlaceGridFromLines(OP_BUY);
         ObjectSetInteger(0, BTN_GRID_MAN_BUY, OBJPROP_STATE, false);
      }
      else if (sparam == BTN_GRID_MAN_SEL) {
         PlaceGridFromLines(OP_SELL);
         ObjectSetInteger(0, BTN_GRID_MAN_SEL, OBJPROP_STATE, false);
      }
      else if (sparam == BTN_MINIMIZE) {
         if (!_panelMinimized) {
            // Przed minimalizacją — zapisz wartości kalkulatora do GV
            GlobalVariableSet(GV("cRisk"), StringToDouble(ObjectGetString(0, EDIT_RISK,     OBJPROP_TEXT)));
            GlobalVariableSet(GV("cSL"),   StringToDouble(ObjectGetString(0, EDIT_SL,       OBJPROP_TEXT)));
            GlobalVariableSet(GV("cTP"),   StringToDouble(ObjectGetString(0, EDIT_TP,       OBJPROP_TEXT)));
            GlobalVariableSet(GV("cN"),    StringToDouble(ObjectGetString(0, EDIT_GRID_N,   OBJPROP_TEXT)));
            GlobalVariableSet(GV("cPMax"), StringToDouble(ObjectGetString(0, EDIT_PYR_MAX,  OBJPROP_TEXT)));
            GlobalVariableSet(GV("cPStp"), StringToDouble(ObjectGetString(0, EDIT_PYR_STP,  OBJPROP_TEXT)));
            GlobalVariableSet(GV("cPRsk"), StringToDouble(ObjectGetString(0, EDIT_PYR_RISK, OBJPROP_TEXT)));
            GlobalVariableSet(GV("cPLot"), StringToDouble(ObjectGetString(0, EDIT_PYR_LOT,  OBJPROP_TEXT)));
         }
         _panelMinimized = !_panelMinimized;
         SaveState();
         RebuildPanel();
         // Po przywróceniu — wczytaj z GV z powrotem
         if (!_panelMinimized) {
            if (GlobalVariableCheck(GV("cRisk"))) ObjectSetString(0, EDIT_RISK,     OBJPROP_TEXT, DoubleToString(GlobalVariableGet(GV("cRisk")), 2));
            if (GlobalVariableCheck(GV("cSL")))   ObjectSetString(0, EDIT_SL,       OBJPROP_TEXT, DoubleToString(GlobalVariableGet(GV("cSL")),   1));
            if (GlobalVariableCheck(GV("cTP")))   ObjectSetString(0, EDIT_TP,       OBJPROP_TEXT, DoubleToString(GlobalVariableGet(GV("cTP")),   1));
            if (GlobalVariableCheck(GV("cN")))    ObjectSetString(0, EDIT_GRID_N,   OBJPROP_TEXT, DoubleToString(GlobalVariableGet(GV("cN")),    0));
            if (GlobalVariableCheck(GV("cPMax"))) ObjectSetString(0, EDIT_PYR_MAX,  OBJPROP_TEXT, DoubleToString(GlobalVariableGet(GV("cPMax")), 0));
            if (GlobalVariableCheck(GV("cPStp"))) ObjectSetString(0, EDIT_PYR_STP,  OBJPROP_TEXT, DoubleToString(GlobalVariableGet(GV("cPStp")), 1));
            if (GlobalVariableCheck(GV("cPRsk"))) ObjectSetString(0, EDIT_PYR_RISK, OBJPROP_TEXT, DoubleToString(GlobalVariableGet(GV("cPRsk")), 2));
            if (GlobalVariableCheck(GV("cPLot"))) ObjectSetString(0, EDIT_PYR_LOT,  OBJPROP_TEXT, DoubleToString(GlobalVariableGet(GV("cPLot")), 2));
            CalculateAndShowLot();
         }
      }
      else if (sparam == BTN_SIATKA_HDR) {
         _siatkaExpanded = !_siatkaExpanded;
         ObjectSetInteger(0, BTN_SIATKA_HDR, OBJPROP_STATE, false);
         SaveState();
         RebuildPanel();
      }
      else if (sparam == BTN_SIATKA_ONOFF) {
         _siatkaEnabled = !_siatkaEnabled;
         ObjectSetInteger(0, BTN_SIATKA_ONOFF, OBJPROP_STATE, false);
         SaveState();
         UpdatePanel();
      }
      else if (sparam == BTN_PIRA_HDR) {
         _piraExpanded = !_piraExpanded;
         ObjectSetInteger(0, BTN_PIRA_HDR, OBJPROP_STATE, false);
         SaveState();
         RebuildPanel();
      }
      else if (sparam == BTN_PIRA_ONOFF) {
         _autoPyramidEnabled = !_autoPyramidEnabled;
         ObjectSetInteger(0, BTN_PIRA_ONOFF, OBJPROP_STATE, false);
         SaveState();
         UpdatePanel();
      }
      else if (sparam == BTN_PIRA_MODE) {
         _piraModePct = !_piraModePct;
         ObjectSetInteger(0, BTN_PIRA_MODE, OBJPROP_STATE, false);
         SaveState();
         RebuildPanel();
      }
      else if (sparam == BTN_ADD_BUY) {
         OpenPyramidOrder(OP_BUY);
         ObjectSetInteger(0, BTN_ADD_BUY, OBJPROP_STATE, false);
      }
      else if (sparam == BTN_ADD_SEL) {
         OpenPyramidOrder(OP_SELL);
         ObjectSetInteger(0, BTN_ADD_SEL, OBJPROP_STATE, false);
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

   if (id == CHARTEVENT_OBJECT_ENDEDIT) {
      if (sparam == EDIT_RISK || sparam == EDIT_SL)
         CalculateAndShowLot();
      if (sparam == EDIT_TP)
         UpdateGridTP();
   }
}

//+------------------------------------------------------------------+
// PANEL
//+------------------------------------------------------------------+
void RebuildPanel() {
   string sRisk = ObjectGetString(0, EDIT_RISK,     OBJPROP_TEXT);
   string sSL   = ObjectGetString(0, EDIT_SL,       OBJPROP_TEXT);
   string sTP   = ObjectGetString(0, EDIT_TP,       OBJPROP_TEXT);
   string sN    = ObjectGetString(0, EDIT_GRID_N,   OBJPROP_TEXT);
   string sPMax = ObjectGetString(0, EDIT_PYR_MAX,  OBJPROP_TEXT);
   string sPStp = ObjectGetString(0, EDIT_PYR_STP,  OBJPROP_TEXT);
   string sPRsk = ObjectGetString(0, EDIT_PYR_RISK, OBJPROP_TEXT);
   string sPLot = ObjectGetString(0, EDIT_PYR_LOT,  OBJPROP_TEXT);

   DeletePanel();
   CreatePanel();

   if (sRisk != "") ObjectSetString(0, EDIT_RISK,     OBJPROP_TEXT, sRisk);
   if (sSL   != "") ObjectSetString(0, EDIT_SL,       OBJPROP_TEXT, sSL);
   if (sTP   != "") ObjectSetString(0, EDIT_TP,       OBJPROP_TEXT, sTP);
   if (sN    != "") ObjectSetString(0, EDIT_GRID_N,   OBJPROP_TEXT, sN);
   if (sPMax != "") ObjectSetString(0, EDIT_PYR_MAX,  OBJPROP_TEXT, sPMax);
   if (sPStp != "") ObjectSetString(0, EDIT_PYR_STP,  OBJPROP_TEXT, sPStp);
   if (sPRsk != "") ObjectSetString(0, EDIT_PYR_RISK, OBJPROP_TEXT, sPRsk);
   if (sPLot != "") ObjectSetString(0, EDIT_PYR_LOT,  OBJPROP_TEXT, sPLot);

   CalculateAndShowLot();
   UpdatePanel();
}

void CreatePanel() {
   int w = 222;
   int x = PanelX, y = PanelY;

   // ── TRYB ZMINIMALIZOWANY — tylko pasek tytułu ────────────────
   if (_panelMinimized) {
      ObjectCreate(0, PANEL_NAME, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_XDISTANCE,   x);
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_YDISTANCE,   y);
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_XSIZE,       w);
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_YSIZE,       28);
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_BGCOLOR,     C'13,17,23');
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_COLOR,       C'30,45,61');
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_WIDTH,       1);
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_CORNER,      CORNER_LEFT_UPPER);
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_SELECTABLE,  false);
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_ZORDER,      0);
      CreateLabel(LBL_TITLE,   x+10, y+9, "TraderLog",  C'0,212,161',   10, true);
      CreateLabel("TLJ_Sub",   x+83, y+9, "Journal",    C'100,120,135', 10, false);
      CreateButton(BTN_MINIMIZE, x+192, y+7, 22, 16, "▲", C'0,212,161', C'13,17,23', C'30,45,61', 8);
      ChartRedraw();
      return;
   }

   int hSiatka = _siatkaExpanded ? 102 : 0;
   int hPira   = _piraExpanded   ? 68 : 0;
   int h = 368 + hSiatka + hPira;

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

   // ── BASE ─────────────────────────────────────────────────
   CreateLabel(LBL_TITLE,     x+10,  y+9,   "TraderLog",          C'0,212,161',   10, true);
   CreateLabel("TLJ_Sub",     x+83,  y+9,   "Journal",            C'100,120,135', 10, false);
   CreateButton(BTN_MINIMIZE, x+192, y+7,   22, 16, "▼",          C'74,96,117',   C'13,17,23', C'30,45,61', 8);
   CreateLabel("TLJ_Ver",     x+10,  y+26,  "EA v2.0",            C'45,65,80',     8, false);
   CreateLabel(LBL_STATUS,    x+108, y+26,  "● Aktywny",          C'0,212,161',    8, false);
   CreateSep("TLJ_L1", x+8, y+40, w-16);

   CreateLabel("TLJ_K1",    x+10,  y+50,  "KONTO",     C'74,96,117',   8, false);
   CreateLabel(LBL_ACCOUNT, x+122, y+50,  "#---",       C'201,209,217', 8, false);
   CreateLabel("TLJ_K2",    x+10,  y+64,  "EQUITY",    C'74,96,117',   8, false);
   CreateLabel(LBL_EQUITY,  x+122, y+64,  "$0.00",     C'201,209,217', 8, false);
   CreateLabel("TLJ_K3",    x+10,  y+78,  "P&L OTWR.", C'74,96,117',   8, false);
   CreateLabel("TLJ_PnL",   x+122, y+78,  "—",         C'201,209,217', 8, false);
   CreateLabel("TLJ_K4",    x+10,  y+92,  "OTWARTE",   C'74,96,117',   8, false);
   CreateLabel(LBL_COUNT,   x+122, y+92,  "0 pozycji", C'201,209,217', 8, false);
   CreateLabel("TLJ_K5",    x+10,  y+106, "WYSŁANO",   C'74,96,117',   8, false);
   CreateLabel("TLJ_Sent",  x+122, y+106, "0 syg.",    C'201,209,217', 8, false);
   CreateSep("TLJ_L2", x+8, y+118, w-16);

   CreateLabel("TLJ_CalcHdr", x+10,  y+126, "KALKULATOR POZYCJI",  C'74,96,117',   7, false);
   CreateLabel("TLJ_RLbl",    x+10,  y+142, "Ryzyko %",            C'150,170,185', 8, false);
   CreateEdit(EDIT_RISK,      x+100, y+138, 50, 16, DoubleToString(DefaultRiskPct, 1));
   CreateLabel("TLJ_SLbl",    x+10,  y+162, "SL (pips)",           C'150,170,185', 8, false);
   CreateEdit(EDIT_SL,        x+100, y+158, 50, 16, DoubleToString(DefaultSLPips, 1));
   CreateLabel("TLJ_TPLbl",   x+10,  y+182, "TP (pips)",           C'150,170,185', 8, false);
   CreateEdit(EDIT_TP,        x+100, y+178, 50, 16, "0.0");
   CreateLabel("TLJ_LotLbl",  x+10,  y+202, "Lot:",                C'150,170,185', 8, false);
   CreateLabel(LBL_LOT,        x+40,  y+202, "—",                   C'0,212,161',   9, true);
   CreateButton(BTN_CALC,     x+158, y+197, 56, 18, "Oblicz",
                C'25,45,65', C'100,160,220', C'45,80,120', 8);
   CreateSep("TLJ_L3", x+8, y+218, w-16);

   // BUY / SELL (zawsze widoczne; gdy SIATKA WŁ → wywołują PlaceGrid)
   CreateButton(BTN_BUY,  x+8,   y+222, 100, 26, "BUY",
                C'0,130,80',  clrWhite, C'0,180,110', 10);
   CreateButton(BTN_SELL, x+114, y+222, 100, 26, "SELL",
                C'160,30,40', clrWhite, C'200,50,60', 10);

   // ── SIATKA SECTION ───────────────────────────────────────
   int ys = y + 252;

   string sHdrTxt = _siatkaExpanded ? "▼ SIATKA" : "▶ SIATKA";
   color  sOnBg   = _siatkaEnabled ? C'0,70,50'   : C'25,35,48';
   color  sOnFg   = _siatkaEnabled ? C'0,210,155' : C'74,96,117';
   color  sOnBdr  = _siatkaEnabled ? C'0,90,65'   : C'35,50,67';
   CreateButton(BTN_SIATKA_HDR,   x+8,   ys, 110, 22, sHdrTxt,
                C'20,30,42', C'74,96,117', C'35,50,67', 8);
   CreateButton(BTN_SIATKA_ONOFF, x+122, ys, 92, 22,
                _siatkaEnabled ? "■ WŁ" : "□ WYŁ",
                sOnBg, sOnFg, sOnBdr, 8);

   if (_siatkaExpanded) {
      // Wiersz 1: N + GRID BUY/SELL (równe kroki — Faron Mode)
      CreateLabel("TLJ_GNLbl", x+8,  ys+34, "N:", C'150,170,185', 8, false);
      CreateEdit(EDIT_GRID_N,  x+22, ys+28, 28, 16, "4");
      CreateButton(BTN_GRID_BUY, x+54,  ys+26, 76, 20, "GRID BUY",
                   C'0,80,55', C'0,210,155', C'0,100,70', 8);
      CreateButton(BTN_GRID_SEL, x+134, ys+26, 80, 20, "GRID SELL",
                   C'100,20,30', C'255,100,120', C'140,35,45', 8);
      // Wiersz 2: + POZIOM  [licznik]  - POZIOM (ręczne linie)
      CreateButton(BTN_ADD_LVL, x+8,   ys+50, 66, 20, "+ POZIOM",
                   C'0,55,40', C'0,180,120', C'0,80,58', 7);
      int lvlCnt = _gridLineCount;
      string lvlTxt = lvlCnt > 0 ? IntegerToString(lvlCnt) + " lvl" : "0 lvl";
      CreateLabel(LBL_LVL_COUNT, x+82, ys+56, lvlTxt, C'0,180,120', 7, false);
      CreateButton(BTN_DEL_LVL, x+148, ys+50, 66, 20, "- POZIOM",
                   C'50,30,10', C'200,140,60', C'80,55,20', 7);
      // Wiersz 3: GRID Z LINII BUY / SELL
      CreateButton(BTN_GRID_MAN_BUY, x+8,   ys+74, 100, 20, "GRID z LINII BUY",
                   C'0,60,42', C'0,200,140', C'0,90,63', 7);
      CreateButton(BTN_GRID_MAN_SEL, x+112, ys+74, 100, 20, "GRID z LINII SELL",
                   C'80,10,20', C'240,90,110', C'130,25,40', 7);
      // Wiersz 4: DOŁĄCZ BUY/SELL (siatka do istniejącej pozycji)
      CreateButton(BTN_ATT_BUY, x+8,   ys+98, 100, 20, "+ DOŁĄCZ BUY",
                   C'0,50,35', C'0,170,120', C'0,70,50', 7);
      CreateButton(BTN_ATT_SEL, x+112, ys+98, 100, 20, "+ DOŁĄCZ SELL",
                   C'70,10,20', C'220,80,100', C'110,20,35', 7);
   }

   int ysiEnd = ys + 22 + hSiatka;
   CreateSep("TLJ_LS", x+8, ysiEnd, w-16);

   // ── PIRA SECTION ─────────────────────────────────────────
   int yp = ysiEnd + 4;

   string pHdrTxt = _piraExpanded ? "▼ PIRAMID" : "▶ PIRAMID";
   color  pOnBg   = _autoPyramidEnabled ? C'0,70,50'   : C'25,35,48';
   color  pOnFg   = _autoPyramidEnabled ? C'0,210,155' : C'74,96,117';
   color  pOnBdr  = _autoPyramidEnabled ? C'0,90,65'   : C'35,50,67';
   CreateButton(BTN_PIRA_HDR,   x+8,   yp, 110, 22, pHdrTxt,
                C'20,30,42', C'74,96,117', C'35,50,67', 8);
   CreateButton(BTN_PIRA_ONOFF, x+122, yp, 92, 22,
                _autoPyramidEnabled ? "■ WŁ" : "□ WYŁ",
                pOnBg, pOnFg, pOnBdr, 8);

   if (_piraExpanded) {
      string modeTxt = _piraModePct ? "% konta"  : "stały lot";
      string fldLbl  = _piraModePct ? "Ryz%:"    : "Lot:";
      CreateButton(BTN_PIRA_MODE, x+8, yp+26, 60, 18, modeTxt,
                   C'25,35,48', C'100,160,220', C'45,80,120', 7);
      CreateLabel("TLJ_PyrFLbl", x+72, yp+32, fldLbl, C'150,170,185', 7, false);
      if (_piraModePct)
         CreateEdit(EDIT_PYR_RISK, x+100, yp+26, 44, 18, DoubleToString(PyramidRiskPct, 1));
      else
         CreateEdit(EDIT_PYR_LOT,  x+100, yp+26, 44, 18, "0.10");
      CreateLabel("TLJ_MxLbl",  x+8,  yp+50, "Mx:",  C'74,96,117', 7, false);
      CreateEdit(EDIT_PYR_MAX,  x+28, yp+44, 28, 16, IntegerToString(PyramidMaxLevels));
      CreateLabel("TLJ_StpLbl", x+62, yp+50, "Stp:", C'74,96,117', 7, false);
      CreateEdit(EDIT_PYR_STP,  x+82, yp+44, 52, 16, DoubleToString(PyramidPips, 1));
      CreateButton(BTN_ADD_BUY, x+8,   yp+64, 100, 22, "+ADD BUY",
                   C'0,70,50',  C'0,210,155', C'0,110,75', 7);
      CreateButton(BTN_ADD_SEL, x+112, yp+64, 100, 22, "+ADD SELL",
                   C'90,15,25', C'255,110,120', C'150,35,45', 7);
   }

   int ypEnd = yp + 22 + hPira;
   CreateSep("TLJ_L4", x+8, ypEnd, w-16);

   // ── FOOTER ───────────────────────────────────────────────
   int yf = ypEnd + 4;
   CreateButton(BTN_CLOSE_ALL, x+8,   yf,    66, 18, "Close ALL",
                C'50,20,20', C'255,100,100', C'100,40,40', 7);
   CreateButton(BTN_CLOSE_BUY, x+78,  yf,    66, 18, "Close BUY",
                C'20,50,30', C'80,200,120',  C'40,100,60', 7);
   CreateButton(BTN_CLOSE_SEL, x+148, yf,    66, 18, "Close SELL",
                C'50,20,20', C'255,80,80',   C'100,40,40', 7);
   CreateSep("TLJ_L5", x+8, yf+22, w-16);
   CreateButton(BTN_PAUSE, x+8,   yf+28, 100, 22, "⏸ Pauza",
                C'30,45,61', C'122,139,153', C'45,63,80', 8);
   CreateButton(BTN_STOP,  x+114, yf+28, 100, 22, "⏹ Stop EA",
                C'61,26,26', C'255,71,87',   C'93,40,40', 8);
   CreateLabel("TLJ_Link", x+10, yf+56, "traderlogjournal.com", C'45,63,80', 7, false);

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

   ObjectSetString (0, LBL_EQUITY,  OBJPROP_TEXT, "$" + DoubleToString(equity, 2));
   ObjectSetString (0, LBL_ACCOUNT, OBJPROP_TEXT, "#" + IntegerToString(mt4AccountNumber));

   string pnlStr = (profit >= 0 ? "+" : "") + "$" + DoubleToString(profit, 2);
   ObjectSetString (0, "TLJ_PnL", OBJPROP_TEXT,  pnlStr);
   ObjectSetInteger(0, "TLJ_PnL", OBJPROP_COLOR,
                    profit > 0 ? C'0,212,161' : profit < 0 ? C'255,71,87' : C'201,209,217');

   ObjectSetString(0, LBL_COUNT, OBJPROP_TEXT,
                   IntegerToString(open) + (open==1?" pozycja":open<5?" pozycje":" pozycji"));
   ObjectSetString(0, "TLJ_Sent", OBJPROP_TEXT, IntegerToString(_sentCount) + " syg.");

   string st = _paused ? "⏸  Wstrzymany" : "●  Aktywny";
   ObjectSetString (0, LBL_STATUS, OBJPROP_TEXT,  st);
   ObjectSetInteger(0, LBL_STATUS, OBJPROP_COLOR, _paused ? C'255,127,0' : C'0,212,161');

   // BUY/SELL — tekst zmienia się gdy siatka włączona
   if (_siatkaEnabled) {
      ObjectSetString(0, BTN_BUY,  OBJPROP_TEXT, "GRID BUY");
      ObjectSetString(0, BTN_SELL, OBJPROP_TEXT, "GRID SELL");
   } else {
      ObjectSetString(0, BTN_BUY,  OBJPROP_TEXT, "BUY");
      ObjectSetString(0, BTN_SELL, OBJPROP_TEXT, "SELL");
   }

   // SIATKA header + toggle
   // Licznik ręcznych poziomów
   if (ObjectFind(0, LBL_LVL_COUNT) >= 0) {
      string lvlT = _gridLineCount > 0 ? IntegerToString(_gridLineCount) + " lvl" : "0 lvl";
      ObjectSetString(0, LBL_LVL_COUNT, OBJPROP_TEXT, lvlT);
   }

   ObjectSetString (0, BTN_SIATKA_HDR, OBJPROP_TEXT,
                    _siatkaExpanded ? "▼ SIATKA" : "▶ SIATKA");
   ObjectSetString (0, BTN_SIATKA_ONOFF, OBJPROP_TEXT,
                    _siatkaEnabled ? "■ WŁ" : "□ WYŁ");
   ObjectSetInteger(0, BTN_SIATKA_ONOFF, OBJPROP_BGCOLOR,
                    _siatkaEnabled ? C'0,70,50'   : C'25,35,48');
   ObjectSetInteger(0, BTN_SIATKA_ONOFF, OBJPROP_COLOR,
                    _siatkaEnabled ? C'0,210,155' : C'74,96,117');

   // PIRA header + toggle (z licznikiem dokładek gdy WŁ)
   ObjectSetString(0, BTN_PIRA_HDR, OBJPROP_TEXT,
                   _piraExpanded ? "▼ PIRAMID" : "▶ PIRAMID");
   int pyrTotal = 0;
   if (_autoPyramidEnabled) {
      for (int i = 0; i < OrdersTotal(); i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
         if (StringFind(OrderComment(), "TLJ_PYR") >= 0) pyrTotal++;
      }
   }
   string piraOnTxt = _autoPyramidEnabled
                      ? "■ WŁ " + IntegerToString(pyrTotal) + "x" : "□ WYŁ";
   ObjectSetString (0, BTN_PIRA_ONOFF, OBJPROP_TEXT,   piraOnTxt);
   ObjectSetInteger(0, BTN_PIRA_ONOFF, OBJPROP_BGCOLOR,
                    _autoPyramidEnabled ? C'0,70,50'   : C'25,35,48');
   ObjectSetInteger(0, BTN_PIRA_ONOFF, OBJPROP_COLOR,
                    _autoPyramidEnabled ? C'0,210,155' : C'74,96,117');

   ChartRedraw();
}

//+------------------------------------------------------------------+
void DeletePanel() {
   string objs[] = {
      PANEL_NAME, BTN_MINIMIZE, BTN_STOP, BTN_PAUSE, BTN_BUY, BTN_SELL, BTN_CALC,
      BTN_CLOSE_ALL, BTN_CLOSE_BUY, BTN_CLOSE_SEL,
      EDIT_RISK, EDIT_SL, EDIT_TP, LBL_LOT,
      LBL_STATUS, LBL_COUNT, LBL_TITLE, LBL_ACCOUNT, LBL_EQUITY,
      "TLJ_Sub", "TLJ_Ver",
      "TLJ_L1", "TLJ_L2", "TLJ_L3", "TLJ_LS", "TLJ_L4", "TLJ_L5",
      "TLJ_K1", "TLJ_K2", "TLJ_K3", "TLJ_K4", "TLJ_K5",
      "TLJ_PnL", "TLJ_Sent", "TLJ_Link",
      "TLJ_CalcHdr", "TLJ_RLbl", "TLJ_SLbl", "TLJ_TPLbl", "TLJ_LotLbl",
      // SIATKA section
      BTN_SIATKA_HDR, BTN_SIATKA_ONOFF,
      "TLJ_GNLbl", EDIT_GRID_N, BTN_GRID_BUY, BTN_GRID_SEL, BTN_ATT_BUY, BTN_ATT_SEL,
      BTN_ADD_LVL, BTN_DEL_LVL, BTN_GRID_MAN_BUY, BTN_GRID_MAN_SEL, LBL_LVL_COUNT,
      // PIRA section
      BTN_PIRA_HDR, BTN_PIRA_ONOFF, BTN_PIRA_MODE,
      "TLJ_PyrFLbl", EDIT_PYR_RISK, EDIT_PYR_LOT,
      "TLJ_MxLbl", EDIT_PYR_MAX, "TLJ_StpLbl", EDIT_PYR_STP,
      BTN_ADD_BUY, BTN_ADD_SEL,
      // Legacy (z poprzednich wersji EA)
      BTN_SIATKA, BTN_PYRAMID
   };
   for (int i = 0; i < ArraySize(objs); i++) ObjectDelete(0, objs[i]);
   ChartRedraw();
}

//+------------------------------------------------------------------+
// Auto-wykrywanie rozmiaru pipsa dla KAŻDEGO instrumentu:
//   Złoto/platyna/pallad (XAU/XPT/XPD/GOLD) — zawsze 0.01 (pip-punkt)
//     Fix: XAUGBP.pro ma dg=3 (nieparzyste) → stary kod zwracał pt*10=0.001*10=0.01 OK,
//     ale XAUUSD dg=2 (parzyste) → zwracał pt*10=0.01*10=0.10 ZA DUŻE (lot 10× za duży).
//     Hardkodowane 0.01 daje spójne zachowanie: 1 pip = 0.01 jednostki (pip-punkt) dla złota.
//   Nieparzyste digits (5,3,1) — broker fractional pip → ×10
//   Parzyste digits + srebro (XAG) — → ×10
//   Wszystko inne (4-digit forex, 2-digit JPY, indeksy, ropa, krypto) → point
//+------------------------------------------------------------------+
double GetPipSize(string sym) {
   double pt = MarketInfo(sym, MODE_POINT);
   int    dg = (int)MarketInfo(sym, MODE_DIGITS);
   string u  = sym;
   StringToUpper(u);

   // === ZŁOTO, PLATYNA, PALLAD ===
   // pip = 0.10 (hardkodowane — działa dla 2-digit i 3-digit)
   if (StringFind(u, "XAU")  >= 0 || StringFind(u, "GOLD") >= 0 ||
       StringFind(u, "XPT")  >= 0 || StringFind(u, "PLAT") >= 0 ||
       StringFind(u, "XPD")  >= 0 || StringFind(u, "PALL") >= 0)
      return 0.1;

   // === SREBRO ===
   // pip = 0.01 (1 cent per ounce) — digits 2 lub 3
   if (StringFind(u, "XAG") >= 0 || StringFind(u, "SILVER") >= 0)
      return (dg <= 2) ? 0.01 : pt * 10.0;

   // === KRYPTO ===
   // pip = 1.0 USD (trader wpisuje SL w dolarach, np. SL=500 = ryzyko $500)
   // BTC: ~42000, ETH: ~2500, LTC: ~80, XRP: ~0.50 (XRP osobno)
   if (StringFind(u, "BTC") >= 0 || StringFind(u, "ETH") >= 0 ||
       StringFind(u, "LTC") >= 0 || StringFind(u, "BCH") >= 0 ||
       StringFind(u, "DOT") >= 0 || StringFind(u, "ADA") >= 0 ||
       StringFind(u, "SOL") >= 0 || StringFind(u, "LINK") >= 0)
      return 1.0;
   // XRP, inne alt coin z niską ceną — pip = 0.0001
   if (StringFind(u, "XRP") >= 0 || StringFind(u, "DOGE") >= 0)
      return 0.0001;

   // === ROPA I GAZY ===
   // pip = pt*10 (konwencja jak złoto: 10 punktów = 1 pip)
   // WTI.FS digits=2: pt=0.01 → pip=0.10; NGAS.FS digits=3: pt=0.001 → pip=0.01
   if (StringFind(u, "WTI")   >= 0 || StringFind(u, "BRENT") >= 0 ||
       StringFind(u, "USOIL") >= 0 || StringFind(u, "UKOIL") >= 0 ||
       StringFind(u, "OIL")   >= 0 || StringFind(u, "CRUDE") >= 0 ||
       StringFind(u, "NGAS")  >= 0 || StringFind(u, "NATGAS")>= 0 ||
       StringFind(u, "GAS")   >= 0)
      return pt * 10.0;

   // === INDEKSY ===
   // AXI: AUS200.FS, UK100.FS, US30.FS, US500.FS, NAS100.FS, GER40.FS,
   //       FRA40.FS, JPN225.FS, HKG50.FS, ESP35.FS, SWI20.FS, NED25.FS
   // pip = 1.0 punkt — wymuś niezależnie od digits (0, 1 lub 2)
   if (StringFind(u, "AUS200")  >= 0 || StringFind(u, "UK100")  >= 0 ||
       StringFind(u, "US30")    >= 0 || StringFind(u, "US500")  >= 0 ||
       StringFind(u, "NAS100")  >= 0 || StringFind(u, "GER")    >= 0 ||
       StringFind(u, "FRA40")   >= 0 || StringFind(u, "JPN225") >= 0 ||
       StringFind(u, "HKG50")   >= 0 || StringFind(u, "ESP35")  >= 0 ||
       StringFind(u, "SWI20")   >= 0 || StringFind(u, "NED25")  >= 0 ||
       StringFind(u, "US2000")  >= 0 || StringFind(u, "CHINA")  >= 0 ||
       StringFind(u, "SING")    >= 0 || StringFind(u, "TWN")    >= 0)
      return 1.0;

   // === METALE PRZEMYSŁOWE / SUROWCE ===
   // COPPER.FS, ALUM, NICKEL, WHEAT, CORN, COFFEE, COTTON, SUGAR, COCOA
   // pip = 0.01 (digits=2) lub pt*10 (digits=3) — obsługa przez defaulty
   // (brak specjalnego wpisu — obsługują je reguły ogólne poniżej)

   // === FOREX I RESZTA ===
   // Nieparzyste cyfry = broker ułamkowy pip (5-digit forex, 3-digit JPY)
   if (dg % 2 == 1) return pt * 10.0;

   // Parzyste cyfry: punkt = pip (4-digit forex stary, 2-digit JPY stary, akcje CFD)
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
   double result = MathMax(MarketInfo(Symbol(), MODE_MINLOT),
                           MathMin(MarketInfo(Symbol(), MODE_MAXLOT), lot));
   return result;
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

// Lot dla dokładki PIRA: % konta (EDIT_PYR_RISK) albo stały lot (EDIT_PYR_LOT).
double GetPiraLot(double slPips) {
   if (_piraModePct) {
      double riskPct = StringToDouble(ObjectGetString(0, EDIT_PYR_RISK, OBJPROP_TEXT));
      if (riskPct <= 0) riskPct = PyramidRiskPct;
      if (riskPct <= 0) riskPct = StringToDouble(ObjectGetString(0, EDIT_RISK, OBJPROP_TEXT));
      return CalcLot(riskPct, slPips);
   }
   double lot  = StringToDouble(ObjectGetString(0, EDIT_PYR_LOT, OBJPROP_TEXT));
   if (lot <= 0 && PyramidRiskPct > 0) return CalcLot(PyramidRiskPct, slPips);
   double step = MarketInfo(Symbol(), MODE_LOTSTEP);
   if (step <= 0) step = 0.01;
   lot = MathFloor(lot / step) * step;
   return MathMax(MarketInfo(Symbol(), MODE_MINLOT),
                  MathMin(MarketInfo(Symbol(), MODE_MAXLOT), lot));
}

//+------------------------------------------------------------------+
// OTWIERANIE ZLECEŃ
//+------------------------------------------------------------------+
void OpenOrder(int orderType) {
   double riskPct = StringToDouble(ObjectGetString(0, EDIT_RISK, OBJPROP_TEXT));
   double slPips  = StringToDouble(ObjectGetString(0, EDIT_SL,   OBJPROP_TEXT));
   double tpPips  = StringToDouble(ObjectGetString(0, EDIT_TP,   OBJPROP_TEXT));
   if (riskPct <= 0 || slPips <= 0) {
      Alert("TLJ: Wpisz poprawne Ryzyko % i SL pips!");
      return;
   }
   double lot = CalcLot(riskPct, slPips);
   if (lot <= 0) { Alert("TLJ: Błąd kalkulacji lota!"); return; }

   int    digits   = (int)MarketInfo(Symbol(), MODE_DIGITS);
   double pipSz    = GetPipSize(Symbol());
   double liveAsk  = MarketInfo(Symbol(), MODE_ASK);
   double liveBid  = MarketInfo(Symbol(), MODE_BID);
   double price, sl, tp;

   if (orderType == OP_BUY) {
      price = NormalizeDouble(liveAsk, digits);
      sl    = NormalizeDouble(liveAsk - slPips * pipSz, digits);
      tp    = tpPips > 0 ? NormalizeDouble(liveAsk + tpPips * pipSz, digits) : 0;
   } else {
      price = NormalizeDouble(liveBid, digits);
      sl    = NormalizeDouble(liveBid + slPips * pipSz, digits);
      tp    = tpPips > 0 ? NormalizeDouble(liveBid - tpPips * pipSz, digits) : 0;
   }

   // Virtual SL/TP — broker widzi sl=0 tp=0, EA zarządza samodzielnie
   double sendSL = VirtualSLTP ? 0 : sl;
   double sendTP = VirtualSLTP ? 0 : tp;

   int ticket = OrderSend(Symbol(), orderType, lot, price, 3, sendSL, sendTP,
                          "TLJ Panel", MagicNumber, 0,
                          orderType == OP_BUY ? clrLime : clrRed);
   if (ticket < 0) {
      int err = GetLastError();
      Print("TLJ: Błąd OrderSend err=", err);
      Alert("TLJ: Błąd otwarcia zlecenia (kod: ", err, ")");
      return;
   }

   if (VirtualSLTP) {
      if (sl > 0) GlobalVariableSet("VTLJ_SL_" + IntegerToString(ticket), sl);
      if (tp > 0) GlobalVariableSet("VTLJ_TP_" + IntegerToString(ticket), tp);
      Print("TLJ: Otwarto ", (orderType==OP_BUY?"BUY":"SELL"),
            " lot=", lot, " vSL=", sl, " vTP=", tp, " ticket=", ticket, " [STEALTH]");
   } else {
      Print("TLJ: Otwarto ", (orderType==OP_BUY?"BUY":"SELL"),
            " lot=", lot, " sl=", sl, " tp=", tp, " ticket=", ticket);
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

      double closePrice = (OrderType() == OP_BUY) ? MarketInfo(Symbol(), MODE_BID) : MarketInfo(Symbol(), MODE_ASK);
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

// Przesuń SL parenta i wszystkich jego dokładek PIRA na wspólny poziom.
void MoveAllPyrSLToCommon(long parentTicket, int dir, double commonSL) {
   string tag = "TLJ_PYR_" + IntegerToString(parentTicket);
   int    dg  = (int)MarketInfo(Symbol(), MODE_DIGITS);
   int    cnt = 0;
   for (int i = 0; i < OrdersTotal(); i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))  continue;
      if (OrderType()        != dir)                     continue;
      if (OrderMagicNumber() != MagicNumber)             continue;
      bool isParent = (OrderTicket() == (int)parentTicket);
      bool isPyr    = (StringFind(OrderComment(), tag) >= 0);
      if (!isParent && !isPyr)                           continue;
      if (MathAbs(OrderStopLoss() - commonSL) < Point)  continue;
      if (OrderModify(OrderTicket(), OrderOpenPrice(), commonSL, OrderTakeProfit(), 0, CLR_NONE))
         cnt++;
      else
         Print("TLJ [PYR SL] BŁĄD OrderModify #", OrderTicket(),
               " err=", GetLastError(), " SL=", DoubleToString(commonSL, dg));
   }
   Print("TLJ [PYR SL] wspólny SL=", DoubleToString(commonSL, dg),
         " parent=#", parentTicket, " (", cnt, " pozycji)");
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

//+------------------------------------------------------------------+
// VIRTUAL SL/TP — broker widzi 0/0, EA zamyka gdy cena dojdzie do
// poziomu zapisanego w GlobalVariables jako VTLJ_SL_/VTLJ_TP_
//+------------------------------------------------------------------+
void CheckVirtualLevels() {
   if (!VirtualSLTP) return;
   double liveAsk = MarketInfo(Symbol(), MODE_ASK);
   double liveBid = MarketInfo(Symbol(), MODE_BID);
   int    digits  = (int)MarketInfo(Symbol(), MODE_DIGITS);

   for (int i = OrdersTotal()-1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderType() > 1)                              continue;
      if (OrderMagicNumber() != MagicNumber)            continue;
      if (OrderSymbol() != Symbol())                    continue;

      int    ticket = OrderTicket();
      string keySL  = "VTLJ_SL_" + IntegerToString(ticket);
      string keyTP  = "VTLJ_TP_" + IntegerToString(ticket);

      double vSL = GlobalVariableCheck(keySL) ? GlobalVariableGet(keySL) : 0;
      double vTP = GlobalVariableCheck(keyTP) ? GlobalVariableGet(keyTP) : 0;
      if (vSL <= 0 && vTP <= 0) continue;

      bool hitSL = false, hitTP = false;
      if (OrderType() == OP_BUY) {
         if (vSL > 0 && liveBid <= vSL) hitSL = true;
         if (vTP > 0 && liveBid >= vTP) hitTP = true;
      } else {
         if (vSL > 0 && liveAsk >= vSL) hitSL = true;
         if (vTP > 0 && liveAsk <= vTP) hitTP = true;
      }
      if (!hitSL && !hitTP) continue;

      double closePrice = OrderType() == OP_BUY ? liveBid : liveAsk;
      if (OrderClose(ticket, OrderLots(), NormalizeDouble(closePrice, digits), 3, clrYellow)) {
         GlobalVariableDel(keySL);
         GlobalVariableDel(keyTP);
         Print("TLJ [STEALTH] Zamknieto #", ticket, " @ ", DoubleToString(closePrice, digits),
               hitSL ? " hit vSL=" : " hit vTP=",
               DoubleToString(hitSL ? vSL : vTP, digits));
      }
   }
}

void CheckGridFills() {
   // Zbierz aktualnie otwarte pozycje siatki (type OP_BUY / OP_SELL, nie pending)
   long currentOpen[];
   ArrayResize(currentOpen, 0);
   for (int i = 0; i < OrdersTotal(); i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderType() > 1)                              continue;
      if (OrderMagicNumber() != MagicNumber)            continue;
      if (StringFind(OrderComment(), "TLJ_GRID_") < 0) continue;
      int sz = ArraySize(currentOpen);
      ArrayResize(currentOpen, sz + 1);
      currentOpen[sz] = OrderTicket();
   }
   // Śledź też bazową pozycję (DOŁĄCZ) — dowolny magic
   if (_gridBaseTicket > 0 &&
       OrderSelect((int)_gridBaseTicket, SELECT_BY_TICKET, MODE_TRADES) &&
       OrderCloseTime() == 0) {
      int sz = ArraySize(currentOpen);
      ArrayResize(currentOpen, sz + 1);
      currentOpen[sz] = _gridBaseTicket;
   }

   // Przy pierwszym wywołaniu: inicjalizuj stan + usuń osierocone pendingsy
   // (EA restartowane po SL → brak pozycji market ale pozostały pending STOP orders)
   if (!_gridInitialized) {
      ArrayCopy(_gridOpenTickets, currentOpen);
      _gridInitialized = true;
      if (ArraySize(currentOpen) == 0) {
         int del = 0;
         for (int i = OrdersTotal()-1; i >= 0; i--) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
            if (OrderType() < 2)                              continue;
            if (OrderMagicNumber() != MagicNumber)            continue;
            if (StringFind(OrderComment(), "TLJ_GRID_") < 0) continue;
            if (OrderDelete(OrderTicket())) del++;
         }
         if (del > 0)
            Print("TLJ [GRID INIT] Usunięto ", del, " osieroconych zleceń siatki (brak pozycji market)");
      }
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

      // Wspólny SL = entry poprzedniej pozycji
      // Gdy L2 wypełnia się a bazowa pozycja pochodzi z DOŁĄCZ → używaj _gridBaseTicket jako L1
      long prevTicket;
      if (myLevel == 2 && _gridBaseTicket > 0)
         prevTicket = _gridBaseTicket;
      else
         prevTicket = FindPrevGridOrder(myType, myLevel);

      if (prevTicket > 0 && OrderSelect((int)prevTicket, SELECT_BY_TICKET, MODE_TRADES)) {
         double commonSL = OrderOpenPrice();
         int    digits   = (int)MarketInfo(Symbol(), MODE_DIGITS);
         int    cnt      = 0;
         // Przesuń wszystkie TLJ_GRID_* zlecenia
         for (int m = 0; m < OrdersTotal(); m++) {
            if (!OrderSelect(m, SELECT_BY_POS, MODE_TRADES))  continue;
            if (OrderType() != myType)                         continue;
            if (OrderMagicNumber() != MagicNumber)             continue;
            if (StringFind(OrderComment(), "TLJ_GRID_") < 0)  continue;
            if (MathAbs(OrderStopLoss() - commonSL) < Point)  continue;
            if (OrderModify(OrderTicket(), OrderOpenPrice(), commonSL, OrderTakeProfit(), 0, CLR_NONE))
               cnt++;
            else
               Print("TLJ [GRID SL] BŁĄD OrderModify #", OrderTicket(),
                     " err=", GetLastError(), " SL=", DoubleToString(commonSL, digits));
         }
         // Przesuń też bazową pozycję (DOŁĄCZ) jeśli to nie ona jest L_prev
         if (_gridBaseTicket > 0 && _gridBaseTicket != prevTicket &&
             OrderSelect((int)_gridBaseTicket, SELECT_BY_TICKET, MODE_TRADES) &&
             OrderCloseTime() == 0 &&
             MathAbs(OrderStopLoss() - commonSL) >= Point) {
            if (OrderModify((int)_gridBaseTicket, OrderOpenPrice(), commonSL, OrderTakeProfit(), 0, CLR_NONE))
               cnt++;
            else
               Print("TLJ [GRID SL] BŁĄD base #", _gridBaseTicket, " err=", GetLastError());
         }
         Print("TLJ [GRID FILL] Poziom ", myLevel, " → wspólny SL=",
               DoubleToString(commonSL, digits), " (przesunięto ", cnt, " SL)");
      }
   }

   ArrayCopy(_gridOpenTickets, currentOpen);
}

//+------------------------------------------------------------------+
// RĘCZNA SIATKA — linie przeciągane przez użytkownika
//+------------------------------------------------------------------+
int CountGridLines() {
   int cnt = 0;
   for (int i = 1; i <= 10; i++) {
      if (ObjectFind(0, GRID_LINE_PREFIX + IntegerToString(i)) >= 0)
         cnt = i;
      else
         break;
   }
   return cnt;
}

void UpdateLevelCountLabel() {
   if (ObjectFind(0, LBL_LVL_COUNT) < 0) return;
   string txt = _gridLineCount > 0 ? IntegerToString(_gridLineCount) + " lvl" : "0 lvl";
   ObjectSetString(0, LBL_LVL_COUNT, OBJPROP_TEXT, txt);
   ChartRedraw();
}

void AddGridLevel() {
   if (_gridLineCount >= 10) {
      Alert("TLJ: Maksimum 10 poziomow");
      return;
   }
   _gridLineCount++;
   string name  = GRID_LINE_PREFIX + IntegerToString(_gridLineCount);
   double price = NormalizeDouble((MarketInfo(Symbol(), MODE_ASK) + MarketInfo(Symbol(), MODE_BID)) / 2.0,
                                  (int)MarketInfo(Symbol(), MODE_DIGITS));
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      C'0,180,120');
   ObjectSetInteger(0, name, OBJPROP_STYLE,      STYLE_DASH);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,      1);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTED,   false);
   ObjectSetString (0, name, OBJPROP_TOOLTIP,
                    "TLJ Poziom " + IntegerToString(_gridLineCount) + " — przeciagnij na strefe");
   UpdateLevelCountLabel();
   Print("TLJ [GL] Dodano poziom ", _gridLineCount, " @ ", DoubleToString(price, (int)MarketInfo(Symbol(), MODE_DIGITS)));
}

void RemoveLastGridLevel() {
   if (_gridLineCount <= 0) return;
   ObjectDelete(0, GRID_LINE_PREFIX + IntegerToString(_gridLineCount));
   _gridLineCount--;
   UpdateLevelCountLabel();
}

void SortPrices(double &arr[], int n, int direction) {
   for (int i = 0; i < n - 1; i++) {
      for (int j = 0; j < n - 1 - i; j++) {
         bool doSwap = (direction == OP_BUY) ? arr[j] > arr[j+1] : arr[j] < arr[j+1];
         if (doSwap) {
            double tmp = arr[j];
            arr[j]     = arr[j+1];
            arr[j+1]   = tmp;
         }
      }
   }
}

void PlaceGridFromLines(int direction) {
   double riskPct = StringToDouble(ObjectGetString(0, EDIT_RISK, OBJPROP_TEXT));
   double slPips  = StringToDouble(ObjectGetString(0, EDIT_SL,   OBJPROP_TEXT));
   double tpPips  = StringToDouble(ObjectGetString(0, EDIT_TP,   OBJPROP_TEXT));

   if (riskPct <= 0 || slPips <= 0) { Alert("TLJ GridLines: Ustaw Ryzyko% i SL"); return; }

   // Zbierz ceny linii
   double prices[];
   int    n = 0;
   for (int i = 1; i <= 10; i++) {
      string lname = GRID_LINE_PREFIX + IntegerToString(i);
      if (ObjectFind(0, lname) < 0) break;
      ArrayResize(prices, n + 1);
      prices[n] = ObjectGetDouble(0, lname, OBJPROP_PRICE, 0);
      n++;
   }
   if (n < 2) {
      Alert("TLJ GridLines: Potrzeba co najmniej 2 poziomow (masz ", n, ")");
      return;
   }

   SortPrices(prices, n, direction);

   int    digits   = (int)MarketInfo(Symbol(), MODE_DIGITS);
   double pipSz    = GetPipSize(Symbol());
   double liveAsk  = MarketInfo(Symbol(), MODE_ASK);
   double liveBid  = MarketInfo(Symbol(), MODE_BID);
   double lstep    = MarketInfo(Symbol(), MODE_LOTSTEP);
   double lmin     = MarketInfo(Symbol(), MODE_MINLOT);
   double lmax     = MarketInfo(Symbol(), MODE_MAXLOT);
   double minDist  = MarketInfo(Symbol(), MODE_STOPLEVEL) * MarketInfo(Symbol(), MODE_POINT);

   double tp = 0;
   if (tpPips > 0)
      tp = direction == OP_BUY
           ? NormalizeDouble(prices[0] + tpPips * pipSz, digits)
           : NormalizeDouble(prices[0] - tpPips * pipSz, digits);

   int placed = 0;
   for (int i = 0; i < n; i++) {
      double entryPrice, sl;
      int    orderType;

      if (i == 0) {
         orderType  = direction;
         entryPrice = direction == OP_BUY
                      ? NormalizeDouble(liveAsk, digits)
                      : NormalizeDouble(liveBid, digits);
         sl = direction == OP_BUY
              ? NormalizeDouble(entryPrice - slPips * pipSz, digits)
              : NormalizeDouble(entryPrice + slPips * pipSz, digits);
      } else {
         orderType  = (direction == OP_BUY) ? OP_BUYSTOP : OP_SELLSTOP;
         entryPrice = NormalizeDouble(prices[i], digits);
         sl         = NormalizeDouble(prices[i-1], digits);

         // Walidacja StopLevel
         double dist = direction == OP_BUY ? entryPrice - liveAsk : liveBid - entryPrice;
         if (dist < minDist) {
            Alert("TLJ GridLines: Poziom ", i+1, " za blisko ceny. Przesun linie dalej.");
            return;
         }
      }

      double slDist = MathAbs(entryPrice - sl) / pipSz;
      if (slDist <= 0) { Alert("TLJ GridLines: Blad SL poziom ", i+1); return; }

      double lot = MathFloor(CalcLot(riskPct, slDist) / lstep) * lstep;
      lot = MathMax(lmin, MathMin(lmax, lot));

      string cmt = "TLJ_GRID_" + IntegerToString(i+1) + "of" + IntegerToString(n);
      int ticket = OrderSend(Symbol(), orderType, lot, entryPrice, 3,
                             sl, tp, cmt, MagicNumber, 0,
                             direction == OP_BUY ? clrLime : clrRed);
      if (ticket < 0) {
         int err = GetLastError();
         Print("TLJ [GridLines] #", i+1, " blad err=", err);
         Alert("TLJ GridLines: Blad zlecenia #", i+1, " (kod: ", err, "). Postawiono: ", placed);
         return;
      }
      placed++;
      Print("TLJ [GridLines] #", i+1, "of", n,
            " entry=", DoubleToString(entryPrice, digits),
            " sl=", DoubleToString(sl, digits),
            " tp=", DoubleToString(tp, digits),
            " lot=", DoubleToString(lot, 2));
   }

   // Usuń linie po postawieniu zleceń
   for (int i = 1; i <= _gridLineCount; i++)
      ObjectDelete(0, GRID_LINE_PREFIX + IntegerToString(i));
   _gridLineCount = 0;
   UpdateLevelCountLabel();
   _gridInitialized = false;
   Print("TLJ [GridLines] Gotowe: ", placed, " zlecen z ", n, " linii");
   ChartRedraw();
}

//+------------------------------------------------------------------+
// DOŁĄCZ — dostawia siatką N-1 STOP-ów do istniejącej pozycji
// Bazowa pozycja staje się "level 1"; _gridBaseTicket ją zapamiętuje.
//+------------------------------------------------------------------+
void AttachGridToExisting(int direction) {
   double riskPct = StringToDouble(ObjectGetString(0, EDIT_RISK, OBJPROP_TEXT));
   if (riskPct <= 0) { Alert("TLJ DOLACZ: Ustaw Ryzyko% w kalkulatorze"); return; }

   // Znajdz ostatnio otwarta pozycje w podanym kierunku (wyklucz TLJ_GRID_*)
   long     baseTicket = -1;
   datetime latestTime = 0;
   for (int i = 0; i < OrdersTotal(); i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderSymbol() != Symbol())  continue;
      if (OrderType()   != direction) continue;
      if (StringFind(OrderComment(), "TLJ_GRID") >= 0) continue;
      if (OrderOpenTime() >= latestTime) {
         latestTime = OrderOpenTime();
         baseTicket = OrderTicket();
      }
   }
   if (baseTicket < 0) {
      Alert("TLJ DOLACZ: Brak otwartej pozycji ",
            direction == OP_BUY ? "BUY" : "SELL", " na ", Symbol());
      return;
   }
   if (!OrderSelect((int)baseTicket, SELECT_BY_TICKET, MODE_TRADES)) return;

   double basePrice    = OrderOpenPrice();
   double posTP        = OrderTakeProfit();
   double posSL        = OrderStopLoss();
   _gridBaseTicket     = baseTicket;

   int    digits  = (int)MarketInfo(Symbol(), MODE_DIGITS);
   double pipSz   = GetPipSize(Symbol());
   double lstep   = MarketInfo(Symbol(), MODE_LOTSTEP);
   double lmin    = MarketInfo(Symbol(), MODE_MINLOT);
   double lmax    = MarketInfo(Symbol(), MODE_MAXLOT);

   // ── TRYB LINII: sa narysowane TLJ_GL_* → uzyj ich cen ────────────
   if (_gridLineCount >= 1) {
      // Zbierz ceny linii
      double prices[];
      int    np = 0;
      for (int i = 1; i <= 10; i++) {
         string lname = GRID_LINE_PREFIX + IntegerToString(i);
         if (ObjectFind(0, lname) < 0) break;
         ArrayResize(prices, np + 1);
         prices[np] = ObjectGetDouble(0, lname, OBJPROP_PRICE, 0);
         np++;
      }
      if (np < 1) { Alert("TLJ DOLACZ: Brak linii do podlaczenia"); return; }

      SortPrices(prices, np, direction);

      double liveAskL = MarketInfo(Symbol(), MODE_ASK);
      double liveBidL = MarketInfo(Symbol(), MODE_BID);
      double minDistL = MarketInfo(Symbol(), MODE_STOPLEVEL) * MarketInfo(Symbol(), MODE_POINT);

      // TP: z pozycji (jesli ma), potem EDIT_TP, potem brak
      double tpPips = 0;
      if (posTP > 0) tpPips = MathAbs(posTP - basePrice) / pipSz;
      if (tpPips <= 0) tpPips = StringToDouble(ObjectGetString(0, EDIT_TP, OBJPROP_TEXT));
      double tp = 0;
      if (tpPips > 0)
         tp = direction == OP_BUY
              ? NormalizeDouble(basePrice + tpPips * pipSz, digits)
              : NormalizeDouble(basePrice - tpPips * pipSz, digits);

      // Zaktualizuj TP bazowej pozycji jezeli zmieniony
      if (tp > 0 && MathAbs(posTP - tp) >= Point)
         OrderModify((int)baseTicket, basePrice, posSL, tp, 0, CLR_NONE);

      int total = np + 1;  // bazowa = level 1, linie = level 2..N
      int placed = 0;
      for (int j = 0; j < np; j++) {
         double entryPrice = NormalizeDouble(prices[j], digits);
         // SL = cena poprzedniego poziomu (level 1 = basePrice)
         double sl = (j == 0) ? basePrice : NormalizeDouble(prices[j-1], digits);
         int    orderType = (direction == OP_BUY) ? OP_BUYSTOP : OP_SELLSTOP;

         // Walidacja: linia musi byc po wlasciwej stronie ceny + pow. stop level
         double distFromMkt = direction == OP_BUY ? entryPrice - liveAskL : liveBidL - entryPrice;
         if (distFromMkt < minDistL) {
            Alert("TLJ DOLACZ-GL: Poziom ", j+2, " (", DoubleToString(entryPrice, digits),
                  ") za blisko lub po zlej stronie ceny. Przesun linie dalej.");
            return;
         }

         double slDist = MathAbs(entryPrice - sl) / pipSz;
         if (slDist <= 0) { Alert("TLJ DOLACZ: Niepoprawny SL poziom ", j+2); return; }
         double lot = MathFloor(CalcLot(riskPct, slDist) / lstep) * lstep;
         lot = MathMax(lmin, MathMin(lmax, lot));

         string comment = "TLJ_GRID_" + IntegerToString(j + 2) + "of" + IntegerToString(total);
         int ticket = OrderSend(Symbol(), orderType, lot, entryPrice, 3,
                                sl, tp, comment, MagicNumber, 0,
                                direction == OP_BUY ? clrLime : clrRed);
         if (ticket < 0) {
            int err = GetLastError();
            Alert("TLJ DOLACZ z LINII: Blad #", j+2, " (err=", err, "). Postawiono: ", placed);
            return;
         }
         placed++;
         Print("TLJ [DOLACZ-GL] #", j+2, "of", total,
               " entry=", DoubleToString(entryPrice, digits),
               " sl=", DoubleToString(sl, digits),
               " lot=", DoubleToString(lot, 2));
      }
      // Usun linie po podlaczeniu
      for (int i = 1; i <= _gridLineCount; i++)
         ObjectDelete(0, GRID_LINE_PREFIX + IntegerToString(i));
      _gridLineCount = 0;
      UpdateLevelCountLabel();
      _gridInitialized = false;
      Print("TLJ [DOLACZ-GL] Gotowe: baza #", baseTicket, " + ", placed, " STOP-ow z linii");
      ChartRedraw();
      return;
   }

   // ── TRYB ROWNYE KROKI: brak linii → anchor = liveAsk/liveBid ────────
   double slPips = StringToDouble(ObjectGetString(0, EDIT_SL, OBJPROP_TEXT));
   int    n      = (int)StringToInteger(ObjectGetString(0, EDIT_GRID_N, OBJPROP_TEXT));

   if (n < 2 || n > 10) { Alert("TLJ DOLACZ: N musi byc 2-10"); return; }
   if (slPips <= 0)      { Alert("TLJ DOLACZ: Ustaw SL w kalkulatorze"); return; }

   double tpPips2 = 0;
   if (posTP > 0) tpPips2 = MathAbs(posTP - basePrice) / pipSz;
   if (tpPips2 <= 0) tpPips2 = StringToDouble(ObjectGetString(0, EDIT_TP, OBJPROP_TEXT));
   if (tpPips2 <= 0) { Alert("TLJ DOLACZ: Pozycja nie ma TP — wpisz TP w kalkulatorze"); return; }

   ObjectSetString(0, EDIT_TP, OBJPROP_TEXT, DoubleToString(NormalizeDouble(tpPips2, 1), 1));

   double stepPips = tpPips2 / n;

   // Kotwica = aktualna cena (nie basePrice) — unika "invalid order" gdy cena odeszła od bazy
   double liveAsk2 = MarketInfo(Symbol(), MODE_ASK);
   double liveBid2 = MarketInfo(Symbol(), MODE_BID);
   double minDist2 = MarketInfo(Symbol(), MODE_STOPLEVEL) * MarketInfo(Symbol(), MODE_POINT);

   if (stepPips * pipSz < minDist2) {
      Alert("TLJ DOLACZ: Krok (", DoubleToString(stepPips, 1), " pips) mniejszy niz stop level brokera (",
            DoubleToString(minDist2 / pipSz, 1), " pips). Zmniejsz N lub zwieksz TP.");
      return;
   }

   double refPrice = direction == OP_BUY ? liveAsk2 : liveBid2;
   double tp2 = direction == OP_BUY
                ? NormalizeDouble(refPrice + tpPips2 * pipSz, digits)
                : NormalizeDouble(refPrice - tpPips2 * pipSz, digits);

   if (MathAbs(posTP - tp2) >= Point)
      OrderModify((int)baseTicket, basePrice, posSL, tp2, 0, CLR_NONE);

   int placed2 = 0;
   for (int j = 1; j < n; j++) {
      double entryPrice, sl;
      int    orderType;
      if (direction == OP_BUY) {
         entryPrice = NormalizeDouble(refPrice + j * stepPips * pipSz, digits);
         // SL Faron: poziom j+1 → SL = wejscie poziomu j (= basePrice dla j==1, potem refPrice + (j-1)*step)
         sl = (j == 1) ? basePrice : NormalizeDouble(refPrice + (j-1) * stepPips * pipSz, digits);
         orderType  = OP_BUYSTOP;
      } else {
         entryPrice = NormalizeDouble(refPrice - j * stepPips * pipSz, digits);
         sl = (j == 1) ? basePrice : NormalizeDouble(refPrice - (j-1) * stepPips * pipSz, digits);
         orderType  = OP_SELLSTOP;
      }
      double lot = MathFloor(CalcLot(riskPct, stepPips) / lstep) * lstep;
      lot = MathMax(lmin, MathMin(lmax, lot));

      string comment = "TLJ_GRID_" + IntegerToString(j + 1) + "of" + IntegerToString(n);
      int ticket = OrderSend(Symbol(), orderType, lot, entryPrice, 3,
                             sl, tp2, comment, MagicNumber, 0,
                             direction == OP_BUY ? clrLime : clrRed);
      if (ticket < 0) {
         int err = GetLastError();
         Alert("TLJ DOLACZ: Blad #", j+1, " (err=", err, "). Postawiono: ", placed2);
         return;
      }
      placed2++;
      Print("TLJ [DOLACZ] #", j+1, "of", n,
            " entry=", DoubleToString(entryPrice, digits),
            " sl=", DoubleToString(sl, digits),
            " lot=", DoubleToString(lot, 2));
   }
   _gridInitialized = false;
   Print("TLJ [DOLACZ] Gotowe: baza #", baseTicket, " @ ", DoubleToString(basePrice, digits),
         " | ref=", DoubleToString(refPrice, digits), " | +", placed2, " STOP-ow");
}

//+------------------------------------------------------------------+
// UPDATE TP SIATKI — EDIT_TP zmieniony przez uzytkownika
// Przesuwa TP we wszystkich TLJ_GRID_* i w pozycji bazowej.
//+------------------------------------------------------------------+
void UpdateGridTP() {
   double tpPips = StringToDouble(ObjectGetString(0, EDIT_TP, OBJPROP_TEXT));
   if (tpPips <= 0) return;

   int    digits = (int)MarketInfo(Symbol(), MODE_DIGITS);
   double pipSz  = GetPipSize(Symbol());

   // Szukaj punktu referencyjnego: _gridBaseTicket lub TLJ_GRID_1of*
   double basePrice = 0;
   int    baseDir   = -1;
   if (_gridBaseTicket > 0 &&
       OrderSelect((int)_gridBaseTicket, SELECT_BY_TICKET, MODE_TRADES) &&
       OrderCloseTime() == 0) {
      basePrice = OrderOpenPrice();
      baseDir   = OrderType();
   } else {
      for (int i = 0; i < OrdersTotal(); i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
         if (OrderSymbol() != Symbol()) continue;
         if (StringFind(OrderComment(), "TLJ_GRID_1of") < 0) continue;
         basePrice = OrderOpenPrice();
         baseDir   = OrderType();
         break;
      }
   }
   if (basePrice == 0 || baseDir < 0) return;

   double newTP = baseDir == OP_BUY
                  ? NormalizeDouble(basePrice + tpPips * pipSz, digits)
                  : NormalizeDouble(basePrice - tpPips * pipSz, digits);

   // Aktualizuj bazowa pozycje
   if (_gridBaseTicket > 0 &&
       OrderSelect((int)_gridBaseTicket, SELECT_BY_TICKET, MODE_TRADES) &&
       OrderCloseTime() == 0 &&
       MathAbs(OrderTakeProfit() - newTP) >= Point) {
      OrderModify((int)_gridBaseTicket, OrderOpenPrice(),
                  OrderStopLoss(), newTP, 0, CLR_NONE);
   }

   // Aktualizuj wszystkie TLJ_GRID_*
   for (int i = 0; i < OrdersTotal(); i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderSymbol() != Symbol()) continue;
      if (StringFind(OrderComment(), "TLJ_GRID") < 0) continue;
      if (MathAbs(OrderTakeProfit() - newTP) < Point) continue;
      OrderModify(OrderTicket(), OrderOpenPrice(),
                  OrderStopLoss(), newTP, 0, CLR_NONE);
   }
   Print("TLJ [UpdateTP] Nowy TP=", DoubleToString(newTP, digits),
         " (", tpPips, " pips od bazy)");
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

   int    digits   = (int)MarketInfo(Symbol(), MODE_DIGITS);
   double pipSz    = GetPipSize(Symbol());
   double liveAsk  = MarketInfo(Symbol(), MODE_ASK);
   double liveBid  = MarketInfo(Symbol(), MODE_BID);

   double basePrice, tp;
   if (direction == OP_BUY) {
      basePrice = NormalizeDouble(liveAsk, digits);
      tp = NormalizeDouble(basePrice + tpPips * pipSz, digits);
   } else {
      basePrice = NormalizeDouble(liveBid, digits);
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

   _gridInitialized = false;
   Print("TLJ [GRID] Gotowe: ", placed, " zleceń (Faron Mode — każde 1% ryzyka niezależnie)");
}

//+------------------------------------------------------------------+
// PIRAMIDOWANIE — MANUALNE
//+------------------------------------------------------------------+
void OpenPyramidOrder(int orderType) {
   double slPips = StringToDouble(ObjectGetString(0, EDIT_SL, OBJPROP_TEXT));
   if (slPips <= 0) { Alert("TLJ: Wpisz poprawny SL pips!"); return; }
   double lot = GetPiraLot(slPips);
   if (lot <= 0) { Alert("TLJ: Błąd kalkulacji lota!"); return; }

   int    digits   = (int)MarketInfo(Symbol(), MODE_DIGITS);
   double pipSz    = GetPipSize(Symbol());
   double liveAsk  = MarketInfo(Symbol(), MODE_ASK);
   double liveBid  = MarketInfo(Symbol(), MODE_BID);
   double price, sl;

   if (orderType == OP_BUY) {
      price = NormalizeDouble(liveAsk, digits);
      sl    = NormalizeDouble(liveAsk - slPips * pipSz, digits);
   } else {
      price = NormalizeDouble(liveBid, digits);
      sl    = NormalizeDouble(liveBid + slPips * pipSz, digits);
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
      // Wspólny SL = entry poprzedniej → przesuń WSZYSTKIE pozycje tego kierunku
      if (PyramidMoveSL) {
         long prev = FindPrevOrder(orderType, (long)ticket);
         if (prev > 0 && OrderSelect((int)prev, SELECT_BY_TICKET, MODE_TRADES)) {
            double commonSL = OrderOpenPrice();
            int    dg       = (int)MarketInfo(Symbol(), MODE_DIGITS);
            int    cnt      = 0;
            for (int m = 0; m < OrdersTotal(); m++) {
               if (!OrderSelect(m, SELECT_BY_POS, MODE_TRADES))  continue;
               if (OrderType()        != orderType)               continue;
               if (OrderMagicNumber() != MagicNumber)             continue;
               if (OrderTicket()      == ticket)                  continue;
               if (MathAbs(OrderStopLoss() - commonSL) < Point)  continue;
               if (OrderModify(OrderTicket(), OrderOpenPrice(), commonSL, OrderTakeProfit(), 0, CLR_NONE)) cnt++;
            }
            if (cnt > 0)
               Print("TLJ [ADD SL] wspólny SL=", DoubleToString(commonSL, dg), " (", cnt, " pozycji)");
         }
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
      if (StringFind(OrderComment(), "TLJ_PYR")   >= 0) continue; // to już dokładka
      if (StringFind(OrderComment(), "TLJ_GRID")  >= 0) continue; // siatki nie piramidujemy
      if (StringFind(OrderComment(), "TLJ Panel+") >= 0) continue; // ręczne dokładki nie piramidujemy

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

      // Krok: panel Stp > 0 → override; inaczej Faron (TP/N) lub stały PyramidPips
      double panelStp = StringToDouble(ObjectGetString(0, EDIT_PYR_STP, OBJPROP_TEXT));
      double stepPips;
      if (panelStp > 0) {
         stepPips = panelStp;
      } else if (PyramidDivisions >= 2 && parentTP > 0) {
         double tpDist = MathAbs(parentTP - entry) / pipSz;
         stepPips = tpDist / PyramidDivisions;
         if (stepPips < 1.0) stepPips = PyramidPips;
      } else {
         stepPips = PyramidPips;
      }

      double threshold = (pyrCount + 1.0) * stepPips;
      if (profitPips < threshold) continue;

      // SL dokładki = 1 interwał (Faron) lub SL parenta jako fallback
      double slPips = (PyramidDivisions >= 2 && parentTP > 0)
                      ? stepPips
                      : ((parentSL > 0) ? MathAbs(entry - parentSL) / pipSz : DefaultSLPips);
      if (slPips <= 0) slPips = DefaultSLPips;

      double lot = GetPiraLot(slPips);
      if (lot <= 0) continue;

      double openPrice, newSL;
      if (dir == OP_BUY) {
         openPrice = NormalizeDouble(MarketInfo(sym, MODE_ASK), digits);
         newSL     = NormalizeDouble(openPrice - slPips * pipSz, digits);
      } else {
         openPrice = NormalizeDouble(MarketInfo(sym, MODE_BID), digits);
         newSL     = NormalizeDouble(openPrice + slPips * pipSz, digits);
      }

      // TP dokładki = TP parenta (jeśli istnieje)
      double pyrTP = 0;
      if (parentTP > 0) pyrTP = parentTP;

      double sendSL2 = VirtualSLTP ? 0 : newSL;
      double sendTP2 = VirtualSLTP ? 0 : pyrTP;

      string comment = tag + "_L" + IntegerToString(pyrCount + 1);
      int newTicket = OrderSend(sym, dir, lot, openPrice, 3, sendSL2, sendTP2,
                                comment, MagicNumber, 0,
                                dir == OP_BUY ? clrLime : clrRed);
      if (newTicket > 0) {
         if (VirtualSLTP) {
            if (newSL > 0) GlobalVariableSet("VTLJ_SL_" + IntegerToString(newTicket), newSL);
            if (pyrTP > 0) GlobalVariableSet("VTLJ_TP_" + IntegerToString(newTicket), pyrTP);
         }
         Print("TLJ [PYRAMID L", pyrCount + 1, "] parent=#", ticket,
               " new=#", newTicket, " lot=", lot,
               " zysk=", DoubleToString(profitPips, 1), " pips",
               " tp=", DoubleToString(pyrTP, digits),
               VirtualSLTP ? " [STEALTH]" : "",
               " MoveSL=", PyramidMoveSL);
         if (!PyramidMoveSL) {
            Print("TLJ [PYRAMID] PyramidMoveSL=false — wspólny SL WYŁĄCZONY. Włącz w parametrach EA.");
         } else {
            // Wspólny SL = entry poprzedniej → przesuń parenta i WSZYSTKIE jego dokładki
            long prevTicket = ticket; // domyślnie parent (dla L1)
            if (pyrCount > 0) {
               string prevTag = tag + "_L" + IntegerToString(pyrCount);
               for (int k = 0; k < OrdersTotal(); k++) {
                  if (!OrderSelect(k, SELECT_BY_POS, MODE_TRADES)) continue;
                  if (StringFind(OrderComment(), prevTag) >= 0) { prevTicket = OrderTicket(); break; }
               }
            }
            if (OrderSelect((int)prevTicket, SELECT_BY_TICKET, MODE_TRADES))
               MoveAllPyrSLToCommon(ticket, dir, OrderOpenPrice());
            else
               Print("TLJ [PYRAMID] Nie znaleziono poprzedniego zlecenia (prevTicket=", prevTicket, ")");
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

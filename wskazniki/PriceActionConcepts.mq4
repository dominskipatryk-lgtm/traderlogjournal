//+------------------------------------------------------------------+
//|  PriceActionConcepts.mq4                                         |
//|  MQL4 | BOS/CHoCH/CHoCH+ | OBs | FVG | EQH/L | Prem/Disc | TLZ |
//+------------------------------------------------------------------+
#property copyright "TraderLogJournal"
#property link      "https://traderlogjournal.com"
#property version   "1.20"
#property strict
#property indicator_chart_window

//═══════════════════════════════════════════════════════════════════
// INPUTS
//═══════════════════════════════════════════════════════════════════
input string _S1        = "══ Market Structure ══";
input int    IntLen      = 3;
input int    SwgLen      = 10;
input int    MSIntMode   = 0;   // 0=BOS+CHoCH  1=BOS  2=Off
input int    MSSwgMode   = 0;
input bool   ShowEQHL    = true;
input double EQThresh    = 0.05;

input string _S2        = "══ Order Blocks ══";
input bool   ShowIntOB   = true;
input int    MaxIntOB    = 5;
input bool   ShowSwgOB   = true;
input int    MaxSwgOB    = 3;
input int    OBMitMethod = 0;   // 0=Close  1=Wick  2=Average
input bool   ShowMetrics = true;
input color  BullOBCol   = C'8,153,129';
input color  BearOBCol   = C'242,54,69';

input string _S3        = "══ Fair Value Gaps ══";
input bool   ShowFVG     = true;
input int    MaxFVG      = 5;

input string _S4        = "══ Premium / Discount ══";
input bool   ShowPD      = true;

input string _S5        = "══ Trend Line Zones ══";
input bool   ShowTLZ     = true;
input color  BullTLZCol  = C'0,150,100';
input color  BearTLZCol  = C'200,50,60';

input string _S6        = "══ Panel ══";
input int    PanelX      = 20;
input int    PanelY      = 30;

//═══════════════════════════════════════════════════════════════════
// DEFINES
//═══════════════════════════════════════════════════════════════════
#define MAX_EV   400
#define MAX_OB   300
#define MAX_FV   150
#define MAX_EQ   100
#define MAX_SW   100
#define P        "PAC_"

#define BT_MSINT P"bMSInt"
#define BT_MSSWG P"bMSSWg"
#define BT_OBINT P"bOBInt"
#define BT_OBSWG P"bOBSwg"
#define BT_EQHL  P"bEQHL"
#define BT_FVG   P"bFVG"
#define BT_PD    P"bPD"
#define BT_TLZ   P"bTLZ"
#define BT_RESET P"bReset"

#define EV_BOS_U   1
#define EV_BOS_D  -1
#define EV_CHCH_U  2
#define EV_CHCH_D -2
#define EV_CHCP_U  3
#define EV_CHCP_D -3

//═══════════════════════════════════════════════════════════════════
// STRUCTS
//═══════════════════════════════════════════════════════════════════
struct Ev {
   datetime tBreak, tLevel;
   double   level;
   int      type;
   bool     isSwing;
};
struct OBD {
   double   top, btm;
   datetime t0;
   double   volPct;
   bool     bull, isSwing, mit;
};
struct FVD {
   double   top, btm;
   datetime t0;
   bool     bull, mit;
};
struct EqD {
   double   price;
   datetime t0;
   bool     isHigh;
};

//═══════════════════════════════════════════════════════════════════
// STATE — Internal MS
//═══════════════════════════════════════════════════════════════════
int      iDir     = 0;
double   iBosHi   = EMPTY_VALUE;
double   iBosLo   = DBL_MAX;
datetime iBosHiT  = 0, iBosLoT = 0;
int      iBosHiBar= -1, iBosLoBar = -1;
double   iChHi    = EMPTY_VALUE, iChLo = DBL_MAX;
datetime iChHiT   = 0, iChLoT = 0;
bool     iCfHl    = false, iCfLh = false;
double   iPrevC   = EMPTY_VALUE;

// STATE — Swing MS
int      sDir     = 0;
double   sBosHi   = EMPTY_VALUE;
double   sBosLo   = DBL_MAX;
datetime sBosHiT  = 0, sBosLoT = 0;
int      sBosHiBar= -1, sBosLoBar = -1;
double   sChHi    = EMPTY_VALUE, sChLo = DBL_MAX;
datetime sChHiT   = 0, sChLoT = 0;
bool     sCfHl    = false, sCfLh = false;
double   sPrevC   = EMPTY_VALUE;

// Swing point arrays (for trend lines)
double   iHiPx[MAX_SW], iLoPx[MAX_SW];
datetime iHiPt[MAX_SW], iLoPt[MAX_SW];
int      iHiCnt = 0, iLoCnt = 0;

double   sHiPx[MAX_SW], sLoPx[MAX_SW];
datetime sHiPt[MAX_SW], sLoPt[MAX_SW];
int      sHiCnt = 0, sLoCnt = 0;

// Data
Ev  gEvs[MAX_EV]; int gEvCnt = 0;
OBD gOBs[MAX_OB]; int gOBCnt = 0;
FVD gFVs[MAX_FV]; int gFVCnt = 0;
EqD gEqs[MAX_EQ]; int gEqCnt = 0;

// Draw tracking
string gDr[MAX_OB*3 + MAX_EV*2 + 60];
int    gDrCnt = 0;

// Toggles
bool tMSInt=true, tMSSWg=true, tOBInt=true, tOBSWg=true;
bool tEQHL=true,  tFVG=true,   tPD=true,    tTLZ=true;
bool gFRec=false;

//═══════════════════════════════════════════════════════════════════
int OnInit() {
   tMSInt=(MSIntMode<2); tMSSWg=(MSSwgMode<2);
   tOBInt=ShowIntOB; tOBSWg=ShowSwgOB;
   tEQHL=ShowEQHL; tFVG=ShowFVG; tPD=ShowPD; tTLZ=ShowTLZ;
   ClearAll(); CreatePanel();
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r) { DelDraw(); DelPanel(); }

void ClearAll() {
   iDir=0; iBosHi=EMPTY_VALUE; iBosLo=DBL_MAX;
   iBosHiT=0; iBosLoT=0; iBosHiBar=-1; iBosLoBar=-1;
   iChHi=EMPTY_VALUE; iChLo=DBL_MAX; iChHiT=0; iChLoT=0;
   iCfHl=false; iCfLh=false; iPrevC=EMPTY_VALUE;
   sDir=0; sBosHi=EMPTY_VALUE; sBosLo=DBL_MAX;
   sBosHiT=0; sBosLoT=0; sBosHiBar=-1; sBosLoBar=-1;
   sChHi=EMPTY_VALUE; sChLo=DBL_MAX; sChHiT=0; sChLoT=0;
   sCfHl=false; sCfLh=false; sPrevC=EMPTY_VALUE;
   gEvCnt=0; gOBCnt=0; gFVCnt=0; gEqCnt=0;
   iHiCnt=0; iLoCnt=0; sHiCnt=0; sLoCnt=0;
}

//═══════════════════════════════════════════════════════════════════
int OnCalculate(const int rt, const int pc,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[],
                const double &close[], const long &tvol[],
                const long &vol[], const int &sp[]) {

   if (rt < SwgLen*2+5) return 0;
   bool full = (pc==0 || gFRec);
   if (full) { ClearAll(); gFRec=false; DelDraw(); }
   int start = full ? SwgLen*2 : MathMax(pc-1, SwgLen*2);

   for (int i=start; i<rt; i++) {
      int ipb = i - IntLen;
      int spb = i - SwgLen;

      // ── Internal pivots ──────────────────────────────────────────
      if (ipb >= IntLen) {
         double ph = PivH(high, ipb, IntLen, rt);
         double pl = PivL(low,  ipb, IntLen, rt);
         if (ph > 0) {
            PushArr(iHiPx, iHiPt, iHiCnt, ph, time[ipb]);
            OnIntHigh(ph, time[ipb], ipb);
            if (iHiCnt>=2) ChkEq(ph, time[ipb], true);
         }
         if (pl > 0) {
            PushArr(iLoPx, iLoPt, iLoCnt, pl, time[ipb]);
            OnIntLow(pl, time[ipb], ipb);
            if (iLoCnt>=2) ChkEq(pl, time[ipb], false);
         }
      }

      // ── Swing pivots ─────────────────────────────────────────────
      if (spb >= SwgLen) {
         double ph = PivH(high, spb, SwgLen, rt);
         double pl = PivL(low,  spb, SwgLen, rt);
         if (ph > 0) { PushArr(sHiPx, sHiPt, sHiCnt, ph, time[spb]); OnSwgHigh(ph, time[spb], spb); }
         if (pl > 0) { PushArr(sLoPx, sLoPt, sLoCnt, pl, time[spb]); OnSwgLow (pl, time[spb], spb); }
      }

      double c = close[i];

      // ── Internal BOS/CHoCH ───────────────────────────────────────
      if (iPrevC != EMPTY_VALUE && MSIntMode < 2)
         ProcMS_Int(i, c, iPrevC, time, open, high, low, close, tvol, rt);
      iPrevC = c;

      // ── Swing BOS/CHoCH ──────────────────────────────────────────
      if (sPrevC != EMPTY_VALUE && MSSwgMode < 2)
         ProcMS_Swg(i, c, sPrevC, time, open, high, low, close, tvol, rt);
      sPrevC = c;

      // ── FVG ──────────────────────────────────────────────────────
      if (ShowFVG && i>=2 && gFVCnt<MAX_FV) {
         if (low[i] > high[i-2]) {
            gFVs[gFVCnt].top=low[i]; gFVs[gFVCnt].btm=high[i-2];
            gFVs[gFVCnt].t0=time[i-1]; gFVs[gFVCnt].bull=true; gFVs[gFVCnt].mit=false; gFVCnt++;
         }
         if (gFVCnt<MAX_FV && high[i] < low[i-2]) {
            gFVs[gFVCnt].top=low[i-2]; gFVs[gFVCnt].btm=high[i];
            gFVs[gFVCnt].t0=time[i-1]; gFVs[gFVCnt].bull=false; gFVs[gFVCnt].mit=false; gFVCnt++;
         }
      }

      // ── Mitigation ───────────────────────────────────────────────
      for (int k=0; k<gOBCnt; k++) {
         if (gOBs[k].mit) continue;
         bool mit=false;
         if (OBMitMethod==0) mit = gOBs[k].bull ? close[i]<gOBs[k].btm : close[i]>gOBs[k].top;
         if (OBMitMethod==1) mit = gOBs[k].bull ? low[i]  <gOBs[k].btm : high[i] >gOBs[k].top;
         if (OBMitMethod==2) { double avg=(gOBs[k].top+gOBs[k].btm)/2.0; mit=gOBs[k].bull?close[i]<avg:close[i]>avg; }
         if (mit) gOBs[k].mit=true;
      }
      for (int k=0; k<gFVCnt; k++) {
         if (gFVs[k].mit) continue;
         if ( gFVs[k].bull && low[i]  < gFVs[k].btm) gFVs[k].mit=true;
         if (!gFVs[k].bull && high[i] > gFVs[k].top) gFVs[k].mit=true;
      }
   }

   if (gOBCnt>250) CompactOBs();
   if (gFVCnt>120) CompactFVs();
   DrawAll(time, high, low, rt);
   return rt;
}

//═══════════════════════════════════════════════════════════════════
// PIVOT UPDATE — Internal
//═══════════════════════════════════════════════════════════════════
void OnIntHigh(double px, datetime t, int bar) {
   if (iDir >= 0) { // bull / undefined: update BOS high
      if (iBosHi==EMPTY_VALUE || px>iBosHi) { iBosHi=px; iBosHiT=t; iBosHiBar=bar; }
   }
   if (iDir < 0) { // bear: update CHoCH level
      if (iChHi==EMPTY_VALUE || px>iChHi) { iChHi=px; iChHiT=t; }
      if (iChHi!=EMPTY_VALUE && px<iChHi)  iCfLh=true;
   }
}
void OnIntLow(double px, datetime t, int bar) {
   if (iDir <= 0) { // bear / undefined: update BOS low
      if (iBosLo==DBL_MAX || px<iBosLo) { iBosLo=px; iBosLoT=t; iBosLoBar=bar; }
   }
   if (iDir > 0) { // bull: update CHoCH level
      if (iChLo==DBL_MAX || px<iChLo) { iChLo=px; iChLoT=t; }
      if (iChLo!=DBL_MAX && px>iChLo) iCfHl=true;
   }
}

// ── Swing
void OnSwgHigh(double px, datetime t, int bar) {
   if (sDir >= 0) { if (sBosHi==EMPTY_VALUE||px>sBosHi) { sBosHi=px; sBosHiT=t; sBosHiBar=bar; } }
   if (sDir < 0)  { if (sChHi==EMPTY_VALUE||px>sChHi)   { sChHi=px; sChHiT=t; }
                    if (sChHi!=EMPTY_VALUE&&px<sChHi)    sCfLh=true; }
}
void OnSwgLow(double px, datetime t, int bar) {
   if (sDir <= 0) { if (sBosLo==DBL_MAX||px<sBosLo) { sBosLo=px; sBosLoT=t; sBosLoBar=bar; } }
   if (sDir > 0)  { if (sChLo==DBL_MAX||px<sChLo)   { sChLo=px; sChLoT=t; }
                    if (sChLo!=DBL_MAX&&px>sChLo)    sCfHl=true; }
}

//═══════════════════════════════════════════════════════════════════
// MARKET STRUCTURE PROCESSING
//═══════════════════════════════════════════════════════════════════
void ProcMS_Int(int i, double c, double prevC,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[],
                const double &close[], const long &tvol[], int rt) {
   // Bullish break
   if (iBosHi!=EMPTY_VALUE && prevC<=iBosHi && c>iBosHi) {
      int et = (iDir>=0) ? EV_BOS_U : (iCfHl ? EV_CHCP_U : EV_CHCH_U);
      EmitEv(time[i], iBosHiT, iBosHi, et, false);
      AddOB(time, open, high, low, close, tvol, i, iBosHiBar, rt, true, false);
      iDir=1; iBosHi=EMPTY_VALUE; iCfHl=false; iCfLh=false;
      if (et!=EV_BOS_U) { iChLo=DBL_MAX; iChLoT=0; }
   }
   // Bearish break
   if (iBosLo!=DBL_MAX && prevC>=iBosLo && c<iBosLo) {
      int et = (iDir<=0) ? EV_BOS_D : (iCfLh ? EV_CHCP_D : EV_CHCH_D);
      EmitEv(time[i], iBosLoT, iBosLo, et, false);
      AddOB(time, open, high, low, close, tvol, i, iBosLoBar, rt, false, false);
      iDir=-1; iBosLo=DBL_MAX; iCfHl=false; iCfLh=false;
      if (et!=EV_BOS_D) { iChHi=EMPTY_VALUE; iChHiT=0; }
   }
}

void ProcMS_Swg(int i, double c, double prevC,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[],
                const double &close[], const long &tvol[], int rt) {
   if (sBosHi!=EMPTY_VALUE && prevC<=sBosHi && c>sBosHi) {
      int et = (sDir>=0) ? EV_BOS_U : (sCfHl ? EV_CHCP_U : EV_CHCH_U);
      EmitEv(time[i], sBosHiT, sBosHi, et, true);
      AddOB(time, open, high, low, close, tvol, i, sBosHiBar, rt, true, true);
      sDir=1; sBosHi=EMPTY_VALUE; sCfHl=false; sCfLh=false;
      if (et!=EV_BOS_U) { sChLo=DBL_MAX; sChLoT=0; }
   }
   if (sBosLo!=DBL_MAX && prevC>=sBosLo && c<sBosLo) {
      int et = (sDir<=0) ? EV_BOS_D : (sCfLh ? EV_CHCP_D : EV_CHCH_D);
      EmitEv(time[i], sBosLoT, sBosLo, et, true);
      AddOB(time, open, high, low, close, tvol, i, sBosLoBar, rt, false, true);
      sDir=-1; sBosLo=DBL_MAX; sCfHl=false; sCfLh=false;
      if (et!=EV_BOS_D) { sChHi=EMPTY_VALUE; sChHiT=0; }
   }
}

void EmitEv(datetime tBreak, datetime tLevel, double level, int type, bool isSwing) {
   if (gEvCnt>=MAX_EV) return;
   gEvs[gEvCnt].tBreak=tBreak; gEvs[gEvCnt].tLevel=tLevel;
   gEvs[gEvCnt].level=level;   gEvs[gEvCnt].type=type;
   gEvs[gEvCnt].isSwing=isSwing; gEvCnt++;
}

void AddOB(const datetime &time[], const double &open[],
           const double &high[], const double &low[],
           const double &close[], const long &tvol[],
           int bosBar, int pivBar, int rt, bool bull, bool isSwing) {
   if (gOBCnt>=MAX_OB || pivBar<0) return;
   int sLen = bosBar - pivBar;
   if (sLen<1) return;

   double obTop=EMPTY_VALUE, obBtm=EMPTY_VALUE;
   int    obIdx=-1; double obVol=0, totVol=0;

   for (int s=1; s<=sLen && (bosBar-s)>=0; s++) {
      int bi = bosBar-s;
      totVol += (double)tvol[bi];
      if (bull && close[bi]<open[bi]) {
         if (obTop==EMPTY_VALUE || low[bi]<obBtm) {
            obTop=high[bi]; obBtm=low[bi]; obIdx=bi; obVol=(double)tvol[bi];
         }
      }
      if (!bull && close[bi]>open[bi]) {
         if (obTop==EMPTY_VALUE || high[bi]>obTop) {
            obTop=high[bi]; obBtm=low[bi]; obIdx=bi; obVol=(double)tvol[bi];
         }
      }
   }
   if (obIdx<0) return;
   double pct = (totVol>0) ? MathRound(obVol/totVol*100.0*10.0)/10.0 : 0;

   gOBs[gOBCnt].top=obTop; gOBs[gOBCnt].btm=obBtm;
   gOBs[gOBCnt].t0=time[obIdx]; gOBs[gOBCnt].volPct=pct;
   gOBs[gOBCnt].bull=bull; gOBs[gOBCnt].isSwing=isSwing; gOBs[gOBCnt].mit=false;
   gOBCnt++;
}

void ChkEq(double px, datetime t, bool isHigh) {
   if (gEqCnt>=MAX_EQ) return;
   int cnt  = isHigh ? iHiCnt : iLoCnt;
   if (cnt<2) return;
   double prev  = isHigh ? iHiPx[iHiCnt-2] : iLoPx[iLoCnt-2];
   datetime prevT = isHigh ? iHiPt[iHiCnt-2] : iLoPt[iLoCnt-2];
   if (prev==0) return;
   double diff = MathAbs(px-prev)/prev*100.0;
   if (diff<=EQThresh) {
      for (int k=gEqCnt-1; k>=MathMax(0,gEqCnt-5); k--)
         if (MathAbs(gEqs[k].price-px)/px*100.0 < EQThresh*2) return;
      gEqs[gEqCnt].price=(px+prev)/2.0; gEqs[gEqCnt].t0=prevT;
      gEqs[gEqCnt].isHigh=isHigh; gEqCnt++;
   }
}

//═══════════════════════════════════════════════════════════════════
// DRAWING
//═══════════════════════════════════════════════════════════════════
void DrawAll(const datetime &time[], const double &high[], const double &low[], int rt) {
   DelDraw();
   datetime rE = TimeCurrent() + (datetime)(PeriodSeconds()*5);

   // ── Market Structure events ──────────────────────────────────────
   for (int k=0; k<gEvCnt; k++) {
      if ( gEvs[k].isSwing && !tMSSWg) continue;
      if (!gEvs[k].isSwing && !tMSInt) continue;
      if (MSIntMode==1 && !gEvs[k].isSwing && MathAbs(gEvs[k].type)>1) continue;
      if (MSSwgMode==1 &&  gEvs[k].isSwing && MathAbs(gEvs[k].type)>1) continue;

      bool bull = (gEvs[k].type>0);
      color lc  = bull ? BullOBCol : BearOBCol;
      int sty   = gEvs[k].isSwing ? STYLE_SOLID : STYLE_DASH;
      int wid   = gEvs[k].isSwing ? 2 : 1;

      T(MkLine(P"EL"+IntegerToString(k), gEvs[k].tLevel, gEvs[k].level,
               gEvs[k].tBreak, gEvs[k].level, lc, wid, sty));

      string lbl="";
      switch(gEvs[k].type) {
         case EV_BOS_U: case EV_BOS_D:   lbl="BOS";    break;
         case EV_CHCH_U: case EV_CHCH_D: lbl="CHoCH";  break;
         case EV_CHCP_U: case EV_CHCP_D: lbl="CHoCH+"; break;
      }
      double off = (bull?1.0:-1.0)*gEvs[k].level*0.0003;
      T(MkTxt(P"ET"+IntegerToString(k), gEvs[k].tBreak, gEvs[k].level+off, lbl, lc, gEvs[k].isSwing?9:8));
   }

   // ── EQH / EQL ────────────────────────────────────────────────────
   if (tEQHL) {
      for (int k=0; k<gEqCnt; k++) {
         color ec=C'150,160,175';
         T(MkLine(P"EQ"+IntegerToString(k), gEqs[k].t0, gEqs[k].price, rE, gEqs[k].price, ec, 1, STYLE_DOT));
         T(MkTxt (P"EQT"+IntegerToString(k), rE, gEqs[k].price, gEqs[k].isHigh?"EQH":"EQL", ec, 8));
      }
   }

   // ── Order Blocks ─────────────────────────────────────────────────
   int iDrawn=0, sDrawn=0;
   for (int k=gOBCnt-1; k>=0; k--) {
      if (gOBs[k].mit) continue;
      if ( gOBs[k].isSwing && (!tOBSWg || sDrawn>=MaxSwgOB)) continue;
      if (!gOBs[k].isSwing && (!tOBInt || iDrawn>=MaxIntOB)) continue;
      if (gOBs[k].isSwing) sDrawn++; else iDrawn++;

      color oc = gOBs[k].bull ? BullOBCol : BearOBCol;
      T(MkRect(P"OB"+IntegerToString(k), gOBs[k].t0, gOBs[k].top, rE, gOBs[k].btm,
               oc, gOBs[k].isSwing?2:1, true));
      if (ShowMetrics) {
         string vtxt = DoubleToString(gOBs[k].volPct,1)+"K ("+DoubleToString(gOBs[k].volPct,1)+"%)";
         T(MkTxt(P"OM"+IntegerToString(k), rE, (gOBs[k].top+gOBs[k].btm)/2.0, vtxt, oc, 8));
      }
   }

   // ── Fair Value Gaps ───────────────────────────────────────────────
   if (tFVG) {
      int fd=0;
      for (int k=gFVCnt-1; k>=0 && fd<MaxFVG; k--) {
         if (gFVs[k].mit) continue; fd++;
         color fc = gFVs[k].bull ? C'8,80,60' : C'80,20,30';
         T(MkRect(P"FV"+IntegerToString(k), gFVs[k].t0, gFVs[k].top, rE, gFVs[k].btm, fc, 1, true));
      }
   }

   // ── Premium / Discount ───────────────────────────────────────────
   if (tPD && sHiCnt>=1 && sLoCnt>=1) {
      double rHi = sHiPx[sHiCnt-1];
      double rLo = sLoPx[sLoCnt-1];
      if (rHi>rLo) {
         double eq = (rHi+rLo)/2.0;
         datetime pdT = time[MathMax(rt-150,0)];
         T(MkRect(P"PDDsc", pdT, eq,   rE, rLo,  C'8,55,40',   1, true));
         T(MkRect(P"PDPrm", pdT, rHi,  rE, eq,   C'65,18,22',  1, true));
         T(MkLine(P"PDEq",  pdT, eq,   rE, eq,   C'180,150,60',1, STYLE_DASH));
         T(MkTxt (P"PDPt",  rE,  rHi,  "Premium",  C'200,100,100', 7));
         T(MkTxt (P"PDEt",  rE,  eq,   "EQ",       C'200,180,60',  7));
         T(MkTxt (P"PDDt",  rE,  rLo,  "Discount", C'80,200,130',  7));
      }
   }

   // ── Trend Line Zones ─────────────────────────────────────────────
   if (tTLZ) {
      if (iLoCnt>=2) {
         double slope=(iLoPx[iLoCnt-1]-iLoPx[iLoCnt-2]);
         T(MkLine(P"TLZBI", iLoPt[iLoCnt-2], iLoPx[iLoCnt-2], rE,
                  iLoPx[iLoCnt-1]+slope*0.5, BullTLZCol, 2, STYLE_SOLID));
      }
      if (iHiCnt>=2) {
         double slope=(iHiPx[iHiCnt-1]-iHiPx[iHiCnt-2]);
         T(MkLine(P"TLZBI2", iHiPt[iHiCnt-2], iHiPx[iHiCnt-2], rE,
                  iHiPx[iHiCnt-1]+slope*0.5, BearTLZCol, 2, STYLE_SOLID));
      }
      if (sLoCnt>=2) {
         double slope=(sLoPx[sLoCnt-1]-sLoPx[sLoCnt-2]);
         T(MkLine(P"TLZBS", sLoPt[sLoCnt-2], sLoPx[sLoCnt-2], rE,
                  sLoPx[sLoCnt-1]+slope*0.5, BullTLZCol, 3, STYLE_SOLID));
      }
      if (sHiCnt>=2) {
         double slope=(sHiPx[sHiCnt-1]-sHiPx[sHiCnt-2]);
         T(MkLine(P"TLZBS2", sHiPt[sHiCnt-2], sHiPx[sHiCnt-2], rE,
                  sHiPx[sHiCnt-1]+slope*0.5, BearTLZCol, 3, STYLE_SOLID));
      }
   }

   ChartRedraw();
}

//═══════════════════════════════════════════════════════════════════
// HELPERS
//═══════════════════════════════════════════════════════════════════
double PivH(const double &h[],int idx,int len,int total) {
   if(idx-len<0||idx+len>=total) return 0;
   double v=h[idx];
   for(int i=1;i<=len;i++) if(h[idx-i]>=v||h[idx+i]>=v) return 0;
   return v;
}
double PivL(const double &l[],int idx,int len,int total) {
   if(idx-len<0||idx+len>=total) return 0;
   double v=l[idx];
   for(int i=1;i<=len;i++) if(l[idx-i]<=v||l[idx+i]<=v) return 0;
   return v;
}
void PushArr(double &px[],datetime &pt[],int &cnt,double p,datetime t) {
   if(cnt<MAX_SW){px[cnt]=p;pt[cnt]=t;cnt++;}
   else{for(int i=0;i<MAX_SW-1;i++){px[i]=px[i+1];pt[i]=pt[i+1];}px[MAX_SW-1]=p;pt[MAX_SW-1]=t;}
}
void CompactOBs(){int j=0;for(int i=0;i<gOBCnt;i++)if(!gOBs[i].mit)gOBs[j++]=gOBs[i];gOBCnt=j;}
void CompactFVs(){int j=0;for(int i=0;i<gFVCnt;i++)if(!gFVs[i].mit)gFVs[j++]=gFVs[i];gFVCnt=j;}

string MkRect(string n,datetime t1,double p1,datetime t2,double p2,color clr,int w,bool back){
   ObjectCreate(0,n,OBJ_RECTANGLE,0,t1,p1,t2,p2);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);ObjectSetInteger(0,n,OBJPROP_WIDTH,w);
   ObjectSetInteger(0,n,OBJPROP_BACK,back);ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);return n;}
string MkLine(string n,datetime t1,double p1,datetime t2,double p2,color clr,int w,int sty){
   ObjectCreate(0,n,OBJ_TREND,0,t1,p1,t2,p2);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);ObjectSetInteger(0,n,OBJPROP_WIDTH,w);
   ObjectSetInteger(0,n,OBJPROP_STYLE,sty);ObjectSetInteger(0,n,OBJPROP_RAY,false);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);return n;}
string MkTxt(string n,datetime t,double p,string txt,color clr,int fs){
   ObjectCreate(0,n,OBJ_TEXT,0,t,p);
   ObjectSetString (0,n,OBJPROP_TEXT,txt);ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fs);ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);return n;}

void T(string n){if(gDrCnt<ArraySize(gDr))gDr[gDrCnt++]=n;}
void DelDraw()  {for(int i=0;i<gDrCnt;i++)ObjectDelete(0,gDr[i]);gDrCnt=0;}

//═══════════════════════════════════════════════════════════════════
// PANEL
//═══════════════════════════════════════════════════════════════════
void CreatePanel(){
   DelPanel();
   int w=216,h=330,x=PanelX,y=PanelY;
   PnlRect(P"Bg",x,y,w,h,C'13,17,23',C'30,45,61');
   PnlLbl(P"T1",x+10,y+9,"Price Action",   C'0,212,161', 10,true);
   PnlLbl(P"T2",x+117,y+9,"Concepts",      C'100,120,135',10,false);
   PnlLbl(P"T3",x+10,y+26,"v1.2 | TraderLogJournal",C'45,65,80',7,false);
   PnlSep(P"S1",x+8,y+40,w-16);
   PnlLbl(P"TH",x+10,y+48,"TOGGLE FEATURES",C'74,96,117',7,false);
   PnlToggle(BT_MSINT,x+8,y+62, w-16,24,"Market Structure Internal",tMSInt);
   PnlToggle(BT_MSSWG,x+8,y+90, w-16,24,"Market Structure Swing",   tMSSWg);
   PnlToggle(BT_OBINT,x+8,y+118,w-16,24,"Order Blocks Internal",    tOBInt);
   PnlToggle(BT_OBSWG,x+8,y+146,w-16,24,"Order Blocks Swing",       tOBSWg);
   PnlToggle(BT_EQHL, x+8,y+174,w-16,24,"EQH / EQL",               tEQHL);
   PnlToggle(BT_FVG,  x+8,y+202,w-16,24,"Fair Value Gaps",          tFVG);
   PnlToggle(BT_PD,   x+8,y+230,w-16,24,"Premium / Discount",       tPD);
   PnlToggle(BT_TLZ,  x+8,y+258,w-16,24,"Trend Line Zones",         tTLZ);
   PnlSep(P"S2",x+8,y+287,w-16);
   PnlBtn(BT_RESET,x+8,y+292,w-16,16,"Reset & Recalculate",
          C'25,35,48',C'100,120,135',C'45,63,80',7);
   ChartRedraw();
}
void DelPanel(){
   string pn[]={P"Bg",P"T1",P"T2",P"T3",P"TH",P"S1",P"S2",
                BT_MSINT,BT_MSSWG,BT_OBINT,BT_OBSWG,
                BT_EQHL,BT_FVG,BT_PD,BT_TLZ,BT_RESET};
   for(int i=0;i<ArraySize(pn);i++) ObjectDelete(0,pn[i]);
}
void PnlRect(string n,int x,int y,int w,int h,color bg,color brd){
   ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);    ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg); ObjectSetInteger(0,n,OBJPROP_COLOR,brd);
   ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,n,OBJPROP_ZORDER,0);}
void PnlLbl(string n,int x,int y,string txt,color clr,int fs=8,bool bold=false){
   ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString (0,n,OBJPROP_TEXT,txt);     ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fs);  ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,n,OBJPROP_ZORDER,5);
   if(bold) ObjectSetString(0,n,OBJPROP_FONT,"Arial Bold");}
void PnlSep(string n,int x,int y,int w){
   ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);    ObjectSetInteger(0,n,OBJPROP_YSIZE,1);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,C'30,45,61');ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,5);}
void PnlBtn(string n,int x,int y,int w,int h,string txt,color bg,color fg,color brd,int fs){
   ObjectCreate(0,n,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);        ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetString (0,n,OBJPROP_TEXT,txt);        ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,n,OBJPROP_COLOR,fg);        ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,brd);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fs);     ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,n,OBJPROP_ZORDER,10);}
void PnlToggle(string n,int x,int y,int w,int h,string txt,bool on){
   PnlBtn(n,x,y,w,h,(on?"  ✔  ":"  ✘  ")+txt,
          on?C'0,60,45':C'20,28,38',on?C'0,212,161':C'74,96,117',on?C'0,120,90':C'40,56,72',8);}
void UpdTgl(string n,bool on,string txt){
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,     on?C'0,60,45':C'20,28,38');
   ObjectSetInteger(0,n,OBJPROP_COLOR,       on?C'0,212,161':C'74,96,117');
   ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,on?C'0,120,90':C'40,56,72');
   ObjectSetString (0,n,OBJPROP_TEXT,        (on?"  ✔  ":"  ✘  ")+txt);}

//═══════════════════════════════════════════════════════════════════
void OnChartEvent(const int id,const long &lp,const double &dp,const string &sp){
   if(id!=CHARTEVENT_OBJECT_CLICK) return;
   if      (sp==BT_MSINT){tMSInt=!tMSInt;UpdTgl(BT_MSINT,tMSInt,"Market Structure Internal");}
   else if (sp==BT_MSSWG){tMSSWg=!tMSSWg;UpdTgl(BT_MSSWG,tMSSWg,"Market Structure Swing");}
   else if (sp==BT_OBINT){tOBInt=!tOBInt;UpdTgl(BT_OBINT,tOBInt,"Order Blocks Internal");}
   else if (sp==BT_OBSWG){tOBSWg=!tOBSWg;UpdTgl(BT_OBSWG,tOBSWg,"Order Blocks Swing");}
   else if (sp==BT_EQHL) {tEQHL =!tEQHL; UpdTgl(BT_EQHL, tEQHL, "EQH / EQL");}
   else if (sp==BT_FVG)  {tFVG  =!tFVG;  UpdTgl(BT_FVG,  tFVG,  "Fair Value Gaps");}
   else if (sp==BT_PD)   {tPD   =!tPD;   UpdTgl(BT_PD,   tPD,   "Premium / Discount");}
   else if (sp==BT_TLZ)  {tTLZ  =!tTLZ;  UpdTgl(BT_TLZ,  tTLZ,  "Trend Line Zones");}
   else if (sp==BT_RESET){gFRec=true;}
   else return;
   ObjectSetInteger(0,sp,OBJPROP_STATE,false);
   ChartRedraw();
}

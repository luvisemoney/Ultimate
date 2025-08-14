//+------------------------------------------------------------------+
//|                                               CascadeGreepMaster |
//|                                   Copyright 2025 Cascade (AI)    |
//|         Purpose: Publish per-symbol risk/SL/cooldown multipliers |
//|                  based on News, Volatility, and Equity regimes.  |
//+------------------------------------------------------------------+
#property copyright "Cascade AI"
#property link      "https://windsurf.ai"
#property version   "1.0"
#property strict

#include <Trade/Trade.mqh>

//==================== Inputs ====================
input group           "Symbols"
input string          InpSymbols                 = "EURUSD;AUDUSD;USDCAD;USDJPY;XAUUSD"; // semicolon-separated
input string          InpGVNamespace             = "CGreep"; // base for global variables
input int             InpUpdateSeconds           = 60;       // update frequency

input group           "News Regime"
input bool            InpUseNews                 = true;
input int             InpNewsWindowBeforeMin     = 60;       // minutes before event
input int             InpNewsWindowAfterMin      = 15;       // minutes after event
input double          InpNewsWeightLow           = 0.85;     // min risk factor near low-impact
input double          InpNewsWeightMedium        = 0.60;     // min risk factor near medium-impact
input double          InpNewsWeightHigh          = 0.30;     // min risk factor near high-impact

input group           "Volatility Regime (ATR)"
input bool            InpUseVolatility           = true;
input ENUM_TIMEFRAMES InpVolTF                   = PERIOD_H1;
input int             InpATRPeriod               = 14;
input int             InpATRAvgLookback          = 100;      // bars for average ATR baseline
input double          InpVolMinRiskFactor        = 0.50;     // floor when volatility is extreme
input bool            InpVolAllowUpsize          = false;    // allow >1.0 risk factor in very low vol

input group           "Equity Regime"
input bool            InpUseEquity               = true;
input double          InpDailyLossSoftPercent    = 1.0;      // when daily DD >= this, reduce risk
input double          InpEquityMinRiskFactor     = 0.50;     // floor under soft daily DD
input bool            InpEquityAllowUpsize       = false;    // allow >1.0 on strong daily profit
input double          InpDailyWinBoostCap        = 1.10;     // max upsize if allowed

input group           "Composition & Publishing"
input double          InpMinRiskFactor           = 0.20;     // global floor
input double          InpMaxRiskFactor           = 1.00;     // global cap
input double          InpSLMultGainOnCut         = 1.00;     // sl_mult = 1 + gain*(1-risk_factor)
input double          InpCooldownGainOnCut       = 2.00;     // cooldown_mult = 1 + gain*(1-risk_factor)

input group           "XAU Overrides"
input double          InpXAU_NewsWeightLow       = 0.80;     // XAU: min risk factor near low-impact
input double          InpXAU_NewsWeightMedium    = 0.50;     // XAU: medium-impact
input double          InpXAU_NewsWeightHigh      = 0.25;     // XAU: high-impact
input int             InpXAU_NewsWindowBeforeMin = 90;       // XAU: minutes before
input int             InpXAU_NewsWindowAfterMin  = 30;       // XAU: minutes after
input double          InpXAU_VolMinRiskFactor    = 0.35;     // XAU: stronger cut under high vol
input bool            InpXAU_VolAllowUpsize      = false;    // XAU: no upsize on low vol
input double          InpXAU_MinRiskFactor       = 0.30;     // XAU: global floor
input double          InpXAU_SLMultGainOnCut     = 1.50;     // XAU: widen SL more when cut
input double          InpXAU_CooldownGainOnCut   = 3.00;     // XAU: longer cooldown when cut

//==================== Globals ====================
string   g_symbols[];
int      g_day_key=0;
double   g_day_equity_start=0.0;

//==================== Utils ====================
void TrimString(string &s)
{
   int start=0; while(start<StringLen(s) && StringGetCharacter(s,start)<=32) start++;
   int end=StringLen(s)-1; while(end>=0 && StringGetCharacter(s,end)<=32) end--;
   if(end<start) { s=""; return; }
   s=StringSubstr(s,start,end-start+1);
}

void Split(const string src, const string delim, string &out[])
{
   ArrayResize(out,0);
   int pos=0, last=0; int dlen=StringLen(delim);
   while((pos=StringFind(src,delim,last))!=-1)
   {
      string token=StringSubstr(src,last,pos-last);
      TrimString(token);
      if(StringLen(token)>0) {
         int n=ArraySize(out); ArrayResize(out,n+1); out[n]=token;
      }
      last=pos+dlen;
   }
   string tail=StringSubstr(src,last);
   TrimString(tail);
   if(StringLen(tail)>0) { int n=ArraySize(out); ArrayResize(out,n+1); out[n]=tail; }
}

int TodayKey()
{
   MqlDateTime dt; TimeToStruct(TimeTradeServer(), dt);
   return dt.year*10000+dt.mon*100+dt.day;
}

void DailyResetIfNeeded()
{
   int key=TodayKey();
   if(key!=g_day_key)
   {
      g_day_key=key;
      g_day_equity_start=AccountInfoDouble(ACCOUNT_EQUITY);
      Print("[MASTER] New day baseline equity=", g_day_equity_start);
   }
}

string Ccy1(const string sym)
{
   if(StringLen(sym)>=3) return StringSubstr(sym,0,3);
   return "";
}
string Ccy2(const string sym)
{
   if(StringLen(sym)>=6) return StringSubstr(sym,3,3);
   return "";
}

// clamp helper
double Clamp(const double v, const double lo, const double hi) { return MathMax(lo, MathMin(hi, v)); }

bool SymbolIsXAU(const string sym)
{
   return (StringFind(sym, "XAU", 0) >= 0 || StringFind(sym, "GOLD", 0) >= 0);
}

//==================== Calendar & News ====================
double ImpactWeightWeighted(const int importance, const double wLow, const double wMed, const double wHigh)
{
   // 0=low,1=medium,2=high in most terminals; fallback to medium otherwise
   if(importance<=0) return wLow;
   if(importance==1) return wMed;
   return wHigh;
}

double NewsFactorForCurrencyWeighted(const string ccy,
                                     const int beforeMin,
                                     const int afterMin,
                                     const double wLow,
                                     const double wMed,
                                     const double wHigh)
{
   if(!InpUseNews || StringLen(ccy)==0) return 1.0;
   datetime now = TimeTradeServer();
   datetime from = now - afterMin*60;
   datetime to   = now + beforeMin*60;
   MqlCalendarValue vals[]; ArrayFree(vals);
   ResetLastError();
   int n = CalendarValueHistory(vals, from, to, NULL, ccy);
   if(n<=0)
   {
      int err=GetLastError();
      if(err!=0) PrintFormat("[MASTER] CalendarValueHistory returned %d (err=%d) for %s", n, err, ccy);
      return 1.0; // neutral if not available
   }
   double factor=1.0;
   for(int i=0;i<n;i++)
   {
      MqlCalendarValue v = vals[i];
      ulong eid = v.event_id;
      MqlCalendarEvent evt; if(!CalendarEventById((long)eid, evt)) continue;
      double w = ImpactWeightWeighted((int)evt.importance, wLow, wMed, wHigh);
      // proximity scaling
      int minutes = (int)MathRound((double)(v.time - now) / 60.0);
      double prox=0.0; // 0 outside windows, 1 at event time
      if(minutes>=0 && minutes<=beforeMin)
         prox = (double)(beforeMin - minutes)/beforeMin;
      else if(minutes<0 && -minutes<=afterMin)
         prox = (double)(afterMin - (-minutes))/afterMin;
      else
         continue;
      double event_factor = 1.0 - (1.0 - w) * prox; // ramps from 1 -> w as prox->1
      factor = MathMin(factor, event_factor);
   }
   return factor;
}

//==================== Volatility (ATR) ====================
bool CopyOne(const int handle, const int buffer, const int shift, double &out)
{
   double tmp[]; int r=CopyBuffer(handle,buffer,shift,1,tmp);
   if(r!=1) return false; out=tmp[0]; return true;
}

double VolatilityFactorForSymbolParams(const string sym, const double volMinRiskFactor, const bool allowUpsize)
{
   if(!InpUseVolatility) return 1.0;
   int hATR = iATR(sym, InpVolTF, InpATRPeriod);
   if(hATR==INVALID_HANDLE) return 1.0;
   double currATR; if(!CopyOne(hATR,0,1,currATR)) { IndicatorRelease(hATR); return 1.0; }
   int n = InpATRAvgLookback;
   double arr[]; int got = CopyBuffer(hATR,0,1,n,arr);
   IndicatorRelease(hATR);
   if(got<=10) return 1.0;
   double sum=0; int cnt=0; for(int i=0;i<got;i++){ if(arr[i]>0){ sum+=arr[i]; cnt++; }}
   if(cnt==0) return 1.0;
   double avg = sum/cnt;
   double ratio = (avg>0 ? currATR/avg : 1.0);
   // higher ATR -> reduce risk; lower ATR -> optionally allow slight upsize
   double f = 1.0/MathSqrt(MathMax(0.0001, ratio));
   if(!allowUpsize) f = MathMin(1.0, f);
   f = Clamp(f, volMinRiskFactor, InpMaxRiskFactor);
   return f;
}

//==================== Equity Regime ====================
double EquityFactor()
{
   if(!InpUseEquity) return 1.0;
   if(g_day_equity_start<=0) return 1.0;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double ddpct = (g_day_equity_start - eq)/g_day_equity_start * 100.0;
   if(ddpct >= InpDailyLossSoftPercent)
      return Clamp(InpEquityMinRiskFactor, InpMinRiskFactor, InpMaxRiskFactor);
   // optional upsize on strong day
   double profitpct = (eq - g_day_equity_start)/g_day_equity_start * 100.0;
   if(InpEquityAllowUpsize && profitpct>=1.0)
      return Clamp(InpDailyWinBoostCap, InpMinRiskFactor, InpMaxRiskFactor);
   return 1.0;
}

//==================== Compose & Publish ====================
void PublishForSymbol(const string sym)
{
   string c1=Ccy1(sym), c2=Ccy2(sym);
   bool isXAU = SymbolIsXAU(sym);
   double rf=1.0;
   if(InpUseNews)
   {
      if(isXAU)
      {
         // Use USD-side news primarily for XAUUSD
         double nf_usd = NewsFactorForCurrencyWeighted("USD",
                                   InpXAU_NewsWindowBeforeMin,
                                   InpXAU_NewsWindowAfterMin,
                                   InpXAU_NewsWeightLow,
                                   InpXAU_NewsWeightMedium,
                                   InpXAU_NewsWeightHigh);
         rf = MathMin(rf, nf_usd);
      }
      else
      {
         double nf1 = NewsFactorForCurrencyWeighted(c1, InpNewsWindowBeforeMin, InpNewsWindowAfterMin,
                                                    InpNewsWeightLow, InpNewsWeightMedium, InpNewsWeightHigh);
         double nf2 = NewsFactorForCurrencyWeighted(c2, InpNewsWindowBeforeMin, InpNewsWindowAfterMin,
                                                    InpNewsWeightLow, InpNewsWeightMedium, InpNewsWeightHigh);
         rf = MathMin(rf, nf1);
         rf = MathMin(rf, nf2);
      }
   }
   double vf = VolatilityFactorForSymbolParams(sym, isXAU ? InpXAU_VolMinRiskFactor : InpVolMinRiskFactor,
                                               isXAU ? InpXAU_VolAllowUpsize : InpVolAllowUpsize);
   rf = MathMin(rf, vf);
   double ef = EquityFactor(); rf = MathMin(rf, ef);
   double floor_rf = isXAU ? InpXAU_MinRiskFactor : InpMinRiskFactor;
   rf = Clamp(rf, floor_rf, InpMaxRiskFactor);

   double sl_gain = isXAU ? InpXAU_SLMultGainOnCut : InpSLMultGainOnCut;
   double cd_gain = isXAU ? InpXAU_CooldownGainOnCut : InpCooldownGainOnCut;
   double sl_mult = 1.0 + sl_gain * (1.0 - rf);
   double cd_mult = 1.0 + cd_gain * (1.0 - rf);

   string base = InpGVNamespace + "/";
   GlobalVariableSet(base+"risk_mult/"+sym, rf);
   GlobalVariableSet(base+"sl_mult/"+sym, sl_mult);
   GlobalVariableSet(base+"cooldown_mult/"+sym, cd_mult);
   GlobalVariableSet(base+"updated_ts", (double)TimeTradeServer());
   // optional: debug
   PrintFormat("[MASTER] %s rf=%.2f sl_mult=%.2f cd_mult=%.2f (news/vol/equity)%s", sym, rf, sl_mult, cd_mult, isXAU?" [XAU]":"");
}

void UpdateAll()
{
   DailyResetIfNeeded();
   for(int i=0;i<ArraySize(g_symbols);++i)
      PublishForSymbol(g_symbols[i]);
}

//==================== Events ====================
int OnInit()
{
   g_day_key = TodayKey();
   g_day_equity_start = AccountInfoDouble(ACCOUNT_EQUITY);
   Split(InpSymbols, ";", g_symbols);
   EventSetTimer(InpUpdateSeconds);
   Print("[MASTER] Initialized for symbols: ", InpSymbols);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
}

void OnTimer()
{
   UpdateAll();
}

void OnTick()
{
   // Also update opportunistically on tick
   static datetime last=0; datetime now=TimeCurrent();
   if(now-last >= InpUpdateSeconds) { UpdateAll(); last=now; }
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Trade transactions handler                                       |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   // Filter to current chart symbol and handle order cancellations
   if(trans.symbol!=_Symbol) return;
   int t = (int)trans.type;
   if(t==TRADE_TRANSACTION_ORDER_DELETE)
     {
      // Clean pending order mapping if order is cancelled/expired
      ulong ord = trans.order;
      if(ord>0)
        {
         for(int i=0;i<ArraySize(g_pending_orders);++i)
           if(g_pending_orders[i]==ord)
             {
              int last=ArraySize(g_pending_orders)-1;
              g_pending_orders[i]=g_pending_orders[last]; g_pending_orders_strat[i]=g_pending_orders_strat[last];
              ArrayResize(g_pending_orders,last); ArrayResize(g_pending_orders_strat,last);
              break;
             }
        }
      return;
     }
   // We only care about deal executions beyond this point
   if(t!=TRADE_TRANSACTION_DEAL_ADD) return;

   ulong deal = trans.deal;
   if(deal==0) return;

   int entry_flag = (int)HistoryDealGetInteger(deal, DEAL_ENTRY);
   ulong pid = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
   string sym = HistoryDealGetString(deal, DEAL_SYMBOL);
   long dmagic = (long)HistoryDealGetInteger(deal, DEAL_MAGIC);

   // Filter to current chart symbol and our magic if available
   if(sym!=_Symbol) return;
   if(MagicNumber>0 && dmagic!=MagicNumber) return;

   if(entry_flag==DEAL_ENTRY_IN)
     {
      // Track newly opened position if not already tracked
      if(pid>0)
        {
         if(FindTrackedIndexByPid(pid)>=0) return; // already tracked
         string strat_name = "unknown";
         // Try to attribute strategy from pending mapping
         for(int m=0; m<ArraySize(g_pending_deals); ++m)
           {
            if(g_pending_deals[m]==deal)
              {
               strat_name = g_pending_deals_strat[m];
               int last = ArraySize(g_pending_deals)-1;
               g_pending_deals[m] = g_pending_deals[last];
               g_pending_deals_strat[m] = g_pending_deals_strat[last];
               ArrayResize(g_pending_deals, last);
               ArrayResize(g_pending_deals_strat, last);
               break;
              }
           }
         // Fallback: attribute by originating order mapping if available
         if(strat_name=="unknown" && trans.order>0)
           {
            for(int j=0;j<ArraySize(g_pending_orders);++j)
              {
               if(g_pending_orders[j]==trans.order)
                 {
                  strat_name = g_pending_orders_strat[j];
                  int last2=ArraySize(g_pending_orders)-1;
                  g_pending_orders[j]=g_pending_orders[last2];
                  g_pending_orders_strat[j]=g_pending_orders_strat[last2];
                  ArrayResize(g_pending_orders,last2);
                  ArrayResize(g_pending_orders_strat,last2);
                  break;
                 }
              }
           }
         int k = ArraySize(g_pos_ids);
         ArrayResize(g_pos_ids,k+1);
         ArrayResize(g_pos_strats,k+1);
         ArrayResize(g_pos_entry_price,k+1);
         ArrayResize(g_pos_initial_risk,k+1);
         ArrayResize(g_pos_start_time,k+1);
         ArrayResize(g_pos_type,k+1);
         ArrayResize(g_pos_max_price,k+1);
         ArrayResize(g_pos_min_price,k+1);
         g_pos_ids[k]=pid; g_pos_strats[k]=strat_name;
         double entry_p = HistoryDealGetDouble(deal, DEAL_PRICE);
         if(entry_p<=0 && PositionSelectByTicket(pid)) entry_p = PositionGetDouble(POSITION_PRICE_OPEN);
         g_pos_entry_price[k]=entry_p;
         g_pos_max_price[k]=entry_p; g_pos_min_price[k]=entry_p;
         int ptype = POSITION_TYPE_BUY;
         if(PositionSelectByTicket(pid)) ptype = (int)PositionGetInteger(POSITION_TYPE);
         g_pos_type[k]=ptype;
         double init_risk = 0.0;
         if(PositionSelectByTicket(pid))
           {
            double slc = PositionGetDouble(POSITION_SL);
            double eop = PositionGetDouble(POSITION_PRICE_OPEN);
            if(slc>0 && eop>0) init_risk = MathAbs((ptype==POSITION_TYPE_BUY? eop - slc : slc - eop));
           }
         g_pos_initial_risk[k]=init_risk;
         // Use deal time for accurate hold time
         g_pos_start_time[k]=(datetime)HistoryDealGetInteger(deal, DEAL_TIME);
         PrintFormat("Tracked pos via OnTradeTransaction: ticket=%I64u strat=%s entry=%.5f initR=%.5f", pid, g_pos_strats[k], entry_p, init_risk);
        }
      return;
     }
   else if(entry_flag==DEAL_ENTRY_OUT)
     {
      if(pid==0) return;
      int idx = FindTrackedIndexByPid(pid);
      if(idx<0)
        {
         // Not tracked; nothing to do
         return;
        }
      // If still open, treat as partial close; wait for final close
      if(PositionSelectByTicket(pid)) return;
      // Fully closed -> log and remove
       HandlePositionClosed(idx, deal);
       return;
      }
  }

//|                                                      PaperEA.mq5 |
//|                                  Copyright 2025, Windsurf, Inc. |
//|                                              https://windsurf.ai |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Windsurf, Inc."
#property link      "https://windsurf.ai"
#property version   "1.00"

// --- Core Interfaces & Data Structures
#include "..\Include\IStrategy.mqh"

// --- Core Services
#include "..\Include\KnowledgeBase.mqh"
#include "..\Include\TradeManager.mqh"
// --- Telemetry
#include "../Include/Telemetry.mqh"
#include "../Include/TelemetryStandard.mqh"
#include "../Include/SessionManager.mqh"
#include "../Include/CorrelationManager.mqh"
#include "../Include/VolatilitySizer.mqh"
// --- Shared Insights loader (DRY)
#include "..\Include\InsightsLoader.mqh"

// --- Standard Libraries
#include <Arrays/ArrayObj.mqh> // Include for CArrayObj
#include <Files/File.mqh>
 // Position management
 #include "..\\Include\\PositionManager.mqh"
 
 // --- Strategy Implementations
// Per-asset registry (internally includes concrete strategy headers)
#include "..\\Include\\Strategies\\AssetRegistry.mqh"
// Strategy selector
#include "..\\Include\\StrategySelector.mqh"

// --- Input Parameters
input double LotSize = 0.01;
input int    MagicNumber = 12345;
input double StopLossPips = 150;
input double TakeProfitPips = 300;
// Trailing stop defaults (used if a strategy does not set trailing fields)
input bool   TrailEnabled = true;
// 0=fixed points, 2=ATR
input int    TrailType = 0;
input int    TrailActivationPoints = 30;
input int    TrailDistancePoints   = 20;
input int    TrailStepPoints       = 5;
// ATR defaults (used when TrailType==2 or a strategy selects ATR)
input int    TrailATRPeriod       = 14;
input double TrailATRMultiplier   = 2.0;
  // Use PositionManager for order placement and bracket handling
  input bool   UsePositionManager   = true;
 // --- Execution guards (spread, ATR regime, sessions)
 input bool   GuardsEnabled         = true;    // master switch for execution guards
 input double GuardMaxSpreadPoints  = 0.0;     // 0=disabled; skip entries if spread (points) exceeds this
 input bool   ATRRegimeEnable       = false;   // gate by ATR percentile regime
 input int    ATRRegimePeriod       = 14;      // ATR period for regime calc
 input int    ATRRegimeLookback     = 500;     // number of bars to build empirical distribution
 input double ATRMinPercentile      = 0.0;     // 0..100 inclusive
 input double ATRMaxPercentile      = 100.0;   // 0..100 inclusive

// --- No-Constraints mode (paper data collection)
input bool   NoConstraintsMode    = true;     // bypass selector/insights/time gates and exploration caps

// --- Insights gating controls
input bool   UseInsightsGating    = true;
input int    GateMinTrades        = 0;        // loosened for bootstrap
input double GateMinWinRate       = 0.00;     // loosened for bootstrap
input double GateMinExpectancyR   = -10.0;    // loosened for bootstrap
input double GateMaxDrawdownR     = 1000000.0;// loosened for bootstrap
input double GateMinProfitFactor  = 0.00;     // loosened for bootstrap
// --- Insights auto-build & staleness
input bool   InsightsAutoBuild             = true;     // auto-build insights.json when missing or stale
input int    InsightsStaleHours            = 48;        // rebuild if older than N hours (0=disable age check)
input int    InsightsMinSourceAdvanceHours = 48;        // require sources (features/kb) to be this many hours newer than insights
input int    InsightsMinIntervalHours      = 24;        // minimum interval between rebuilds per symbol/timeframe
input bool   InsightsCheckOnTimer          = true;     // also check on timer events
input int    InsightsRebuildTimeoutMs      = 1800000; // cooperative timeout for insights rebuild (0=disable) [30 minutes]
// --- Exploration Mode (bootstrap unseen slices)
input bool   ExploreOnNoSlice     = true;    // allow limited trades when slice has no data
input int    ExploreMaxPerSlice   = 100;     // loosened for bootstrap
input int    ExploreMaxPerSlicePerDay = 100; // loosened for bootstrap
// --- Strategy selection controls
input bool   UseStrategySelector   = true;   // gate by insights-based score
input double SelW_PF               = 1.0;
input double SelW_Exp              = 1.0;
input double SelW_WR               = 0.5;
input double SelW_DD               = 0.3;
input bool   SelStrictThresholds   = false;  // enforce hard thresholds inside selector

// --- Selector recency weighting
input bool   SelUseRecency         = true;   // blend recent performance
input int    SelRecentDays         = 14;     // lookback days from features.csv
input double SelRecAlpha           = 0.5;    // 0..1 weight towards recent

// --- Phase 5: Advanced gating and tuning
input bool   P5_AutoDisableEnable    = true;    // auto-disable underperforming strategies
input double P5_MinPF                = 1.20;    // minimum recent/baseline profit factor
input double P5_MinWR                = 0.45;    // minimum win rate
input double P5_MinExpR              = -0.05;   // minimum expectancy (R multiple)
input int    P5_AutoDisableCooldownM = 1440;    // minutes to keep disabled before re-evaluate
input bool   P5_AutoReenable         = true;    // automatically re-enable after cooldown

input bool   P5_AutoTuneEnable       = true;    // enable dynamic indicator auto-tuning
input int    P5_AutoTuneEveryMin     = 60;      // run auto-tune every N minutes

input bool   P5_TimerRescoreEnable   = true;    // refresh recent overlays on a timer
input int    P5_TimerRescoreEveryMin = 60;      // rescore/lookback refresh interval (minutes)

// Placeholders for correlation pruning, MTF confirmation, and stability gating
// Wire-ups are logged and skipped if the required selector/strategy helpers are unavailable
input bool   P5_CorrPruneEnable      = false;   // prune highly correlated strategies (across open positions)
input double P5_CorrMax              = 0.80;    // max allowed correlation before pruning
input int    P5_CorrLookbackDays     = 30;      // lookback window for correlation build

input bool   P5_MTFConfirmEnable     = false;   // require higher-TF confirmation (if available)
input string P5_MTFHigherTFs         = "H1,H4";  // comma-separated higher TFs to consider
input int    P5_MTFMinAgree          = 1;       // minimum agreeing TF count

input bool   P5_StabilityGateEnable  = false;   // gate on parameter stability (if available)
input int    P5_StabilityWindowDays  = 14;      // window for stability tracking
input double P5_StabilityMaxStdR     = 1.00;    // max allowed std-dev of R in window

// Persistence and execution mode
input bool   P5_PersistLossCounters  = false;   // persist consecutive loss counters per symbol+magic (FILE_COMMON)
input bool   P5_PickBestEnable       = false;   // execute only the best-scoring strategy (selector) per tick

// --- News / Promotion / Regime / Circuit cooldown (parity with LiveEA)
input bool   UseNewsFilter       = false;   // block around defined news windows
input int    NewsBufferBeforeMin = 30;      // minutes before an event
input int    NewsBufferAfterMin  = 30;      // minutes after an event
input int    NewsImpactMin       = 2;       // 1=low, 2=medium, 3=high
input bool   NewsUseFile         = true;    // read blackouts from CSV in Common files
input string NewsFileRelPath     = "DualEA\\news_blackouts.csv";

input bool   UsePromotionGate    = false;   // allow only during configured windows
input bool   PromoLiveOnly       = false;   // apply only on live accounts
input int    PromoStartHour      = 0;       // inclusive, server time
input int    PromoEndHour        = 24;      // exclusive, supports wrap if less than start

input bool   UseRegimeGate       = false;   // filter by volatility regimes
input int    RegimeATRPeriod     = 14;
input double RegimeMinATRPct     = 0.0;     // 0=disabled
input double RegimeMaxATRPct     = 1000.0;  // 1000=disabled

input int    CircuitCooldownSec  = 0;       // 0=disabled

// --- FR-02 Session Manager inputs
input bool   UseSessionManager     = true;
input int    SessionEndHour        = 20;
input int    MaxTradesPerSession   = 10;

// --- FR-05 Correlation Manager inputs
input bool   UseCorrelationManager = true;
input double MaxCorrelationLimit   = 0.7;
input int    CorrLookbackDays      = 30;

// --- FR-06 Volatility Sizer inputs
input bool   UseVolatilitySizer    = false;
input int    VolSizerATRPeriod     = 14;
input double VolSizerBaseATRPct    = 1.0;
input double VolSizerMinMult       = 0.1;
input double VolSizerMaxMult       = 3.0;
input double VolSizerTargetRisk    = 1.0;

// --- Gate helper implementations and telemetry (parity with LiveEA)
// Global manager instances
CTelemetryStandard* g_tel_standard = NULL;
CSessionManager* g_session_manager = NULL;
CCorrelationManager* g_correlation_manager = NULL;
CVolatilitySizer* g_volatility_sizer = NULL;

// News blackout cache
string   g_news_key[];
datetime g_news_from[];
datetime g_news_to[];
int      g_news_impact[];

void EnsureNewsLoaded()
  {
   if(!UseNewsFilter || !NewsUseFile) return;
   if(ArraySize(g_news_key)>0) return;
   int h = FileOpen(NewsFileRelPath, FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(h==INVALID_HANDLE) { if(ShouldLog(LOG_INFO)) PrintFormat("News filter: cannot open %s (Common). Err=%d", NewsFileRelPath, GetLastError()); return; }
   bool first=true;
   while(!FileIsEnding(h))
     {
      string k = FileReadString(h); if(k=="" && FileIsEnding(h)) break;
      string sfrom = FileReadString(h);
      string sto   = FileReadString(h);
      string simp  = FileReadString(h);
      if(first && (StringFind(k, "key", 0)==0)) { first=false; continue; }
      first=false;
      datetime tfrom = StringToTime(sfrom);
      datetime tto   = StringToTime(sto);
      int impact = (int)StringToInteger(simp);
      int n = ArraySize(g_news_key);
      ArrayResize(g_news_key,n+1); ArrayResize(g_news_from,n+1); ArrayResize(g_news_to,n+1); ArrayResize(g_news_impact,n+1);
      StringToUpper(k);
      g_news_key[n]=k; g_news_from[n]=tfrom; g_news_to[n]=tto; g_news_impact[n]=impact;
     }
   FileClose(h);
   if(ShouldLog(LOG_INFO)) PrintFormat("News blackout windows loaded: %d", ArraySize(g_news_key));
  }

void AddUniqueKey(string &arr[], const string k)
  {
   for(int i=0;i<ArraySize(arr);++i) if(arr[i]==k) return;
   int n=ArraySize(arr); ArrayResize(arr, n+1); arr[n]=k;
  }

bool NewsAllowed(string &reason)
  {
   reason = "ok";
   if(!UseNewsFilter) return true;
   EnsureNewsLoaded();
   string keys[]; string sU=_Symbol; StringToUpper(sU);
   AddUniqueKey(keys, sU); AddUniqueKey(keys, "*");
   string ccy[] = { "USD","EUR","GBP","JPY","CHF","AUD","NZD","CAD","SEK","NOK","DKK","SGD","HKD","CNY","CNH","ZAR","MXN","TRY" };
   for(int i=0;i<ArraySize(ccy);++i) if(StringFind(sU, ccy[i])>=0) AddUniqueKey(keys, ccy[i]);
   if(StringFind(sU, "US30")>=0 || StringFind(sU, "US500")>=0 || StringFind(sU, "NAS")>=0 || StringFind(sU, "DJ")>=0 || StringFind(sU, "SPX")>=0) AddUniqueKey(keys, "USD");
   if(StringFind(sU, "GER")>=0 || StringFind(sU, "DAX")>=0 || StringFind(sU, "FRA40")>=0 || StringFind(sU, "CAC")>=0) AddUniqueKey(keys, "EUR");
   if(StringFind(sU, "UK100")>=0 || StringFind(sU, "FTSE")>=0) AddUniqueKey(keys, "GBP");
   if(StringFind(sU, "JPN")>=0 || StringFind(sU, "JP")>=0 || StringFind(sU, "NIK")>=0) AddUniqueKey(keys, "JPY");
   if(StringFind(sU, "HK50")>=0 || StringFind(sU, "HSI")>=0) AddUniqueKey(keys, "HKD");
   if(StringFind(sU, "AUS")>=0) AddUniqueKey(keys, "AUD");
   datetime now=TimeCurrent();
   for(int i=0;i<ArraySize(g_news_key);++i)
     {
      if(g_news_impact[i] < NewsImpactMin) continue;
      bool match=false; for(int j=0;j<ArraySize(keys) && !match;++j) if(g_news_key[i]==keys[j]) match=true; if(!match) continue;
      datetime from=g_news_from[i]-(NewsBufferBeforeMin*60);
      datetime to  =g_news_to[i]  +(NewsBufferAfterMin*60);
      if(now>=from && now<=to) { reason="news_window"; return false; }
     }
   return true;
  }

bool PromotionAllowed(string &reason)
  {
   reason="ok";
   if(!UsePromotionGate) return true;
   if(PromoLiveOnly && AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_REAL) return true;
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   int h=dt.hour;
   bool in_window = (PromoStartHour<=PromoEndHour ? (h>=PromoStartHour && h<PromoEndHour)
                                                 : (h>=PromoStartHour || h<PromoEndHour));
   if(!in_window) { reason="promo_window"; return false; }
   return true;
  }

bool RegimeAllowed(string &reason)
  {
   reason="ok";
   if(!UseRegimeGate) return true;
   int atr_handle = iATR(_Symbol, _Period, RegimeATRPeriod);
   if(atr_handle==INVALID_HANDLE) return true;
   double atr_buf[]; ArrayResize(atr_buf,1);
   int copied = CopyBuffer(atr_handle, 0, 0, 1, atr_buf);
   IndicatorRelease(atr_handle);
   if(copied!=1) return true;
   double atr=atr_buf[0]; double px=SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr<=0.0 || px<=0.0) return true;
   double atr_pct = 100.0 * atr / px;
   if(RegimeMinATRPct>0.0 && atr_pct < RegimeMinATRPct) { reason="regime_low_atr"; return false; }
   if(RegimeMaxATRPct>0.0 && atr_pct > RegimeMaxATRPct) { reason="regime_high_atr"; return false; }
   return true;
  }

bool CircuitCooldownAllowed(string &reason)
  {
   reason="ok";
   if(CircuitCooldownSec<=0) return true;
   static datetime g_last_paper_action = 0;
   if(g_last_paper_action==0) return true;
   if((TimeCurrent() - g_last_paper_action) < CircuitCooldownSec) { reason="circuit_cooldown"; return false; }
   return true;
  }

ulong NowMs(){ return (ulong)GetTickCount(); }
void LogGate(const string tag, const bool allowed, const string phase, const ulong t0)
  {
   int latency = (int)(NowMs() - t0);
   if(ShouldLog(LOG_INFO)) PrintFormat("[%s] %s latency_ms=%d", tag, (allowed?"allow":"block"), latency);
   if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
     {
      string det = StringFormat("phase=%s p6_latency_ms=%d", phase, latency);
      (*g_telemetry).LogEvent(_Symbol, (int)_Period, "gate", StringFormat("%s_%s", tag, (allowed?"allow":"block")), det);
     }
   // Standardized telemetry schema
   if(TelemetryEnabled && CheckPointer(g_tel_standard)!=POINTER_INVALID)
     {
      (*g_tel_standard).LogGateEvent(_Symbol, (int)_Period, tag, allowed, phase, latency, "n/a");
     }
  }

bool EarlyGatesAllow()
  {
   string reason; ulong t0;
   t0=NowMs(); bool news_ok = NewsAllowed(reason);    LogGate("NEWS",   news_ok, "early", t0); if(!news_ok) return false;
   t0=NowMs(); bool promo_ok= PromotionAllowed(reason);LogGate("PROMO",  promo_ok,"early", t0); if(!promo_ok) return false;
   t0=NowMs(); bool reg_ok  = RegimeAllowed(reason);  LogGate("REGIME", reg_ok,  "early", t0); if(!reg_ok) return false;
   t0=NowMs(); bool circ_ok = CircuitCooldownAllowed(reason); LogGate("CIRCUIT", circ_ok, "early", t0); if(!circ_ok) return false;
   
   // FR-02 Session gate
   if(UseSessionManager && CheckPointer(g_session_manager)!=POINTER_INVALID)
     {
      t0=NowMs(); bool sess_ok = g_session_manager.IsSessionAllowed(reason); LogGate("SESSION", sess_ok, "early", t0); if(!sess_ok) return false;
     }
   
   // FR-05 Correlation gate
   if(UseCorrelationManager && CheckPointer(g_correlation_manager)!=POINTER_INVALID)
     {
      double max_corr;
      t0=NowMs(); bool corr_ok = g_correlation_manager.CheckCorrelationLimits(reason, max_corr); LogGate("CORR", corr_ok, "early", t0); if(!corr_ok) return false;
     }
   
   return true;
  }

bool Risk4GatesAllow()
  {
   string reason; ulong t0;
   t0=NowMs(); bool news_ok = NewsAllowed(reason);    LogGate("NEWS",   news_ok, "risk4", t0); if(!news_ok) return false;
   t0=NowMs(); bool promo_ok= PromotionAllowed(reason);LogGate("PROMO",  promo_ok,"risk4", t0); if(!promo_ok) return false;
   t0=NowMs(); bool reg_ok  = RegimeAllowed(reason);  LogGate("REGIME", reg_ok,  "risk4", t0); if(!reg_ok) return false;
   t0=NowMs(); bool circ_ok = CircuitCooldownAllowed(reason); LogGate("CIRCUIT", circ_ok, "risk4", t0); if(!circ_ok) return false;
   
   // FR-02 Session gate
   if(UseSessionManager && CheckPointer(g_session_manager)!=POINTER_INVALID)
     {
      t0=NowMs(); bool sess_ok = g_session_manager.IsSessionAllowed(reason); LogGate("SESSION", sess_ok, "risk4", t0); if(!sess_ok) return false;
     }
   
   // FR-05 Correlation gate
   if(UseCorrelationManager && CheckPointer(g_correlation_manager)!=POINTER_INVALID)
     {
      double max_corr;
      t0=NowMs(); bool corr_ok = g_correlation_manager.CheckCorrelationLimits(reason, max_corr); LogGate("CORR", corr_ok, "risk4", t0); if(!corr_ok) return false;
     }

   // FR-04 Position Manager gate
   if(UsePositionManager && CheckPointer(g_position_manager)!=POINTER_INVALID)
     {
      int open_positions = PositionsTotal();
      bool pm_ok = (open_positions < 10);
      t0=NowMs(); LogGate("PM", pm_ok, "risk4", t0);
      if(!pm_ok) return false;
     }
   
   return true;
  }
// --- Policy gating (async from ml/policy.json)
input bool   UsePolicyGating       = true;
// --- Default policy fallback (neutral scaling when policy lookup misses)
input bool   DefaultPolicyFallback = true;   // allow neutral trading when policy slice is missing
input bool   FallbackDemoOnly      = true;   // restrict fallback to demo accounts
input bool   FallbackWhenNoPolicy  = true;   // allow fallback when policy file is not loaded

// --- Time-of-day gating (server time)
input bool   UseTradingHours       = false;
input int    TradingStartHour      = 7;      // inclusive [0..23]
input int    TradingEndHour        = 20;     // exclusive when Start<End; wraps overnight otherwise

// --- Telemetry (buffered JSONL)
input bool   TelemetryEnabled      = true;
input int    TelemetryLevel        = 1;      // 0=off, 1=events, 2=verbose
input string TelemetryExperiment   = "";     // experiment tag for file prefix
input int    TelemetryBufferMax    = 256;    // flush threshold
input string TelemetryDir          = "DualEA\\telemetry"; // Common Files subdir

// --- Insights rebuild concurrency + cancellation guards
bool g_insights_rebuild_in_progress = false; // prevent overlapping rebuilds
datetime g_last_insights_rebuild_time = 0;    // per-instance (symbol+timeframe) last successful rebuild
// Per-slice (symbol|timeframe) last rebuild map (in-memory)
string   g_ir_keys[];
datetime g_ir_times[];
int IRFindIndex(const string key)
{
  for(int i=0;i<ArraySize(g_ir_keys);++i)
    if(g_ir_keys[i]==key) return i;
  return -1;
}
datetime IRGetLast(const string key)
{
  int idx = IRFindIndex(key);
  if(idx<0) return 0;
  return g_ir_times[idx];
}
void IRSetLast(const string key, const datetime t)
{
  int idx = IRFindIndex(key);
  if(idx<0)
  {
    int n = ArraySize(g_ir_keys);
    ArrayResize(g_ir_keys,n+1); ArrayResize(g_ir_times,n+1);
    g_ir_keys[n]=key; g_ir_times[n]=t;
  }
  else
  {
    g_ir_times[idx]=t;
  }
}

// --- Verbosity controls
enum LogLevel { LOG_ERROR = 0, LOG_INFO = 1, LOG_DEBUG = 2 };
input int    Verbosity = LOG_INFO; // 0=silent, 1=info, 2=debug
bool ShouldLog(const int level){ return Verbosity >= level; }

// --- Risk/Position limits
input int    MaxOpenPositions = 0; // 0=unlimited; total simultaneous positions across account

// --- Spread and Session caps
input double SpreadMaxPoints   = 0.0; // 0=disabled, block when current spread (points) > this cap
input int    SessionStartHour  = 0;   // session/day boundary hour [0..23] for daily caps and baselines
input int    SessionMaxTrades  = 0;   // 0=unlimited; max new trades per session/day (per symbol/timeframe for this EA instance)

// --- Risk & circuit breakers (0=disabled)
input double MaxDailyLossPct   = 0.0; // block new trades if equity drawdown from session baseline exceeds this percent
input double MaxDrawdownPct    = 0.0; // block new trades if equity drawdown from session high-water exceeds this percent
input double MinMarginLevel    = 0.0; // block if Account margin level (%) < this threshold
input int    ConsecutiveLossLimit = 0; // block when consecutive losing closures >= this limit (magic-number scoped)

// --- Helper: compute R multiple strictly in price units
double ComputeRMultiple(const double entry_price, const double close_price, const double init_risk_price, const int pos_type)
  {
   if(init_risk_price<=0.0 || entry_price<=0.0 || close_price<=0.0)
      return 0.0;
   double move = (pos_type==POSITION_TYPE_SELL ? (entry_price - close_price) : (close_price - entry_price));
   double r = move / init_risk_price;
   // Abnormal magnitude detector: log for diagnostics
   if(MathAbs(r) > 100.0)
     {
      if(ShouldLog(LOG_DEBUG))
         PrintFormat("[R-MULT ALERT] abs(R)=%.2f entry=%.5f close=%.5f initR=%.8f type=%s", r, entry_price, close_price, init_risk_price, (pos_type==POSITION_TYPE_SELL?"SELL":"BUY"));
     }
   return r;
  }

 // Check and apply policy reload signal from Common Files (DualEA\\policy.reload)
 void CheckPolicyReload()
   {
    if(!UsePolicyGating) return;
    string path = "DualEA\\policy.reload";
    int h = FileOpen(path, FILE_READ|FILE_COMMON|FILE_TXT|FILE_ANSI);
    if(h==INVALID_HANDLE)
      return;
    FileClose(h);
    bool ok = Policy_Load();
    PrintFormat("Policy reload signal detected: %s", (ok?"reloaded":"failed"));
    // best-effort delete in Common Files
    if(!FileDelete(path, FILE_COMMON))
      {
       // If delete failed, log once; it's non-fatal
       PrintFormat("Policy reload: cannot delete signal file %s (err=%d)", path, GetLastError());
      }
   }

 // Check insights.reload signal from Common Files and trigger rebuild
 void CheckInsightsReload()
  {
   string path = "DualEA\\insights.reload";
   int h = FileOpen(path, FILE_READ|FILE_COMMON|FILE_TXT|FILE_ANSI);
   if(h==INVALID_HANDLE)
     return;
   FileClose(h);
   bool ok = Insights_RebuildAndReload("reload");
   PrintFormat("Insights reload signal detected: %s", (ok?"rebuilt":"failed"));
   // best-effort delete
   if(!FileDelete(path, FILE_COMMON))
     {
      PrintFormat("Insights reload: cannot delete signal file %s (err=%d)", path, GetLastError());
     }
  }
 
  // Load policy.json from Common Files and cache min_confidence and slice_probs
 bool Policy_Load()
   {
    g_policy_loaded = false;
    g_policy_min_conf = 0.0;
    ArrayResize(g_pol_strat,0); ArrayResize(g_pol_sym,0); ArrayResize(g_pol_tf,0); ArrayResize(g_pol_p,0);
    ArrayResize(g_pol_sl,0); ArrayResize(g_pol_tp,0); ArrayResize(g_pol_trail,0);
    string path = "DualEA\\policy.json";
    int h = FileOpen(path, FILE_READ|FILE_TXT|FILE_COMMON|FILE_ANSI);
    if(h==INVALID_HANDLE)
      {
       PrintFormat("Policy gating: cannot open %s (Common). Err=%d", path, GetLastError());
       return false;
      }
    string cur_s="", cur_y=""; int cur_tf=-1; double cur_p=-1.0;
    double cur_sl=1.0, cur_tp=1.0, cur_tr=1.0; // optional scales default to 1.0
    while(!FileIsEnding(h))
      {
       string line = FileReadString(h);
       if(line=="" && FileIsEnding(h)) break;
       int p;
       // min_confidence
       p = StringFind(line, "\"min_confidence\"", 0);
       if(p>=0)
         {
          int c = StringFind(line, ":", p);
          if(c>=0){ string num = TrimCopy(StringSubstr(line, c+1)); double v = StringToDouble(num); if(v>0) g_policy_min_conf = v; }
         }
       // strategy
       p = StringFind(line, "\"strategy\"", 0);
       if(p>=0)
         {
          int q = StringFind(line, ",", p+1); string seg = (q>p? StringSubstr(line, p, q-p) : StringSubstr(line, p));
          int c3=StringFind(seg, "\"", 0); c3 = StringFind(seg, "\"", c3+1); int c4=StringFind(seg, "\"", c3+1); int c5=StringFind(seg, "\"", c4+1);
          if(c4>0 && c5>c4) cur_s = StringSubstr(seg, c4+1, c5-c4-1);
         }
       // symbol
       p = StringFind(line, "\"symbol\"", 0);
       if(p>=0)
         {
          int q = StringFind(line, ",", p+1); string seg = (q>p? StringSubstr(line, p, q-p) : StringSubstr(line, p));
          int c3=StringFind(seg, "\"", 0); c3 = StringFind(seg, "\"", c3+1); int c4=StringFind(seg, "\"", c3+1); int c5=StringFind(seg, "\"", c4+1);
          if(c4>0 && c5>c4) cur_y = StringSubstr(seg, c4+1, c5-c4-1);
         }
       // timeframe
       p = StringFind(line, "\"timeframe\"", 0);
       if(p>=0)
         {
          int c = StringFind(line, ":", p); if(c>=0){ string num = TrimCopy(StringSubstr(line, c+1)); cur_tf = (int)StringToInteger(num); }
         }
       // p_win
       p = StringFind(line, "\"p_win\"", 0);
       if(p>=0)
         {
          int c = StringFind(line, ":", p); if(c>=0){ string num = TrimCopy(StringSubstr(line, c+1)); cur_p = StringToDouble(num); }
         }
       // optional: sl_scale
       p = StringFind(line, "\"sl_scale\"", 0);
       if(p>=0)
         {
          int c = StringFind(line, ":", p); if(c>=0){ string num = TrimCopy(StringSubstr(line, c+1)); double v = StringToDouble(num); if(v>0) cur_sl = v; }
         }
       // optional: tp_scale
       p = StringFind(line, "\"tp_scale\"", 0);
       if(p>=0)
         {
          int c = StringFind(line, ":", p); if(c>=0){ string num = TrimCopy(StringSubstr(line, c+1)); double v = StringToDouble(num); if(v>0) cur_tp = v; }
         }
       // optional: trail_atr_mult (or generic trail_scale for fixed points)
       p = StringFind(line, "\"trail_atr_mult\"", 0);
       if(p>=0)
         {
          int c = StringFind(line, ":", p); if(c>=0){ string num = TrimCopy(StringSubstr(line, c+1)); double v = StringToDouble(num); if(v>0) cur_tr = v; }
         }
       // If we have a full object, commit and reset
       if(cur_s!="" && cur_y!="" && cur_tf!=-1 && cur_p>=0.0)
         {
          int n = ArraySize(g_pol_strat);
          ArrayResize(g_pol_strat,n+1); ArrayResize(g_pol_sym,n+1); ArrayResize(g_pol_tf,n+1); ArrayResize(g_pol_p,n+1);
          ArrayResize(g_pol_sl,n+1); ArrayResize(g_pol_tp,n+1); ArrayResize(g_pol_trail,n+1);
          g_pol_strat[n]=cur_s; g_pol_sym[n]=cur_y; g_pol_tf[n]=cur_tf; g_pol_p[n]=cur_p;
          g_pol_sl[n]=cur_sl; g_pol_tp[n]=cur_tp; g_pol_trail[n]=cur_tr;
          cur_s=""; cur_y=""; cur_tf=-1; cur_p=-1.0; cur_sl=1.0; cur_tp=1.0; cur_tr=1.0;
         }
      }
    FileClose(h);
    g_policy_loaded = (ArraySize(g_pol_strat)>0);
    if(ShouldLog(LOG_INFO)) PrintFormat("Policy gating: min_conf=%.3f slices=%d", g_policy_min_conf, ArraySize(g_pol_strat));
    return g_policy_loaded;
   }
 
  // Normalize broker-specific suffixes to base symbol (e.g., "AUDNZD_otc" -> "AUDNZD")
  string NormalizeSymbol(string s)
    {
     string lowers = s; StringToLower(lowers);
     // Common suffixes/prefixes to strip
     string suf[] = { "_otc", "_pro", "_ecn", "_mini", "_micro", ".r", ".i", ".pro", ".ecn", ".m" };
     for(int i=0;i<ArraySize(suf);++i)
       {
        int p = StringFind(lowers, suf[i], StringLen(lowers)-StringLen(suf[i]));
        if(p>=0 && p==StringLen(lowers)-StringLen(suf[i]))
          {
           // Remove suffix of same length from original string
           s = StringSubstr(s, 0, StringLen(s)-StringLen(suf[i]));
           break;
          }
       }
     return s;
    }

  double GetPolicyProb(const string strategy, const string symbol, const int timeframe)
    {
     string symN = NormalizeSymbol(symbol);
     // 1) Exact slice: strat+symbol+timeframe
     for(int i=0;i<ArraySize(g_pol_strat);++i)
       if(g_pol_strat[i]==strategy && g_pol_sym[i]==symN && g_pol_tf[i]==timeframe)
         return g_pol_p[i];
     // 2) Symbol aggregate across TFs: strat+symbol, tf=-1
     for(int i=0;i<ArraySize(g_pol_strat);++i)
       if(g_pol_strat[i]==strategy && g_pol_sym[i]==symN && g_pol_tf[i]==-1)
         return g_pol_p[i];
     // 3) Strategy aggregate across symbols/TFs: strat only, symbol="*", tf=-1
     for(int i=0;i<ArraySize(g_pol_strat);++i)
       if(g_pol_strat[i]==strategy && g_pol_sym[i]=="*" && g_pol_tf[i]==-1)
         return g_pol_p[i];
     return -1.0;
    }

  // Retrieve a policy scale with same fallback precedence. Defaults to 1.0 when not found.
  double GetPolicyScaleSL(const string strategy, const string symbol, const int timeframe)
    {
     string symN = NormalizeSymbol(symbol);
     for(int i=0;i<ArraySize(g_pol_strat);++i)
       if(g_pol_strat[i]==strategy && g_pol_sym[i]==symN && g_pol_tf[i]==timeframe)
         return (g_pol_sl[i]>0? g_pol_sl[i] : 1.0);
     for(int i=0;i<ArraySize(g_pol_strat);++i)
       if(g_pol_strat[i]==strategy && g_pol_sym[i]==symN && g_pol_tf[i]==-1)
         return (g_pol_sl[i]>0? g_pol_sl[i] : 1.0);
     for(int i=0;i<ArraySize(g_pol_strat);++i)
       if(g_pol_strat[i]==strategy && g_pol_sym[i]=="*" && g_pol_tf[i]==-1)
         return (g_pol_sl[i]>0? g_pol_sl[i] : 1.0);
     return 1.0;
    }

  double GetPolicyScaleTP(const string strategy, const string symbol, const int timeframe)
    {
     string symN = NormalizeSymbol(symbol);
     for(int i=0;i<ArraySize(g_pol_strat);++i)
       if(g_pol_strat[i]==strategy && g_pol_sym[i]==symN && g_pol_tf[i]==timeframe)
         return (g_pol_tp[i]>0? g_pol_tp[i] : 1.0);
     for(int i=0;i<ArraySize(g_pol_strat);++i)
       if(g_pol_strat[i]==strategy && g_pol_sym[i]==symN && g_pol_tf[i]==-1)
         return (g_pol_tp[i]>0? g_pol_tp[i] : 1.0);
     for(int i=0;i<ArraySize(g_pol_strat);++i)
       if(g_pol_strat[i]==strategy && g_pol_sym[i]=="*" && g_pol_tf[i]==-1)
         return (g_pol_tp[i]>0? g_pol_tp[i] : 1.0);
     return 1.0;
    }

  double GetPolicyScaleTrail(const string strategy, const string symbol, const int timeframe)
    {
     string symN = NormalizeSymbol(symbol);
     for(int i=0;i<ArraySize(g_pol_strat);++i)
       if(g_pol_strat[i]==strategy && g_pol_sym[i]==symN && g_pol_tf[i]==timeframe)
         return (g_pol_trail[i]>0? g_pol_trail[i] : 1.0);
     for(int i=0;i<ArraySize(g_pol_strat);++i)
       if(g_pol_strat[i]==strategy && g_pol_sym[i]==symN && g_pol_tf[i]==-1)
         return (g_pol_trail[i]>0? g_pol_trail[i] : 1.0);
     for(int i=0;i<ArraySize(g_pol_strat);++i)
       if(g_pol_strat[i]==strategy && g_pol_sym[i]=="*" && g_pol_tf[i]==-1)
         return (g_pol_trail[i]>0? g_pol_trail[i] : 1.0);
     return 1.0;
    }

  // Apply policy-driven scaling to SL/TP/trailing of an order. Entry price approximated.
  void ApplyPolicyScaling(TradeOrder &order, const string symbol, const int timeframe, const double ppol)
    {
     if(!UsePolicyGating || !g_policy_loaded) return;
     // fetch scales
     double sls = GetPolicyScaleSL(order.strategy_name, symbol, timeframe);
     double tps = GetPolicyScaleTP(order.strategy_name, symbol, timeframe);
     double trs = GetPolicyScaleTrail(order.strategy_name, symbol, timeframe);

     // determine entry reference
     double entry = 0.0;
     if(order.price>0.0)
       entry = order.price; // pending
     else
       entry = (order.action==ACTION_BUY? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID));

     // Adjust SL
     if(order.stop_loss>0.0 && entry>0.0 && sls>0.0 && sls!=1.0)
       {
        double d = MathAbs(entry - order.stop_loss);
        double nd = d * sls;
        if(order.action==ACTION_BUY)
          order.stop_loss = entry - nd;
        else if(order.action==ACTION_SELL)
          order.stop_loss = entry + nd;
       }
     // Adjust TP
     if(order.take_profit>0.0 && entry>0.0 && tps>0.0 && tps!=1.0)
       {
        double d = MathAbs(order.take_profit - entry);
        double nd = d * tps;
        if(order.action==ACTION_BUY)
          order.take_profit = entry + nd;
        else if(order.action==ACTION_SELL)
          order.take_profit = entry - nd;
       }
     // Adjust trailing
     if(order.trailing_enabled && trs>0.0 && trs!=1.0)
       {
        if(order.trailing_type==TRAIL_ATR)
          order.atr_multiplier *= trs;
        else if(order.trailing_type==TRAIL_FIXED_POINTS)
          {
           order.trail_distance_points *= trs;
           order.trail_step_points *= trs;
          }
       }
     if(ShouldLog(LOG_DEBUG))
       PrintFormat("[POLICY] scales applied %s/%s tf=%d p=%.3f sl=%.2f tp=%.2f tr=%.2f",
                   order.strategy_name, symbol, timeframe, ppol, sls, tps, trs);
    }

// Determine if insights.json is missing or stale vs features/knowledge_base or by age
bool Insights_IsStale(const int stale_hours)
  {
   string ip = "DualEA\\insights.json";
   long ex_i = FileGetInteger(ip, FILE_EXISTS, true);
   if(ex_i==0) return true; // missing insights
   datetime ti = (datetime)FileGetInteger(ip, FILE_MODIFY_DATE, true);
   // Enforce minimum interval between rebuilds for this slice (symbol|timeframe)
   string slice_key = Symbol() + "|" + IntegerToString((int)Period());
   datetime last_slice = IRGetLast(slice_key);
   if(InsightsMinIntervalHours>0 && last_slice>0)
     {
      if((TimeCurrent() - last_slice) < (InsightsMinIntervalHours*60*60))
         return false;
     }
   if(stale_hours>0)
     {
      if((TimeCurrent() - ti) > (stale_hours*60*60))
         return true;
     }
   // Rebuild if source CSVs are newer
   string fp = "DualEA\\features.csv";
   if(FileGetInteger(fp, FILE_EXISTS, true)>0)
     {
      datetime tf = (datetime)FileGetInteger(fp, FILE_MODIFY_DATE, true);
      if(tf>ti)
        {
         // Require sources to be ahead by at least InsightsMinSourceAdvanceHours
         if(InsightsMinSourceAdvanceHours<=0 || (tf - ti) >= (InsightsMinSourceAdvanceHours*60*60))
            return true;
        }
     }
   string kp = "DualEA\\knowledge_base.csv";
   if(FileGetInteger(kp, FILE_EXISTS, true)>0)
     {
      datetime tk = (datetime)FileGetInteger(kp, FILE_MODIFY_DATE, true);
      if(tk>ti)
        {
         if(InsightsMinSourceAdvanceHours<=0 || (tk - ti) >= (InsightsMinSourceAdvanceHours*60*60))
            return true;
        }
     }
   return false;
  }

// Rebuild insights.json and reload gating/selector caches
bool Insights_RebuildAndReload(const string reason)
  {
   if(ShouldLog(LOG_INFO)) PrintFormat("Insights auto-build triggered (%s)", reason);

   // Concurrency guard
   if(g_insights_rebuild_in_progress)
     {
      if(ShouldLog(LOG_INFO)) Print("[INSIGHTS] rebuild skipped: already in progress");
      if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
         (*g_telemetry).LogEvent(_Symbol, (int)_Period, "system", "insights_rebuild_skip_busy", StringFormat("reason=%s", reason));
      return false;
     }

   g_insights_rebuild_in_progress = true;
   g_insights_cancel_requested = false;
   ulong t0 = GetTickCount();

   if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
     {
      string det = StringFormat("reason=%s timeout_ms=%d", reason, InsightsRebuildTimeoutMs);
      (*g_telemetry).LogEvent(_Symbol, (int)_Period, "system", "insights_rebuild_start", det);
     }

   int elapsed_ms = 0;

   CInsightsBuilder b;
   if(InsightsRebuildTimeoutMs>0)
     b.SetTimeoutMs(InsightsRebuildTimeoutMs);
   // Disable verbose progress by default; can be toggled later if needed
   b.SetVerbose(false);

   bool ok = b.Build();
   elapsed_ms = (int)(GetTickCount() - t0);

   if(!ok)
     {
      PrintFormat("Insights auto-build FAILED (%s). elapsed_ms=%d Err=%d", reason, elapsed_ms, GetLastError());
      if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
        {
         string detf = StringFormat("reason=%s elapsed_ms=%d timeout_ms=%d", reason, elapsed_ms, InsightsRebuildTimeoutMs);
         (*g_telemetry).LogEvent(_Symbol, (int)_Period, "system", "insights_rebuild_failure", detf);
        }
      g_insights_rebuild_in_progress = false;
      g_insights_cancel_requested = false;
      return false;
     }

   // Reload insights gating cache
   bool gate_loaded = Insights_Load();
   if(ShouldLog(LOG_INFO)) PrintFormat("Insights gating cache reload after build: %s", (gate_loaded?"ok":"fail"));
   // Reload selector insights if available
   if(CheckPointer(g_selector)!=POINTER_INVALID)
     {
      bool sel_ok = (*g_selector).Load();
      if(ShouldLog(LOG_INFO)) PrintFormat("Selector insights reload after build: %s", (sel_ok?"ok":"fail"));
     }

   if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
     {
      string dets = StringFormat("reason=%s elapsed_ms=%d timeout_ms=%d gate_reload=%s", reason, elapsed_ms, InsightsRebuildTimeoutMs, (gate_loaded?"ok":"fail"));
      (*g_telemetry).LogEvent(_Symbol, (int)_Period, "system", "insights_rebuild_success", dets);
     }
   g_insights_rebuild_in_progress = false;
   g_insights_cancel_requested = false;
   if(ok)
     {
      g_last_insights_rebuild_time = TimeCurrent();
      string slice_key2 = Symbol() + "|" + IntegerToString((int)Period());
      IRSetLast(slice_key2, g_last_insights_rebuild_time);
      // Write ready signal for LiveEA to detect immediate availability
      string rdy = "DualEA\\insights.ready";
      // best-effort delete previous
      if(FileIsExist(rdy, FILE_COMMON)) FileDelete(rdy, FILE_COMMON);
      int hr = FileOpen(rdy, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
      if(hr!=INVALID_HANDLE)
        {
         FileWrite(hr, IntegerToString((int)g_last_insights_rebuild_time));
         FileClose(hr);
         if(ShouldLog(LOG_INFO)) Print("Insights ready signal written");
        }
      else
        {
         PrintFormat("Insights ready: cannot create %s (err=%d)", rdy, GetLastError());
        }
     }
   return true;
  }

// --- String trim helper (returns a trimmed copy)
string TrimCopy(string s)
  {
   StringTrimLeft(s);
   StringTrimRight(s);
   return s;
  }
// Identify likely crypto symbols (basic heuristic)
bool IsLikelyCryptoSymbol(const string s)
  {
   string b = NormalizeSymbol(s);
   StringToUpper(b);
   string toks[] = {"BTC","ETH","XRP","LTC","BCH","BNB","ADA","DOGE","DOT","SOL","MATIC","TRX","SHIB","AVAX","TON"};
   for(int i=0;i<ArraySize(toks);++i)
     {
      if(StringFind(b, toks[i], 0) == 0) return true; // prefix match
     }
   if(StringLen(b)>=6)
     {
      string base = StringSubstr(b, 0, StringLen(b)-3);
      for(int j=0;j<ArraySize(toks);++j)
        if(base==toks[j]) return true;
     }
   return false;
  }

// Compute ATR percentile (0..100) of current ATR vs last N bars; returns true on success
bool GetATRPercentile(const string symbol, const ENUM_TIMEFRAMES tf, const int period, const int lookback, double &percentile_out)
  {
   percentile_out = -1.0;
   if(period<=0 || lookback<=10) return false;
   int h = iATR(symbol, tf, period);
   if(h==INVALID_HANDLE) return false;
   int need = MathMin(lookback+1, 2000);
   double buf[];
   int copied = CopyBuffer(h, 0, 0, need, buf);
   IndicatorRelease(h);
   if(copied<period+5 || copied<=1) return false;
   double cur = buf[0];
   if(cur<=0.0) return false;
   int valid=0, below=0;
   for(int i=1;i<copied;++i)
     {
      double v = buf[i];
      if(v>0.0){ valid++; if(v<cur) below++; }
     }
   if(valid<=0) return false;
   percentile_out = 100.0 * ((double)below / (double)valid);
   return true;
  }
// Logging controls
input bool   DebugTrailing = false;
input bool   KBDebugInit   = true;

// --- Trainer / LSTM flags (for downstream trainer tooling)
input bool   TrainerLSTM_Enable     = false;
input int    TrainerLSTM_MinSeq     = 50;
input int    TrainerLSTM_MaxSeq     = 500;
input bool   TrainerLSTM_UseRecency = true;

// --- Explore-cap logging dedupe state ---
datetime g_ecap_bar_time = 0;
string   g_ecap_keys[];
int      g_ecap_counts[];
int      g_ecap_printed_once[]; // 0/1 whether we logged the first occurrence for this key this bar

int ECapFindKeyIndex(const string key)
{
  for(int i=0;i<ArraySize(g_ecap_keys);++i)
    if(g_ecap_keys[i]==key) return i;
  return -1;
}

// Returns true if this is the first occurrence for the key in the current bar
bool ECapIncrement(const string key)
{
  datetime bar = iTime(_Symbol,_Period,0);
  if(g_ecap_bar_time==0)
    g_ecap_bar_time = bar;
  if(bar!=g_ecap_bar_time)
  {
    // caller should have flushed before incrementing for a new bar; still reset defensively
    ArrayResize(g_ecap_keys,0); ArrayResize(g_ecap_counts,0); ArrayResize(g_ecap_printed_once,0);
    g_ecap_bar_time = bar;
  }
  int idx = ECapFindKeyIndex(key);
  if(idx<0)
  {
    int n = ArraySize(g_ecap_keys);
    ArrayResize(g_ecap_keys,n+1); ArrayResize(g_ecap_counts,n+1); ArrayResize(g_ecap_printed_once,n+1);
    g_ecap_keys[n] = key; g_ecap_counts[n] = 1; g_ecap_printed_once[n] = 0;
    return true;
  }
  g_ecap_counts[idx]++;
  return (g_ecap_printed_once[idx]==0);
}

void ECapMarkPrinted(const string key)
{
  int idx = ECapFindKeyIndex(key);
  if(idx>=0) g_ecap_printed_once[idx] = 1;
}

void ECapFlushSummaryIfNewBar()
{
  if(g_ecap_bar_time==0) return;
  datetime bar = iTime(_Symbol,_Period,0);
  if(bar==g_ecap_bar_time) return; // same bar, nothing to do
  // Emit one summary per key for the previous bar
  string bar_ts = TimeToString(g_ecap_bar_time, TIME_DATE|TIME_MINUTES);
  for(int i=0;i<ArraySize(g_ecap_keys);++i)
  {
    int total = g_ecap_counts[i];
    int suppressed = total - (g_ecap_printed_once[i]>0 ? 1 : 0);
    if(ShouldLog(LOG_INFO))
      PrintFormat("[GATE] explore_cap summary bar=%s key=%s occurrences=%d suppressed=%d", bar_ts, g_ecap_keys[i], total, (suppressed<0?0:suppressed));
  }
  // Reset for new bar
  ArrayResize(g_ecap_keys,0); ArrayResize(g_ecap_counts,0); ArrayResize(g_ecap_printed_once,0);
  g_ecap_bar_time = bar;
}

// --- Heartbeat / status panel
input bool   HeartbeatEnabled = true;
input int    HeartbeatMinutes = 15;   // update every N minutes
input bool   HeartbeatVerbose = true; // print [STRAT] lines per strategy

// --- Globals
CKnowledgeBase*         g_kb = NULL;
CTradeManager*          g_trade_manager = NULL;
 CArrayObj*              g_strategies; // Array to hold all strategy objects
 CFeaturesKB*            g_features = NULL; // Features logger
 CTelemetry*             g_telemetry = NULL; // Telemetry logger
 // --- Spread/Session/Risk state
 datetime                g_session_start = 0;
 int                     g_session_day   = 0;
 double                  g_session_equity_start = 0.0;
 double                  g_equity_highwater     = 0.0;
 // Strategy selector
 CStrategySelector*       g_selector = NULL;
 // Position manager (optional)
 CPositionManager*        g_position_manager = NULL;
 // Insights gating cache
string                  g_gate_strat[];
string                  g_gate_sym[];
int                     g_gate_tf[];
int                     g_gate_cnt[];
double                  g_gate_wr[];
double                  g_gate_avgR[];
double                  g_gate_pf[];
double                  g_gate_dd[];
// Policy cache (per-slice probability) and threshold
bool                    g_policy_loaded = false;
double                  g_policy_min_conf = 0.0;
string                  g_pol_strat[];
string                  g_pol_sym[];
int                     g_pol_tf[];
// --- Phase 5 housekeeping
// Last timestamp we refreshed recent overlays for selector (optional; used to rate-limit rescoring)
datetime               g_p5_last_rescore_ts = 0;
double                  g_pol_p[];
double                  g_pol_sl[];
double                  g_pol_tp[];
double                  g_pol_trail[];

// Exploration Mode tracking (weekly persistent)
string                  g_exp_keys[];    // slice key: strategy|symbol|timeframe
int                     g_exp_weeks[];   // week bucket id (Monday yyyymmdd)
int                     g_exp_counts[];  // count within week
string                  g_explore_pending_key = ""; // set by Insights_Allow when allowing explore

// Daily exploration tracking (persistent)
string                  g_exp_day_keys[];
int                     g_exp_day_days[];   // yyyymmdd
int                     g_exp_day_counts[];

// Active position tracking for MFE/MAE and closure analytics
ulong                   g_pos_ids[];           // POSITION_IDENTIFIER
string                  g_pos_strats[];        // strategy attribution
double                  g_pos_entry_price[];   // entry price
double                  g_pos_initial_risk[];  // initial risk (price units)
datetime                g_pos_start_time[];    // entry time
int                     g_pos_type[];          // POSITION_TYPE_*
double                  g_pos_max_price[];     // MFE price
double                  g_pos_min_price[];     // MAE price

// Persistent consecutive loss counters (per symbol + magic)
string                  g_loss_sym[];
long                    g_loss_mag[];
int                     g_loss_cnt[];

// --- Persistent loss counters helpers (placed before first use)
string LossCountersDirPath()
  {
   return "DualEA/"; // keep under common DualEA folder
  }

string SanitizeForFilename(const string s)
  {
   string r=s;
   string bad = "\\/:*?\"<>|";
   for(int i=0;i<StringLen(bad);++i)
     StringReplace(r, StringSubstr(bad,i,1), "_");
   return r;
  }

string LossKeyPath(const string sym, const long mag)
  {
   string dir = LossCountersDirPath();
   string fname = "loss_" + SanitizeForFilename(sym) + "_" + IntegerToString(mag) + ".csv";
   return dir + fname; // FILE_COMMON
  }

void SaveLossKey(const string sym, const long mag, const int consec)
  {
   string path = LossKeyPath(sym, mag);
   int h = FileOpen(path, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(h==INVALID_HANDLE){ PrintFormat("Loss persist(key): cannot open %s for write. Err=%d", path, GetLastError()); return; }
   FileWrite(h, "symbol,magic,consec");
   FileWrite(h, sym, IntegerToString(mag), IntegerToString(consec));
   FileClose(h);
  }

void SaveLossCounters()
  {
   for(int i=0;i<ArraySize(g_loss_sym);++i)
     SaveLossKey(g_loss_sym[i], g_loss_mag[i], g_loss_cnt[i]);
  }

bool LoadLossCounters()
  {
   ArrayResize(g_loss_sym,0); ArrayResize(g_loss_mag,0); ArrayResize(g_loss_cnt,0);
   string dir = LossCountersDirPath();
   string name="";
   long fh = FileFindFirst(dir+"loss_*.csv", name, FILE_COMMON);
   if(fh==INVALID_HANDLE)
     {
      PrintFormat("Loss persist: no prior %sloss_*.csv (ok)", dir);
      return true;
     }
   bool ok=true;
   do
     {
      string path = dir + name;
      int h = FileOpen(path, FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
      if(h!=INVALID_HANDLE)
        {
         bool first=true;
         while(!FileIsEnding(h))
           {
            string s = FileReadString(h); if(s=="" && FileIsEnding(h)) break;
            string m = FileReadString(h);
            string c = FileReadString(h);
            if(first && (StringFind(s, "symbol", 0)==0)) { first=false; continue; }
            first=false;
            int n = ArraySize(g_loss_sym);
            ArrayResize(g_loss_sym,n+1); ArrayResize(g_loss_mag,n+1); ArrayResize(g_loss_cnt,n+1);
            g_loss_sym[n]=s; g_loss_mag[n]=(long)StringToInteger(m); g_loss_cnt[n]=(int)StringToInteger(c);
           }
         FileClose(h);
        }
      else
        {
         ok=false;
         PrintFormat("Loss persist: cannot open %s for read. Err=%d", path, GetLastError());
        }
     }
   while(FileFindNext(fh, name));
   FileFindClose(fh);
   return ok;
  }

int GetConsecLossPersist(const string sym, const long mag)
  {
   for(int i=0;i<ArraySize(g_loss_sym);++i)
     if(g_loss_sym[i]==sym && g_loss_mag[i]==mag) return g_loss_cnt[i];
   return 0;
  }

void SetConsecLossPersist(const string sym, const long mag, const int val)
  {
   for(int i=0;i<ArraySize(g_loss_sym);++i)
     if(g_loss_sym[i]==sym && g_loss_mag[i]==mag)
       {
        g_loss_cnt[i] = (val<0?0:val);
        SaveLossKey(sym, mag, g_loss_cnt[i]);
        return;
       }
   int n = ArraySize(g_loss_sym);
   ArrayResize(g_loss_sym,n+1); ArrayResize(g_loss_mag,n+1); ArrayResize(g_loss_cnt,n+1);
   g_loss_sym[n]=sym; g_loss_mag[n]=mag; g_loss_cnt[n]=(val<0?0:val);
   SaveLossKey(sym, mag, g_loss_cnt[n]);
  }

void IncConsecLossPersist(const string sym, const long mag)
  {
   for(int i=0;i<ArraySize(g_loss_sym);++i)
     if(g_loss_sym[i]==sym && g_loss_mag[i]==mag)
       {
        g_loss_cnt[i] = g_loss_cnt[i] + 1;
        SaveLossKey(sym, mag, g_loss_cnt[i]);
        return;
       }
   int n = ArraySize(g_loss_sym);
   ArrayResize(g_loss_sym,n+1); ArrayResize(g_loss_mag,n+1); ArrayResize(g_loss_cnt,n+1);
   g_loss_sym[n]=sym; g_loss_mag[n]=mag; g_loss_cnt[n]=1;
   SaveLossKey(sym, mag, 1);
  }

// --- Helpers: tracking lookup and robust closure logging/removal
int FindTrackedIndexByPid(ulong pid)
  {
   for(int t=0; t<ArraySize(g_pos_ids); ++t)
     if(g_pos_ids[t]==pid) return t;
   return -1;
  }

void HandlePositionClosed(int idx, ulong close_deal)
  {
   if(idx<0 || idx>=ArraySize(g_pos_ids)) return;
   ulong   pid         = g_pos_ids[idx];
   string  strat       = g_pos_strats[idx];
   double  entry_price = g_pos_entry_price[idx];
   double  init_risk   = g_pos_initial_risk[idx]; // price units
   datetime t_start    = g_pos_start_time[idx];
   int     ptype       = g_pos_type[idx];
   double  max_price   = g_pos_max_price[idx];
   double  min_price   = g_pos_min_price[idx];

   string  sym_close   = HistoryDealGetString(close_deal, DEAL_SYMBOL);
   double  close_price = HistoryDealGetDouble(close_deal, DEAL_PRICE);
   double  profit_money= HistoryDealGetDouble(close_deal, DEAL_PROFIT);
   datetime ts_close   = (datetime)HistoryDealGetInteger(close_deal, DEAL_TIME);

   // Compute R-multiple
   double r = 0.0;
   if(init_risk>0.0 && entry_price>0.0 && close_price>0.0)
     {
      if(ptype==POSITION_TYPE_BUY) r = (close_price - entry_price) / init_risk;
      else                         r = (entry_price - close_price) / init_risk;
     }

   // Compute MFE/MAE in points and R
   double fav_pts=0.0, adv_pts=0.0;
   if(ptype==POSITION_TYPE_BUY)
     { fav_pts = (max_price - entry_price) / _Point; adv_pts = (entry_price - min_price) / _Point; }
   else
     { fav_pts = (entry_price - min_price) / _Point; adv_pts = (max_price - entry_price) / _Point; }
   double mfe_r = 0.0, mae_r = 0.0;
   if(init_risk>0.0)
     { mfe_r = (fav_pts * _Point) / init_risk; mae_r = (adv_pts * _Point) / init_risk; }

   // Hold time (seconds)
   double hold_secs = 0.0; if(ts_close>t_start) hold_secs = (double)(ts_close - t_start);

   // Feature logging at close
   if(CheckPointer(g_features)!=POINTER_INVALID)
     {
      if(init_risk>0.0) (*g_features).WriteKV(ts_close, sym_close, strat, "r_multiple", r);
      (*g_features).WriteKV(ts_close, sym_close, strat, "hold_time_seconds", hold_secs);
      (*g_features).WriteKV(ts_close, sym_close, strat, "mfe_points", fav_pts);
      (*g_features).WriteKV(ts_close, sym_close, strat, "mae_points", adv_pts);
      if(init_risk>0.0)
        {
         (*g_features).WriteKV(ts_close, sym_close, strat, "mfe_r", mfe_r);
         (*g_features).WriteKV(ts_close, sym_close, strat, "mae_r", mae_r);
        }
     }

   // Final KB record
   if(CheckPointer(g_kb)!=POINTER_INVALID)
     {
      TradeRecord rec;
      rec.timestamp    = ts_close;
      rec.symbol       = sym_close;
      rec.type         = (ptype==POSITION_TYPE_BUY? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      rec.entry_price  = entry_price;
      rec.stop_loss    = 0.0;
      rec.take_profit  = 0.0;
      rec.close_price  = close_price;
      rec.profit       = profit_money;
      rec.strategy_id  = strat;
      (*g_kb).WriteRecord(rec);
     }

   // Telemetry for closure
   if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
     {
      string details = StringFormat("pid=%I64u r=%.6f profit=%.2f hold=%.0fs mfe_r=%.6f mae_r=%.6f",
                                   pid, r, profit_money, hold_secs, mfe_r, mae_r);
      (*g_telemetry).LogEvent(sym_close, (int)_Period, strat, "position_closed", details);
     }

   if(ShouldLog(LOG_INFO))
     PrintFormat("[CLOSE] pid=%I64u strat=%s r=%.6f profit=%.2f hold=%.0fs mfe_pts=%.1f mae_pts=%.1f", pid, strat, r, profit_money, hold_secs, fav_pts, adv_pts);

   // Update persistent consecutive loss counters if enabled
   if(P5_PersistLossCounters)
     {
      if(profit_money < 0.0)
        IncConsecLossPersist(_Symbol, MagicNumber);
      else if(profit_money > 0.0)
        SetConsecLossPersist(_Symbol, MagicNumber, 0);
     }

   // Remove tracked position via swap-with-last to keep arrays compact
   int last = ArraySize(g_pos_ids)-1;
   g_pos_ids[idx] = g_pos_ids[last];
   g_pos_strats[idx] = g_pos_strats[last];
   g_pos_entry_price[idx] = g_pos_entry_price[last];
   g_pos_initial_risk[idx] = g_pos_initial_risk[last];
   g_pos_start_time[idx] = g_pos_start_time[last];
   g_pos_type[idx] = g_pos_type[last];
   g_pos_max_price[idx] = g_pos_max_price[last];
   g_pos_min_price[idx] = g_pos_min_price[last];
   ArrayResize(g_pos_ids, last);
   ArrayResize(g_pos_strats, last);
   ArrayResize(g_pos_entry_price, last);
   ArrayResize(g_pos_initial_risk, last);
   ArrayResize(g_pos_start_time, last);
   ArrayResize(g_pos_type, last);
   ArrayResize(g_pos_max_price, last);
   ArrayResize(g_pos_min_price, last);
  }

// Pending order/deal attribution (to map back strategy names on asynchronous trade events)
ulong                   g_pending_orders[];
string                  g_pending_orders_strat[];
ulong                   g_pending_deals[];
string                  g_pending_deals_strat[];

// Returns Monday date of the week as yyyymmdd integer for the provided time
int WeekMondayId(datetime t)
  {
   MqlDateTime dt; TimeToStruct(t, dt);
   // MT5: day_of_week 0=Sunday, 1=Monday, ... 6=Saturday
   int dow = dt.day_of_week;
   int delta_days = (dow==0 ? 6 : (dow-1));
   datetime monday = t - (delta_days * 86400);
   MqlDateTime md; TimeToStruct(monday, md);
   return (md.year*10000 + md.mon*100 + md.day);
  }

string ExploreCountsPath()
  {
   return "DualEA\\explore_counts.csv"; // FILE_COMMON
  }

void SaveExploreCounts()
  {
   string path = ExploreCountsPath();
   int h = FileOpen(path, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(h==INVALID_HANDLE){ PrintFormat("Explore persist: cannot open %s for write. Err=%d", path, GetLastError()); return; }
   // header
   FileWrite(h, "key,week_monday_yyyymmdd,count");
   for(int i=0;i<ArraySize(g_exp_keys);++i)
     {
      FileWrite(h, g_exp_keys[i], IntegerToString(g_exp_weeks[i]), IntegerToString(g_exp_counts[i]));
     }
   FileClose(h);
 }

bool LoadExploreCounts()
  {
   ArrayResize(g_exp_keys,0); ArrayResize(g_exp_weeks,0); ArrayResize(g_exp_counts,0);
   string path = ExploreCountsPath();
   int h = FileOpen(path, FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(h==INVALID_HANDLE) { PrintFormat("Explore persist: no prior %s (ok)", path); return true; }
   bool first=true;
   while(!FileIsEnding(h))
     {
      string k = FileReadString(h); if(k=="" && FileIsEnding(h)) break;
      string wk_s = FileReadString(h);
      string cnt_s = FileReadString(h);
      // skip header if present
      if(first && (StringFind(k, "key", 0)==0)) { first=false; continue; }
      first=false;
      int n = ArraySize(g_exp_keys);
      ArrayResize(g_exp_keys,n+1); ArrayResize(g_exp_weeks,n+1); ArrayResize(g_exp_counts,n+1);
      g_exp_keys[n]=k; g_exp_weeks[n]=(int)StringToInteger(wk_s); g_exp_counts[n]=(int)StringToInteger(cnt_s);
     }
   FileClose(h);
   return true;
  }


// Daily helpers
int DayId(datetime t)
  {
   MqlDateTime dt; TimeToStruct(t, dt);
   return (dt.year*10000 + dt.mon*100 + dt.day);
  }

string ExploreDayCountsPath()
  {
   return "DualEA\\explore_counts_day.csv";
  }

void SaveExploreCountsDay()
  {
   string path = ExploreDayCountsPath();
   int h = FileOpen(path, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(h==INVALID_HANDLE){ PrintFormat("Explore persist(day): cannot open %s for write. Err=%d", path, GetLastError()); return; }
   FileWrite(h, "key,day_yyyymmdd,count");
   for(int i=0;i<ArraySize(g_exp_day_keys);++i)
     FileWrite(h, g_exp_day_keys[i], IntegerToString(g_exp_day_days[i]), IntegerToString(g_exp_day_counts[i]));
   FileClose(h);
  }

bool LoadExploreCountsDay()
  {
   ArrayResize(g_exp_day_keys,0); ArrayResize(g_exp_day_days,0); ArrayResize(g_exp_day_counts,0);
   string path = ExploreDayCountsPath();
   int h = FileOpen(path, FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(h==INVALID_HANDLE) { PrintFormat("Explore persist(day): no prior %s (ok)", path); return true; }
   bool first=true;
   while(!FileIsEnding(h))
     {
      string k = FileReadString(h); if(k=="" && FileIsEnding(h)) break;
      string d = FileReadString(h);
      string c = FileReadString(h);
      if(first && (StringFind(k, "key", 0)==0)) { first=false; continue; }
      first=false;
      int n = ArraySize(g_exp_day_keys);
      ArrayResize(g_exp_day_keys,n+1); ArrayResize(g_exp_day_days,n+1); ArrayResize(g_exp_day_counts,n+1);
      g_exp_day_keys[n]=k; g_exp_day_days[n]=(int)StringToInteger(d); g_exp_day_counts[n]=(int)StringToInteger(c);
     }
   FileClose(h);
   return true;
  }

string SliceKey(const string strategy, const string symbol, const int timeframe)
  {
   return strategy + "|" + symbol + "|" + IntegerToString(timeframe);
  }

int GetExploreCount(const string key)
  {
   int wk = WeekMondayId(TimeCurrent());
   for(int i=0;i<ArraySize(g_exp_keys);++i)
     if(g_exp_keys[i]==key && g_exp_weeks[i]==wk) return g_exp_counts[i];
   return 0;
  }

int GetExploreCountDay(const string key)
  {
   int d = DayId(TimeCurrent());
   for(int i=0;i<ArraySize(g_exp_day_keys);++i)
     if(g_exp_day_keys[i]==key && g_exp_day_days[i]==d) return g_exp_day_counts[i];
   return 0;
  }

void IncExploreCount(const string key)
  {
   int wk = WeekMondayId(TimeCurrent());
   for(int i=0;i<ArraySize(g_exp_keys);++i)
     if(g_exp_keys[i]==key && g_exp_weeks[i]==wk)
       {
        g_exp_counts[i] = g_exp_counts[i] + 1;
        SaveExploreCounts();
        // also bump daily
        int dd = DayId(TimeCurrent()); bool day_found=false;
        for(int j=0;j<ArraySize(g_exp_day_keys);++j)
          if(g_exp_day_keys[j]==key && g_exp_day_days[j]==dd){ g_exp_day_counts[j]+=1; day_found=true; break; }
        if(!day_found)
          {
           int m = ArraySize(g_exp_day_keys);
           ArrayResize(g_exp_day_keys,m+1); ArrayResize(g_exp_day_days,m+1); ArrayResize(g_exp_day_counts,m+1);
           g_exp_day_keys[m]=key; g_exp_day_days[m]=dd; g_exp_day_counts[m]=1;
          }
        SaveExploreCountsDay();
        return;
       }
   int n = ArraySize(g_exp_keys);
   ArrayResize(g_exp_keys, n+1);
   ArrayResize(g_exp_weeks, n+1);
   ArrayResize(g_exp_counts, n+1);
   g_exp_keys[n] = key;
   g_exp_weeks[n] = wk;
   g_exp_counts[n] = 1;
   SaveExploreCounts();
   // init daily row
   int dd = DayId(TimeCurrent());
   int m = ArraySize(g_exp_day_keys);
   ArrayResize(g_exp_day_keys,m+1); ArrayResize(g_exp_day_days,m+1); ArrayResize(g_exp_day_counts,m+1);
   g_exp_day_keys[m]=key; g_exp_day_days[m]=dd; g_exp_day_counts[m]=1;
   SaveExploreCountsDay();
  }

// Check if insights has an existing slice for exact strategy/symbol/timeframe
bool HasSlice(const string strategy, const string symbol, const int timeframe)
  {
   for(int i=0;i<ArraySize(g_gate_strat);++i)
     if(g_gate_strat[i]==strategy && g_gate_sym[i]==symbol && g_gate_tf[i]==timeframe && g_gate_cnt[i]>0)
        return true;
   return false;
  }

bool Insights_Load()
  {
   int loaded = Insights_Load_Default(
      g_gate_strat,
      g_gate_sym,
      g_gate_tf,
      g_gate_cnt,
      g_gate_wr,
      g_gate_avgR,
      g_gate_pf,
      g_gate_dd
   );
   if(loaded<0)
      return false;
   if(ShouldLog(LOG_INFO)) PrintFormat("Insights gating: loaded %d slices", ArraySize(g_gate_strat));
   return ArraySize(g_gate_strat)>0;
  }

bool Insights_Allow(const string strategy, const string symbol, const int timeframe, string &reason, const bool shadow=false, const bool no_side_effects=false)
  {
    reason = "";
    // Global bypass for data collection
    if(NoConstraintsMode && !shadow)
      {
       reason = "no_constraints";
       return true;
      }
   // Default policy fallback when no policy is loaded
   if(DefaultPolicyFallback && UsePolicyGating && FallbackWhenNoPolicy && !g_policy_loaded)
     {
      bool demo_ok0 = (!FallbackDemoOnly) || (AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO);
      if(demo_ok0)
        {
         reason = "fallback_no_policy";
         return true;
        }
     }
   // Default policy fallback: allow neutral trading when policy slice is missing
   if(DefaultPolicyFallback && UsePolicyGating && g_policy_loaded)
     {
      double pchk = GetPolicyProb(strategy, symbol, timeframe);
      if(pchk < 0.0)
        {
         bool demo_ok = (!FallbackDemoOnly) || (AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO);
         if(demo_ok)
           {
            reason = "fallback_policy_miss";
            return true;
           }
        }
     }
   // Find matching slice
   for(int i=0;i<ArraySize(g_gate_strat);++i)
     if(g_gate_strat[i]==strategy && g_gate_sym[i]==symbol && g_gate_tf[i]==timeframe)
       {
        if(g_gate_cnt[i] < GateMinTrades)
          {
            reason = "min_trades"; return false;
          }
        if(g_gate_wr[i]  < GateMinWinRate)
          {
            reason = "win_rate"; return false;
          }
        if(g_gate_avgR[i]< GateMinExpectancyR)
          {
            reason = "expectancy"; return false;
          }
        if(g_gate_dd[i]  > GateMaxDrawdownR)
          {
            reason = "drawdown"; return false;
          }
        if(g_gate_pf[i]  < GateMinProfitFactor)
          {
            reason = "profit_factor"; return false;
          }
        // Policy check for exact slice
        if(UsePolicyGating && g_policy_loaded)
          {
           double ppol = GetPolicyProb(strategy, symbol, timeframe);
           if(ppol>=0.0 && ppol < g_policy_min_conf)
             { reason = "policy_min_conf"; return false; }
          }
        return true;
       }
   // If no slices loaded at all, allow cold-start to bootstrap data
   if(ArraySize(g_gate_strat)==0)
     { reason = "cold_start"; return true; }

   // Fallback 1: aggregate by strategy+symbol across all timeframes
   int total=0; double wins=0.0; double sumR=0.0; double pf_sum=0.0; int pf_cnt=0; double worst_dd=0.0;
   for(int j=0;j<ArraySize(g_gate_strat);++j)
     if(g_gate_strat[j]==strategy && g_gate_sym[j]==symbol)
       {
        total += g_gate_cnt[j];
        wins  += g_gate_wr[j]*g_gate_cnt[j];
        sumR  += g_gate_avgR[j]*g_gate_cnt[j];
        pf_sum+= g_gate_pf[j]; pf_cnt++;
        if(g_gate_dd[j]>worst_dd) worst_dd=g_gate_dd[j];
       }
   if(total>0)
     {
      double wr   = (total>0? wins/total : 0.0);
      double avgR = (total>0? sumR/total : 0.0);
      double pf   = (pf_cnt>0? pf_sum/pf_cnt : 0.0);
      double dd   = worst_dd;
      if(total < GateMinTrades)
        {
         reason = "min_trades_agg_sym"; return false;
        }
      if(wr    < GateMinWinRate)
        {
         reason = "win_rate_agg_sym"; return false;
        }
      if(avgR  < GateMinExpectancyR)
        {
         reason = "expectancy_agg_sym"; return false;
        }
      if(dd    > GateMaxDrawdownR)
        {
         reason = "drawdown_agg_sym"; return false;
        }
      if(pf    < GateMinProfitFactor)
        {
         reason = "profit_factor_agg_sym"; return false;
        }
      // Policy check for aggregated slice (if available)
      if(UsePolicyGating && g_policy_loaded)
        {
         double ppol = GetPolicyProb(strategy, symbol, timeframe);
         if(ppol>=0.0 && ppol < g_policy_min_conf)
           { reason = "policy_min_conf_agg_sym"; return false; }
        }
      reason = "agg_sym_ok"; return true;
     }

   // Fallback 2: aggregate by strategy across all symbols/timeframes
   total=0; wins=0.0; sumR=0.0; pf_sum=0.0; pf_cnt=0; worst_dd=0.0;
   for(int j=0;j<ArraySize(g_gate_strat);++j)
     if(g_gate_strat[j]==strategy)
       {
        total += g_gate_cnt[j];
        wins  += g_gate_wr[j]*g_gate_cnt[j];
        sumR  += g_gate_avgR[j]*g_gate_cnt[j];
        pf_sum+= g_gate_pf[j]; pf_cnt++;
        if(g_gate_dd[j]>worst_dd) worst_dd=g_gate_dd[j];
       }
   if(total>0)
     {
      double wr   = (total>0? wins/total : 0.0);
      double avgR = (total>0? sumR/total : 0.0);
      double pf   = (pf_cnt>0? pf_sum/pf_cnt : 0.0);
      double dd   = worst_dd;
      if(total < GateMinTrades)
        { reason = "min_trades_agg_strat"; return false; }
      if(wr    < GateMinWinRate)
        { reason = "win_rate_agg_strat"; return false; }
      if(avgR  < GateMinExpectancyR)
        { reason = "expectancy_agg_strat"; return false; }
      if(dd    > GateMaxDrawdownR)
        { reason = "drawdown_agg_strat"; return false; }
      if(pf    < GateMinProfitFactor)
        { reason = "profit_factor_agg_strat"; return false; }
      // Policy check for aggregated strategy (if available)
      if(UsePolicyGating && g_policy_loaded)
        {
         double ppol = GetPolicyProb(strategy, symbol, timeframe);
         if(ppol>=0.0 && ppol < g_policy_min_conf)
           { reason = "policy_min_conf_agg_strat"; return false; }
        }
      reason = "agg_strat_ok"; return true;
     }

   // If slice not found and gating disabled, allow
   if(!UseInsightsGating) return true;
   // Else, no exact slice exists. Exploration Mode: allow only when no slice, with day+week caps
   if(ExploreOnNoSlice)
     {
      // Strict policy: allow exploration ONLY when no slice exists
      bool has_slice = HasSlice(strategy, symbol, timeframe);
      if(has_slice)
        {
         reason = "slice_exists";
         return false;
        }
      string key = SliceKey(strategy, symbol, timeframe);
      int used_w = GetExploreCount(key);
      int used_d = GetExploreCountDay(key);
      if(ExploreMaxPerSlicePerDay > 0 && used_d >= ExploreMaxPerSlicePerDay)
        { reason = "explore_cap_day"; return false; }
      if(ExploreMaxPerSlice > 0 && used_w >= ExploreMaxPerSlice)
        { reason = "explore_cap_week"; return false; }
      if(!no_side_effects)
        g_explore_pending_key = key;
      reason = "explore_allow";
      return true;
     }
   reason = "no_slice";
   return false;
  }
 
// --- Spread/Session/Risk gating helpers and session tracking
double CurrentSpreadPoints()
  {
   double bid=0.0, ask=0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   if(ask>0.0 && bid>0.0) return (ask - bid) / _Point;
   return 0.0;
  }

datetime ComputeSessionBoundary(datetime now)
  {
   MqlDateTime dt; TimeToStruct(now, dt);
   dt.hour = SessionStartHour; dt.min=0; dt.sec=0;
   datetime today_boundary = StructToTime(dt);
   if(today_boundary > now) today_boundary -= 24*60*60; // yesterday if boundary in future
   return today_boundary;
  }

void EnsureSessionRollover()
  {
   datetime b = ComputeSessionBoundary(TimeCurrent());
   MqlDateTime dts; TimeToStruct(b, dts);
   int day = dts.year*10000 + dts.mon*100 + dts.day;
   if(g_session_start==0 || g_session_day!=day)
     {
      g_session_start = b;
      g_session_day   = day;
      g_session_equity_start = AccountInfoDouble(ACCOUNT_EQUITY);
      g_equity_highwater     = g_session_equity_start;
      if(ShouldLog(LOG_INFO)) PrintFormat("Session rollover: start=%s equity=%.2f",
        TimeToString(g_session_start, TIME_DATE|TIME_MINUTES), g_session_equity_start);
     }
  }

int CountNewTradesSince(const datetime t0)
  {
   int count=0;
   if(!HistorySelect(t0, TimeCurrent())) return 0;
   for(int i=0;i<HistoryDealsTotal();++i)
     {
      ulong dtk = HistoryDealGetTicket(i); if(dtk==0) continue;
      if((int)HistoryDealGetInteger(dtk, DEAL_ENTRY)!=DEAL_ENTRY_IN) continue;
      string ds = HistoryDealGetString(dtk, DEAL_SYMBOL);
      long   mg = (long)HistoryDealGetInteger(dtk, DEAL_MAGIC);
      if(ds==_Symbol && mg==MagicNumber) ++count;
     }
   return count;
  }

int CountConsecutiveLosses()
  {
   int consec=0;
   datetime t0 = TimeCurrent() - 120*86400; // scan up to 120 days
   if(!HistorySelect(t0, TimeCurrent())) return 0;
   for(int i=HistoryDealsTotal()-1; i>=0; --i)
     {
      ulong dtk = HistoryDealGetTicket(i);
      if(dtk==0) continue;
      string ds = HistoryDealGetString(dtk, DEAL_SYMBOL);
      long   mg = (long)HistoryDealGetInteger(dtk, DEAL_MAGIC);
      if(ds!=_Symbol || mg!=MagicNumber) continue;
      int entry_flag = (int)HistoryDealGetInteger(dtk, DEAL_ENTRY);
      if(entry_flag!=DEAL_ENTRY_OUT) continue;
      double profit = HistoryDealGetDouble(dtk, DEAL_PROFIT);
      if(profit < 0.0) ++consec;
      else if(profit > 0.0) break; // stop on first win
     }
   return consec;
  }

bool SpreadAllowed(string &reason)
  {
   reason = "ok";
   if(SpreadMaxPoints<=0.0) return true;
   double spr = CurrentSpreadPoints();
   if(spr <= SpreadMaxPoints) return true;
   reason = "spread_cap";
   return false;
  }

bool SessionAllowed(string &reason)
  {
   reason = "ok";
   if(SessionMaxTrades<=0) return true;
   int used = CountNewTradesSince(g_session_start);
   if(used < SessionMaxTrades) return true;
   reason = "session_cap";
   return false;
  }

bool RiskAllowed(string &reason)
  {
   reason = "ok";
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq>g_equity_highwater) g_equity_highwater = eq;
   if(MaxDailyLossPct>0.0 && g_session_equity_start>0.0)
     {
      double dd = 100.0*(g_session_equity_start - eq)/g_session_equity_start;
      if(dd >= MaxDailyLossPct) { reason="max_daily_loss"; return false; }
     }
   if(MaxDrawdownPct>0.0 && g_equity_highwater>0.0)
     {
      double ddh = 100.0*(g_equity_highwater - eq)/g_equity_highwater;
      if(ddh >= MaxDrawdownPct) { reason="max_drawdown"; return false; }
     }
   if(MinMarginLevel>0.0)
     {
      double ml = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
      if(ml>0.0 && ml < MinMarginLevel) { reason="margin_level"; return false; }
     }
   if(ConsecutiveLossLimit>0)
     {
     int cl = (P5_PersistLossCounters ? GetConsecLossPersist(_Symbol, MagicNumber) : CountConsecutiveLosses());
      if(cl >= ConsecutiveLossLimit) { reason="consec_losses"; return false; }
     }
  return true;
 }

 // --- Phase 5 advanced gating stubs (default-allow; telemetry wired in OnTick)
bool P5_CorrPruneAllow(const TradeOrder &order, string &reason)
  {
   reason = "ok";
   // No open positions -> nothing to prune
   int npos = PositionsTotal();
   if(npos<=0)
     return true;

   // Prefer PositionManager's portfolio correlation if available
   double avg_abs_corr = 0.0;
   bool corr_from_pm = (CheckPointer(g_position_manager)!=POINTER_INVALID);
   if(corr_from_pm)
     {
      avg_abs_corr = (*g_position_manager).GetPortfolioCorrelation(_Symbol);
     }
   else
     {
      // Manual weighted average absolute correlation to each open symbol
       int ps = PeriodSeconds(_Period);
       if(ps<=0) ps = 60;
       int approx_bars = (int)MathMax(50, MathMin(2000, (P5_CorrLookbackDays*86400)/ps));
       double sum=0.0, wsum=0.0;
       for(int i=0;i<npos;++i)
         {
          ulong ot = PositionGetTicket(i);
          if(ot==0) continue;
          string osym = PositionGetString(POSITION_SYMBOL);
          if(osym=="" || osym==_Symbol) continue;
         // selection is set by PositionGetTicket; read fields directly
         double vol = PositionGetDouble(POSITION_VOLUME);
         // Compute Pearson correlation between closes of _Symbol and osym
         double a[]; double b[];
         int ca = CopyClose(_Symbol, _Period, 0, approx_bars, a);
         int cb = CopyClose(osym,   _Period, 0, approx_bars, b);
         int m = MathMin(ca, cb);
         if(m<10) continue;
         double ma=0.0, mb=0.0; for(int k=0;k<m;++k){ ma+=a[k]; mb+=b[k]; }
         ma/=m; mb/=m;
         double cov=0.0, va=0.0, vb=0.0;
         for(int k=0;k<m;++k)
           {
            double da=a[k]-ma; double db=b[k]-mb;
            cov+=da*db; va+=da*da; vb+=db*db;
           }
         if(va<=0.0 || vb<=0.0) continue;
         double c = cov / MathSqrt(va*vb);
         if(c>1.0) c=1.0; if(c<-1.0) c=-1.0;
         sum += MathAbs(c) * vol;
         wsum += vol;
        }
      avg_abs_corr = (wsum>0.0? sum/wsum : 0.0);
    }

   if(avg_abs_corr > P5_CorrMax)
     {
      reason = StringFormat("corr=%.2f>max=%.2f", avg_abs_corr, P5_CorrMax);
      return false;
     }
   return true;
  }
 
 bool P5_MTFConfirmAllow(const TradeOrder &order, string &reason)
   {
    reason = "ok";
    // Disabled -> allow
    if(!P5_MTFConfirmEnable)
      { reason = "mtf_disabled"; return true; }
    // Selector must be available
    if(!(UseStrategySelector && CheckPointer(g_selector)!=POINTER_INVALID))
      { reason = "no_selector"; return true; }
    // Parse TF list
    string items[];
    int n = StringSplit(P5_MTFHigherTFs, ',', items);
    if(n<=0)
      { reason = "no_tfs"; return true; }

    int total=0, agree=0;
    // Accumulate brief details (capped) for reason string
    string det = ""; int det_added=0;
    for(int i=0;i<n;++i)
      {
       // Map token to timeframe
       string tok = items[i];
       StringTrimLeft(tok); StringTrimRight(tok);
       // Uppercase normalize without relying on return types of library helpers
       for(int jj=0; jj<StringLen(tok); ++jj)
         {
          int ch = (int)StringGetCharacter(tok, jj);
          if(ch>='a' && ch<='z')
            StringSetCharacter(tok, jj, (ushort)(ch-32));
         }
       int tf = -1;
       if(tok=="M1") tf = (int)PERIOD_M1;
       else if(tok=="M2") tf = (int)PERIOD_M2;
       else if(tok=="M3") tf = (int)PERIOD_M3;
       else if(tok=="M4") tf = (int)PERIOD_M4;
       else if(tok=="M5") tf = (int)PERIOD_M5;
       else if(tok=="M6") tf = (int)PERIOD_M6;
       else if(tok=="M10") tf = (int)PERIOD_M10;
       else if(tok=="M12") tf = (int)PERIOD_M12;
       else if(tok=="M15") tf = (int)PERIOD_M15;
       else if(tok=="M20") tf = (int)PERIOD_M20;
       else if(tok=="M30") tf = (int)PERIOD_M30;
       else if(tok=="H1") tf = (int)PERIOD_H1;
       else if(tok=="H2") tf = (int)PERIOD_H2;
       else if(tok=="H3") tf = (int)PERIOD_H3;
       else if(tok=="H4") tf = (int)PERIOD_H4;
       else if(tok=="H6") tf = (int)PERIOD_H6;
       else if(tok=="H8") tf = (int)PERIOD_H8;
       else if(tok=="H12") tf = (int)PERIOD_H12;
       else if(tok=="D1") tf = (int)PERIOD_D1;
       else if(tok=="W1") tf = (int)PERIOD_W1;
       else if(tok=="MN1" || tok=="MO1" || tok=="MONTH" || tok=="MN") tf = (int)PERIOD_MN1;
       if(tf<0) continue;
       // Skip if identical to current TF to ensure it's truly higher/different
       if(tf == (int)_Period) continue;
       total++;
       double s = (*g_selector).Score(_Symbol, (ENUM_TIMEFRAMES)tf, order.strategy_name);
       bool ok = (s > 0.0);
       if(ok) agree++;
       if(det_added<3)
         {
          string nm = EnumToString((ENUM_TIMEFRAMES)tf);
          det += (det==""? "" : ", ") + StringFormat("%s:%.3f%s", nm, s, (ok?"+":"-"));
          det_added++;
         }
      }

    if(total<=0)
      { reason = "no_valid_tfs"; return true; }
    if(P5_MTFMinAgree<=0)
      { reason = StringFormat("agree=%d/%d(skip_min)", agree, total); return true; }

    bool pass = (agree >= P5_MTFMinAgree);
    reason = StringFormat("agree=%d/%d need>=%d [%s]", agree, total, P5_MTFMinAgree, det);
    return pass;
   }
 
 bool P5_StabilityAllow(const TradeOrder &order, string &reason)
  {
   reason = "ok";
   // Read recent R-multiples from features.csv for this strategy+symbol, compute std-dev
   datetime cutoff = TimeCurrent() - (P5_StabilityWindowDays*24*60*60);
   int h = FileOpen("DualEA\\features.csv", FILE_READ|FILE_TXT|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_COMMON|FILE_ANSI);
   if(h==INVALID_HANDLE)
     {
      // No features available -> cannot assess; allow with reason
      reason = "no_features";
      return true;
     }
   double vals[]; ArrayResize(vals, 0);
   // Build normalized symbol for comparison (strip common broker suffixes)
   string cur_sym = _Symbol; string cur_low = cur_sym; StringToLower(cur_low);
   string suf[] = { "_otc", "_pro", "_ecn", "_mini", "_micro", ".r", ".i", ".pro", ".ecn", ".m" };
   for(int si=0; si<ArraySize(suf); ++si)
     {
      int p = StringFind(cur_low, suf[si], StringLen(cur_low)-StringLen(suf[si]));
      if(p>=0 && p==StringLen(cur_low)-StringLen(suf[si]))
        { cur_sym = StringSubstr(cur_sym, 0, StringLen(cur_sym)-StringLen(suf[si])); break; }
     }
   while(!FileIsEnding(h))
     {
      string line = FileReadString(h);
      if(line=="" && FileIsEnding(h)) break;
      // Expect CSV: ts,symbol,strategy,key,value
      int p0 = StringFind(line, ",", 0); if(p0<0) continue; string ts  = StringSubstr(line,0,p0);
      int p1 = StringFind(line, ",", p0+1); if(p1<0) continue; string sym = StringSubstr(line,p0+1,p1-p0-1);
      int p2 = StringFind(line, ",", p1+1); if(p2<0) continue; string strat = StringSubstr(line,p1+1,p2-p1-1);
      int p3 = StringFind(line, ",", p2+1); if(p3<0) continue; string key = StringSubstr(line,p2+1,p3-p2-1);
      string val = StringSubstr(line,p3+1);
      StringTrimLeft(sym); StringTrimRight(sym);
      StringTrimLeft(strat); StringTrimRight(strat);
      StringTrimLeft(key); StringTrimRight(key);
      if(StringCompare(key, "r_multiple")!=0) continue;
      // Normalize symbol in row similarly
      string row_sym = sym; string row_low = row_sym; StringToLower(row_low);
      for(int si=0; si<ArraySize(suf); ++si)
        {
         int p = StringFind(row_low, suf[si], StringLen(row_low)-StringLen(suf[si]));
         if(p>=0 && p==StringLen(row_low)-StringLen(suf[si]))
           { row_sym = StringSubstr(row_sym, 0, StringLen(row_sym)-StringLen(suf[si])); break; }
        }
      if(row_sym!=cur_sym) continue;
      if(strat!=order.strategy_name) continue;
      datetime t = (datetime)StringToTime(ts); if(t<cutoff) continue;
      double r = StringToDouble(val);
      int n=ArraySize(vals); ArrayResize(vals,n+1); vals[n]=r;
     }
   FileClose(h);
   int m = ArraySize(vals);
   if(m<5)
     {
      reason = "insufficient_data";
      return true;
     }
   double mean=0.0; for(int i=0;i<m;++i) mean+=vals[i]; mean/=m;
   double var=0.0; for(int i=0;i<m;++i){ double d=vals[i]-mean; var+=d*d; } var/=m;
   double stdr = MathSqrt(var);
   if(stdr > P5_StabilityMaxStdR)
     {
      reason = StringFormat("stdR=%.2f>max=%.2f cnt=%d", stdr, P5_StabilityMaxStdR, m);
       return false;
     }
   return true;
  }

// Emit periodic scan/gating status and show a small on-chart panel
void LogHeartbeat()
  {
   string ts = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   int tf = (int)_Period;
   double bid=0.0, ask=0.0; SymbolInfoDouble(_Symbol, SYMBOL_BID, bid); SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   double spread_pts = 0.0; if(ask>0.0 && bid>0.0) spread_pts = (ask - bid) / _Point;
   int nstrats = (CheckPointer(g_strategies)!=POINTER_INVALID ? (int)g_strategies.Total() : 0);

   // SCAN
   if(ShouldLog(LOG_INFO)) PrintFormat("[SCAN] %s tf=%d time=%s strats=%d spread_pts=%.1f", _Symbol, tf, ts, nstrats, spread_pts);

   // STRAT lines
   if(HeartbeatVerbose && CheckPointer(g_strategies)!=POINTER_INVALID)
     {
      for(int i=0;i<g_strategies.Total();++i)
        {
         IStrategy *st = (IStrategy*)g_strategies.At(i);
         if(CheckPointer(st)==POINTER_INVALID) continue;
         string nm = st.Name();
         double wr = -1.0;
         if(CheckPointer(g_selector)!=POINTER_INVALID)
           wr = (*g_selector).GetWinRate(_Symbol, tf, nm, true);
         string ps = (wr<0.0?"-":DoubleToString(wr,3));
         if(ShouldLog(LOG_INFO)) PrintFormat("[STRAT] %s p_win=%s", nm, ps);
        }
     }

   // GATE summary
   string gsum = StringFormat("insights=%s policy=%s(min=%.3f) explore=%s caps(slice=%d/day=%d)",
      (UseInsightsGating?"on":"off"), (UsePolicyGating?"on":"off"), g_policy_min_conf,
      (ExploreOnNoSlice?"on":"off"), ExploreMaxPerSlice, ExploreMaxPerSlicePerDay);
   if(ShouldLog(LOG_INFO)) PrintFormat("[GATE] %s", gsum);

   // Panel
   string panel = StringFormat("DualEA Heartbeat\n%s tf=%d\nstrats=%d spread_pts=%.1f\n%s",
      _Symbol, tf, nstrats, spread_pts, gsum);
   Comment(panel);
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Core services
   if(CheckPointer(g_kb)==POINTER_INVALID)
      g_kb = new CKnowledgeBase();
   if(CheckPointer(g_features)==POINTER_INVALID)
      g_features = new CFeaturesKB();
   if(CheckPointer(g_trade_manager)==POINTER_INVALID)
      g_trade_manager = new CTradeManager(_Symbol, LotSize, MagicNumber);

   // Optional: PositionManager (behind UsePositionManager)
   if(UsePositionManager)
     {
      if(CheckPointer(g_position_manager)==POINTER_INVALID)
        {
         g_position_manager = new CPositionManager();
         if(CheckPointer(g_position_manager)!=POINTER_INVALID)
           {
            bool pm_ok = (*g_position_manager).InitializeSimple(_Symbol, TrailATRPeriod, TrailActivationPoints, TrailDistancePoints, TrailStepPoints);
            (*g_position_manager).SetMagicNumber(MagicNumber);
            // Enable ATR-based volatility exit using input multiplier
            (*g_position_manager).SetVolatilityExit(true, TrailATRMultiplier);
            if(!pm_ok) { Print("[PM] InitializeSimple failed; continuing without PositionManager enhancements"); }
           }
        }
     }
   else
     {
      if(CheckPointer(g_position_manager)!=POINTER_INVALID){ delete g_position_manager; g_position_manager=NULL; }
     }

    // Telemetry
    if(TelemetryEnabled)
     {
      g_telemetry = new CTelemetry(_Symbol, TelemetryExperiment, TelemetryBufferMax, (int)_Period);
      if(CheckPointer(g_telemetry)==POINTER_INVALID)
        {
         Print("Failed to create telemetry instance");
         return INIT_FAILED;
        }
      g_tel_standard = new CTelemetryStandard(g_telemetry);
     }

   // Initialize FR-02 Session Manager
   if(UseSessionManager)
     {
      g_session_manager = new CSessionManager(_Symbol, _Period);
      g_session_manager.SetEnabled(true);
      g_session_manager.SetSessionHours(SessionStartHour, SessionEndHour);
      g_session_manager.SetMaxTradesPerSession(MaxTradesPerSession);
      g_session_manager.SetMaxDailyLossPct(MaxDailyLossPct);
     }

   // Initialize FR-05 Correlation Manager
   if(UseCorrelationManager)
     {
      g_correlation_manager = new CCorrelationManager(_Symbol, _Period);
      g_correlation_manager.SetEnabled(true);
      g_correlation_manager.SetMaxCorrelation(MaxCorrelationLimit);
      g_correlation_manager.SetLookbackDays(CorrLookbackDays);
     }

   // Initialize FR-06 Volatility Sizer
   if(UseVolatilitySizer)
     {
      g_volatility_sizer = new CVolatilitySizer(_Symbol, _Period);
      g_volatility_sizer.SetEnabled(true);
      g_volatility_sizer.SetATRPeriod(VolSizerATRPeriod);
      g_volatility_sizer.SetBaseATRPercent(VolSizerBaseATRPct);
      g_volatility_sizer.SetMultiplierRange(VolSizerMinMult, VolSizerMaxMult);
      g_volatility_sizer.SetTargetRiskPercent(VolSizerTargetRisk);
     }

   // Reset pending mappings and tracking arrays to ensure a clean state on (re)init
   ArrayResize(g_pending_orders, 0);
   ArrayResize(g_pending_orders_strat, 0);
   ArrayResize(g_pending_deals, 0);
   ArrayResize(g_pending_deals_strat, 0);
   ArrayResize(g_pos_ids, 0);
   ArrayResize(g_pos_strats, 0);
   ArrayResize(g_pos_entry_price, 0);
   ArrayResize(g_pos_initial_risk, 0);
   ArrayResize(g_pos_start_time, 0);
   ArrayResize(g_pos_type, 0);
   ArrayResize(g_pos_max_price, 0);
   ArrayResize(g_pos_min_price, 0);
   g_explore_pending_key = "";
   // Reset explore-cap dedupe state
   g_ecap_bar_time = 0;
   ArrayResize(g_ecap_keys, 0);
   ArrayResize(g_ecap_counts, 0);
   ArrayResize(g_ecap_printed_once, 0);

   // Strategy selector
   if(CheckPointer(g_selector)==POINTER_INVALID)
      {
       g_selector = new CStrategySelector();
      (*g_selector).ConfigureWeights(SelW_PF, SelW_Exp, SelW_WR, SelW_DD);
     (*g_selector).ConfigureRecency(SelUseRecency, SelRecentDays, SelRecAlpha);
      // Align thresholds with gating inputs
      (*g_selector).ConfigureThresholds(GateMinTrades, GateMinWinRate, GateMinExpectancyR, GateMinProfitFactor, GateMaxDrawdownR);
      // Toggle strict thresholds inside selector scoring
      (*g_selector).SetStrictThresholds(SelStrictThresholds);
      // Log selector configuration for transparency
      if(ShouldLog(LOG_INFO))
        {
         PrintFormat("Selector config: w_pf=%.3f w_exp=%.3f w_wr=%.3f w_dd=%.3f recency=%s days=%d alpha=%.3f strict=%s",
           SelW_PF, SelW_Exp, SelW_WR, SelW_DD,
           (SelUseRecency?"true":"false"), SelRecentDays, SelRecAlpha,
           (SelStrictThresholds?"true":"false"));
         PrintFormat("Selector thresholds: min_trades=%d min_wr=%.2f min_exp=%.2f min_pf=%.2f max_dd=%.2f",
           GateMinTrades, GateMinWinRate, GateMinExpectancyR, GateMinProfitFactor, GateMaxDrawdownR);
        }
      // Load insights and recent overlays
      bool ok_ins = (*g_selector).Load();
      bool ok_rec = (*g_selector).LoadRecent();
      PrintFormat("Selector init: insights=%s recent=%s", (ok_ins?"ok":"fail"), (ok_rec?"ok":"skip/fail"));
     }

   // Initialize strategies container and register strategies for current symbol/timeframe
   if(CheckPointer(g_strategies)==POINTER_INVALID)
      g_strategies = new CArrayObj();
   // Clear any existing to avoid duplicates across re-inits
   if(CheckPointer(g_strategies)!=POINTER_INVALID && g_strategies.Total()>0)
     {
      for(int i=0;i<g_strategies.Total();++i)
        {
         CObject* obj = (CObject*)g_strategies.At(i);
         if(CheckPointer(obj)!=POINTER_INVALID) delete obj;
        }
      g_strategies.Clear();
     }
   // Add verified strategies (for _Symbol/_Period)
   if(CheckPointer(g_strategies)!=POINTER_INVALID)
     {
      // Register strategies dynamically per asset class for this symbol/timeframe
      RegisterStrategiesForSymbol(g_strategies, _Symbol, (ENUM_TIMEFRAMES)_Period);
     }

   // Load insights gating cache for Insights_Allow()/HasSlice()
   bool gate_loaded = Insights_Load();
   if(ShouldLog(LOG_INFO)) PrintFormat("Insights gating cache load: %s", (gate_loaded?"ok":"fail"));
   // Load policy gating cache
   if(UsePolicyGating)
     {
      bool pol_ok = Policy_Load();
      if(ShouldLog(LOG_INFO)) PrintFormat("Policy gating cache load: %s", (pol_ok?"ok":"fail"));
     }

   // Auto-build insights if missing or stale
   if(InsightsAutoBuild)
     {
      bool stale = Insights_IsStale(InsightsStaleHours);
      if(stale)
        Insights_RebuildAndReload("OnInit-stale-or-missing");
     }

   // Load persistent exploration counters (weekly and daily)
   bool wk_ok = LoadExploreCounts();
   bool dy_ok = LoadExploreCountsDay();
   if(ShouldLog(LOG_INFO)) PrintFormat("Explore counters loaded: week=%s day=%s", (wk_ok?"ok":"fail"), (dy_ok?"ok":"fail"));

   // Load persistent loss counters (optional)
   if(P5_PersistLossCounters)
     {
      bool lc_ok = LoadLossCounters();
      if(ShouldLog(LOG_INFO)) PrintFormat("Loss counters loaded: %s", (lc_ok?"ok":"fail"));
     }

   // Heartbeat timer
    if(HeartbeatEnabled && HeartbeatMinutes>0)
      {
       int sec = HeartbeatMinutes*60; if(sec<1) sec=1;
       EventSetTimer(sec);
       // emit an immediate heartbeat so user sees status without waiting
       LogHeartbeat();
      }
   // Mode banner: NoConstraintsMode disables all gating and caps
   if(NoConstraintsMode)
     {
      if(ShouldLog(LOG_INFO)) Print("Mode: NoConstraintsMode=true -> bypass trading hours, selector gating, insights gating, exploration caps (0=unlimited), and MaxOpenPositions");
     }
   // Initialize session baseline and high-water marks
   EnsureSessionRollover();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    // Persist exploration counters
    SaveExploreCounts();
    SaveExploreCountsDay();

    // Persist loss counters when enabled
    if(P5_PersistLossCounters)
      SaveLossCounters();

    // Telemetry flush & dispose
    if(CheckPointer(g_telemetry)!=POINTER_INVALID)
      {
       // session end marker
       if(TelemetryEnabled)
         (*g_telemetry).LogEvent(_Symbol, (int)_Period, "sys", "deinit", StringFormat("reason=%d", reason));
       (*g_telemetry).Flush();
       delete g_telemetry; g_telemetry=NULL;
      }

    // Clear pending mappings and tracking arrays to free memory and avoid leakage across reinitializations
    ArrayResize(g_pending_orders, 0);
    ArrayResize(g_pending_orders_strat, 0);
    ArrayResize(g_pending_deals, 0);
    ArrayResize(g_pending_deals_strat, 0);
    ArrayResize(g_pos_ids, 0);
    ArrayResize(g_pos_strats, 0);
    ArrayResize(g_pos_entry_price, 0);
    ArrayResize(g_pos_initial_risk, 0);
    ArrayResize(g_pos_start_time, 0);
    ArrayResize(g_pos_type, 0);
    ArrayResize(g_pos_max_price, 0);
    ArrayResize(g_pos_min_price, 0);
    g_explore_pending_key = "";
    // Reset explore-cap dedupe state
    g_ecap_bar_time = 0;
    ArrayResize(g_ecap_keys, 0);
    ArrayResize(g_ecap_counts, 0);
    ArrayResize(g_ecap_printed_once, 0);

    // Dispose strategies
    if(CheckPointer(g_strategies)!=POINTER_INVALID)
      {
       for(int i=0;i<g_strategies.Total();++i)
         {
         CObject* obj = (CObject*)g_strategies.At(i);
         if(CheckPointer(obj)!=POINTER_INVALID) delete obj;
        }
      g_strategies.Clear();
      delete g_strategies; g_strategies=NULL;
     }
   // Dispose services
   if(CheckPointer(g_selector)!=POINTER_INVALID){ delete g_selector; g_selector=NULL; }
   if(CheckPointer(g_trade_manager)!=POINTER_INVALID){ delete g_trade_manager; g_trade_manager=NULL; }
   if(CheckPointer(g_features)!=POINTER_INVALID){ delete g_features; g_features=NULL; }
   if(CheckPointer(g_kb)!=POINTER_INVALID){ delete g_kb; g_kb=NULL; }
   if(CheckPointer(g_position_manager)!=POINTER_INVALID){ delete g_position_manager; g_position_manager=NULL; }
   if(CheckPointer(g_tel_standard)!=POINTER_INVALID){ delete g_tel_standard; g_tel_standard=NULL; }
   if(CheckPointer(g_session_manager)!=POINTER_INVALID){ delete g_session_manager; g_session_manager=NULL; }
   if(CheckPointer(g_correlation_manager)!=POINTER_INVALID){ delete g_correlation_manager; g_correlation_manager=NULL; }
   if(CheckPointer(g_volatility_sizer)!=POINTER_INVALID){ delete g_volatility_sizer; g_volatility_sizer=NULL; }
   if(HeartbeatEnabled) { EventKillTimer(); Comment(""); }
  }

//+------------------------------------------------------------------+
//| Timer event                                                       |
//+------------------------------------------------------------------+
void OnTimer()
  {
   // Always allow policy reload checks on timer
   CheckPolicyReload();
   // On-demand insights rebuild via flag in Common Files
   CheckInsightsReload();
    // Periodic staleness check and auto-rebuild
    if(InsightsAutoBuild)
      {
       if(Insights_IsStale(InsightsStaleHours))
        Insights_RebuildAndReload("OnTimer-stale");
      }
    // Flush telemetry periodically regardless of heartbeat setting
    if(CheckPointer(g_telemetry)!=POINTER_INVALID)
        (*g_telemetry).Flush();
   if(!HeartbeatEnabled || HeartbeatMinutes<=0) return;
   LogHeartbeat();
  }

// Helper: find the most recent deal ticket for this symbol/magic from history
ulong FindLatestDealForSymbolMagic(const string sym, const int magic)
  {
   datetime t0 = TimeCurrent() - 7*86400;
   HistorySelect(t0, TimeCurrent());
   for(int i=HistoryDealsTotal()-1; i>=0; --i)
     {
      ulong dtk = HistoryDealGetTicket(i); if(dtk==0) continue;
      if((int)HistoryDealGetInteger(dtk, DEAL_ENTRY)!=DEAL_ENTRY_IN) continue;
      string ds = HistoryDealGetString(dtk, DEAL_SYMBOL);
      long   mg = (long)HistoryDealGetInteger(dtk, DEAL_MAGIC);
      if(ds==sym && (magic<=0 || mg==magic))
         return dtk;
     }
   return 0;
  }

// Helper: find the most recent pending order ticket for this symbol/magic from order pool
ulong FindLatestOrderForSymbolMagic(const string sym, const int magic)
  {
   ulong best=0; datetime best_ts=0;
   int total = OrdersTotal();
   for(int i=0; i<total; ++i)
     {
      ulong otk = OrderGetTicket(i);
      if(otk==0) continue;
      if(!OrderSelect(otk)) continue;
      string os = OrderGetString(ORDER_SYMBOL);
      long   mg = (long)OrderGetInteger(ORDER_MAGIC);
      if(os!=sym || (magic>0 && mg!=magic)) continue;
      datetime ts = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(ts>=best_ts) { best_ts=ts; best=otk; }
     }
   return best;
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
  // Runtime policy reload support
  CheckPolicyReload();
  // Early gating checks (parity with LiveEA): NEWS, PROMO, REGIME, CIRCUIT
  if(!EarlyGatesAllow())
    {
     if(ShouldLog(LOG_INFO)) Print("[EARLY] gates blocked tick");
     return;
    }
   // Maintain session baseline/high-water on each tick
   EnsureSessionRollover();
//--- Always update trailing stops for open positions managed by our magic number
   if(CheckPointer(g_trade_manager)!=POINTER_INVALID)
     {
      (*g_trade_manager).UpdateTrailingStops();
     }
 //--- Optional time-of-day trading hours gate
  if(!NoConstraintsMode && UseTradingHours)
    {
     if(IsLikelyCryptoSymbol(_Symbol))
       {
        // Crypto allowed 24/7; skip session gating
       }
     else
       {
        MqlDateTime _tm; TimeToStruct(TimeCurrent(), _tm); int hr = _tm.hour;
        bool within=false;
        if(TradingStartHour<=TradingEndHour)
          within = (hr>=TradingStartHour && hr<TradingEndHour);
        else
          within = (hr>=TradingStartHour || hr<TradingEndHour); // overnight window
        if(!within)
          {
           // Outside trading hours: do not open new trades (still manage trailing above)
           return;
          }
       }
    }
//--- Update MFE/MAE extremes for active positions
   int pos_total = PositionsTotal();
   for(int i=0; i<pos_total; ++i)
     {
      ulong t = PositionGetTicket(i);
      if(t==0) continue;
      string psym = PositionGetString(POSITION_SYMBOL);
      if(psym=="") continue;
      long   pmag = PositionGetInteger(POSITION_MAGIC);
      if(psym!=_Symbol || pmag!=MagicNumber) continue;
      ulong  pid  = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      double pcur = PositionGetDouble(POSITION_PRICE_CURRENT);
      // find index
      int idx = -1;
      for(int t=0; t<ArraySize(g_pos_ids); ++t) { if(g_pos_ids[t]==pid) { idx=t; break; } }
      if(idx<0) continue;
      if(pcur>g_pos_max_price[idx]) g_pos_max_price[idx]=pcur;
     if(pcur<g_pos_min_price[idx]) g_pos_min_price[idx]=pcur;
    }
  //--- Volatility exit checks via PositionManager (ATR trail, etc.)
 if(UsePositionManager && CheckPointer(g_position_manager)!=POINTER_INVALID)
  {
     for(int i=0; i<PositionsTotal(); ++i)
       {
        ulong t2 = PositionGetTicket(i);
        if(t2==0) continue;
        string psym2 = PositionGetString(POSITION_SYMBOL);
        if(psym2=="") continue;
        if(psym2!=_Symbol) continue;
        long pmag2 = PositionGetInteger(POSITION_MAGIC);
        if(pmag2!=MagicNumber) continue;
        ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
        double close_px = 0.0; string reason = "";
        if((*g_position_manager).CheckExitConditions(ticket, close_px, reason))
          {
           (*g_position_manager).ClosePosition(ticket, reason);
          }
       }
    }
   //--- Detect closed positions and log outcomes (r_multiple + KB close record)
   for(int i=0; i<ArraySize(g_pos_ids); )
     {
      ulong pid = g_pos_ids[i];
      // If position is no longer open, attempt to log its closure
      if(!PositionSelectByTicket(pid))
        {
         // Search recent history for the closing deal of this position
         datetime t0 = (g_pos_start_time[i]>0? g_pos_start_time[i] - 3600 : TimeCurrent() - 7*86400);
         HistorySelect(t0, TimeCurrent());
         ulong close_deal = 0;
         for(int d = HistoryDealsTotal()-1; d>=0; --d)
           {
            ulong deal_ticket = HistoryDealGetTicket(d);
            if((ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID)==pid)
              {
               int entry_flag = (int)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
               if(entry_flag==DEAL_ENTRY_OUT)
                 { close_deal = deal_ticket; break; }
              }
           }
         if(close_deal>0)
           {
            HandlePositionClosed(i, close_deal);
            continue; // re-check swapped element index i
           }
        }
      ++i;
     }
//--- Iterate through each strategy
   if(CheckPointer(g_strategies)==POINTER_INVALID)
     {
      Print("Error: g_strategies not initialized; skipping tick.");
      return;
     }
  // --- Phase 5: PickBest execution mode (optional pre-scan to choose one strategy) ---
  int chosen_only = -1;
  if(P5_PickBestEnable && UseStrategySelector && CheckPointer(g_selector)!=POINTER_INVALID)
    {
     // Pre-scan to collect strategies with signals
     string cand_names[]; int cand_index[];
     for(int i=0; i<g_strategies.Total(); ++i)
       {
        IStrategy* st_pre = (IStrategy*)g_strategies.At(i);
        if(CheckPointer(st_pre)==POINTER_INVALID) continue;
        (*st_pre).Refresh();
        TradeOrder ord_pre = (*st_pre).CheckSignal();
        if(ord_pre.action != ACTION_NONE)
          {
           int n = ArraySize(cand_names);
           ArrayResize(cand_names, n+1); ArrayResize(cand_index, n+1);
           cand_names[n] = (*st_pre).Name(); cand_index[n] = i;
          }
       }
     if(ArraySize(cand_names)>0)
       {
        double scores[];
        int best_local = (*g_selector).PickBest(_Symbol, _Period, cand_names, scores);
        if(best_local>=0 && best_local<ArraySize(cand_index))
          {
           // Only accept if score is positive; otherwise fall back to normal loop
           if(ArraySize(scores)>best_local && scores[best_local]>0.0)
             chosen_only = cand_index[best_local];
          }
       }
    }
  for(int i = 0; i < g_strategies.Total(); i++)
    {
     // Safely cast to the interface pointer
     IStrategy* strategy = (IStrategy*)g_strategies.At(i);
     if(CheckPointer(strategy) == POINTER_INVALID)
       {
        Print("Error: Could not cast strategy at index ", i);
        continue;
       }

     // If PickBest selected a single candidate, skip others
     if(P5_PickBestEnable && chosen_only>=0 && i!=chosen_only)
       continue;

      // Refresh strategy data (e.g., update indicator values)
      (*strategy).Refresh();

      // Check for a trade signal
      TradeOrder order = (*strategy).CheckSignal();

      // If a signal is returned, process it
       if(order.action != ACTION_NONE)
         {
         // Telemetry: shadow gating when NoConstraintsMode bypasses real gates
         if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
           {
            // Shadow selector gating
            if(NoConstraintsMode && UseStrategySelector && CheckPointer(g_selector)!=POINTER_INVALID)
              {
               double s_shadow = (*g_selector).Score(_Symbol, _Period, (*strategy).Name());
               string rsel = (s_shadow>0.0? "score>0" : "score<=0");
               (*g_telemetry).LogGatingShadow((*strategy).Name(), _Symbol, (int)_Period, "selector", (s_shadow>0.0), rsel, true);
              }
            // Shadow insights gating (no side effects, ignore NoConstraints bypass)
            if(NoConstraintsMode && UseInsightsGating)
              {
               string rshadow=""; bool allow_shadow = Insights_Allow(order.strategy_name, _Symbol, _Period, rshadow, true, true);
               (*g_telemetry).LogGatingShadow(order.strategy_name, _Symbol, (int)_Period, "insights", allow_shadow, rshadow, true);
              }
            // Shadow Phase 4 risk gates when NoConstraintsMode bypasses them
            if(NoConstraintsMode)
              {
               string r_sp=""; bool ok_sp = SpreadAllowed(r_sp);
               (*g_telemetry).LogGatingShadow(order.strategy_name, _Symbol, (int)_Period, "risk4_spread", ok_sp, r_sp, true);
               string r_se=""; bool ok_se = SessionAllowed(r_se);
               (*g_telemetry).LogGatingShadow(order.strategy_name, _Symbol, (int)_Period, "risk4_session", ok_se, r_se, true);
               string r_rk=""; bool ok_rk = RiskAllowed(r_rk);
               (*g_telemetry).LogGatingShadow(order.strategy_name, _Symbol, (int)_Period, "risk4", ok_rk, r_rk, true);
              }
           }
         // Optional: selector gate using insights-based score
          if(!NoConstraintsMode && UseStrategySelector && CheckPointer(g_selector)!=POINTER_INVALID)
            {
             double s = (*g_selector).Score(_Symbol, _Period, (*strategy).Name());
             if(s<=0.0)
               {
                // If exploration quota remains for this slice, bypass selector during bootstrap
                 if(ExploreOnNoSlice)
                   {
                    string ekey = SliceKey((*strategy).Name(), _Symbol, _Period);
                    bool has_slice = HasSlice((*strategy).Name(), _Symbol, _Period);
                    int used_w = GetExploreCount(ekey);
                    int used_d = GetExploreCountDay(ekey);
                    // Relaxed: allow exploration even if a slice exists, as long as caps permit
                     {
                      bool day_ok = (ExploreMaxPerSlicePerDay==0 || used_d < ExploreMaxPerSlicePerDay);
                      bool week_ok = (ExploreMaxPerSlice==0 || used_w < ExploreMaxPerSlice);
                      if(day_ok && week_ok)
                       {
                        if(ShouldLog(LOG_INFO)) PrintFormat("Selector gate: exploration allow %s on %s/%d (score=%.3f) (day=%d/%d, week=%d/%d) slice_exists=%s", (*strategy).Name(), _Symbol, (int)_Period, s, used_d, ExploreMaxPerSlicePerDay, used_w, ExploreMaxPerSlice, (has_slice?"true":"false"));
                        g_explore_pending_key = ekey;
                        if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                          (*g_telemetry).LogGating(_Symbol, (int)_Period, (*strategy).Name(), "selector", true, "explore_selector");
                       }
                      else
                       {
                        ECapFlushSummaryIfNewBar();
                        string ecap_key_sel = StringFormat("%s|%s|%d", (*strategy).Name(), _Symbol, (int)_Period);
                        bool first_sel = ECapIncrement(ecap_key_sel);
                        if(first_sel && ShouldLog(LOG_DEBUG)) PrintFormat("Selector gate: blocked %s on %s/%d reason=%s (day=%d/%d, week=%d/%d) slice_exists=%s", (*strategy).Name(), _Symbol, (int)_Period, "explore_cap", used_d, ExploreMaxPerSlicePerDay, used_w, ExploreMaxPerSlice, (has_slice?"true":"false"));
                        ECapMarkPrinted(ecap_key_sel);
                        if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                          (*g_telemetry).LogGating(_Symbol, (int)_Period, (*strategy).Name(), "selector", false, "explore_cap");
                        continue;
                       }
                     }
                   }
                 else
                   {
                    if(ShouldLog(LOG_INFO)) PrintFormat("Selector gate: blocked %s on %s/%d (score=%.3f)", (*strategy).Name(), _Symbol, (int)_Period, s);
                    if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                      (*g_telemetry).LogGating(_Symbol, (int)_Period, (*strategy).Name(), "selector", false, "score<=0");
                    continue;
                   }
               }
            }
         // Position guard: block when total open positions reach limit
         if(MaxOpenPositions > 0 && PositionsTotal() >= MaxOpenPositions) 
           {
            if(ShouldLog(LOG_INFO)) PrintFormat("EXEC: blocked %s on %s/%s due to MaxOpenPositions=%d (PositionsTotal=%d)", order.strategy_name, _Symbol, EnumToString(_Period), MaxOpenPositions, PositionsTotal());
            return;
           }

         // If strategy did not provide trailing settings, apply defaults from inputs
         if(TrailEnabled && !order.trailing_enabled)
           {
            order.trailing_enabled          = true;
            order.trailing_type             = (TrailingType)TrailType;
            order.trail_activation_points   = TrailActivationPoints;
            order.trail_distance_points     = TrailDistancePoints;
            order.trail_step_points         = TrailStepPoints;
            // ATR params always set so strategies can opt-in by setting trailing_type=TRAIL_ATR
            order.atr_period                = TrailATRPeriod;
            order.atr_multiplier            = TrailATRMultiplier;
           }

           // Insights-based gating before execution
            if(!NoConstraintsMode && UseInsightsGating)
              {
               string gate_reason="";
               if(!Insights_Allow(order.strategy_name, _Symbol, _Period, gate_reason))
                 {
                  if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                    (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "insights", false, gate_reason);
                  // If selector granted exploration for this exact slice, bypass insights thresholds when caps allow
                  string ekeyB = SliceKey(order.strategy_name, _Symbol, _Period);
                  if(g_explore_pending_key == ekeyB)
                    {
                     int used_d2 = GetExploreCountDay(ekeyB);
                     int used_w2 = GetExploreCount(ekeyB);
                     bool day_ok2 = (ExploreMaxPerSlicePerDay==0 || used_d2 < ExploreMaxPerSlicePerDay);
                     bool week_ok2 = (ExploreMaxPerSlice==0 || used_w2 < ExploreMaxPerSlice);
                     if(day_ok2 && week_ok2)
                       {
                        bool has_slice = HasSlice(order.strategy_name, _Symbol, _Period);
                        PrintFormat("GATE: explore allow %s on %s/%s reason=%s->explore_selector (day=%d/%d, week=%d/%d) slice_exists=%s", order.strategy_name, _Symbol, EnumToString(_Period), gate_reason, used_d2, ExploreMaxPerSlicePerDay, used_w2, ExploreMaxPerSlice, (has_slice?"true":"false"));
                        if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                          (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "insights", true, "explore_selector");
                        // fall through to execution
                       }
                     else
                       {
                        bool has_slice = HasSlice(order.strategy_name, _Symbol, _Period);
                        ECapFlushSummaryIfNewBar();
                        string ecap_key_gate = StringFormat("%s|%s|%d", order.strategy_name, _Symbol, (int)_Period);
                        bool first_gate = ECapIncrement(ecap_key_gate);
                        if(first_gate && ShouldLog(LOG_DEBUG)) PrintFormat("GATE: blocked %s on %s/%s reason=%s (day=%d/%d, week=%d/%d) slice_exists=%s", order.strategy_name, _Symbol, EnumToString(_Period), "explore_cap", used_d2, ExploreMaxPerSlicePerDay, used_w2, ExploreMaxPerSlice, (has_slice?"true":"false"));
                        ECapMarkPrinted(ecap_key_gate);
                        if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                          (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "insights", false, "explore_cap");
                        return;
                       }
                    }
                  else
                    {
                     bool has_slice = HasSlice(order.strategy_name, _Symbol, _Period);
                     // Add usage context when cap triggers
                     if(StringFind(gate_reason, "explore_cap", 0) == 0)
                       {
                        ECapFlushSummaryIfNewBar();
                        string ecap_key_gate2 = StringFormat("%s|%s|%d", order.strategy_name, _Symbol, (int)_Period);
                        bool first_gate2 = ECapIncrement(ecap_key_gate2);
                        if(first_gate2 && ShouldLog(LOG_DEBUG)) PrintFormat("GATE: blocked %s on %s/%s reason=%s (day=%d/%d, week=%d/%d) slice_exists=%s", order.strategy_name, _Symbol, EnumToString(_Period), gate_reason, GetExploreCountDay(ekeyB), ExploreMaxPerSlicePerDay, GetExploreCount(ekeyB), ExploreMaxPerSlice, (has_slice?"true":"false"));
                        ECapMarkPrinted(ecap_key_gate2);
                        if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                          (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "insights", false, gate_reason);
                       }
                     else
                       {
                        // Non-explore reasons remain info-level as-is
                        if(ShouldLog(LOG_INFO)) PrintFormat("GATE: blocked %s on %s/%s reason=%s slice_exists=%s", order.strategy_name, _Symbol, EnumToString(_Period), gate_reason, (has_slice?"true":"false"));
                        if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                          (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "insights", false, gate_reason);
                       }
                     return;
                    }
                 }
               else
                 {
                  if(StringFind(gate_reason, "explore_", 0) == 0)
                    {
                     bool has_slice = HasSlice(order.strategy_name, _Symbol, _Period);
                     string ekey2 = SliceKey(order.strategy_name, _Symbol, _Period);
                     if(ShouldLog(LOG_INFO)) PrintFormat("GATE: explore allow %s on %s/%s reason=%s (day=%d/%d, week=%d/%d) slice_exists=%s", order.strategy_name, _Symbol, EnumToString(_Period), gate_reason, GetExploreCountDay(ekey2), ExploreMaxPerSlicePerDay, GetExploreCount(ekey2), ExploreMaxPerSlice, (has_slice?"true":"false"));
                     if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                       (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "insights", true, gate_reason);
                    }
                  else if(gate_reason=="fallback_policy_miss")
                    {
                     bool is_demo = (AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO);
                     if(ShouldLog(LOG_INFO)) PrintFormat("FALLBACK: policy slice missing -> neutral scaling used for %s on %s/%s demo=%s", order.strategy_name, _Symbol, EnumToString(_Period), (is_demo?"true":"false"));
                     if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                       (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "insights", true, gate_reason);
                    }
                  else if(gate_reason=="fallback_no_policy")
                    {
                     bool is_demo2 = (AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO);
                     if(ShouldLog(LOG_INFO)) PrintFormat("FALLBACK: no policy loaded -> neutral scaling used for %s on %s/%s demo=%s", order.strategy_name, _Symbol, EnumToString(_Period), (is_demo2?"true":"false"));
                     if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                       (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "insights", true, gate_reason);
                    }
                  else
                    {
                     if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                       (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "insights", true, gate_reason);
                    }
                 }
              }

           // Execute the trade
           // --- Execution Guards ---
           if(GuardsEnabled)
             {
              // Spread guard
              if(GuardMaxSpreadPoints>0.0)
                {
                 double b=0.0,a=0.0; SymbolInfoDouble(_Symbol,SYMBOL_BID,b); SymbolInfoDouble(_Symbol,SYMBOL_ASK,a);
                 double spr_pts = 0.0; if(a>0.0 && b>0.0) spr_pts = (a-b)/_Point;
                 if(spr_pts>GuardMaxSpreadPoints)
                   {
                    if(ShouldLog(LOG_INFO)) PrintFormat("[GUARD] spread_points=%.1f > max=%.1f -> skip %s", spr_pts, GuardMaxSpreadPoints, order.strategy_name);
                    if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                      (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "guards", false, "spread");
                    continue;
                   }
                }
              // ATR regime percentile guard
              if(ATRRegimeEnable)
                {
                 double pct=0.0; int per=(ATRRegimePeriod>0?ATRRegimePeriod:TrailATRPeriod);
                 if(GetATRPercentile(_Symbol,(ENUM_TIMEFRAMES)_Period, per, ATRRegimeLookback, pct))
                   {
                    if(pct<ATRMinPercentile || pct>ATRMaxPercentile)
                      {
                       if(ShouldLog(LOG_INFO)) PrintFormat("[GUARD] ATR%%=%.1f out of [%.1f, %.1f] -> skip %s", pct, ATRMinPercentile, ATRMaxPercentile, order.strategy_name);
                       if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                         (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "guards", false, "atr_percentile");
                       continue;
                      }
                   }
                }
             }
           // Phase 4 Risk & Safety Systems: enforce gating just before execution
           if(!NoConstraintsMode)
             {
              // Spread cap
              string r_sp_exec="";
              if(!SpreadAllowed(r_sp_exec))
                {
                 if(ShouldLog(LOG_INFO)) PrintFormat("[RISK4] blocked %s on %s/%s reason=%s (spread)", order.strategy_name, _Symbol, EnumToString(_Period), r_sp_exec);
                 if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                   (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "risk4_spread", false, r_sp_exec);
                 return;
                }
              else
                {
                 if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                   (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "risk4_spread", true, r_sp_exec);
                }

              // Session/day trade cap
              string r_se_exec="";
              if(!SessionAllowed(r_se_exec))
                {
                 if(ShouldLog(LOG_INFO)) PrintFormat("[RISK4] blocked %s on %s/%s reason=%s (session)", order.strategy_name, _Symbol, EnumToString(_Period), r_se_exec);
                 if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                   (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "risk4_session", false, r_se_exec);
                 return;
                }
              else
                {
                 if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                   (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "risk4_session", true, r_se_exec);
                }

              // Equity/margin/consecutive losses
              string r_rk_exec="";
              if(!RiskAllowed(r_rk_exec))
                {
                 if(ShouldLog(LOG_INFO)) PrintFormat("[RISK4] blocked %s on %s/%s reason=%s", order.strategy_name, _Symbol, EnumToString(_Period), r_rk_exec);
                 if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                   (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "risk4", false, r_rk_exec);
                 return;
                }
              else
                {
                 if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                   (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "risk4", true, r_rk_exec);
                }
             }
          // --- Phase 5: Advanced gating & tuning (after Phase 4, before execution) ---
          {
           // Periodic selector refresh (optional)
           if(P5_TimerRescoreEnable && CheckPointer(g_selector)!=POINTER_INVALID)
             {
              datetime nowts = TimeCurrent();
              if(g_p5_last_rescore_ts==0 || (nowts - g_p5_last_rescore_ts) >= (P5_TimerRescoreEveryMin*60))
                {
                 bool sel_ok = (*g_selector).Load(); // reload insights overlay for selector
                 g_p5_last_rescore_ts = nowts;
                 if(ShouldLog(LOG_DEBUG)) PrintFormat("[P5] selector refresh: %s", (sel_ok?"ok":"fail"));
                }
             }

           // Strategy-level checks require a live strategy pointer
           if(CheckPointer(strategy)!=POINTER_INVALID)
             {
              // Auto re-enable after cooldown if previously disabled
              if(P5_AutoDisableEnable && !(*strategy).Enabled())
                {
                 string dis_until_s = (*strategy).MetadataGet("p5_disabled_until_ts", "0");
                 long dis_until_l = (long)StringToInteger(dis_until_s);
                 datetime dis_until = (datetime)dis_until_l;
                 if(P5_AutoReenable && dis_until>0 && TimeCurrent() >= dis_until)
                   {
                    (*strategy).SetEnabled(true);
                    (*strategy).MetadataSet("p5_disabled_until_ts", "0");
                    if(ShouldLog(LOG_INFO)) PrintFormat("[P5] auto-reenabled %s after cooldown", order.strategy_name);
                    if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                      (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "p5_auto_reenable", true, "cooldown_elapsed");
                   }
                 // If still disabled, block this trade
                 if(!(*strategy).Enabled())
                   {
                    string until_str = (dis_until>0? TimeToString(dis_until, TIME_DATE|TIME_MINUTES) : "n/a");
                    if(ShouldLog(LOG_INFO)) PrintFormat("[P5] blocked %s on %s/%s reason=%s (until=%s)", order.strategy_name, _Symbol, EnumToString(_Period), "p5_disabled_cooldown", until_str);
                    if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                      (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "p5_disabled", false, "cooldown");
                    return;
                   }
                }

              // Auto-disable underperforming strategies (using selector metrics)
              if(P5_AutoDisableEnable && CheckPointer(g_selector)!=POINTER_INVALID)
                {
                 bool under = (*g_selector).IsUnderperforming(_Symbol, _Period, order.strategy_name,
                                                              P5_MinPF, P5_MinWR, P5_MinExpR);
                 if(under)
                   {
                    datetime until = TimeCurrent() + (P5_AutoDisableCooldownM*60);
                    (*strategy).SetEnabled(false);
                    (*strategy).MetadataSet("p5_disabled_until_ts", IntegerToString((long)until));
                    if(ShouldLog(LOG_INFO)) PrintFormat("[P5] auto-disable %s on %s/%s until %s (minPF=%.2f, minWR=%.2f, minExp=%.2f)",
                                                       order.strategy_name, _Symbol, EnumToString(_Period),
                                                       TimeToString(until, TIME_DATE|TIME_MINUTES), P5_MinPF, P5_MinWR, P5_MinExpR);
                    if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                      (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "p5_auto_disable", false, "underperform");
                    return;
                   }
                }

              // Auto-tune indicators periodically
              if(P5_AutoTuneEnable)
                {
                 string last_tune_s = (*strategy).MetadataGet("p5_last_tune_ts", "0");
                 long last_tune_l = (long)StringToInteger(last_tune_s);
                 datetime last_tune = (datetime)last_tune_l;
                 if(last_tune<=0 || (TimeCurrent() - last_tune) >= (P5_AutoTuneEveryMin*60))
                   {
                    bool tuned = (*strategy).AutoTuneIndicators(_Symbol, (ENUM_TIMEFRAMES)_Period);
                    if(tuned)
                      {
                       if(ShouldLog(LOG_INFO)) PrintFormat("[P5] auto-tuned indicators for %s on %s/%s", order.strategy_name, _Symbol, EnumToString(_Period));
                       if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                         (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "p5_auto_tune", true, "params_updated");
                      }
                    (*strategy).MetadataSet("p5_last_tune_ts", IntegerToString((long)TimeCurrent()));
                   }
                }
             }

           // Correlation pruning gate
           if(P5_CorrPruneEnable)
             {
              string r_corr="";
              if(NoConstraintsMode)
                {
                 bool ok_shadow = P5_CorrPruneAllow(order, r_corr);
                 if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                   (*g_telemetry).LogGatingShadow(order.strategy_name, _Symbol, (int)_Period, "p5_corr", ok_shadow, r_corr, true);
                }
              else
                {
                 if(!P5_CorrPruneAllow(order, r_corr))
                   {
                    if(ShouldLog(LOG_INFO)) PrintFormat("[P5] blocked %s on %s/%s reason=%s (corr_prune)", order.strategy_name, _Symbol, EnumToString(_Period), r_corr);
                    if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                      (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "p5_corr", false, r_corr);
                    return;
                   }
                 else
                   {
                    if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                      (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "p5_corr", true, r_corr);
                   }
                }
             }

           // Multi-timeframe confirmation gate
           if(P5_MTFConfirmEnable)
             {
              string r_mtf="";
              if(NoConstraintsMode)
                {
                 bool ok_shadow2 = P5_MTFConfirmAllow(order, r_mtf);
                 if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                   (*g_telemetry).LogGatingShadow(order.strategy_name, _Symbol, (int)_Period, "mtf_confirm", ok_shadow2, r_mtf, true);
                }
              else
                {
                 if(!P5_MTFConfirmAllow(order, r_mtf))
                   {
                    if(ShouldLog(LOG_INFO)) PrintFormat("[P5] blocked %s on %s/%s reason=%s (mtf_confirm)", order.strategy_name, _Symbol, EnumToString(_Period), r_mtf);
                    if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                      (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "mtf_confirm", false, r_mtf);
                    return;
                   }
                 else
                   {
                    if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                      (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "mtf_confirm", true, r_mtf);
                   }
                }
             }

           // Stability gating
           if(P5_StabilityGateEnable)
             {
              string r_stab="";
              if(NoConstraintsMode)
                {
                 bool ok_shadow3 = P5_StabilityAllow(order, r_stab);
                 if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                   (*g_telemetry).LogGatingShadow(order.strategy_name, _Symbol, (int)_Period, "p5_stability", ok_shadow3, r_stab, true);
                }
              else
                {
                 if(!P5_StabilityAllow(order, r_stab))
                   {
                    if(ShouldLog(LOG_INFO)) PrintFormat("[P5] blocked %s on %s/%s reason=%s (stability)", order.strategy_name, _Symbol, EnumToString(_Period), r_stab);
                    if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                      (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "p5_stability", false, r_stab);
                    return;
                   }
                 else
                   {
                    if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                      (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "p5_stability", true, r_stab);
                   }
                }
             }

          }

          bool result = false;
           ulong res_order = 0;
           ulong res_deal  = 0;
           double res_price = 0.0;
           int res_retcode = 0;

           if(UsePositionManager && CheckPointer(g_position_manager)!=POINTER_INVALID)
            {
              // Snapshot latest before placement
              ulong prev_order = FindLatestOrderForSymbolMagic(_Symbol, MagicNumber);
              ulong prev_deal  = FindLatestDealForSymbolMagic(_Symbol, MagicNumber);

              double entry_px = order.price; // 0 for market
             int trail_pts = 0;
             if(order.trailing_enabled)
               {
                if(order.trailing_type==TRAIL_ATR)
                  {
                   // Compute ATR-based trailing distance in points
                   int atrp = (order.atr_period>0 ? order.atr_period : TrailATRPeriod);
                   int h = iATR(_Symbol, _Period, atrp);
                   if(h!=INVALID_HANDLE)
                     {
                      double b[]; if(CopyBuffer(h,0,0,1,b)==1)
                        {
                         double atr = b[0];
                         int pts = (int)MathRound((atr * order.atr_multiplier) / _Point);
                         if(pts>0) trail_pts = pts;
                        }
                      IndicatorRelease(h);
                     }
                  }
                else
                  {
                   trail_pts = (int)order.trail_distance_points;
                  }
               }
             // --- Volatility Sizing (FR-06) ---
             double stop_pts_pm = 0.0;
             double bid_pm=0.0, ask_pm=0.0; SymbolInfoDouble(_Symbol,SYMBOL_BID,bid_pm); SymbolInfoDouble(_Symbol,SYMBOL_ASK,ask_pm);
             if(order.stop_loss>0.0)
               {
                if(order.order_type==ORDER_TYPE_BUY || order.order_type==ORDER_TYPE_BUY_LIMIT || order.order_type==ORDER_TYPE_BUY_STOP)
                  {
                   double ref = (entry_px>0.0? entry_px : ask_pm);
                   stop_pts_pm = MathMax(0.0, (ref - order.stop_loss)/_Point);
                  }
                else
                  {
                   double ref = (entry_px>0.0? entry_px : bid_pm);
                   stop_pts_pm = MathMax(0.0, (order.stop_loss - ref)/_Point);
                  }
               }
             double lot_to_use_pm = LotSize;
             if(UseVolatilitySizer && CheckPointer(g_volatility_sizer)!=POINTER_INVALID)
               {
                double atr_pct_pm=0.0; string vs_r1_pm=""; double mult_hint_pm = (*g_volatility_sizer).CalculateSizeMultiplier(atr_pct_pm, vs_r1_pm);
                double mult_final_pm=1.0; string vs_r2_pm="";
                lot_to_use_pm = (*g_volatility_sizer).CalculatePositionSize(LotSize, stop_pts_pm, mult_final_pm, vs_r2_pm);
                if(TelemetryEnabled && CheckPointer(g_tel_standard)!=POINTER_INVALID)
                  (*g_tel_standard).LogVolatilitySizingEvent(_Symbol, (int)_Period, LotSize, mult_final_pm, lot_to_use_pm, atr_pct_pm);
               }

             result = (*g_position_manager).PlaceBracketOrder(_Symbol,
                                                              order.order_type,
                                                              lot_to_use_pm,
                                                              entry_px,
                                                              order.stop_loss,
                                                              order.take_profit,
                                                              0.0,
                                                              trail_pts,
                                                              0,
                                                              order.strategy_name);
              res_retcode = (result ? 10009 /*TRADE_RETCODE_DONE*/ : GetLastError());

              // Resolve newest order/deal after placement
              ulong now_order = FindLatestOrderForSymbolMagic(_Symbol, MagicNumber);
              if(now_order!=0 && now_order!=prev_order) res_order = now_order;
              ulong now_deal  = FindLatestDealForSymbolMagic(_Symbol, MagicNumber);
              if(now_deal!=0 && now_deal!=prev_deal)
                {
                 res_deal = now_deal;
                 res_price = HistoryDealGetDouble(res_deal, DEAL_PRICE);
                }
             }
           else
             {
              // --- Volatility Sizing (FR-06) ---
              double stop_pts_tm = 0.0;
              double bid_tm=0.0, ask_tm=0.0; SymbolInfoDouble(_Symbol,SYMBOL_BID,bid_tm); SymbolInfoDouble(_Symbol,SYMBOL_ASK,ask_tm);
              if(order.stop_loss>0.0)
                {
                 if(order.order_type==ORDER_TYPE_BUY || order.order_type==ORDER_TYPE_BUY_LIMIT || order.order_type==ORDER_TYPE_BUY_STOP)
                   {
                    double ref = (order.price>0.0? order.price : ask_tm);
                    stop_pts_tm = MathMax(0.0, (ref - order.stop_loss)/_Point);
                   }
                 else
                   {
                    double ref = (order.price>0.0? order.price : bid_tm);
                    stop_pts_tm = MathMax(0.0, (order.stop_loss - ref)/_Point);
                   }
                }
              double lot_to_use_tm = LotSize;
              if(UseVolatilitySizer && CheckPointer(g_volatility_sizer)!=POINTER_INVALID)
                {
                 double atr_pct_tm=0.0; string vs_r1_tm=""; double mult_hint_tm = (*g_volatility_sizer).CalculateSizeMultiplier(atr_pct_tm, vs_r1_tm);
                 double mult_final_tm=1.0; string vs_r2_tm="";
                 lot_to_use_tm = (*g_volatility_sizer).CalculatePositionSize(LotSize, stop_pts_tm, mult_final_tm, vs_r2_tm);
                 if(TelemetryEnabled && CheckPointer(g_tel_standard)!=POINTER_INVALID)
                   (*g_tel_standard).LogVolatilitySizingEvent(_Symbol, (int)_Period, LotSize, mult_final_tm, lot_to_use_tm, atr_pct_tm);
                }
              // Apply to order override so TradeManager uses it
              order.lots = lot_to_use_tm;
              result = (*g_trade_manager).ExecuteOrder(order);
              if(result)
                {
                 res_order = (*g_trade_manager).ResultOrder();
                 res_deal  = (*g_trade_manager).ResultDeal();
                 res_price = (*g_trade_manager).ResultPrice();
                 res_retcode = (int)(*g_trade_manager).ResultRetcode();
                }
             }

           if(result)
             {
               // Configure trailing on successful execution
               if(TrailEnabled)
                 {
              // Configure trailing according to the strategy's order policy
              (*g_trade_manager).ConfigureTrailing(order);
                 }

              // Event log
              (*g_kb).LogTrade(order.strategy_name, res_retcode, res_deal, res_order);

              // Telemetry: trade executed
              if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                (*g_telemetry).LogTradeExecuted(order.strategy_name, _Symbol, (int)_Period, res_retcode, res_deal, res_order);

             // Feature logging (Phase 1)
             if(CheckPointer(g_features)!=POINTER_INVALID)
               {
                datetime ts = TimeCurrent();
                // ATR current
                int atr_period = (order.trailing_type==TRAIL_ATR)? order.atr_period : TrailATRPeriod;
                int atr_h = iATR(_Symbol, _Period, atr_period);
                if(atr_h!=INVALID_HANDLE)
                  {
                   double b[]; if(CopyBuffer(atr_h,0,0,1,b)==1)
                     {
                      double atr = b[0];
                      (*g_features).WriteKV(ts, _Symbol, order.strategy_name, "atr", atr);
                      // Regime proxy: atr/price
                      double mid=0; double bid=0,ask=0; SymbolInfoDouble(_Symbol,SYMBOL_BID,bid); SymbolInfoDouble(_Symbol,SYMBOL_ASK,ask); mid=(bid+ask)/2.0;
                      if(mid>0) (*g_features).WriteKV(ts, _Symbol, order.strategy_name, "atr_over_price", atr/mid);
                     }
                   IndicatorRelease(atr_h);
                  }
                 // Spread (compute from bid/ask to avoid integer property)
                 double spr_points = 0.0;
                 double _b=0.0,_a=0.0; SymbolInfoDouble(_Symbol,SYMBOL_BID,_b); SymbolInfoDouble(_Symbol,SYMBOL_ASK,_a);
                 if(_a>0 && _b>0) spr_points = (_a - _b) / _Point;
                 (*g_features).WriteKV(ts, _Symbol, order.strategy_name, "spread_points", spr_points);
                // Timeframe feature for insights (binds r_multiple to TF)
                (*g_features).WriteKV(ts, _Symbol, order.strategy_name, "timeframe", (double)_Period);
                // Trailing params
                (*g_features).WriteKV(ts, _Symbol, order.strategy_name, "trail_type", (double)order.trailing_type);
                (*g_features).WriteKV(ts, _Symbol, order.strategy_name, "trail_activation_points", (double)order.trail_activation_points);
                (*g_features).WriteKV(ts, _Symbol, order.strategy_name, "trail_distance_points", (double)order.trail_distance_points);
                (*g_features).WriteKV(ts, _Symbol, order.strategy_name, "trail_step_points", (double)order.trail_step_points);
                (*g_features).WriteKV(ts, _Symbol, order.strategy_name, "trail_atr_period", (double)order.atr_period);
                (*g_features).WriteKV(ts, _Symbol, order.strategy_name, "trail_atr_multiplier", (double)order.atr_multiplier);
               // Ask strategy to export its own indicator/context features
               if(CheckPointer(strategy)!=POINTER_INVALID)
                 {
                  (*strategy).ExportFeatures(g_features, ts);
                 }
             }

             // Full record log
              TradeRecord rec;
              rec.timestamp    = TimeCurrent();
              rec.symbol       = _Symbol;
              rec.type         = order.order_type;
              rec.entry_price  = res_price;
              rec.stop_loss    = order.stop_loss;
              rec.take_profit  = order.take_profit;
              rec.close_price  = 0.0;
              rec.profit       = 0.0;
              rec.strategy_id  = order.strategy_name;
              (*g_kb).WriteRecord(rec);
              // Stash pending mapping so we can attribute when the entry deal arrives
              ulong ord = res_order;
              if(ord>0)
                {
                 int n = ArraySize(g_pending_orders);
                 ArrayResize(g_pending_orders, n+1); ArrayResize(g_pending_orders_strat, n+1);
                 g_pending_orders[n] = ord; g_pending_orders_strat[n] = order.strategy_name;
                }
              ulong dl = res_deal;
              if(dl>0)
                {
                 int m = ArraySize(g_pending_deals);
                 ArrayResize(g_pending_deals, m+1); ArrayResize(g_pending_deals_strat, m+1);
                 g_pending_deals[m] = dl; g_pending_deals_strat[m] = order.strategy_name;
                }
              // Immediate tracking of the opened position to ensure OnTimer/closures work even if transaction mapping is missed
              {
               ulong pos_id_immediate = 0;
               if(dl>0)
                 pos_id_immediate = (ulong)HistoryDealGetInteger(dl, DEAL_POSITION_ID);
               // fallback: select by symbol if position id not resolved yet
               if(pos_id_immediate==0)
                 {
                  if(PositionSelect(_Symbol))
                    pos_id_immediate = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
                 }
               if(pos_id_immediate>0)
                 {
                  // prevent duplicates if OnTradeTransaction already added
                  bool exists=false;
                  for(int t=0;t<ArraySize(g_pos_ids);++t){ if(g_pos_ids[t]==pos_id_immediate){ exists=true; break; } }
                  if(!exists)
                  {
                  int k = ArraySize(g_pos_ids);
                  ArrayResize(g_pos_ids,k+1);
                  ArrayResize(g_pos_strats,k+1);
                  ArrayResize(g_pos_entry_price,k+1);
                  ArrayResize(g_pos_initial_risk,k+1);
                  ArrayResize(g_pos_start_time,k+1);
                  ArrayResize(g_pos_type,k+1);
                  ArrayResize(g_pos_max_price,k+1);
                  ArrayResize(g_pos_min_price,k+1);
                  g_pos_ids[k]=pos_id_immediate; g_pos_strats[k]=(order.strategy_name==""?"unknown":order.strategy_name);
                  double entry_p = res_price;
                  if(entry_p<=0 && PositionSelectByTicket(pos_id_immediate)) entry_p = PositionGetDouble(POSITION_PRICE_OPEN);
                  g_pos_entry_price[k]=entry_p;
                  g_pos_max_price[k]=entry_p; g_pos_min_price[k]=entry_p;
                  int ptype = POSITION_TYPE_BUY;
                  if(PositionSelectByTicket(pos_id_immediate)) ptype = (int)PositionGetInteger(POSITION_TYPE);
                  g_pos_type[k]=ptype;
                  double init_risk = 0.0;
                  if(order.stop_loss>0 && entry_p>0)
                    init_risk = MathAbs((ptype==POSITION_TYPE_BUY? entry_p - order.stop_loss : order.stop_loss - entry_p));
                  if(init_risk<=0.0 && PositionSelectByTicket(pos_id_immediate))
                    {
                     double slc = PositionGetDouble(POSITION_SL);
                     double eop = PositionGetDouble(POSITION_PRICE_OPEN);
                     if(slc>0 && eop>0) init_risk = MathAbs((ptype==POSITION_TYPE_BUY? eop - slc : slc - eop));
                    }
                  g_pos_initial_risk[k]=init_risk;
                  g_pos_start_time[k]=TimeCurrent();
                  PrintFormat("Tracked pos immediately: ticket=%I64u strat=%s entry=%.5f initR=%.5f", pos_id_immediate, g_pos_strats[k], entry_p, init_risk);
                  }
                 }
              }
              // Exploration accounting: count only on successful execution
              if(g_explore_pending_key!="")
                {
                 IncExploreCount(g_explore_pending_key);
                 PrintFormat("Exploration used for %s -> %d/%d", g_explore_pending_key, GetExploreCount(g_explore_pending_key), ExploreMaxPerSlice);
                 g_explore_pending_key = "";
                }
              PrintFormat("Trade executed by %s. Deal: %d, Order: %d", order.strategy_name, (int)res_deal, (int)res_order);
              return; // Exit after processing one trade
             }
         else
           {
            // Ensure exploration pending key does not leak across failed executions
            if(g_explore_pending_key!="")
              {
               PrintFormat("Exploration not used due to failed execution for %s", g_explore_pending_key);
               g_explore_pending_key = "";
              }
            PrintFormat("Trade failed for %s. Error: %d", order.strategy_name, GetLastError());
            // Telemetry: trade failed
            if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
              (*g_telemetry).LogTradeFailed(order.strategy_name, _Symbol, (int)_Period, GetLastError());
           }
        }
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Trade transaction handler                                        |
//+------------------------------------------------------------------+
#ifdef DUP_HANDLER_DISABLED // duplicate handler disabled (merged into top-of-file handler)
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   // Only process events for this chart's symbol
   if(trans.symbol!=_Symbol)
      return;

   int t = (int)trans.type;
   if(t==TRADE_TRANSACTION_DEAL_ADD)
     {
      ulong deal = trans.deal;
      if(deal==0) return;
      // Ensure history context for the recent window
      HistorySelect(TimeCurrent()-7*86400, TimeCurrent());

      long dmag = HistoryDealGetInteger(deal, DEAL_MAGIC);
      if(dmag!=MagicNumber) return; // ignore foreign deals

      int   entry_flag = (int)HistoryDealGetInteger(deal, DEAL_ENTRY);
      ulong pos_id     = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);

      if(entry_flag==DEAL_ENTRY_IN)
        {
         // Attribute strategy via pending maps
         string strat = "unknown";
         int idxpd=-1; for(int i=0;i<ArraySize(g_pending_deals);++i){ if(g_pending_deals[i]==deal){ idxpd=i; break; } }
         if(idxpd>=0)
           {
            strat = g_pending_deals_strat[idxpd];
            int last=ArraySize(g_pending_deals)-1;
            g_pending_deals[idxpd]=g_pending_deals[last]; g_pending_deals_strat[idxpd]=g_pending_deals_strat[last];
            ArrayResize(g_pending_deals,last); ArrayResize(g_pending_deals_strat,last);
           }
         else if(trans.order>0)
           {
            int idxpo=-1; for(int j=0;j<ArraySize(g_pending_orders);++j){ if(g_pending_orders[j]==trans.order){ idxpo=j; break; } }
            if(idxpo>=0)
              {
               strat = g_pending_orders_strat[idxpo];
               int last2=ArraySize(g_pending_orders)-1;
               g_pending_orders[idxpo]=g_pending_orders[last2]; g_pending_orders_strat[idxpo]=g_pending_orders_strat[last2];
               ArrayResize(g_pending_orders,last2); ArrayResize(g_pending_orders_strat,last2);
              }
           }

         if(pos_id>0 && FindTrackedIndexByPid(pos_id)<0)
           {
            // Track newly opened position
            int k = ArraySize(g_pos_ids);
            ArrayResize(g_pos_ids,k+1);
            ArrayResize(g_pos_strats,k+1);
            ArrayResize(g_pos_entry_price,k+1);
            ArrayResize(g_pos_initial_risk,k+1);
            ArrayResize(g_pos_start_time,k+1);
            ArrayResize(g_pos_type,k+1);
            ArrayResize(g_pos_max_price,k+1);
            ArrayResize(g_pos_min_price,k+1);
            g_pos_ids[k]=pos_id; g_pos_strats[k]=strat;
            double eprice = HistoryDealGetDouble(deal, DEAL_PRICE);
            g_pos_entry_price[k]=eprice; g_pos_max_price[k]=eprice; g_pos_min_price[k]=eprice;
            int ptype = POSITION_TYPE_BUY;
            if(PositionSelectByTicket(pos_id)) ptype = (int)PositionGetInteger(POSITION_TYPE);
            g_pos_type[k]=ptype;
            double init_risk = 0.0;
            if(PositionSelectByTicket(pos_id))
              {
               double slc = PositionGetDouble(POSITION_SL);
               double eop = PositionGetDouble(POSITION_PRICE_OPEN);
               if(slc>0 && eop>0) init_risk = MathAbs((ptype==POSITION_TYPE_BUY? eop - slc : slc - eop));
              }
            g_pos_initial_risk[k]=init_risk;
            g_pos_start_time[k]=TimeCurrent();
            if(ShouldLog(LOG_INFO)) PrintFormat("OnTradeTransaction: tracked entry pid=%I64u strat=%s", pos_id, g_pos_strats[k]);
           }
        }
      else if(entry_flag==DEAL_ENTRY_OUT)
        {
         if(pos_id>0)
           {
            int idx = FindTrackedIndexByPid(pos_id);
            if(idx>=0)
              HandlePositionClosed(idx, deal);
           }
        }
     }
   else if(t==TRADE_TRANSACTION_ORDER_DELETE)
     {
      // Clean pending order mapping if order is cancelled/expired
      ulong ord = trans.order;
      if(ord>0)
        {
         for(int i=0;i<ArraySize(g_pending_orders);++i)
           if(g_pending_orders[i]==ord)
             {
              int last=ArraySize(g_pending_orders)-1;
              g_pending_orders[i]=g_pending_orders[last]; g_pending_orders_strat[i]=g_pending_orders_strat[last];
              ArrayResize(g_pending_orders,last); ArrayResize(g_pending_orders_strat,last);
              break;
             }
        }
     }
  }
 #endif // duplicate handler disabled

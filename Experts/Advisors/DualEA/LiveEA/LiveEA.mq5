//+------------------------------------------------------------------+
//|                                                      LiveEA.mq5 |
//|                    DualEA Live Trading Expert - Reconstructed   |
//+------------------------------------------------------------------+
#property copyright "DualEA"
#property version   "2.0"
#property strict

//+------------------------------------------------------------------+
//| INCLUDES                                                         |
//+------------------------------------------------------------------+
#include "..\\Include\\IStrategy.mqh"
#include "..\\Include\\PositionManager.mqh"
#include "..\\Include\\TradeManager.mqh"
#include "..\\Include\\Telemetry.mqh"
#include "..\\Include\\TelemetryStandard.mqh"
#include "..\\Include\\SessionManager.mqh"
#include "..\\Include\\CorrelationManager.mqh"
#include "..\\Include\\VolatilitySizer.mqh"
#include "..\\Include\\InsightsLoader.mqh"
#include "..\\Include\\IncrementalInsightEngine.mqh"   // Real-time O(1) statistics engine
#include "LiveEA_StrategyBridge.mqh"

//+------------------------------------------------------------------+
//| ENUMS AND CONSTANTS                                              |
//+------------------------------------------------------------------+
enum LogLevel { LOG_ERROR=0, LOG_WARN=1, LOG_INFO=2, LOG_DEBUG=3 };

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - CORE SETTINGS                                |
//+------------------------------------------------------------------+
input long  MagicNumber           = 123456;
input int   Verbosity             = 1;        // 0=errors,1=warn,2=info,3=debug
input bool  TelemetryEnabled      = false;    // enable telemetry emission
input bool  NoConstraintsMode     = false;    // shadow-gate only, do not block
//+------------------------------------------------------------------+
//| INPUT PARAMETERS - TELEMETRY                                    |
//+------------------------------------------------------------------+
input string TelemetryExperiment  = "live";
input int    TelemetryBufferMax   = 1000;

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - RISK MANAGEMENT                              |
//+------------------------------------------------------------------+
input double SpreadMaxPoints      = 0.0;   // 0=disabled
input int    SessionStartHour     = 0;     // 0..23
input int    SessionMaxTrades     = 0;     // 0=disabled
input double MaxDailyLossPct      = 0.0;   // 0=disabled
input double MaxDrawdownPct       = 0.0;   // 0=disabled
input double MinMarginLevel       = 0.0;   // 0=disabled, e.g. 100.0
input int    ConsecutiveLossLimit = 0;     // 0=disabled
input bool   P5_PersistLossCounters = false; // persist counters (minimal in-memory here)

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - INSIGHTS GATING                              |
//+------------------------------------------------------------------+
input bool   UseInsightsGating    = true;
input int    GateMinTrades        = 0;        // loosened for bootstrap
input double GateMinWinRate       = 0.00;     // loosened for bootstrap
input double GateMinExpectancyR   = -10.0;    // loosened for bootstrap
input double GateMaxDrawdownR     = 1000000.0;// loosened for bootstrap
input double GateMinProfitFactor  = 0.00;     // loosened for bootstrap

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - EXPLORATION MODE                             |
//+------------------------------------------------------------------+
input bool   ExploreOnNoSlice     = true;    // allow limited trades when slice has no data
input int    ExploreMaxPerSlice   = 100;     // loosened for bootstrap
input int    ExploreMaxPerSlicePerDay = 100; // loosened for bootstrap

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - POLICY GATING                                |
//+------------------------------------------------------------------+
input bool   UsePolicyGating       = true;
input bool   DefaultPolicyFallback = true;   // allow neutral trading when policy slice is missing
input bool   FallbackDemoOnly      = true;   // restrict fallback to demo accounts
input bool   FallbackWhenNoPolicy  = true;   // allow fallback when policy file is not loaded

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - CORRELATION MANAGEMENT                       |
//+------------------------------------------------------------------+
input double P5_CorrMax           = 1.0;   // 1.0=no pruning by default
input int    P5_CorrLookbackDays  = 5;     // used if PositionManager is not available
input bool   UsePositionManager    = false; // optional PositionManager usage

// News / Promotion / Regime / Cooldown inputs
input bool   UseNewsFilter       = false;   // block around defined news windows
input int    NewsBufferBeforeMin = 30;      // minutes before an event
input int    NewsBufferAfterMin  = 30;      // minutes after an event
input int    NewsImpactMin       = 2;       // 1=low, 2=medium, 3=high
input bool   NewsUseFile         = true;    // read blackouts from CSV in Common files
input string NewsFileRelPath     = "DualEA\\news_blackouts.csv";

// --- Insights live auto-reload controls
input bool   InsightsAutoReload        = true;  // if stale/missing, request rebuild and auto-reload when ready
input int    InsightsLiveFreshMinutes  = 10;    // consider insights fresh if modified within N minutes
input int    InsightsReadyPollSec      = 5;     // poll frequency for ready signal

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

// --- FR-04 Position Manager inputs
input int    PMMaxOpenPositions    = 10;     // 0=disabled; cap total open positions before PM gate blocks

// --- FR-06 Volatility Sizer inputs
input bool   UseVolatilitySizer    = false;
input int    VolSizerATRPeriod     = 14;
input double VolSizerBaseATRPct    = 1.0;
input double VolSizerMinMult       = 0.1;
input double VolSizerMaxMult       = 3.0;
input double VolSizerTargetRisk    = 1.0;
input double BaseLotSize           = 0.01;   // base lot size used when sizing via VolatilitySizer

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
CTelemetry       *g_telemetry        = NULL;
CTelemetryStandard* g_tel_standard = NULL;
CPositionManager *g_position_manager = NULL;
CSessionManager* g_session_manager = NULL;
CCorrelationManager* g_correlation_manager = NULL;
CVolatilitySizer* g_volatility_sizer = NULL;
CIncrementalInsightEngine* g_insight_engine = NULL; // Real-time statistics engine
bool              g_eval_busy        = false;
datetime          g_last_trade_placed= 0;

// --- Insights gating cache (loaded from insights.json via InsightsLoader)
string g_gate_strat[];
string g_gate_sym[];
int    g_gate_tf[];
int    g_gate_cnt[];
double g_gate_wr[];
double g_gate_avgR[];
double g_gate_pf[];
double g_gate_dd[];

// --- Policy gating cache (loaded from policy.json)
bool   g_policy_loaded  = false;
double g_policy_min_conf= 0.0;
string g_pol_strat[];
string g_pol_sym[];
int    g_pol_tf[];
double g_pol_p[];
double g_pol_sl[];
double g_pol_tp[];
double g_pol_trail[];

// Live insights reload state
bool    g_waiting_insights = false; // set after we request reload; reset when ready is consumed

// --- Exploration Mode tracking (weekly + daily persistent)
string g_exp_keys[];    // slice key: strategy|symbol|timeframe
int    g_exp_weeks[];   // week bucket id (Monday yyyymmdd)
int    g_exp_counts[];  // count within week
string g_explore_pending_key = ""; // set by Insights_Allow when allowing explore
// Daily exploration tracking (persistent)
string g_exp_day_keys[];
int    g_exp_day_days[];
int    g_exp_day_counts[];

// --- News blackout cache (from CSV)
string   g_news_key[];
datetime g_news_from[];
datetime g_news_to[];
int      g_news_impact[];

//+------------------------------------------------------------------+
//| UTILITY FUNCTIONS                                                |
//+------------------------------------------------------------------+
bool ShouldLog(const int level) { return (Verbosity >= level); }

void LogMessage(const int level, const string message)
{
    if (!ShouldLog(level)) return;
    
    string prefix = "";
    switch(level)
    {
        case LOG_ERROR: prefix = "[ERROR] "; break;
        case LOG_WARN:  prefix = "[WARN] ";  break;
        case LOG_INFO:  prefix = "[INFO] ";  break;
        case LOG_DEBUG: prefix = "[DEBUG] "; break;
    }
    
    Print(prefix + message);
}

//+------------------------------------------------------------------+
//| SERVICE INITIALIZATION FUNCTIONS                                 |
//+------------------------------------------------------------------+
void EnsureTelemetry()
  {
   if(!TelemetryEnabled) return;
   if(CheckPointer(g_telemetry)==POINTER_INVALID)
     {
      g_telemetry = new CTelemetry(_Symbol, TelemetryExperiment, TelemetryBufferMax, (int)_Period);
      if(CheckPointer(g_telemetry)==POINTER_INVALID)
        {
         Print("Failed to create telemetry instance");
         return;
        }
      g_tel_standard = new CTelemetryStandard(g_telemetry);
     }
  }

void EnsurePM()
  {
   if(!UsePositionManager) return;
   if(CheckPointer(g_position_manager)==POINTER_INVALID)
     {
      g_position_manager = new CPositionManager();
      if(CheckPointer(g_position_manager)!=POINTER_INVALID)
        (*g_position_manager).SetMagicNumber((int)MagicNumber);
     }
  }

void EnsureSessionManager()
  {
   if(!UseSessionManager) return;
   if(CheckPointer(g_session_manager)==POINTER_INVALID)
     {
      g_session_manager = new CSessionManager(_Symbol, _Period);
      g_session_manager.SetEnabled(true);
      g_session_manager.SetSessionHours(SessionStartHour, SessionEndHour);
      g_session_manager.SetMaxTradesPerSession(MaxTradesPerSession);
      g_session_manager.SetMaxDailyLossPct(MaxDailyLossPct);
     }
  }

void EnsureCorrelationManager()
  {
   if(!UseCorrelationManager) return;
   if(CheckPointer(g_correlation_manager)==POINTER_INVALID)
     {
      g_correlation_manager = new CCorrelationManager(_Symbol, _Period);
      g_correlation_manager.SetEnabled(true);
      g_correlation_manager.SetMaxCorrelation(MaxCorrelationLimit);
      g_correlation_manager.SetLookbackDays(CorrLookbackDays);
     }
  }

void EnsureVolatilitySizer()
  {
   if(!UseVolatilitySizer) return;
   if(CheckPointer(g_volatility_sizer)==POINTER_INVALID)
     {
      g_volatility_sizer = new CVolatilitySizer(_Symbol, _Period);
      g_volatility_sizer.SetEnabled(true);
      g_volatility_sizer.SetATRPeriod(VolSizerATRPeriod);
      g_volatility_sizer.SetBaseATRPercent(VolSizerBaseATRPct);
      g_volatility_sizer.SetMultiplierRange(VolSizerMinMult, VolSizerMaxMult);
      g_volatility_sizer.SetTargetRiskPercent(VolSizerTargetRisk);
     }
  }

// --- Spread/Session/Risk gating helpers and session tracking
datetime g_session_start = 0;
int      g_session_day   = 0;
double   g_session_equity_start = 0.0;
double   g_equity_highwater     = 0.0;

double CurrentSpreadPoints()
  {
   double bid=0.0, ask=0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   if(ask>0.0 && bid>0.0 && _Point>0.0) return (ask - bid)/_Point;
   return 0.0;
  }

 datetime ComputeSessionBoundary(datetime now)
   {
    MqlDateTime dt; TimeToStruct(now, dt);
    dt.hour = SessionStartHour;
    dt.min  = 0;
    dt.sec  = 0;
    datetime today_boundary = StructToTime(dt);
    if(now < today_boundary) return today_boundary - 86400;
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
    int total = (int)HistoryDealsTotal();
    for(int i=0;i<total;++i)
      {
       ulong ticket = HistoryDealGetTicket(i);
       if(HistoryDealGetString(ticket, DEAL_SYMBOL)!=_Symbol) continue;
       long  mag = (long)HistoryDealGetInteger(ticket, DEAL_MAGIC);
       if(mag != MagicNumber) continue;
       int entry = (int)HistoryDealGetInteger(ticket, DEAL_ENTRY);
       if(entry==DEAL_ENTRY_IN) count++;
      }
    return count;
   }

 int CountConsecutiveLosses()
   {
    int consec=0;
    datetime t0 = TimeCurrent() - 120*86400;
    if(!HistorySelect(t0, TimeCurrent())) return 0;
    for(int i=HistoryDealsTotal()-1; i>=0; --i)
      {
       ulong ticket = HistoryDealGetTicket(i);
       if((int)HistoryDealGetInteger(ticket, DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
       long mag = (long)HistoryDealGetInteger(ticket, DEAL_MAGIC);
       if(mag != MagicNumber) continue;
       double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
       if(profit < 0.0) consec++;
       else break;
      }
    return consec;
   }

 // --- Minimal persistent consecutive loss counters (in-memory)
 string g_loss_sym[];
 long   g_loss_mag[];
 int    g_loss_cnt[];

 int GetConsecLossPersist(const string sym, const long mag)
   {
    for(int i=0;i<ArraySize(g_loss_sym);++i)
      if(g_loss_sym[i]==sym && g_loss_mag[i]==mag) return g_loss_cnt[i];
    return 0;
   }

 void SetConsecLossPersist(const string sym, const long mag, const int val)
   {
    for(int i=0;i<ArraySize(g_loss_sym);++i)
      if(g_loss_sym[i]==sym && g_loss_mag[i]==mag) { g_loss_cnt[i]=(val<0?0:val); return; }
    int n=ArraySize(g_loss_sym);
    ArrayResize(g_loss_sym,n+1); ArrayResize(g_loss_mag,n+1); ArrayResize(g_loss_cnt,n+1);
    g_loss_sym[n]=sym; g_loss_mag[n]=mag; g_loss_cnt[n]=(val<0?0:val);
   }

 void IncConsecLossPersist(const string sym, const long mag)
   {
    for(int i=0;i<ArraySize(g_loss_sym);++i)
      if(g_loss_sym[i]==sym && g_loss_mag[i]==mag) { g_loss_cnt[i]=g_loss_cnt[i]+1; return; }
    int n=ArraySize(g_loss_sym);
    ArrayResize(g_loss_sym,n+1); ArrayResize(g_loss_mag,n+1); ArrayResize(g_loss_cnt,n+1);
    g_loss_sym[n]=sym; g_loss_mag[n]=mag; g_loss_cnt[n]=1;
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
       int cl = (P5_PersistLossCounters ? GetConsecLossPersist(_Symbol, (long)MagicNumber)
                                        : CountConsecutiveLosses());
       if(cl >= ConsecutiveLossLimit) { reason="consec_losses"; return false; }
      }
    return true;
   }

 // Helper: append unique key to a dynamic string array
 void AddUniqueKey(string &arr[], const string k)
   {
    for(int i=0;i<ArraySize(arr);++i)
      if(arr[i]==k) return;
    int n=ArraySize(arr);
    ArrayResize(arr, n+1);
    arr[n]=k;
   }

 bool NewsAllowed(string &reason)
   {
    reason = "ok";
    if(!UseNewsFilter)
      return true;

    // Derive keys to match against news file entries
    string keys[];
    string sU = _Symbol; StringToUpper(sU);
    // Add full symbol and wildcard
    AddUniqueKey(keys, sU);
    AddUniqueKey(keys, "*");
    // Try to extract currency codes
    string ccy[] = { "USD","EUR","GBP","JPY","CHF","AUD","NZD","CAD","SEK","NOK","DKK","SGD","HKD","CNY","CNH","ZAR","MXN","TRY" };
    for(int i=0;i<ArraySize(ccy);++i) if(StringFind(sU, ccy[i])>=0) AddUniqueKey(keys, ccy[i]);
    // Index heuristics -> base currency
    if(StringFind(sU, "US30")>=0 || StringFind(sU, "US500")>=0 || StringFind(sU, "NAS")>=0 || StringFind(sU, "DJ")>=0 || StringFind(sU, "SPX")>=0)
      AddUniqueKey(keys, "USD");
    if(StringFind(sU, "GER")>=0 || StringFind(sU, "DAX")>=0 || StringFind(sU, "FRA40")>=0 || StringFind(sU, "CAC")>=0)
      AddUniqueKey(keys, "EUR");
    if(StringFind(sU, "UK100")>=0 || StringFind(sU, "FTSE")>=0)
      AddUniqueKey(keys, "GBP");
    if(StringFind(sU, "JPN")>=0 || StringFind(sU, "JP")>=0 || StringFind(sU, "NIK")>=0)
      AddUniqueKey(keys, "JPY");
    if(StringFind(sU, "HK50")>=0 || StringFind(sU, "HSI")>=0)
      AddUniqueKey(keys, "HKD");
    if(StringFind(sU, "AUS")>=0)
      AddUniqueKey(keys, "AUD");

    datetime now = TimeCurrent();
    // Scan loaded blackout windows
    for(int i=0;i<ArraySize(g_news_key);++i)
      {
        // impact threshold
        if(g_news_impact[i] < NewsImpactMin) continue;
        // key match
        bool match=false;
        for(int j=0;j<ArraySize(keys) && !match;++j)
          if(g_news_key[i]==keys[j]) match=true;
        if(!match) continue;
        // window with buffers
        datetime from = g_news_from[i] - (NewsBufferBeforeMin*60);
        datetime to   = g_news_to[i]   + (NewsBufferAfterMin*60);
        if(now>=from && now<=to)
          {
            reason = "news_window";
            return false;
          }
      }
    return true;
   }

 bool PromotionAllowed(string &reason)
   {
    reason = "ok";
    if(!UsePromotionGate)
      return true;
    // Apply only on live accounts if configured
    if(PromoLiveOnly && AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_REAL)
      return true;
    MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
    int h = dt.hour;
    // handle windows possibly spanning midnight
    bool in_window = false;
    if(PromoStartHour<=PromoEndHour)
      in_window = (h>=PromoStartHour && h<PromoEndHour);
    else
      in_window = (h>=PromoStartHour || h<PromoEndHour);
    if(!in_window)
      { reason = "promo_window"; return false; }
    return true;
   }

 bool RegimeAllowed(string &reason)
   {
    reason = "ok";
    if(!UseRegimeGate)
      return true;
    int atr_handle = iATR(_Symbol, _Period, RegimeATRPeriod);
    if(atr_handle==INVALID_HANDLE)
      return true;
    double atr_buf[]; ArrayResize(atr_buf,1);
    int copied = CopyBuffer(atr_handle, 0, 0, 1, atr_buf);
    IndicatorRelease(atr_handle);
    if(copied!=1)
      return true;
    double atr = atr_buf[0];
    double px  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if(atr<=0.0 || px<=0.0)
      return true; // cannot assess -> allow
    double atr_pct = 100.0 * atr / px;
    if(RegimeMinATRPct>0.0 && atr_pct < RegimeMinATRPct)
      { reason = "regime_low_atr"; return false; }
    if(RegimeMaxATRPct>0.0 && atr_pct > RegimeMaxATRPct)
      { reason = "regime_high_atr"; return false; }
    return true;
   }

 bool CircuitCooldownAllowed(string &reason)
   {
    reason = "ok";
    if(CircuitCooldownSec<=0)
      return true;
    if(g_last_trade_placed<=0)
      return true;
    datetime now = TimeCurrent();
    if((now - g_last_trade_placed) < CircuitCooldownSec)
      { reason = "circuit_cooldown"; return false; }
    return true;
   }

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
          ulong t = PositionGetTicket(i);
          if(t==0) continue;
          if(!PositionSelectByTicket(t)) continue;
          string osym = PositionGetString(POSITION_SYMBOL);
          if(osym=="" || osym==_Symbol) continue;
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

// --- Insights/Policy helpers and loaders
// Trim helper
string TrimCopy(string s){ StringTrimLeft(s); StringTrimRight(s); return s; }

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
      if(ShouldLog(LOG_WARN)) PrintFormat("Policy gating: cannot open %s (Common). Err=%d", path, GetLastError());
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
         int c = StringFind(line, ":", p); if(c>=0){ string num = TrimCopy(StringSubstr(line, c+1)); cur_sl = StringToDouble(num); }
        }
      // optional: tp_scale
      p = StringFind(line, "\"tp_scale\"", 0);
      if(p>=0)
        {
         int c = StringFind(line, ":", p); if(c>=0){ string num = TrimCopy(StringSubstr(line, c+1)); cur_tp = StringToDouble(num); }
        }
      // optional: trail_scale
      p = StringFind(line, "\"trail_scale\"", 0);
      if(p>=0)
        {
         int c = StringFind(line, ":", p); if(c>=0){ string num = TrimCopy(StringSubstr(line, c+1)); cur_tr = StringToDouble(num); }
        }
      // commit when we have strat+symbol (timeframe may be -1)
      if(cur_s!="" && cur_y!="" && cur_tf!=-2 && cur_p>=0.0)
        {
         int n = ArraySize(g_pol_strat);
         ArrayResize(g_pol_strat,n+1); ArrayResize(g_pol_sym,n+1); ArrayResize(g_pol_tf,n+1);
         ArrayResize(g_pol_p,n+1); ArrayResize(g_pol_sl,n+1); ArrayResize(g_pol_tp,n+1); ArrayResize(g_pol_trail,n+1);
         g_pol_strat[n]=cur_s; g_pol_sym[n]=cur_y; g_pol_tf[n]=cur_tf; g_pol_p[n]=cur_p; g_pol_sl[n]=cur_sl; g_pol_tp[n]=cur_tp; g_pol_trail[n]=cur_tr;
         // reset slice accumulators for next object
         cur_s=""; cur_y=""; cur_tf=-1; cur_p=-1.0; cur_sl=1.0; cur_tp=1.0; cur_tr=1.0;
        }
     }
   FileClose(h);
   g_policy_loaded = (ArraySize(g_pol_strat)>0);
   if(ShouldLog(LOG_INFO)) PrintFormat("Policy gating: min_conf=%.3f slices=%d", g_policy_min_conf, ArraySize(g_pol_strat));
   return g_policy_loaded;
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

// --- Exploration counters (weekly/daily) persistence
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
   if(h==INVALID_HANDLE) { if(ShouldLog(LOG_INFO)) PrintFormat("Explore persist: no prior %s (ok)", path); return true; }
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
   if(h==INVALID_HANDLE) { if(ShouldLog(LOG_INFO)) PrintFormat("Explore persist(day): no prior %s (ok)", path); return true; }
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

// --- Evaluation and execution orchestrator
 void EvaluateAndMaybeExecute(const TradeOrder &order)
   {
    if(g_eval_busy) return; // prevent reentry
    g_eval_busy = true;
    ulong t0 = GetTickCount();

    EnsureSessionRollover();
    EnsureTelemetry();
    EnsurePM();
    EnsureSessionManager();
    EnsureCorrelationManager();
    EnsureVolatilitySizer();

    // Shadow gates (diagnostic only)
    if(NoConstraintsMode && TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
      {
       int lat=0;
       string r;
       r=""; bool s_ok = SpreadAllowed(r); lat=(int)(GetTickCount()-t0);
       (*g_telemetry).LogGatingShadow(order.strategy_name, _Symbol, (int)_Period, "spread", s_ok, (s_ok?"ok":r)+";p6_latency="+IntegerToString(lat)+"ms", true);
       r=""; bool ses_ok = SessionAllowed(r); lat=(int)(GetTickCount()-t0);
       (*g_telemetry).LogGatingShadow(order.strategy_name, _Symbol, (int)_Period, "session", ses_ok, (ses_ok?"ok":r)+";p6_latency="+IntegerToString(lat)+"ms", true);
       r=""; bool r_ok = RiskAllowed(r); lat=(int)(GetTickCount()-t0);
       (*g_telemetry).LogGatingShadow(order.strategy_name, _Symbol, (int)_Period, "risk", r_ok, (r_ok?"ok":r)+";p6_latency="+IntegerToString(lat)+"ms", true);
       r=""; bool news_ok = NewsAllowed(r); lat=(int)(GetTickCount()-t0);
       (*g_telemetry).LogGatingShadow(order.strategy_name, _Symbol, (int)_Period, "news", news_ok, (news_ok?"ok":r)+";p6_latency="+IntegerToString(lat)+"ms", true);
       r=""; bool promo_ok = PromotionAllowed(r); lat=(int)(GetTickCount()-t0);
       (*g_telemetry).LogGatingShadow(order.strategy_name, _Symbol, (int)_Period, "promotion", promo_ok, (promo_ok?"ok":r)+";p6_latency="+IntegerToString(lat)+"ms", true);
       r=""; bool regime_ok = RegimeAllowed(r); lat=(int)(GetTickCount()-t0);
       (*g_telemetry).LogGatingShadow(order.strategy_name, _Symbol, (int)_Period, "regime", regime_ok, (regime_ok?"ok":r)+";p6_latency="+IntegerToString(lat)+"ms", true);
       r=""; bool cool_ok = CircuitCooldownAllowed(r); lat=(int)(GetTickCount()-t0);
       (*g_telemetry).LogGatingShadow(order.strategy_name, _Symbol, (int)_Period, "circuit_cooldown", cool_ok, (cool_ok?"ok":r)+";p6_latency="+IntegerToString(lat)+"ms", true);
       // Shadow insights gating (no side effects, ignore NoConstraints bypass)
       if(UseInsightsGating)
         {
          string rshadow=""; bool allow_shadow = Insights_Allow(order.strategy_name, _Symbol, (int)_Period, rshadow, true, true);
          (*g_telemetry).LogGatingShadow(order.strategy_name, _Symbol, (int)_Period, "insights", allow_shadow, rshadow, true);
         }
      }

    // Early gates (fail-closed unless NoConstraintsMode)
    if(!NoConstraintsMode)
      {
       // Spread gate
       string r_spread_early=""; if(!SpreadAllowed(r_spread_early))
         {
          if(ShouldLog(LOG_INFO)) PrintFormat("GATE: blocked %s on %s/%s reason=%s (spread)", order.strategy_name, _Symbol, EnumToString(_Period), r_spread_early);
          if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
            (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "spread", false, r_spread_early+";p6_latency="+IntegerToString((int)(GetTickCount()-t0))+"ms");
          g_eval_busy = false; return;
         }
       // Session gate
       string r_sess_early=""; if(!SessionAllowed(r_sess_early))
         {
          if(ShouldLog(LOG_INFO)) PrintFormat("GATE: blocked %s on %s/%s reason=%s (session)", order.strategy_name, _Symbol, EnumToString(_Period), r_sess_early);
          if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
            (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "session", false, r_sess_early+";p6_latency="+IntegerToString((int)(GetTickCount()-t0))+"ms");
          g_eval_busy = false; return;
         }
       string rr=""; if(!RiskAllowed(rr))
         {
          if(ShouldLog(LOG_INFO)) PrintFormat("GATE: blocked %s on %s/%s reason=%s (eq=%.2f base=%.2f high=%.2f ml=%.2f)", order.strategy_name, _Symbol, EnumToString(_Period), rr, AccountInfoDouble(ACCOUNT_EQUITY), g_session_equity_start, g_equity_highwater, AccountInfoDouble(ACCOUNT_MARGIN_LEVEL));
          if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
            (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "risk", false, rr+";p6_latency="+IntegerToString((int)(GetTickCount()-t0))+"ms");
          g_eval_busy = false; return;
         }
       string r_news_early=""; if(!NewsAllowed(r_news_early))
         {
          if(ShouldLog(LOG_INFO)) PrintFormat("GATE: blocked %s on %s/%s reason=%s (news)", order.strategy_name, _Symbol, EnumToString(_Period), r_news_early);
          if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
            (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "news", false, r_news_early+";p6_latency="+IntegerToString((int)(GetTickCount()-t0))+"ms");
          g_eval_busy = false; return;
         }
       string r_promo_early=""; if(!PromotionAllowed(r_promo_early))
         {
          if(ShouldLog(LOG_INFO)) PrintFormat("GATE: blocked %s on %s/%s reason=%s (promotion)", order.strategy_name, _Symbol, EnumToString(_Period), r_promo_early);
          if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
            (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "promotion", false, r_promo_early+";p6_latency="+IntegerToString((int)(GetTickCount()-t0))+"ms");
          g_eval_busy = false; return;
         }
       string r_regime_early=""; if(!RegimeAllowed(r_regime_early))
         {
          if(ShouldLog(LOG_INFO)) PrintFormat("GATE: blocked %s on %s/%s reason=%s (regime)", order.strategy_name, _Symbol, EnumToString(_Period), r_regime_early);
          if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
            (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "regime", false, r_regime_early+";p6_latency="+IntegerToString((int)(GetTickCount()-t0))+"ms");
          g_eval_busy = false; return;
         }
       string r_cool_early=""; if(!CircuitCooldownAllowed(r_cool_early))
         {
          if(ShouldLog(LOG_INFO)) PrintFormat("GATE: blocked %s on %s/%s reason=%s (circuit_cooldown)", order.strategy_name, _Symbol, EnumToString(_Period), r_cool_early);
          if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
            (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "circuit_cooldown", false, r_cool_early+";p6_latency="+IntegerToString((int)(GetTickCount()-t0))+"ms");
          g_eval_busy = false; return;
         }
      }

    // Insights/Policy gate (fail-closed unless NoConstraintsMode)
    if(!NoConstraintsMode)
      {
       // Check IncrementalInsightEngine for auto-promoted strategies
       if(CheckPointer(g_insight_engine) != POINTER_INVALID)
       {
          if(!g_insight_engine.IsStrategyApproved(order.strategy_name, _Symbol, (int)_Period))
          {
             // Strategy not yet promoted - block trade
             if(ShouldLog(LOG_INFO)) PrintFormat("[INSIGHTS] blocked %s on %s/%s reason=not_approved", 
                                                  order.strategy_name, _Symbol, EnumToString(_Period));
             g_eval_busy=false; return;
          }
       }
       
       string gate_reason="";
       bool ins_ok = Insights_Allow(order.strategy_name, _Symbol, (int)_Period, gate_reason);
       if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
         (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "insights", ins_ok, (ins_ok?"ok":gate_reason)+";p6_latency="+IntegerToString((int)(GetTickCount()-t0))+"ms");
       if(!ins_ok)
         {
          if(ShouldLog(LOG_INFO)) PrintFormat("[INSIGHTS] blocked %s on %s/%s reason=%s", order.strategy_name, _Symbol, EnumToString(_Period), gate_reason);
          g_eval_busy=false; return;
         }
      }

    // Correlation gate
    string r_corr=""; bool corr_ok = P5_CorrPruneAllow(order, r_corr);
    if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
      (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "corr", corr_ok, (corr_ok?"ok":r_corr)+";p6_latency="+IntegerToString((int)(GetTickCount()-t0))+"ms");
    if(!corr_ok) { if(ShouldLog(LOG_INFO)) PrintFormat("[CORR] blocked %s on %s/%s reason=%s", order.strategy_name, _Symbol, EnumToString(_Period), r_corr); g_eval_busy=false; return; }

    // Final RISK4 gates just before execution
    string r_rk_exec="";
    if(!RiskAllowed(r_rk_exec))
      {
       if(ShouldLog(LOG_INFO)) PrintFormat("[RISK4] blocked %s on %s/%s reason=%s", order.strategy_name, _Symbol, EnumToString(_Period), r_rk_exec);
       if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
         (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "risk4", false, r_rk_exec+";p6_latency="+IntegerToString((int)(GetTickCount()-t0))+"ms");
       g_eval_busy = false; return;
      }
    string r_spread_exec="";
    if(!SpreadAllowed(r_spread_exec))
      {
       if(ShouldLog(LOG_INFO)) PrintFormat("[RISK4] blocked %s on %s/%s reason=%s (spread)", order.strategy_name, _Symbol, EnumToString(_Period), r_spread_exec);
       if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
         (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "risk4_spread", false, r_spread_exec+";p6_latency="+IntegerToString((int)(GetTickCount()-t0))+"ms");
       g_eval_busy = false; return;
      }
    string r_sess_exec="";
    if(!SessionAllowed(r_sess_exec))
      {
       if(ShouldLog(LOG_INFO)) PrintFormat("[RISK4] blocked %s on %s/%s reason=%s (session)", order.strategy_name, _Symbol, EnumToString(_Period), r_sess_exec);
        if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
         (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "risk4_session", false, r_sess_exec+";p6_latency="+IntegerToString((int)(GetTickCount()-t0))+"ms");
       g_eval_busy = false; return;
      }
    string r_news_exec="";
    if(!NewsAllowed(r_news_exec))
      {
       if(ShouldLog(LOG_INFO)) PrintFormat("[RISK4] blocked %s on %s/%s reason=%s (news)", order.strategy_name, _Symbol, EnumToString(_Period), r_news_exec);
       if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
         (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "risk4_news", false, r_news_exec+";p6_latency="+IntegerToString((int)(GetTickCount()-t0))+"ms");
       g_eval_busy = false; return;
      }
    string r_promo_exec="";
    if(!PromotionAllowed(r_promo_exec))
      {
       if(ShouldLog(LOG_INFO)) PrintFormat("[RISK4] blocked %s on %s/%s reason=%s (promotion)", order.strategy_name, _Symbol, EnumToString(_Period), r_promo_exec);
       if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
         (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "risk4_promotion", false, r_promo_exec+";p6_latency="+IntegerToString((int)(GetTickCount()-t0))+"ms");
       g_eval_busy = false; return;
      }
    string r_regime_exec="";
    if(!RegimeAllowed(r_regime_exec))
      {
       if(ShouldLog(LOG_INFO)) PrintFormat("[RISK4] blocked %s on %s/%s reason=%s (regime)", order.strategy_name, _Symbol, EnumToString(_Period), r_regime_exec);
       if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
         (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "risk4_regime", false, r_regime_exec+";p6_latency="+IntegerToString((int)(GetTickCount()-t0))+"ms");
       g_eval_busy = false; return;
      }
    string r_cool_exec="";
    if(!CircuitCooldownAllowed(r_cool_exec))
      {
       if(ShouldLog(LOG_INFO)) PrintFormat("[RISK4] blocked %s on %s/%s reason=%s (circuit_cooldown)", order.strategy_name, _Symbol, EnumToString(_Period), r_cool_exec);
       if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
         (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "risk4_circuit_cooldown", false, r_cool_exec+";p6_latency="+IntegerToString((int)(GetTickCount()-t0))+"ms");
       g_eval_busy = false; return;
      }

    if(ShouldLog(LOG_INFO)) PrintFormat("[READY] %s on %s/%s passed gates", order.strategy_name, _Symbol, EnumToString(_Period));

   // Apply policy-driven scaling (if enabled and available) using a local copy of order
   TradeOrder req = order;
   double ppol_now = (UsePolicyGating && g_policy_loaded ? GetPolicyProb(req.strategy_name, _Symbol, (int)_Period) : -1.0);
   ApplyPolicyScaling(req, _Symbol, (int)_Period, ppol_now);

   // --- FR-06 Volatility Position Sizing (set req.lots) ---
  if(UseVolatilitySizer && CheckPointer(g_volatility_sizer)!=POINTER_INVALID)
    {
     double stop_pts = 0.0;
     double bid=0.0, ask=0.0; SymbolInfoDouble(_Symbol, SYMBOL_BID, bid); SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
     if(req.stop_loss>0.0)
       {
        if(req.order_type==ORDER_TYPE_BUY || req.order_type==ORDER_TYPE_BUY_LIMIT || req.order_type==ORDER_TYPE_BUY_STOP)
          {
           double ref = (req.price>0.0? req.price : ask);
           stop_pts = MathMax(0.0, (ref - req.stop_loss)/_Point);
          }
        else
          {
           double ref = (req.price>0.0? req.price : bid);
           stop_pts = MathMax(0.0, (req.stop_loss - ref)/_Point);
          }
       }
     double atr_pct=0.0; string vs_r1=""; double mult_hint = (*g_volatility_sizer).CalculateSizeMultiplier(atr_pct, vs_r1);
     double mult_final=1.0; string vs_r2="";
     double sized = (*g_volatility_sizer).CalculatePositionSize(BaseLotSize, stop_pts, mult_final, vs_r2);
     if(sized>0.0) req.lots = sized;
     if(TelemetryEnabled && CheckPointer(g_tel_standard)!=POINTER_INVALID)
       (*g_tel_standard).LogVolatilitySizingEvent(_Symbol, (int)_Period, BaseLotSize, mult_final, (sized>0.0?sized:BaseLotSize), atr_pct);
    }

  // Execute the trade using TradeManager
  CTradeManager tm(_Symbol, 0.0 /* default to symbol min lot if order.lots==0 */, (int)MagicNumber);
   bool exec_ok = tm.ExecuteOrder(req);
   uint retcode = tm.ResultRetcode();
   ulong deal_id = tm.ResultDeal();
   ulong order_id = tm.ResultOrder();

   if(exec_ok)
     {
      g_last_trade_placed = TimeCurrent();
      if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
        (*g_telemetry).LogTradeExecuted(order.strategy_name, _Symbol, (int)_Period, (int)retcode, deal_id, order_id);
      // Exploration accounting: count only on successful execution
      if(g_explore_pending_key!="")
        {
         IncExploreCount(g_explore_pending_key);
         if(ShouldLog(LOG_INFO)) PrintFormat("Exploration used for %s -> %d/%d", g_explore_pending_key, GetExploreCount(g_explore_pending_key), ExploreMaxPerSlice);
         g_explore_pending_key = "";
        }
     }
   else
     {
      if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
        (*g_telemetry).LogTradeFailed(order.strategy_name, _Symbol, (int)_Period, (int)retcode);
      // Ensure exploration pending key does not leak across failed executions
      if(g_explore_pending_key!="")
        {
         if(ShouldLog(LOG_INFO)) PrintFormat("Exploration not used due to failed execution for %s", g_explore_pending_key);
         g_explore_pending_key = "";
        }
     }

   g_eval_busy = false;
  }

// --- Terminal event handlers
int OnInit()
  {
   EnsureSessionRollover();
   EnsureTelemetry();
   EnsurePM();
   EnsureSessionManager();
   EnsureCorrelationManager();
   EnsureVolatilitySizer();
   
   // Initialize Incremental Insight Engine for real-time strategy approval
   g_insight_engine = new CIncrementalInsightEngine();
   if(CheckPointer(g_insight_engine) != POINTER_INVALID)
   {
      if(ShouldLog(LOG_INFO)) Print("[LiveEA] Incremental Insight Engine initialized");
   }
   // Load exploration counters and gating caches
   LoadExploreCounts();
   LoadExploreCountsDay();
   bool gate_loaded = Insights_Load();
   if(ShouldLog(LOG_INFO)) PrintFormat("Insights gating cache load: %s", (gate_loaded?"ok":"fail"));
   if(UsePolicyGating) { bool pol_ok = Policy_Load(); if(ShouldLog(LOG_INFO)) PrintFormat("Policy cache load: %s", (pol_ok?"ok":"fail")); }
   // Load news blackout windows
   if(UseNewsFilter && NewsUseFile)
     {
      // Reset and load
      ArrayResize(g_news_key,0); ArrayResize(g_news_from,0); ArrayResize(g_news_to,0); ArrayResize(g_news_impact,0);
      int h = FileOpen(NewsFileRelPath, FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
      if(h!=INVALID_HANDLE)
        {
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
      else
        {
         if(ShouldLog(LOG_WARN)) PrintFormat("News filter: cannot open %s (Common). Err=%d", NewsFileRelPath, GetLastError());
        }
     }
   // GATE summary
   string gsum = StringFormat("insights=%s policy=%s(min=%.3f) explore=%s caps(slice=%d/day=%d)",
      (UseInsightsGating?"on":"off"), (UsePolicyGating?"on":"off"), g_policy_min_conf,
      (ExploreOnNoSlice?"on":"off"), ExploreMaxPerSlice, ExploreMaxPerSlicePerDay);
   if(ShouldLog(LOG_INFO)) PrintFormat("[GATE] %s", gsum);
   if(ShouldLog(LOG_INFO)) Print("LiveEA initialized");
   // Start watcher timer for insights ready signal
   if(InsightsAutoReload && InsightsReadyPollSec>0)
      EventSetTimer(InsightsReadyPollSec);
   // Bootstrap: ensure insights are fresh or request a rebuild immediately
   MaybeEnsureInsights();
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(CheckPointer(g_position_manager)!=POINTER_INVALID) { delete g_position_manager; g_position_manager=NULL; }
   if(CheckPointer(g_telemetry)!=POINTER_INVALID)        { delete g_telemetry;        g_telemetry=NULL; }
   if(CheckPointer(g_tel_standard)!=POINTER_INVALID)     { delete g_tel_standard;     g_tel_standard=NULL; }
   if(CheckPointer(g_session_manager)!=POINTER_INVALID)  { delete g_session_manager;  g_session_manager=NULL; }
   if(CheckPointer(g_correlation_manager)!=POINTER_INVALID) { delete g_correlation_manager; g_correlation_manager=NULL; }
   if(CheckPointer(g_volatility_sizer)!=POINTER_INVALID) { delete g_volatility_sizer; g_volatility_sizer=NULL; }
   if(CheckPointer(g_insight_engine)!=POINTER_INVALID)   { delete g_insight_engine;   g_insight_engine=NULL; }
   if(InsightsAutoReload && InsightsReadyPollSec>0)
      EventKillTimer();
  }

void OnTick()
  {
   // Strategy orchestration is external; gates are available via EvaluateAndMaybeExecute(order)
   // Early gating before any selection/insights logic
   if(!EvaluateAndMaybeExecute_PreSelector())
     {
      if(ShouldLog(LOG_INFO)) Print("[EARLY] gates blocked tick");
      return;
     }
   // If an external orchestrator performs selection and prepares orders, it should
   // call EvaluateAndMaybeExecute_PreExecute() just before execution. We call it here
   // as a placeholder to ensure telemetry is emitted even when no orders are placed.
   EvaluateAndMaybeExecute_PreExecute();
  }

// --- Phase 6: Gate orchestration with shadow telemetry
ulong NowMs(){ return (ulong)GetTickCount(); }

void LogGate(const string tag, const bool allowed, const string phase, const ulong t0)
  {
   int latency = (int)(NowMs() - t0);
   if(ShouldLog(LOG_INFO))
      PrintFormat("[%s] %s latency_ms=%d", tag, (allowed?"allow":"block"), latency);
   if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
     {
      string det = StringFormat("phase=%s p6_latency_ms=%d", phase, latency);
      (*g_telemetry).LogEvent(_Symbol, (int)_Period, "gate", StringFormat("%s_%s", tag, (allowed?"allow":"block")), det);
     }
   // Standardized telemetry
   if(TelemetryEnabled && CheckPointer(g_tel_standard)!=POINTER_INVALID)
     {
      (*g_tel_standard).LogGateEvent(_Symbol, (int)_Period, tag, allowed, phase, latency, "n/a");
     }
  }

// Early gates before selector/insights
bool EarlyGatesAllow()
  {
   string reason;
   ulong t0;
   // NEWS
   t0=NowMs(); bool news_ok = NewsAllowed(reason); LogGate("NEWS", news_ok, "early", t0);
   if(!news_ok && !NoConstraintsMode) return false;
   // PROMO
   t0=NowMs(); bool promo_ok = PromotionAllowed(reason); LogGate("PROMO", promo_ok, "early", t0);
   if(!promo_ok && !NoConstraintsMode) return false;
   // REGIME
   t0=NowMs(); bool reg_ok = RegimeAllowed(reason); LogGate("REGIME", reg_ok, "early", t0);
   if(!reg_ok && !NoConstraintsMode) return false;
   // CIRCUIT cooldown
   t0=NowMs(); bool circ_ok = CircuitCooldownAllowed(reason); LogGate("CIRCUIT", circ_ok, "early", t0);
   // SESSION (diagnostic in early; block only if NoConstraintsMode is false)
   EnsureSessionManager();
   if(UseSessionManager && CheckPointer(g_session_manager)!=POINTER_INVALID)
     {
      t0=NowMs(); bool sess_ok = g_session_manager.IsSessionAllowed(reason); LogGate("SESSION", sess_ok, "early", t0);
      if(!sess_ok && !NoConstraintsMode) return false;
     }
   // CORRELATION (diagnostic/block depending on NoConstraintsMode)
   EnsureCorrelationManager();
   if(UseCorrelationManager && CheckPointer(g_correlation_manager)!=POINTER_INVALID)
     {
      double max_corr;
      t0=NowMs(); bool corr_ok = g_correlation_manager.CheckCorrelationLimits(reason, max_corr); LogGate("CORR", corr_ok, "early", t0);
      if(!corr_ok && !NoConstraintsMode) return false;
     }
   return true;
  }

// Final risk4 gates just before execution
bool Risk4GatesAllow()
  {
   string reason;
   ulong t0;
   t0=NowMs(); bool news_ok = NewsAllowed(reason); LogGate("NEWS", news_ok, "risk4", t0); if(!news_ok) return false;
   t0=NowMs(); bool promo_ok= PromotionAllowed(reason); LogGate("PROMO", promo_ok,"risk4", t0); if(!promo_ok) return false;
   t0=NowMs(); bool reg_ok  = RegimeAllowed(reason); LogGate("REGIME", reg_ok, "risk4", t0); if(!reg_ok) return false;
   t0=NowMs(); bool circ_ok = CircuitCooldownAllowed(reason); LogGate("CIRCUIT", circ_ok,"risk4", t0); if(!circ_ok) return false;
   
   // FR-02 Session gate
   EnsureSessionManager();
   if(UseSessionManager && CheckPointer(g_session_manager)!=POINTER_INVALID)
     {
      t0=NowMs(); bool sess_ok = g_session_manager.IsSessionAllowed(reason); LogGate("SESSION", sess_ok, "risk4", t0); if(!sess_ok) return false;
     }
   
   // FR-05 Correlation gate
   EnsureCorrelationManager();
   if(UseCorrelationManager && CheckPointer(g_correlation_manager)!=POINTER_INVALID)
     {
      double max_corr;
      t0=NowMs(); bool corr_ok = g_correlation_manager.CheckCorrelationLimits(reason, max_corr); LogGate("CORR", corr_ok, "risk4", t0); if(!corr_ok) return false;
     }
   
   // FR-04 Position Manager gate
   EnsurePM();
   if(UsePositionManager && CheckPointer(g_position_manager)!=POINTER_INVALID)
     {
      int open_positions = PositionsTotal();
      bool pm_ok = (PMMaxOpenPositions<=0 ? true : (open_positions < PMMaxOpenPositions));
      t0=NowMs(); LogGate("PM", pm_ok, "risk4", t0); 
      if(!pm_ok) return false;
     }
   
   return true;
  }

// Public function to be called by orchestrator before/after selector/insights
bool EvaluateAndMaybeExecute_PreSelector()
  {
   return EarlyGatesAllow();
  }

bool EvaluateAndMaybeExecute_PreExecute()
  {
   return Risk4GatesAllow();
  }

// --- Insights ready/reload logic ---
bool IsInsightsFresh(const int fresh_minutes)
  {
   string ip = "DualEA\\insights.json";
   long ex_i = FileGetInteger(ip, FILE_EXISTS, true);
   if(ex_i==0) return false;
   datetime ti = (datetime)FileGetInteger(ip, FILE_MODIFY_DATE, true);
   if(fresh_minutes<=0) return true; // any existing is fine
   return ((TimeCurrent() - ti) <= (fresh_minutes*60));
  }

void RequestInsightsReload()
  {
   string path = "DualEA\\insights.reload";
   if(FileIsExist(path, FILE_COMMON)) FileDelete(path, FILE_COMMON);
   int h = FileOpen(path, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(h!=INVALID_HANDLE)
     {
      FileWrite(h, IntegerToString((int)TimeCurrent()));
      FileClose(h);
      if(ShouldLog(LOG_INFO)) Print("Insights reload requested");
     }
   else
     {
      if(ShouldLog(LOG_WARN)) PrintFormat("Insights reload: cannot create %s (err=%d)", path, GetLastError());
     }
  }

void CheckInsightsReady()
  {
   string rdy = "DualEA\\insights.ready";
   int h = FileOpen(rdy, FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(h==INVALID_HANDLE) return;
   // Ready present -> consume and reload
   FileClose(h);
   if(!FileDelete(rdy, FILE_COMMON))
     {
      // still proceed, but log
      if(ShouldLog(LOG_WARN)) PrintFormat("Insights ready: cannot delete %s (err=%d)", rdy, GetLastError());
     }
   bool ok = Insights_Load();
   if(ShouldLog(LOG_INFO)) PrintFormat("Insights ready detected: reload %s", (ok?"ok":"fail"));
   g_waiting_insights = false;
  }

void MaybeEnsureInsights()
  {
   if(!InsightsAutoReload) return;
   if(IsInsightsFresh(InsightsLiveFreshMinutes)) return;
   if(!g_waiting_insights)
     {
      RequestInsightsReload();
      g_waiting_insights = true;
     }
  }

void OnTimer()
  {
   if(!InsightsAutoReload) return;
   MaybeEnsureInsights();
   CheckInsightsReady();
  }

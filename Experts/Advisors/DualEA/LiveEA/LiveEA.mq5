// LiveEA.mq5
// Trades on a live account, using strategies influenced by the knowledge base.

#property copyright "2025, Windsurf Engineering"
#property link      "https://www.windsurf.ai"
#property version   "1.00"

// --- Core Interfaces & Data Structures
#include "..\Include\IStrategy.mqh"

// --- Core Services
#include "..\Include\KnowledgeBase.mqh"
#include "..\Include\TradeManager.mqh"
// --- Telemetry
#include "..\Include\Telemetry.mqh"

// --- Standard Libraries
#include <Arrays/ArrayObj.mqh> // Include for CArrayObj
#include <Files/File.mqh>

// --- Strategy Implementations
// Per-asset registry (internally includes concrete strategy headers)
#include "..\\Include\\Strategies\\AssetRegistry.mqh"
// Strategy selector
#include "..\\Include\\StrategySelector.mqh"
// Shared insights loader (DRY parsing across EAs)
#include "..\\Include\\InsightsLoader.mqh"

// --- Position Manager
#include "..\\Include\\PositionManager.mqh"

// --- Input Parameters
input double LotSize = 0.01;
input int    MagicNumber = 54321;  // distinct from PaperEA default
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

// --- Position Manager integration (off by default to avoid regressions)
input bool   UsePositionManager   = false;

// --- Position Manager tuning & correlation controls
input bool   PM_EnableCorrelationSizing = true;     // apply correlation-adjusted volume when placing/scaling trades
input bool   PM_EnableAdaptiveSizing    = false;    // enable adaptive sizing inside PositionManager
input double PM_MinSizeMult             = 0.5;      // min multiplier for adaptive sizing
input double PM_MaxSizeMult             = 1.5;      // max multiplier for adaptive sizing
input int    PM_ScalingProfile          = 1;        // 0=Aggressive, 1=Moderate, 2=Conservative
input bool   PM_EnableVolatilityExit    = true;     // allow ATR-based volatility exits via PositionManager
input double PM_VolatilityExitATRMult   = 2.0;      // ATR multiple for volatility exits

// --- Position Manager dynamic risk caps (disabled by default)
input bool   PM_EnableDynamicRiskCaps   = false;    // cap per-position and portfolio growth dynamically
input double PM_MaxDailyDDPct           = 5.0;      // max intraday drawdown % before tighter caps (advisory)
input double PM_MaxPosRiskPct           = 1.0;      // max risk % per position (advisory)
input double PM_MaxPortfolioRiskPct     = 5.0;      // max total risk % across portfolio (advisory)
input double PM_RiskDecay               = 0.50;     // decay factor for dynamic caps (0..1)

// --- Correlation sizing minimum floors (avoid over‑dampening)
input double PM_CorrMinMult             = 0.25;     // minimum multiplier of base lots after correlation dampening
input double PM_CorrMinLots             = 0.00;     // absolute minimum lots after dampening (in lots)

// --- No-Constraints mode (live default OFF)
input bool   NoConstraintsMode    = false;     // bypass selector/insights/time gates and exploration caps

// --- Insights gating controls
input bool   UseInsightsGating    = true;
input int    GateMinTrades        = 0;        // loosened for bootstrap
input double GateMinWinRate       = 0.00;     // loosened for bootstrap
input double GateMinExpectancyR   = -10.0;    // loosened for bootstrap
input double GateMaxDrawdownR     = 1000000.0;// loosened for bootstrap
input double GateMinProfitFactor  = 0.00;     // loosened for bootstrap
// --- Insights auto-build & staleness
input bool   InsightsAutoBuild    = true;     // auto-build insights.json when missing or stale
input int    InsightsStaleHours   = 6;        // rebuild if older than N hours (0=disable age check)
input bool   InsightsCheckOnTimer = true;     // also check on timer events
// --- Insights rebuild safety guards
input bool   InsightsSuppressWhileTrading = true; // skip rebuild if an active position exists for this symbol & MagicNumber
input int    InsightsRebuildCooldownMin   = 30;   // minimum minutes between rebuilds (0=disable)
input int    InsightsAfterTradeCooldownMin= 5;    // suppress rebuilds for N minutes after placing a trade (0=disable)
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

// --- Selector recency weighting
input bool   SelUseRecency         = true;   // blend recent performance
input int    SelRecentDays         = 14;     // lookback days from features.csv
input double SelRecAlpha           = 0.5;    // 0..1 weight towards recent
input bool   SelStrictThresholds     = false;   // enforce hard thresholds inside selector

// --- MTF confirmation gating
input bool            EnableMTFConfirmations = false; // require confirmation from a higher timeframe
input ENUM_TIMEFRAMES MTFConfirmTF          = PERIOD_H1; // timeframe used for confirmation
input double          MTFConfirmMinScore     = 0.0;      // min selector score on confirm TF

// --- Underperformance gating (recent overlays from features.csv)
input bool   UnderperfDisableEnabled = false; // block when recent overlay underperforms
input int    UnderperfWindowDays     = 14;    // recency window for recent overlays
input double UnderperfMinPF          = 1.0;   // minimum recent profit factor
input double UnderperfMinWR          = 0.45;  // minimum recent win rate
input double UnderperfMinExpR        = 0.0;   // minimum recent expectancy (R)
input bool   UnderperfAutoDisable    = false; // also SetEnabled(false) when underperforming

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

// --- Verbosity controls
enum LogLevel { LOG_ERROR = 0, LOG_INFO = 1, LOG_DEBUG = 2 };
input int    Verbosity = LOG_INFO; // 0=silent, 1=info, 2=debug
bool ShouldLog(const int level){ return Verbosity >= level; }

// Logging controls
input bool   DebugTrailing = false;
input bool   KBDebugInit   = true;

// --- Trainer / LSTM flags (for downstream trainer tooling)
input bool   TrainerLSTM_Enable     = false;
input int    TrainerLSTM_MinSeq     = 50;
input int    TrainerLSTM_MaxSeq     = 500;
input bool   TrainerLSTM_UseRecency = true;

// --- Heartbeat / status panel
input bool   HeartbeatEnabled = true;
input int    HeartbeatMinutes = 15;   // update every N minutes
input bool   HeartbeatVerbose = true; // print [STRAT] lines per strategy

// --- Timer-based evaluation scan
input bool   TimerScanEnabled = false;   // enable periodic EvaluateAndMaybeExecute on timer
input int    TimerScanMinutes = 5;       // run evaluation every N minutes on timer
input bool   TimerScanVerbose = false;   // extra logs when timer scan triggers

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

// --- Phase 5 advanced gating
input bool   P5_CorrPruneEnable      = false;   // prune highly correlated strategies (across open positions)
input double P5_CorrMax              = 0.80;    // max allowed correlation before pruning
input int    P5_CorrLookbackDays     = 30;      // lookback window for correlation build
input bool   P5_StabilityGateEnable  = false;   // gate on parameter/performance stability (if available)
input int    P5_StabilityWindowDays  = 14;      // window for stability tracking
input double P5_StabilityMaxStdR     = 1.00;    // max allowed std-dev of R in window
input bool   P5_PersistLossCounters  = false;   // persist consecutive loss counters across sessions
input int    P5_AutoDisableCooldownMin = 60;    // minutes to keep a strategy disabled after auto-disable (0=disable cooldown)
input bool   P5_AutoReenableOnTimer    = true;  // automatically re-enable strategies when cooldown expires (checked on timer)
input bool   P5_AutoTuneEnabled        = false; // periodically call AutoTuneIndicators() for strategies
input int    P5_AutoTuneEveryMin       = 60;    // minutes between auto-tune runs per strategy

// --- Globals
CKnowledgeBase*         g_kb = NULL;
CTradeManager*          g_trade_manager = NULL;
CArrayObj*              g_strategies; // Array to hold all strategy objects
CFeaturesKB*            g_features = NULL; // Features logger
CTelemetry*             g_telemetry = NULL; // Telemetry logger
CPositionManager*       g_position_manager = NULL; // Position Manager
// Strategy selector
CStrategySelector*      g_selector = NULL;
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
// Pending order/deal attribution (to map back strategy names on asynchronous trade events)
ulong                   g_pending_orders[];
string                  g_pending_orders_strat[];
ulong                   g_pending_deals[];
string                  g_pending_deals_strat[];
// Persistent consecutive loss tracking (per symbol + magic)
string                  g_loss_sym[];
long                    g_loss_mag[];
int                     g_loss_cnt[];
// Re-entrancy guard and cadence trackers
bool                    g_eval_busy = false;      // protects evaluation from overlapping runs
datetime                g_last_timer_scan = 0;    // last time Evaluate ran via timer-scan
datetime                g_last_heartbeat = 0;     // last time heartbeat was logged
datetime                g_last_insights_check = 0; // last time insights staleness was checked
datetime                g_last_insights_rebuild = 0; // last time insights rebuild completed
datetime                g_last_trade_placed = 0;    // last time a trade was placed
// Phase 6: timer scan telemetry start time (ms)
ulong                   g_p6_scan_t0_ms = 0;

// --- Helpers: tracking lookup and robust closure logging/removal
int FindTrackedIndexByPid(ulong pid)
  {
   for(int t=0; t<ArraySize(g_pos_ids); ++t)
     if(g_pos_ids[t]==pid) return t;
   return -1;
  }

bool IsPositionOpenByIdentifier(const ulong pid)
  {
   int total = PositionsTotal();
   CPositionInfo pos;
   for(int i=0; i<total; ++i)
     {
      if(!pos.SelectByIndex(i)) continue;
      // Filter same symbol & magic to reduce scan cost
      string sym = pos.Symbol();
      long   mag = (long)pos.Magic();
      if(sym!=_Symbol || mag!=MagicNumber) continue;
      ulong  id  = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      if(id==pid) return true;
     }
   return false;
  }

 // Check if there is any active position for this EA instance (symbol + MagicNumber)
 bool HasActivePositionForThisEAMagic()
   {
    int total = PositionsTotal();
    CPositionInfo pos;
    for(int i=0; i<total; ++i)
      {
       if(!pos.SelectByIndex(i)) continue;
       if(pos.Symbol()!=_Symbol) continue;
       long mag = (long)pos.Magic();
       if(mag==MagicNumber)
         return true;
      }
    return false;
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

    // Update persistent consecutive loss counter (per symbol+magic) when enabled
    if(P5_PersistLossCounters)
      {
       if(profit_money < 0.0)
         {
          IncConsecLossPersist(sym_close, (long)MagicNumber);
         }
       else
         {
          SetConsecLossPersist(sym_close, (long)MagicNumber, 0);
         }
       if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
         {
          int cl_now = GetConsecLossPersist(sym_close, (long)MagicNumber);
          string det = StringFormat("consec=%d profit=%.2f", cl_now, profit_money);
          (*g_telemetry).LogEvent(sym_close, (int)_Period, strat, "consec_loss_update", det);
         }
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

// Persistent consecutive loss counters (per symbol + magic) using per-key files
string LossCountersDirPath()
  {
   return "DualEA\\loss\\"; // directory in FILE_COMMON
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
   // Ensure directory exists in Common Files
   string absdir = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + dir;
   FolderCreate(absdir);
   string fname = "loss_" + SanitizeForFilename(sym) + "_" + IntegerToString(mag) + ".csv";
   return dir + fname;
  }

// Save only a single key file
void SaveLossKey(const string sym, const long mag, const int consec)
  {
   string path = LossKeyPath(sym, mag);
   int h = FileOpen(path, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(h==INVALID_HANDLE){ PrintFormat("Loss persist(key): cannot open %s for write. Err=%d", path, GetLastError()); return; }
   FileWrite(h, "symbol,magic,consec");
   FileWrite(h, sym, IntegerToString(mag), IntegerToString(consec));
   FileClose(h);
  }

// Bulk save (iterates keys), retained for OnDeinit convenience
void SaveLossCounters()
  {
   for(int i=0;i<ArraySize(g_loss_sym);++i)
     SaveLossKey(g_loss_sym[i], g_loss_mag[i], g_loss_cnt[i]);
  }

bool LoadLossCounters()
  {
   ArrayResize(g_loss_sym,0); ArrayResize(g_loss_mag,0); ArrayResize(g_loss_cnt,0);
   string dir = LossCountersDirPath();
   string absdir = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + dir;
   FolderCreate(absdir);
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
    // Use shared loader to avoid divergence between EAs
    int loaded = Insights_Load_Default(
       g_gate_strat, g_gate_sym, g_gate_tf,
       g_gate_cnt, g_gate_wr, g_gate_avgR,
       g_gate_pf, g_gate_dd);
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
          { reason = "min_trades"; return false; }
        if(g_gate_wr[i]  < GateMinWinRate)
          { reason = "win_rate"; return false; }
        if(g_gate_avgR[i]< GateMinExpectancyR)
          { reason = "expectancy"; return false; }
        if(g_gate_dd[i]  > GateMaxDrawdownR)
          { reason = "drawdown"; return false; }
        if(g_gate_pf[i]  < GateMinProfitFactor)
          { reason = "profit_factor"; return false; }
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
        { reason = "min_trades_agg_sym"; return false; }
      if(wr    < GateMinWinRate)
        { reason = "win_rate_agg_sym"; return false; }
      if(avgR  < GateMinExpectancyR)
        { reason = "expectancy_agg_sym"; return false; }
      if(dd    > GateMaxDrawdownR)
        { reason = "drawdown_agg_sym"; return false; }
      if(pf    < GateMinProfitFactor)
        { reason = "profit_factor_agg_sym"; return false; }
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
        { reason = "slice_exists"; return false; }
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

// Policy gating helpers
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
      if(tf>ti) return true;
     }
   string kp = "DualEA\\knowledge_base.csv";
   if(FileGetInteger(kp, FILE_EXISTS, true)>0)
     {
      datetime tk = (datetime)FileGetInteger(kp, FILE_MODIFY_DATE, true);
      if(tk>ti) return true;
     }
   return false;
  }

// Rebuild insights.json and reload gating/selector caches
bool Insights_RebuildAndReload(const string reason)
  {
   if(ShouldLog(LOG_INFO)) PrintFormat("Insights auto-build triggered (%s)", reason);
   CInsightsBuilder b;
   bool ok = b.Build();
   if(!ok)
     {
      PrintFormat("Insights auto-build FAILED (%s). Err=%d", reason, GetLastError());
      return false;
     }
   // Reload insights gating cache
   bool gate_loaded = Insights_Load();
   if(ShouldLog(LOG_INFO)) PrintFormat("Insights gating cache reload after build: %s", (gate_loaded?"ok":"fail"));
   // Reload selector insights if available
   bool sel_ok = false;
   bool sel_attempted = false;
   if(CheckPointer(g_selector)!=POINTER_INVALID)
     {
      sel_attempted = true;
      sel_ok = (*g_selector).Load();
      if(ShouldLog(LOG_INFO)) PrintFormat("Selector insights reload after build: %s", (sel_ok?"ok":"fail"));
     }
   // Mark rebuild time for cooldown enforcement
   g_last_insights_rebuild = TimeCurrent();
   // Telemetry: Phase 5 refresh after successful rebuild and reload
   if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
     {
      string details = StringFormat("reason=%s gate=%s selector=%s", reason, (gate_loaded?"ok":"fail"), (sel_attempted? (sel_ok?"ok":"fail") : "skipped"));
      (*g_telemetry).LogEvent(_Symbol, (int)_Period, "sys", "p5_refresh", details);
     }
   return true;
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

// --- String trim helper (returns a trimmed copy)
string TrimCopy(string s)
  {
   StringTrimLeft(s);
   StringTrimRight(s);
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
   string gsum = StringFormat(
      "insights=%s policy=%s(min=%.3f) fallback(def=%s,demo_only=%s,no_policy=%s)",
      (UseInsightsGating?"on":"off"), (UsePolicyGating?"on":"off"), g_policy_min_conf,
      (DefaultPolicyFallback?"on":"off"), (FallbackDemoOnly?"on":"off"), (FallbackWhenNoPolicy?"on":"off")
      );

   string panel = StringFormat(
      "DualEA Heartbeat\n%s tf=%d\nstrats=%d spread_pts=%.1f\n%s",
      _Symbol, tf, nstrats, spread_pts, gsum
      );
   Comment(panel);
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

 // --- Phase 5 advanced gating stubs (default-allow; telemetry wired in EvaluateAndMaybeExecute)
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

 // --- Explore cap log throttling and per-bar counters
  // Reset counters on a new bar and track first-occurrence logging per slice key
  datetime g_ecap_bar_time = 0;
  string   g_ecap_keys[];
  int      g_ecap_counts[];
  bool     g_ecap_printed[];

  // Ensure per-bar state resets when a new bar starts
  void ECapFlushSummaryIfNewBar()
    {
     datetime cur_bar = iTime(_Symbol, _Period, 0);
     if(cur_bar != g_ecap_bar_time)
       {
        g_ecap_bar_time = cur_bar;
        ArrayResize(g_ecap_keys, 0);
        ArrayResize(g_ecap_counts, 0);
        ArrayResize(g_ecap_printed, 0);
       }
    }

  // Increment cap count for a key. Returns true if this is the first occurrence this bar
  bool ECapIncrement(const string key)
    {
     int n = ArraySize(g_ecap_keys);
     for(int i=0;i<n;++i)
       {
        if(g_ecap_keys[i] == key)
          {
           g_ecap_counts[i]++;
           return (g_ecap_counts[i]==1);
          }
       }
     ArrayResize(g_ecap_keys, n+1);
     ArrayResize(g_ecap_counts, n+1);
     ArrayResize(g_ecap_printed, n+1);
     g_ecap_keys[n]     = key;
     g_ecap_counts[n]   = 1;
     g_ecap_printed[n]  = false;
     return true;
    }

  // Mark that we've already printed a message for this key in the current bar
  void ECapMarkPrinted(const string key)
    {
     int n = ArraySize(g_ecap_keys);
     for(int i=0;i<n;++i)
       {
        if(g_ecap_keys[i] == key)
          {
           g_ecap_printed[i] = true;
           return;
          }
       }
    }

 // Core evaluation loop with re-entrancy guard
 void EvaluateAndMaybeExecute(const bool from_timer=false)
   {
    if(g_eval_busy)
      {
       if(ShouldLog(LOG_DEBUG)) Print("Evaluate skipped: already running");
       return;
      }
    g_eval_busy = true;
    // Telemetry: rescoring triggered by timer
    if(from_timer && TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
      {
       int nstrats = (CheckPointer(g_strategies)!=POINTER_INVALID ? (int)g_strategies.Total() : 0);
       string details = StringFormat("n=%d spread=%.1f", nstrats, CurrentSpreadPoints());
       (*g_telemetry).LogEvent(_Symbol, (int)_Period, "sys", "p5_rescore", details);
      }
    // Iterate through each strategy
    if(CheckPointer(g_strategies)==POINTER_INVALID)
      {
       Print("Error: g_strategies not initialized; skipping evaluation.");
       g_eval_busy = false;
       return;
      }
    // Phase 6: compute current minute bucket once per evaluation (string to avoid overflow)
    MqlDateTime p6_dt; TimeToStruct(TimeCurrent(), p6_dt);
    string p6_minute_key = StringFormat("%04d%02d%02d%02d%02d", p6_dt.year, p6_dt.mon, p6_dt.day, p6_dt.hour, p6_dt.min);
    for(int i = 0; i < g_strategies.Total(); i++)
      {
       // Safely cast to the interface pointer
       IStrategy* strategy = (IStrategy*)g_strategies.At(i);
       if(CheckPointer(strategy) == POINTER_INVALID)
         {
          Print("Error: Could not cast strategy at index ", i);
          continue;
         }
       // Phase 6: per-strategy per-minute deduplication
       string p6_last_s = (*strategy).MetadataGet("p6_last_bucket", "");
       if(p6_last_s == p6_minute_key)
         {
          if(ShouldLog(LOG_DEBUG)) PrintFormat("[P6] dedup: skip %s minute=%s", (*strategy).Name(), p6_minute_key);
          continue;
         }
       (*strategy).MetadataSet("p6_last_bucket", p6_minute_key);
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
            // Shadow correlation-pruning gate
            if(NoConstraintsMode && P5_CorrPruneEnable)
              {
               string r_corr=""; bool ok_corr = P5_CorrPruneAllow(order, r_corr);
               (*g_telemetry).LogGatingShadow(order.strategy_name, _Symbol, (int)_Period, "p5_corr", ok_corr, r_corr, true);
              }
            // Shadow stability gate
            if(NoConstraintsMode && P5_StabilityGateEnable)
              {
               string r_stab=""; bool ok_stab = P5_StabilityAllow(order, r_stab);
               (*g_telemetry).LogGatingShadow(order.strategy_name, _Symbol, (int)_Period, "p5_stability", ok_stab, r_stab, true);
              }
            // Shadow MTF confirmation (bypassed in NoConstraintsMode)
            if(NoConstraintsMode && EnableMTFConfirmations && UseStrategySelector && CheckPointer(g_selector)!=POINTER_INVALID)
              {
               double s_mtf = (*g_selector).Score(_Symbol, MTFConfirmTF, (*strategy).Name());
               bool ok_mtf = (s_mtf >= MTFConfirmMinScore);
               string rmtf = StringFormat("tf=%s score=%.3f min=%.3f", EnumToString(MTFConfirmTF), s_mtf, MTFConfirmMinScore);
               (*g_telemetry).LogGatingShadow(order.strategy_name, _Symbol, (int)_Period, "p5_mtf", ok_mtf, rmtf, true);
              }
            // Shadow underperformance gate (recent overlays)
            if(NoConstraintsMode && UnderperfDisableEnabled && UseStrategySelector && CheckPointer(g_selector)!=POINTER_INVALID)
              {
              // Load recent overlays window for underperformance shadow check
              (*g_selector).EnsureRecentLoaded(UnderperfWindowDays);
              int rcnt=0; double rwr=0.0, ravgr=0.0, rpf=0.0;
              bool have_recent = (*g_selector).GetRecentMetrics(_Symbol, _Period, (*strategy).Name(), rcnt, rwr, ravgr, rpf);
              if(!have_recent)
                (*g_selector).GetBaselineMetrics(_Symbol, _Period, (*strategy).Name(), rcnt, rwr, ravgr, rpf);
              bool under = (*g_selector).IsUnderperforming(_Symbol, _Period, (*strategy).Name(), UnderperfMinPF, UnderperfMinWR, UnderperfMinExpR);
               string src = (have_recent? "recent":"baseline");
               string runp = StringFormat("src=%s cnt=%d wr=%.3f pf=%.3f exp=%.3f th_pf=%.2f th_wr=%.2f th_exp=%.2f", src, rcnt, rwr, rpf, ravgr, UnderperfMinPF, UnderperfMinWR, UnderperfMinExpR);
               (*g_telemetry).LogGatingShadow(order.strategy_name, _Symbol, (int)_Period, "p5_underperf", !under, runp, true);
              }
            // Shadow spread/session/risk gates
            if(NoConstraintsMode)
              {
               string rr=""; bool s_ok = SpreadAllowed(rr);
               (*g_telemetry).LogGatingShadow(order.strategy_name, _Symbol, (int)_Period, "spread", s_ok, (s_ok?"ok":rr), true);
               string rse=""; bool ses_ok = SessionAllowed(rse);
               (*g_telemetry).LogGatingShadow(order.strategy_name, _Symbol, (int)_Period, "session", ses_ok, (ses_ok?"ok":rse), true);
               string rr2=""; bool r_ok = RiskAllowed(rr2);
               (*g_telemetry).LogGatingShadow(order.strategy_name, _Symbol, (int)_Period, "risk", r_ok, (r_ok?"ok":rr2), true);
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
                     // Phase 6 latency: selector gate (explore cap)
                     if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID && from_timer && g_p6_scan_t0_ms>0)
                       {
                        uint dtms_sel_ec = (uint)(GetTickCount() - g_p6_scan_t0_ms);
                        (*g_telemetry).LogEvent(_Symbol, (int)_Period, (*strategy).Name(), "p6_latency", StringFormat("stage=gate_selector ms=%u", dtms_sel_ec));
                       }
                     continue;
                    }
                  }
                else
                  {
                   if(ShouldLog(LOG_INFO)) PrintFormat("Selector gate: blocked %s on %s/%d (score=%.3f)", (*strategy).Name(), _Symbol, (int)_Period, s);
                   if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                     (*g_telemetry).LogGating(_Symbol, (int)_Period, (*strategy).Name(), "selector", false, "score<=0");
                   // Phase 6 latency: selector gate (score<=0)
                   if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID && from_timer && g_p6_scan_t0_ms>0)
                     {
                      uint dtms_sel = (uint)(GetTickCount() - g_p6_scan_t0_ms);
                      (*g_telemetry).LogEvent(_Symbol, (int)_Period, (*strategy).Name(), "p6_latency", StringFormat("stage=gate_selector ms=%u", dtms_sel));
                     }
                   continue;
                  }
               }
            }
          // Phase 5: correlation pruning gate (before MTF confirm)
          if(!NoConstraintsMode && P5_CorrPruneEnable)
            {
             string r_corr="";
             if(!P5_CorrPruneAllow(order, r_corr))
               {
                if(ShouldLog(LOG_INFO)) PrintFormat("[P5] blocked %s on %s/%s reason=%s (corr_prune)", order.strategy_name, _Symbol, EnumToString(_Period), r_corr);
                if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                  (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "p5_corr", false, r_corr);
                // Phase 6 latency: correlation prune gate
                if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID && from_timer && g_p6_scan_t0_ms>0)
                  {
                   uint dtms_corr = (uint)(GetTickCount() - g_p6_scan_t0_ms);
                   (*g_telemetry).LogEvent(_Symbol, (int)_Period, order.strategy_name, "p6_latency", StringFormat("stage=gate_corr ms=%u", dtms_corr));
                  }
                continue;
               }
             else
               {
                if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                  (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "p5_corr", true, r_corr);
               }
            }
          // MTF confirmation gate (after selector, before other risk gates)
          if(!NoConstraintsMode && EnableMTFConfirmations)
            {
             if(!(UseStrategySelector && CheckPointer(g_selector)!=POINTER_INVALID))
               {
                if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                  (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "p5_mtf", true, "no_selector");
               }
             else
               {
                double s_htf = (*g_selector).Score(_Symbol, MTFConfirmTF, (*strategy).Name());
                if(s_htf < MTFConfirmMinScore)
                  {
                   string reason_mtf = StringFormat("tf=%s score=%.3f<thresh=%.3f", EnumToString(MTFConfirmTF), s_htf, MTFConfirmMinScore);
                   if(ShouldLog(LOG_INFO)) PrintFormat("GATE: blocked %s on %s/%s reason=p5_mtf (%s)", order.strategy_name, _Symbol, EnumToString(_Period), reason_mtf);
                   if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                     (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "p5_mtf", false, reason_mtf);
                   continue;
                  }
                else
                  {
                   if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                    {
                     string okmsg = StringFormat("tf=%s score=%.3f>=%.3f", EnumToString(MTFConfirmTF), s_htf, MTFConfirmMinScore);
                     (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "p5_mtf", true, okmsg);
                    }
                  }
               }
            }
          // Phase 5: stability gate (after MTF confirm, before underperformance)
          if(!NoConstraintsMode && P5_StabilityGateEnable)
            {
             string r_stab="";
             if(!P5_StabilityAllow(order, r_stab))
               {
                if(ShouldLog(LOG_INFO)) PrintFormat("[P5] blocked %s on %s/%s reason=%s (stability)", order.strategy_name, _Symbol, EnumToString(_Period), r_stab);
                if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                  (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "p5_stability", false, r_stab);
                // Phase 6 latency: stability gate
                if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID && from_timer && g_p6_scan_t0_ms>0)
                  {
                   uint dtms_stab = (uint)(GetTickCount() - g_p6_scan_t0_ms);
                   (*g_telemetry).LogEvent(_Symbol, (int)_Period, order.strategy_name, "p6_latency", StringFormat("stage=gate_stability ms=%u", dtms_stab));
                  }
                continue;
               }
             else
               {
                if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                  (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "p5_stability", true, r_stab);
               }
            }
          // Underperformance gate (after MTF confirm, before other risk/PM/insights)
          if(!NoConstraintsMode && UnderperfDisableEnabled)
            {
             if(!(UseStrategySelector && CheckPointer(g_selector)!=POINTER_INVALID))
               {
                if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                  (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "p5_underperf", true, "no_selector");
               }
             else
               {
                // Load recent overlays window for underperformance check
                (*g_selector).EnsureRecentLoaded(UnderperfWindowDays);
                int rcnt=0; double rwr=0.0, ravgr=0.0, rpf=0.0;
                bool have_recent = (*g_selector).GetRecentMetrics(_Symbol, _Period, (*strategy).Name(), rcnt, rwr, ravgr, rpf);
                if(!have_recent)
                  (*g_selector).GetBaselineMetrics(_Symbol, _Period, (*strategy).Name(), rcnt, rwr, ravgr, rpf);
                bool under = (*g_selector).IsUnderperforming(_Symbol, _Period, (*strategy).Name(), UnderperfMinPF, UnderperfMinWR, UnderperfMinExpR);
                string src = (have_recent? "recent":"baseline");
                string runp = StringFormat("src=%s cnt=%d wr=%.3f pf=%.3f exp=%.3f th_pf=%.2f th_wr=%.2f th_exp=%.2f", src, rcnt, rwr, rpf, ravgr, UnderperfMinPF, UnderperfMinWR, UnderperfMinExpR);
                if(under)
                  {
                   if(ShouldLog(LOG_INFO)) PrintFormat("GATE: blocked %s on %s/%s reason=underperf (%s)", order.strategy_name, _Symbol, EnumToString(_Period), runp);
                   if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                     (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "p5_underperf", false, runp);
                   // Phase 6 latency: underperformance gate
                   if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID && from_timer && g_p6_scan_t0_ms>0)
                     {
                      uint dtms_under = (uint)(GetTickCount() - g_p6_scan_t0_ms);
                      (*g_telemetry).LogEvent(_Symbol, (int)_Period, order.strategy_name, "p6_latency", StringFormat("stage=gate_underperf ms=%u", dtms_under));
                     }
                   if(UnderperfAutoDisable && CheckPointer(strategy)!=POINTER_INVALID)
                     {
                      (*strategy).SetEnabled(false);
                      // Set cooldown metadata for Phase 5 auto-disable
                      datetime until_ts = 0;
                      if(P5_AutoDisableCooldownMin>0)
                        until_ts = TimeCurrent() + (P5_AutoDisableCooldownMin*60);
                      (*strategy).MetadataSet("p5_disabled_until_ts", IntegerToString((long)until_ts));
                      string msg = runp;
                      if(until_ts>0) msg = msg + " until=" + TimeToString(until_ts, TIME_DATE|TIME_MINUTES);
                      if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                        (*g_telemetry).LogEvent(_Symbol, (int)_Period, order.strategy_name, "underperf_auto_disabled", msg);
                     }
                   continue;
                  }
                else
                  {
                   if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                     (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "p5_underperf", true, runp);
                  }
               }
            }
          // Position guard: block when total open positions reach limit
          if(MaxOpenPositions > 0 && PositionsTotal() >= MaxOpenPositions)
            {
             if(ShouldLog(LOG_INFO)) PrintFormat("EXEC: blocked %s on %s/%s due to MaxOpenPositions=%d (PositionsTotal=%d)", order.strategy_name, _Symbol, EnumToString(_Period), MaxOpenPositions, PositionsTotal());
             g_eval_busy = false;
             return;
            }
          // Spread cap
          if(!NoConstraintsMode)
            {
             string rs=""; if(!SpreadAllowed(rs))
               {
                if(ShouldLog(LOG_INFO)) PrintFormat("GATE: blocked %s on %s/%s reason=%s (spread=%.1f cap=%.1f)", order.strategy_name, _Symbol, EnumToString(_Period), rs, CurrentSpreadPoints(), SpreadMaxPoints);
                if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                  (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "spread", false, rs);
                g_eval_busy = false;
                return;
               }
             // Session cap
             string rse=""; if(!SessionAllowed(rse))
               {
                if(ShouldLog(LOG_INFO)) PrintFormat("GATE: blocked %s on %s/%s reason=%s (used=%d max=%d)", order.strategy_name, _Symbol, EnumToString(_Period), rse, CountNewTradesSince(g_session_start), SessionMaxTrades);
                if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                  (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "session", false, rse);
                g_eval_busy = false;
                return;
               }
             // Risk circuit breakers
             string rr=""; if(!RiskAllowed(rr))
               {
                if(ShouldLog(LOG_INFO)) PrintFormat("GATE: blocked %s on %s/%s reason=%s (eq=%.2f base=%.2f high=%.2f ml=%.2f)", order.strategy_name, _Symbol, EnumToString(_Period), rr, AccountInfoDouble(ACCOUNT_EQUITY), g_session_equity_start, g_equity_highwater, AccountInfoDouble(ACCOUNT_MARGIN_LEVEL));
                if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                  (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "risk", false, rr);
                g_eval_busy = false;
                return;
               }
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
                      // Phase 6 latency: insights gate (explore cap)
                      if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID && from_timer && g_p6_scan_t0_ms>0)
                        {
                         uint dtms_ig1 = (uint)(GetTickCount() - g_p6_scan_t0_ms);
                         (*g_telemetry).LogEvent(_Symbol, (int)_Period, order.strategy_name, "p6_latency", StringFormat("stage=gate_insights ms=%u", dtms_ig1));
                        }
                      g_eval_busy = false;
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
                      // Phase 6 latency: insights gate
                      if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID && from_timer && g_p6_scan_t0_ms>0)
                        {
                         uint dtms_ig2 = (uint)(GetTickCount() - g_p6_scan_t0_ms);
                         (*g_telemetry).LogEvent(_Symbol, (int)_Period, order.strategy_name, "p6_latency", StringFormat("stage=gate_insights ms=%u", dtms_ig2));
                        }
                     }
                   g_eval_busy = false;
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
          // Pre-execution PositionManager guards (optional)
          if(UsePositionManager && CheckPointer(g_position_manager)!=POINTER_INVALID)
            {
             // 1) Pre-trade exit checks on existing positions for this symbol/magic
             for(int pi=0; pi<PositionsTotal(); ++pi)
               {
                ulong t = PositionGetTicket(pi);
                if(t==0) continue;
                if(!PositionSelectByTicket(t)) continue;
                string psym2 = PositionGetString(POSITION_SYMBOL);
                if(psym2!=_Symbol) continue;
                long pmag2 = PositionGetInteger(POSITION_MAGIC);
                if(pmag2!=MagicNumber) continue;
                ulong ticket2 = (ulong)PositionGetInteger(POSITION_TICKET);
                double close_px2 = 0.0; string reason2 = "";
                if((*g_position_manager).CheckExitConditions(ticket2, close_px2, reason2))
                  {
                   if(ShouldLog(LOG_INFO)) PrintFormat("[PM] Pre-trade exit: closing ticket=%I64u reason=%s", ticket2, reason2);
                   if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                     (*g_telemetry).LogEvent(_Symbol, (int)_Period, order.strategy_name, "pm_exit_pretrade", StringFormat("ticket=%I64u reason=%s", ticket2, reason2));
                   (*g_position_manager).ClosePosition(ticket2, reason2);
                  }
               }
            }
          // Execute the trade
          // Apply policy-driven scaling if available
          if(UsePolicyGating && g_policy_loaded)
            {
             double ppol_exec = GetPolicyProb(order.strategy_name, _Symbol, _Period);
             if(ppol_exec>=0.0) ApplyPolicyScaling(order, _Symbol, _Period, ppol_exec);
            }
          // Correlation-adjusted sizing for new entries (post-policy scaling)
          if(UsePositionManager && PM_EnableCorrelationSizing && CheckPointer(g_position_manager)!=POINTER_INVALID)
            {
             double base_lots = order.lots;
             double corr_now = (*g_position_manager).GetPortfolioCorrelation(_Symbol);
             double adj_lots = (*g_position_manager).CalculateCorrelationAdjustedVolume(_Symbol, base_lots);
             if(adj_lots>0.0)
               {
                double lots_after = adj_lots;
                // Enforce floors to avoid over-dampening
                double floor_rel = base_lots * PM_CorrMinMult;
                double floor_abs = PM_CorrMinLots;
                double floor_all = MathMax(floor_rel, floor_abs);
                if(lots_after < floor_all)
                  {
                   double before_floor = lots_after;
                   lots_after = floor_all;
                   if(ShouldLog(LOG_INFO)) PrintFormat("[PM] Corr floor: raised %.4f -> %.4f (rel=%.4f abs=%.4f)", before_floor, lots_after, floor_rel, floor_abs);
                   if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                     (*g_telemetry).LogEvent(_Symbol, (int)_Period, order.strategy_name, "pm_corr_floor", StringFormat("corr=%.3f before=%.4f after=%.4f rel_floor=%.4f abs_floor=%.4f", corr_now, before_floor, lots_after, floor_rel, floor_abs));
                  }
                order.lots = lots_after;
                if(ShouldLog(LOG_INFO)) PrintFormat("[PM] Corr sizing: corr=%.3f lots %.4f -> %.4f", corr_now, base_lots, lots_after);
                if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                  (*g_telemetry).LogEvent(_Symbol, (int)_Period, order.strategy_name, "pm_corr_sizing", StringFormat("corr=%.3f lots_in=%.4f lots_out=%.4f", corr_now, base_lots, lots_after));
               }
             else if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
               {
                (*g_telemetry).LogEvent(_Symbol, (int)_Period, order.strategy_name, "pm_corr_sizing", StringFormat("corr=%.3f lots_in=%.4f lots_out=%.4f (no_change)", corr_now, base_lots, adj_lots));
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
                g_eval_busy = false;
                return;
               }
             // Session/day trade cap
             string r_se_exec="";
             if(!SessionAllowed(r_se_exec))
               {
                if(ShouldLog(LOG_INFO)) PrintFormat("[RISK4] blocked %s on %s/%s reason=%s (session)", order.strategy_name, _Symbol, EnumToString(_Period), r_se_exec);
                if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                  (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "risk4_session", false, r_se_exec);
                g_eval_busy = false;
                return;
               }
             // Equity/margin/consecutive losses
             string r_rk_exec="";
             if(!RiskAllowed(r_rk_exec))
               {
                if(ShouldLog(LOG_INFO)) PrintFormat("[RISK4] blocked %s on %s/%s reason=%s", order.strategy_name, _Symbol, EnumToString(_Period), r_rk_exec);
                if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                  (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "risk4", false, r_rk_exec);
                g_eval_busy = false;
                return;
               }
            }
          bool result = (*g_trade_manager).ExecuteOrder(order);
          if(result)
            {
             // Mark last trade placement time
             g_last_trade_placed = TimeCurrent();
             // Configure trailing on successful execution
             if(TrailEnabled)
               {
                // Configure trailing according to the strategy's order policy
                (*g_trade_manager).ConfigureTrailing(order);
               }
             // Event log
             (*g_kb).LogTrade(order.strategy_name, (int)(*g_trade_manager).ResultRetcode(), (*g_trade_manager).ResultDeal(), (*g_trade_manager).ResultOrder());
             // Telemetry: trade executed
             if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
               (*g_telemetry).LogTradeExecuted(order.strategy_name, _Symbol, (int)_Period, (int)(*g_trade_manager).ResultRetcode(), (*g_trade_manager).ResultDeal(), (*g_trade_manager).ResultOrder());
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
             rec.entry_price  = (*g_trade_manager).ResultPrice();
             rec.stop_loss    = order.stop_loss;
             rec.take_profit  = order.take_profit;
             rec.close_price  = 0.0;
             rec.profit       = 0.0;
             rec.strategy_id  = order.strategy_name;
             (*g_kb).WriteRecord(rec);
             // Stash pending mapping so we can attribute when the entry deal arrives
             ulong ord = (*g_trade_manager).ResultOrder();
             if(ord>0)
               {
                int n = ArraySize(g_pending_orders);
                ArrayResize(g_pending_orders, n+1); ArrayResize(g_pending_orders_strat, n+1);
                g_pending_orders[n] = ord; g_pending_orders_strat[n] = order.strategy_name;
               }
             ulong dl = (*g_trade_manager).ResultDeal();
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
                 for(int pi=0; pi<PositionsTotal(); ++pi)
                   {
                    ulong t = PositionGetTicket(pi);
                    if(t==0) continue;
                    if(!PositionSelectByTicket(t)) continue;
                    string psym = PositionGetString(POSITION_SYMBOL);
                    if(psym!=_Symbol) continue;
                    pos_id_immediate = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
                    break;
                   }
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
                  double entry_p = (*g_trade_manager).ResultPrice();
                  if(entry_p<=0)
                    {
                     // Fallback: resolve entry price by matching POSITION_IDENTIFIER among open positions
                     for(int pi=0; pi<PositionsTotal(); ++pi)
                       {
                        ulong t = PositionGetTicket(pi);
                        if(t==0) continue;
                        if(!PositionSelectByTicket(t)) continue;
                        if((ulong)PositionGetInteger(POSITION_IDENTIFIER)==pos_id_immediate)
                          {
                           entry_p = PositionGetDouble(POSITION_PRICE_OPEN);
                           break;
                          }
                       }
                    }
                  g_pos_entry_price[k]=entry_p;
                  g_pos_max_price[k]=entry_p; g_pos_min_price[k]=entry_p;
                  int ptype = POSITION_TYPE_BUY;
                  {
                   // Fallback: resolve position type by identifier
                   for(int pi=0; pi<PositionsTotal(); ++pi)
                     {
                      ulong t = PositionGetTicket(pi);
                      if(t==0) continue;
                      if(!PositionSelectByTicket(t)) continue;
                      if((ulong)PositionGetInteger(POSITION_IDENTIFIER)==pos_id_immediate)
                        {
                         ptype = (int)PositionGetInteger(POSITION_TYPE);
                         break;
                        }
                     }
                  }
                  g_pos_type[k]=ptype;
                  double init_risk = 0.0;
                  if(order.stop_loss>0 && entry_p>0)
                    init_risk = MathAbs((ptype==POSITION_TYPE_BUY? entry_p - order.stop_loss : order.stop_loss - entry_p));
                  if(init_risk<=0.0)
                    {
                     // Fallback: compute risk using current position SL/open by identifier
                     for(int pi=0; pi<PositionsTotal(); ++pi)
                       {
                        ulong t = PositionGetTicket(pi);
                        if(t==0) continue;
                        if(!PositionSelectByTicket(t)) continue;
                        if((ulong)PositionGetInteger(POSITION_IDENTIFIER)==pos_id_immediate)
                          {
                           double slc = PositionGetDouble(POSITION_SL);
                           double eop = PositionGetDouble(POSITION_PRICE_OPEN);
                           if(slc>0 && eop>0) init_risk = MathAbs((ptype==POSITION_TYPE_BUY? eop - slc : slc - eop));
                           break;
                          }
                       }
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
             PrintFormat("Trade executed by %s. Deal: %d, Order: %d", order.strategy_name, (*g_trade_manager).ResultDeal(), (*g_trade_manager).ResultOrder());
             g_eval_busy = false;
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
      g_eval_busy = false;
      }
   }

 void ScanStrategies(const bool telemetry_only=false)
  {
    static int last_minute_id = -1;
    MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
    int minute_id = dt.year*100000000 + dt.mon*1000000 + dt.day*10000 + dt.hour*100 + dt.min;
    if(minute_id == last_minute_id) return;
    last_minute_id = minute_id;
    if(telemetry_only && TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
      {
       int nstrats = (CheckPointer(g_strategies)!=POINTER_INVALID ? (int)g_strategies.Total() : 0);
       string details = StringFormat("n=%d spread=%.1f", nstrats, CurrentSpreadPoints());
       (*g_telemetry).LogEvent(_Symbol, (int)_Period, "sys", "scan", details);
      }
  }
  
  //+------------------------------------------------------------------+
  //| Expert initialization function                                   |
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

   // PositionManager: initialize and enable ATR volatility exit (behind flag)
  if(UsePositionManager && CheckPointer(g_position_manager)==POINTER_INVALID)
    {
     g_position_manager = new CPositionManager();
     if(CheckPointer(g_position_manager)!=POINTER_INVALID)
       {
        bool pm_ok = (*g_position_manager).InitializeSimple(_Symbol, TrailATRPeriod, TrailActivationPoints, TrailDistancePoints, TrailStepPoints);
        (*g_position_manager).SetMagicNumber(MagicNumber);
        // Apply tuning from inputs
        (*g_position_manager).SetAdaptiveSizing(PM_EnableAdaptiveSizing, PM_MinSizeMult, PM_MaxSizeMult);
        // Map integer to ScalingProfile enum (0=Aggressive,1=Moderate,2=Conservative)
        ScalingProfile sp = SCALING_MODERATE;
        if(PM_ScalingProfile<=0) sp = SCALING_AGGRESSIVE; else if(PM_ScalingProfile>=2) sp = SCALING_CONSERVATIVE; else sp = SCALING_MODERATE;
        (*g_position_manager).SetScalingProfile(sp);
        // Volatility exit
        (*g_position_manager).SetVolatilityExit(PM_EnableVolatilityExit, PM_VolatilityExitATRMult);
        // Dynamic risk caps
        (*g_position_manager).SetDynamicRisk(PM_EnableDynamicRiskCaps, PM_MaxDailyDDPct, PM_MaxPosRiskPct, PM_MaxPortfolioRiskPct, PM_RiskDecay);
        if(!pm_ok)
          {
           Print("[PM] InitializeSimple failed; continuing without PositionManager enhancements");
          }
        else if(ShouldLog(LOG_INFO))
          {
           PrintFormat("[PM] Initialized (adaptive=%s min=%.2f max=%.2f profile=%d vol_exit=%s atr_mult=%.2f dyn_risk=%s dd%%=%.2f pos%%=%.2f port%%=%.2f decay=%.2f)",
                      (PM_EnableAdaptiveSizing?"true":"false"), PM_MinSizeMult, PM_MaxSizeMult, PM_ScalingProfile,
                      (PM_EnableVolatilityExit?"true":"false"), PM_VolatilityExitATRMult,
                      (PM_EnableDynamicRiskCaps?"true":"false"), PM_MaxDailyDDPct, PM_MaxPosRiskPct, PM_MaxPortfolioRiskPct, PM_RiskDecay);
          }
       }
    }
  else if(!UsePositionManager && ShouldLog(LOG_DEBUG))
    {
     Print("[PM] Disabled by UsePositionManager=false");
    }

   // Initialize session/equity baselines
   EnsureSessionRollover();

   // Telemetry
   if(TelemetryEnabled && CheckPointer(g_telemetry)==POINTER_INVALID)
     {
      g_telemetry = new CTelemetry(TelemetryDir, TelemetryExperiment, TelemetryLevel, TelemetryBufferMax);
      if(CheckPointer(g_telemetry)!=POINTER_INVALID)
        (*g_telemetry).LogEvent(_Symbol, (int)_Period, "sys", "init", StringFormat("NoConstraintsMode=%s", (NoConstraintsMode?"true":"false")));
     }

   // Insights auto-build before selector/gating loads
   if(InsightsAutoBuild)
     {
      bool stale = Insights_IsStale(InsightsStaleHours);
      if(stale)
        {
         Insights_RebuildAndReload("init");
        }
     }

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
      // Telemetry: emit selector configuration summary at init
      if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
        {
         string details_cfg = StringFormat(
           "w_pf=%.3f w_exp=%.3f w_wr=%.3f w_dd=%.3f recency=%s days=%d alpha=%.3f strict=%s th_min_trades=%d th_min_wr=%.2f th_min_exp=%.2f th_min_pf=%.2f th_max_dd=%.2f insights=%s recent=%s",
           SelW_PF, SelW_Exp, SelW_WR, SelW_DD,
           (SelUseRecency?"true":"false"), SelRecentDays, SelRecAlpha,
           (SelStrictThresholds?"true":"false"),
           GateMinTrades, GateMinWinRate, GateMinExpectancyR, GateMinProfitFactor, GateMaxDrawdownR,
           (ok_ins?"ok":"fail"), (ok_rec?"ok":"skip/fail")
         );
         (*g_telemetry).LogEvent(_Symbol, (int)_Period, "sys", "p5_selector_cfg", details_cfg);
        }
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
   // Register per-asset strategies for this symbol/timeframe
   if(CheckPointer(g_strategies)!=POINTER_INVALID)
     {
      RegisterStrategiesForSymbol(g_strategies, _Symbol, (ENUM_TIMEFRAMES)_Period);
     }

  // Phase 6: prewarm indicator handles for low-latency scans
  if(CheckPointer(g_strategies)!=POINTER_INVALID)
    {
     for(int i=0;i<g_strategies.Total();++i)
       {
        IStrategy* strategy = (IStrategy*)g_strategies.At(i);
        if(CheckPointer(strategy)==POINTER_INVALID) continue;
        bool pw = (*strategy).PrewarmIndicators(_Symbol, (ENUM_TIMEFRAMES)_Period);
        if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID && pw)
          (*g_telemetry).LogEvent(_Symbol, (int)_Period, (*strategy).Name(), "p6_prewarm_init", "true");
       }
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

   // Load persistent exploration counters (weekly and daily)
  bool wk_ok = LoadExploreCounts();
  bool dy_ok = LoadExploreCountsDay();
  if(ShouldLog(LOG_INFO)) PrintFormat("Explore counters loaded: week=%s day=%s", (wk_ok?"ok":"fail"), (dy_ok?"ok":"fail"));
  // Load persistent consecutive loss counters (optional)
  if(P5_PersistLossCounters)
    {
     bool lc_ok = LoadLossCounters();
     if(ShouldLog(LOG_INFO)) PrintFormat("Loss counters loaded: %s", (lc_ok?"ok":"fail"));
    }
  else
    {
     if(ShouldLog(LOG_INFO)) Print("[P5] Persistent loss counters disabled");
    }

   // Timer: unify heartbeat and timer-scan
   {
    int sec = 0;
    if(HeartbeatEnabled && HeartbeatMinutes>0)
      {
       int hb = HeartbeatMinutes*60; if(hb<1) hb=1;
       sec = (sec==0? hb : MathMin(sec, hb));
      }
    if(TimerScanEnabled && TimerScanMinutes>0)
      {
       int ts = TimerScanMinutes*60; if(ts<1) ts=1;
       sec = (sec==0? ts : MathMin(sec, ts));
      }
    if(sec>0)
      {
       EventSetTimer(sec);
       if(HeartbeatEnabled)
         {
          LogHeartbeat();
          g_last_heartbeat = TimeCurrent();
         }
      }
   }
   // Mode banner: NoConstraintsMode disables all gating and caps
   if(NoConstraintsMode)
     {
      if(ShouldLog(LOG_INFO)) Print("Mode: NoConstraintsMode=true -> bypass trading hours, selector gating, insights gating, exploration caps (0=unlimited), and MaxOpenPositions");
     }
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
   if(CheckPointer(g_position_manager)!=POINTER_INVALID){ delete g_position_manager; g_position_manager=NULL; }
   if(CheckPointer(g_selector)!=POINTER_INVALID){ delete g_selector; g_selector=NULL; }
   if(CheckPointer(g_trade_manager)!=POINTER_INVALID){ delete g_trade_manager; g_trade_manager=NULL; }
   if(CheckPointer(g_features)!=POINTER_INVALID){ delete g_features; g_features=NULL; }
   if(CheckPointer(g_kb)!=POINTER_INVALID){ delete g_kb; g_kb=NULL; }
   if(HeartbeatEnabled || TimerScanEnabled) { EventKillTimer(); Comment(""); }
  }
//+------------------------------------------------------------------+
//| Timer event                                                       |
//+------------------------------------------------------------------+
  void OnTimer()
    {
     // Always allow policy reload checks on timer
     CheckPolicyReload();
     // Allow manual insights rebuild via signal file
     CheckInsightsReload();
     // Flush telemetry periodically regardless of heartbeat setting
     if(CheckPointer(g_telemetry)!=POINTER_INVALID)
        (*g_telemetry).Flush();
     // Auto re-enable strategies whose cooldown expired (optional)
     if(P5_AutoReenableOnTimer && CheckPointer(g_strategies)!=POINTER_INVALID)
       {
        for(int i=0; i<g_strategies.Total(); ++i)
          {
           IStrategy* strategy = (IStrategy*)g_strategies.At(i);
           if(CheckPointer(strategy)==POINTER_INVALID) continue;
           string sname = (*strategy).Name();
           string cd = (*strategy).MetadataGet("p5_disabled_until_ts", "");
           if(cd=="") continue;
           long until = (long)StringToInteger(cd);
           if(until>0 && until <= (long)TimeCurrent())
             {
              (*strategy).SetEnabled(true);
              (*strategy).MetadataSet("p5_disabled_until_ts", "");
              if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                (*g_telemetry).LogEvent(_Symbol, (int)_Period, sname, "p5_auto_reenabled", "expired_cooldown");
              if(ShouldLog(LOG_INFO)) PrintFormat("[P5] auto re-enabled %s on timer after cooldown expiry", sname);
             }
          }
       }
     // Dynamic indicator auto-tuning (per-strategy cadence)
     if(P5_AutoTuneEnabled && P5_AutoTuneEveryMin>0 && CheckPointer(g_strategies)!=POINTER_INVALID)
       {
        int minsec = P5_AutoTuneEveryMin*60;
        for(int i=0; i<g_strategies.Total(); ++i)
          {
           IStrategy* strategy = (IStrategy*)g_strategies.At(i);
           if(CheckPointer(strategy)==POINTER_INVALID) continue;
           string sname = (*strategy).Name();
           string last_ts_s = (*strategy).MetadataGet("p5_last_tune_ts", "0");
           long last_ts = (long)StringToInteger(last_ts_s);
           if(last_ts==0 || ((long)TimeCurrent()-last_ts) >= minsec)
             {
              bool changed = (*strategy).AutoTuneIndicators(_Symbol, _Period);
              (*strategy).MetadataSet("p5_last_tune_ts", IntegerToString((long)TimeCurrent()));
              if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                {
                 string payload = StringFormat("changed=%s", (changed?"true":"false"));
                 (*g_telemetry).LogEvent(_Symbol, (int)_Period, sname, "p5_auto_tune", payload);
                }
              if(ShouldLog(LOG_DEBUG)) PrintFormat("[P5] auto-tune %s changed=%s", sname, (changed?"true":"false"));
             }
          }
       }
     // Optionally check insights staleness on timer (throttled)
     if(InsightsAutoBuild && InsightsCheckOnTimer)
       {
        if(g_last_insights_check==0 || (TimeCurrent()-g_last_insights_check)>=300)
          {
           g_last_insights_check = TimeCurrent();
           // Safety guards: suppress rebuild during active trades or shortly after placement
           if(InsightsSuppressWhileTrading && HasActivePositionForThisEAMagic())
             {
              if(ShouldLog(LOG_DEBUG)) Print("Insights timer: skip rebuild due to active position for this EA");
             }
           else if(InsightsAfterTradeCooldownMin>0 && g_last_trade_placed>0 && (TimeCurrent() - g_last_trade_placed) < (InsightsAfterTradeCooldownMin*60))
             {
              if(ShouldLog(LOG_DEBUG)) PrintFormat("Insights timer: skip rebuild within %d min after trade", InsightsAfterTradeCooldownMin);
             }
           else if(InsightsRebuildCooldownMin>0 && g_last_insights_rebuild>0 && (TimeCurrent() - g_last_insights_rebuild) < (InsightsRebuildCooldownMin*60))
             {
              if(ShouldLog(LOG_DEBUG)) PrintFormat("Insights timer: skip rebuild within cooldown %d min", InsightsRebuildCooldownMin);
             }
           else if(Insights_IsStale(InsightsStaleHours))
             {
              Insights_RebuildAndReload("timer");
             }
           }
       }
    // Heartbeat cadence (non-blocking)
    if(HeartbeatEnabled && HeartbeatMinutes>0)
      {
       if(g_last_heartbeat==0 || (TimeCurrent()-g_last_heartbeat) >= (HeartbeatMinutes*60))
         {
          LogHeartbeat();
          g_last_heartbeat = TimeCurrent();
         }
      }
    // Parity scan (telemetry only, per-minute dedup)
    ScanStrategies(true);
    // Timer-based evaluation scan cadence
    if(TimerScanEnabled && TimerScanMinutes>0)
      {
       if(g_last_timer_scan==0 || (TimeCurrent()-g_last_timer_scan) >= (TimerScanMinutes*60))
         {
          if(TimerScanVerbose && ShouldLog(LOG_INFO)) Print("TimerScan: triggering EvaluateAndMaybeExecute()");
          // Phase 6: mark scan start for latency telemetry
          g_p6_scan_t0_ms = GetTickCount();
          if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
            {
             int nstrats2 = (CheckPointer(g_strategies)!=POINTER_INVALID ? (int)g_strategies.Total() : 0);
             string d2 = StringFormat("n=%d spread=%.1f", nstrats2, CurrentSpreadPoints());
             (*g_telemetry).LogEvent(_Symbol, (int)_Period, "sys", "p6_scan_start", d2);
            }
          // Phase 6: prewarm indicators before timer-scan evaluation
          if(CheckPointer(g_strategies)!=POINTER_INVALID)
            {
             for(int i=0; i<g_strategies.Total(); ++i)
               {
                IStrategy* strategy = (IStrategy*)g_strategies.At(i);
                if(CheckPointer(strategy)==POINTER_INVALID) continue;
                (*strategy).PrewarmIndicators(_Symbol, (ENUM_TIMEFRAMES)_Period);
               }
            }
          EvaluateAndMaybeExecute(true);
          // Reset scan start timestamp
          g_p6_scan_t0_ms = 0;
          g_last_timer_scan = TimeCurrent();
         }
      }
    }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
 void OnTick()
   {
    // Runtime policy reload support
    CheckPolicyReload();
    // Update session/equity trackers
    EnsureSessionRollover();
    double _eq = AccountInfoDouble(ACCOUNT_EQUITY); if(_eq>g_equity_highwater) g_equity_highwater=_eq;
    // Always update trailing stops for open positions managed by our magic number
    if(CheckPointer(g_trade_manager)!=POINTER_INVALID)
      {
       (*g_trade_manager).UpdateTrailingStops();
      }
    // Optional time-of-day trading hours gate
    if(!NoConstraintsMode && UseTradingHours)
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
    // Update MFE/MAE extremes for active positions
    int pos_total = PositionsTotal();
    for(int i=0; i<pos_total; ++i)
      {
       ulong t = PositionGetTicket(i);
       if(t==0) continue;
       if(!PositionSelectByTicket(t)) continue;
       string psym = PositionGetString(POSITION_SYMBOL);
       long   pmag = PositionGetInteger(POSITION_MAGIC);
       if(psym!=_Symbol || pmag!=MagicNumber) continue;
       ulong  pid  = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
       double pcur = PositionGetDouble(POSITION_PRICE_CURRENT);
       // find index in tracking arrays
       int idx = -1;
       for(int t=0; t<ArraySize(g_pos_ids); ++t) { if(g_pos_ids[t]==pid) { idx=t; break; } }
       if(idx<0) continue;
       if(pcur>g_pos_max_price[idx]) g_pos_max_price[idx]=pcur;
       if(pcur<g_pos_min_price[idx]) g_pos_min_price[idx]=pcur;
      }
    // Volatility (ATR) exit checks via PositionManager
    if(CheckPointer(g_position_manager)!=POINTER_INVALID)
      {
       for(int i=0; i<PositionsTotal(); ++i)
         {
          ulong t = PositionGetTicket(i);
          if(t==0) continue;
          if(!PositionSelectByTicket(t)) continue;
          string psym2 = PositionGetString(POSITION_SYMBOL);
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
    // Detect closed positions and log outcomes
    for(int i=0; i<ArraySize(g_pos_ids); )
      {
       ulong pid = g_pos_ids[i];
       // If position is no longer open, attempt to log its closure
       if(!IsPositionOpenByIdentifier(pid))
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
             continue; // do not increment i, array was compacted
            }
         }
       ++i;
      }
    // Strategy evaluation (guarded)
   if(CheckPointer(g_strategies)==POINTER_INVALID)
     {
      Print("Error: g_strategies not initialized; skipping tick.");
      return;
     }
   // Evaluate strategies centrally (re-entrancy guarded)
   EvaluateAndMaybeExecute(false);
  }
//+------------------------------------------------------------------+
//| EvaluateAndMaybeExecute() function                                |
//+------------------------------------------------------------------+
void EvaluateAndMaybeExecute_DUP_REMOVED(const bool from_timer=false)
  {
   if(g_eval_busy) return;
   g_eval_busy = true;
   // Iterate through each strategy
   for(int i = 0; i < g_strategies.Total(); i++)
     {
      // Safely cast to the interface pointer
      IStrategy* strategy = (IStrategy*)g_strategies.At(i);
      if(CheckPointer(strategy) == POINTER_INVALID)
        {
         Print("Error: Could not cast strategy at index ", i);
         continue;
        }
      // Phase 5: enforce auto-disable cooldown and optional auto re-enable
      string strat_name = (*strategy).Name();
      string cd_ts = (*strategy).MetadataGet("p5_disabled_until_ts", "");
      bool   s_enabled = (*strategy).Enabled();
      if(cd_ts!="" || !s_enabled)
        {
         long until = 0;
         if(cd_ts!="") until = (long)StringToInteger(cd_ts);
         // If still within cooldown or strategy is disabled without expiry, gate it
         if((until>0 && until > (long)TimeCurrent()) || (!s_enabled && until==0))
           {
            string rcd = (until>0 ? StringFormat("cooldown_until=%s", TimeToString((datetime)until, TIME_DATE|TIME_MINUTES)) : "disabled");
            if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
              (*g_telemetry).LogGating(_Symbol, (int)_Period, strat_name, "p5_cooldown", false, rcd);
            if(ShouldLog(LOG_DEBUG)) PrintFormat("[P5] cooldown gate: skip %s reason=%s", strat_name, rcd);
            continue;
           }
         // Cooldown expired -> optionally auto re-enable on timer-driven scans
         if(until>0 && until <= (long)TimeCurrent())
           {
            if(from_timer && P5_AutoReenableOnTimer)
              {
               (*strategy).SetEnabled(true);
               (*strategy).MetadataSet("p5_disabled_until_ts", "");
               if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                 (*g_telemetry).LogEvent(_Symbol, (int)_Period, strat_name, "p5_auto_reenabled", "expired_cooldown");
               if(ShouldLog(LOG_INFO)) PrintFormat("[P5] auto re-enabled %s after cooldown expiry", strat_name);
              }
           }
        }
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
            // Shadow spread/session/risk gates
            if(NoConstraintsMode)
              {
               string rr=""; bool s_ok = SpreadAllowed(rr);
               (*g_telemetry).LogGatingShadow(order.strategy_name, _Symbol, (int)_Period, "spread", s_ok, (s_ok?"ok":rr), true);
               bool ses_ok = SessionAllowed(rr);
               (*g_telemetry).LogGatingShadow(order.strategy_name, _Symbol, (int)_Period, "session", ses_ok, (ses_ok?"ok":rr), true);
               string rr2=""; bool r_ok = RiskAllowed(rr2);
               (*g_telemetry).LogGatingShadow(order.strategy_name, _Symbol, (int)_Period, "risk", r_ok, (r_ok?"ok":rr2), true);
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
            g_eval_busy = false;
            return;
           }
         // Spread cap
         if(!NoConstraintsMode)
           {
            string rs=""; if(!SpreadAllowed(rs))
              {
               if(ShouldLog(LOG_INFO)) PrintFormat("GATE: blocked %s on %s/%s reason=%s (spread=%.1f cap=%.1f)", order.strategy_name, _Symbol, EnumToString(_Period), rs, CurrentSpreadPoints(), SpreadMaxPoints);
               if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                 (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "spread", false, rs);
               // Phase 6 latency: spread gate
               if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID && from_timer && g_p6_scan_t0_ms>0)
                 {
                  uint dtms_sp = (uint)(GetTickCount() - g_p6_scan_t0_ms);
                  (*g_telemetry).LogEvent(_Symbol, (int)_Period, order.strategy_name, "p6_latency", StringFormat("stage=gate_spread ms=%u", dtms_sp));
                 }
               g_eval_busy = false;
               return;
              }
            // Session cap
            string rse=""; if(!SessionAllowed(rse))
              {
               if(ShouldLog(LOG_INFO)) PrintFormat("GATE: blocked %s on %s/%s reason=%s (used=%d max=%d)", order.strategy_name, _Symbol, EnumToString(_Period), rse, CountNewTradesSince(g_session_start), SessionMaxTrades);
               if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                 (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "session", false, rse);
               // Phase 6 latency: session gate
               if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID && from_timer && g_p6_scan_t0_ms>0)
                 {
                  uint dtms_se = (uint)(GetTickCount() - g_p6_scan_t0_ms);
                  (*g_telemetry).LogEvent(_Symbol, (int)_Period, order.strategy_name, "p6_latency", StringFormat("stage=gate_session ms=%u", dtms_se));
                 }
               g_eval_busy = false;
               return;
              }
            // Risk circuit breakers
            string rr=""; if(!RiskAllowed(rr))
              {
               if(ShouldLog(LOG_INFO)) PrintFormat("GATE: blocked %s on %s/%s reason=%s (eq=%.2f base=%.2f high=%.2f ml=%.2f)", order.strategy_name, _Symbol, EnumToString(_Period), rr, AccountInfoDouble(ACCOUNT_EQUITY), g_session_equity_start, g_equity_highwater, AccountInfoDouble(ACCOUNT_MARGIN_LEVEL));
               if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
                 (*g_telemetry).LogGating(_Symbol, (int)_Period, order.strategy_name, "risk", false, rr);
               // Phase 6 latency: risk gate
               if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID && from_timer && g_p6_scan_t0_ms>0)
                 {
                  uint dtms_rk = (uint)(GetTickCount() - g_p6_scan_t0_ms);
                  (*g_telemetry).LogEvent(_Symbol, (int)_Period, order.strategy_name, "p6_latency", StringFormat("stage=gate_risk ms=%u", dtms_rk));
                 }
               g_eval_busy = false;
               return;
              }
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
                      g_eval_busy = false;
                      return;
                     }
                  }
               }
            }
          // Execute the trade
          // Apply policy-driven scaling if available
          if(UsePolicyGating && g_policy_loaded)
            {
             double ppol_exec = GetPolicyProb(order.strategy_name, _Symbol, _Period);
             if(ppol_exec>=0.0) ApplyPolicyScaling(order, _Symbol, _Period, ppol_exec);
            }
          bool result = (*g_trade_manager).ExecuteOrder(order);
          if(result)
            {
             // Configure trailing on successful execution
             if(TrailEnabled)
               {
                // Configure trailing according to the strategy's order policy
                (*g_trade_manager).ConfigureTrailing(order);
               }
             // Event log
             (*g_kb).LogTrade(order.strategy_name, (int)(*g_trade_manager).ResultRetcode(), (*g_trade_manager).ResultDeal(), (*g_trade_manager).ResultOrder());
             // Telemetry: trade executed
             if(TelemetryEnabled && CheckPointer(g_telemetry)!=POINTER_INVALID)
               (*g_telemetry).LogTradeExecuted(order.strategy_name, _Symbol, (int)_Period, (int)(*g_trade_manager).ResultRetcode(), (*g_trade_manager).ResultDeal(), (*g_trade_manager).ResultOrder());
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
             rec.entry_price  = (*g_trade_manager).ResultPrice();
             rec.stop_loss    = order.stop_loss;
             rec.take_profit  = order.take_profit;
             rec.close_price  = 0.0;
             rec.profit       = 0.0;
             rec.strategy_id  = order.strategy_name;
             (*g_kb).WriteRecord(rec);
             // Stash pending mapping so we can attribute when the entry deal arrives
             ulong ord = (*g_trade_manager).ResultOrder();
             if(ord>0)
               {
                int n = ArraySize(g_pending_orders);
                ArrayResize(g_pending_orders, n+1); ArrayResize(g_pending_orders_strat, n+1);
                g_pending_orders[n] = ord; g_pending_orders_strat[n] = order.strategy_name;
               }
             ulong dl = (*g_trade_manager).ResultDeal();
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
                 for(int pi=0; pi<PositionsTotal(); ++pi)
                   {
                    ulong t = PositionGetTicket(pi);
                    if(t==0) continue;
                    if(!PositionSelectByTicket(t)) continue;
                    string psym = PositionGetString(POSITION_SYMBOL);
                    if(psym!=_Symbol) continue;
                    pos_id_immediate = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
                    break;
                   }
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
                  double entry_p = (*g_trade_manager).ResultPrice();
                  if(entry_p<=0)
                    {
                     // Fallback: resolve entry price by matching POSITION_IDENTIFIER among open positions
                     for(int pi=0; pi<PositionsTotal(); ++pi)
                       {
                        ulong t = PositionGetTicket(pi);
                        if(t==0) continue;
                        if(!PositionSelectByTicket(t)) continue;
                        if((ulong)PositionGetInteger(POSITION_IDENTIFIER)==pos_id_immediate)
                          {
                           entry_p = PositionGetDouble(POSITION_PRICE_OPEN);
                           break;
                          }
                       }
                    }
                  g_pos_entry_price[k]=entry_p;
                  g_pos_max_price[k]=entry_p; g_pos_min_price[k]=entry_p;
                  int ptype = POSITION_TYPE_BUY;
                  {
                   // Fallback: resolve position type by identifier
                  for(int pi=0; pi<PositionsTotal(); ++pi)
                    {
                     ulong t = PositionGetTicket(pi);
                     if(t==0) continue;
                     if(!PositionSelectByTicket(t)) continue;
                     ulong pos_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
                     if(pos_id==pos_id_immediate)
                       {
                        ptype = (int)PositionGetInteger(POSITION_TYPE);
                        break;
                       }
                    }
                  }
                  g_pos_type[k]=ptype;
                  double init_risk = 0.0;
                  if(order.stop_loss>0 && entry_p>0)
                    init_risk = MathAbs((ptype==POSITION_TYPE_BUY? entry_p - order.stop_loss : order.stop_loss - entry_p));
                  if(init_risk<=0.0)
                    {
                     // Fallback: compute risk using current position SL/open by identifier
                     for(int pi=0; pi<PositionsTotal(); ++pi)
                       {
                        ulong t = PositionGetTicket(pi);
                        if(t==0) continue;
                        if(!PositionSelectByTicket(t)) continue;
                        if((ulong)PositionGetInteger(POSITION_IDENTIFIER)==pos_id_immediate)
                          {
                           double slc = PositionGetDouble(POSITION_SL);
                           double eop = PositionGetDouble(POSITION_PRICE_OPEN);
                           if(slc>0 && eop>0) init_risk = MathAbs((ptype==POSITION_TYPE_BUY? eop - slc : slc - eop));
                           break;
                          }
                       }
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
             PrintFormat("Trade executed by %s. Deal: %d, Order: %d", order.strategy_name, (*g_trade_manager).ResultDeal(), (*g_trade_manager).ResultOrder());
             g_eval_busy = false;
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
             g_eval_busy = false;
            }
         }
      }
    g_eval_busy = false;
    }

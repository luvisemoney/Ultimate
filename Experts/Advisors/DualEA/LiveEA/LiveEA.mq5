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
#include "..\Include\Strategies\BollAveragesStrategy.mqh"
#include "..\\Include\\Strategies\\MeanReversionBBStrategy.mqh"
// Advanced/verified strategies
#include "..\\Include\\Strategies\\SuperTrendADXKamaStrategy.mqh"
#include "..\\Include\\Strategies\\RSI2BBReversionStrategy.mqh"
#include "..\\Include\\Strategies\\DonchianATRBreakoutStrategy.mqh"
// Strategy selector
#include "..\\Include\\StrategySelector.mqh"
// Shared insights loader (DRY parsing across EAs)
#include "..\\Include\\InsightsLoader.mqh"

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

// --- Risk/Position limits
input int    MaxOpenPositions = 0; // 0=unlimited; total simultaneous positions across account

// --- Helper: compute R multiple strictly in price units
double ComputeRMultiple(const double entry_price, const double close_price, const double init_risk_price, const int pos_type)
  {
   if(init_risk_price<=0.0 || entry_price<=0.0 || close_price<=0.0)
      return 0.0;
   double move = (pos_type==POSITION_TYPE_SELL ? (entry_price - close_price) : (close_price - entry_price));
   double r = move / init_risk_price;
   if(MathAbs(r) > 100.0)
     {
      if(ShouldLog(LOG_DEBUG))
         PrintFormat("[R-MULT ALERT] abs(R)=%.2f entry=%.5f close=%.5f initR=%.8f type=%s", r, entry_price, close_price, init_risk_price, (pos_type==POSITION_TYPE_SELL?"SELL":"BUY"));
     }
   return r;
  }

// --- String trim helper (returns a trimmed copy)
string TrimCopy(string s)
  {
   StringTrimLeft(s);
   StringTrimRight(s);
   return s;
  }

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

// --- Globals
CKnowledgeBase*         g_kb = NULL;
CTradeManager*          g_trade_manager = NULL;
CArrayObj*              g_strategies; // Array to hold all strategy objects
CFeaturesKB*            g_features = NULL; // Features logger
CTelemetry*             g_telemetry = NULL; // Telemetry logger
// Strategy selector
CStrategySelector*       g_selector = NULL;
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
      string k = FileReadString(h);
      if(k=="" && FileIsEnding(h)) break;
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
   if(CheckPointer(g_selector)!=POINTER_INVALID)
     {
      bool sel_ok = (*g_selector).Load();
      if(ShouldLog(LOG_INFO)) PrintFormat("Selector insights reload after build: %s", (sel_ok?"ok":"fail"));
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

// Insights maintenance state
datetime                g_last_insights_check = 0;

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

   // Telemetry
   if(TelemetryEnabled && CheckPointer(g_telemetry)==POINTER_INVALID)
     {
      g_telemetry = new CTelemetry(TelemetryDir, TelemetryExperiment, TelemetryLevel, TelemetryBufferMax);
      if(CheckPointer(g_telemetry)!=POINTER_INVALID)
        (*g_telemetry).LogEvent(_Symbol, (int)_Period, "sys", "init", StringFormat("NoConstraints=%s", (NoConstraintsMode?"true":"false")));
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
      CObject* s1 = (CObject*)new CSuperTrendADXKamaStrategy(_Symbol, (ENUM_TIMEFRAMES)_Period);
      g_strategies.Add(s1);
      CObject* s2 = (CObject*)new CRSI2BBReversionStrategy(_Symbol, (ENUM_TIMEFRAMES)_Period);
      g_strategies.Add(s2);
      CObject* s3 = (CObject*)new CDonchianATRBreakoutStrategy(_Symbol, (ENUM_TIMEFRAMES)_Period);
      g_strategies.Add(s3);
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
   if(CheckPointer(g_selector)!=POINTER_INVALID){ delete g_selector; g_selector=NULL; }
   if(CheckPointer(g_trade_manager)!=POINTER_INVALID){ delete g_trade_manager; g_trade_manager=NULL; }
   if(CheckPointer(g_features)!=POINTER_INVALID){ delete g_features; g_features=NULL; }
   if(CheckPointer(g_kb)!=POINTER_INVALID){ delete g_kb; g_kb=NULL; }
   if(HeartbeatEnabled) { EventKillTimer(); Comment(""); }
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
     // Optionally check insights staleness on timer (throttled)
     if(InsightsAutoBuild && InsightsCheckOnTimer)
       {
        if(g_last_insights_check==0 || (TimeCurrent()-g_last_insights_check)>=300)
          {
           g_last_insights_check = TimeCurrent();
           if(Insights_IsStale(InsightsStaleHours))
             {
              Insights_RebuildAndReload("timer");
             }
          }
       }
     if(!HeartbeatEnabled || HeartbeatMinutes<=0) return;
     LogHeartbeat();
    }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
 void OnTick()
   {
    // Runtime policy reload support
    CheckPolicyReload();
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
       string psym = PositionGetSymbol(i);
       if(psym==NULL || psym=="") continue;
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
    // Iterate through each strategy
    if(CheckPointer(g_strategies)==POINTER_INVALID)
      {
       Print("Error: g_strategies not initialized; skipping tick.");
       return;
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
                  double entry_p = (*g_trade_manager).ResultPrice();
                  if(entry_p<=0)
                    {
                     // Fallback: resolve entry price by matching POSITION_IDENTIFIER among open positions
                     for(int pi=0; pi<PositionsTotal(); ++pi)
                       {
                        string _sym = PositionGetSymbol(pi);
                        if(_sym==NULL || _sym=="") continue;
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
                      string _sym = PositionGetSymbol(pi);
                      if(_sym==NULL || _sym=="") continue;
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
                        string _sym = PositionGetSymbol(pi);
                        if(_sym==NULL || _sym=="") continue;
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

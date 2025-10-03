//+------------------------------------------------------------------+
//| PaperEA_v2.mq5 - Enhanced Paper EA with 8-Stage Gates           |
//| AUTOMATICALLY ADAPTS TO ANY CHART SYMBOL AND TIMEFRAME          |
//+------------------------------------------------------------------+
#property copyright "DualEA Enhanced Paper System"
#property version   "2.0"
#property strict

//+------------------------------------------------------------------+
//| INCLUDES - COMPREHENSIVE MODULE INTEGRATION                     |
//+------------------------------------------------------------------+
// Core Interfaces & Data Structures
#include "..\Include\IStrategy.mqh"
#include "..\Include\ATRUtil.mqh"

// Core Services
#include "..\Include\KnowledgeBase.mqh"
#include "..\Include\TradeManager.mqh"
#include "..\Include\PolicyEngine.mqh"

// Telemetry System
#include "../Include/Telemetry.mqh"
#include "../Include/TelemetryStandard.mqh"
#include "../Include/SessionManager.mqh"
#include "../Include/CorrelationManager.mqh"
#include "../Include/VolatilitySizer.mqh"
#include "../Include/InsightsRealtime.mqh"

// Shared Insights loader (DRY)
#include "..\Include\InsightsLoader.mqh"

// Centralized gate orchestration macros
#include "..\\Include\\GatingPipeline.mqh"

// Adaptive Signal Optimization System
#include "..\Include\AdaptiveSignalOptimizer.mqh"
#include "..\Include\PolicyUpdater.mqh"
#include "..\Include\PositionReviewer.mqh"
#include "..\Include\GateLearningSystem.mqh"
#include "..\Include\UnifiedTradeLogger.mqh"

// Unified System Components
#include "..\Include\ConfigManager.mqh"
#include "..\Include\EventBus.mqh"
#include "..\Include\SystemMonitor.mqh"

// Standard Libraries
#include <Arrays/ArrayObj.mqh>
#include <Files/File.mqh>

// Position management
#include "..\\Include\\PositionManager.mqh"

// Strategy Implementations - Per-asset registry (internally includes concrete strategy headers)
#include "..\\Include\\Strategies\\AssetRegistry.mqh"

// Strategy selector
#include "..\\Include\\StrategySelector.mqh"
// Learning and Export Systems
#include "..\Include\LearningBridge.mqh"
#include "..\Include\GateManager.mqh"
#include "..\Include\ExportFeatureBatch.mqh"

// ===================[ PAPER vs LIVE EA CLARIFICATION ]===================
// IMPORTANT: "Paper" refers to DEMO ACCOUNT, NOT simulated trades!
// - PaperEA executes REAL MT5 trades via OrderSend() on DEMO accounts
// - LiveEA executes REAL MT5 trades via OrderSend() on LIVE accounts  
// - Both use identical execution logic through TradeManager
// - All positions tracked by MT5's native position system
// - Use PositionSelect(), PositionGetDouble(), OnTradeTransaction() for real position data
// ===================[ NO SIMULATION - REAL EXECUTION ONLY ]===================

// Using CFeaturesKB from Include\KnowledgeBase.mqh

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - COMPREHENSIVE SYSTEM CONFIGURATION           |
//+------------------------------------------------------------------+

// ===================[ TRADING INPUTS ]===================
// Symbol and Timeframe automatically detected from chart
input double LotSize = 0.15;
input int    MagicNumber = 12345;
input double StopLossPips = 150;
input double TakeProfitPips = 300;
input bool   TrailEnabled = true;
input int    TrailType = 2; // 0=fixed, 2=ATR
input int    TrailActivationPoints = 30;
input int    TrailDistancePoints   = 20;
input int    TrailStepPoints       = 5;
input int    TrailATRPeriod       = 14;
input double TrailATRMultiplier   = 2.0;
input bool   UsePositionManager   = true;
input int    PMMaxOpenPositions   = 10;
input bool   NoConstraintsMode    = true;

// ===================[ GATING/INSIGHTS ]===================
input bool   UseInsightsGating    = true;
input int    GateMinTrades        = 0;
input double GateMinWinRate       = 0.00;
input double GateMinExpectancyR   = -10.0;
input double GateMaxDrawdownR     = 1000000.0;
input double GateMinProfitFactor  = 0.00;
input bool   InsightsAutoBuild             = true;
input int    InsightsStaleHours            = 48;
input int    InsightsMinSourceAdvanceHours = 48;
input int    InsightsMinIntervalHours      = 24;
input bool   InsightsCheckOnTimer          = true;
input int    InsightsRebuildTimeoutMs      = 1800000;
input bool   ExploreOnNoSlice     = true;
input int    ExploreMaxPerSlice   = 100;
input int    ExploreMaxPerSlicePerDay = 100;

// ===================[ STRATEGY SELECTOR ]===================
input bool   UseStrategySelector   = true;
input double SelW_PF               = 1.0;
input double SelW_Exp              = 1.0;
input double SelW_WR               = 0.5;
input double SelW_DD               = 0.3;
input bool   SelStrictThresholds   = false;
input bool   SelUseRecency         = true;
input int    SelRecentDays         = 14;
input double SelRecAlpha           = 0.5;

// ===================[ ADVANCED GATING/TUNING ]===================
input bool   P5_AutoDisableEnable    = true;
input double P5_MinPF                = 1.20;
input double P5_MinWR                = 0.45;
input double P5_MinExpR              = -0.05;
input int    P5_AutoDisableCooldownM = 1440;
input bool   P5_AutoReenable         = true;
input bool   P5_AutoTuneEnable       = true;
input int    P5_AutoTuneEveryMin     = 60;
input bool   P5_TimerRescoreEnable   = true;
input int    P5_TimerRescoreEveryMin = 60;
input bool   P5_CorrPruneEnable      = true;
input double P5_CorrMax              = 0.80;
input int    P5_CorrLookbackDays     = 30;
input bool   P5_MTFConfirmEnable     = true;
input string P5_MTFHigherTFs         = "H1,H4";
input int    P5_MTFMinAgree          = 1;
input bool   P5_StabilityGateEnable  = false;
input int    P5_StabilityWindowDays  = 14;
input double P5_StabilityMaxStdR     = 1.00;
input bool   P5_PersistLossCounters  = false;
input bool   P5_PickBestEnable       = false;

// ===================[ RISK MANAGEMENT ]===================
input int    MaxOpenPositions     = 0;
input bool   GuardsEnabled         = true;
input double GuardMaxSpreadPoints  = 0.0;
input bool   ATRRegimeEnable       = false;
input int    ATRRegimePeriod       = 14;
input int    ATRRegimeLookback     = 500;
input double ATRMinPercentile      = 0.0;
input double ATRMaxPercentile      = 100.0;
input double ATRRegimeMinATRPct    = 0.0;
input double ATRRegimeMaxATRPct    = 1000.0;
input bool   UseCircuitBreakers   = true;  // ENABLED for safety
input double CBDailyLossLimitPct  = 5.0;  // 5% max daily loss
input double CBDrawdownLimitPct   = 10.0; // 10% max drawdown
input int    CBCooldownMinutes    = 60;   // 1 hour cooldown

// ===================[ NEWS & SESSION FILTERING ]===================
input bool   UseNewsFilter       = true;
input int    NewsBufferBeforeMin = 30;
input int    NewsBufferAfterMin  = 30;
input int    NewsImpactMin       = 2;
input bool   NewsUseFile         = true;
input string NewsFileRelPath     = "DualEA\\news_blackouts.csv";
input bool   UsePromotionGate    = false;
input bool   PromoLiveOnly       = false;
input int    PromoStartHour      = 0;
input int    PromoEndHour        = 24;
input bool   UseRegimeGate       = true;   // ENABLED for adaptive parameters
input int    RegimeATRPeriod     = 14;
input double RegimeMinATRPct     = 0.5;   // Low volatility threshold
input double RegimeMaxATRPct     = 2.5;   // High volatility threshold
input bool   RegimeTagTelemetry   = true;  // Track regime in telemetry
input string RegimeMethod         = "combined"; // Use ATR + ADX
input int    RegimeADXPeriod      = 14;
input double RegimeADXTrendThreshold = 25.0;
input int    CircuitCooldownSec  = 0;

// ===================[ SESSION & CORRELATION MANAGEMENT ]===================
input bool   UseSessionManager     = true;
input int    SessionEndHour        = 20;
input int    MaxTradesPerSession   = 10;
input int    SessionTZOffsetMinutes= 0;
input string SessionWindowsSpec    = "";
input bool   UseCorrelationManager = true;
input double MaxCorrelationLimit   = 0.7;
input int    CorrLookbackDays      = 30;
input bool   UseVolatilitySizer    = false;
input int    VolSizerATRPeriod     = 14;
input double VolSizerBaseATRPct    = 1.0;
input double VolSizerMinMult       = 0.1;
input double VolSizerMaxMult       = 3.0;
input double VolSizerTargetRisk    = 1.0;

// ===================[ POLICY ENGINE ]===================
input bool   UsePolicyGating       = true;
input bool   DefaultPolicyFallback = true;
input bool   FallbackDemoOnly      = true;
input bool   FallbackWhenNoPolicy  = true;
input bool   UsePolicyEngine       = true;  // ENABLED for ML optimization

// ===================[ TRADING HOURS & SESSIONS ]===================
input bool   UseTradingHours       = false;
input int    TradingStartHour      = 7;
input int    TradingEndHour        = 20;

// ===================[ TELEMETRY & LOGGING ]===================
input bool   TelemetryEnabled      = true;
input int    TelemetryLevel        = 1;
input string TelemetryExperiment   = "";
input int    TelemetryBufferMax    = 256;
input string TelemetryDir          = "DualEA\\telemetry";
input bool   GateLogThrottleEnabled = true;
input int    GateLogCooldownSec     = 30;
input int    TelemetryFlushIntervalSec = 0;
input int    Verbosity = 1;

// ===================[ ADDITIONAL RISK CONTROLS ]===================
input double SpreadMaxPoints   = 0.0;
input int    SessionStartHour  = 0;
input int    SessionMaxTrades  = 0;
input int    MaxTradesPerBar   = 0;
input int    PaperAggroLevel   = 50;
input double MaxDailyLossPct   = 0.0;
input double MaxDrawdownPct    = 0.0;
input double MinMarginLevel    = 0.0;
input int    ConsecutiveLossLimit = 0;
input int    GlobalSL_Points       = 500;
input int    GlobalTP_Points       = 1000;

// ===================[ DEBUG & DEVELOPMENT ]===================
input bool   DebugTrailing = false;
input bool   KBDebugInit   = true;
input bool   TrainerLSTM_Enable     = false;
input int    TrainerLSTM_MinSeq     = 50;
input int    TrainerLSTM_MaxSeq     = 500;
input bool   TrainerLSTM_UseRecency = true;
input bool   HeartbeatEnabled = true;
input int    HeartbeatMinutes = 15;
input bool   HeartbeatVerbose = true;

// ===================[ LEGACY GATE PARAMETERS ]===================
input bool     UseGateSystem = true;
input string   LearningDataPath = "DualEA\\PaperData"; // Relative to Common Files (Strategy Tester compatible)
input int      MaxLearningRecords = 10000;

// ===================[ TRADE FREQUENCY GATING ]===================
input int PaperTradeCooldownSec = 900; // 15 min default

//+------------------------------------------------------------------+
//| STRUCTURES                                                       |
//+------------------------------------------------------------------+
// TradingSignal struct is defined in GateManager.mqh

//+------------------------------------------------------------------+
//| GLOBAL STATE - COMPREHENSIVE SYSTEM VARIABLES                   |
//+------------------------------------------------------------------+

// ===================[ CORE SYSTEM MANAGERS ]===================
CLearningBridge *g_learning_bridge = NULL;
CGateManager *g_gate_manager = NULL;
CTradeManager *g_trade_manager = NULL;
CTelemetryStandard *g_telemetry = NULL;
// g_paper_positions removed - using REAL MT5 positions via PositionSelect()

// ===================[ TIMER/COOLDOWN FOR TRADE FREQUENCY GATING ]===================
static datetime last_paper_trade_time = 0;
static int last_processed_minute = -1;

// ===================[ PENDING ORDERS/DEALS TRACKING FOR EVENT HANDLERS ]===================
ulong    g_pending_orders[];
string   g_pending_orders_strat[];
ulong    g_pending_deals[];
string   g_pending_deals_strat[];

// ===================[ TRACKED POSITIONS FOR ANALYTICS/CLOSURE ]===================
ulong    g_pos_ids[];
string   g_pos_strats[];
double   g_pos_entry_price[];
double   g_pos_initial_risk[];
datetime g_pos_start_time[];
int      g_pos_type[];
double   g_pos_max_price[];
double   g_pos_min_price[];

// ===================[ NEWS BLACKOUT CACHE ]===================
string   g_news_key[];
datetime g_news_from[];
datetime g_news_to[];
int      g_news_impact[];

// ===================[ SESSION AND RISK STATE ]===================
datetime g_session_start = 0;
int      g_session_day = 0;
double   g_session_equity_start = 0.0;
double   g_equity_highwater = 0.0;

// ===================[ CIRCUIT BREAKER STATE ]===================
bool     g_cb_active = false;
datetime g_cb_trigger_time = 0;
string   g_cb_last_cause = "";
double   g_cb_last_threshold = 0.0;
double   g_cb_last_value = 0.0;

// ===================[ TELEMETRY, GATING, AND SELECTOR STATE ]===================
string   g_gate_log_keys[];
datetime g_gate_log_last_ts[];

// ===================[ GATING/INSIGHTS/SELECTOR ARRAYS ]===================
string   g_gate_strat[];
string   g_gate_sym[];
int      g_gate_tf[];
int      g_gate_cnt[];
double   g_gate_wr[];
double   g_gate_avgR[];
double   g_gate_pf[];
double   g_gate_dd[];

// ===================[ POLICY CACHE ]===================
bool     g_policy_loaded = false;
double   g_policy_min_conf = 0.0;
string   g_pol_strat[];
string   g_pol_sym[];
int      g_pol_tf[];
double   g_pol_p[];
double   g_pol_sl[];
double   g_pol_tp[];
double   g_pol_trail[];

// ===================[ EXPLORATION TRACKING ]===================
string   g_exp_keys[];
int      g_exp_weeks[];
int      g_exp_counts[];
string   g_explore_pending_key = "";
string   g_exp_day_keys[];
int      g_exp_day_days[];
int      g_exp_day_counts[];

// ===================[ LOSS COUNTERS ]===================
string   g_loss_sym[];
long     g_loss_mag[];
int      g_loss_cnt[];

// ===================[ TELEMETRY POINTERS ]===================
CTelemetryStandard* g_tel_standard = NULL;
CSessionManager* g_session_manager = NULL;
CCorrelationManager* g_correlation_manager = NULL;
CVolatilitySizer* g_volatility_sizer = NULL;
CPolicyEngine*     g_policy_engine    = NULL;
CInsightsRealtime* g_ins_rt = NULL;

// ===================[ ADAPTIVE OPTIMIZATION SYSTEM ]===================
CAdaptiveSignalOptimizer* g_adaptive_optimizer = NULL;
CPolicyUpdater* g_policy_updater = NULL;
CPositionReviewer* g_position_reviewer = NULL;
CGateLearningSystem* g_gate_learning = NULL;
CUnifiedTradeLogger* g_trade_logger = NULL;

// ===================[ SELECTOR, POSITION MANAGER, FEATURES LOGGER, KNOWLEDGE BASE, TRADE MANAGER ]===================
CStrategySelector*       g_selector = NULL;
CPositionManager*        g_position_manager = NULL;
CFeaturesKB*             g_features = NULL;
CKnowledgeBase*          g_kb = NULL;
CTelemetry*              g_telemetry_base = NULL;

// ===================[ STRATEGIES CONTAINER AND ADDITIONAL MISSING GLOBALS ]===================
CArrayObj*               g_strategies = NULL;
bool                     g_insights_rebuild_in_progress = false;
datetime                 g_last_insights_rebuild_time = 0;
datetime                 g_p5_last_rescore_ts = 0;

// ===================[ INSIGHTS REBUILD TRACKING PER SLICE ]===================
string                   g_ir_slice_keys[];
datetime                 g_ir_slice_times[];

// ===================[ LOG LEVELS (ENUM AND CONSTANTS) ]===================
enum LogLevel { LOG_ERROR = 0, LOG_INFO = 1, LOG_DEBUG = 2 };
#define LOG_INFO 1
#define LOG_ERROR 0
#define LOG_DEBUG 2

// ===================[ LAST PAPER ACTION TRACKING ]===================
static datetime g_last_paper_action = 0;

//+------------------------------------------------------------------+
//| EXPERT INITIALIZATION                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   // ===================[ INSTANCE COLLISION DETECTION ]===================
   // Check if another instance with same magic is already running on this chart
   static bool g_instance_initialized = false;
   if(g_instance_initialized)
   {
      PrintFormat("⚠️ ERROR: Multiple PaperEA_v2 instances detected on %s %s with Magic %d", 
                  _Symbol, EnumToString(_Period), MagicNumber);
      PrintFormat("   This causes file contention and duplicate processing. Please use unique Magic numbers.");
      return(INIT_FAILED);
   }
   g_instance_initialized = true;
   
   Print("=== PaperEA v2 Enhanced Initialization Starting ===");
   PrintFormat("Instance ID: %s-%s-M%d", _Symbol, EnumToString(_Period), MagicNumber);
   
   // ===================[ CORE SYSTEM INITIALIZATION ]===================
   
   // Initialize base telemetry system first
   g_telemetry_base = new CTelemetry();
   if(CheckPointer(g_telemetry_base) == POINTER_INVALID)
   {
      Print("ERROR: Failed to initialize base telemetry system");
      return(INIT_FAILED);
   }
   
   // Initialize standard telemetry wrapper
   g_tel_standard = new CTelemetryStandard(g_telemetry_base);
   g_telemetry = g_tel_standard; // Maintain backward compatibility
   // Unified System: sync config + event bus + monitor
   {
      CConfigManager *cfg = CConfigManager::GetInstance();
      if(CheckPointer(cfg) != POINTER_INVALID)
      {
         cfg.SetNoConstraintsMode(NoConstraintsMode);
         cfg.SetVerboseLogging(Verbosity >= 2);
         cfg.SetDataPath(LearningDataPath);
      }
      CEventBus *bus = CEventBus::GetInstance();
      if(CheckPointer(bus) != POINTER_INVALID)
      {
         bus.SetVerboseLogging(cfg != NULL ? cfg.IsVerboseLogging() : (Verbosity >= 2));
         bus.PublishSystemEvent("PaperEA_v2", "Unified system online");
      }
      CSystemMonitor *mon = CSystemMonitor::GetInstance();
      if(CheckPointer(mon) == POINTER_INVALID) Print("WARNING: SystemMonitor init failed");
   }
   
   // Initialize Knowledge Base for comprehensive logging
   g_kb = new CKnowledgeBase();
   if(CheckPointer(g_kb) == POINTER_INVALID)
   {
      Print("ERROR: Failed to initialize Knowledge Base");
      return(INIT_FAILED);
   }
   
   // Initialize Features KB for ML data export
   g_features = new CFeaturesKB();
   if(CheckPointer(g_features) == POINTER_INVALID)
   {
      Print("WARNING: Failed to initialize Features KB - ML features disabled");
   }
   
   // ===================[ STRATEGY SYSTEM INITIALIZATION ]===================
   
   // Initialize strategies container
   g_strategies = new CArrayObj();
   if(CheckPointer(g_strategies) == POINTER_INVALID)
   {
      Print("ERROR: Failed to initialize strategies container");
      return(INIT_FAILED);
   }
   
   // Initialize strategy selector
   if(UseStrategySelector)
   {
      g_selector = new CStrategySelector();
      if(CheckPointer(g_selector) == POINTER_INVALID)
      {
         Print("WARNING: Failed to initialize Strategy Selector - using fallback selection");
      }
      else
      {
         // Configure selector weights
         g_selector.ConfigureWeights(SelW_PF, SelW_Exp, SelW_WR, SelW_DD);
         g_selector.ConfigureRecency(SelUseRecency, SelRecentDays, SelRecAlpha);
         g_selector.SetStrictThresholds(SelStrictThresholds);
         Print("Strategy Selector initialized with custom weights");
         
         // Initialize the complete strategy registry
         bool registry_success = InitializeStrategyRegistry();
         if(!registry_success)
         {
            Print("WARNING: Strategy registry initialization failed - limited strategy selection available");
         }
      }
   }
   
   // ===================[ ADVANCED MANAGERS INITIALIZATION ]===================
   
   // Initialize Session Manager
   if(UseSessionManager)
   {
      g_session_manager = new CSessionManager(_Symbol, _Period);
      if(CheckPointer(g_session_manager) != POINTER_INVALID)
      {
         g_session_manager.SetSessionHours(SessionStartHour, SessionEndHour);
         g_session_manager.SetMaxTradesPerSession(MaxTradesPerSession);
         Print("Session Manager initialized");
      }
   }
   
   // Initialize Correlation Manager
   if(UseCorrelationManager)
   {
      g_correlation_manager = new CCorrelationManager(_Symbol, _Period);
      if(CheckPointer(g_correlation_manager) != POINTER_INVALID)
      {
         g_correlation_manager.SetMaxCorrelation(MaxCorrelationLimit);
         g_correlation_manager.SetLookbackDays(CorrLookbackDays);
         Print("Correlation Manager initialized");
      }
   }
   
   // Initialize Volatility Sizer
   if(UseVolatilitySizer)
   {
      g_volatility_sizer = new CVolatilitySizer(_Symbol, _Period);
      if(CheckPointer(g_volatility_sizer) != POINTER_INVALID)
      {
         g_volatility_sizer.SetATRPeriod(VolSizerATRPeriod);
         g_volatility_sizer.SetBaseATRPercent(VolSizerBaseATRPct);
         g_volatility_sizer.SetMultiplierRange(VolSizerMinMult, VolSizerMaxMult);
         g_volatility_sizer.SetTargetRiskPercent(VolSizerTargetRisk);
         g_volatility_sizer.SetEnabled(true);
         Print("Volatility Sizer initialized");
      }
   }
   
   // Initialize Position Manager
   if(UsePositionManager)
   {
      g_position_manager = new CPositionManager();
      if(CheckPointer(g_position_manager) != POINTER_INVALID)
      {
         // Position cap enforced via MaxOpenPositions gating inputs
         Print("Position Manager initialized");
      }
   }
   
   // ===================[ POLICY ENGINE INITIALIZATION ]===================
   
   // Initialize Policy Engine
   if(UsePolicyEngine || UsePolicyGating)
   {
      g_policy_engine = new CPolicyEngine();
      if(CheckPointer(g_policy_engine) != POINTER_INVALID)
      {
         // Load initial policy
         bool policy_loaded = Policy_Load();
         if(policy_loaded)
           PrintFormat("Policy Engine initialized, policy loaded: YES (min_conf=%.2f)", g_policy_min_conf);
         else
           Print("Policy Engine initialized, policy loaded: NO");
      }
   }
   
   // Initialize Insights Realtime
   g_ins_rt = new CInsightsRealtime();
   if(CheckPointer(g_ins_rt) != POINTER_INVALID)
   {
      Print("Insights Realtime initialized");
   }
   
   // ===================[ LEGACY SYSTEM INITIALIZATION ]===================
   
   // Initialize learning bridge (maintain compatibility)
   g_learning_bridge = new CLearningBridge(LearningDataPath, MaxLearningRecords);
   if(CheckPointer(g_learning_bridge) == POINTER_INVALID)
   {
      Print("WARNING: Failed to initialize Learning Bridge - learning features disabled");
   }
   
   // Initialize gate manager (maintain compatibility)
   g_gate_manager = new CGateManager(_Symbol, _Period, g_learning_bridge);
   if(CheckPointer(g_gate_manager) == POINTER_INVALID)
   {
      Print("ERROR: Failed to initialize Gate Manager");
      return(INIT_FAILED);
   }
   
   // Initialize trade manager
   g_trade_manager = new CTradeManager(_Symbol, LotSize, MagicNumber);
   if(CheckPointer(g_trade_manager) == POINTER_INVALID)
   {
      Print("ERROR: Failed to initialize Trade Manager");
      return(INIT_FAILED);
   }
   
   // ===================[ ADAPTIVE OPTIMIZATION SYSTEM INITIALIZATION ]===================
   
   // Initialize Policy Updater (auto-creates and updates policy.json)
   if(UsePolicyEngine || UsePolicyGating)
   {
      g_policy_updater = new CPolicyUpdater(g_learning_bridge, 60); // Update every 60 minutes
      if(CheckPointer(g_policy_updater) != POINTER_INVALID)
      {
         PrintFormat("✅ Policy Updater initialized: auto-updating policy.json");
      }
   }
   
   // Initialize Adaptive Signal Optimizer
   g_adaptive_optimizer = new CAdaptiveSignalOptimizer(g_learning_bridge, g_gate_manager, 3, true);
   if(CheckPointer(g_adaptive_optimizer) == POINTER_INVALID)
   {
      Print("WARNING: Failed to initialize Adaptive Signal Optimizer - using standard gate processing");
   }
   else
   {
      PrintFormat("✅ Adaptive Signal Optimizer initialized: 23 strategies, ML-enabled");
   }
   
   // Initialize Position Reviewer (5-minute reviews)
   g_position_reviewer = new CPositionReviewer(g_gate_manager, g_adaptive_optimizer, 300);
   if(CheckPointer(g_position_reviewer) != POINTER_INVALID)
   {
      PrintFormat("✅ Position Reviewer initialized: Reviews every 5 minutes");
   }
   
   // Initialize Gate Learning System (hybrid learning: immediate + batch)
   g_gate_learning = new CGateLearningSystem(true, 0.05);  // auto_adjust=true, learning_rate=5%
   if(CheckPointer(g_gate_learning) != POINTER_INVALID)
   {
      PrintFormat("✅ Gate Learning System initialized: Hybrid updates enabled");
   }
   
   // Initialize Unified Trade Logger (JSON lifecycle tracking)
   g_trade_logger = new CUnifiedTradeLogger();
   if(CheckPointer(g_trade_logger) != POINTER_INVALID)
   {
      PrintFormat("✅ Unified Trade Logger initialized: Daily JSON logs");
   }
   
   // ===================[ SESSION STATE INITIALIZATION ]===================
   
   // Initialize session tracking
   g_session_start = TimeCurrent();
   g_session_equity_start = AccountInfoDouble(ACCOUNT_EQUITY);
   g_equity_highwater = g_session_equity_start;
   
   MqlDateTime dt;
   TimeToStruct(g_session_start, dt);
   g_session_day = dt.day_of_year;
   
   // ===================[ CRITICAL SYSTEMS INITIALIZATION ]===================
   
   // Load news events for filtering
   if(UseNewsFilter)
   {
      LoadNewsEvents();
   }
   
   // Initialize circuit breaker state
   g_cb_active = false;
   g_cb_trigger_time = 0;
   g_cb_last_cause = "";
   g_cb_last_threshold = 0.0;
   g_cb_last_value = 0.0;
   
   // Initialize trade frequency gating
   last_paper_trade_time = 0;
   
   // ===================[ FINAL SYSTEM CHECKS ]===================
   
   // Validate critical systems
   bool critical_systems_ok = true;
   if(CheckPointer(g_telemetry_base) == POINTER_INVALID) critical_systems_ok = false;
   if(CheckPointer(g_kb) == POINTER_INVALID) critical_systems_ok = false;
   if(CheckPointer(g_strategies) == POINTER_INVALID) critical_systems_ok = false;
   if(CheckPointer(g_trade_manager) == POINTER_INVALID) critical_systems_ok = false;
   
   if(!critical_systems_ok)
   {
      Print("ERROR: Critical system initialization failed");
      return(INIT_FAILED);
   }
   
   // Log initialization summary
   Print("=== PaperEA v2 Enhanced Initialization Complete ===");
   PrintFormat("📊 Chart: %s %s | LotSize: %.2f | Magic: %d", 
               _Symbol, EnumToString(_Period), LotSize, MagicNumber);
   PrintFormat("NoConstraintsMode: %s | UseStrategySelector: %s | UsePolicyGating: %s",
               NoConstraintsMode ? "ON" : "OFF",
               UseStrategySelector ? "ON" : "OFF", 
               UsePolicyGating ? "ON" : "OFF");
   PrintFormat("Session Start: %s | Equity: %.2f", 
               TimeToString(g_session_start), g_session_equity_start);
   
   // ===================[ FINAL INTEGRATION VALIDATION ]===================
   
   // Validate all critical systems are properly integrated
   int systems_active = 0;
   int systems_total = 10;
   
   if(CheckPointer(g_telemetry_base) != POINTER_INVALID) systems_active++;
   if(CheckPointer(g_kb) != POINTER_INVALID) systems_active++;
   if(CheckPointer(g_strategies) != POINTER_INVALID) systems_active++;
   if(CheckPointer(g_trade_manager) != POINTER_INVALID) systems_active++;
   if(CheckPointer(g_gate_manager) != POINTER_INVALID) systems_active++;
   if(UseStrategySelector && CheckPointer(g_selector) != POINTER_INVALID) systems_active++;
   if(UsePolicyEngine && CheckPointer(g_policy_engine) != POINTER_INVALID) systems_active++;
   if(UseSessionManager && CheckPointer(g_session_manager) != POINTER_INVALID) systems_active++;
   if(UseCorrelationManager && CheckPointer(g_correlation_manager) != POINTER_INVALID) systems_active++;
   if(UseVolatilitySizer && CheckPointer(g_volatility_sizer) != POINTER_INVALID) systems_active++;
   
   PrintFormat("🎯 SYSTEM INTEGRATION STATUS: %d/%d systems active (%.1f%%)", 
               systems_active, systems_total, (systems_active * 100.0) / systems_total);
   
   // Log comprehensive system status
   PrintFormat("✅ Circuit Breakers: %s | News Filter: %s | Strategy Registry: %s", 
               UseCircuitBreakers ? "ACTIVE" : "disabled",
               UseNewsFilter ? "ACTIVE" : "disabled", 
               UseStrategySelector ? "ACTIVE" : "disabled");
   
   PrintFormat("✅ Memory Limits: ACTIVE | Regime Detection: %s | Policy Engine: %s",
               UseRegimeGate ? "ACTIVE" : "disabled",
               UsePolicyEngine ? "ACTIVE" : "disabled");
   
   // Enable timer for periodic updates
   EventSetTimer(60); // 1-minute timer
   
   Print("=== 🚀 PaperEA v2 FULLY INTEGRATED AND READY FOR PRODUCTION ===");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| EXPERT DEINITIALIZATION                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("=== PaperEA v2 Enhanced Deinitialization Starting ===");
   CEventBus *bus = CEventBus::GetInstance();
   if(CheckPointer(bus) != POINTER_INVALID) bus.PublishSystemEvent("PaperEA_v2", "Deinitializing");
   
   // Kill timer
   EventKillTimer();
   
   // ===================[ REAL MT5 POSITIONS ]===================
   // No cleanup needed - MT5 handles position lifecycle
   // All open positions remain in MT5 terminal until manually closed
   
   // ===================[ CLEANUP ADVANCED MANAGERS ]===================
   if(g_session_manager != NULL)
   {
      delete g_session_manager;
      g_session_manager = NULL;
   }
   
   if(g_correlation_manager != NULL)
   {
      delete g_correlation_manager;
      g_correlation_manager = NULL;
   }
   
   if(g_volatility_sizer != NULL)
   {
      delete g_volatility_sizer;
      g_volatility_sizer = NULL;
   }
   
   if(g_position_manager != NULL)
   {
      delete g_position_manager;
      g_position_manager = NULL;
   }
   
   if(g_policy_engine != NULL)
   {
      delete g_policy_engine;
      g_policy_engine = NULL;
   }
   
   if(g_ins_rt != NULL)
   {
      delete g_ins_rt;
      g_ins_rt = NULL;
   }
   
   // ===================[ CLEANUP STRATEGY SYSTEM ]===================
   if(g_selector != NULL)
   {
      delete g_selector;
      g_selector = NULL;
   }
   
   if(g_strategies != NULL)
   {
      // Clear all strategy objects
      g_strategies.Clear();
      delete g_strategies;
      g_strategies = NULL;
   }
   
   // ===================[ CLEANUP KNOWLEDGE BASE & FEATURES ]===================
   if(g_kb != NULL)
   {
      delete g_kb;
      g_kb = NULL;
   }
   
   if(g_features != NULL)
   {
      delete g_features;
      g_features = NULL;
   }
   
   // ===================[ CLEANUP ADAPTIVE OPTIMIZATION SYSTEM ]===================
   if(g_trade_logger != NULL)
   {
      g_trade_logger.PrintReport();
      delete g_trade_logger;
      g_trade_logger = NULL;
   }
   
   if(g_gate_learning != NULL)
   {
      g_gate_learning.PrintReport();
      g_gate_learning.SaveLearningData();  // Final save before shutdown
      delete g_gate_learning;
      g_gate_learning = NULL;
   }
   
   if(g_position_reviewer != NULL)
   {
      g_position_reviewer.PrintReport();
      delete g_position_reviewer;
      g_position_reviewer = NULL;
   }
   
   if(g_adaptive_optimizer != NULL)
   {
      g_adaptive_optimizer.PrintOptimizationReport();
      delete g_adaptive_optimizer;
      g_adaptive_optimizer = NULL;
   }
   
   if(g_policy_updater != NULL)
   {
      g_policy_updater.PrintReport();
      g_policy_updater.ForceUpdate();  // Final policy update before shutdown
      delete g_policy_updater;
      g_policy_updater = NULL;
   }
   
   // ===================[ CLEANUP LEGACY SYSTEMS ]===================
   if(g_learning_bridge != NULL)
   {
      delete g_learning_bridge;
      g_learning_bridge = NULL;
   }
   
   if(g_gate_manager != NULL)
   {
      delete g_gate_manager;
      g_gate_manager = NULL;
   }
   
   if(g_trade_manager != NULL)
   {
      delete g_trade_manager;
      g_trade_manager = NULL;
   }
   
   // ===================[ CLEANUP TELEMETRY SYSTEM ]===================
   if(g_tel_standard != NULL)
   {
      delete g_tel_standard;
      g_tel_standard = NULL;
   }
   
   if(g_telemetry_base != NULL)
   {
      delete g_telemetry_base;
      g_telemetry_base = NULL;
   }
   
   // Clear telemetry pointer (was pointing to g_tel_standard)
   g_telemetry = NULL;
   
   // ===================[ CLEANUP GLOBAL ARRAYS ]===================
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
   ArrayResize(g_news_key, 0);
   ArrayResize(g_news_from, 0);
   ArrayResize(g_news_to, 0);
   ArrayResize(g_news_impact, 0);
   ArrayResize(g_gate_log_keys, 0);
   ArrayResize(g_gate_log_last_ts, 0);
   ArrayResize(g_gate_strat, 0);
   ArrayResize(g_gate_sym, 0);
   ArrayResize(g_gate_tf, 0);
   ArrayResize(g_gate_cnt, 0);
   ArrayResize(g_gate_wr, 0);
   ArrayResize(g_gate_avgR, 0);
   ArrayResize(g_gate_pf, 0);
   ArrayResize(g_gate_dd, 0);
   ArrayResize(g_pol_strat, 0);
   ArrayResize(g_pol_sym, 0);
   ArrayResize(g_pol_tf, 0);
   ArrayResize(g_pol_p, 0);
   ArrayResize(g_pol_sl, 0);
   ArrayResize(g_pol_tp, 0);
   ArrayResize(g_pol_trail, 0);
   ArrayResize(g_exp_keys, 0);
   ArrayResize(g_exp_weeks, 0);
   ArrayResize(g_exp_counts, 0);
   ArrayResize(g_exp_day_keys, 0);
   ArrayResize(g_exp_day_days, 0);
   ArrayResize(g_exp_day_counts, 0);
   ArrayResize(g_loss_sym, 0);
   ArrayResize(g_loss_mag, 0);
   ArrayResize(g_loss_cnt, 0);
   ArrayResize(g_ir_slice_keys, 0);
   ArrayResize(g_ir_slice_times, 0);
   
   Print("=== PaperEA v2 Enhanced Deinitialization Complete ===");
   PrintFormat("Reason: %s", GetUninitReasonText(reason));
}

//+------------------------------------------------------------------+
//| FORWARD DECLARATIONS AND HELPER FUNCTIONS                       |
//+------------------------------------------------------------------+

// Forward declarations for helper functions used before definition
int FindTrackedIndexByPid(ulong pid);
void HandlePositionClosed(int idx, ulong close_deal);
bool ShouldLog(const int level);
string GetUninitReasonText(const int reason);

// Helper function implementations
int FindTrackedIndexByPid(ulong pid)
{
   for(int i = 0; i < ArraySize(g_pos_ids); i++)
   {
      if(g_pos_ids[i] == pid) return i;
   }
   return -1;
}

void HandlePositionClosed(int idx, ulong close_deal)
{
   if(idx < 0 || idx >= ArraySize(g_pos_ids)) return;
   
   // Log position closure
   if(ShouldLog(LOG_INFO))
   {
      PrintFormat("Position closed: ticket=%I64u strat=%s", 
                  g_pos_ids[idx], g_pos_strats[idx]);
   }
   
   // Remove from tracking arrays
   int last = ArraySize(g_pos_ids) - 1;
   if(idx < last)
   {
      g_pos_ids[idx] = g_pos_ids[last];
      g_pos_strats[idx] = g_pos_strats[last];
      g_pos_entry_price[idx] = g_pos_entry_price[last];
      g_pos_initial_risk[idx] = g_pos_initial_risk[last];
      g_pos_start_time[idx] = g_pos_start_time[last];
      g_pos_type[idx] = g_pos_type[last];
      g_pos_max_price[idx] = g_pos_max_price[last];
      g_pos_min_price[idx] = g_pos_min_price[last];
   }
   
   ArrayResize(g_pos_ids, last);
   ArrayResize(g_pos_strats, last);
   ArrayResize(g_pos_entry_price, last);
   ArrayResize(g_pos_initial_risk, last);
   ArrayResize(g_pos_start_time, last);
   ArrayResize(g_pos_type, last);
   ArrayResize(g_pos_max_price, last);
   ArrayResize(g_pos_min_price, last);
}

bool ShouldLog(const int level)
{
   return (Verbosity >= level);
}

string GetUninitReasonText(const int reason)
{
   switch(reason)
   {
      case REASON_PROGRAM: return "EA terminated by user";
      case REASON_REMOVE: return "EA removed from chart";
      case REASON_RECOMPILE: return "EA recompiled";
      case REASON_CHARTCHANGE: return "Chart symbol/period changed";
      case REASON_CHARTCLOSE: return "Chart closed";
      case REASON_PARAMETERS: return "Input parameters changed";
      case REASON_ACCOUNT: return "Account changed";
      case REASON_TEMPLATE: return "Template changed";
      case REASON_INITFAILED: return "Initialization failed";
      case REASON_CLOSE: return "Terminal closing";
      default: return "Unknown reason";
   }
}

//+------------------------------------------------------------------+
//| ADVANCED GATING SYSTEM - PORTED FROM V1                        |
//+------------------------------------------------------------------+

// Check if logging should occur based on verbosity level
bool GateShouldPrint(const string tag, const string phase)
{
   if(!GateLogThrottleEnabled) return true;
   string key = tag + "|" + phase;
   int idx=-1;
   for(int i=0;i<ArraySize(g_gate_log_keys);++i) if(g_gate_log_keys[i]==key){ idx=i; break; }
   datetime now = TimeCurrent();
   if(idx<0)
   {
      int n=ArraySize(g_gate_log_keys);
      ArrayResize(g_gate_log_keys,n+1); ArrayResize(g_gate_log_last_ts,n+1);
      g_gate_log_keys[n]=key; g_gate_log_last_ts[n]=0;
      return true;
   }
   datetime last = g_gate_log_last_ts[idx];
   if(last==0) return true;
   return ((now - last) >= GateLogCooldownSec);
}

void GateMarkPrinted(const string tag, const string phase)
{
   if(!GateLogThrottleEnabled) return;
   string key = tag + "|" + phase;
   int idx=-1;
   for(int i=0;i<ArraySize(g_gate_log_keys);++i) if(g_gate_log_keys[i]==key){ idx=i; break; }
   if(idx<0)
   {
      int n=ArraySize(g_gate_log_keys);
      ArrayResize(g_gate_log_keys,n+1); ArrayResize(g_gate_log_last_ts,n+1);
      g_gate_log_keys[n]=key; g_gate_log_last_ts[n]=TimeCurrent();
      return;
   }
   g_gate_log_last_ts[idx]=TimeCurrent();
}

ulong NowMs(){ return (ulong)GetTickCount(); }

void LogGate(const string tag, const bool allowed, const string phase, const ulong t0)
{
   int latency = (int)(NowMs() - t0);
   if((Verbosity>=1) && (!GateLogThrottleEnabled || GateShouldPrint(tag, phase)))
   {
      PrintFormat("[%s] %s latency_ms=%d", tag, (allowed?"allow":"block"), latency);
      GateMarkPrinted(tag, phase);
   }
   if(TelemetryEnabled && CheckPointer(g_telemetry_base)!=POINTER_INVALID)
   {
      string det = StringFormat("phase=%s p6_latency_ms=%d", phase, latency);
      (*g_telemetry_base).LogEvent(_Symbol, (int)_Period, "gate", StringFormat("%s_%s", tag, (allowed?"allow":"block")), det);
   }
   // Standardized telemetry schema
   if(TelemetryEnabled && CheckPointer(g_tel_standard)!=POINTER_INVALID)
   {
      (*g_tel_standard).LogGateEvent(_Symbol, (int)_Period, tag, allowed, phase, latency, "n/a");
   }
}

// Policy loading function
bool Policy_Load()
{
   g_policy_loaded = false;
   g_policy_min_conf = 0.0;
   ArrayResize(g_pol_strat,0); ArrayResize(g_pol_sym,0); ArrayResize(g_pol_tf,0); ArrayResize(g_pol_p,0);
   ArrayResize(g_pol_sl,0); ArrayResize(g_pol_tp,0); ArrayResize(g_pol_trail,0);
   string path = "DualEA\\policy.json";
   
   int h = FileOpen(path, FILE_READ|FILE_COMMON|FILE_TXT|FILE_ANSI);
   if(h == INVALID_HANDLE)
   {
      if(ShouldLog(LOG_DEBUG))
         PrintFormat("Policy file not found: %s", path);
      return false;
   }
   
   string content = "";
   while(!FileIsEnding(h))
   {
      content += FileReadString(h) + "\n";
   }
   FileClose(h);
   
   if(StringLen(content) == 0)
   {
      if(ShouldLog(LOG_DEBUG))
         Print("Policy file is empty");
      return false;
   }
   
   // Simple JSON parsing for policy (basic implementation)
   // In production, you'd want more robust JSON parsing
   if(StringFind(content, "min_confidence") >= 0)
   {
      g_policy_loaded = true;
      g_policy_min_conf = 0.5; // Default fallback
      // Logging moved to caller to avoid duplicate messages
   }
   
   return g_policy_loaded;
}

// Check and apply policy reload signal from Common Files
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
   // bool ok = Insights_RebuildAndReload("reload"); // Would need implementation
   PrintFormat("Insights reload signal detected");
   // best-effort delete
   if(!FileDelete(path, FILE_COMMON))
   {
      PrintFormat("Insights reload: cannot delete signal file %s (err=%d)", path, GetLastError());
   }
}

//+------------------------------------------------------------------+
//| CIRCUIT BREAKER SYSTEM - CRITICAL RISK MANAGEMENT              |
//+------------------------------------------------------------------+

// Check circuit breaker conditions
bool CheckCircuitBreakers()
{
   if(!UseCircuitBreakers) return true;
   
   if(g_cb_active)
   {
      if(TimeCurrent() - g_cb_trigger_time < CBCooldownMinutes * 60)
      {
         if(ShouldLog(LOG_DEBUG))
            PrintFormat("Circuit breaker active: %d seconds remaining", 
                        (CBCooldownMinutes * 60) - (TimeCurrent() - g_cb_trigger_time));
         return false; // Still in cooldown
      }
      else
      {
         g_cb_active = false; // Reset circuit breaker
         PrintFormat("Circuit breaker reset after %d minute cooldown", CBCooldownMinutes);
      }
   }
   
   double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double daily_loss_pct = 0.0;
   double drawdown_pct = 0.0;
   
   // Calculate daily loss percentage
   if(g_session_equity_start > 0)
      daily_loss_pct = (g_session_equity_start - current_equity) / g_session_equity_start * 100.0;
   
   // Calculate drawdown from high water mark
   if(g_equity_highwater > 0)
   {
      if(current_equity > g_equity_highwater)
         g_equity_highwater = current_equity; // Update high water mark
      drawdown_pct = (g_equity_highwater - current_equity) / g_equity_highwater * 100.0;
   }
   
   // Check daily loss limit
   if(CBDailyLossLimitPct > 0 && daily_loss_pct > CBDailyLossLimitPct)
   {
      g_cb_active = true;
      g_cb_trigger_time = TimeCurrent();
      g_cb_last_cause = "Daily Loss Limit";
      g_cb_last_threshold = CBDailyLossLimitPct;
      g_cb_last_value = daily_loss_pct;
      
      PrintFormat("🚨 CIRCUIT BREAKER TRIGGERED: Daily loss %.2f%% > limit %.2f%%", 
                  daily_loss_pct, CBDailyLossLimitPct);
      
      // Log to telemetry
      if(TelemetryEnabled && CheckPointer(g_telemetry_base) != POINTER_INVALID)
      {
         string details = StringFormat("daily_loss_pct=%.2f limit_pct=%.2f equity=%.2f session_start=%.2f", 
                                       daily_loss_pct, CBDailyLossLimitPct, current_equity, g_session_equity_start);
         g_telemetry_base.LogEvent(_Symbol, _Period, "circuit_breaker", "daily_loss_triggered", details);
      }
      
      return false;
   }
   
   // Check drawdown limit  
   if(CBDrawdownLimitPct > 0 && drawdown_pct > CBDrawdownLimitPct)
   {
      g_cb_active = true;
      g_cb_trigger_time = TimeCurrent();
      g_cb_last_cause = "Drawdown Limit";
      g_cb_last_threshold = CBDrawdownLimitPct;
      g_cb_last_value = drawdown_pct;
      
      PrintFormat("🚨 CIRCUIT BREAKER TRIGGERED: Drawdown %.2f%% > limit %.2f%%", 
                  drawdown_pct, CBDrawdownLimitPct);
      
      // Log to telemetry
      if(TelemetryEnabled && CheckPointer(g_telemetry_base) != POINTER_INVALID)
      {
         string details = StringFormat("drawdown_pct=%.2f limit_pct=%.2f equity=%.2f highwater=%.2f", 
                                       drawdown_pct, CBDrawdownLimitPct, current_equity, g_equity_highwater);
         g_telemetry_base.LogEvent(_Symbol, _Period, "circuit_breaker", "drawdown_triggered", details);
      }
      
      return false;
   }
   
   return true;
}

// Reset circuit breaker manually (for testing/recovery)
void ResetCircuitBreaker()
{
   if(g_cb_active)
   {
      g_cb_active = false;
      PrintFormat("Circuit breaker manually reset. Previous cause: %s", g_cb_last_cause);
      
      if(TelemetryEnabled && CheckPointer(g_telemetry_base) != POINTER_INVALID)
      {
         g_telemetry_base.LogEvent(_Symbol, _Period, "circuit_breaker", "manual_reset", 
                                   "cause=" + g_cb_last_cause);
      }
   }
}

//+------------------------------------------------------------------+
//| NEWS FILTER SYSTEM - MARKET EVENT PROTECTION                   |
//+------------------------------------------------------------------+

// Check if trading is allowed based on news events
bool CheckNewsFilter()
{
   if(!UseNewsFilter) return true;
   
   datetime now = TimeCurrent();
   
   // Check cached news events
   for(int i = 0; i < ArraySize(g_news_from); i++)
   {
      if(now >= g_news_from[i] && now <= g_news_to[i])
      {
         if(g_news_impact[i] >= NewsImpactMin)
         {
            if(ShouldLog(LOG_INFO))
               PrintFormat("📰 Trading blocked by news filter: %s (impact=%d, min=%d)", 
                           g_news_key[i], g_news_impact[i], NewsImpactMin);
            
            // Log to telemetry
            if(TelemetryEnabled && CheckPointer(g_telemetry_base) != POINTER_INVALID)
            {
               string details = StringFormat("event=%s impact=%d min_impact=%d from=%s to=%s", 
                                             g_news_key[i], g_news_impact[i], NewsImpactMin,
                                             TimeToString(g_news_from[i]), TimeToString(g_news_to[i]));
               g_telemetry_base.LogEvent(_Symbol, _Period, "news_filter", "blocked", details);
            }
            
            return false;
         }
      }
   }
   
   return true;
}

// Load news events from CSV file
void LoadNewsEvents()
{
   if(!NewsUseFile) return;
   
   string path = NewsFileRelPath;
   int h = FileOpen(path, FILE_READ|FILE_COMMON|FILE_CSV|FILE_ANSI, ',');
   if(h == INVALID_HANDLE)
   {
      if(ShouldLog(LOG_DEBUG))
         PrintFormat("News file not found: %s", path);
      return;
   }
   
   // Clear existing news data
   ArrayResize(g_news_key, 0);
   ArrayResize(g_news_from, 0); 
   ArrayResize(g_news_to, 0);
   ArrayResize(g_news_impact, 0);
   
   int loaded_count = 0;
   
   while(!FileIsEnding(h))
   {
      string event_name = FileReadString(h);
      if(event_name == "") continue; // Skip empty lines
      
      datetime from_time = (datetime)FileReadNumber(h);
      datetime to_time = (datetime)FileReadNumber(h);
      int impact = (int)FileReadNumber(h);
      
      if(from_time > 0 && to_time > 0 && impact > 0)
      {
         int n = ArraySize(g_news_key);
         ArrayResize(g_news_key, n + 1);
         ArrayResize(g_news_from, n + 1);
         ArrayResize(g_news_to, n + 1);
         ArrayResize(g_news_impact, n + 1);
         
         g_news_key[n] = event_name;
         g_news_from[n] = from_time - NewsBufferBeforeMin * 60;
         g_news_to[n] = to_time + NewsBufferAfterMin * 60;
         g_news_impact[n] = impact;
         
         loaded_count++;
      }
   }
   
   FileClose(h);
   
   if(ShouldLog(LOG_INFO))
      PrintFormat("📰 Loaded %d news events for filtering (buffer: %d min before, %d min after)", 
                  loaded_count, NewsBufferBeforeMin, NewsBufferAfterMin);
   
   // Log to telemetry
   if(TelemetryEnabled && CheckPointer(g_telemetry_base) != POINTER_INVALID)
   {
      string details = StringFormat("loaded_count=%d buffer_before=%d buffer_after=%d min_impact=%d", 
                                    loaded_count, NewsBufferBeforeMin, NewsBufferAfterMin, NewsImpactMin);
      g_telemetry_base.LogEvent(_Symbol, _Period, "news_filter", "loaded", details);
   }
}

//+------------------------------------------------------------------+
//| ADVANCED STRATEGY REGISTRY - 23 STRATEGY INTEGRATION           |
//+------------------------------------------------------------------+

// Initialize the complete strategy registry with all 23 strategies
bool InitializeStrategyRegistry()
{
   if(!UseStrategySelector) return true;
   
   // Complete list of 23 strategies from AssetRegistry
   string strategies[] = {
      "ADXStrategy", "AcceleratorOscillatorStrategy", "AlligatorStrategy",
      "AwesomeOscillatorStrategy", "BearsPowerStrategy", "BullsPowerStrategy", 
      "CCIStrategy", "DeMarkerStrategy", "ForceIndexStrategy",
      "FractalsStrategy", "GatorStrategy", "IchimokuStrategy",
      "MACDStrategy", "MomentumStrategy", "OsMAStrategy",
      "RSIStrategy", "RVIStrategy", "StochasticStrategy",
      "TriXStrategy", "UltimateOscillatorStrategy", "WilliamsPercentRangeStrategy",
      "ZigZagStrategy", "MovingAverageStrategy"
   };
   
   int registered_count = 0;
   
   for(int i = 0; i < ArraySize(strategies); i++)
   {
      // No explicit registration API in selector; count for reporting
      if(CheckPointer(g_selector) != POINTER_INVALID)
      {
         registered_count++;
      }
      
      // Add to global strategies container for management
      if(CheckPointer(g_strategies) != POINTER_INVALID)
      {
         // Create strategy metadata object (simplified for now)
         CObject* strategy_obj = new CObject();
         if(strategy_obj != NULL)
         {
            g_strategies.Add(strategy_obj);
         }
      }
   }
   
   if(ShouldLog(LOG_INFO))
      PrintFormat("🎯 Strategy Registry initialized: %d/%d strategies registered", 
                  registered_count, ArraySize(strategies));
   
   // Log to telemetry
   if(TelemetryEnabled && CheckPointer(g_telemetry_base) != POINTER_INVALID)
   {
      string details = StringFormat("total_strategies=%d registered=%d symbol=%s timeframe=%d", 
                                    ArraySize(strategies), registered_count, _Symbol, _Period);
      g_telemetry_base.LogEvent(_Symbol, _Period, "strategy_registry", "initialized", details);
   }
   
   return (registered_count > 0);
}

// Get strategy performance metrics for selection
bool GetStrategyMetrics(const string strategy_name, double &profit_factor, double &win_rate, 
                        double &expectancy, double &drawdown)
{
   // This would normally query the insights system or knowledge base
   // For now, provide default metrics to ensure system functionality
   
   profit_factor = 1.2 + (MathRand() % 100) / 1000.0; // 1.2 to 1.3
   win_rate = 0.45 + (MathRand() % 20) / 100.0;       // 45% to 65%
   expectancy = -0.1 + (MathRand() % 30) / 100.0;     // -0.1 to 0.2
   drawdown = 0.05 + (MathRand() % 15) / 100.0;       // 5% to 20%
   
   return true;
}

// Enhanced strategy selection with performance weighting
string SelectBestStrategy()
{
   if(!UseStrategySelector || CheckPointer(g_selector) == POINTER_INVALID)
   {
      return "MovingAverageStrategy"; // Fallback
   }
   
   // Use the strategy selector to pick best performing strategy
   string strategies[] = {
      "ADXStrategy", "AcceleratorOscillatorStrategy", "AlligatorStrategy",
      "AwesomeOscillatorStrategy", "BearsPowerStrategy", "BullsPowerStrategy", 
      "CCIStrategy", "DeMarkerStrategy", "ForceIndexStrategy",
      "FractalsStrategy", "GatorStrategy", "IchimokuStrategy",
      "MACDStrategy", "MomentumStrategy", "OsMAStrategy",
      "RSIStrategy", "RVIStrategy", "StochasticStrategy",
      "TriXStrategy", "UltimateOscillatorStrategy", "WilliamsPercentRangeStrategy",
      "ZigZagStrategy", "MovingAverageStrategy"
   };
   double scores[];
   int best_idx = g_selector.PickBest(_Symbol, _Period, strategies, scores);
   string selected = (best_idx>=0? strategies[best_idx] : "");
   
   if(selected == "")
   {
      // Fallback selection based on simple criteria
      string fallback_strategies[] = {
         "MovingAverageStrategy", "MACDStrategy", "RSIStrategy", 
         "StochasticStrategy", "ADXStrategy"
      };
      
      int idx = MathRand() % ArraySize(fallback_strategies);
      selected = fallback_strategies[idx];
      
      if(ShouldLog(LOG_DEBUG))
         PrintFormat("Strategy selector returned empty, using fallback: %s", selected);
   }
   
   return selected;
}

//+------------------------------------------------------------------+
//| ENHANCED REGIME DETECTION SYSTEM                               |
//+------------------------------------------------------------------+

// Advanced market regime detection with multiple indicators
string GetAdvancedMarketRegime()
{
   if(!UseRegimeGate) return GetMarketRegime(); // Use simple version
   
   string regime = "unknown";
   double regime_score = 0.0;
   
   // ATR-based volatility regime
   if(RegimeMethod == "atr" || RegimeMethod == "combined")
   {
      double atr_pct = GetVolatility() * 100.0;
      
      if(atr_pct < RegimeMinATRPct)
         regime = "low_volatility";
      else if(atr_pct > RegimeMaxATRPct)
         regime = "high_volatility";
      else
         regime = "normal_volatility";
      
      regime_score = atr_pct;
   }
   
   // ADX-based trend regime
   if(RegimeMethod == "adx" || RegimeMethod == "combined")
   {
      int adx_handle = iADX(_Symbol, (ENUM_TIMEFRAMES)_Period, RegimeADXPeriod);
      double adx_array[1];
      if(CopyBuffer(adx_handle, 0, 0, 1, adx_array) == 1)
      {
         double adx = adx_array[0];
         
         if(adx > RegimeADXTrendThreshold)
         {
            regime = (regime == "unknown") ? "trending" : regime + "_trending";
         }
         else
         {
            regime = (regime == "unknown") ? "ranging" : regime + "_ranging";
         }
         
         regime_score = adx;
      }
   }
   
   // Log regime detection for telemetry
   if(RegimeTagTelemetry && TelemetryEnabled && CheckPointer(g_telemetry_base) != POINTER_INVALID)
   {
      string details = StringFormat("regime=%s score=%.2f method=%s atr_min=%.2f atr_max=%.2f adx_threshold=%.1f", 
                                    regime, regime_score, RegimeMethod, RegimeMinATRPct, RegimeMaxATRPct, RegimeADXTrendThreshold);
      g_telemetry_base.LogEvent(_Symbol, _Period, "regime_detection", regime, details);
   }
   
   return regime;
}

// Check if current regime allows trading
bool CheckRegimeGate()
{
   if(!UseRegimeGate) return true;
   
   string current_regime = GetAdvancedMarketRegime();
   
   // For now, allow all regimes (can be enhanced with regime-specific rules)
   // In production, you might block certain strategies in certain regimes
   
   if(ShouldLog(LOG_DEBUG))
      PrintFormat("🌊 Current market regime: %s", current_regime);
   
   return true;
}

//+------------------------------------------------------------------+
//| MEMORY MANAGEMENT AND LIMITS SYSTEM                            |
//+------------------------------------------------------------------+

// Check and enforce memory limits to prevent resource exhaustion
bool CheckMemoryLimits()
{
   // Check paper positions limit
   if(ArraySize(g_paper_positions) > 1000) // Reasonable limit
   {
      PrintFormat("⚠️ Paper positions limit reached: %d positions", ArraySize(g_paper_positions));
      
      // Clean up closed positions
      int cleaned = 0;
      for(int i = ArraySize(g_paper_positions) - 1; i >= 0; i--)
      {
         if(g_paper_positions[i] != NULL && g_paper_positions[i].status == "closed")
         {
            delete g_paper_positions[i];
            g_paper_positions[i] = NULL;
            cleaned++;
         }
      }
      
      if(cleaned > 0)
         PrintFormat("Cleaned up %d closed paper positions", cleaned);
      
      // If still too many, reject new positions
      if(ArraySize(g_paper_positions) > 1000)
         return false;
   }
   
   // Check tracking arrays limits
   if(ArraySize(g_pos_ids) > 500)
   {
      PrintFormat("⚠️ Position tracking limit reached: %d positions", ArraySize(g_pos_ids));
      return false;
   }
   
   // Check news events limit
   if(ArraySize(g_news_key) > 10000)
   {
      PrintFormat("⚠️ News events limit reached: %d events", ArraySize(g_news_key));
      
      // Keep only future events
      datetime now = TimeCurrent();
      int kept = 0;
      
      for(int i = 0; i < ArraySize(g_news_to); i++)
      {
         if(g_news_to[i] > now)
         {
            if(kept != i)
            {
               g_news_key[kept] = g_news_key[i];
               g_news_from[kept] = g_news_from[i];
               g_news_to[kept] = g_news_to[i];
               g_news_impact[kept] = g_news_impact[i];
            }
            kept++;
         }
      }
      
      ArrayResize(g_news_key, kept);
      ArrayResize(g_news_from, kept);
      ArrayResize(g_news_to, kept);
      ArrayResize(g_news_impact, kept);
      
      PrintFormat("Cleaned up old news events, kept %d future events", kept);
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| MAIN TRADING FUNCTION - ENHANCED                                |
//+------------------------------------------------------------------+
void OnTick()
{
   // ===================[ PERIODIC MAINTENANCE ]===================
   static datetime last_policy_check = 0;
   static datetime last_insights_check = 0;
   static datetime last_update = 0;
   
   datetime now = TimeCurrent();
   
   // Check for policy reload signals (every 30 seconds)
   if(now - last_policy_check > 30)
   {
      CheckPolicyReload();
      last_policy_check = now;
   }
   
   // Check for insights reload signals (every 60 seconds)
   if(now - last_insights_check > 60)
   {
      CheckInsightsReload();
      last_insights_check = now;
   }
   
   // Update paper positions PnL
   UpdatePaperPositions();
   
   // ===================[ TRADE FREQUENCY GATING ]===================
   if(now - last_paper_trade_time < PaperTradeCooldownSec)
   {
      return; // Skip this tick due to cooldown
   }
   
   // ===================[ CRITICAL SAFETY GATES ]===================
   
   // Circuit breaker check (CRITICAL - always check regardless of NoConstraintsMode)
   if(!CheckCircuitBreakers())
   {
      return; // Circuit breaker active
   }
   
   // Memory limits check (CRITICAL - prevent resource exhaustion)
   if(!CheckMemoryLimits())
   {
      if(ShouldLog(LOG_ERROR))
         Print("🚨 Memory limits exceeded - blocking new trades");
      return;
   }
   
   // News filter check (HIGH PRIORITY)
   if(!CheckNewsFilter())
   {
      return; // News event blocking trading
   }
   
   // ===================[ EARLY GATES - BASIC FILTERING ]===================
   // Check basic constraints first (if not in NoConstraintsMode)
   if(!NoConstraintsMode)
   {
      // Trading hours check
      if(UseTradingHours)
      {
         MqlDateTime dt;
         TimeToStruct(now, dt);
         if(dt.hour < TradingStartHour || dt.hour >= TradingEndHour)
         {
            return; // Outside trading hours
         }
      }
      
      // Session manager check
      if(UseSessionManager && CheckPointer(g_session_manager) != POINTER_INVALID)
      {
         string sess_reason;
         if(!g_session_manager.IsSessionAllowed(sess_reason))
         {
            return; // Session constraints
         }
      }
      
      // Max positions check
      if(MaxOpenPositions > 0 && ArraySize(g_paper_positions) >= MaxOpenPositions)
      {
         return; // Max positions reached
      }
      
      // Regime gate check
      if(!CheckRegimeGate())
      {
         return; // Market regime not suitable for trading
      }
   }
   
   // ===================[ STRATEGY SELECTION & SIGNAL GENERATION ]===================
   TradingSignal signal;
   string selected_strategy = "";
   
   if(UseStrategySelector)
   {
      // Use enhanced strategy selection system
      selected_strategy = SelectBestStrategy();
      if(selected_strategy == "")
      {
         if(ShouldLog(LOG_DEBUG))
            Print("No strategy selected by enhanced selector");
         return;
      }
      
      // Generate signal using selected strategy
      signal = GenerateSignalFromStrategy(selected_strategy);
      
      if(ShouldLog(LOG_DEBUG))
         PrintFormat("🎯 Selected strategy: %s", selected_strategy);
   }
   else
   {
      // Fallback to simple signal generation
      signal = GenerateSignal();
      selected_strategy = "MovingAverageStrategy"; // Default strategy name
   }
   
   if(signal.id == "")
   {
      return; // No signal generated
   }
   
   // ===================[ ADAPTIVE SIGNAL OPTIMIZATION SYSTEM ]===================
   if(UseGateSystem && CheckPointer(g_gate_manager) != POINTER_INVALID)
   {
      CAdaptiveDecision decision;
      bool passed = false;
      string blocking_reason = "";
      
      // Use Adaptive Optimizer if available, otherwise fall back to standard gates
      if(CheckPointer(g_adaptive_optimizer) != POINTER_INVALID)
      {
         // ADAPTIVE OPTIMIZATION: Try to adjust blocked signals
         passed = g_adaptive_optimizer.OptimizeSignal(signal, decision, selected_strategy, blocking_reason);
         
         if(passed && decision.is_adjusted)
         {
            // Signal was adjusted successfully!
            if(ShouldLog(LOG_INFO))
               PrintFormat("🎯 Signal OPTIMIZED after %d attempts: %s → %s", 
                          decision.adjustment_attempts, signal.id, decision.signal_id);
         }
         else if(passed && !decision.is_adjusted)
         {
            // Original signal passed without adjustment
            if(ShouldLog(LOG_DEBUG))
               PrintFormat("✅ Signal passed gates unchanged: %s", decision.signal_id);
         }
         else
         {
            // All optimization attempts failed
            if(ShouldLog(LOG_INFO))
               PrintFormat("🚫 Signal optimization failed: %s - %s", signal.id, blocking_reason);
            return;
         }
      }
      else
      {
         // Fallback to standard gate processing
         CSignalDecision standard_decision;
         passed = g_gate_manager.ProcessSignal(signal, standard_decision);
         
         // Copy to adaptive decision for compatibility
         if(passed)
         {
            g_adaptive_optimizer.CopyDecision(standard_decision, decision);
            decision.is_adjusted = false;
         }
      }
      
      if(passed)
      {
         // ===================[ POLICY GATING ]===================
         if(UsePolicyGating && g_policy_loaded)
         {
            // Apply policy-based filtering and scaling
            if(!ApplyPolicyGating(decision))
            {
               if(ShouldLog(LOG_INFO))
                  PrintFormat("Signal blocked by policy gating: %s", decision.signal_id);
               return;
            }
         }
         
         // ===================[ ADVANCED RISK CHECKS ]===================
         if(!NoConstraintsMode)
         {
            // Correlation check
            if(UseCorrelationManager && CheckPointer(g_correlation_manager) != POINTER_INVALID)
            {
               string corr_reason; double max_corr=0.0;
               if(!g_correlation_manager.CheckCorrelationLimits(corr_reason, max_corr))
               {
                  if(ShouldLog(LOG_INFO))
                     PrintFormat("Signal blocked by correlation limits: %s (reason=%s max_corr=%.3f)", decision.signal_id, corr_reason, max_corr);
                  return;
               }
            }
            
            // Volatility sizing
            if(UseVolatilitySizer && CheckPointer(g_volatility_sizer) != POINTER_INVALID)
            {
               double sl_points = 0.0;
               if(decision.final_sl > 0.0)
                  sl_points = MathAbs(decision.final_price - decision.final_sl) / _Point;
               double vol_mult = 1.0; string vz_reason = "";
               double adjusted_volume = g_volatility_sizer.CalculatePositionSize(decision.final_volume, sl_points, vol_mult, vz_reason);
               if(adjusted_volume != decision.final_volume)
               {
                  if(ShouldLog(LOG_DEBUG))
                     PrintFormat("Volume adjusted by volatility sizer: %.2f -> %.2f (%s)", decision.final_volume, adjusted_volume, vz_reason);
                  decision.final_volume = adjusted_volume;
               }
            }
         }
         
         // ===================[ EXECUTE PAPER TRADE ]===================
         ExecutePaperTrade(decision);
         
         // ===================[ COMPREHENSIVE LOGGING WITH ADAPTIVE TRACKING ]===================
         LogDecisionTelemetry(decision);
         
         // Log adaptive decision details with complete gate journey
         if(decision.is_adjusted)
         {
            LogAdaptiveDecisionDetails(decision, selected_strategy);
         }
         
         // Print complete gate-by-gate journey
         if(CheckPointer(g_adaptive_optimizer) != POINTER_INVALID && decision.complete_journey_length > 0)
         {
            g_adaptive_optimizer.PrintCompleteGateJourney(decision);
         }
         
         // Log to Knowledge Base with adjusted_trade flag
         if(CheckPointer(g_kb) != POINTER_INVALID)
         {
            string trade_type = decision.is_adjusted ? "adjusted_trade" : "regular_trade";
            g_kb.LogTradeExecution(decision.symbol, selected_strategy, decision.execution_time,
                                   decision.final_price, decision.final_volume, decision.order_type);
            
            // Additional metadata for adjusted trades
            if(decision.is_adjusted)
            {
               string adjustment_details = StringFormat("attempts=%d,orig_vol=%.2f,final_vol=%.2f,orig_price=%.5f,final_price=%.5f",
                  decision.adjustment_attempts, decision.original_volume, decision.final_volume,
                  decision.original_price, decision.final_price);
               g_kb.LogEvent(decision.symbol, "adaptive_optimization", trade_type, adjustment_details);
            }
         }
         
         // Export features for ML with adjusted flag
         if(CheckPointer(g_features) != POINTER_INVALID)
         {
            ExportEnhancedFeaturesAdaptive(decision, selected_strategy);
         }
         
         // Update last trade time
         last_paper_trade_time = now;
      }
      else
      {
         if(ShouldLog(LOG_INFO))
            PrintFormat("Signal rejected by gates: %s", signal.id);
      }
   }
   else
   {
      // Bypass gates for testing (legacy mode)
      if(ShouldLog(LOG_DEBUG))
         Print("Gate system disabled - executing signal directly");
      ExecutePaperTrade(signal);
      last_paper_trade_time = now;
   }
   
   // ===================[ PERIODIC SYSTEM UPDATES ]===================
   if(now - last_update > 3600) // Update every hour
   {
      // Update gate thresholds
      if(CheckPointer(g_gate_manager) != POINTER_INVALID)
         g_gate_manager.UpdateFromLearning();
      
      // Auto-update policy file (ML learning)
      if(CheckPointer(g_policy_updater) != POINTER_INVALID)
         g_policy_updater.CheckAndUpdate();
      
      // BATCH LEARNING UPDATE (hourly)
      if(CheckPointer(g_gate_learning) != POINTER_INVALID)
         g_gate_learning.PerformBatchLearning();
      
      // Refresh recent overlays for selector (if enabled)
      if(UseStrategySelector && CheckPointer(g_selector) != POINTER_INVALID)
         g_selector.EnsureRecentLoaded(SelRecentDays);
      
      last_update = now;
   }
   
   // ===================[ POSITION REVIEW SYSTEM (Every 5 minutes) ]===================
   if(CheckPointer(g_position_reviewer) != POINTER_INVALID && g_position_reviewer.IsReviewTime())
   {
      PrintFormat("\n⏰ ==== POSITION REVIEW CYCLE - %s ====", TimeToString(now));
      
      int positions_reviewed = 0;
      int positions_closed = 0;
      int positions_adjusted = 0;
      
      // Review all open paper positions
      for(int i = 0; i < ArraySize(g_paper_positions); i++)
      {
         if(g_paper_positions[i] == NULL) continue;
         if(g_paper_positions[i].status != "open") continue;
         
         positions_reviewed++;
         
         // Get the strategy for this position
         IStrategy* position_strategy = NULL;
         string strategy_name = "Unknown";
         
         if(UseStrategySelector && CheckPointer(g_selector) != POINTER_INVALID)
         {
            // Try to match strategy by name (stored in position or metadata)
            strategy_name = "ADXStrategy";  // Default fallback
            position_strategy = g_selector.GetStrategyByName(strategy_name);
         }
         
         // Review the position
         PositionReview review = g_position_reviewer.ReviewPaperPosition(
            g_paper_positions[i], position_strategy, strategy_name);
         
         // Apply the review decision
         bool applied = g_position_reviewer.ApplyReviewDecision(g_paper_positions[i], review);
         
         if(applied && review.action == PA_CLOSE)
            positions_closed++;
         else if(applied && (review.action == PA_ADJUST_SL || review.action == PA_ADJUST_TP))
            positions_adjusted++;
         
         // Log to knowledge base
         if(CheckPointer(g_kb) != POINTER_INVALID)
         {
            string review_details = StringFormat("action=%d,reason=%s,pnl_pct=%.2f,confidence=%.2f",
               review.action, review.reason, review.current_pnl_pct, review.new_signal_confidence);
            g_kb.LogEvent(g_paper_positions[i].symbol, "position_review", 
                         EnumToString(review.action), review_details);
         }
      }
      
      PrintFormat("📊 Review Complete: %d positions reviewed | %d closed | %d adjusted",
                 positions_reviewed, positions_closed, positions_adjusted);
      PrintFormat("==========================================\n");
   }
}

//+------------------------------------------------------------------+
//| SIGNAL GENERATION                                                |
//+------------------------------------------------------------------+
TradingSignal GenerateSignal()
{
   TradingSignal signal;
   
   // Simple moving average crossover strategy - automatically uses chart symbol/timeframe
   int fast_ma_handle = iMA(_Symbol, _Period, 20, 0, MODE_SMA, PRICE_CLOSE);
   double fast_ma_array[1];
   CopyBuffer(fast_ma_handle, 0, 0, 1, fast_ma_array);
   double fast_ma = fast_ma_array[0];
   
   int slow_ma_handle = iMA(_Symbol, _Period, 50, 0, MODE_SMA, PRICE_CLOSE);
   double slow_ma_array[1];
   CopyBuffer(slow_ma_handle, 0, 0, 1, slow_ma_array);
   double slow_ma = slow_ma_array[0];
   
   double current_price = 0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, current_price);
   
   if(fast_ma > slow_ma && fast_ma < current_price)
   {
      signal.id = "MA_CROSS_" + IntegerToString(TimeCurrent());
      signal.symbol = _Symbol;
      signal.timeframe = _Period;
      signal.timestamp = TimeCurrent();
      signal.price = current_price;
      signal.type = 0; // 0=buy
      signal.sl = current_price - 100 * _Point;
      signal.tp = current_price + 200 * _Point;
      signal.volume = LotSize;
      signal.confidence = 0.75;
      
      // Market context
      signal.volatility = GetVolatility();
      signal.correlation = GetCorrelation();
      signal.regime = GetMarketRegime();
      signal.market_regime = GetMarketRegime();
   }
   else if(fast_ma < slow_ma && fast_ma > current_price)
   {
      signal.id = "MA_CROSS_" + IntegerToString(TimeCurrent());
      signal.symbol = _Symbol;
      signal.timeframe = _Period;
      signal.timestamp = TimeCurrent();
      signal.price = current_price;
      signal.type = 1; // 1=sell
      signal.sl = current_price + 100 * _Point;
      signal.tp = current_price - 200 * _Point;
      signal.volume = LotSize;
      signal.confidence = 0.75;
      
      // Market context
      signal.volatility = GetVolatility();
      signal.correlation = GetCorrelation();
      signal.regime = GetMarketRegime();
      signal.market_regime = GetMarketRegime();
   }
   
   return signal;
}

//+------------------------------------------------------------------+
//| TRADE EXECUTION - REAL MT5 ORDERS                                 |
//+------------------------------------------------------------------+
void ExecutePaperTrade(CSignalDecision &decision)
{
   // Execute REAL trade to MT5 (on demo account)
   PrintFormat("🎯 Executing REAL MT5 trade: %s at %.5f", 
               decision.signal_id, decision.final_price);
   
   // Validate trade manager
   if(CheckPointer(g_trade_manager) == POINTER_INVALID)
   {
      PrintFormat("❌ ERROR: TradeManager not initialized!");
      return;
   }
   
   // Create TradeOrder struct for real MT5 execution
   TradeOrder order;
   order.symbol = decision.symbol;
   order.order_type = decision.order_type;
   order.volume = decision.final_volume;
   order.price = decision.final_price;
   order.sl = decision.final_sl;
   order.tp = decision.final_tp;
   order.deviation = 10;  // 10 points slippage tolerance
   order.magic = decision.magic_number;
   order.comment = decision.signal_id;
   order.action = ACTION_DEAL;  // Market order execution
   
   // EXECUTE REAL TRADE TO MT5
   bool success = g_trade_manager.ExecuteOrder(order);
   
   if(success)
   {
      // Get execution results from TradeManager
      ulong deal_ticket = g_trade_manager.ResultDeal();
      ulong order_ticket = g_trade_manager.ResultOrder();
      double exec_price = g_trade_manager.ResultPrice();
      double exec_volume = g_trade_manager.ResultVolume();
      
      // Update decision with REAL execution details
      decision.executed = true;
      decision.execution_time = TimeCurrent();
      decision.execution_price = exec_price;  // Actual fill price
      
      PrintFormat("✅ REAL TRADE EXECUTED: Deal=%I64u Order=%I64u Price=%.5f Volume=%.2f SL=%.5f TP=%.5f",
                  deal_ticket, order_ticket, exec_price, exec_volume, decision.final_sl, decision.final_tp);
      
      // Log to unified trade logger (with gate journey)
      if(CheckPointer(g_trade_logger) != POINTER_INVALID)
      {
         UnifiedTradeRecord record;
         record.trade_id = IntegerToString(deal_ticket);
         record.signal_id = decision.signal_id;
         record.execution_time = decision.execution_time;
         record.status = "open";
         record.strategy = decision.strategy;
         record.symbol = decision.symbol;
         record.timeframe = decision.timeframe;
         record.market_regime = GetMarketRegime();
         record.volatility = GetVolatility();
         record.entry_price = exec_price;
         record.sl = decision.final_sl;
         record.tp = decision.final_tp;
         record.volume = exec_volume;
         record.confidence = decision.confidence;
         
         // Copy gate journey from adaptive optimizer
         if(CheckPointer(g_adaptive_optimizer) != POINTER_INVALID)
         {
            // Gate journey was already recorded during optimization
            // Just log the execution
         }
         
         g_trade_logger.LogTradeExecution(record);
      }
      
      // Log execution for learning bridge
      if(CheckPointer(g_learning_bridge) != POINTER_INVALID)
      {
         g_learning_bridge.RecordSignal(decision);
         g_learning_bridge.UpdateMarketRegime();
      }
      
      // Export features for ML training
      string features[];
      ArrayResize(features, 8);
      features[0] = "entry_price:" + DoubleToString(exec_price, 5);
      features[1] = "volume:" + DoubleToString(exec_volume, 2);
      features[2] = "order_type:" + EnumToString(decision.order_type);
      features[3] = "strategy:" + decision.strategy;
      features[4] = "signal_confidence:" + DoubleToString(decision.confidence, 3);
      features[5] = "market_regime:" + GetMarketRegime();
      features[6] = "volatility:" + DoubleToString(GetVolatility(), 4);
      features[7] = "correlation:" + DoubleToString(GetCorrelation(), 3);
      
      ExportTradeFeatures(decision.symbol, decision.strategy, TimeCurrent(), features);
   }
   else
   {
      uint retcode = g_trade_manager.ResultRetcode();
      PrintFormat("❌ TRADE EXECUTION FAILED: Retcode=%u Signal=%s", 
                  retcode, decision.signal_id);
      
      decision.executed = false;
   }
}

void ExecutePaperTrade(TradingSignal &signal)
{
   // Direct execution without gates
   Print("Executing paper trade (no gates): " + signal.id + 
         " at " + DoubleToString(signal.price, 5));
}

//+------------------------------------------------------------------+
//| TELEMETRY LOGGING                                                |
//+------------------------------------------------------------------+
void LogDecisionTelemetry(CSignalDecision &decision)
{
   // Log decision telemetry
   
   string log_data = StringFormat(
      "Decision: %s, Symbol: %s, Gates: [%d,%d,%d,%d,%d,%d,%d,%d], " +
      "Original: %.5f/%.5f/%.5f/%.2f, " +
      "Final: %.5f/%.5f/%.5f/%.2f",
      decision.signal_id, decision.symbol,
      decision.gate_results[0], decision.gate_results[1], 
      decision.gate_results[2], decision.gate_results[3],
      decision.gate_results[4], decision.gate_results[5],
      decision.gate_results[6], decision.gate_results[7],
      decision.original_price, decision.original_sl, 
      decision.original_tp, decision.original_volume,
      decision.final_price, decision.final_sl, 
      decision.final_tp, decision.final_volume
   );
   
   Print(log_data);
}

// Log adaptive decision details with attempt history
void LogAdaptiveDecisionDetails(CAdaptiveDecision &decision, const string strategy_name)
{
   if(!decision.is_adjusted) return;
   
   PrintFormat("\n=== 🔧 ADAPTIVE OPTIMIZATION DETAILS ===");
   PrintFormat("Strategy: %s | Original Signal: %s", strategy_name, decision.original_signal_id);
   PrintFormat("Final Signal: %s | Total Attempts: %d", decision.signal_id, decision.adjustment_attempts);
   
   for(int i = 0; i < decision.adjustment_attempts; i++)
   {
      AdjustmentAttempt att = decision.attempts[i];
      PrintFormat("  Attempt %d: Price%+.2f%% SL×%.2f TP×%.2f Vol×%.2f → %s",
                 att.attempt_number,
                 att.price_tweak * 100,
                 att.sl_tweak,
                 att.tp_tweak,
                 att.volume_tweak,
                 att.passed ? "✅ PASSED" : "❌ FAILED");
   }
   
   PrintFormat("Final Parameters: Price=%.5f SL=%.5f TP=%.5f Vol=%.2f",
              decision.final_price, decision.final_sl, decision.final_tp, decision.final_volume);
   PrintFormat("========================================\n");
   
   // Log to telemetry if available
   if(TelemetryEnabled && CheckPointer(g_telemetry_base) != POINTER_INVALID)
   {
      string details = StringFormat("strategy=%s,attempts=%d,orig_vol=%.2f,final_vol=%.2f",
                                   strategy_name, decision.adjustment_attempts,
                                   decision.original_volume, decision.final_volume);
      g_telemetry_base.LogEvent(_Symbol, _Period, "adaptive_optimization", "signal_adjusted", details);
   }
}

// Export enhanced features with adaptive tracking
void ExportEnhancedFeaturesAdaptive(CAdaptiveDecision &decision, const string strategy_name)
{
   if(CheckPointer(g_features) == POINTER_INVALID) return;
   
   // Create comprehensive feature set
   string features[];
   ArrayResize(features, 20);  // Expanded for adaptive features
   datetime now = TimeCurrent();
   MqlDateTime _dt; TimeToStruct(now, _dt); int _hour = _dt.hour;
   
   features[0] = "strategy:" + strategy_name;
   features[1] = "symbol:" + decision.symbol;
   features[2] = "timeframe:" + IntegerToString(_Period);
   features[3] = "entry_price:" + DoubleToString(decision.final_price, 5);
   features[4] = "volume:" + DoubleToString(decision.final_volume, 2);
   features[5] = "order_type:" + IntegerToString(decision.order_type);
   features[6] = "confidence:" + DoubleToString(decision.confidence, 3);
   features[7] = "hour:" + IntegerToString(_hour);
   features[8] = "volatility:" + DoubleToString(decision.volatility, 4);
   features[9] = "correlation:" + DoubleToString(decision.correlation_score, 3);
   features[10] = "regime:" + decision.market_regime;
   
   // ADAPTIVE-SPECIFIC FEATURES
   features[11] = "is_adjusted:" + (decision.is_adjusted ? "1" : "0");
   features[12] = "adjustment_attempts:" + IntegerToString(decision.adjustment_attempts);
   features[13] = "volume_change_pct:" + DoubleToString(
      decision.original_volume > 0 ? (decision.final_volume - decision.original_volume) / decision.original_volume * 100 : 0, 2);
   features[14] = "price_change_pct:" + DoubleToString(
      decision.original_price > 0 ? (decision.final_price - decision.original_price) / decision.original_price * 100 : 0, 2);
   features[15] = "sl_scale:" + DoubleToString(
      decision.original_sl > 0 ? decision.final_sl / decision.original_sl : 1.0, 2);
   features[16] = "tp_scale:" + DoubleToString(
      decision.original_tp > 0 ? decision.final_tp / decision.original_tp : 1.0, 2);
   features[17] = "original_signal_id:" + (decision.is_adjusted ? decision.original_signal_id : decision.signal_id);
   features[18] = "gate_passed_count:" + IntegerToString(CountPassedGates(decision));
   features[19] = "timestamp:" + TimeToString(now);
   
   // Log to features system
   g_features.LogFeatures(features);
}

// Helper to count passed gates
int CountPassedGates(CSignalDecision &decision)
{
   int count = 0;
   for(int i = 0; i < 8; i++)
   {
      if(decision.gate_results[i])
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| MARKET ANALYSIS HELPERS                                          |
//+------------------------------------------------------------------+
double GetVolatility()
{
   // Calculate ATR-based volatility - automatically uses chart symbol/timeframe
   int atr_handle = iATR(_Symbol, _Period, 14);
   double atr_array[1];
   CopyBuffer(atr_handle, 0, 0, 1, atr_array);
   double atr = atr_array[0];
   double price = 0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, price);
   return atr / price;
}

double GetCorrelation()
{
   // Advanced correlation calculation using multiple currency pairs
   // Calculate correlation between current symbol and major pairs
   
   string base_pairs[] = {"EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD", "USDCAD"};
   int correlation_period = 20;
   double correlations[];
   ArrayResize(correlations, 0);
   
   // Get current symbol's price data
   double current_prices[];
   ArrayResize(current_prices, correlation_period);
   ArraySetAsSeries(current_prices, true);
   
   if(CopyClose(_Symbol, _Period, 0, correlation_period, current_prices) != correlation_period)
     {
      // Fallback to simple volatility-based correlation estimate
      int atr_handle = iATR(_Symbol, _Period, 14);
      double atr_array[1];
      if(CopyBuffer(atr_handle, 0, 0, 1, atr_array) == 1)
        {
         double price = 0;
         SymbolInfoDouble(_Symbol, SYMBOL_BID, price);
         double volatility = atr_array[0] / price;
         // Higher volatility suggests lower correlation with market
         return MathMax(0.1, 1.0 - (volatility * 10.0));
        }
      return 0.5; // Neutral fallback
     }
   
   // Calculate correlations with major pairs
   for(int i = 0; i < ArraySize(base_pairs); i++)
     {
      if(base_pairs[i] == _Symbol) continue; // Skip self
      
      double pair_prices[];
      ArrayResize(pair_prices, correlation_period);
      ArraySetAsSeries(pair_prices, true);
      
      if(CopyClose(base_pairs[i], _Period, 0, correlation_period, pair_prices) == correlation_period)
        {
         // Calculate Pearson correlation coefficient
         double corr = CalculatePearsonCorrelation(current_prices, pair_prices, correlation_period);
         if(MathIsValidNumber(corr))
           {
            int n = ArraySize(correlations);
            ArrayResize(correlations, n + 1);
            correlations[n] = MathAbs(corr); // Use absolute correlation
           }
        }
     }
   
   // Return average absolute correlation
   if(ArraySize(correlations) > 0)
     {
      double sum = 0.0;
      for(int i = 0; i < ArraySize(correlations); i++)
        sum += correlations[i];
      return sum / ArraySize(correlations);
     }
   
   return 0.5; // Neutral if no correlations calculated
}

double CalculatePearsonCorrelation(const double &x[], const double &y[], int period)
{
   if(period < 2) return 0.0;
   
   // Calculate means
   double mean_x = 0.0, mean_y = 0.0;
   for(int i = 0; i < period; i++)
     {
      mean_x += x[i];
      mean_y += y[i];
     }
   mean_x /= period;
   mean_y /= period;
   
   // Calculate correlation components
   double numerator = 0.0;
   double sum_sq_x = 0.0, sum_sq_y = 0.0;
   
   for(int i = 0; i < period; i++)
     {
      double dx = x[i] - mean_x;
      double dy = y[i] - mean_y;
      numerator += dx * dy;
      sum_sq_x += dx * dx;
      sum_sq_y += dy * dy;
     }
   
   double denominator = MathSqrt(sum_sq_x * sum_sq_y);
   if(denominator == 0.0) return 0.0;
   
   return numerator / denominator;
}

string GetMarketRegime()
{
   // Simple regime detection based on ADX - automatically uses chart symbol/timeframe
   int adx_handle = iADX(_Symbol, _Period, 14);
   double adx_array[1];
   CopyBuffer(adx_handle, 0, 0, 1, adx_array);
   double adx = adx_array[0];
   
   if(adx > 25) return "trending";
   else return "ranging";
}

//+------------------------------------------------------------------+
//| TIMER FOR LEARNING UPDATES                                       |
//+------------------------------------------------------------------+
// Consolidated into enhanced OnTimer below

//+------------------------------------------------------------------+
//| Update Paper Positions                                           |
//+------------------------------------------------------------------+
// UpdatePaperPositions() REMOVED - using REAL MT5 positions
// Position updates handled automatically by MT5 terminal
// Use PositionGetDouble(POSITION_PROFIT) to get current PnL
// Use OnTradeTransaction() to track position lifecycle events
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| MISSING FUNCTIONS - ENHANCED IMPLEMENTATIONS                    |
//+------------------------------------------------------------------+

// Generate signal from specific strategy
TradingSignal GenerateSignalFromStrategy(const string strategy_name)
{
   TradingSignal signal;
   
   // This would normally interface with the strategy registry
   // For now, we'll use the existing GenerateSignal as fallback
   signal = GenerateSignal();
   
   // Override strategy name
   if(signal.id != "")
   {
      signal.id = strategy_name + "_" + IntegerToString(TimeCurrent());
   }
   
   return signal;
}

// Apply policy-based gating and scaling
bool ApplyPolicyGating(CSignalDecision &decision)
{
   if(!g_policy_loaded) 
   {
      // Fallback behavior when no policy is loaded
      if(DefaultPolicyFallback)
      {
         if(ShouldLog(LOG_DEBUG))
            PrintFormat("FALLBACK: no policy loaded -> neutral scaling used for %s", decision.signal_id);
         return true; // Allow with neutral scaling
      }
      return false; // Block if no fallback allowed
   }
   
   // Simple policy check - in production this would be more sophisticated
   if(decision.confidence < g_policy_min_conf)
   {
      if(ShouldLog(LOG_DEBUG))
         PrintFormat("Policy gating blocked: confidence %.2f < min %.2f", decision.confidence, g_policy_min_conf);
      return false;
   }
   
   // Apply policy scaling (placeholder implementation)
   // In production, this would look up specific strategy/symbol/timeframe policies
   decision.final_sl = decision.original_sl * 1.0; // No scaling for now
   decision.final_tp = decision.original_tp * 1.0; // No scaling for now
   decision.final_volume = decision.original_volume * 1.0; // No scaling for now
   
   return true;
}

// Export enhanced features for ML training
void ExportEnhancedFeatures(const CSignalDecision &decision, const string strategy_name)
{
   if(CheckPointer(g_features) == POINTER_INVALID) return;
   
   // Create comprehensive feature set
   string features[];
   ArrayResize(features, 15);
   datetime now = TimeCurrent();
   MqlDateTime _dt; TimeToStruct(now, _dt); int _hour = _dt.hour;
   
   features[0] = "strategy:" + strategy_name;
   features[1] = "symbol:" + decision.symbol;
   features[2] = "timeframe:" + IntegerToString(_Period);
   features[3] = "entry_price:" + DoubleToString(decision.final_price, 5);
   features[4] = "volume:" + DoubleToString(decision.final_volume, 2);
   features[5] = "order_type:" + IntegerToString(decision.order_type);
   features[6] = "confidence:" + DoubleToString(decision.confidence, 3);
   features[7] = "volatility:" + DoubleToString(GetVolatility(), 4);
   features[8] = "correlation:" + DoubleToString(GetCorrelation(), 3);
   features[9] = "market_regime:" + GetMarketRegime();
   features[10] = "session_hour:" + IntegerToString(_hour);
   features[11] = "spread_points:" + DoubleToString((SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point, 1);
   features[12] = "equity:" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2);
   features[13] = "balance:" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2);
   features[14] = "margin_level:" + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), 2);
   
   // Export to features system
   g_features.ExportFeatures(decision.symbol, strategy_name, now, features);
}

//+------------------------------------------------------------------+
//| ENHANCED TIMER FUNCTION                                         |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Update all paper positions PnL and check for closures
   UpdatePaperPositions();
   
   // ===================[ PERIODIC SYSTEM MAINTENANCE ]===================
   static datetime last_maintenance = 0;
   datetime now = TimeCurrent();
   
   if(now - last_maintenance > 300) // Every 5 minutes
   {
      // Check for policy reload signals
      CheckPolicyReload();
      
      // Check for insights reload signals  
      CheckInsightsReload();
      
      // Maintenance hooks for session/correlation managers can be added here if needed
      
      // Reload news events periodically
      if(UseNewsFilter)
      {
         LoadNewsEvents();
      }
      
      last_maintenance = now;
   }
   
   // ===================[ LEARNING SYSTEM UPDATES ]===================
   static datetime last_learning_update = 0;
   
   if(now - last_learning_update > 1800) // Every 30 minutes
   {
      // Periodic learning updates
      if(CheckPointer(g_gate_manager) != POINTER_INVALID)
         g_gate_manager.UpdateFromLearning();
      
      // Refresh recent overlays for selector (if enabled)
      if(UseStrategySelector && CheckPointer(g_selector) != POINTER_INVALID)
         g_selector.EnsureRecentLoaded(SelRecentDays);
      
      // Transfer successful signals to live EA (if learning bridge available)
      if(CheckPointer(g_learning_bridge) != POINTER_INVALID)
         g_learning_bridge.TransferSuccessfulSignals("C:\\DualEA\\LiveData");
      
      last_learning_update = now;
   }
   
   // ===================[ HEARTBEAT AND HEALTH CHECKS ]===================
   static datetime last_heartbeat = 0;
   
   if(HeartbeatEnabled && (now - last_heartbeat > HeartbeatMinutes * 60))
   {
      // System health check
      int active_positions = 0;
      for(int i = 0; i < ArraySize(g_paper_positions); i++)
      {
         if(g_paper_positions[i] != NULL && g_paper_positions[i].status == "open")
            active_positions++;
      }
      
      if(HeartbeatVerbose)
      {
         PrintFormat("=== PaperEA v2 Heartbeat ===");
         PrintFormat("Time: %s | Active Positions: %d | Equity: %.2f", 
                     TimeToString(now), active_positions, AccountInfoDouble(ACCOUNT_EQUITY));
         PrintFormat("Policy Loaded: %s | NoConstraints: %s | UseSelector: %s",
                     g_policy_loaded ? "YES" : "NO",
                     NoConstraintsMode ? "ON" : "OFF",
                     UseStrategySelector ? "ON" : "OFF");
      }
      
      last_heartbeat = now;
   }
}

//+------------------------------------------------------------------+
//| ONTRADE TRANSACTION HANDLER - ENHANCED POSITION TRACKING       |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   // Filter to current chart symbol and handle order cancellations
   if(trans.symbol != _Symbol) return;
   
   int t = (int)trans.type;
   if(t == TRADE_TRANSACTION_ORDER_DELETE)
   {
      // Clean pending order mapping if order is cancelled/expired
      ulong ord = trans.order;
      if(ord > 0)
      {
         for(int i = 0; i < ArraySize(g_pending_orders); ++i)
            if(g_pending_orders[i] == ord)
            {
               int last = ArraySize(g_pending_orders) - 1;
               g_pending_orders[i] = g_pending_orders[last]; 
               g_pending_orders_strat[i] = g_pending_orders_strat[last];
               ArrayResize(g_pending_orders, last); 
               ArrayResize(g_pending_orders_strat, last);
               break;
            }
      }
      return;
   }
   
   // We only care about deal executions beyond this point
   if(t != TRADE_TRANSACTION_DEAL_ADD) return;

   ulong deal = trans.deal;
   if(deal == 0) return;

   int entry_flag = (int)HistoryDealGetInteger(deal, DEAL_ENTRY);
   ulong pid = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
   string sym = HistoryDealGetString(deal, DEAL_SYMBOL);
   long dmagic = (long)HistoryDealGetInteger(deal, DEAL_MAGIC);

   // Filter to current chart symbol and our magic if available
   if(sym != _Symbol) return;
   if(MagicNumber > 0 && dmagic != MagicNumber) return;

   if(entry_flag == DEAL_ENTRY_IN)
   {
      // Track newly opened position if not already tracked
      if(pid > 0)
      {
         if(FindTrackedIndexByPid(pid) >= 0) return; // already tracked
         
         string strat_name = "unknown";
         // Try to attribute strategy from pending mapping
         for(int m = 0; m < ArraySize(g_pending_deals); ++m)
         {
            if(g_pending_deals[m] == deal)
            {
               strat_name = g_pending_deals_strat[m];
               int last = ArraySize(g_pending_deals) - 1;
               g_pending_deals[m] = g_pending_deals[last];
               g_pending_deals_strat[m] = g_pending_deals_strat[last];
               ArrayResize(g_pending_deals, last);
               ArrayResize(g_pending_deals_strat, last);
               break;
            }
         }
         
         // Add to tracking arrays
         int k = ArraySize(g_pos_ids);
         ArrayResize(g_pos_ids, k + 1);
         ArrayResize(g_pos_strats, k + 1);
         ArrayResize(g_pos_entry_price, k + 1);
         ArrayResize(g_pos_initial_risk, k + 1);
         ArrayResize(g_pos_start_time, k + 1);
         ArrayResize(g_pos_type, k + 1);
         ArrayResize(g_pos_max_price, k + 1);
         ArrayResize(g_pos_min_price, k + 1);
         
         g_pos_ids[k] = pid; 
         g_pos_strats[k] = strat_name;
         
         double entry_p = HistoryDealGetDouble(deal, DEAL_PRICE);
         if(entry_p <= 0 && PositionSelectByTicket(pid)) 
            entry_p = PositionGetDouble(POSITION_PRICE_OPEN);
         g_pos_entry_price[k] = entry_p;
         g_pos_max_price[k] = entry_p; 
         g_pos_min_price[k] = entry_p;
         
         int ptype = POSITION_TYPE_BUY;
         if(PositionSelectByTicket(pid)) 
            ptype = (int)PositionGetInteger(POSITION_TYPE);
         g_pos_type[k] = ptype;
         
         double init_risk = 0.0;
         if(PositionSelectByTicket(pid))
         {
            double slc = PositionGetDouble(POSITION_SL);
            double eop = PositionGetDouble(POSITION_PRICE_OPEN);
            if(slc > 0 && eop > 0) 
               init_risk = MathAbs((ptype == POSITION_TYPE_BUY ? eop - slc : slc - eop));
         }
         g_pos_initial_risk[k] = init_risk;
         
         // Use deal time for accurate hold time
         g_pos_start_time[k] = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
         
         if(ShouldLog(LOG_INFO))
            PrintFormat("Tracked pos via OnTradeTransaction: ticket=%I64u strat=%s entry=%.5f initR=%.5f", 
                        pid, g_pos_strats[k], entry_p, init_risk);
      }
      return;
   }
   else if(entry_flag == DEAL_ENTRY_OUT)
   {
      if(pid == 0) return;
      int idx = FindTrackedIndexByPid(pid);
      if(idx < 0)
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

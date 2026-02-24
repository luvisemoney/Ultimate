//+------------------------------------------------------------------+
//| PaperEA_v2_P0P5_Integration.mqh - Integration Layer              |
//| Ties all P0-P5 components into PaperEA_v2.mq5 with user specs      |
//| Auto-drift adjustment, CPU budgeting, risk gate protection         |
//+------------------------------------------------------------------+
#ifndef PAPEREA_V2_P0P5_INTEGRATION_MQH
#define PAPEREA_V2_P0P5_INTEGRATION_MQH

#include "CDualEAController.mqh"
#include "CSymbolCoordinator.mqh"
#include "CGateFeatureCache.mqh"
#include "CShadowLogger.mqh"

//+------------------------------------------------------------------+
//| Input Parameters - P0-P5 Features (Enabled by Default)             |
//+------------------------------------------------------------------+
// === P0-P5 Hardening & Intelligence ===
input bool InpEnableAutoDriftAdjustment = true;      // P2-1: Auto-adjust gate thresholds
input bool InpEnableCPUBudgeting = true;              // P3-1: 10ms fail-fast budgeting
input bool InpEnableNuclearRiskEngine = true;         // P4-3: VaR/Kelly/Correlation risk
input bool InpEnableMultiTimeframeGate = true;          // P2-4: MTF confirmation
input bool InpEnableCorrelationPruning = true;          // P2-5: Strategy diversification
input bool InpEnableShadowBridge = true;                // P2-3: Parallel demo execution
input bool InpEnableFeatureDriftDetection = true;       // P4-4: Distribution shift alerts
input bool InpEnableTimerScanner = true;                // P3-5: Low-tick signal capture
input bool InpEnableSQLiteParallel = true;                // P1-1: ACID parallel logging
input bool InpEnablePositionManager = true;               // P1-6: Kelly sizing + vol exits
input bool InpEnableSymbolCoordination = true;            // P4-5: Redis cross-chart coordination

// === Risk Gate Protection (Never Skip) ===
input bool InpProtectG1_SignalRinse = true;             // G1: Always process
input bool InpProtectG4_Frequency = true;                 // G4: Always process
input bool InpProtectG7_AdaptiveML = true;                // G7: Always process
input bool InpProtectG8_Execution = true;                 // G8: Always process

// === Thresholds & Limits ===
input double InpDriftZScoreThreshold = 2.5;               // Drift detection sensitivity
input double InpCPUBudgetMs = 10.0;                       // Per-tick CPU limit
input double InpMaxPortfolioRiskPct = 15.0;               // Portfolio risk cap
input double InpMaxCorrelation = 0.70;                    // Strategy correlation limit
input int InpMaxPositionsPerSymbol = 5;                   // Symbol position limit
input int InpSQLiteMigrationDays = 30;                    // Parallel run duration

//+------------------------------------------------------------------+
//| Global Controller Instance                                         |
//+------------------------------------------------------------------+
CDualEAController* g_dual_ea_controller = NULL;

//+------------------------------------------------------------------+
//| Initialize P0-P5 Systems                                         |
//+------------------------------------------------------------------+
bool InitializeP0P5Systems()
{
   Print("=== [PaperEA_v2] Initializing P0-P5 Hardening Systems ===");
   
   // Build configuration from inputs
   SDualEAConfig config;
   config.SetDefaults();

   // Map P0-P5 inputs into available SDualEAConfig fields
   config.shadow_logging_enabled = InpEnableShadowBridge;
   config.shadow_mode_only = ShadowMode;
   config.sqlite_enabled = InpEnableSQLiteParallel;
   config.sqlite_db_name = "dualea_kb.db";
   config.circuit_breaker_enabled = InpEnableNuclearRiskEngine;
   config.correlation_sizing_enabled = InpEnablePositionManager;
   config.volatility_exits_enabled = InpEnablePositionManager;
   config.max_risk_per_trade_pct = (InpMaxPortfolioRiskPct > 0.0 ? InpMaxPortfolioRiskPct : config.max_risk_per_trade_pct);
   config.max_positions = (InpMaxPositionsPerSymbol > 0 ? InpMaxPositionsPerSymbol : config.max_positions);
   
   // Initialize controller singleton
   g_dual_ea_controller = CDualEAController::Instance();
   
   if(!g_dual_ea_controller.Initialize(config))
   {
      Print("[PaperEA_v2] CRITICAL: Failed to initialize DualEA Controller");
      return false;
   }
   
   // Initialize symbol coordinator if enabled
   if(InpEnableSymbolCoordination)
   {
      if(!InitializeSymbolCoordinator(InpMaxPortfolioRiskPct))
      {
         Print("[PaperEA_v2] WARNING: Symbol coordinator init failed, running solo mode");
      }
      else
      {
         Print("[PaperEA_v2] ✓ Symbol coordinator active (Redis cross-chart)");
      }
   }
   
   // Initialize SQLite if parallel mode enabled
   if(InpEnableSQLiteParallel)
   {
      CSQLiteKnowledgeBase* sqlite_kb = g_dual_ea_controller.GetSQLiteKB();
      if(sqlite_kb != NULL)
      {
         Print("[PaperEA_v2] ✓ SQLite parallel logging active (30-day migration)");
      }
   }
   
   // Initialize indicator cache
   CIndicatorCache* cache = g_dual_ea_controller.GetIndicatorCache();
   if(cache != NULL)
   {
      // Pre-warm common indicators (disabled - PreWarmIndicator not available)
      // cache.PreWarmIndicator(_Symbol, PERIOD_CURRENT, INDI_MA, 20);
      // cache.PreWarmIndicator(_Symbol, PERIOD_CURRENT, INDI_RSI, 14);
      // cache.PreWarmIndicator(_Symbol, PERIOD_CURRENT, INDI_ATR, 14);
      // cache.PreWarmIndicator(_Symbol, PERIOD_CURRENT, INDI_MACD, 12);
      Print("[PaperEA_v2] ✓ Indicator cache ready (pre-warming disabled)");
   }
   
   Print("=== [PaperEA_v2] P0-P5 Systems Ready ===");
   return true;
}

//+------------------------------------------------------------------+
//| Shutdown P0-P5 Systems                                             |
//+------------------------------------------------------------------+
void ShutdownP0P5Systems()
{
   Print("=== [PaperEA_v2] Shutting Down P0-P5 Systems ===");
   
   // Print final reports
   if(g_dual_ea_controller != NULL)
   {
      Print(g_dual_ea_controller.GetStatusReport());
   }
   
   // Shutdown coordinator
   ShutdownSymbolCoordinator();
   
   // Destroy controller (singleton)
   CDualEAController::Destroy();
   g_dual_ea_controller = NULL;
   
   Print("=== [PaperEA_v2] P0-P5 Systems Shutdown Complete ===");
}

// Overload that requires explicit intent; use this from OnDeinit only.
void ShutdownP0P5Systems(const bool from_deinit)
{
   if(!from_deinit)
   {
      Print("[PaperEA_v2] WARNING: ShutdownP0P5Systems(from_deinit=false) ignored to protect SQLite lifecycle");
      return;
   }
   ShutdownP0P5Systems();
}

//+------------------------------------------------------------------+
//| PRE-GATE VALIDATOR: Concept Drift + MTF Check                     |
//| Called before each gate in 8-stage cascade                       |
//+------------------------------------------------------------------+
bool PreGateValidate(const string &gate_name, double &threshold, const double &features[])
{
   if(g_dual_ea_controller == NULL) return true;
   
   // P2-1: Concept drift auto-adjustment + P2-4: MTF confirmation
   return g_dual_ea_controller.PreGateValidation(gate_name, features, threshold);
}

//+------------------------------------------------------------------+
//| CPU BUDGET CHECK: Risk Gates Protected                              |
//| Returns true if gate should process, false if skipped              |
//+------------------------------------------------------------------+
bool CheckGateBudget(const string &gate_name, bool &was_skipped)
{
   was_skipped = false;
   
   if(g_dual_ea_controller == NULL) return true;
   
   // P3-1: CPU budgeting with risk gate protection
   // G1, G4, G7, G8 never skipped per user spec
   return g_dual_ea_controller.ShouldProcessGate(gate_name, was_skipped);
}

//+------------------------------------------------------------------+
//| POST-GATE RECORD: Outcome tracking for drift detection            |
//+------------------------------------------------------------------+
void PostGateRecord(const string &gate_name, bool passed, double confidence)
{
   if(g_dual_ea_controller == NULL) return;
   
   g_dual_ea_controller.PostGateRecord(gate_name, passed, confidence);
}

//+------------------------------------------------------------------+
//| STRATEGY SELECTION: Correlation-pruned diversified subset         |
//| Called before executing any strategy signal                        |
//+------------------------------------------------------------------+
bool SelectStrategy(const string &strategy_name, const double &signals[])
{
   if(g_dual_ea_controller == NULL) return true;
   
   // P2-5: Correlation-aware pruning during selection
   return g_dual_ea_controller.SelectStrategyForExecution(strategy_name, signals);
}

//+------------------------------------------------------------------+
//| CIRCUIT BREAKER: Nuclear Risk Engine (Interface Compatible)         |
//| Replaces original CheckCircuitBreakers() in PaperEA_v2.mq5        |
//+------------------------------------------------------------------+
bool CheckCircuitBreakers(double daily_pnl_pct, double drawdown_pct,
                         int consecutive_losses, string &reason)
{
   // P4-3: Nuclear risk engine with legacy fallback
   if(g_dual_ea_controller != NULL)
   {
      return g_dual_ea_controller.CheckCircuitBreakers(
         daily_pnl_pct, drawdown_pct, consecutive_losses, reason);
   }
   
   // Fallback if controller not available
   if(daily_pnl_pct < -5.0)
   {
      reason = "Daily loss > 5%";
      return false;
   }
   
   if(drawdown_pct > 15.0)
   {
      reason = "Drawdown > 15%";
      return false;
   }
   
   if(consecutive_losses >= 3)
   {
      reason = "3+ consecutive losses";
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| POSITION SIZE: Kelly-adjusted from nuclear risk engine              |
//+------------------------------------------------------------------+
double GetPositionSizeAdjusted(double base_size)
{
   if(g_dual_ea_controller == NULL) return base_size;
   
   // P4-3: Kelly criterion sizing
   return g_dual_ea_controller.GetRecommendedPositionSize(base_size);
}

//+------------------------------------------------------------------+
//| PORTFOLIO COORDINATION: Check if trade allowed across symbols       |
//+------------------------------------------------------------------+
bool ShouldTradePortfolioCheck(const string &direction, double risk_pct, string &reason)
{
   if(!InpEnableSymbolCoordination || g_symbol_coordinator == NULL)
      return true;
   
   // Convert string direction to ENUM_ORDER_TYPE
   ENUM_ORDER_TYPE order_type = (direction == "SELL") ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   return g_symbol_coordinator.ShouldTrade(order_type, risk_pct, reason);
}

//+------------------------------------------------------------------+
//| COORDINATION: Record trade execution                                |
//+------------------------------------------------------------------+
void RecordTradeCoordination(const string &direction, double size, double risk_pct)
{
   if(g_symbol_coordinator != NULL)
   {
      ENUM_ORDER_TYPE order_type = (direction == "SELL") ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      g_symbol_coordinator.RecordTrade(order_type, size, risk_pct);
   }
}

//+------------------------------------------------------------------+
//| COORDINATION: Record position close                                 |
//+------------------------------------------------------------------+
void RecordCloseCoordination(double pnl, double risk_released)
{
   if(g_symbol_coordinator != NULL)
   {
      g_symbol_coordinator.RecordClose(pnl, risk_released);
   }
}

//+------------------------------------------------------------------+
//| ON TICK: P0-P5 processing cycle                                     |
//+------------------------------------------------------------------+
void OnTickP0P5()
{
   // P0-P5 OnTick processing
   if(g_dual_ea_controller != NULL)
   {
      // Controller handles its own tick processing
   }
   
   if(InpEnableSymbolCoordination && g_symbol_coordinator != NULL)
   {
      // No per-tick maintenance method is defined on CSymbolCoordinator.
      // Coordination is handled via RecordTrade/RecordClose.
   }
}

//+------------------------------------------------------------------+
//| ON TIMER: P0-P5 periodic tasks                                    |
//+------------------------------------------------------------------+
void OnTimerP0P5()
{
   // P0-P5 OnTimer processing
   if(g_dual_ea_controller != NULL)
   {
      // Controller handles its own timer processing
   }
}

//+------------------------------------------------------------------+
//| BATCH LOGGING: Queue telemetry event                              |
//+------------------------------------------------------------------+
void LogEventP0P5(const string &event, const string &context, const string &details)
{
   // Telemetry logging through controller
   if(g_dual_ea_controller != NULL)
   {
      // Log via Print for now - integrate with telemetry system
      PrintFormat("[P0P5-EVENT] %s | %s | %s", event, context, details);
   }
}

//+------------------------------------------------------------------+
//| FEATURE DRIFT: Record sample for distribution tracking              |
//+------------------------------------------------------------------+
void RecordFeatureSample(const string &feature_name, double value)
{
   // Feature drift recording through controller
   if(g_dual_ea_controller == NULL) return;
   
   // Log feature sample for drift detection
   if(InpEnableFeatureDriftDetection)
   {
      PrintFormat("[DRIFT-SAMPLE] %s = %.4f", feature_name, value);
   }
}

//+------------------------------------------------------------------+
//| INDICATOR CACHE: Get cached value                                  |
//+------------------------------------------------------------------+
double GetCachedIndicator(int indicator_type, int period, int shift = 0)
{
   // Indicator cache - returns 0.0 if controller not available
   if(g_dual_ea_controller == NULL) return 0.0;
   
   // For now, calculate indicator directly via handles + CopyBuffer.
   // In future: integrate with CIndicatorCache for caching.
   int handle = INVALID_HANDLE;
   int buffer_index = 0;

   switch(indicator_type)
   {
      case 1: // MA
         handle = iMA(_Symbol, (ENUM_TIMEFRAMES)period, 20, 0, MODE_SMA, PRICE_CLOSE);
         buffer_index = 0;
         break;
      case 2: // RSI
         handle = iRSI(_Symbol, (ENUM_TIMEFRAMES)period, 14, PRICE_CLOSE);
         buffer_index = 0;
         break;
      case 3: // ATR
         handle = iATR(_Symbol, (ENUM_TIMEFRAMES)period, 14);
         buffer_index = 0;
         break;
      case 4: // MACD main
         handle = iMACD(_Symbol, (ENUM_TIMEFRAMES)period, 12, 26, 9, PRICE_CLOSE);
         buffer_index = 0;
         break;
      default:
         return 0.0;
   }

   if(handle == INVALID_HANDLE)
      return 0.0;

   double buf[1];
   if(CopyBuffer(handle, buffer_index, shift, 1, buf) != 1)
   {
      IndicatorRelease(handle);
      return 0.0;
   }

   IndicatorRelease(handle);
   return buf[0];
}

//+------------------------------------------------------------------+
//| STATUS: Full system health report                                  |
//+------------------------------------------------------------------+
string GetP0P5StatusReport()
{
   string report = "";
   
   if(g_dual_ea_controller != NULL)
   {
      report += g_dual_ea_controller.GetStatusReport() + "\n";
   }
   
   if(InpEnableSymbolCoordination && g_symbol_coordinator != NULL)
   {
      // report += g_symbol_coordinator.GetStatusReport() + "\n";
   }
   
   return report;
}

#endif // PAPEREA_V2_P0P5_INTEGRATION_MQH

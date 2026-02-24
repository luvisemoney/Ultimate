//+------------------------------------------------------------------+
//| DualEA_MasterIntegration.mqh - Complete P0/P1 Integration        |
//| Master include file that initializes all hardened components      |
//| Version: 2.0 - Comprehensive EA Hardening & Intelligence Upgrade |
//+------------------------------------------------------------------+
#ifndef DUALEA_MASTERINTEGRATION_MQH
#define DUALEA_MASTERINTEGRATION_MQH

//+------------------------------------------------------------------+
//| P0 Components - Critical Fixes                                   |
//+------------------------------------------------------------------+
#include "CShadowLogger.mqh"           // P0-1: Atomic CSV writes
#include "CGateFeatureCache.mqh"       // P0-5: Feature caching

//+------------------------------------------------------------------+
//| P1 Components - Architecture Upgrades                              |
//+------------------------------------------------------------------+
#include "CSQLiteKnowledgeBase.mqh"    // P1-1: SQLite KB
#include "CInsightGateBridge.mqh"      // P1-2: O(1) insights bridge
#include "CRegimeAwareStrategy.mqh"    // P1-3: Regime adaptation
#include "CSystemMonitor.mqh"          // P1-4: Health circuit breaker
// Replaced Redis with SQLite - zero external dependencies
#include "CSQLiteExplorationCounter.mqh"// P1-5: Redis counters
#include "CPositionManager.mqh"        // P1-6: Correlation sizing

// Include existing components
#include "EnhancedEfficientGateSystem.mqh"
#include "CMLPolishGateONNX.mqh"

//+------------------------------------------------------------------+
//| Configuration Structure                                            |
//+------------------------------------------------------------------+
struct SDualEAConfig
{
   // P0-1: Shadow logging
   bool   shadow_logging_enabled;
   bool   shadow_mode_only;
   string shadow_log_directory;
   
   // P0-4: ONNX monitoring
   bool   onnx_health_monitor_enabled;
   int    onnx_max_latency_ms;
   
   // P0-5: Feature cache
   int    feature_cache_max_age_seconds;
   
   // P1-1: SQLite
   bool   sqlite_enabled;
   string sqlite_db_name;
   
   // P1-2: Insight bridge
   int    insight_cache_sync_seconds;
   
   // P1-4: System monitor
   bool   circuit_breaker_enabled;
   double max_tick_latency_ms;
   double max_error_rate_per_hour;
   int    circuit_breaker_cooldown_minutes;
   
   // P1-5: Redis
   bool   redis_enabled;
   string redis_host;
   int    redis_port;
   
   // P1-6: Position management
   bool   correlation_sizing_enabled;
   bool   volatility_exits_enabled;
   double max_risk_per_trade_pct;
   double max_total_risk_pct;
   int    max_positions;
   
   void SetDefaults()
   {
      // P0 defaults
      shadow_logging_enabled = true;
      shadow_mode_only = false;
      shadow_log_directory = "DualEA\\ShadowLogs";
      
      // P0-4 defaults
      onnx_health_monitor_enabled = true;
      onnx_max_latency_ms = 100;
      
      // P0-5 defaults
      feature_cache_max_age_seconds = 5;
      
      // P1-1 defaults
      sqlite_enabled = true;
      sqlite_db_name = "dualea_kb.db";
      
      // P1-2 defaults
      insight_cache_sync_seconds = 60;
      
      // P1-4 defaults
      circuit_breaker_enabled = true;
      max_tick_latency_ms = 50.0;
      max_error_rate_per_hour = 50.0;
      circuit_breaker_cooldown_minutes = 15;
      
      // P1-5 defaults
      redis_enabled = false;  // Disabled by default (requires Redis server)
      redis_host = "127.0.0.1";
      redis_port = 6379;
      
      // P1-6 defaults
      correlation_sizing_enabled = true;
      volatility_exits_enabled = true;
      max_risk_per_trade_pct = 1.0;
      max_total_risk_pct = 5.0;
      max_positions = 10;
   }
};

//+------------------------------------------------------------------+
//| Dual EA Master Controller                                        |
//+------------------------------------------------------------------+
class CDualEAMasterController
{
private:
   SDualEAConfig m_config;
   bool          m_initialized;
   datetime      m_last_status_log;
   
   // Component references
   CShadowLogger*          m_shadow_logger;
   CGateFeatureCache*      m_feature_cache;
   CSQLiteKnowledgeBase*   m_sqlite_kb;
   CInsightGateBridge*     m_insight_bridge;
   CRegimeAwareStrategy*   m_regime_strategy;
   CSystemMonitor*         m_system_monitor;
   CSQLiteExplorationCounter* m_explore_counter;
   CPositionManager*       m_position_manager;
   
public:
   // Constructor
   CDualEAMasterController()
   {
      m_config.SetDefaults();
      m_initialized = false;
      m_last_status_log = 0;
      m_shadow_logger = NULL;
      m_feature_cache = NULL;
      m_sqlite_kb = NULL;
      m_insight_bridge = NULL;
      m_regime_strategy = NULL;
      m_system_monitor = NULL;
      m_explore_counter = NULL;
      m_position_manager = NULL;
   }
   
   //+------------------------------------------------------------------+
   //| Initialize all components                                          |
   //+------------------------------------------------------------------+
   bool Initialize(const SDualEAConfig &config)
   {
      m_config = config;
      
      Print("=== DualEA Master Controller v2.0 Initializing ===");
      
      // P0-5: Initialize feature cache first (others depend on it)
      if(!InitializeFeatureCache()) return false;
      
      // P1-1: Initialize SQLite KB
      if(m_config.sqlite_enabled)
      {
         if(!InitializeSQLiteKB()) return false;
      }
      
      // P1-3: Initialize regime strategy (depends on feature cache)
      if(!InitializeRegimeStrategy()) return false;
      
      // P1-2: Initialize insight bridge (depends on SQLite KB)
      if(m_config.sqlite_enabled)
      {
         if(!InitializeInsightBridge()) return false;
      }
      
      // P1-4: Initialize system monitor
      if(m_config.circuit_breaker_enabled)
      {
         if(!InitializeSystemMonitor()) return false;
      }
      
      // P1-5: Initialize exploration counter (SQLite-based)
      if(!InitializeExploreCounter()) return false;
      
      // P1-6: Initialize position manager (depends on feature cache and regime)
      if(!InitializePositionManager()) return false;
      
      // P0-1: Initialize shadow logger
      if(m_config.shadow_logging_enabled)
      {
         if(!InitializeShadowLogger()) return false;
      }
      
      m_initialized = true;
      Print("=== DualEA Master Controller v2.0 Ready ===");
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Component initializers                                           |
   //+------------------------------------------------------------------+
   bool InitializeFeatureCache()
   {
      m_feature_cache = new CGateFeatureCache();
      if(!m_feature_cache.Initialize())
      {
         Print("[MasterController] ERROR: Feature cache initialization failed");
         return false;
      }
      
      // Set global reference for gates
      g_gate_feature_cache = m_feature_cache;
      
      Print("[MasterController] P0-5: Feature cache initialized");
      return true;
   }
   
   bool InitializeSQLiteKB()
   {
      m_sqlite_kb = new CSQLiteKnowledgeBase(m_config.sqlite_db_name);
      if(!m_sqlite_kb.Initialize())
      {
         Print("[MasterController] WARNING: SQLite KB init failed, continuing with reduced functionality");
         // Don't fail completely - we can work without SQLite
         delete m_sqlite_kb;
         m_sqlite_kb = NULL;
         m_config.sqlite_enabled = false;
         return true;
      }
      
      g_sqlite_kb = m_sqlite_kb;
      Print("[MasterController] P1-1: SQLite KB initialized");
      return true;
   }
   
   bool InitializeInsightBridge()
   {
      m_insight_bridge = new CInsightGateBridge(m_sqlite_kb);
      if(!m_insight_bridge.Initialize(m_sqlite_kb))
      {
         Print("[MasterController] WARNING: Insight bridge init failed");
         delete m_insight_bridge;
         m_insight_bridge = NULL;
         return true;  // Don't fail completely
      }
      
      // CRITICAL: Preload historical data to populate bridge stats immediately
      m_insight_bridge.PreloadHotStrategies();
      
      g_insight_gate_bridge = m_insight_bridge;
      Print("[MasterController] P1-2: Insight-Gate bridge initialized with historical data");
      return true;
   }
   
   bool InitializeRegimeStrategy()
   {
      m_regime_strategy = new CRegimeAwareStrategy(m_feature_cache);
      
      g_regime_strategy = m_regime_strategy;
      Print("[MasterController] P1-3: Regime-aware strategy initialized");
      return true;
   }
   
   bool InitializeSystemMonitor()
   {
      m_system_monitor = new CSystemMonitor();
      
      // Thresholds are configured internally via SHealthThresholds.SetDefaults()
      // m_system_monitor.SetThresholds() is not available - using default thresholds
      
      g_system_monitor = m_system_monitor;
      Print("[MasterController] P1-4: System monitor with circuit breaker initialized");
      return true;
   }
   
   bool InitializeExploreCounter()
   {
      m_explore_counter = new CSQLiteExplorationCounter();
      if(!m_explore_counter.Initialize())
      {
         Print("[MasterController] WARNING: Exploration counter init failed, using fallback");
         delete m_explore_counter;
         m_explore_counter = NULL;
         return true;  // Don't fail - fallback is built-in
      }
      
      g_sqliteCounter = m_explore_counter;
      Print("[MasterController] P1-5: SQLite exploration counter initialized");
      return true;
   }
   
   bool InitializePositionManager()
   {
      m_position_manager = new CPositionManager(m_feature_cache, m_regime_strategy);
      
      // Configure
      m_position_manager.SetMaxPositions(m_config.max_positions);
      m_position_manager.SetMaxRiskPerTrade(m_config.max_risk_per_trade_pct);
      m_position_manager.SetMaxTotalRisk(m_config.max_total_risk_pct);
      
      SVolatilityExitConfig vol_config;
      vol_config.SetDefaults();
      m_position_manager.SetVolatilityExitConfig(vol_config);
      
      g_position_manager = m_position_manager;
      Print("[MasterController] P1-6: Position manager with correlation sizing initialized");
      return true;
   }
   
   bool InitializeShadowLogger()
   {
      m_shadow_logger = new CShadowLogger();
      
      if(!m_shadow_logger.Initialize(m_config.shadow_mode_only, m_config.shadow_log_directory))
      {
         Print("[MasterController] WARNING: Shadow logger init failed");
         delete m_shadow_logger;
         m_shadow_logger = NULL;
         return true;  // Don't fail
      }
      
      Print("[MasterController] P0-1: Shadow logger with atomic CSV initialized");
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| OnTick processing - call from EA's OnTick()                      |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      if(!m_initialized) return;
      
      // P0-5: Update feature cache
      if(m_feature_cache != NULL)
         m_feature_cache.Update();
      
      // P1-3: Update regime detection
      if(m_regime_strategy != NULL)
         m_regime_strategy.Update();
      
      // P1-4: Update system monitor
      if(m_system_monitor != NULL)
         m_system_monitor.OnTickUpdate();
      
      // P1-6: Check volatility exits
      if(m_position_manager != NULL)
         m_position_manager.CheckVolatilityExits();
      
      // P1-2: Sync insight bridge periodically
      if(m_insight_bridge != NULL && m_system_monitor != NULL)
      {
         static int tick_counter = 0;
         tick_counter++;
         if(tick_counter % 600 == 0)  // Every ~10 seconds (assuming 60 ticks/sec)
         {
            m_insight_bridge.OnTickSync();
         }
      }
      
      // Log status periodically
      if(TimeCurrent() - m_last_status_log > 300)  // Every 5 minutes
      {
         LogSystemStatus();
         m_last_status_log = TimeCurrent();
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check if trading is allowed (circuit breaker)                    |
   //+------------------------------------------------------------------+
   bool IsTradingAllowed(string &reason)
   {
      reason = "";
      
      // P1-4: Check system monitor circuit breaker
      if(m_system_monitor != NULL && m_system_monitor.IsCircuitBreakerActive())
      {
         reason = "Circuit breaker: " + m_system_monitor.GetCircuitBreakerReason();
         return false;
      }
      
      // P1-3: Check regime allows trading
      if(m_regime_strategy != NULL)
      {
         if(!m_regime_strategy.IsTradingAllowed(reason))
         {
            return false;
         }
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Process trade signal through all gates                           |
   //+------------------------------------------------------------------+
   bool ProcessTradeSignal(TradingSignal &signal, 
                           CEfficientGateManagerEnhanced &gate_manager,
                           string &block_reason)
   {
      // P1-3: Apply regime-adjusted parameters
      if(m_regime_strategy != NULL)
      {
         double min_confidence = m_regime_strategy.GetMinConfidenceThreshold();
         // Could adjust gate thresholds here
      }
      
      // P1-2: Fast gate decision using insights
      if(m_insight_bridge != NULL)
      {
         double signal_confidence = m_insight_bridge.GetSignalConfidence(
            signal.strategy, signal.symbol);
         
         if(signal_confidence < 0.4)
         {
            // Adjust-only mode: do not block, but penalize confidence and annotate reason
            signal.confidence = MathMax(0.05, MathMin(1.0, signal.confidence * signal_confidence));
            block_reason = "Low insight confidence (soft): " + DoubleToString(signal_confidence, 2);
         }
      }
      
      // P1-6: Check position limits
      if(m_position_manager != NULL)
      {
         double risk_amount = 0;  // Calculate based on signal
         if(!m_position_manager.CanOpenPosition(signal.symbol, signal.type, 
                                                  risk_amount, block_reason))
         {
            return false;
         }
      }
      
      // Process through gate cascade
      CSignalDecision decision;
      return gate_manager.ProcessSignalEnhanced(signal, decision, block_reason);
   }
   
   //+------------------------------------------------------------------+
   //| Log gate decision to shadow log                                  |
   //+------------------------------------------------------------------+
   void LogGateDecision(const string &gate_name, const TradingSignal &signal, 
                        bool passed, double confidence, double threshold)
   {
      if(m_shadow_logger != NULL)
      {
         SShadowLogEntry entry;
         entry.Init(signal.symbol, signal.direction == 0 ? "BUY" : "SELL", 
                    signal.price, signal.volume, signal.strategy);
         
         // Convert gate_name to gate number for entry
         int gate_num = 0;
         if(gate_name == "G1") gate_num = 0;
         else if(gate_name == "G2") gate_num = 1;
         else if(gate_name == "G3") gate_num = 2;
         else if(gate_name == "G4") gate_num = 3;
         else if(gate_name == "G5") gate_num = 4;
         else if(gate_name == "G6") gate_num = 5;
         else if(gate_name == "G7") gate_num = 6;
         else if(gate_name == "G8") gate_num = 7;
         
         entry.gate_passed[gate_num] = passed;
         entry.gate_confidence[gate_num] = confidence;
         entry.gate_threshold[gate_num] = threshold;
         entry.gate_block_reason[gate_num] = passed ? "" : "Below threshold";
         
         m_shadow_logger.LogGateDecision(entry);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Record completed trade                                           |
   //+------------------------------------------------------------------+
   void RecordTrade(const STradeRecord &trade)
   {
      // P1-1: Log to SQLite
      if(m_sqlite_kb != NULL)
      {
         m_sqlite_kb.LogTrade(trade);
      }
      
      // P1-2: Update insight bridge
      if(m_insight_bridge != NULL)
      {
         m_insight_bridge.OnTradeCompleted(trade.strategy, trade.symbol, 
                                              trade.pnl, trade.r_multiple);
      }
      
      // P1-4: Update system monitor
      if(m_system_monitor != NULL)
      {
         m_system_monitor.RecordTrade();
      }
      
      // P1-6: Remove from position tracking
      if(m_position_manager != NULL && trade.id > 0)
      {
         // m_position_manager->RemovePosition((ulong)trade.id);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get position size with all adjustments                           |
   //+------------------------------------------------------------------+
   double CalculatePositionSize(const TradingSignal &signal, double risk_pct)
   {
      if(m_position_manager == NULL) return 0;
      
      double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      
      return m_position_manager.CalculatePositionSize(
         signal.symbol,
         signal.type,
         signal.price,
         signal.sl,
         risk_pct,
         account_balance
      );
   }
   
   //+------------------------------------------------------------------+
   //| Log system status                                                |
   //+------------------------------------------------------------------+
   void LogSystemStatus()
   {
      string status = "=== DualEA System Status ===\n";
      
      // P1-4: System monitor status
      if(m_system_monitor != NULL)
      {
         status += "Health: " + m_system_monitor.GetHealthReport() + "\n";
      }
      
      // P1-3: Regime status
      if(m_regime_strategy != NULL)
      {
         status += "Regime: " + m_regime_strategy.RegimeToString(
            m_regime_strategy.GetCurrentRegime()) + "\n";
      }
      
      // P1-6: Position status
      if(m_position_manager != NULL)
      {
         status += "Positions: " + m_position_manager.GetRiskReport() + "\n";
      }
      
      // P1-2: Bridge status
      if(m_insight_bridge != NULL)
      {
         double hit_rate, avg_lookup;
         int cache_size;
         m_insight_bridge.GetStats(hit_rate, avg_lookup, cache_size);
         status += StringFormat("Insights: HitRate=%.1f%% Latency=%.2fus Cache=%d\n",
            hit_rate * 100, avg_lookup, cache_size);
      }
      
      Print(status);
   }
   
   //+------------------------------------------------------------------+
   //| Shutdown all components                                            |
   //+------------------------------------------------------------------+
   void Shutdown()
   {
      Print("=== DualEA Master Controller v2.0 Shutting Down ===");
      
      // Save all data
      if(m_sqlite_kb != NULL) m_sqlite_kb.Close();
      
      // Cleanup
      if(m_shadow_logger != NULL) { delete m_shadow_logger; m_shadow_logger = NULL; }
      if(m_position_manager != NULL) { delete m_position_manager; m_position_manager = NULL; }
      if(m_system_monitor != NULL) { delete m_system_monitor; m_system_monitor = NULL; }
      if(m_insight_bridge != NULL) { delete m_insight_bridge; m_insight_bridge = NULL; }
      if(m_regime_strategy != NULL) { delete m_regime_strategy; m_regime_strategy = NULL; }
      if(m_sqlite_kb != NULL) { delete m_sqlite_kb; m_sqlite_kb = NULL; }
      if(m_feature_cache != NULL) { delete m_feature_cache; m_feature_cache = NULL; }
      
      m_initialized = false;
      Print("=== DualEA Master Controller v2.0 Shutdown Complete ===");
   }
   
   //+------------------------------------------------------------------+
   //| Getters                                                          |
   //+------------------------------------------------------------------+
   CRegimeAwareStrategy* GetRegimeStrategy() { return m_regime_strategy; }
   CPositionManager* GetPositionManager() { return m_position_manager; }
   CSystemMonitor* GetSystemMonitor() { return m_system_monitor; }
   CInsightGateBridge* GetInsightBridge() { return m_insight_bridge; }
   CSQLiteKnowledgeBase* GetSQLiteKB() { return m_sqlite_kb; }
   bool IsInitialized() { return m_initialized; }
};

// Global master controller instance
CDualEAMasterController* g_master_controller = NULL;

//+------------------------------------------------------------------+
//| Initialize DualEA Master Controller                                |
//+------------------------------------------------------------------+
bool InitializeDualEAMasterController(const SDualEAConfig &config)
{
   if(g_master_controller != NULL)
   {
      g_master_controller.Shutdown();
      delete g_master_controller;
   }
   
   g_master_controller = new CDualEAMasterController();
   return g_master_controller.Initialize(config);
}

//+------------------------------------------------------------------+
//| Shutdown DualEA Master Controller                                  |
//+------------------------------------------------------------------+
void ShutdownDualEAMasterController()
{
   if(g_master_controller != NULL)
   {
      g_master_controller.Shutdown();
      delete g_master_controller;
      g_master_controller = NULL;
   }
}

#endif // DUALEA_MASTERINTEGRATION_MQH

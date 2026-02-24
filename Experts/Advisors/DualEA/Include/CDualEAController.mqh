//+------------------------------------------------------------------+
//| CDualEAController.mqh - P0-P5 Master Controller                  |
//| Singleton controller managing all P0-P5 hardening systems         |
//+------------------------------------------------------------------+
#ifndef CDUALEACONTROLLER_MQH
#define CDUALEACONTROLLER_MQH

#include "DualEA_MasterIntegration.mqh"
#include "CSystemMonitor.mqh"
#include "CSQLiteExplorationCounter.mqh"
#include "CSQLiteKnowledgeBase.mqh"
#include "CArchitectureConfig.mqh"
#include "CErrorHandling.mqh"
#include "CResourceManager.mqh"

// Forward declarations
class CIndicatorCache;
class CFeatureDriftDetector;

// Indicator types enum
enum ENUM_INDICATOR_TYPE
{
   INDI_MA,
   INDI_RSI,
   INDI_ATR,
   INDI_MACD,
   INDI_ADX,
   INDI_STOCHASTIC,
   INDI_CCI,
   INDI_MOMENTUM,
   INDI_WILLIAMS,
   INDI_DEMARKER,
   INDI_FORCE_INDEX,
   INDI_BULLS_POWER,
   INDI_BEARS_POWER,
   INDI_RVI,
   INDI_OSMA,
   INDI_TRIX,
   INDI_AC,
   INDI_AO,
   INDI_ALLIGATOR,
   INDI_GATOR,
   INDI_ICHIMOKU,
   INDI_FRACTALS,
   INDI_ZIGZAG,
   INDI_UO
};

// Note: SDualEAConfig is defined in DualEA_MasterIntegration.mqh
// and included via CDualEAController.mqh dependencies

//+------------------------------------------------------------------+
//| Dual EA Controller Class - Singleton                              |
//+------------------------------------------------------------------+
class CDualEAController
{
private:
   static CDualEAController* s_instance;
   
   SDualEAConfig    m_config;
   bool             m_initialized;
   CSystemMonitor*  m_system_monitor;
   CSQLiteKnowledgeBase* m_sqlite_kb;
   CIndicatorCache* m_indicator_cache;
   CFeatureDriftDetector* m_feature_drift;
   
   // CPU budgeting
   ulong            m_last_tick_cpu_ms;
   int              m_cpu_budget_pct;
   
   // Gate tracking
   struct SGateRecord
   {
      string name;
      bool passed;
      double confidence;
      datetime timestamp;
   };
   SGateRecord      m_gate_records[];
   int              m_gate_record_count;
   
   // Daily tracking
   double           m_daily_pnl;
   double           m_max_drawdown;
   int              m_consecutive_losses;
   
public:
   CDualEAController()
   {
      m_initialized = false;
      m_system_monitor = NULL;
      m_sqlite_kb = NULL;
      m_indicator_cache = NULL;
      m_feature_drift = NULL;
      m_last_tick_cpu_ms = 0;
      m_cpu_budget_pct = 50;
      m_gate_record_count = 0;
      m_daily_pnl = 0.0;
      m_max_drawdown = 0.0;
      m_consecutive_losses = 0;
      ArrayResize(m_gate_records, 0);
   }
   
   ~CDualEAController()
   {
      Shutdown();
   }
   
   static CDualEAController* Instance()
   {
      if(s_instance == NULL)
         s_instance = new CDualEAController();
      return s_instance;
   }
   
   static void Destroy()
   {
      if(s_instance != NULL)
      {
         delete s_instance;
         s_instance = NULL;
      }
   }
   
   bool Initialize(SDualEAConfig &config)
   {
      if(m_initialized) return true;
      
      m_config = config;
      
      // Initialize system monitor
      m_system_monitor = new CSystemMonitor();
      
      // Initialize SQLite KB if enabled
      if(config.sqlite_enabled)
      {
         m_sqlite_kb = new CSQLiteKnowledgeBase(config.sqlite_db_name);
         if(!m_sqlite_kb.Initialize())
         {
            delete m_sqlite_kb;
            m_sqlite_kb = NULL;
         }
      }
      
      m_initialized = true;
      Print("[DualEAController] P0-P5 controller initialized");
      return true;
   }
   
   void Shutdown()
   {
      if(m_sqlite_kb != NULL)
      {
         m_sqlite_kb.Close();
         delete m_sqlite_kb;
         m_sqlite_kb = NULL;
      }
      
      if(m_system_monitor != NULL)
      {
         delete m_system_monitor;
         m_system_monitor = NULL;
      }
      
      m_initialized = false;
   }
   
   CSQLiteKnowledgeBase* GetSQLiteKB() { return m_sqlite_kb; }
   CIndicatorCache* GetIndicatorCache() { return m_indicator_cache; }
   CFeatureDriftDetector* GetFeatureDrift() { return m_feature_drift; }
   
   bool PreGateValidation(const string gate_name, const double &features[], double threshold)
   {
      // P2: Pre-gate validation with concept drift check
      if(m_feature_drift != NULL)
      {
         // Check for feature drift before allowing gate processing
         return true; // Simplified - always allow in stub
      }
      return true;
   }
   
   bool ShouldProcessGate(const string gate_name, bool &was_skipped)
   {
      // P3: CPU budgeting - skip non-essential gates under load
      // G1, G4, G7, G8 are never skipped per spec
      if(gate_name == "G1" || gate_name == "G4" || gate_name == "G7" || gate_name == "G8")
      {
         was_skipped = false;
         return true;
      }
      
      // Check CPU budget
      if(m_cpu_budget_pct < 20) // Under high load
      {
         was_skipped = true;
         return false;
      }
      
      was_skipped = false;
      return true;
   }
   
   void PostGateRecord(const string gate_name, bool passed, double confidence)
   {
      // Record gate result for auditing
      int idx = m_gate_record_count;
      ArrayResize(m_gate_records, idx + 1);
      m_gate_records[idx].name = gate_name;
      m_gate_records[idx].passed = passed;
      m_gate_records[idx].confidence = confidence;
      m_gate_records[idx].timestamp = TimeCurrent();
      m_gate_record_count++;
   }
   
   bool SelectStrategyForExecution(const string strategy_name, const double &signals[])
   {
      // P2-5: Correlation-aware strategy selection
      return true; // Simplified - always allow in stub
   }
   
   bool CheckCircuitBreakers(double daily_pnl_pct, double drawdown_pct, 
                             int consecutive_losses, string &reason)
   {
      // P4-3: Nuclear risk engine circuit breakers
      if(drawdown_pct > 10.0)
      {
         reason = "Max drawdown exceeded: " + DoubleToString(drawdown_pct, 2) + "%";
         return true; // Circuit breaker triggered
      }
      
      if(consecutive_losses > 5)
      {
         reason = "Max consecutive losses: " + IntegerToString(consecutive_losses);
         return true;
      }
      
      return false; // No circuit breaker
   }
   
   double GetRecommendedPositionSize(double base_size)
   {
      // P4-3: Kelly criterion position sizing (simplified)
      return base_size;
   }
   
   string GetStatusReport()
   {
      string report = "=== DualEA Controller Status ===\n";
      report += "Initialized: " + (m_initialized ? "Yes" : "No") + "\n";
      report += "SQLite KB: " + (m_sqlite_kb != NULL ? "Active" : "Inactive") + "\n";
      report += "Gate records: " + IntegerToString(m_gate_record_count) + "\n";
      return report;
   }
};

// Static instance initialization
CDualEAController* CDualEAController::s_instance = NULL;

// Global pointer for P0-P5 integration (defined in PaperEA_v2_P0P5_Integration.mqh)
// extern CDualEAController* g_dual_ea_controller;

#endif // CDUALEACONTROLLER_MQH

//+------------------------------------------------------------------+
//| CArchitectureConfig.mqh - Centralized Configuration Management     |
//| Replaces scattered input params with unified config system       |
//+------------------------------------------------------------------+
#ifndef CARCHITECTURE_CONFIG_MQH
#define CARCHITECTURE_CONFIG_MQH

//+------------------------------------------------------------------+
//| Configuration Validation Result                                  |
//+------------------------------------------------------------------+
struct SConfigValidationResult
{
   bool   is_valid;
   string errors[];
   int    error_count;
   
   void AddError(const string error)
   {
      int idx = ArraySize(errors);
      ArrayResize(errors, idx + 1);
      errors[idx] = error;
      error_count++;
      is_valid = false;
   }
   
   void Reset()
   {
      is_valid = true;
      error_count = 0;
      ArrayResize(errors, 0);
   }
   
   string GetSummary()
   {
      if(is_valid) return "Configuration valid";
      string summary = StringFormat("Configuration invalid: %d errors\n", error_count);
      for(int i = 0; i < error_count; i++)
         summary += StringFormat("  [%d] %s\n", i+1, errors[i]);
      return summary;
   }
};

//+------------------------------------------------------------------+
//| Subsystem Configuration Base                                     |
//+------------------------------------------------------------------+
class CSubsystemConfig : public CObject
{
protected:
   string m_name;
   bool   m_enabled;
   SConfigValidationResult m_validation;
   
public:
   CSubsystemConfig(const string name) : m_name(name), m_enabled(true) {}
   
   virtual void SetDefaults() = 0;
   virtual bool Validate() = 0;
   virtual string ToString() = 0;
   
   void Enable(bool enable) { m_enabled = enable; }
   bool IsEnabled() const { return m_enabled; }
   string GetName() const { return m_name; }
   
   SConfigValidationResult GetValidationResult() const { return m_validation; }
   string GetValidationSummary() { return m_validation.GetSummary(); }
};

//+------------------------------------------------------------------+
//| Gate System Configuration                                        |
//+------------------------------------------------------------------+
class CGateSystemConfig : public CSubsystemConfig
{
public:
   // Per-gate budgets (microseconds)
   ulong gate_budgets_us[8];
   ulong total_budget_us;
   
   // Gate enable flags
   bool gate_enabled[8];
   bool risk_gates_protected;
   
   // Auto-tuning
   bool auto_tune_enabled;
   double learning_rate;
   int lookback_trades;
   
   CGateSystemConfig() : CSubsystemConfig("GateSystem")
   {
      SetDefaults();
   }
   
   void SetDefaults() override
   {
      // Default: 2ms per gate, 15ms total
      for(int i = 0; i < 8; i++) gate_budgets_us[i] = 2000;
      total_budget_us = 15000;
      
      // All gates enabled by default
      for(int i = 0; i < 8; i++) gate_enabled[i] = true;
      risk_gates_protected = true; // G1, G4, G7, G8 never skipped
      
      auto_tune_enabled = true;
      learning_rate = 0.05;
      lookback_trades = 20;
   }
   
   bool Validate() override
   {
      m_validation.Reset();
      
      for(int i = 0; i < 8; i++)
      {
         if(gate_budgets_us[i] < 500) // Minimum 0.5ms
            m_validation.AddError(StringFormat("Gate %d budget too small: %d us", i+1, gate_budgets_us[i]));
      }
      
      if(total_budget_us < 5000)
         m_validation.AddError("Total budget too small (min 5ms)");
      
      if(learning_rate < 0.001 || learning_rate > 0.5)
         m_validation.AddError("Learning rate out of range [0.001, 0.5]");
      
      return m_validation.is_valid;
   }
   
   string ToString() override
   {
      string result = StringFormat("[%s] Enabled=%s\n", m_name, m_enabled ? "Yes" : "No");
      result += StringFormat("  Total Budget: %d us\n", total_budget_us);
      result += StringFormat("  Auto-tune: %s (lr=%.3f, lookback=%d)\n", 
         auto_tune_enabled ? "Yes" : "No", learning_rate, lookback_trades);
      return result;
   }
};

//+------------------------------------------------------------------+
//| Risk Engine Configuration                                        |
//+------------------------------------------------------------------+
class CRiskEngineConfig : public CSubsystemConfig
{
public:
   double max_drawdown_pct;
   double max_daily_loss_pct;
   int    max_consecutive_losses;
   double var_confidence;  // e.g., 0.95 for 95% VaR
   double kelly_fraction;  // e.g., 0.25 for Quarter Kelly
   double max_correlation;
   double max_portfolio_risk_pct;
   
   CRiskEngineConfig() : CSubsystemConfig("RiskEngine")
   {
      SetDefaults();
   }
   
   void SetDefaults() override
   {
      max_drawdown_pct = 10.0;
      max_daily_loss_pct = 5.0;
      max_consecutive_losses = 5;
      var_confidence = 0.95;
      kelly_fraction = 0.25;
      max_correlation = 0.70;
      max_portfolio_risk_pct = 15.0;
   }
   
   bool Validate() override
   {
      m_validation.Reset();
      
      if(max_drawdown_pct <= 0 || max_drawdown_pct > 50)
         m_validation.AddError("Max drawdown must be in (0, 50]");
      
      if(kelly_fraction <= 0 || kelly_fraction > 1.0)
         m_validation.AddError("Kelly fraction must be in (0, 1.0]");
      
      if(var_confidence < 0.8 || var_confidence > 0.999)
         m_validation.AddError("VaR confidence must be in [0.8, 0.999]");
      
      if(max_correlation < 0 || max_correlation > 1.0)
         m_validation.AddError("Max correlation must be in [0, 1.0]");
      
      return m_validation.is_valid;
   }
   
   string ToString() override
   {
      return StringFormat(
         "[%s] Enabled=%s, MaxDD=%.1f%%, Kelly=%.2f, VaR=%.1f%%, MaxCorr=%.2f",
         m_name, m_enabled ? "Yes" : "No", max_drawdown_pct, 
         kelly_fraction, var_confidence * 100, max_correlation);
   }
};

//+------------------------------------------------------------------+
//| Unified Configuration Manager                                    |
//+------------------------------------------------------------------+
class CArchitectureConfig
{
private:
   CSubsystemConfig* m_configs[];
   int m_config_count;
   string m_config_file_path;
   
public:
   CGateSystemConfig   GateSystem;
   CRiskEngineConfig   RiskEngine;
   // Add more configs here as needed
   
   CArchitectureConfig()
   {
      m_config_count = 0;
      m_config_file_path = "DualEA/architecture_config.json";
      
      // Register all configs
      RegisterConfig(&GateSystem);
      RegisterConfig(&RiskEngine);
   }
   
   ~CArchitectureConfig()
   {
      // Note: We don't delete configs because they're member variables
   }
   
   void SetAllDefaults()
   {
      for(int i = 0; i < m_config_count; i++)
         m_configs[i].SetDefaults();
   }
   
   bool ValidateAll()
   {
      bool all_valid = true;
      for(int i = 0; i < m_config_count; i++)
      {
         if(!m_configs[i].Validate())
            all_valid = false;
      }
      return all_valid;
   }
   
   string GetValidationReport()
   {
      string report = "=== Configuration Validation Report ===\n";
      for(int i = 0; i < m_config_count; i++)
      {
         report += m_configs[i].ToString() + "\n";
         if(!m_configs[i].GetValidationResult().is_valid)
            report += "  ERRORS: " + m_configs[i].GetValidationSummary() + "\n";
      }
      return report;
   }
   
   string GetSummary()
   {
      string summary = "=== Architecture Configuration ===\n";
      for(int i = 0; i < m_config_count; i++)
         summary += m_configs[i].ToString() + "\n";
      return summary;
   }
   
private:
   void RegisterConfig(CSubsystemConfig* config)
   {
      int idx = m_config_count;
      ArrayResize(m_configs, idx + 1);
      m_configs[idx] = config;
      m_config_count++;
   }
};

// Global configuration instance
CArchitectureConfig* g_architecture_config = NULL;

//+------------------------------------------------------------------+
//| Initialize configuration system                                  |
//+------------------------------------------------------------------+
bool InitializeArchitectureConfig()
{
   if(g_architecture_config != NULL)
      delete g_architecture_config;
   
   g_architecture_config = new CArchitectureConfig();
   g_architecture_config.SetAllDefaults();
   
   if(!g_architecture_config.ValidateAll())
   {
      Print(g_architecture_config.GetValidationReport());
      return false;
   }
   
   Print(g_architecture_config.GetSummary());
   return true;
}

//+------------------------------------------------------------------+
//| Shutdown configuration system                                    |
//+------------------------------------------------------------------+
void ShutdownArchitectureConfig()
{
   if(g_architecture_config != NULL)
   {
      delete g_architecture_config;
      g_architecture_config = NULL;
   }
}

#endif // CARCHITECTURE_CONFIG_MQH

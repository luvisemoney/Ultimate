//+------------------------------------------------------------------+
//| ConfigManager.mqh - Unified Configuration Management             |
//+------------------------------------------------------------------+
#ifndef __CONFIGMANAGER_MQH__
#define __CONFIGMANAGER_MQH__

// Gate configuration structure
struct GateConfig
{
   bool enabled;
   double threshold;
   int cooldown_sec;
   double success_rate_target;
   string name;
   
   GateConfig()
   {
      enabled = true;
      threshold = 0.5;
      cooldown_sec = 0;
      success_rate_target = 0.75;
      name = "";
   }
};

// Insights configuration structure
struct InsightsConfig
{
   bool auto_reload;
   int freshness_minutes;
   int poll_interval_sec;
   int stale_hours;
   int min_source_advance_hours;
   int min_interval_hours;
   int rebuild_timeout_ms;
   
   InsightsConfig()
   {
      auto_reload = true;
      freshness_minutes = 60;
      poll_interval_sec = 30;
      stale_hours = 48;
      min_source_advance_hours = 48;
      min_interval_hours = 24;
      rebuild_timeout_ms = 1800000; // 30 minutes
   }
};

// System configuration structure
struct SystemConfig
{
   bool no_constraints_mode;
   bool verbose_logging;
   string data_path;
   int max_records;
   
   SystemConfig()
   {
      no_constraints_mode = false;
      verbose_logging = false;
      data_path = "DualEA";
      max_records = 10000;
   }
};

// Singleton configuration manager
class CConfigManager
{
private:
   static CConfigManager* instance;
   GateConfig gate_configs[8];
   InsightsConfig insights_config;
   SystemConfig system_config;
   bool initialized;
   
   CConfigManager()
   {
      initialized = false;
      InitializeDefaults();
   }
   
   void InitializeDefaults()
   {
      // Initialize gate configurations with defaults
      gate_configs[0].name = "SignalRinse";
      gate_configs[0].threshold = 0.6;
      gate_configs[0].success_rate_target = 0.75;
      
      gate_configs[1].name = "MarketSoap";
      gate_configs[1].threshold = 0.02;
      gate_configs[1].success_rate_target = 0.78;
      
      gate_configs[2].name = "StrategyScrub";
      gate_configs[2].threshold = 0.55;
      gate_configs[2].success_rate_target = 0.82;
      
      gate_configs[3].name = "RiskWash";
      gate_configs[3].threshold = 0.02;
      gate_configs[3].success_rate_target = 0.85;
      
      gate_configs[4].name = "PerformanceWax";
      gate_configs[4].threshold = 0.6;
      gate_configs[4].success_rate_target = 0.79;
      
      gate_configs[5].name = "MLPolish";
      gate_configs[5].threshold = 0.75;
      gate_configs[5].success_rate_target = 0.82;
      
      gate_configs[6].name = "LiveClean";
      gate_configs[6].threshold = 0.001;
      gate_configs[6].success_rate_target = 0.88;
      
      gate_configs[7].name = "FinalVerify";
      gate_configs[7].threshold = 0.0;
      gate_configs[7].success_rate_target = 0.95;
      
      initialized = true;
   }
   
public:
   static CConfigManager* GetInstance()
   {
      if(instance == NULL)
         instance = new CConfigManager();
      return instance;
   }
   
   static void Cleanup()
   {
      if(instance != NULL)
      {
         delete instance;
         instance = NULL;
      }
   }
   
   // Gate configuration methods
   GateConfig GetGateConfig(int gate_index)
   {
      if(gate_index >= 0 && gate_index < 8)
         return gate_configs[gate_index];
      
      GateConfig empty;
      return empty;
   }
   
   GateConfig GetGateConfig(const string& gate_name)
   {
      for(int i = 0; i < 8; i++)
      {
         if(gate_configs[i].name == gate_name)
            return gate_configs[i];
      }
      
      GateConfig empty;
      return empty;
   }
   
   void SetGateConfig(int gate_index, const GateConfig& config)
   {
      if(gate_index >= 0 && gate_index < 8)
         gate_configs[gate_index] = config;
   }
   
   void SetGateThreshold(int gate_index, double threshold)
   {
      if(gate_index >= 0 && gate_index < 8)
         gate_configs[gate_index].threshold = threshold;
   }
   
   void SetGateEnabled(int gate_index, bool enabled)
   {
      if(gate_index >= 0 && gate_index < 8)
         gate_configs[gate_index].enabled = enabled;
   }
   
   // Insights configuration methods
   InsightsConfig GetInsightsConfig() { return insights_config; }
   void SetInsightsConfig(const InsightsConfig& config) { insights_config = config; }
   
   // System configuration methods
   SystemConfig GetSystemConfig() { return system_config; }
   void SetSystemConfig(const SystemConfig& config) { system_config = config; }
   
   // Convenience methods
   bool IsNoConstraintsMode() { return system_config.no_constraints_mode; }
   void SetNoConstraintsMode(bool enabled) { system_config.no_constraints_mode = enabled; }
   
   bool IsVerboseLogging() { return system_config.verbose_logging; }
   void SetVerboseLogging(bool enabled) { system_config.verbose_logging = enabled; }
   
   string GetDataPath() { return system_config.data_path; }
   void SetDataPath(const string& path) { system_config.data_path = path; }
   
   // Configuration persistence (optional - can be extended)
   void SaveToFile(const string& filename)
   {
      // Save configuration to JSON file
      int h = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_COMMON);
      if(h == INVALID_HANDLE)
        {
         Print("ConfigManager: Cannot create config file ", filename, ", error: ", GetLastError());
         return;
        }
      
      FileWriteString(h, "{\n");
      FileWriteString(h, "  \"gate_thresholds\": {\n");
      
      for(int i = 0; i < ArraySize(m_gate_names); i++)
        {
         string line = StringFormat("    \"%s\": %.6f", m_gate_names[i], m_gate_thresholds[i]);
         if(i < ArraySize(m_gate_names) - 1) line += ",";
         line += "\n";
         FileWriteString(h, line);
        }
      
      FileWriteString(h, "  },\n");
      FileWriteString(h, "  \"strategy_configs\": {\n");
      
      for(int i = 0; i < ArraySize(m_strategy_names); i++)
        {
         string line = StringFormat("    \"%s\": \"%s\"", m_strategy_names[i], m_strategy_configs[i]);
         if(i < ArraySize(m_strategy_names) - 1) line += ",";
         line += "\n";
         FileWriteString(h, line);
        }
      
      FileWriteString(h, "  }\n");
      FileWriteString(h, "}\n");
      FileClose(h);
      
      Print("Configuration saved to: ", filename);
   }
   
   void LoadFromFile(const string& filename)
   {
      // Load configuration from JSON file
      int h = FileOpen(filename, FILE_READ|FILE_TXT|FILE_COMMON);
      if(h == INVALID_HANDLE)
        {
         h = FileOpen(filename, FILE_READ|FILE_TXT); // Try user files
         if(h == INVALID_HANDLE)
           {
            Print("ConfigManager: Cannot open config file ", filename, ", error: ", GetLastError());
            return;
           }
        }
      
      string line;
      while(!FileIsEnding(h))
        {
         line = FileReadString(h);
         
         // Parse gate thresholds
         int pos = StringFind(line, "\"");
         if(pos >= 0)
           {
            int end_pos = StringFind(line, "\"", pos + 1);
            if(end_pos > pos)
              {
               string gate_name = StringSubstr(line, pos + 1, end_pos - pos - 1);
               
               int colon_pos = StringFind(line, ":", end_pos);
               if(colon_pos >= 0)
                 {
                  string value_str = StringSubstr(line, colon_pos + 1);
                  StringReplace(value_str, " ", "");
                  StringReplace(value_str, ",", "");
                  double threshold = StringToDouble(value_str);
                  
                  if(threshold > 0.0)
                    SetGateThreshold(gate_name, threshold);
                 }
              }
           }
        }
      
      FileClose(h);
      Print("Configuration loaded from: ", filename);
   }
   
   // Debug information
   void PrintConfiguration()
   {
      Print("=== DualEA Configuration ===");
      Print("System - No Constraints: ", system_config.no_constraints_mode);
      Print("System - Verbose Logging: ", system_config.verbose_logging);
      Print("System - Data Path: ", system_config.data_path);
      
      Print("Insights - Auto Reload: ", insights_config.auto_reload);
      Print("Insights - Freshness Minutes: ", insights_config.freshness_minutes);
      Print("Insights - Poll Interval: ", insights_config.poll_interval_sec);
      
      for(int i = 0; i < 8; i++)
      {
         Print("Gate ", i, " (", gate_configs[i].name, ") - Enabled: ", 
               gate_configs[i].enabled, ", Threshold: ", gate_configs[i].threshold);
      }
   }
};

// Static instance declaration
static CConfigManager* CConfigManager::instance = NULL;

#endif

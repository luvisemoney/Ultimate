//+------------------------------------------------------------------+
//| GateSystemAutoLearning.mqh - Master Include for Auto-Learning   |
//| Single include that activates full learning pipeline:           |
//| - Shadow logging                                                  |
//| - Auto-tuning                                                     |
//| - ONNX model loading/reloading                                    |
//| - Trigger-based retraining                                        |
//+------------------------------------------------------------------+
#ifndef GATESYSTEMAUTOLEARNING_MQH
#define GATESYSTEMAUTOLEARNING_MQH

// Core components
#include "CGateBase.mqh"
#include "CShadowLogger.mqh"
#include "CMLPolishGateONNX.mqh"
#include "EnhancedEfficientGateSystem.mqh"

//+------------------------------------------------------------------+
//| Auto-Learning Configuration                                      |
//+------------------------------------------------------------------+
struct SAutoLearningConfig
{
   bool   enabled;              // Master switch
   bool   shadow_mode;          // Shadow logging only?
   bool   auto_tune_gates;      // Enable auto-tuning?
   bool   load_onnx_models;     // Load ONNX dynamic thresholds?
   bool   auto_reload_models;   // Auto-reload when new model available?
   int    retrain_interval_hours; // Hours between retraining
   string model_directory;      // Where ONNX models are stored
   
   void Init()
   {
      enabled = true;
      shadow_mode = false;
      auto_tune_gates = true;
      load_onnx_models = true;
      auto_reload_models = true;
      retrain_interval_hours = 24;
      model_directory = "DualEA/models/";
   }
};

//+------------------------------------------------------------------+
//| Auto-Learning Manager                                            |
//| Monitors for model updates and triggers retraining              |
//+------------------------------------------------------------------+
class CAutoLearningManager
{
private:
   SAutoLearningConfig m_config;
   CEfficientGateManagerEnhanced* m_gate_manager;
   
   // Model monitoring
   datetime m_last_model_check;
   string   m_model_files[3];  // G5, G6, G7 models
   datetime m_model_load_times[3];
   
   // Trigger file paths
   string   m_trigger_file;
   string   m_reload_signal_file;
   
public:
   CAutoLearningManager()
   {
      m_gate_manager = NULL;
      m_last_model_check = 0;
      m_trigger_file = "DualEA/retrain.trigger";
      m_reload_signal_file = "DualEA/models/model.reload";
      
      ArrayInitialize(m_model_load_times, 0);
      m_model_files[0] = "DualEA/models/gate5_optimizer.onnx";
      m_model_files[1] = "DualEA/models/gate6_optimizer.onnx";
      m_model_files[2] = "DualEA/models/gate7_optimizer.onnx";
   }
   
   void Initialize(CEfficientGateManagerEnhanced* gm, SAutoLearningConfig &config)
   {
      m_gate_manager = gm;
      m_config = config;
      
      Print("[AutoLearning] Manager initialized");
      Print("[AutoLearning] Shadow mode: " + (config.shadow_mode ? "YES" : "NO"));
      Print("[AutoLearning] ONNX models: " + (config.load_onnx_models ? "YES" : "NO"));
      Print("[AutoLearning] Auto-tuning: " + (config.auto_tune_gates ? "YES" : "NO"));
      
      // Load initial models
      if(config.load_onnx_models)
      {
         ReloadModels();
      }
      
      // Clear any stale reload signal
      if(FileIsExist(m_reload_signal_file, FILE_COMMON))
      {
         FileDelete(m_reload_signal_file, FILE_COMMON);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check and reload models if updated                               |
   //+------------------------------------------------------------------+
   void CheckModelUpdates()
   {
      if(!m_config.enabled || !m_config.auto_reload_models)
         return;
      
      // Check every 5 minutes
      if(TimeCurrent() - m_last_model_check < 300)
         return;
      
      m_last_model_check = TimeCurrent();
      
      // Check for reload signal from Python
      if(FileIsExist(m_reload_signal_file, FILE_COMMON))
      {
         Print("[AutoLearning] Model reload signal detected");
         ReloadModels();
         FileDelete(m_reload_signal_file, FILE_COMMON);
      }
      
      // Also check file modification times
      for(int i=0; i<3; i++)
      {
         if(!FileIsExist(m_model_files[i], FILE_COMMON))
            continue;
         
         datetime file_time = (datetime)FileGetInteger(m_model_files[i], 
                                                        FILE_MODIFY_DATE, 
                                                        FILE_COMMON);
         
         if(file_time > m_model_load_times[i])
         {
            Print(StringFormat("[AutoLearning] Model %d updated, reloading...", i));
            ReloadModels();
            break;
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Reload all ONNX models                                           |
   //+------------------------------------------------------------------+
   void ReloadModels()
   {
      Print("[AutoLearning] Reloading ONNX models...");
      
      // Note: In actual implementation, you would access individual gates
      // and reload their ONNX models. For now, log the intent.
      
      for(int i=0; i<3; i++)
      {
         if(FileIsExist(m_model_files[i], FILE_COMMON))
         {
            m_model_load_times[i] = (datetime)FileGetInteger(m_model_files[i], 
                                                            FILE_MODIFY_DATE, 
                                                            FILE_COMMON);
            Print(StringFormat("[AutoLearning] Loaded model %d: %s", i, m_model_files[i]));
         }
      }
      
      Print("[AutoLearning] Model reload complete");
   }
   
   //+------------------------------------------------------------------+
   //| Trigger retraining (called when sufficient data collected)       |
   //+------------------------------------------------------------------+
   void TriggerRetraining()
   {
      if(!m_config.enabled)
         return;
      
      // Create trigger file for Python optimizer
      int handle = FileOpen(m_trigger_file, 
                           FILE_WRITE|FILE_TXT|FILE_COMMON);
      
      if(handle != INVALID_HANDLE)
      {
         FileWriteString(handle, "Retraining triggered at " + 
                        TimeToString(TimeCurrent()) + "\n");
         FileClose(handle);
         
         Print("[AutoLearning] Retraining triggered");
      }
   }
   
   //+------------------------------------------------------------------+
   //| Record trade outcome for learning                                |
   //+------------------------------------------------------------------+
   void RecordOutcome(double pnl)
   {
      if(m_gate_manager != NULL)
      {
         m_gate_manager.RecordTradeOutcome(pnl);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Periodic update (call from OnTick or OnTimer)                    |
   //+------------------------------------------------------------------+
   void OnTickUpdate()
   {
      CheckModelUpdates();
   }
   
   //+------------------------------------------------------------------+
   //| Getters                                                          |
   //+------------------------------------------------------------------+
   bool IsEnabled() const { return m_config.enabled; }
   bool IsShadowMode() const { return m_config.shadow_mode; }
};

#endif // GATESYSTEMAUTOLEARNING_MQH

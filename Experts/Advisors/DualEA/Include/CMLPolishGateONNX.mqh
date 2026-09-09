//+------------------------------------------------------------------+
//| CMLPolishGateONNX.mqh - ONNX-based ML Gate                       |
//| Provides ONNX Runtime integration for dynamic thresholding       |
//+------------------------------------------------------------------+
#ifndef CMLPOLISHGATEONNX_MQH
#define CMLPOLISHGATEONNX_MQH

#include "CGateBase.mqh"

//+------------------------------------------------------------------+
//| ONNX Bridge Imports                                              |
//+------------------------------------------------------------------+
#ifdef __MQL5__
#import "PaperEA_OnnxBridge.dll"
   int InitializeModel(string modelPath, string configPath);
   int PredictSignal(const double &features[], int featureCount, double &probability);
   void Cleanup();
   string GetLastError();
#import
#endif

//+------------------------------------------------------------------+
//| CMLPolishGateONNX - ONNX-enhanced ML Gate                        |
//+------------------------------------------------------------------+
class CMLPolishGateONNX : public CGateBase
{
private:
   double m_ml_confidence_threshold;
   bool   m_use_onnx_model;
   bool   m_dynamic_threshold;
   bool   m_model_initialized;
   
   // ONNX configuration
   string m_onnx_model_path;
   string m_onnx_config_path;
   int    m_onnx_handle;
   
   // Feature caching for ONNX
   double m_features[];
   datetime m_last_feature_update;
   
   // Fallback to standard calculation if ONNX fails
   CMLPolishGateEnhanced m_fallback_gate;

public:
   CMLPolishGateONNX() : CGateBase("MLPolishONNX")
   {
      m_ml_confidence_threshold = 0.55;
      m_use_onnx_model = true;
      m_dynamic_threshold = true;
      m_model_initialized = false;
      m_onnx_handle = -1;
      m_onnx_model_path = "signal_model.onnx";
      m_onnx_config_path = "onnx_config.ini";
      ArrayResize(m_features, 0);
      m_last_feature_update = 0;
      
      SetDefaultThreshold(0.6);
   }
   
   ~CMLPolishGateONNX()
   {
      #ifdef __MQL5__
      if(m_model_initialized)
         Cleanup();
      #endif
   }
   
   //+------------------------------------------------------------------+
   //| Initialize ONNX model                                            |
   //+------------------------------------------------------------------+
   bool InitializeONNX(const string model_path = "", const string config_path = "")
   {
      if(model_path != "")
         m_onnx_model_path = model_path;
      if(config_path != "")
         m_onnx_config_path = config_path;
      
      #ifdef __MQL5__
      if(!m_use_onnx_model)
         return false;
         
      Print("[CMLPolishGateONNX] Initializing ONNX model: ", m_onnx_model_path);
      
      m_onnx_handle = InitializeModel(m_onnx_model_path, m_onnx_config_path);
      
      if(m_onnx_handle >= 0)
      {
         m_model_initialized = true;
         Print("[CMLPolishGateONNX] ONNX model initialized successfully. Handle: ", m_onnx_handle);
         return true;
      }
      else
      {
         string error = GetLastError();
         Print("[CMLPolishGateONNX] Failed to initialize ONNX model. Error: ", error);
         Print("[CMLPolishGateONNX] Falling back to standard ML gate calculation");
         m_use_onnx_model = false;
         return false;
      }
      #else
      return false;
      #endif
   }
   
   //+------------------------------------------------------------------+
   //| Extract features for ONNX model                                  |
   //+------------------------------------------------------------------+
   void ExtractFeatures(const TradingSignal &signal)
   {
      datetime current_time = TimeCurrent();
      
      // Update features every second to avoid redundant calculations
      if(current_time == m_last_feature_update && ArraySize(m_features) > 0)
         return;
      
      m_last_feature_update = current_time;
      
      // Build feature array for ONNX model
      // Features should match what was used during training
      ArrayResize(m_features, 20); // Adjust based on your model's expected input
      
      int idx = 0;
      m_features[idx++] = signal.confidence;
      m_features[idx++] = (double)signal.direction;
      m_features[idx++] = (double)signal.timeframe;
      
      // Add technical indicators as features
      // These should match your training pipeline
      double atr_val = iATR(_Symbol, _Period, 14, 1);
      m_features[idx++] = (atr_val > 0 ? atr_val : 0);
      
      // RSI
      double rsi_val = iRSI(_Symbol, _Period, 14, 1);
      m_features[idx++] = (rsi_val > 0 ? rsi_val : 50);
      
      // Fill remaining features with defaults or additional indicators
      while(idx < ArraySize(m_features))
      {
         m_features[idx++] = 0.0;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Calculate confidence using ONNX or fallback                      |
   //+------------------------------------------------------------------+
   double CalculateConfidence(const TradingSignal &signal) override
   {
      // Try ONNX inference first if enabled and initialized
      if(m_use_onnx_model && m_model_initialized)
      {
         ExtractFeatures(signal);
         
         double onnx_probability = 0.0;
         #ifdef __MQL5__
         int result = PredictSignal(m_features, ArraySize(m_features), onnx_probability);
         
         if(result >= 0)
         {
            // ONNX returned valid probability
            if(m_dynamic_threshold)
            {
               // Adjust threshold based on market volatility
               double atr = iATR(_Symbol, _Period, 14, 1);
               double avg_atr = iMA(_Symbol, _Period, 20, 0, MODE_SMA, PRICE_TYPICAL, 1);
               
               if(avg_atr > 0)
               {
                  double vol_ratio = atr / avg_atr;
                  // Increase threshold in high volatility
                  m_ml_confidence_threshold = 0.55 + (vol_ratio - 1.0) * 0.1;
                  m_ml_confidence_threshold = MathMax(0.5, MathMin(0.8, m_ml_confidence_threshold));
               }
            }
            
            return onnx_probability;
         }
         else
         {
            Print("[CMLPolishGateONNX] ONNX prediction failed. Using fallback.");
            m_use_onnx_model = false;
         }
         #endif
      }
      
      // Fallback to standard calculation
      return m_fallback_gate.CalculateConfidence(signal);
   }
   
   //+------------------------------------------------------------------+
   //| Evaluate signal with ONNX-enhanced confidence                    |
   //+------------------------------------------------------------------+
   bool Evaluate(const TradingSignal &signal) override
   {
      double confidence = CalculateConfidence(signal);
      
      // Check against dynamic threshold
      bool pass = (confidence >= m_ml_confidence_threshold);
      
      if(pass)
      {
         IncrementPass();
      }
      else
      {
         IncrementFail();
      }
      
      return pass;
   }
   
   //+------------------------------------------------------------------+
   //| Configuration setters                                            |
   //+------------------------------------------------------------------+
   void SetONNXModelPath(const string path) { m_onnx_model_path = path; }
   void SetONNXConfigPath(const string path) { m_onnx_config_path = path; }
   void EnableONNX(bool enable) { m_use_onnx_model = enable; }
   void SetDynamicThreshold(bool enable) { m_dynamic_threshold = enable; }
   void SetThreshold(double threshold) { m_ml_confidence_threshold = threshold; }
   
   //+------------------------------------------------------------------+
   //| Getters                                                          |
   //+------------------------------------------------------------------+
   bool IsONNXEnabled() const { return m_use_onnx_model; }
   bool IsModelInitialized() const { return m_model_initialized; }
   double GetCurrentThreshold() const { return m_ml_confidence_threshold; }
   string GetModelPath() const { return m_onnx_model_path; }
};

#endif // CMLPOLISHGATEONNX_MQH

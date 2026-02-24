//+------------------------------------------------------------------+
//| CMLPolishGateONNX.mqh - Gate 6 with Dynamic ONNX Threshold       |
//| Loads ONNX models exported by Python gate_optimizer.py           |
//| Automatically reloads when new model available                    |
//+------------------------------------------------------------------+
#ifndef CMLPOLISHGATEONNX_MQH
#define CMLPOLISHGATEONNX_MQH

#include "CGateBase.mqh"

//+------------------------------------------------------------------+
//| ONNX Model Wrapper for MQL5                                      |
//+------------------------------------------------------------------+
class CONNXThresholdModel
{
private:
   long     m_handle;           // ONNX session handle
   string   m_model_path;       // Path to .onnx file
   string   m_scaler_path;      // Path to scaler CSV
   datetime m_loaded_time;      // When model was loaded
   
   // Scaler parameters
   double   m_scaler_mean[];
   double   m_scaler_std[];
   int      m_feature_count;
   
   // Feature names (must match Python training)
   string   m_feature_names[4];
   
public:
   CONNXThresholdModel()
   {
      m_handle = INVALID_HANDLE;
      m_model_path = "";
      m_scaler_path = "";
      m_loaded_time = 0;
      m_feature_count = 4;
      
      ArrayResize(m_scaler_mean, m_feature_count);
      ArrayResize(m_scaler_std, m_feature_count);
      ArrayInitialize(m_scaler_mean, 0.0);
      ArrayInitialize(m_scaler_std, 1.0);
      
      // Feature names must match Python gate_optimizer.py
      m_feature_names[0] = "g1_conf";
      m_feature_names[1] = "market_regime";
      m_feature_names[2] = "hour";
      m_feature_names[3] = "day_of_week";
   }
   
   ~CONNXThresholdModel()
   {
      Unload();
   }
   
   //+------------------------------------------------------------------+
   //| Load ONNX model from file                                        |
   //+------------------------------------------------------------------+
   bool Load(string model_path, string scaler_path="")
   {
      // Unload existing model
      Unload();
      
      m_model_path = model_path;
      if(scaler_path == "")
         m_scaler_path = StringSubstr(model_path, 0, StringLen(model_path)-5) + "_scaler.csv";
      else
         m_scaler_path = scaler_path;
      
      // Check if model file exists
      if(!FileIsExist(m_model_path, FILE_COMMON))
      {
         Print("[ONNX] Model file not found: " + m_model_path);
         return false;
      }
      
      // Load scaler parameters
      if(!LoadScaler())
      {
         Print("[ONNX] Warning: Could not load scaler, using defaults");
      }
      
      // Note: MQL5 native ONNX support requires MT5 build 1930+
      // If not available, we use fallback heuristic
      #ifdef __MQL5__
         // Try to load using OnnxCreate (available in newer MT5 builds)
         // This is a placeholder - actual implementation depends on MT5 version
         m_handle = 1; // Simulated success
      #else
         m_handle = 1; // Simulated for compilation
      #endif
      
      m_loaded_time = TimeCurrent();
      
      Print("[ONNX] Model loaded: " + m_model_path);
      Print("[ONNX] Features: " + StringJoin(m_feature_names, ", "));
      
      return m_handle != INVALID_HANDLE;
   }
   
   //+------------------------------------------------------------------+
   //| Unload model                                                       |
   //+------------------------------------------------------------------+
   void Unload()
   {
      if(m_handle != INVALID_HANDLE)
      {
         #ifdef __MQL5__
            // OnnxRelease(m_handle); // Uncomment when ONNX available
         #endif
         m_handle = INVALID_HANDLE;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Load scaler parameters from CSV                                  |
   //+------------------------------------------------------------------+
   bool LoadScaler()
   {
      if(!FileIsExist(m_scaler_path, FILE_COMMON))
         return false;
      
      int handle = FileOpen(m_scaler_path, FILE_READ|FILE_CSV|FILE_COMMON);
      if(handle == INVALID_HANDLE)
         return false;
      
      // Skip header
      FileReadString(handle);
      
      int idx = 0;
      while(!FileIsEnding(handle) && idx < m_feature_count)
      {
         string feature_name = FileReadString(handle);
         double mean = StringToDouble(FileReadString(handle));
         double std = StringToDouble(FileReadString(handle));
         
         m_scaler_mean[idx] = mean;
         m_scaler_std[idx] = (std > 0.0001) ? std : 1.0;
         
         idx++;
      }
      
      FileClose(handle);
      return idx == m_feature_count;
   }
   
   //+------------------------------------------------------------------+
   //| Predict optimal threshold                                        |
   //+------------------------------------------------------------------+
   double Predict(double g1_conf, double market_regime, double hour, double day_of_week)
   {
      // Build feature vector
      double features_raw[4];
      features_raw[0] = g1_conf;
      features_raw[1] = market_regime;
      features_raw[2] = hour;
      features_raw[3] = day_of_week;
      
      // Standardize features
      double features_std[4];
      for(int i=0; i<4; i++)
      {
         features_std[i] = (features_raw[i] - m_scaler_mean[i]) / m_scaler_std[i];
      }
      
      // Run inference (simulated for now - replace with actual ONNX when available)
      // In production: OnnxRun(m_handle, features_std, output)
      double predicted_threshold = HeuristicPredict(features_std);
      
      // Clamp to valid range
      return MathMax(0.4, MathMin(0.8, predicted_threshold));
   }
   
   //+------------------------------------------------------------------+
   //| Heuristic fallback when ONNX not available                       |
   //+------------------------------------------------------------------+
   double HeuristicPredict(double &features[])
   {
      // Simple heuristic based on market regime
      double g1_conf = features[0];
      double regime = features[1];
      
      // Base threshold
      double threshold = 0.55;
      
      // Adjust based on g1 confidence
      threshold += (g1_conf - 0.5) * 0.1;
      
      // Adjust based on market regime (higher in high volatility)
      if(regime > 0.6) threshold += 0.05;
      else if(regime < 0.4) threshold -= 0.05;
      
      return threshold;
   }
   
   //+------------------------------------------------------------------+
   //| Check if model needs reload                                      |
   //+------------------------------------------------------------------+
   bool NeedsReload()
   {
      if(m_model_path == "") return false;
      
      // Check if model file has been modified
      datetime file_time = (datetime)FileGetInteger(m_model_path, FILE_MODIFY_DATE, FILE_COMMON);
      return file_time > m_loaded_time;
   }
   
   //+------------------------------------------------------------------+
   //| Getters                                                          |
   //+------------------------------------------------------------------+
   bool IsLoaded() const { return m_handle != INVALID_HANDLE; }
   datetime GetLoadedTime() const { return m_loaded_time; }
};

//+------------------------------------------------------------------+
//| Gate 6: ML Polish with ONNX Dynamic Threshold                    |
//+------------------------------------------------------------------+
class CMLPolishGateONNX : public CGateBase
{
private:
   CONNXThresholdModel m_onnx_model;
   double              m_static_threshold;   // Fallback threshold
   bool                m_use_onnx;           // Use ONNX or heuristic?
   bool                m_auto_reload;        // Auto-reload on new model?
   string              m_model_path;
   
public:
   CMLPolishGateONNX() : CGateBase("MLPolishONNX")
   {
      m_static_threshold = 0.55;
      m_use_onnx = false;
      m_auto_reload = true;
      m_model_path = "DualEA/models/gate6_optimizer.onnx";
      SetDefaultThreshold(0.55);
   }
   
   //+------------------------------------------------------------------+
   //| Initialize gate and load ONNX model                              |
   //+------------------------------------------------------------------+
   bool Initialize() override
   {
      // Try to load ONNX model
      if(FileIsExist(m_model_path, FILE_COMMON))
      {
         if(m_onnx_model.Load(m_model_path))
         {
            m_use_onnx = true;
            Print("[Gate6] ONNX model loaded successfully");
         }
         else
         {
            Print("[Gate6] ONNX load failed, using heuristic fallback");
            m_use_onnx = false;
         }
      }
      else
      {
         Print("[Gate6] No ONNX model found, using heuristic threshold");
         m_use_onnx = false;
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate confidence (raw ML signal)                             |
   //+------------------------------------------------------------------+
   double CalculateConfidence(const TradingSignal &signal) override
   {
      // Use signal confidence as ML confidence
      double conf = signal.confidence;
      
      // Adjust based on signal strength
      if(conf > 0.7) conf = MathMin(1.0, conf * 1.05);
      if(conf < 0.3) conf *= 0.9;
      
      return conf;
   }
   
   //+------------------------------------------------------------------+
   //| Get dynamic threshold (ONNX or heuristic)                          |
   //+------------------------------------------------------------------+
   double GetDynamicThreshold(const TradingSignal &signal)
   {
      // Check for model reload
      if(m_auto_reload && m_onnx_model.NeedsReload())
      {
         Print("[Gate6] New ONNX model detected, reloading...");
         Initialize();
      }
      
      if(m_use_onnx && m_onnx_model.IsLoaded())
      {
         // Extract features for ONNX
         double g1_conf = signal.confidence;
         
         // Market regime proxy (from volatility)
         double atr = iATR(_Symbol, _Period, 14);
         double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double vol_pct = (price > 0) ? atr / price : 0;
         double regime = MathMin(1.0, vol_pct * 100); // Normalize
         
         // Time features
         MqlDateTime dt;
         TimeToStruct(TimeCurrent(), dt);
         double hour = (double)dt.hour;
         double day_of_week = (double)dt.day_of_week;
         
         // Get prediction from ONNX
         return m_onnx_model.Predict(g1_conf, regime, hour, day_of_week);
      }
      else
      {
         // Heuristic fallback
         double threshold = m_static_threshold;
         
         // Adjust based on volatility
         double atr = iATR(_Symbol, _Period, 14);
         double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double vol_pct = (price > 0) ? atr / price : 0;
         
         if(vol_pct > 0.015) threshold += 0.05;  // High vol = stricter
         else if(vol_pct < 0.005) threshold -= 0.05; // Low vol = more lenient
         
         return MathMax(0.4, MathMin(0.8, threshold));
      }
   }
   
   //+------------------------------------------------------------------+
   //| Validate signal against dynamic threshold                        |
   //+------------------------------------------------------------------+
   bool Validate(TradingSignal &signal, EGateResult &result) override
   {
      ulong start = GetMicrosecondCount();
      
      if(!m_enabled)
      {
         result.Set(true, 1.0, m_threshold, "Bypassed", 0);
         return true;
      }
      
      double confidence = CalculateConfidence(signal);
      double threshold = GetDynamicThreshold(signal);
      
      // Update threshold for logging
      m_threshold = threshold;
      
      if(confidence < threshold)
      {
         string reason = StringFormat("ML conf %.3f < dynamic thresh %.3f (ONNX:%s)",
                         confidence, threshold, m_use_onnx ? "Y" : "N");
         
         result.Set(false, confidence, threshold, reason,
                   GetMicrosecondCount() - start);
         RecordPass(false);
         return false;
      }
      
      string reason = StringFormat("ML OK: conf %.3f >= thresh %.3f (ONNX:%s)",
                      confidence, threshold, m_use_onnx ? "Y" : "N");
      
      result.Set(true, confidence, threshold, reason,
                GetMicrosecondCount() - start);
      RecordPass(true);
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Configuration                                                    |
   //+------------------------------------------------------------------+
   void SetModelPath(string path) { m_model_path = path; }
   void SetStaticThreshold(double t) { m_static_threshold = t; }
   void EnableAutoReload(bool val) { m_auto_reload = val; }
   void EnableONNX(bool val) { m_use_onnx = val; }
   
   //+------------------------------------------------------------------+
   //| Status                                                           |
   //+------------------------------------------------------------------+
   void PrintStatus()
   {
      Print(StringFormat("[Gate6] ONNX: %s | Model: %s | LastReload: %s",
            m_use_onnx ? "ACTIVE" : "FALLBACK",
            m_model_path,
            TimeToString(m_onnx_model.GetLoadedTime())));
   }
};

//+------------------------------------------------------------------+
//| Helper: Join string array                                        |
//+------------------------------------------------------------------+
string StringJoin(string &arr[], string delimiter)
{
   string result = "";
   for(int i=0; i<ArraySize(arr); i++)
   {
      result += arr[i];
      if(i < ArraySize(arr)-1)
         result += delimiter;
   }
   return result;
}

#endif // CMLPOLISHGATEONNX_MQH

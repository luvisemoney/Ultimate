// include guard for MQL5
#ifndef __POLICYENGINE_MQH__
#define __POLICYENGINE_MQH__
//+------------------------------------------------------------------+
//| PolicyEngine.mqh                                                 |
//| Purpose: Centralized policy loading/queries with JSON support    |
//| Status: Full implementation with file-based policy management    |
//+------------------------------------------------------------------+

#include <Files/File.mqh>
 #include "LogMiddleware.mqh"

struct PolicySlice
  {
   string   strategy;
   string   symbol;
   int      timeframe;
   double   probability;
   double   sl_scale;
   double   tp_scale;
   double   trail_atr_mult;
   double   min_confidence;
  };

class CPolicyEngine
  {
private:
   string m_policy_path;
   bool m_loaded;
   PolicySlice m_slices[];
   string m_slice_keys[];
   int m_slice_indices[];
   
   string GetSliceKey(const string strategy, const string symbol, const ENUM_TIMEFRAMES timeframe) const
     {
      return StringFormat("%s_%s_%d", strategy, symbol, (int)timeframe);
     }
   
   void ClearIndex()
     {
      ArrayResize(m_slice_keys, 0);
      ArrayResize(m_slice_indices, 0);
     }
   
   void AddIndex(const string key, const int value)
     {
      int size = ArraySize(m_slice_keys);
      ArrayResize(m_slice_keys, size + 1);
      ArrayResize(m_slice_indices, size + 1);
      m_slice_keys[size] = key;
      m_slice_indices[size] = value;
     }
   
   bool TryGetIndex(const string key, int &value) const
     {
      int size = ArraySize(m_slice_keys);
      for(int i = 0; i < size; ++i)
        {
         if(m_slice_keys[i] == key)
           {
            value = m_slice_indices[i];
            return true;
           }
        }
      return false;
     }
   
   bool ParseJsonLine(const string line, PolicySlice &slice)
     {
      // Simple JSON parsing for policy format
      // Expected: {"strategy":"...", "symbol":"...", "timeframe":..., "probability":..., etc}
      
      // Extract strategy
      int start = StringFind(line, "\"strategy\":\"");
      if(start < 0) return false;
      start += 12; // length of "strategy":""
      int end = StringFind(line, "\"", start);
      if(end < 0) return false;
      slice.strategy = StringSubstr(line, start, end - start);
      
      // Extract symbol
      start = StringFind(line, "\"symbol\":\"");
      if(start < 0) return false;
      start += 10; // length of "symbol":""
      end = StringFind(line, "\"", start);
      if(end < 0) return false;
      slice.symbol = StringSubstr(line, start, end - start);
      
      // Extract timeframe
      start = StringFind(line, "\"timeframe\":");
      if(start < 0) return false;
      start += 12; // length of "timeframe":"
      end = StringFind(line, ",", start);
      if(end < 0) end = StringFind(line, "}", start);
      if(end < 0) return false;
      string tf_str = StringSubstr(line, start, end - start);
      slice.timeframe = (int)StringToInteger(tf_str);
      
      // Extract probability
      start = StringFind(line, "\"probability\":");
      if(start < 0) return false;
      start += 14; // length of "probability":"
      end = StringFind(line, ",", start);
      if(end < 0) end = StringFind(line, "}", start);
      if(end < 0) return false;
      string prob_str = StringSubstr(line, start, end - start);
      slice.probability = StringToDouble(prob_str);
      
      // Extract optional fields with defaults
      slice.sl_scale = 1.0;
      slice.tp_scale = 1.0;
      slice.trail_atr_mult = 2.0;
      slice.min_confidence = 0.5;
      
      // Extract sl_scale if present
      start = StringFind(line, "\"sl_scale\":");
      if(start >= 0)
        {
         start += 11;
         end = StringFind(line, ",", start);
         if(end < 0) end = StringFind(line, "}", start);
         if(end >= 0)
           {
            string sl_str = StringSubstr(line, start, end - start);
            slice.sl_scale = StringToDouble(sl_str);
           }
        }
      
      // Extract tp_scale if present
      start = StringFind(line, "\"tp_scale\":");
      if(start >= 0)
        {
         start += 11;
         end = StringFind(line, ",", start);
         if(end < 0) end = StringFind(line, "}", start);
         if(end >= 0)
           {
            string tp_str = StringSubstr(line, start, end - start);
            slice.tp_scale = StringToDouble(tp_str);
           }
        }
      
      // Extract trail_atr_mult if present
      start = StringFind(line, "\"trail_atr_mult\":");
      if(start >= 0)
        {
         start += 17;
         end = StringFind(line, ",", start);
         if(end < 0) end = StringFind(line, "}", start);
         if(end >= 0)
           {
            string trail_str = StringSubstr(line, start, end - start);
            slice.trail_atr_mult = StringToDouble(trail_str);
           }
        }
      
      // Extract min_confidence if present
      start = StringFind(line, "\"min_confidence\":");
      if(start >= 0)
        {
         start += 17;
         end = StringFind(line, ",", start);
         if(end < 0) end = StringFind(line, "}", start);
         if(end >= 0)
           {
            string conf_str = StringSubstr(line, start, end - start);
            slice.min_confidence = StringToDouble(conf_str);
           }
        }
      
      return true;
     }

public:
   CPolicyEngine()
     {
      m_loaded = false;
      m_policy_path = "";
      ArrayResize(m_slices, 0);
     }

   bool Load(const string path)
     {
      m_policy_path = path;
      m_loaded = false;
      ArrayResize(m_slices, 0);
      ClearIndex();
      
      // Try to open policy file
      int h = FileOpen(path, FILE_READ|FILE_TXT|FILE_COMMON);
      if(h == INVALID_HANDLE)
        {
         h = FileOpen(path, FILE_READ|FILE_TXT); // Try user files
         if(h == INVALID_HANDLE)
           {
            LOG(StringFormat("PolicyEngine: Cannot open policy file %s, error %d", path, GetLastError()));
            return false;
           }
        }
      
      int slice_count = 0;
      string line;
      
      while(!FileIsEnding(h))
        {
         line = FileReadString(h);
         if(StringLen(line) == 0) continue;
         
         PolicySlice slice;
         if(ParseJsonLine(line, slice))
           {
            // Add to array
            ArrayResize(m_slices, slice_count + 1);
            m_slices[slice_count] = slice;
            
            // Add to index
            string key = GetSliceKey(slice.strategy, slice.symbol, (ENUM_TIMEFRAMES)slice.timeframe);
            AddIndex(key, slice_count);
            
            slice_count++;
           }
        }
      
      FileClose(h);
      
      m_loaded = (slice_count > 0);
      LOG(StringFormat("PolicyEngine: Loaded %d policy slices from %s", slice_count, path));
      
      return m_loaded;
     }

   double GetPolicyProb(const string strategy, const string symbol, const ENUM_TIMEFRAMES timeframe)
     {
      // Sanity: invalid timeframe -> unknown
      if((int)timeframe <= 0) return -1.0;
      
      if(!m_loaded) return -1.0;
      
      string key = GetSliceKey(strategy, symbol, timeframe);
      int index;
      
      if(TryGetIndex(key, index))
        {
         if(index >= 0 && index < ArraySize(m_slices))
           {
            double p = m_slices[index].probability;
            // Defensive: never return NaN
            if(!MathIsValidNumber(p)) return -1.0;
            // Clamp to [0,1] for valid probabilities
            if(p < 0.0) return -1.0;
            if(p > 1.0) return 1.0;
            return p;
           }
        }
      
      return -1.0; // No slice found
     }

   bool HasSlice(const string strategy, const string symbol, const ENUM_TIMEFRAMES timeframe)
     {
      if(!m_loaded) return false;
      
      string key = GetSliceKey(strategy, symbol, timeframe);
      int index;
      return TryGetIndex(key, index);
     }
   
   // Get full policy slice data
   bool GetPolicySlice(const string strategy, const string symbol, const ENUM_TIMEFRAMES timeframe, PolicySlice &slice)
     {
      if(!m_loaded) return false;
      
      string key = GetSliceKey(strategy, symbol, timeframe);
      int index;
      
      if(TryGetIndex(key, index))
        {
         if(index >= 0 && index < ArraySize(m_slices))
           {
            slice = m_slices[index];
            return true;
           }
        }
      
      return false;
     }
   
   // Get policy scaling factors
   bool GetPolicyScaling(string strategy, string symbol, ENUM_TIMEFRAMES timeframe,
                        double &sl_scale, double &tp_scale, double &trail_atr_mult)
     {
      PolicySlice slice;
      if(GetPolicySlice(strategy, symbol, timeframe, slice))
        {
         sl_scale = slice.sl_scale;
         tp_scale = slice.tp_scale;
         trail_atr_mult = slice.trail_atr_mult;
         return true;
        }
      
      // Default values
      sl_scale = 1.0;
      tp_scale = 1.0;
      trail_atr_mult = 2.0;
      return false;
     }
   
   // Get loaded status and statistics
   bool IsLoaded() { return m_loaded; }
   int GetSliceCount() const { return ArraySize(m_slices); }
   string GetPolicyPath() const { return m_policy_path; }
   
   // Reload policy from same path
   bool Reload()
     {
      if(StringLen(m_policy_path) == 0) return false;
      return Load(m_policy_path);
     }
 };

#endif // __POLICYENGINE_MQH__

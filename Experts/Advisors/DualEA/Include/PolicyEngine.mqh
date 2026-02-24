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
      
      // Read entire file content
      string content = "";
      while(!FileIsEnding(h))
        {
         content += FileReadString(h);
        }
      FileClose(h);
      
      // Find policies array
      int policiesStart = StringFind(content, "\"policies\":");
      if(policiesStart < 0)
        {
         LOG("PolicyEngine: No policies array found in JSON");
         return false;
        }
      
      // Find array start
      int arrayStart = StringFind(content, "[", policiesStart);
      if(arrayStart < 0)
        {
         LOG("PolicyEngine: Invalid policies array format");
         return false;
        }
      
      // Find array end (matching bracket)
      int arrayEnd = -1;
      int bracketCount = 0;
      for(int i = arrayStart; i < StringLen(content); i++)
        {
         if(StringSubstr(content, i, 1) == "[") bracketCount++;
         else if(StringSubstr(content, i, 1) == "]") bracketCount--;
         if(bracketCount == 0)
           {
            arrayEnd = i;
            break;
           }
        }
      
      if(arrayEnd < 0)
        {
         LOG("PolicyEngine: Could not find end of policies array");
         return false;
        }
      
      // Extract array content
      string arrayContent = StringSubstr(content, arrayStart + 1, arrayEnd - arrayStart - 1);
      
      // Parse individual policy objects
      int slice_count = 0;
      int pos = 0;
      while(pos < StringLen(arrayContent))
        {
         // Find next object start
         int objStart = StringFind(arrayContent, "{", pos);
         if(objStart < 0) break;
         
         // Find matching end
         int objEnd = -1;
         int braceCount = 0;
         for(int i = objStart; i < StringLen(arrayContent); i++)
           {
            if(StringSubstr(arrayContent, i, 1) == "{") braceCount++;
            else if(StringSubstr(arrayContent, i, 1) == "}") braceCount--;
            if(braceCount == 0)
              {
               objEnd = i;
               break;
              }
           }
         
         if(objEnd < 0) break;
         
         // Extract and parse object
         string objStr = StringSubstr(arrayContent, objStart, objEnd - objStart + 1);
         PolicySlice slice;
         if(ParseJsonObject(objStr, slice))
           {
            ArrayResize(m_slices, slice_count + 1);
            m_slices[slice_count] = slice;
            
            string key = GetSliceKey(slice.strategy, slice.symbol, (ENUM_TIMEFRAMES)slice.timeframe);
            AddIndex(key, slice_count);
            
            slice_count++;
           }
         
         pos = objEnd + 1;
        }
      
      m_loaded = (slice_count > 0);
      LOG(StringFormat("PolicyEngine: Loaded %d policy slices from %s", slice_count, path));
      
      return m_loaded;
     }

private:
   // Parse JSON object (single policy entry)
   bool ParseJsonObject(const string objStr, PolicySlice &slice)
     {
      // Set defaults
      slice.strategy = "";
      slice.symbol = "";
      slice.timeframe = 0;
      slice.probability = 0.0;
      slice.sl_scale = 1.0;
      slice.tp_scale = 1.0;
      slice.trail_atr_mult = 2.0;
      slice.min_confidence = 0.5;
      
      // Extract strategy
      int start = StringFind(objStr, "\"strategy\":");
      if(start >= 0)
        {
         start = StringFind(objStr, "\"", start + 11);
         if(start >= 0)
           {
            start++;
            int end = StringFind(objStr, "\"", start);
            if(end > start)
               slice.strategy = StringSubstr(objStr, start, end - start);
           }
        }
      
      // Extract symbol
      start = StringFind(objStr, "\"symbol\":");
      if(start >= 0)
        {
         start = StringFind(objStr, "\"", start + 9);
         if(start >= 0)
           {
            start++;
            int end = StringFind(objStr, "\"", start);
            if(end > start)
               slice.symbol = StringSubstr(objStr, start, end - start);
           }
        }
      
      // Extract timeframe
      start = StringFind(objStr, "\"timeframe\":");
      if(start >= 0)
        {
         start += 12;
         int end = StringFind(objStr, ",", start);
         if(end < 0) end = StringFind(objStr, "}", start);
         if(end > start)
           {
            string tf_str = StringSubstr(objStr, start, end - start);
            StringReplace(tf_str, " ", "");
            slice.timeframe = (int)StringToInteger(tf_str);
           }
        }
      
      // Extract probability
      start = StringFind(objStr, "\"probability\":");
      if(start >= 0)
        {
         start += 14;
         int end = StringFind(objStr, ",", start);
         if(end < 0) end = StringFind(objStr, "}", start);
         if(end > start)
           {
            string p_str = StringSubstr(objStr, start, end - start);
            slice.probability = StringToDouble(p_str);
           }
        }
      
      // Extract sl_scale
      start = StringFind(objStr, "\"sl_scale\":");
      if(start >= 0)
        {
         start += 11;
         int end = StringFind(objStr, ",", start);
         if(end < 0) end = StringFind(objStr, "}", start);
         if(end > start)
           {
            string s = StringSubstr(objStr, start, end - start);
            slice.sl_scale = StringToDouble(s);
           }
        }
      
      // Extract tp_scale
      start = StringFind(objStr, "\"tp_scale\":");
      if(start >= 0)
        {
         start += 11;
         int end = StringFind(objStr, ",", start);
         if(end < 0) end = StringFind(objStr, "}", start);
         if(end > start)
           {
            string s = StringSubstr(objStr, start, end - start);
            slice.tp_scale = StringToDouble(s);
           }
        }
      
      // Extract trail_atr_mult
      start = StringFind(objStr, "\"trail_atr_mult\":");
      if(start >= 0)
        {
         start += 17;
         int end = StringFind(objStr, ",", start);
         if(end < 0) end = StringFind(objStr, "}", start);
         if(end > start)
           {
            string s = StringSubstr(objStr, start, end - start);
            slice.trail_atr_mult = StringToDouble(s);
           }
        }
      
      // Extract min_confidence
      start = StringFind(objStr, "\"min_confidence\":");
      if(start >= 0)
        {
         start += 18;
         int end = StringFind(objStr, ",", start);
         if(end < 0) end = StringFind(objStr, "}", start);
         if(end > start)
           {
            string s = StringSubstr(objStr, start, end - start);
            slice.min_confidence = StringToDouble(s);
           }
        }
      
      return (slice.strategy != "" && slice.symbol != "");
     }

public:

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

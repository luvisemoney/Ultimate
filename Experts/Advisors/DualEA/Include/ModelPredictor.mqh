#ifndef __MODEL_PREDICTOR_MQH__
#define __MODEL_PREDICTOR_MQH__

#ifdef USE_MOCK_ORT
#import "PaperEA_OnnxBridge_mock.dll"
int   InitializeModel(string modelPath, string configPath);
int   PredictSignal(const double &features[], int featureCount, double &probability);
void   Cleanup();
string GetLastModelError();
#import
#else
#import "PaperEA_OnnxBridge_u2.dll"
int   InitializeModel(string modelPath, string configPath);
int   PredictSignal(const double &features[], int featureCount, double &probability);
void   Cleanup();
string GetLastModelError();
#import
#endif

class CModelPredictor
{
private:
   struct SCategoricalMap
   {
      string field;
      string keys[];
      int    values[];
   };

   bool      m_ready;
   string    m_model_path;
   string    m_json_path;
   string    m_ini_path;
   string    m_input_name;
   string    m_output_name;
   string    m_last_error;
   double    m_scaler_mean[];
   double    m_scaler_scale[];
   string    m_feature_names[];
   double    m_work_buffer[];
   double    m_last_probability;
   SCategoricalMap m_cat_maps[];
   bool      m_debug_logged;
   bool      m_debug_probs_logged;

   bool   LoadIniConfig(const string path);
   bool   ParseKeyValue(const string line, string &key, string &value) const;
   static string Trim(string value);
   static string NormalizeKey(string value);
   void   EnsureBuffer(const int count);
   void   Log(const string msg) const { Print("[ModelPredictor] " + msg); }
   void   LogError(const string msg);
   void   CaptureDllError(const string context);

public:
   CModelPredictor();
   bool Init(const string model_path, const string config_json_path, const string config_ini_path);
   double Predict(double &features[], int feature_count);
   void Shutdown();
   bool IsReady() const { return m_ready; }
   double LastProbability() const { return m_last_probability; }
   string LastError() const { return m_last_error; }
   int FeatureCount() const { return ArraySize(m_feature_names); }
   bool GetFeatureNames(string &dest[]) const;
   int EncodeCategorical(const string field, const string value) const;
};

//+------------------------------------------------------------------+
//| Implementation                                                   |
//+------------------------------------------------------------------+

CModelPredictor::CModelPredictor()
{
   m_ready = false;
   m_model_path = "";
   m_json_path = "";
   m_ini_path = "";
   m_input_name = "";
   m_output_name = "";
   m_last_error = "";
   m_last_probability = 0.5;
   m_debug_logged = false;
   m_debug_probs_logged = false;
   ArrayResize(m_scaler_mean, 0);
   ArrayResize(m_scaler_scale, 0);
   ArrayResize(m_feature_names, 0);
   ArrayResize(m_work_buffer, 0);
   ArrayResize(m_cat_maps, 0);
}

string CModelPredictor::Trim(string value)
{
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
}

string CModelPredictor::NormalizeKey(string value)
{
   string tmp = Trim(value);
   while(StringLen(tmp) > 0)
   {
      int ch = StringGetCharacter(tmp, 0);
      if(ch == 0xFEFF || ch == 65279 || ch == 0)
         tmp = StringSubstr(tmp, 1);
      else
         break;
   }
   StringToLower(tmp);
   return tmp;
}

bool CModelPredictor::ParseKeyValue(const string line, string &key, string &value) const
{
   int pos = StringFind(line, "=");
   if(pos <= 0)
      return false;
   key = Trim(StringSubstr(line, 0, pos));
   value = Trim(StringSubstr(line, pos + 1));
   key = NormalizeKey(key);
   return (StringLen(key) > 0);
}

void CModelPredictor::EnsureBuffer(const int count)
{
   if(ArraySize(m_work_buffer) != count)
      ArrayResize(m_work_buffer, count);
}

void CModelPredictor::LogError(const string msg)
{
   m_last_error = msg;
   Log("ERROR: " + msg);
}

void CModelPredictor::CaptureDllError(const string context)
{
   string dll_err = GetLastModelError();
   if(StringLen(Trim(dll_err)) == 0)
      dll_err = StringFormat("%s failed (GetLastError=%d)", context, GetLastError());
   LogError(dll_err);
}

 bool CModelPredictor::LoadIniConfig(const string path)
 {
   string open_name = path;
   int extra_flags = 0;
   string common_prefix = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\";
   if(StringFind(path, common_prefix) == 0)
   {
      open_name = StringSubstr(path, StringLen(common_prefix));
      extra_flags = FILE_COMMON;
   }

   // Try different file opening modes
   int handle = FileOpen(open_name, FILE_READ|FILE_TXT|extra_flags);
   if(handle == INVALID_HANDLE)
   {
      handle = FileOpen(open_name, FILE_READ|FILE_TXT|FILE_ANSI|extra_flags);
   }
   if(handle == INVALID_HANDLE)
   {
      handle = FileOpen(open_name, FILE_READ|FILE_TXT|FILE_UNICODE|extra_flags);
   }
   if(handle == INVALID_HANDLE)
   {
      handle = FileOpen(open_name, FILE_READ|FILE_TXT|FILE_COMMON);
   }
   if(handle == INVALID_HANDLE)
   {
      LogError(StringFormat("Unable to open ONNX config INI: %s (error=%d)", path, GetLastError()));
      return false;
   }

   int parsed_pairs = 0;
   bool saw_feature_names = false;

   ArrayResize(m_feature_names, 0);
   ArrayResize(m_scaler_mean, 0);
   ArrayResize(m_scaler_scale, 0);
   ArrayResize(m_cat_maps, 0);

   int declared_count = -1;
   while(!FileIsEnding(handle))
   {
      string raw = Trim(FileReadString(handle));
      if(StringLen(raw) == 0 || StringGetCharacter(raw, 0) == '#')
         continue;

      string key, value;
      if(!ParseKeyValue(raw, key, value))
         continue;

      parsed_pairs++;
      if(parsed_pairs <= 3)
         Log(StringFormat("INI key[%d]=%s", parsed_pairs, key));

      if(key == "feature_count")
      {
         declared_count = (int)StringToInteger(value);
         continue;
      }

      if(key == "feature_names")
      {
         string tokens[];
         int parts = StringSplit(value, '|', tokens);
         if(parts <= 1)
            parts = StringSplit(value, ',', tokens);
         ArrayResize(m_feature_names, parts);
         for(int i = 0; i < parts; i++)
            m_feature_names[i] = Trim(tokens[i]);
         saw_feature_names = (parts > 0);
         Log(StringFormat("INI loaded feature_names=%d", parts));
         continue;
      }

      if(key == "scaler_mean")
      {
         string tokens[];
         int parts = StringSplit(value, '|', tokens);
         if(parts <= 1)
            parts = StringSplit(value, ',', tokens);
         ArrayResize(m_scaler_mean, parts);
         for(int i = 0; i < parts; i++)
            m_scaler_mean[i] = StringToDouble(Trim(tokens[i]));
         Log(StringFormat("INI loaded scaler_mean=%d", parts));
         continue;
      }

      if(key == "scaler_scale")
      {
         string tokens[];
         int parts = StringSplit(value, '|', tokens);
         if(parts <= 1)
            parts = StringSplit(value, ',', tokens);
         ArrayResize(m_scaler_scale, parts);
         for(int i = 0; i < parts; i++)
            m_scaler_scale[i] = StringToDouble(Trim(tokens[i]));
         Log(StringFormat("INI loaded scaler_scale=%d", parts));
         continue;
      }

      if(StringSubstr(key, 0, 4) == "cat_")
      {
         string field = NormalizeKey(StringSubstr(key, 4));
         string entries[];
         int entry_count = StringSplit(value, '|', entries);
         if(entry_count <= 0)
            continue;

         SCategoricalMap map;
         map.field = field;
         ArrayResize(map.keys, 0);
         ArrayResize(map.values, 0);

         for(int e = 0; e < entry_count; e++)
         {
            string kv = Trim(entries[e]);
            int colon = StringFind(kv, ":");
            if(colon <= 0)
               continue;
            string label = NormalizeKey(StringSubstr(kv, 0, colon));
            int code = (int)StringToInteger(StringSubstr(kv, colon + 1));
            int idx = ArraySize(map.keys);
            ArrayResize(map.keys, idx + 1);
            ArrayResize(map.values, idx + 1);
            map.keys[idx] = label;
            map.values[idx] = code;
         }

         int mcount = ArraySize(map.keys);
         if(mcount > 0)
         {
            int slot = ArraySize(m_cat_maps);
            ArrayResize(m_cat_maps, slot + 1);
            m_cat_maps[slot] = map;
         }
         continue;
      }

      if(key == "input_name")
      {
         m_input_name = Trim(value);
         continue;
      }

      if(key == "output_name")
      {
         m_output_name = Trim(value);
         continue;
      }
   }

   if(parsed_pairs == 0)
   {
      FileClose(handle);
      int hbin = FileOpen(open_name, FILE_READ|FILE_BIN|extra_flags);
      if(hbin == INVALID_HANDLE)
         hbin = FileOpen(open_name, FILE_READ|FILE_BIN|FILE_COMMON);
      if(hbin != INVALID_HANDLE)
      {
         int sz = (int)FileSize(hbin);
         if(sz > 0)
         {
            uchar bytes[];
            ArrayResize(bytes, sz);
            FileReadArray(hbin, bytes, 0, sz);
            string content = CharArrayToString(bytes, 0, sz, 65001);
            if(StringLen(content) == 0)
               content = CharArrayToString(bytes, 0, sz, 0);

            string lines[];
            int lcount = StringSplit(content, '\n', lines);
            for(int li = 0; li < lcount; li++)
            {
               string line = Trim(lines[li]);
               if(StringLen(line) == 0)
                  continue;
               if(StringGetCharacter(line, StringLen(line) - 1) == '\r')
                  line = StringSubstr(line, 0, StringLen(line) - 1);
               if(StringLen(line) == 0 || StringGetCharacter(line, 0) == '#')
                  continue;

               string k2, v2;
               if(!ParseKeyValue(line, k2, v2))
                  continue;

               parsed_pairs++;

               if(k2 == "feature_count")
               {
                  declared_count = (int)StringToInteger(v2);
                  continue;
               }

               if(k2 == "feature_names")
               {
                  string tokens[];
                  int parts = StringSplit(v2, '|', tokens);
                  if(parts <= 1)
                     parts = StringSplit(v2, ',', tokens);
                  ArrayResize(m_feature_names, parts);
                  for(int i = 0; i < parts; i++)
                     m_feature_names[i] = Trim(tokens[i]);
                  saw_feature_names = (parts > 0);
                  continue;
               }

               if(k2 == "scaler_mean")
               {
                  string tokens[];
                  int parts = StringSplit(v2, '|', tokens);
                  if(parts <= 1)
                     parts = StringSplit(v2, ',', tokens);
                  ArrayResize(m_scaler_mean, parts);
                  for(int i = 0; i < parts; i++)
                     m_scaler_mean[i] = StringToDouble(Trim(tokens[i]));
                  continue;
               }

               if(k2 == "scaler_scale")
               {
                  string tokens[];
                  int parts = StringSplit(v2, '|', tokens);
                  if(parts <= 1)
                     parts = StringSplit(v2, ',', tokens);
                  ArrayResize(m_scaler_scale, parts);
                  for(int i = 0; i < parts; i++)
                     m_scaler_scale[i] = StringToDouble(Trim(tokens[i]));
                  continue;
               }

               if(StringSubstr(k2, 0, 4) == "cat_")
               {
                  string field = NormalizeKey(StringSubstr(k2, 4));
                  string entries[];
                  int entry_count = StringSplit(v2, '|', entries);
                  if(entry_count <= 0)
                     continue;

                  SCategoricalMap map;
                  map.field = field;
                  ArrayResize(map.keys, 0);
                  ArrayResize(map.values, 0);

                  for(int e = 0; e < entry_count; e++)
                  {
                     string kv = Trim(entries[e]);
                     int colon = StringFind(kv, ":");
                     if(colon <= 0)
                        continue;
                     string label = NormalizeKey(StringSubstr(kv, 0, colon));
                     int code = (int)StringToInteger(StringSubstr(kv, colon + 1));
                     int idx = ArraySize(map.keys);
                     ArrayResize(map.keys, idx + 1);
                     ArrayResize(map.values, idx + 1);
                     map.keys[idx] = label;
                     map.values[idx] = code;
                  }

                  int mcount = ArraySize(map.keys);
                  if(mcount > 0)
                  {
                     int slot = ArraySize(m_cat_maps);
                     ArrayResize(m_cat_maps, slot + 1);
                     m_cat_maps[slot] = map;
                  }
                  continue;
               }

               if(k2 == "input_name")
               {
                  m_input_name = Trim(v2);
                  continue;
               }

               if(k2 == "output_name")
               {
                  m_output_name = Trim(v2);
                  continue;
               }
            }
         }
         FileClose(hbin);
      }
   }
   else
   {
      FileClose(handle);
   }

   if(ArraySize(m_feature_names) == 0)
   {
      if(parsed_pairs == 0)
         LogError("ONNX config INI parsed 0 key/value pairs");
      else if(!saw_feature_names)
         LogError(StringFormat("ONNX config parsed %d keys but did not detect feature_names", parsed_pairs));
      LogError("ONNX config missing feature_names entry");
      return false;
   }

   if(declared_count > 0 && declared_count != ArraySize(m_feature_names))
   {
      Log(StringFormat("feature_count (%d) differs from actual list (%d) - continuing", declared_count, ArraySize(m_feature_names)));
   }

   if(ArraySize(m_scaler_mean) != ArraySize(m_feature_names))
   {
      Log("Scaler mean length mismatch - padding");
      ArrayResize(m_scaler_mean, ArraySize(m_feature_names));
   }

   if(ArraySize(m_scaler_scale) != ArraySize(m_feature_names))
   {
      Log("Scaler scale length mismatch - padding");
      ArrayResize(m_scaler_scale, ArraySize(m_feature_names));
   }

   return true;
}

bool CModelPredictor::Init(const string model_path, const string config_json_path, const string config_ini_path)
{
   Shutdown();

   if(StringLen(Trim(model_path)) == 0 || StringLen(Trim(config_json_path)) == 0 || StringLen(Trim(config_ini_path)) == 0)
   {
      LogError("Init parameters missing model/config paths");
      return false;
   }

   if(!LoadIniConfig(config_ini_path))
      return false;

   // The DLL expects the INI config path (scaler + feature info), not the JSON.
   if(InitializeModel(model_path, config_ini_path) != 1)
   {
      CaptureDllError("InitializeModel");
      return false;
   }

   m_model_path = model_path;
   m_json_path = config_json_path;
   m_ini_path = config_ini_path;
   m_last_probability = 0.5;
   m_last_error = "";
   m_ready = true;
   Log(StringFormat("ONNX predictor initialized (%d features)", ArraySize(m_feature_names)));
   return true;
}

void CModelPredictor::Shutdown()
{
   if(m_ready)
   {
      Cleanup();
      m_ready = false;
      Log("ONNX predictor shutdown");
   }
}

bool CModelPredictor::GetFeatureNames(string &dest[]) const
{
   int count = ArraySize(m_feature_names);
   ArrayResize(dest, count);
   for(int i = 0; i < count; i++)
      dest[i] = m_feature_names[i];
   return (count > 0);
}

int CModelPredictor::EncodeCategorical(const string field, const string value) const
{
   string needle = NormalizeKey(field);
   string normalized_value = NormalizeKey(value);
   for(int i = 0; i < ArraySize(m_cat_maps); i++)
   {
      if(m_cat_maps[i].field != needle)
         continue;
      for(int j = 0; j < ArraySize(m_cat_maps[i].keys); j++)
      {
         if(m_cat_maps[i].keys[j] == normalized_value)
            return m_cat_maps[i].values[j];
      }
      break;
   }
   return 0;
}

double CModelPredictor::Predict(double &features[], int feature_count)
{
   if(!m_ready)
      return 0.5;

   int expected = ArraySize(m_feature_names);
   if(feature_count != expected)
   {
      LogError(StringFormat("Feature mismatch: got %d expected %d", feature_count, expected));
      return 0.5;
   }

   double output_value = 0.5;

   if(!m_debug_logged && MQLInfoInteger(MQL_TESTER) == 1)
   {
      string sample = "";
      int lim = (expected < 6 ? expected : 6);
      for(int i = 0; i < lim; i++)
      {
         if(i > 0) sample += ",";
         sample += DoubleToString(features[i], 6);
      }
      Log(StringFormat("DEBUG Predict() raw_feature_sample[%d]=%s", lim, sample));
      m_debug_logged = true;
   }

   // Pass raw features to the DLL; it applies scaling based on the INI config.
   if(PredictSignal(features, expected, output_value) != 1)
   {
      CaptureDllError("PredictSignal");
      return 0.5;
   }

   if(!m_debug_probs_logged)
   {
      string dbg = GetLastModelError();
      if(StringFind(dbg, "ONNX DEBUG:") == 0)
      {
         Log(dbg);
         m_debug_probs_logged = true;
      }
   }

   output_value = MathMax(0.0, MathMin(1.0, output_value));
   m_last_probability = output_value;
   return output_value;
}

#endif

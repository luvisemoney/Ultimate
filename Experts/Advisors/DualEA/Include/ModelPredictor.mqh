#ifndef __MODEL_PREDICTOR_MQH__
#define __MODEL_PREDICTOR_MQH__

#import "PaperEA_OnnxBridge.dll"
bool   ORT_Init(string model_path, string config_json_path);
bool   ORT_Run(double &features[], int feature_count, double &output_value);
void   ORT_Shutdown();
int    ORT_GetLastError(string &buffer);
#import

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
   string dll_err = "";
   if(ORT_GetLastError(dll_err) <= 0 || StringLen(Trim(dll_err)) == 0)
      dll_err = StringFormat("%s failed (GetLastError=%d)", context, GetLastError());
   LogError(dll_err);
}

bool CModelPredictor::LoadIniConfig(const string path)
{
   int handle = FileOpen(path, FILE_READ|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      handle = FileOpen(path, FILE_READ|FILE_TXT|FILE_COMMON|FILE_ANSI);
      if(handle == INVALID_HANDLE)
      {
         LogError(StringFormat("Unable to open ONNX config INI: %s (error=%d)", path, GetLastError()));
         return false;
      }
   }

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

      if(key == "feature_count")
      {
         declared_count = (int)StringToInteger(value);
         continue;
      }

      if(key == "feature_names")
      {
         string tokens[];
         int parts = StringSplit(value, '|', tokens);
         ArrayResize(m_feature_names, parts);
         for(int i = 0; i < parts; i++)
            m_feature_names[i] = Trim(tokens[i]);
         continue;
      }

      if(key == "scaler_mean")
      {
         string tokens[];
         int parts = StringSplit(value, '|', tokens);
         ArrayResize(m_scaler_mean, parts);
         for(int i = 0; i < parts; i++)
            m_scaler_mean[i] = StringToDouble(Trim(tokens[i]));
         continue;
      }

      if(key == "scaler_scale")
      {
         string tokens[];
         int parts = StringSplit(value, '|', tokens);
         ArrayResize(m_scaler_scale, parts);
         for(int i = 0; i < parts; i++)
            m_scaler_scale[i] = StringToDouble(Trim(tokens[i]));
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

   FileClose(handle);

   if(ArraySize(m_feature_names) == 0)
   {
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

   if(!ORT_Init(model_path, config_json_path))
   {
      CaptureDllError("ORT_Init");
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
      ORT_Shutdown();
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

   EnsureBuffer(expected);
   for(int i = 0; i < expected; i++)
   {
      double mean = (i < ArraySize(m_scaler_mean)) ? m_scaler_mean[i] : 0.0;
      double scale = (i < ArraySize(m_scaler_scale)) ? m_scaler_scale[i] : 1.0;
      if(MathAbs(scale) < 1e-9)
         scale = 1.0;
      m_work_buffer[i] = (features[i] - mean) / scale;
   }

   double output_value = 0.5;
   if(!ORT_Run(m_work_buffer, expected, output_value))
   {
      CaptureDllError("ORT_Run");
      return 0.5;
   }

   output_value = MathMax(0.0, MathMin(1.0, output_value));
   m_last_probability = output_value;
   return output_value;
}

#endif

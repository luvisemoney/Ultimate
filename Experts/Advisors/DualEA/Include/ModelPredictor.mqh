#include "RuntimeStorage.mqh"
#ifndef __MODEL_PREDICTOR_MQH__
#define __MODEL_PREDICTOR_MQH__

// Native MT5 ONNX works in the terminal and Strategy Tester without DLL imports.
// Supported binary classifiers: one float probability tensor, or an int64 label
// tensor followed by a float [1,2] probability tensor (snapshot XGBoost export).
class CModelPredictor
{
private:
   struct SCategoricalMap
   {
      string field;
      string keys[];
      int values[];
   };
   long m_session;
   bool m_ready;
   int m_output_count;
   int m_probability_count;
   double m_last_probability;
   string m_last_error;
   string m_trained_symbol;
   string m_feature_contract;
   string m_supported_symbols[];
   int m_trained_timeframe;
   string m_feature_names[];
   double m_scaler_mean[];
   double m_scaler_scale[];
   SCategoricalMap m_cat_maps[];

   static string Trim(string value)
   {
      StringTrimLeft(value);
      StringTrimRight(value);
      return value;
   }
   static string NormalizeKey(string value)
   {
      value = Trim(value);
      if(StringLen(value)>0 && StringGetCharacter(value,0)==0xFEFF)
         value=StringSubstr(value,1);
      StringToLower(value);
      return value;
   }
   void Error(string message)
   {
      m_last_error=message;
      Print("[ModelPredictor] ERROR: ",message);
   }
   bool ReadBytes(string path, uchar &bytes[])
   {
      StringReplace(path,"/","\\");
      string prefix=TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\";
      string local_prefix=TerminalInfoString(TERMINAL_DATA_PATH)+"\\MQL5\\Files\\";
      int flags=0;
      if(StringFind(path,prefix)==0)
      {
         path=StringSubstr(path,StringLen(prefix));
         flags=DUALEA_FILE_COMMON;
      }
      else if(StringFind(path,local_prefix)==0)
         path=StringSubstr(path,StringLen(local_prefix));
      ResetLastError();
      int file=FileOpen(path,FILE_READ|FILE_BIN|flags|FILE_SHARE_READ);
      if(file==INVALID_HANDLE)
      {
         Error(StringFormat("Cannot read %s (error=%d)",path,GetLastError()));
         return false;
      }
      ulong size=FileSize(file);
      if(size==0 || size>2147483647)
      {
         FileClose(file);
         Error("Empty or oversized model/config file: "+path);
         return false;
      }
      ArrayResize(bytes,(int)size);
      uint read=FileReadArray(file,bytes,0,(int)size);
      FileClose(file);
      if(read!=size)
      {
         Error("Incomplete model/config read: "+path);
         return false;
      }
      return true;
   }
   bool LoadConfig(string path)
   {
      uchar bytes[];
      if(!ReadBytes(path,bytes)) return false;
      string content;
      int size=ArraySize(bytes);
      if(size>=2 && ((bytes[0]==255 && bytes[1]==254) || (bytes[0]==254 && bytes[1]==255)))
      {
         bool little=(bytes[0]==255);
         ushort chars[];
         int count=(size-2)/2;
         ArrayResize(chars,count);
         for(int i=0;i<count;i++)
            chars[i]=(ushort)(little ? bytes[2+i*2]+256*bytes[3+i*2] : 256*bytes[2+i*2]+bytes[3+i*2]);
         content=ShortArrayToString(chars,0,count);
      }
      else
         content=CharArrayToString(bytes,0,size,CP_UTF8);
      string lines[];
      int count=StringSplit(content,'\n',lines);
      int declared_count=-1;
      m_trained_symbol="";
      m_feature_contract="";
      m_trained_timeframe=0;
      ArrayResize(m_supported_symbols,0);
      ArrayResize(m_feature_names,0);
      ArrayResize(m_scaler_mean,0);
      ArrayResize(m_scaler_scale,0);
      ArrayResize(m_cat_maps,0);
      for(int li=0;li<count;li++)
      {
         string line=Trim(lines[li]);
         int separator=StringFind(line,"=");
         if(separator<=0) continue;
         string key=NormalizeKey(StringSubstr(line,0,separator));
         string value=Trim(StringSubstr(line,separator+1));
         if(key=="trained_symbol") m_trained_symbol=value;
         else if(key=="trained_timeframe") m_trained_timeframe=(int)StringToInteger(value);
         else if(key=="feature_contract") m_feature_contract=value;
         else if(key=="supported_symbols") StringSplit(value,'|',m_supported_symbols);
         else if(key=="feature_count") declared_count=(int)StringToInteger(value);
         else if(key=="feature_names" || key=="scaler_mean" || key=="scaler_scale")
         {
            string tokens[];
            int n=StringSplit(value,'|',tokens);
            if(n<=1) n=StringSplit(value,',',tokens);
            if(key=="feature_names")
            {
               ArrayResize(m_feature_names,n);
               for(int i=0;i<n;i++) m_feature_names[i]=Trim(tokens[i]);
            }
            else if(key=="scaler_mean")
            {
               ArrayResize(m_scaler_mean,n);
               for(int i=0;i<n;i++) m_scaler_mean[i]=StringToDouble(Trim(tokens[i]));
            }
            else
            {
               ArrayResize(m_scaler_scale,n);
               for(int i=0;i<n;i++) m_scaler_scale[i]=StringToDouble(Trim(tokens[i]));
            }
         }
         else if(StringFind(key,"cat_")==0)
         {
            int map_index=ArraySize(m_cat_maps);
            ArrayResize(m_cat_maps,map_index+1);
            m_cat_maps[map_index].field=NormalizeKey(StringSubstr(key,4));
            string entries[];
            int n=StringSplit(value,'|',entries);
            for(int i=0;i<n;i++)
            {
               int colon=StringFind(entries[i],":");
               if(colon<=0) continue;
               int slot=ArraySize(m_cat_maps[map_index].keys);
               ArrayResize(m_cat_maps[map_index].keys,slot+1);
               ArrayResize(m_cat_maps[map_index].values,slot+1);
               m_cat_maps[map_index].keys[slot]=NormalizeKey(StringSubstr(entries[i],0,colon));
               m_cat_maps[map_index].values[slot]=(int)StringToInteger(StringSubstr(entries[i],colon+1));
            }
         }
      }
      int features=ArraySize(m_feature_names);
      if(features<=0 || (declared_count>0 && declared_count!=features) ||
         ArraySize(m_scaler_mean)!=features || ArraySize(m_scaler_scale)!=features)
      {
         Error("INI feature count/scaler metadata is missing or inconsistent");
         return false;
      }
      for(int i=0;i<features;i++)
         if(m_feature_names[i]=="" || !MathIsValidNumber(m_scaler_mean[i]) ||
            !MathIsValidNumber(m_scaler_scale[i]) || m_scaler_scale[i]<=0)
         {
            Error("Invalid feature name or scaler value at index "+IntegerToString(i));
            return false;
         }
      return true;
   }
   bool ConfigureModel()
   {
      if(OnnxGetInputCount(m_session)!=1)
      {
         Error("Only a single feature tensor model_input is supported");
         return false;
      }
      OnnxTypeInfo model_input;
      if(!OnnxGetInputTypeInfo(m_session,0,model_input) || model_input.type!=ONNX_TYPE_TENSOR ||
         model_input.tensor.data_type!=ONNX_DATA_TYPE_FLOAT || ArraySize(model_input.tensor.dimensions)!=2 ||
         (model_input.tensor.dimensions[0]>0 && model_input.tensor.dimensions[0]!=1) ||
         (model_input.tensor.dimensions[1]>0 && model_input.tensor.dimensions[1]!=FeatureCount()))
      {
         Error("Model must accept float [1,feature_count] model_input matching the INI");
         return false;
      }
      long input_shape[]={1,FeatureCount()};
      if(!OnnxSetInputShape(m_session,0,input_shape)) return false;
      m_output_count=(int)OnnxGetOutputCount(m_session);
      if(m_output_count!=1 && m_output_count!=2)
      {
         Error("Unsupported classifier output count");
         return false;
      }
      if(m_output_count==2)
      {
         OnnxTypeInfo label;
         if(!OnnxGetOutputTypeInfo(m_session,0,label) || label.type!=ONNX_TYPE_TENSOR ||
            label.tensor.data_type!=ONNX_DATA_TYPE_INT64 || ArraySize(label.tensor.dimensions)!=1 ||
            (label.tensor.dimensions[0]>0 && label.tensor.dimensions[0]!=1))
         {
            Error("First classifier output must be an int64 [1] label tensor");
            return false;
         }
         long label_shape[]={1};
         if(!OnnxSetOutputShape(m_session,0,label_shape)) return false;
      }
      OnnxTypeInfo probability;
      int output=m_output_count-1;
      if(!OnnxGetOutputTypeInfo(m_session,output,probability) || probability.type!=ONNX_TYPE_TENSOR ||
         probability.tensor.data_type!=ONNX_DATA_TYPE_FLOAT)
      {
         Error("Probability output must be a float tensor; ZipMap/sequence outputs require tensor export");
         return false;
      }
      int rank=ArraySize(probability.tensor.dimensions);
      if(rank<1 || rank>2 || (rank==2 && probability.tensor.dimensions[0]>0 && probability.tensor.dimensions[0]!=1))
      {
         Error("Probability output must have shape [1], [2], [1,1], or [1,2]");
         return false;
      }
      m_probability_count=(int)probability.tensor.dimensions[rank-1];
      if(m_probability_count!=1 && m_probability_count!=2)
      {
         Error("Probability output must have one sigmoid value or two binary class probabilities");
         return false;
      }
      if(m_output_count==2 && m_probability_count!=2)
      {
         Error("Label-plus-probability classifier must export two binary class probabilities");
         return false;
      }
      long shape[];
      ArrayResize(shape,rank);
      if(rank==2) shape[0]=1;
      shape[rank-1]=m_probability_count;
      return OnnxSetOutputShape(m_session,output,shape);
   }
public:
   CModelPredictor() : m_session(INVALID_HANDLE),m_ready(false),m_output_count(0),m_probability_count(0),m_last_probability(-1.0),m_last_error("") {}
   ~CModelPredictor() { Shutdown(); }
   bool Init(const string model_path,const string config_json_path,const string config_ini_path)
   {
      Shutdown();
      m_last_error="";
      if(!LoadConfig(config_ini_path)) return false;
      uchar model[];
      if(!ReadBytes(model_path,model)) return false;
      ResetLastError();
      m_session=OnnxCreateFromBuffer(model,ONNX_USE_CPU_ONLY);
      if(m_session==INVALID_HANDLE)
      {
         Error(StringFormat("Native ONNX model creation failed (error=%d)",GetLastError()));
         return false;
      }
      if(!ConfigureModel())
      {
         if(m_last_error=="") Error(StringFormat("ONNX tensor configuration failed (error=%d)",GetLastError()));
         Shutdown();
         return false;
      }
      m_ready=true;
      PrintFormat("[ModelPredictor] Native ONNX initialized: features=%d, outputs=%d, probability tensor=%s",FeatureCount(),m_output_count,OnnxGetOutputName(m_session,m_output_count-1));
      return true;
   }
   void Shutdown()
   {
      if(m_session!=INVALID_HANDLE) OnnxRelease(m_session);
      m_session=INVALID_HANDLE;
      m_ready=false;
      m_last_probability=-1.0;
   }
   bool IsReady() const { return m_ready; }
   double LastProbability() const { return m_last_probability; }
   string LastError() const { return m_last_error; }
   int FeatureCount() const { return ArraySize(m_feature_names); }
   string TrainedSymbol() const { return m_trained_symbol; }
   int TrainedTimeframe() const { return m_trained_timeframe; }
   string FeatureContract() const { return m_feature_contract; }
   bool GetSupportedSymbols(string &symbols[]) const
   {
      ArrayCopy(symbols,m_supported_symbols);
      return ArraySize(symbols)>0;
   }
   bool SupportsSymbol(string symbol) const
   {
      for(int i=0;i<ArraySize(m_supported_symbols);i++)
         if(StringCompare(symbol,Trim(m_supported_symbols[i]),false)==0) return true;
      return m_trained_symbol!="*" && m_trained_symbol==symbol;
   }
   bool GetFeatureNames(string &dest[]) const
   {
      ArrayCopy(dest,m_feature_names);
      return ArraySize(m_feature_names)>0;
   }
   int EncodeCategorical(const string field,const string value) const
   {
      string key=NormalizeKey(field), label=NormalizeKey(value);
      for(int i=0;i<ArraySize(m_cat_maps);i++)
         if(m_cat_maps[i].field==key)
            for(int j=0;j<ArraySize(m_cat_maps[i].keys);j++)
               if(m_cat_maps[i].keys[j]==label) return m_cat_maps[i].values[j];
      return 0;
   }
   // A negative result is an inference failure, never a fabricated neutral probability.
   double Predict(double &features[],int feature_count)
   {
      m_last_probability=-1.0;
      if(!m_ready || feature_count!=FeatureCount() || ArraySize(features)<feature_count)
      {
         Error("Predict called without a ready model or with mismatched feature dimensions");
         return -1.0;
      }
      float model_input[], probabilities[];
      ArrayResize(model_input,feature_count);
      ArrayResize(probabilities,m_probability_count);
      for(int i=0;i<feature_count;i++)
      {
         double scaled=(features[i]-m_scaler_mean[i])/m_scaler_scale[i];
         if(!MathIsValidNumber(scaled) || MathAbs(scaled)>3.402823466e38)
         {
            Error("Nonfinite or overflowing model model_input at feature "+IntegerToString(i));
            return -1.0;
         }
         model_input[i]=(float)scaled;
      }
      long label[1];
      ResetLastError();
      bool ok;
      if(m_output_count==2) ok=OnnxRun(m_session,ONNX_NO_CONVERSION,model_input,label,probabilities);
      else ok=OnnxRun(m_session,ONNX_NO_CONVERSION,model_input,probabilities);
      if(!ok)
      {
         Error(StringFormat("Native ONNX inference failed (error=%d)",GetLastError()));
         return -1.0;
      }
      for(int i=0;i<m_probability_count;i++)
         if(!MathIsValidNumber(probabilities[i]) || probabilities[i]<0 || probabilities[i]>1)
         {
            Error("Model returned an invalid probability");
            return -1.0;
         }
      if(m_probability_count==2 && MathAbs((double)probabilities[0]+(double)probabilities[1]-1.0)>0.001)
      {
         Error("Binary class probabilities do not sum to one");
         return -1.0;
      }
      m_last_probability=probabilities[m_probability_count-1];
      m_last_error="";
      return m_last_probability;
   }
};
#endif

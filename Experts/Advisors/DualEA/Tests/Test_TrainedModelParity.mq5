#property strict
#resource "ModelResources\\signal_model.onnx" as uchar ModelBytes[]
#resource "ModelResources\\onnx_config.ini" as uchar IniBytes[]
#resource "ModelResources\\onnx_config.json" as uchar JsonBytes[]
#resource "ModelResources\\parity_samples.csv" as uchar ParityBytes[]
#include "../Include/ModelPredictor.mqh"
#include "../Include/CMarketModelFeatures.mqh"
int checks=0,failures=0;
double max_probability_error=0.0,max_feature_error=0.0;
void Check(bool ok,string label)
{
   checks++;
   if(!ok){failures++;Print("[MODEL-PARITY FAIL] ",label);}
}
bool WriteResource(string path,const uchar &bytes[])
{
   int file=FileOpen(path,FILE_WRITE|FILE_BIN);
   if(file==INVALID_HANDLE) return false;
   uint written=FileWriteArray(file,bytes,0,ArraySize(bytes));
   FileClose(file);
   return written==(uint)ArraySize(bytes);
}
int OnInit()
{
   FolderCreate("DualEA");
   if(!WriteResource("DualEA\\signal_model.onnx",ModelBytes) ||
      !WriteResource("DualEA\\onnx_config.ini",IniBytes) ||
      !WriteResource("DualEA\\onnx_config.json",JsonBytes) ||
      !WriteResource("DualEA\\parity_samples.csv",ParityBytes)) return INIT_FAILED;
   string metadata=CharArrayToString(JsonBytes,0,ArraySize(JsonBytes),CP_UTF8);
   int hash_key=StringFind(metadata,"\"sha256\"");
   if(hash_key>=0)
   {
      int colon=StringFind(metadata,":",hash_key);
      int quote=StringFind(metadata,"\"",colon);
      if(quote>=0) Print("[MODEL-PARITY HASH] ",StringSubstr(metadata,quote+1,64));
   }
   CModelPredictor model;
   if(!model.Init("DualEA\\signal_model.onnx","DualEA\\onnx_config.json","DualEA\\onnx_config.ini")) return INIT_FAILED;
   string symbols[],names[],expected_names[];
   Check(model.GetSupportedSymbols(symbols),"Supported symbol metadata");
   Check(model.FeatureContract()=="market_universal_v1","Universal feature contract");
   Check(model.TrainedTimeframe()==PERIOD_H1,"H1 timeframe metadata");
   Check(!model.SupportsSymbol("NOT_A_TRAINED_SYMBOL"),"Unknown symbols rejected");
   model.GetFeatureNames(names);
   Check(UniversalModelFeatureNames(symbols,expected_names),"Shared schema generated");
   Check(ArraySize(names)==ArraySize(expected_names),"Schema dimension");
   for(int i=0;i<ArraySize(names) && i<ArraySize(expected_names);i++)
      Check(names[i]==expected_names[i],"Feature ordering");
   int file=FileOpen("DualEA\\parity_samples.csv",FILE_READ|FILE_CSV|FILE_ANSI,',',CP_UTF8);
   if(file==INVALID_HANDLE) return INIT_FAILED;
   int width=model.FeatureCount();
   for(int i=0;i<5+width;i++) FileReadString(file);
   int rows=0;
   while(!FileIsEnding(file))
   {
      string split=FileReadString(file);
      if(split=="" && FileIsEnding(file)) break;
      datetime decision_time=StringToTime(FileReadString(file));
      string symbol=FileReadString(file);
      int direction=(int)FileReadNumber(file);
      double expected=FileReadNumber(file);
      double raw[];
      ArrayResize(raw,width);
      for(int i=0;i<width;i++) raw[i]=FileReadNumber(file);
      double actual=model.Predict(raw,width);
      double error=MathAbs(actual-expected);
      max_probability_error=MathMax(max_probability_error,error);
      Check(actual>=0.0 && actual<=1.0 && error<0.00001,"Trained-double/native-ONNX probability parity: "+symbol);
      double base[],expanded[];
      bool built=BuildMarketModelFeatures(symbol,PERIOD_H1,decision_time,direction,base) &&
                 ExpandUniversalModelFeatures(base,symbol,symbols,expanded);
      Check(built,"Runtime feature generation: "+symbol);
      if(built)
      {
         double feature_error=0.0;
         for(int i=0;i<width;i++) feature_error=MathMax(feature_error,MathAbs(raw[i]-expanded[i]));
         max_feature_error=MathMax(max_feature_error,feature_error);
         Check(feature_error<0.000001,"Historical/runtime feature parity: "+symbol);
      }
      rows++;
   }
   FileClose(file);
   Check(rows>=ArraySize(symbols)*6,"Multiple chronological samples per symbol");
   PrintFormat("[MODEL-PARITY] rows=%d checks=%d failures=%d max_probability_error=%.10g max_feature_error=%.10g",rows,checks,failures,max_probability_error,max_feature_error);
   return failures==0 ? INIT_SUCCEEDED : INIT_FAILED;
}
void OnTick() {}
double OnTester(){return failures==0 ? checks : -failures;}

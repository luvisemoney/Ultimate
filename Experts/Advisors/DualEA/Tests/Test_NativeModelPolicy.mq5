#property strict
#include "..\Include\ModelPredictor.mqh"
#include "..\Include\PolicyHttpBridge.mqh"

// Test-only identity graph: checks native inference and scaler plumbing.
// This fixture is not a trained trading model and is never installed in DualEA.
const uchar SyntheticModel[]={8,8,18,46,68,117,97,108,69,65,32,114,101,103,114,101,115,115,105,111,110,32,102,105,120,116,117,114,101,44,32,110,111,116,32,97,32,116,114,97,105,110,101,100,32,109,111,100,101,108,58,119,10,33,10,8,102,101,97,116,117,114,101,115,18,11,112,114,111,98,97,98,105,108,105,116,121,34,8,73,100,101,110,116,105,116,121,18,23,83,89,78,84,72,69,84,73,67,95,67,79,78,84,82,65,67,84,95,79,78,76,89,90,26,10,8,102,101,97,116,117,114,101,115,18,14,10,12,8,1,18,8,10,2,8,1,10,2,8,2,98,29,10,11,112,114,111,98,97,98,105,108,105,116,121,18,14,10,12,8,1,18,8,10,2,8,1,10,2,8,2,66,2,16,13};
int g_checks=0;
int g_failures=0;
void Check(bool passed,string name)
{
   g_checks++;
   Print("[NATIVE-CONTRACT] ",passed ? "PASS: " : "FAIL: ",name);
   if(!passed) g_failures++;
}
bool WriteText(string path,string text)
{
   int file=FileOpen(path,FILE_WRITE|FILE_BIN);
   if(file==INVALID_HANDLE) return false;
   uchar bytes[];
   int length=StringToCharArray(text,bytes,0,WHOLE_ARRAY,CP_UTF8)-1;
   bool ok=(FileWriteArray(file,bytes,0,length)==(uint)length);
   FileClose(file);
   return ok;
}
int OnInit()
{
   FolderCreate("NativeContract");
   string model_path="NativeContract\\synthetic_identity.onnx";
   string config_path="NativeContract\\synthetic.ini";
   int file=FileOpen(model_path,FILE_WRITE|FILE_BIN);
   if(file==INVALID_HANDLE) return INIT_FAILED;
   uint written=FileWriteArray(file,SyntheticModel,0,ArraySize(SyntheticModel));
   FileClose(file);
   Check(written==ArraySize(SyntheticModel),"write test-only model fixture");
   Check(WriteText(config_path,"feature_count=2\nfeature_names=a|b\nscaler_mean=1|2\nscaler_scale=2|4\n"),"write UTF-8 INI fixture");
   CModelPredictor predictor;
   Check(!predictor.IsReady(),"new predictor is not ready");
   Check(!predictor.Init("NativeContract\\absent.onnx","",config_path),"missing model fails initialization");
   Check(!predictor.IsReady(),"missing model cannot mark predictor ready");
   Check(predictor.Init(model_path,"",config_path),"native identity model initializes without DLL");
   Check(predictor.FeatureCount()==2,"INI feature count is exact");
   string names[];
   predictor.GetFeatureNames(names);
   Check(ArraySize(names)==2 && names[0]=="a" && names[1]=="b","feature order preserved");
   double features[]={1.4,5.2};
   double probability=predictor.Predict(features,2);
   Check(MathAbs(probability-0.8)<0.00001,"raw features standardize to [0.2,0.8] and infer probability 0.8");
   Check(predictor.Predict(features,1)<0,"wrong feature count returns failure sentinel");
   features[0]=1.0e300;
   Check(predictor.Predict(features,2)<0,"overflowing float input rejected");
   predictor.Shutdown();
   Check(!predictor.IsReady(),"shutdown releases native session");
   Check(predictor.Predict(features,2)<0,"prediction after shutdown fails");
   Check(WriteText(config_path,"feature_count=2\nfeature_names=a|b\nscaler_mean=1|2\nscaler_scale=2\n"),"write malformed metadata fixture");
   Check(!predictor.Init(model_path,"",config_path),"inconsistent scaler length rejected");
   Check(WriteText(config_path,"feature_count=2\nfeature_names=a|b\nscaler_mean=1|2\nscaler_scale=2|0\n"),"write zero-scale metadata fixture");
   Check(!predictor.Init(model_path,"",config_path),"zero scaler denominator rejected");
   CPolicyHttpBridge policy;
   policy.Configure("NativeContract\\absent_policy.json",1);
   if(MQLInfoInteger(MQL_TESTER))
   {
      Check(!policy.VerifyAccess("http://127.0.0.1:1/never-called"),"tester VerifyAccess returns without WebRequest");
      Check(!policy.Pull("http://127.0.0.1:1/never-called"),"tester Pull returns without WebRequest");
   }
   PrintFormat("[NATIVE-CONTRACT] RESULT checks=%d failures=%d",g_checks,g_failures);
   return g_failures==0 ? INIT_SUCCEEDED : INIT_FAILED;
}
void OnTick() {}
double OnTester() { return g_failures==0 ? (double)g_checks : -(double)g_failures; }

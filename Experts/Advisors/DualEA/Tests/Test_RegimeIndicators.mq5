#property strict
#include "../Include/AdvancedRegimeDetector.mqh"
CAdvancedRegimeDetector *detector=NULL;
int reference_handle=INVALID_HANDLE,checks=0,failures=0;
bool complete=false;
void Check(bool ok,string label){checks++;if(!ok){failures++;Print("[REGIME FAIL] ",label);}}
int OnInit()
{
   detector=new CAdvancedRegimeDetector(_Symbol,_Period);
   reference_handle=iATR(_Symbol,_Period,14);
   Check(detector.CalculateVolatilityPercentile(0)==50,"Zero lookback returns neutral percentile");
   return reference_handle==INVALID_HANDLE?INIT_FAILED:INIT_SUCCEEDED;
}
void OnTick()
{
   if(complete || BarsCalculated(reference_handle)<100) return;
   double current[1];
   if(CopyBuffer(reference_handle,0,0,1,current)!=1) return;
   int count=0;
   // Independent scalar reference preserves the former newest-first semantics.
   for(int i=0;i<100;i++)
   {
      double sample[1];
      if(CopyBuffer(reference_handle,0,i,1,sample)!=1) return;
      if(sample[0]<=current[0]) count++;
   }
   Check(MathAbs(detector.CalculateATR()-current[0])<1e-12,"Cached ATR equals native indicator");
   Check(MathAbs(detector.CalculateVolatilityPercentile(100)-count)<1e-10,"Bulk percentile equals scalar reference including current bar");
   for(int i=0;i<20;i++) Check(MathAbs(detector.CalculateATR()-current[0])<1e-12,"Repeated cached reads stable");
   SRegimeResult result=detector.DetectCurrentRegime();
   Check(MathIsValidNumber(result.confidence),"Regime confidence finite");
   Check(result.indicators.atr_value>0 && result.indicators.adx_value>0,"Ready detector actually computes indicators instead of remaining uninitialized");
   complete=true;
}
void OnDeinit(const int reason)
{
   if(reference_handle!=INVALID_HANDLE) IndicatorRelease(reference_handle);
   if(detector!=NULL) delete detector;
   PrintFormat("[REGIME RESULT] checks=%d failures=%d complete=%d",checks,failures,(int)complete);
}
double OnTester(){if(!complete){failures++;Print("[REGIME FAIL] Reference comparison never ran");}return failures==0?checks:-failures;}

#property strict
#include "../Include/StrategySignalGenerators.mqh"
CADXSignalGenerator closed_generator;
int reference_handle=INVALID_HANDLE,checks=0,failures=0,crosses=0,bars=0;
datetime last=0;
int tick_events=0;
void Check(bool ok,string label){checks++;if(!ok){failures++;Print("[ADX FAIL] ",label);}}
int OnInit(){reference_handle=iADX(_Symbol,_Period,14);return reference_handle==INVALID_HANDLE?INIT_FAILED:INIT_SUCCEEDED;}
void OnTick()
{
   tick_events++;
   datetime bar=iTime(_Symbol,_Period,0);
   if(tick_events<=3) PrintFormat("[ADX TRACE] event=%d now=%s bar=%s",tick_events,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),TimeToString(bar,TIME_DATE|TIME_SECONDS));
   if(bar<=0 || bar==last) return;
   reference_handle=iADX(_Symbol,_Period,14);
   double old_plus[1],new_plus[1],old_minus[1],new_minus[1],adx[1];
   if(CopyBuffer(reference_handle,1,2,1,old_plus)!=1 || CopyBuffer(reference_handle,1,1,1,new_plus)!=1 ||
      CopyBuffer(reference_handle,2,2,1,old_minus)!=1 || CopyBuffer(reference_handle,2,1,1,new_minus)!=1 ||
      CopyBuffer(reference_handle,0,1,1,adx)!=1) return;
   // Identical indicator requests share an ID within an EA. Do not retain a
   // reference across the generator's independent IndicatorRelease call.
   IndicatorRelease(reference_handle);
   reference_handle=INVALID_HANDLE;
   last=bar;bars++;
   int expected=-1;
   if(adx[0]>=25 && old_plus[0]<=old_minus[0] && new_plus[0]>new_minus[0]) expected=0;
   if(adx[0]>=25 && old_minus[0]<=old_plus[0] && new_minus[0]>new_plus[0]) expected=1;
   TradingSignal signal;
   bool generated=closed_generator.GenerateSignal(_Symbol,_Period,signal);
   Check(generated==(expected>=0),"Closed-bar crossover presence matches independent scalar reads");
   if(generated)
   {
      crosses++;
      Check(signal.type==expected,"Crossover direction follows time order");
      Check(signal.strategy=="ADXStrategy" && signal.strategy_name==signal.strategy,"Strategy identity retained");
      Check(signal.entry_price==signal.price && signal.stop_loss==signal.sl && signal.take_profit==signal.tp,"Canonical and legacy fields agree");
      Check(expected==0?(signal.sl<signal.price && signal.tp>signal.price):(signal.sl>signal.price && signal.tp<signal.price),"Directional stops are valid");
   }
}
double OnTester()
{
   Check(bars>0 && crosses>0,"Actual historical crossovers exercised");
   PrintFormat("[ADX RESULT] checks=%d failures=%d bars=%d crosses=%d tick_events=%d",checks,failures,bars,crosses,tick_events);
   return failures==0?checks:-failures;
}
void OnDeinit(const int reason){if(reference_handle!=INVALID_HANDLE) IndicatorRelease(reference_handle);}

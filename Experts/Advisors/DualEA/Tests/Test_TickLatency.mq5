#property strict
#include "../Include/CSystemMonitor.mqh"
int checks=0,failures=0;
void Check(bool ok,string label)
{
   checks++;
   if(!ok){failures++;Print("[TICK-LATENCY FAIL] ",label);}
}
int OnInit()
{
   FolderCreate("DualEA");
   CSystemMonitor fast;
   Check(fast.GetTickSampleCount()==0,"No invented startup sample");
   fast.OnTickUpdate(1000);
   const ulong idle_start=GetMicrosecondCount();
   // Tester Sleep advances virtual time, so create a real counter gap here.
   // This wait is outside the completed OnTick-work sample being recorded.
   while(GetMicrosecondCount()-idle_start<120000) {}
   const ulong idle_us=GetMicrosecondCount()-idle_start;
   Check(idle_us>=120000,"Real elapsed gap exceeds the unchanged critical threshold");
   fast.OnTickUpdate(500);
   fast.EvaluateHealth();
   Check(MathAbs(fast.GetLastTickWorkMs()-0.5)<1e-10,"Microsecond-to-millisecond units");
   Check(fast.GetTickSampleCount()==2,"One sample per completed tick");
   Check(fast.GetMetricStatus(HEALTH_TICK_LATENCY)==HEALTH_OK,"Idle quote gap is not execution latency");
   Check(!fast.IsCircuitBreakerActive(),"No false idle-gap circuit breaker");
   for(int i=0;i<70;i++) fast.OnTickUpdate(1000);
   fast.EvaluateHealth();
   Check(fast.GetTickSampleCount()==72,"Ring wrap retains total sample count");
   Check(fast.GetMetricStatus(HEALTH_TICK_LATENCY)==HEALTH_OK,"Fast tick work remains healthy after ring wrap");

   CSystemMonitor warning;
   warning.OnTickUpdate(15000);
   Check(warning.GetMetricStatus(HEALTH_TICK_LATENCY)==HEALTH_WARNING,"15ms handler warns");
   Check(!warning.IsCircuitBreakerActive(),"Warning does not trip breaker");

   CSystemMonitor slow;
   slow.OnTickUpdate(75000);
   Check(slow.GetMetricStatus(HEALTH_TICK_LATENCY)==HEALTH_CRITICAL,"75ms handler is critical");
   Check(slow.IsCircuitBreakerActive(),"Genuinely slow handler still trips breaker");
   Check(slow.GetCircuitBreakerReason()=="TickLatency","Correct critical reason");
   Check(slow.GetCircuitBreakerTriggeredTime()>0,"Trip timestamp recorded");
   Check(!fast.IsCircuitBreakerActive(),"Monitor instances do not share health-check state");
   slow.ResetCircuitBreaker();
   Check(slow.GetCircuitBreakerReason()=="","Reset clears stale trigger reason");
   Check(slow.GetCircuitBreakerTriggeredTime()==0,"Reset clears stale trigger timestamp");
   slow.EvaluateHealth();
   Check(slow.IsCircuitBreakerActive(),"Unresolved real overload retrips after manual reset");
   for(int i=0;i<5;i++) slow.OnTickUpdate(1000);
   slow.EvaluateHealth();
   Check(slow.GetMetricStatus(HEALTH_TICK_LATENCY)==HEALTH_OK,"Recent fast samples restore metric health");
   Check(slow.IsCircuitBreakerActive(),"Recovery preserves the existing breaker cooldown");
   slow.ResetCircuitBreaker();
   Check(!slow.IsCircuitBreakerActive(),"Healthy monitor can be reset");

   CSystemMonitor boundary_warning;
   boundary_warning.OnTickUpdate(10000);
   Check(boundary_warning.GetMetricStatus(HEALTH_TICK_LATENCY)==HEALTH_OK,"Existing 10ms boundary unchanged");
   CSystemMonitor boundary_critical;
   boundary_critical.OnTickUpdate(50000);
   Check(boundary_critical.GetMetricStatus(HEALTH_TICK_LATENCY)==HEALTH_WARNING,"Existing 50ms boundary unchanged");
   CSystemMonitor above_critical;
   above_critical.OnTickUpdate(50001);
   Check(above_critical.GetMetricStatus(HEALTH_TICK_LATENCY)==HEALTH_CRITICAL,"50.001ms is critical");
   CSystemMonitor zero;
   zero.OnTickUpdate(0);
   Check(zero.GetLastTickWorkMs()==0 && zero.GetTickSampleCount()==1,"Zero-duration fast sample is valid");
   CSystemMonitor spike;
   for(int i=0;i<5;i++) spike.OnTickUpdate(1000);
   spike.OnTickUpdate(50001);
   Check(spike.IsCircuitBreakerActive(),"Single spike trips immediately even between periodic checks");
   Check(spike.GetMaxTickWorkMs()==50.001,"Lifetime maximum retains isolated spike");
   for(int i=0;i<70;i++) spike.OnTickUpdate(100);
   Check(spike.GetMaxTickWorkMs()==50.001,"Maximum survives ring wrap and fast recovery");
   CSystemMonitor overhead;
   overhead.OnTickUpdate(1000);
   overhead.RecordHandlerCompletion(50001);
   Check(overhead.IsCircuitBreakerActive(),"Monitor overhead crossing limit also trips");
   Check(overhead.GetHandlerCriticalCount()==1,"Individual critical exceedance counted");
   overhead.RecordHandlerCompletion(100);
   Check(overhead.GetMaxHandlerMs()==50.001,"Complete-handler maximum retained");
   overhead.PrintLatencySummary();
   CSystemMonitor measured;
   const ulong busy_started=GetMicrosecondCount();
   while(GetMicrosecondCount()-busy_started<60000) {}
   const ulong busy_elapsed=GetMicrosecondCount()-busy_started;
   measured.OnTickUpdate(busy_elapsed);
   measured.RecordHandlerCompletion(GetMicrosecondCount()-busy_started);
   Check(measured.IsCircuitBreakerActive(),"Measured CPU stall trips without synthetic duration input");
   Check(measured.GetMaxHandlerMs()>=60,"Actual measured stall retained in handler maximum");
   PrintFormat("[TICK-LATENCY RESULT] checks=%d failures=%d idle_gap_us=%I64u",checks,failures,idle_us);
   return failures==0 ? INIT_SUCCEEDED : INIT_FAILED;
}
void OnTick() {}
double OnTester(){return failures==0 ? checks : -failures;}

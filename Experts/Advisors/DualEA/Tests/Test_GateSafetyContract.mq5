#property strict
#include "../Include/EnhancedEfficientGateSystem.mqh"
int failures=0,checks=0;
void Check(bool ok,string label) { checks++; if(!ok) { failures++; Print("[GATE-SAFETY FAIL] ",label); } }
int OnInit()
{
   CEfficientGateManagerEnhanced manager;
   manager.Initialize(false);
   TradingSignal signal;
   signal.Init();
   signal.id="gate-safety";
   signal.strategy="test";
   signal.symbol=_Symbol;
   signal.timeframe=_Period;
   signal.price=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   signal.sl=signal.price-100*_Point;
   signal.tp=signal.price+200*_Point;
   signal.volume=0.01;
   signal.confidence=0.01;
   CSignalDecision decision;
   string reason;
   for(int mode=0;mode<=4;mode++)
   {
      manager.SetMode((EGateProcessingMode)mode);
      signal.confidence=0.01;
      bool passed=manager.ProcessSignalEnhanced(signal,decision,reason);
      Check(!passed,"Low-confidence risk failure blocks every processing mode");
      Check(!decision.gate_results[0],"G1 result records failure");
      Check(decision.gate_timestamps[0]>0,"G1 actually evaluated");
      Check(reason!="","Blocking reason retained");
      Check(decision.original_volume==0.01 && decision.signal_id==signal.id,"Original fields retained");
   }
   signal.volume=0;
   Check(!manager.ProcessSignalEnhanced(signal,decision,reason),"Explicit zero volume rejected");
   manager.Shutdown();
   PrintFormat("[GATE-SAFETY RESULT] checks=%d failures=%d",checks,failures);
   return failures==0 ? INIT_SUCCEEDED : INIT_FAILED;
}
void OnTick() {}
double OnTester() { return failures==0 ? checks : -failures; }

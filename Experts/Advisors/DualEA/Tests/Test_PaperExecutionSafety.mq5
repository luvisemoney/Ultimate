#property strict
#include "../Include/PaperExecutionSafety.mqh"
int failures=0;
int checks=0;
void Check(bool passed,string label)
{
   checks++;
   if(!passed) { failures++; Print("[SAFETY FAIL] ",label); }
}
int OnInit()
{
   Check(!PaperAccountAllowed(false,ACCOUNT_TRADE_MODE_REAL),"real account refused");
   Check(!PaperAccountAllowed(false,ACCOUNT_TRADE_MODE_CONTEST),"contest refused");
   Check(PaperAccountAllowed(false,ACCOUNT_TRADE_MODE_DEMO),"demo allowed");
   Check(PaperAccountAllowed(true,ACCOUNT_TRADE_MODE_REAL),"tester simulated account allowed");
   for(int tester=0;tester<2;tester++)
      for(int mode=0;mode<3;mode++)
         for(int enabled=0;enabled<2;enabled++)
            for(int shadow=0;shadow<2;shadow++)
            {
               bool expected=(tester==1 || mode==ACCOUNT_TRADE_MODE_DEMO) && enabled==1 && shadow==0;
               Check(PaperExecutionAllowed((bool)tester,mode,(bool)enabled,(bool)shadow)==expected,"execution matrix");
            }
   PrintFormat("[SAFETY RESULT] checks=%d failures=%d",checks,failures);
   return failures==0 ? INIT_SUCCEEDED : INIT_FAILED;
}
void OnTick() {}
double OnTester() { return failures==0 ? checks : -failures; }

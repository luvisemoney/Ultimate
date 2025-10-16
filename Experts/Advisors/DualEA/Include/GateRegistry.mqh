#ifndef __GATE_REGISTRY_MQH__
#define __GATE_REGISTRY_MQH__

#include "GateManager.mqh" // for IGate and concrete gate classes

// List default gate names in pipeline order
void GetDefaultGateNames(string &out[])
{
   ArrayResize(out, 8);
   out[0] = "SignalRinse";
   out[1] = "MarketSoap";
   out[2] = "StrategyScrub";
   out[3] = "RiskWash";
   out[4] = "PerformanceWax";
   out[5] = "MLPolish";
   out[6] = "LiveClean";
   out[7] = "FinalVerify";
}

// Factory: instantiate a gate by name
IGate* CreateGateByName(const string name)
{
   if(name == "SignalRinse")  return new CSignalRinseGate();
   if(name == "MarketSoap")   return new CMarketSoapGate();
   if(name == "StrategyScrub")return new CStrategyScrubGate();
   if(name == "RiskWash")     return new CRiskWashGate();
   if(name == "PerformanceWax")return new CPerformanceWaxGate();
   if(name == "MLPolish")     return new CMLPolishGate();
   if(name == "LiveClean")    return new CLiveCleanGate();
   if(name == "FinalVerify")  return new CFinalVerifyGate();
   return NULL;
}

#endif // __GATE_REGISTRY_MQH__

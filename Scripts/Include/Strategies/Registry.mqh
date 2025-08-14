// Strategies/Registry.mqh (Scripts copy)
// Central registry for default strategy names used by builders/selectors.
#property copyright "2025, Windsurf"
#property strict

#ifndef __STRATEGIES_REGISTRY_MQH__
#define __STRATEGIES_REGISTRY_MQH__

void GetDefaultStrategyNames(string &out[])
  {
   ArrayResize(out, 5);
   // Update when strategies change
   out[0] = "BollAveragesStrategy";
   out[1] = "DonchianATRBreakoutStrategy";
   out[2] = "MeanReversionBBStrategy";
   out[3] = "RSI2BBReversionStrategy";
   out[4] = "SuperTrendADXKamaStrategy";
  }

#endif // __STRATEGIES_REGISTRY_MQH__

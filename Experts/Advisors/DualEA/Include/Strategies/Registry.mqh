// Strategies/Registry.mqh
// Central registry for default strategy names used by builders/selectors.
#property copyright "2025, Windsurf Engineering"
#property strict

#ifndef __STRATEGIES_REGISTRY_MQH__
#define __STRATEGIES_REGISTRY_MQH__

// Fill 'out' with the default strategy class names.
// This function resets the array each call.
void GetDefaultStrategyNames(string &out[])
  {
   ArrayResize(out, 9);
   // Update this list when strategies change
   // Names must match class-name identifiers used by strategies
   out[0] = "BollAveragesStrategy";
   out[1] = "DonchianATRBreakoutStrategy";
   out[2] = "MeanReversionBBStrategy";
   out[3] = "RSI2BBReversionStrategy";
   out[4] = "SuperTrendADXKamaStrategy";
   // Newly added
   out[5] = "OpeningRangeBreakoutStrategy";
   out[6] = "VWAPReversionStrategy";
   out[7] = "EMAPullbackStrategy";
   out[8] = "KeltnerMomentumStrategy";
  }

#endif // __STRATEGIES_REGISTRY_MQH__

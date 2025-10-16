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
   ArrayResize(out, 21);
   // Names must match IStrategy::Name() returns
   int i=0;
   out[i++] = "ADXStrategy";
   out[i++] = "AcceleratorOscillatorStrategy";
   out[i++] = "AlligatorStrategy";
   out[i++] = "AroonStrategy";
   out[i++] = "AwesomeOscillatorStrategy";
   out[i++] = "BearsPowerStrategy";
   out[i++] = "BollsAveragesStrategy"; // fallback alias if present (kept for compatibility)
   out[i++] = "BollAveragesStrategy";
   out[i++] = "BullsPowerStrategy";
   out[i++] = "DonchianATRBreakoutStrategy";
   out[i++] = "EMAPullbackStrategy";
   out[i++] = "ForexTrendStrategy";
   out[i++] = "GoldVolatilityStrategy";
   out[i++] = "IndicesEnergiesStrategy";
   out[i++] = "KeltnerMomentumStrategy";
   out[i++] = "MeanReversionBBStrategy";
   out[i++] = "MultiIndicatorStrategy";
   out[i++] = "OpeningRangeBreakoutStrategy";
   out[i++] = "RSI2BBReversionStrategy";
   out[i++] = "SuperTrendADXKamaStrategy";
   out[i++] = "VWAPReversionStrategy";
  }

#endif // __STRATEGIES_REGISTRY_MQH__

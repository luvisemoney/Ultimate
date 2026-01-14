// Strategies/AssetRegistry.mqh
// Per-asset-class strategy registration for a given symbol/timeframe
#property strict

#ifndef __ASSET_REGISTRY_MQH__
#define __ASSET_REGISTRY_MQH__

#include <Arrays/ArrayObj.mqh>
#include "..\\IStrategy.mqh"

// Concrete strategies
#include "BollAveragesStrategy.mqh"
#include "MeanReversionBBStrategy.mqh"
#include "SuperTrendADXKamaStrategy.mqh"
#include "RSI2BBReversionStrategy.mqh"
#include "DonchianATRBreakoutStrategy.mqh"
#include "OpeningRangeBreakoutStrategy.mqh"
#include "VWAPReversionStrategy.mqh"
#include "EMAPullbackStrategy.mqh"
#include "KeltnerMomentumStrategy.mqh"

enum AssetClass
{
   ASSET_FX_MAJOR,
   ASSET_FX_MINOR,
   ASSET_STOCK,
   ASSET_COMMODITY,
   ASSET_CRYPTO,
   ASSET_OTHER
};

AssetClass ClassifySymbol(const string symbol)
{
   string upper = symbol;
   StringToUpper(upper);

   // FX classification
   if (StringFind(upper, "USD") >= 0)
   {
      if (StringFind(upper, "EUR") >= 0 || StringFind(upper, "GBP") >= 0 ||
          StringFind(upper, "JPY") >= 0 || StringFind(upper, "CHF") >= 0 ||
          StringFind(upper, "CAD") >= 0 || StringFind(upper, "AUD") >= 0 ||
          StringFind(upper, "NZD") >= 0)
         return ASSET_FX_MAJOR;
      return ASSET_FX_MINOR;
   }
   return ASSET_OTHER;
}

struct StrategyInfo
{
   string name;
   IStrategy* strategy;
};

void RegisterStrategiesForSymbol(CArrayObj* out, const string symbol, const ENUM_TIMEFRAMES tf)
{
   if (CheckPointer(out) == POINTER_INVALID) return;

   StrategyInfo strategies[20];
   int count = 0;

   AssetClass asset = ClassifySymbol(symbol);

   switch (asset)
   {
      case ASSET_FX_MAJOR:
         strategies[count].name = "SuperTrendADXKama";
         strategies[count++].strategy = new CSuperTrendADXKamaStrategy(symbol, tf);
         strategies[count].name = "RSI2BBReversion";
         strategies[count++].strategy = new CRSI2BBReversionStrategy(symbol, tf);
         strategies[count].name = "DonchianATRBreakout";
         strategies[count++].strategy = new CDonchianATRBreakoutStrategy(symbol, tf);
         strategies[count].name = "MeanReversionBB";
         strategies[count++].strategy = new CMeanReversionBBStrategy(symbol, tf);
         strategies[count].name = "KeltnerMomentum";
         strategies[count++].strategy = new CKeltnerMomentumStrategy(symbol, tf);
         strategies[count].name = "VWAPReversion";
         strategies[count++].strategy = new CVWAPReversionStrategy(symbol, tf);
         strategies[count].name = "EMAPullback";
         strategies[count++].strategy = new CEMAPullbackStrategy(symbol, tf);
         strategies[count].name = "OpeningRangeBreakout";
         strategies[count++].strategy = new COpeningRangeBreakoutStrategy(symbol, tf);
         break;

      case ASSET_FX_MINOR:
         strategies[count].name = "MeanReversionBB";
         strategies[count++].strategy = new CMeanReversionBBStrategy(symbol, tf);
         strategies[count].name = "EMAPullback";
         strategies[count++].strategy = new CEMAPullbackStrategy(symbol, tf);
         break;

      case ASSET_STOCK:
         strategies[count].name = "VWAPReversion";
         strategies[count++].strategy = new CVWAPReversionStrategy(symbol, tf);
         strategies[count].name = "OpeningRangeBreakout";
         strategies[count++].strategy = new COpeningRangeBreakoutStrategy(symbol, tf);
         break;

      case ASSET_COMMODITY:
         strategies[count].name = "KeltnerMomentum";
         strategies[count++].strategy = new CKeltnerMomentumStrategy(symbol, tf);
         break;

      case ASSET_CRYPTO:
         strategies[count].name = "SuperTrendADXKama";
         strategies[count++].strategy = new CSuperTrendADXKamaStrategy(symbol, tf);
         break;

      default:
         strategies[count].name = "MeanReversionBB";
         strategies[count++].strategy = new CMeanReversionBBStrategy(symbol, tf);
         break;
   }

   for (int i = 0; i < count; i++)
   {
      (*strategies[i].strategy).SetName(strategies[i].name);
      out.Add(strategies[i].strategy);
   }
}

#endif // __ASSET_REGISTRY_MQH__

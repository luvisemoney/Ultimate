// Strategies/AssetRegistry.mqh
// Per-asset-class strategy registration for a given symbol/timeframe
#property strict

#ifndef __ASSET_REGISTRY_MQH__
#define __ASSET_REGISTRY_MQH__

#include <Arrays/ArrayObj.mqh>

// Strategy interface
#include "..\\IStrategy.mqh"

// Concrete strategies (centralized includes)
#include "..\\Strategies\\BollAveragesStrategy.mqh"
#include "..\\Strategies\\MeanReversionBBStrategy.mqh"
#include "..\\Strategies\\SuperTrendADXKamaStrategy.mqh"
#include "..\\Strategies\\RSI2BBReversionStrategy.mqh"
#include "..\\Strategies\\DonchianATRBreakoutStrategy.mqh"
// Newly added strategies for indices and crypto
#include "..\\Strategies\\OpeningRangeBreakoutStrategy.mqh"
#include "..\\Strategies\\VWAPReversionStrategy.mqh"
#include "..\\Strategies\\EMAPullbackStrategy.mqh"
#include "..\\Strategies\\KeltnerMomentumStrategy.mqh"

// --- Asset class taxonomy
enum AssetClass
  {
   ASSET_FX_MAJOR = 0,
   ASSET_FX_MINOR = 1,
   ASSET_CRYPTO   = 2,
   ASSET_METAL    = 3,
   ASSET_ENERGY   = 4,
   ASSET_INDEX    = 5,
   ASSET_OTHER    = 6
  };

// Helpers
string ToLowerCopy(string s){ StringToLower(s); return s; }
string ToUpperCopy(string s){ StringToUpper(s); return s; }

bool ContainsAny(const string haystack, string &needles[])
  {
   for(int i=0;i<ArraySize(needles);++i)
     if(StringFind(haystack, needles[i])>=0)
        return true;
   return false;
  }

int CountContains(const string haystack, string &needles[])
  {
   int cnt=0;
   for(int i=0;i<ArraySize(needles);++i)
     if(StringFind(haystack, needles[i])>=0)
        cnt++;
   return cnt;
  }

AssetClass ClassifySymbol(const string symbol)
  {
   string sL = ToLowerCopy(symbol);
   string sU = ToUpperCopy(symbol);

   // --- Crypto
   string crypto_tokens[] = { "btc","xbt","eth","ltc","xrp","ada","doge","sol","dot","bch","bnb","matic","trx","atom","avax" };
   if(ContainsAny(sL, crypto_tokens))
      return ASSET_CRYPTO;

   // --- Metals
   string metal_tokens[]  = { "xau","xag","xpt","xpd","gold","silver","platinum","palladium" };
   if(ContainsAny(sL, metal_tokens))
      return ASSET_METAL;

   // --- Energies
   string energy_tokens[] = { "xbr","brent","wti","usoil","ukoil","oil","xng","ngas","natgas" };
   if(ContainsAny(sL, energy_tokens))
      return ASSET_ENERGY;

   // --- Indices
   string index_tokens[]  = { "us30","dj30","dow","us500","spx","sp500","nas100","ndx","nasdaq",
                              "ger40","dax","uk100","ftse","fra40","cac","jpn225","jp225","nik","hk50","hsi","aus200","spain35","ita40" };
   if(ContainsAny(sL, index_tokens))
      return ASSET_INDEX;

   // --- FX majors/minors heuristic
   string ccy[] = { "USD","EUR","GBP","JPY","CHF","AUD","NZD","CAD","SEK","NOK","DKK","SGD","HKD","CNY","CNH","ZAR","MXN","TRY" };
   int ccy_hits = CountContains(sU, ccy);
   if(ccy_hits>=2)
     {
      bool has_usd = (StringFind(sU, "USD")>=0);
      string g7[] = { "EUR","GBP","JPY","CHF","AUD","NZD","CAD" };
      bool other_in_g7=false; for(int i=0;i<ArraySize(g7);++i) if(StringFind(sU, g7[i])>=0 && g7[i]!="USD") { other_in_g7=true; break; }
      if(has_usd && other_in_g7) return ASSET_FX_MAJOR;
      return ASSET_FX_MINOR;
     }

   return ASSET_OTHER;
  }

// Register strategies based on asset class. This appends to 'out'.
void RegisterStrategiesForSymbol(CArrayObj* out, const string symbol, const ENUM_TIMEFRAMES tf)
  {
   if(CheckPointer(out)==POINTER_INVALID) return;
   AssetClass ac = ClassifySymbol(symbol);

   switch(ac)
     {
      case ASSET_FX_MAJOR:
      case ASSET_FX_MINOR:
        {
         out.Add((CObject*)new CSuperTrendADXKamaStrategy(symbol, tf));
         out.Add((CObject*)new CRSI2BBReversionStrategy(symbol, tf));
         out.Add((CObject*)new CDonchianATRBreakoutStrategy(symbol, tf));
         // Conservative: keep MR BB for tighter ranges on minors
         if(ac==ASSET_FX_MINOR)
            out.Add((CObject*)new CMeanReversionBBStrategy(symbol, tf));
         break;
        }
      case ASSET_METAL:
        {
         // Metals: combine trend and mean-reversion
         out.Add((CObject*)new CSuperTrendADXKamaStrategy(symbol, tf));
         out.Add((CObject*)new CRSI2BBReversionStrategy(symbol, tf));
         break;
        }
      case ASSET_CRYPTO:
        {
        // Crypto: momentum on Keltner, breakout, and VWAP reversion
        out.Add((CObject*)new CKeltnerMomentumStrategy(symbol, tf));
        out.Add((CObject*)new CDonchianATRBreakoutStrategy(symbol, tf));
        out.Add((CObject*)new CVWAPReversionStrategy(symbol, tf));
        out.Add((CObject*)new CSuperTrendADXKamaStrategy(symbol, tf));
        break;
        }
      case ASSET_ENERGY:
        {
         out.Add((CObject*)new CSuperTrendADXKamaStrategy(symbol, tf));
         out.Add((CObject*)new CDonchianATRBreakoutStrategy(symbol, tf));
         break;
        }
      case ASSET_INDEX:
        {
        // Indices: opening range breakout, EMA pullback, VWAP reversion, and trend
        out.Add((CObject*)new COpeningRangeBreakoutStrategy(symbol, tf));
        out.Add((CObject*)new CEMAPullbackStrategy(symbol, tf));
        out.Add((CObject*)new CVWAPReversionStrategy(symbol, tf));
        out.Add((CObject*)new CSuperTrendADXKamaStrategy(symbol, tf));
        break;
        }
      case ASSET_OTHER:
      default:
        {
         // Fallback: previously verified trio
         out.Add((CObject*)new CSuperTrendADXKamaStrategy(symbol, tf));
         out.Add((CObject*)new CRSI2BBReversionStrategy(symbol, tf));
         out.Add((CObject*)new CDonchianATRBreakoutStrategy(symbol, tf));
         break;
        }
     }
  }

#endif // __ASSET_REGISTRY_MQH__

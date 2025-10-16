#ifndef __STRATEGY_FACTORY_MQH__
#define __STRATEGY_FACTORY_MQH__

#include "IStrategy.mqh"

#include "Strategies/ADXStrategy.mqh"
#include "Strategies/AcceleratorOscillatorStrategy.mqh"
#include "Strategies/AlligatorStrategy.mqh"
#include "Strategies/AroonStrategy.mqh"
#include "Strategies/AwesomeOscillatorStrategy.mqh"
#include "Strategies/BearsPowerStrategy.mqh"
#include "Strategies/BollAveragesStrategy.mqh"
#include "Strategies/BullsPowerStrategy.mqh"
#include "Strategies/DonchianATRBreakoutStrategy.mqh"
#include "Strategies/EMAPullbackStrategy.mqh"
#include "Strategies/ForexTrendStrategy.mqh"
#include "Strategies/GoldVolatilityStrategy.mqh"
#include "Strategies/IndicesEnergiesStrategy.mqh"
#include "Strategies/KeltnerMomentumStrategy.mqh"
#include "Strategies/MeanReversionBBStrategy.mqh"
#include "Strategies/MultiIndicatorStrategy.mqh"
#include "Strategies/OpeningRangeBreakoutStrategy.mqh"
#include "Strategies/RSI2BBReversionStrategy.mqh"
#include "Strategies/SuperTrendADXKamaStrategy.mqh"
#include "Strategies/VWAPReversionStrategy.mqh"

// Factory: instantiate strategy by its published Name()
IStrategy* CreateStrategyByName(const string name, const string symbol, const ENUM_TIMEFRAMES timeframe)
{
   if(name == "ADXStrategy") return new CADXStrategy(symbol, timeframe);
   if(name == "AcceleratorOscillatorStrategy") return new CAcceleratorOscillatorStrategy(symbol, timeframe);
   if(name == "AlligatorStrategy") return new CAlligatorStrategy(symbol, timeframe);
   if(name == "AroonStrategy") return new CAroonStrategy(symbol, timeframe);
   if(name == "AwesomeOscillatorStrategy") return new CAwesomeOscillatorStrategy(symbol, timeframe);
   if(name == "BearsPowerStrategy") return new CBearsPowerStrategy(symbol, timeframe);
   if(name == "BollAveragesStrategy") return new CBollAveragesStrategy(symbol, timeframe);
   if(name == "BullsPowerStrategy") return new CBullsPowerStrategy(symbol, timeframe);
   if(name == "DonchianATRBreakoutStrategy") return new CDonchianATRBreakoutStrategy(symbol, timeframe);
   if(name == "EMAPullbackStrategy") return new CEMAPullbackStrategy(symbol, timeframe);
   if(name == "ForexTrendStrategy") return new CForexTrendStrategy(symbol, timeframe);
   if(name == "GoldVolatilityStrategy") return new CGoldVolatilityStrategy(symbol, timeframe);
   if(name == "IndicesEnergiesStrategy") return new CIndicesEnergiesStrategy(symbol, timeframe);
   if(name == "KeltnerMomentumStrategy") return new CKeltnerMomentumStrategy(symbol, timeframe);
   if(name == "MeanReversionBBStrategy") return new CMeanReversionBBStrategy(symbol, timeframe);
   if(name == "MultiIndicatorStrategy") return new CMultiIndicatorStrategy(symbol, timeframe);
   if(name == "OpeningRangeBreakoutStrategy") return new COpeningRangeBreakoutStrategy(symbol, timeframe);
   if(name == "RSI2BBReversionStrategy") return new CRSI2BBReversionStrategy(symbol, timeframe);
   if(name == "SuperTrendADXKamaStrategy") return new CSuperTrendADXKamaStrategy(symbol, timeframe);
   if(name == "VWAPReversionStrategy") return new CVWAPReversionStrategy(symbol, timeframe);
   return NULL;
}

#endif // __STRATEGY_FACTORY_MQH__

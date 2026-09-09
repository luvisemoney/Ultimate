//+------------------------------------------------------------------+
//| LiveEA Strategy Bridge - Connects PaperEA insights to LiveEA     |
//+------------------------------------------------------------------+
#include "../Include/IStrategy.mqh"
#include "../Include/Strategies\Registry.mqh"
#include "../Include/InsightsLoader.mqh"

// Include all strategy headers
#include "../Include/Strategies\BollAveragesStrategy.mqh"
#include "../Include/Strategies\DonchianATRBreakoutStrategy.mqh"
#include "../Include/Strategies\MeanReversionBBStrategy.mqh"
#include "../Include/Strategies\RSI2BBReversionStrategy.mqh"
#include "../Include/Strategies\SuperTrendADXKamaStrategy.mqh"
#include "../Include/Strategies\OpeningRangeBreakoutStrategy.mqh"
#include "../Include/Strategies\VWAPReversionStrategy.mqh"
#include "../Include/Strategies\EMAPullbackStrategy.mqh"
#include "../Include/Strategies\KeltnerMomentumStrategy.mqh"
#include "../Include/Strategies\AcceleratorOscillatorStrategy.mqh"
#include "../Include/Strategies\ADXStrategy.mqh"
#include "../Include/Strategies\AlligatorStrategy.mqh"
#include "../Include/Strategies\AroonStrategy.mqh"
#include "../Include/Strategies\MultiIndicatorStrategy.mqh"
#include "../Include/Strategies\GoldVolatilityStrategy.mqh"
#include "../Include/Strategies\ForexTrendStrategy.mqh"
#include "../Include/Strategies\IndicesEnergiesStrategy.mqh"
#include "../Include/Strategies\AwesomeOscillatorStrategy.mqh"
#include "../Include/Strategies\BearsPowerStrategy.mqh"
#include "../Include/Strategies\BullsPowerStrategy.mqh"

class CLiveEAStrategyBridge
{
private:
   IStrategy* m_strategies[];
   string     m_symbol;
   ENUM_TIMEFRAMES m_tf;
   bool       m_initialized;
   
public:
   CLiveEAStrategyBridge(const string symbol, const ENUM_TIMEFRAMES tf)
   {
      m_symbol = symbol;
      m_tf = tf;
      m_initialized = false;
      ArrayResize(m_strategies, 0);
   }
   
   ~CLiveEAStrategyBridge()
   {
      for(int i=0; i<ArraySize(m_strategies); ++i)
         if(CheckPointer(m_strategies[i])==POINTER_DYNAMIC)
            delete m_strategies[i];
   }
   
   bool Initialize()
   {
      if(m_initialized) return true;
      
      string strategy_names[];
      GetDefaultStrategyNames(strategy_names);
      
      for(int i=0; i<ArraySize(strategy_names); ++i)
      {
         IStrategy* strategy = CreateStrategy(strategy_names[i], m_symbol, m_tf);
         if(CheckPointer(strategy)!=POINTER_INVALID)
         {
            int size = ArraySize(m_strategies);
            ArrayResize(m_strategies, size+1);
            m_strategies[size] = strategy;
         }
      }
      
      m_initialized = true;
      return ArraySize(m_strategies) > 0;
   }
   
   IStrategy* CreateStrategy(const string name, const string symbol, const ENUM_TIMEFRAMES tf)
   {
      // Factory method to create strategies by name
      if(name == "BollAveragesStrategy") return new CBollAveragesStrategy(symbol, tf);
      if(name == "DonchianATRBreakoutStrategy") return new CDonchianATRBreakoutStrategy(symbol, tf);
      if(name == "MeanReversionBBStrategy") return new CMeanReversionBBStrategy(symbol, tf);
      if(name == "RSI2BBReversionStrategy") return new CRSI2BBReversionStrategy(symbol, tf);
      if(name == "SuperTrendADXKamaStrategy") return new CSuperTrendADXKamaStrategy(symbol, tf);
      if(name == "OpeningRangeBreakoutStrategy") return new COpeningRangeBreakoutStrategy(symbol, tf);
      if(name == "VWAPReversionStrategy") return new CVWAPReversionStrategy(symbol, tf);
      if(name == "EMAPullbackStrategy") return new CEMAPullbackStrategy(symbol, tf);
      if(name == "KeltnerMomentumStrategy") return new CKeltnerMomentumStrategy(symbol, tf);
      if(name == "AcceleratorOscillatorStrategy") return new CAcceleratorOscillatorStrategy(symbol, tf);
      if(name == "ADXStrategy") return new CADXStrategy(symbol, tf);
      if(name == "AlligatorStrategy") return new CAlligatorStrategy(symbol, tf);
      if(name == "AroonStrategy") return new CAroonStrategy(symbol, tf);
      if(name == "MultiIndicatorStrategy") return new CMultiIndicatorStrategy(symbol, tf);
      if(name == "GoldVolatilityStrategy") return new CGoldVolatilityStrategy(symbol, tf);
      if(name == "ForexTrendStrategy") return new CForexTrendStrategy(symbol, tf);
      if(name == "IndicesEnergiesStrategy") return new CIndicesEnergiesStrategy(symbol, tf);
      if(name == "AwesomeOscillatorStrategy") return new CAwesomeOscillatorStrategy(symbol, tf);
      if(name == "BearsPowerStrategy") return new CBearsPowerStrategy(symbol, tf);
      if(name == "BullsPowerStrategy") return new CBullsPowerStrategy(symbol, tf);
      
      return NULL;
   }
   
   void RefreshAll()
   {
      if(!m_initialized) return;
      
      for(int i=0; i<ArraySize(m_strategies); ++i)
         if(CheckPointer(m_strategies[i])!=POINTER_INVALID)
            m_strategies[i].Refresh();
   }
   
   TradeOrder CheckAllSignals()
   {
      TradeOrder best_order;
      best_order.action = ACTION_NONE;
      
      if(!m_initialized) return best_order;
      
      RefreshAll();
      
      for(int i=0; i<ArraySize(m_strategies); ++i)
      {
         if(CheckPointer(m_strategies[i])==POINTER_INVALID) continue;
         
         TradeOrder order = m_strategies[i].CheckSignal();
         if(order.action != ACTION_NONE)
         {
            // Simple priority: take the first valid signal
            return order;
         }
      }
      
      return best_order;
   }
   
   string GetStatus()
   {
      if(!m_initialized) return "Not initialized";
      return StringFormat("Bridge active with %d strategies", ArraySize(m_strategies));
   }
};

//+------------------------------------------------------------------+
//| CTestStrategy.mqh - Minimal test strategy stub                    |
//+------------------------------------------------------------------+
#ifndef CTESTSTRATEGY_MQH
#define CTESTSTRATEGY_MQH

#include "..\IStrategy.mqh"

//+------------------------------------------------------------------+
//| Test Strategy - Minimal implementation for compilation            |
//+------------------------------------------------------------------+
class CTestStrategy : public IStrategy
{
public:
   CTestStrategy(string symbol, ENUM_TIMEFRAMES timeframe) : IStrategy("TestStrategy", symbol, timeframe)
   {
   }
   
   virtual void Refresh() override
   {
   }
   
   virtual TradeOrder CheckSignal() override
   {
      TradeOrder order;
      return order;
   }
   
   virtual string Name() const override
   {
      return "TestStrategy";
   }
   
   virtual void ExportFeatures(CObject* obj, const datetime ts) override
   {
   }
};

#endif // CTESTSTRATEGY_MQH

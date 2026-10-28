#property strict
#include "../Include/TradeManager.mqh"
int checks=0,failures=0;
bool ran=false;
void Check(bool ok,string name){checks++;if(!ok){failures++;Print("[TP FAIL] ",name);}}
int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER) || AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}
void OnTick()
{
   if(ran)return;
   MqlDateTime clock;TimeToStruct(TimeCurrent(),clock);
   if(clock.hour<8)return; // Avoid the broker's closed rollover session.
   ran=true;
   CTradeManager manager(_Symbol,0.01,2026102809);manager.SetExecutionMode(EXEC_ENABLED);
   TradeOrder order;order.action=ACTION_BUY;order.order_type=ORDER_TYPE_BUY;
   order.lots=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);order.strategy_name="TP_regression";
   order.price=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double distance=MathMax(2000*_Point,(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)+100)*_Point);
   order.stop_loss=NormalizeDouble(bid-distance,_Digits);
   order.take_profit=NormalizeDouble(order.price+distance,_Digits);
   Check(manager.ExecuteOrder(order),"first protected entry accepted");
   order.take_profit=NormalizeDouble(order.price+2*distance,_Digits);
   Check(manager.ExecuteOrder(order),"second protected entry accepted");
   ulong tickets[];double targets[],stops[];
   for(int i=0;i<PositionsTotal();i++){
      ulong ticket=PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC)!=2026102809)continue;
      int n=ArraySize(tickets);ArrayResize(tickets,n+1);ArrayResize(targets,n+1);ArrayResize(stops,n+1);
      tickets[n]=ticket;targets[n]=PositionGetDouble(POSITION_TP);stops[n]=PositionGetDouble(POSITION_SL);
      Check(targets[n]>0,"server retained TP on entry");
   }
   Check(ArraySize(tickets)==2,"two same-symbol hedged positions exist");
   order.trailing_enabled=true;order.trailing_type=TRAIL_FIXED_POINTS;
   // Deliberately force the modifier branch immediately in this tester-only case.
   order.trail_activation_points=-100000;order.trail_distance_points=distance/_Point/2;order.trail_step_points=1;
   manager.ConfigureTrailing(order);manager.UpdateTrailingStops();
   for(int i=0;i<ArraySize(tickets);i++){
      Check(PositionSelectByTicket(tickets[i]),"same ticket still exists");
      Check(MathAbs(PositionGetDouble(POSITION_TP)-targets[i])<_Point/2,"each ticket retains its own target");
      Check(PositionGetDouble(POSITION_SL)>stops[i],"each ticket receives its own trailing SL");
   }
   PrintFormat("[TP RESULT] checks=%d failures=%d",checks,failures);
}
double OnTester(){return ran && failures==0?checks:-MathMax(1,failures);}

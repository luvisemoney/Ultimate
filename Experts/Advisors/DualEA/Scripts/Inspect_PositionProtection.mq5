#property strict
#property script_show_inputs
// Read-only diagnostic. No OrderSend, CTrade, modification or account identity.
void OnStart()
{
   for(int i=0;i<PositionsTotal();i++){
      ulong ticket=PositionGetTicket(i);if(ticket==0)continue;
      string symbol=PositionGetString(POSITION_SYMBOL);
      double tp=PositionGetDouble(POSITION_TP),sl=PositionGetDouble(POSITION_SL);
      string visibility="different_chart_symbol";
      if(symbol==_Symbol){
         double low=ChartGetDouble(0,CHART_PRICE_MIN),high=ChartGetDouble(0,CHART_PRICE_MAX);
         visibility=tp<=0?"missing":(tp>=low && tp<=high?"inside_visible_price_range":"outside_visible_price_range");
      }
      PrintFormat("[POSITION-INSPECT] ticket=%I64u symbol=%s entry=%.8f sl=%.8f tp=%.8f tp_chart=%s comment=%s magic=%I64d",
                  ticket,symbol,PositionGetDouble(POSITION_PRICE_OPEN),sl,tp,visibility,PositionGetString(POSITION_COMMENT),PositionGetInteger(POSITION_MAGIC));
   }
}

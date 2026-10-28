#property strict
// Execution benchmark only: it deliberately refuses every non-tester account.
// This is a separate model strategy, not a bypass of PaperEA's gate cascade.
#resource "ModelResources\\signal_model.onnx" as uchar BenchmarkModel[]
#resource "ModelResources\\onnx_config.ini" as uchar BenchmarkIni[]
#resource "ModelResources\\onnx_config.json" as uchar BenchmarkMetadata[]
#include <Trade/Trade.mqh>
#include "../Include/ModelPredictor.mqh"
#include "../Include/CMarketModelFeatures.mqh"
input double FixedLots=0.01;
input double MaximumRiskPercent=0.5;
input double MinimumProbability=0.5;
input double MaximumSpreadFraction=0.001;
input double ExtraRoundTurnCommissionPerLot=7.0; // Sensitivity assumption, additional to actual deal costs
input double ExtraSlippagePointsPerSide=2.0; // Sensitivity estimate, not execution-delay simulation
CModelPredictor predictor;
CTrade execution;
string trained_symbols[];
datetime last_bar=0;
int decisions=0,no_edge=0,risk_rejections=0,inference_failures=0;
int entry_requests=0,entries_filled=0,close_requests=0,request_failures=0;
int cost_failures=0;
double extra_costs=0,stress_costs=0;
const ulong benchmark_magic=2026102804;

bool WriteBenchmarkResource(string path,const uchar &bytes[])
{
   int f=FileOpen(path,FILE_WRITE|FILE_BIN);
   if(f==INVALID_HANDLE) return false;
   uint written=FileWriteArray(f,bytes);FileClose(f);
   return written==(uint)ArraySize(bytes);
}
int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER) || _Period!=PERIOD_H1 || FixedLots<=0 ||
      MaximumRiskPercent<=0 || MaximumRiskPercent>1 || MinimumProbability<0.5 || MinimumProbability>=1 ||
      ExtraRoundTurnCommissionPerLot<0 || ExtraSlippagePointsPerSide<0) return INIT_PARAMETERS_INCORRECT;
   FolderCreate("Benchmark");
   if(!WriteBenchmarkResource("Benchmark\\model.onnx",BenchmarkModel) ||
      !WriteBenchmarkResource("Benchmark\\config.ini",BenchmarkIni) ||
      !WriteBenchmarkResource("Benchmark\\config.json",BenchmarkMetadata)) return INIT_FAILED;
   if(!predictor.Init("Benchmark\\model.onnx","Benchmark\\config.json","Benchmark\\config.ini") ||
      predictor.FeatureContract()!="market_universal_v1" || !predictor.SupportsSymbol(_Symbol) ||
      !predictor.GetSupportedSymbols(trained_symbols)) return INIT_FAILED;
   execution.SetExpertMagicNumber(benchmark_magic);
   execution.SetTypeFillingBySymbol(_Symbol);
   execution.SetDeviationInPoints(20);
   Print("[BENCHMARK CONTRACT] tester_only=true strategy=ONNX_probability_4h_hold probability_threshold=",MinimumProbability,
      " holding_hours=4 stop_atr_multiple=2 fixed_lots=",FixedLots," risk_cap_pct=",MaximumRiskPercent,
      " extra_commission_per_lot=",ExtraRoundTurnCommissionPerLot," extra_slippage_points_per_side=",ExtraSlippagePointsPerSide);
   return INIT_SUCCEEDED;
}
void OnTick()
{
   if(PositionSelect(_Symbol))
   {
      if((ulong)PositionGetInteger(POSITION_MAGIC)!=benchmark_magic) return;
      if(TimeCurrent()-(datetime)PositionGetInteger(POSITION_TIME)>=4*3600)
      {
         close_requests++;
         if(!execution.PositionClose(_Symbol) || execution.ResultRetcode()!=TRADE_RETCODE_DONE)
         {request_failures++;Print("[BENCHMARK CLOSE REJECT] ",execution.ResultRetcodeDescription());}
      }
      return;
   }
   datetime bar=iTime(_Symbol,PERIOD_H1,0);
   // Match the hourly training entry horizon; do not open late after a mid-bar exit.
   if(bar<=0 || bar==last_bar || TimeCurrent()<bar || TimeCurrent()-bar>=60) return;
   double probability[2],base_buy[],features[];
   for(int side=0;side<2;side++)
   {
      double base[];
      if(!BuildMarketModelFeatures(_Symbol,PERIOD_H1,bar,side,base) ||
         !ExpandUniversalModelFeatures(base,_Symbol,trained_symbols,features)) return;
      if(side==0) ArrayCopy(base_buy,base);
      probability[side]=predictor.Predict(features,ArraySize(features));
      if(probability[side]<0){inference_failures++;last_bar=bar;return;}
   }
   last_bar=bar;decisions++;
   int side=probability[0]>probability[1]?0:1;
   if(probability[side]<=MinimumProbability || probability[0]==probability[1]){no_edge++;return;}
   MqlTick quote;
   if(!SymbolInfoTick(_Symbol,quote) || quote.bid<=0 || quote.ask<quote.bid) return;
   if((quote.ask-quote.bid)/quote.bid>MaximumSpreadFraction){risk_rejections++;return;}
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),minimum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maximum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(step<=0 || tick_size<=0){risk_rejections++;return;}
   double lots=MathFloor(FixedLots/step+1e-9)*step;
   if(lots<minimum || lots>maximum){risk_rejections++;return;}
   double previous_close=iClose(_Symbol,PERIOD_H1,1);
   double distance=2.0*base_buy[11]*previous_close;
   distance=MathMax(distance,(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)+1)*_Point+(quote.ask-quote.bid));
   double price=side==0?quote.ask:quote.bid;
   double sl=side==0?MathFloor((price-distance)/tick_size)*tick_size:MathCeil((price+distance)/tick_size)*tick_size;
   sl=NormalizeDouble(sl,_Digits);
   double loss;
   ENUM_ORDER_TYPE order_type=side==0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   if(sl<=0 || !OrderCalcProfit(order_type,_Symbol,lots,price,sl,loss) || loss>=0 ||
      -loss>AccountInfoDouble(ACCOUNT_EQUITY)*MaximumRiskPercent/100.0){risk_rejections++;return;}
   entry_requests++;
   PrintFormat("[BENCHMARK REQUEST] symbol=%s side=%s probability=%.6f volume=%.4f price=%.8f sl=%.8f",
      _Symbol,side==0?"BUY":"SELL",probability[side],lots,price,sl);
   bool sent=side==0?execution.Buy(lots,_Symbol,0,sl,0,"ONNX_4h_benchmark"):execution.Sell(lots,_Symbol,0,sl,0,"ONNX_4h_benchmark");
   if(sent && (execution.ResultRetcode()==TRADE_RETCODE_DONE || execution.ResultRetcode()==TRADE_RETCODE_DONE_PARTIAL))
   {
      entries_filled++;
      double extra=lots*ExtraRoundTurnCommissionPerLot;
      double spread_cash=0,slippage_cash=0;
      if(!OrderCalcProfit(order_type,_Symbol,lots,price,price+quote.ask-quote.bid,spread_cash)) cost_failures++;
      if(!OrderCalcProfit(order_type,_Symbol,lots,price,price+2*ExtraSlippagePointsPerSide*_Point,slippage_cash)) cost_failures++;
      extra_costs+=extra;
      stress_costs+=extra+MathAbs(spread_cash)*0.5+MathAbs(slippage_cash);
      PrintFormat("[BENCHMARK FILL] deal=%I64u volume=%.4f price=%.8f",execution.ResultDeal(),execution.ResultVolume(),execution.ResultPrice());
   }
   else{request_failures++;Print("[BENCHMARK ENTRY REJECT] ",execution.ResultRetcodeDescription());}
}
double OnTester()
{
   HistorySelect(0,TimeCurrent());
   double commission=0,swap=0,fees=0,realized=0;
   ulong owned_positions[];
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong deal=HistoryDealGetTicket(i);
      if(HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol || (ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=benchmark_magic) continue;
      ulong position=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
      bool seen=false;
      for(int j=0;j<ArraySize(owned_positions);j++) if(owned_positions[j]==position) seen=true;
      if(position>0 && !seen){int n=ArraySize(owned_positions);ArrayResize(owned_positions,n+1);owned_positions[n]=position;}
   }
   int ledger=FileOpen("benchmark-deals.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(ledger!=INVALID_HANDLE) FileWrite(ledger,"deal","position","time","type","entry","volume","price","profit","commission","swap","fee");
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong deal=HistoryDealGetTicket(i);
      ulong position=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
      bool owned=false;
      for(int j=0;j<ArraySize(owned_positions);j++) if(owned_positions[j]==position) owned=true;
      // Tester-enforced liquidation can use magic=0; ownership follows position ID.
      if(HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol || !owned) continue;
      commission+=HistoryDealGetDouble(deal,DEAL_COMMISSION);swap+=HistoryDealGetDouble(deal,DEAL_SWAP);
      fees+=HistoryDealGetDouble(deal,DEAL_FEE);realized+=HistoryDealGetDouble(deal,DEAL_PROFIT);
      if(ledger!=INVALID_HANDLE) FileWrite(ledger,deal,HistoryDealGetInteger(deal,DEAL_POSITION_ID),TimeToString((datetime)HistoryDealGetInteger(deal,DEAL_TIME),TIME_DATE|TIME_SECONDS),
         HistoryDealGetInteger(deal,DEAL_TYPE),HistoryDealGetInteger(deal,DEAL_ENTRY),HistoryDealGetDouble(deal,DEAL_VOLUME),HistoryDealGetDouble(deal,DEAL_PRICE),
         HistoryDealGetDouble(deal,DEAL_PROFIT),HistoryDealGetDouble(deal,DEAL_COMMISSION),HistoryDealGetDouble(deal,DEAL_SWAP),HistoryDealGetDouble(deal,DEAL_FEE));
   }
   if(ledger!=INVALID_HANDLE) FileClose(ledger);
   double net=TesterStatistics(STAT_PROFIT),loss=TesterStatistics(STAT_GROSS_LOSS);
   double pf=loss<0?TesterStatistics(STAT_GROSS_PROFIT)/MathAbs(loss):0;
   string summary=StringFormat("{\"symbol\":\"%s\",\"decisions\":%d,\"no_edge\":%d,\"risk_rejections\":%d,\"inference_failures\":%d,\"entry_requests\":%d,\"entries_filled\":%d,\"close_requests\":%d,\"request_failures\":%d,\"trades\":%.0f,\"wins\":%.0f,\"net_profit\":%.6f,\"gross_profit\":%.6f,\"gross_loss\":%.6f,\"profit_factor\":%.6f,\"equity_drawdown_pct\":%.6f,\"commission\":%.6f,\"swap\":%.6f,\"fees\":%.6f,\"deal_ledger_net\":%.6f,\"net_after_extra_commission\":%.6f,\"net_after_stress_costs\":%.6f}",
      _Symbol,decisions,no_edge,risk_rejections,inference_failures,entry_requests,entries_filled,close_requests,request_failures,
      TesterStatistics(STAT_TRADES),TesterStatistics(STAT_PROFIT_TRADES),net,TesterStatistics(STAT_GROSS_PROFIT),loss,pf,TesterStatistics(STAT_EQUITY_DDREL_PERCENT),
      commission,swap,fees,realized+commission+swap+fees,net-extra_costs,net-stress_costs);
   summary=StringSubstr(summary,0,StringLen(summary)-1)+StringFormat(",\"cost_failures\":%d}",cost_failures);
   Print("[BENCHMARK RESULT] ",summary);
   return net-stress_costs;
}

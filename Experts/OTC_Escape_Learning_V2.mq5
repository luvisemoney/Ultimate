//+------------------------------------------------------------------+
//|                             OTC Escape EA (Learning) V2           |
//|                        Optimized for OTC Markets                  |
//|                              With Machine Learning                |
//+------------------------------------------------------------------+
#property version   "2.00"
#property strict

//--- Include files
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Arrays\ArrayObj.mqh>
#include <OTCTypes.mqh>
#include <OTCLearningEngine.mqh>

//--- Global Objects
CPositionInfo  m_position;                   // trade position object
CTrade         m_trade;                      // trading object
CSymbolInfo    m_symbol;                     // symbol info object
CAccountInfo   m_account;                    // account info wrapper
CLearningEngine *learning_engine = NULL;     // learning engine object

//--- Indicator Handles
int handle_ma_fast, handle_ma_slow, handle_rsi, handle_adx, handle_atr;

//--- Indicator Buffers
double ma_fast_buffer[], ma_slow_buffer[], rsi_buffer[], adx_buffer[], atr_buffer[];

//--- Input Parameters
input ulong  InpMagicNumber  = 12345;        // Magic Number
input ushort InpTakeProfit   = 40;           // TakeProfit for positions (pips)
input ushort InpStopLoss     = 30;           // StopLoss for positions (pips)
input bool   InpUseStopLoss  = true;         // Use stop loss
input bool   InpUseTakeProfit= true;         // Use take profit
input string InpName_Expert  = "OTC_Escape_Learning_V2"; // Expert Name
input ulong  InpSlippage     = 3;            // Slippage (points)
input double InpLots         = 0.02;         // Lot size
input int    InpMAPeriod1    = 5;            // Fast MA Period
input int    InpMAPeriod2    = 10;           // Slow MA Period
input ENUM_MA_METHOD InpMAMethod = MODE_SMA; // MA Method
input ENUM_APPLIED_PRICE InpMAPrice = PRICE_CLOSE; // MA Price

input group "=== Advanced Strategy Settings ==="
input int InpRSI_Period = 14;      // RSI Period
input int InpADX_Period = 14;      // ADX Period
input int InpATR_Period = 14;      // ATR Period
input double InpADX_Threshold = 25.0; // ADX trend strength threshold
input double InpATR_SL_Multiplier = 2.0; // ATR multiplier for Stop Loss
input double InpATR_TP_Multiplier = 1.5; // Reward:Risk Ratio for Take Profit

input group "=== Order Settings ==="
input int    InpMaxOpenTrades = 5;          // Maximum number of open trades

input group "=== Learning Engine Settings ==="
input bool   InpUseLearning = true;         // Enable learning engine
input bool   InpUseAdaptiveLogic = true;    // Enable adaptive SL/TP logic
input int    InpMinTradesForAnalysis = 50;  // Min trades per regime to adapt
input double InpVolatilityThreshold = 0.001; // Volatility threshold for regime change
input double InpTrendThreshold = 20.0;      // Trend strength threshold for regime change

//--- Global Variables for Adaptive Logic
double g_adaptive_sl_pips = 0;
double g_adaptive_tp_pips = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   m_symbol.Name(Symbol());
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetTypeFilling(ORDER_FILLING_FOK);

   handle_ma_fast = iMA(Symbol(), Period(), InpMAPeriod1, 0, InpMAMethod, InpMAPrice);
   handle_ma_slow = iMA(Symbol(), Period(), InpMAPeriod2, 0, InpMAMethod, InpMAPrice);
   handle_rsi = iRSI(Symbol(), Period(), InpRSI_Period, InpMAPrice);
   handle_adx = iADX(Symbol(), Period(), InpADX_Period);
   handle_atr = iATR(Symbol(), Period(), InpATR_Period);

   if(handle_ma_fast == INVALID_HANDLE || handle_ma_slow == INVALID_HANDLE || handle_rsi == INVALID_HANDLE || handle_adx == INVALID_HANDLE || handle_atr == INVALID_HANDLE)
   {
      Print("Error creating indicators");
      return(INIT_FAILED);
   }



   if(InpUseLearning)
   {
      learning_engine = new CLearningEngine(InpVolatilityThreshold, InpTrendThreshold);
      if(CheckPointer(learning_engine) == POINTER_INVALID)
      {
         learning_engine = new CLearningEngine();
         if(CheckPointer(learning_engine) == POINTER_INVALID)
         {
            ExpertRemove();
            return(INIT_FAILED);
         }
      }
      learning_engine->Init(Symbol(), Period());
      learning_engine->SetMinTradesForAnalysis(InpMinTradesForAnalysis);
   }

   Print("OTC Escape EA V2 initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(handle_ma_fast);
   IndicatorRelease(handle_ma_slow);
   IndicatorRelease(handle_rsi);
   IndicatorRelease(handle_adx);
   IndicatorRelease(handle_atr);

   if(CheckPointer(learning_engine) == POINTER_DYNAMIC)
   {
      delete learning_engine;
   }
   Print("OTC Escape EA V2 deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   m_symbol.RefreshRates();
   static datetime last_bar = 0;
   datetime current_bar = (datetime)SeriesInfoInteger(Symbol(), Period(), SERIES_LASTBAR_DATE);
   if(last_bar == current_bar) return;
   last_bar = current_bar;

   //--- Copy indicator data
   ArraySetAsSeries(ma_fast_buffer, true);
   ArraySetAsSeries(ma_slow_buffer, true);
   ArraySetAsSeries(rsi_buffer, true);
   ArraySetAsSeries(adx_buffer, true);
   ArraySetAsSeries(atr_buffer, true);

   if(CopyBuffer(handle_ma_fast, 0, 0, 2, ma_fast_buffer) < 2 ||
      CopyBuffer(handle_ma_slow, 0, 0, 2, ma_slow_buffer) < 2 ||
      CopyBuffer(handle_rsi, 0, 0, 2, rsi_buffer) < 2 ||
      CopyBuffer(handle_adx, 0, 0, 2, adx_buffer) < 2 ||
      CopyBuffer(handle_atr, 0, 0, 2, atr_buffer) < 2)
   {
      Print("Error copying indicator buffers in OnTick");
      return;
   }

   if(InpUseAdaptiveLogic)
   {
      AdaptParameters();
   }

   CheckForOpen();
}

//+------------------------------------------------------------------+
//| Check for new trade signals                                      |
//+------------------------------------------------------------------+
void CheckForOpen()
{
   if(m_position.Select(Symbol()))
   {
      return; // Position already exists
   }

   bool buy_signal = ma_fast_buffer[1] > ma_slow_buffer[1] && adx_buffer[1] > InpADX_Threshold;
   bool sell_signal = ma_fast_buffer[1] < ma_slow_buffer[1] && adx_buffer[1] > InpADX_Threshold;

   // Determine SL and TP in pips
   double sl_pips, tp_pips;
   if(InpUseAdaptiveLogic && g_adaptive_sl_pips > 0)
   {
      sl_pips = g_adaptive_sl_pips;
      tp_pips = g_adaptive_tp_pips;
   }
   else
   {
      double atr_value = atr_buffer[1];
      if(atr_value <= 0) return; // Cannot set SL/TP without ATR
      sl_pips = atr_value / _Point * InpATR_SL_Multiplier;
      tp_pips = sl_pips * InpATR_TP_Multiplier;
   }

   if(buy_signal)
   {
      OpenTrade(ORDER_TYPE_BUY, InpLots, sl_pips, tp_pips);
   }
   
   if(sell_signal)
   {
      OpenTrade(ORDER_TYPE_SELL, InpLots, sl_pips, tp_pips);
   }
}

//+------------------------------------------------------------------+
//| Open a new trade                                                 |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE OrderType, double LotSize, double sl_pips, double tp_pips)
{
   double price = (OrderType == ORDER_TYPE_BUY) ? m_symbol.Ask() : m_symbol.Bid();
   
   // Calculate SL/TP prices from pips
   double sl_price = (sl_pips > 0) ? ((OrderType == ORDER_TYPE_BUY) ? price - sl_pips * _Point : price + sl_pips * _Point) : 0;
   double tp_price = (tp_pips > 0) ? ((OrderType == ORDER_TYPE_BUY) ? price + tp_pips * _Point : price - tp_pips * _Point) : 0;

   //--- High-Precision Diagnostic Log
   string log_message = StringFormat("Attempting PositionOpen: symbol=%s, type=%s, lot=%.2f, entry=%.5f, sl=%.5f, tp=%.5f",
                                     _Symbol, (OrderType == ORDER_TYPE_BUY ? "BUY" : "SELL"), LotSize, price, sl_price, tp_price);
   Print(log_message);

   // Corrected call using PositionOpen
   if(!m_trade.PositionOpen(_Symbol, OrderType, LotSize, price, sl_price, tp_price, "EA V2 Trade"))
   {
      PrintFormat("PositionOpen failed: %d - %s", m_trade.ResultRetcode(), m_trade.ResultComment());
   }
   else
   {
      Print("Position opened successfully");
      if(InpUseLearning && CheckPointer(learning_engine) == POINTER_DYNAMIC)
      {
         STradeRecord *trade_record = new STradeRecord();
         if(CheckPointer(trade_record) != POINTER_INVALID)
         {
            trade_record->trade_type = OrderType;
            trade_record->entry_time = TimeCurrent();
            trade_record->entry_price = m_trade.ResultPrice();
            trade_record->lot_size = LotSize;
            trade_record->stop_loss = m_trade.ResultSL();
            trade_record->take_profit = m_trade.ResultTP();
            trade_record->spread = (m_symbol.Ask() - m_symbol.Bid()) / _Point;
            trade_record->volatility = atr_buffer[1];
            trade_record->trend_strength = adx_buffer[1];
            trade_record->market_regime = learning_engine->GetCurrentMarketRegime(trade_record->volatility, trade_record->trend_strength);
            learning_engine->AddTrade(trade_record); 
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Adapt strategy parameters based on learned data                  |
//+------------------------------------------------------------------+
void AdaptParameters()
{
   if(CheckPointer(learning_engine) == POINTER_INVALID) return;

   double current_volatility = atr_buffer[1];
   double current_trend = adx_buffer[1];
   
   SMarketState market_state;
   market_state.Reset();
   market_state.regime = learning_engine->GetCurrentMarketRegime(current_volatility, current_trend);

   if(learning_engine->GetOptimizedParameters(market_state))
   {
      if(market_state.optimal_sl > 0 && market_state.optimal_tp > 0)
      {
         g_adaptive_tp_pips = market_state.optimal_tp;
         g_adaptive_sl_pips = market_state.optimal_sl;
         PrintFormat("AdaptParameters: Parameters updated for regime %s. New TP: %.1f, SL: %.1f", 
                     EnumToString(market_state.regime), g_adaptive_tp_pips, g_adaptive_sl_pips);
      }
   }
   else
   {
      g_adaptive_sl_pips = 0;
      g_adaptive_tp_pips = 0;
   }
}

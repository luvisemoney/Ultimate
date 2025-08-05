//+------------------------------------------------------------------+
//|                             OTC Escape EA                        |
//|                        Optimized for OTC Markets                 |
//|                                    Based on escape.mq5 template  |
//+------------------------------------------------------------------+
#property version   "1.000"
#property strict

//--- Include files
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>  
#include <Trade\AccountInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Global Objects
CPositionInfo  m_position;                   // trade position object
CTrade         m_trade;                      // trading object
CSymbolInfo    m_symbol;                     // symbol info object
CAccountInfo   m_account;                    // account info wrapper
CDealInfo      m_deal;                       // deals object
COrderInfo     m_order;                      // pending orders object

//--- Input Parameters (Optimized for OTC Markets)
input ushort InpTakeProfit_l = 40;           // TakeProfit for long positions (points)
input ushort InpTakeProfit_s = 40;           // TakeProfit for short positions (points)
input ushort InpStopLoss_l   = 30;           // StopLoss for long positions (points)
input ushort InpStopLoss_s   = 30;           // StopLoss for short positions (points)
input string InpName_Expert  = "OTC_Escape"; // Expert Name
input ulong  InpSlippage     = 3;            // Slippage (points)
input bool   UseSound        = false;        // Enable sounds
input string NameFileSound   = "Alert.wav";  // Sound file
input double InpLots         = 0.1;          // Lot size
input int    InpMAPeriod1    = 5;            // Fast MA Period
input int    InpMAPeriod2    = 10;           // Slow MA Period
input ENUM_MA_METHOD InpMAMethod = MODE_SMA; // MA Method
input ENUM_APPLIED_PRICE InpMAPrice = PRICE_CLOSE; // MA Price
input int    InpMaxSpread   = 30;            // Maximum allowed spread (points)
input bool   InpUseTimeFilter = true;        // Use time filter
input int    InpStartHour    = 1;            // Start trading hour (broker time)
input int    InpEndHour      = 22;           // End trading hour (broker time)

//--- Global Variables
ulong        m_magic = 987569;               // Magic number
int          m_digits_adjust = 1;            // Digits adjustment
bool         m_is_otc = true;                // OTC market flag

//--- Indicator Handles
int          handle_ma_fast;                 // Handle for fast MA
int          handle_ma_slow;                 // Handle for slow MA

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize symbol and trading objects
   m_symbol.Name(Symbol());
   m_trade.SetExpertMagicNumber(m_magic);
   m_trade.SetDeviationInPoints(InpSlippage);
   m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   //--- Check if symbol is valid for OTC trading
   if(!IsOTCSymbol())
   {
      Print("Warning: This EA is optimized for OTC symbols. Current symbol: ", Symbol());
      m_is_otc = false;
   }
   
   //--- Initialize indicator handles
   handle_ma_fast = iMA(Symbol(), Period(), InpMAPeriod1, 0, InpMAMethod, InpMAPrice);
   handle_ma_slow = iMA(Symbol(), Period(), InpMAPeriod2, 0, InpMAMethod, InpMAPrice);
   
   //--- Check if indicator handles are valid
   if(handle_ma_fast == INVALID_HANDLE || handle_ma_slow == INVALID_HANDLE)
   {
      Print("Error creating indicator handles");
      return(INIT_FAILED);
   }
   
   //--- Adjust for 3/5 digit brokers
   m_digits_adjust = (m_symbol.Digits() == 3 || m_symbol.Digits() == 5) ? 10 : 1;
   
   //--- Check if we have enough bars
   if(Bars(Symbol(), Period()) < 100)
   {
      Print("Not enough bars");
      return(INIT_FAILED);
   }
   
   //--- All initialization successful
   Print("OTC Escape EA initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicator handles
   if(handle_ma_fast != INVALID_HANDLE)
      IndicatorRelease(handle_ma_fast);
   if(handle_ma_slow != INVALID_HANDLE)
      IndicatorRelease(handle_ma_slow);
      
   Comment("");
   Print("EA deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check for new bar
   static datetime last_bar = 0;
   datetime current_bar = (datetime)SeriesInfoInteger(Symbol(), Period(), SERIES_LASTBAR_DATE);
   if(last_bar == current_bar)
      return;
   last_bar = current_bar;
   
   //--- Check if we can trade
   if(!CanTrade())
      return;
   
   //--- Check for open positions
   if(PositionsTotal() > 0)
   {
      CheckForClose();
      return;
   }
   
   //--- Check for new trading signals
   CheckForOpen();
}

//+------------------------------------------------------------------+
//| Check if we can trade                                            |
//+------------------------------------------------------------------+
bool CanTrade()
{
   //--- Check if market is open
   if(m_is_otc)
   {
      // OTC markets might have different trading hours
      if(InpUseTimeFilter)
      {
         datetime time = TimeCurrent();
         MqlDateTime tm;
         TimeToStruct(time, tm);
         
         if(tm.hour < InpStartHour || tm.hour >= InpEndHour)
            return false;
      }
   }
   
   //--- Check spread
   double spread = m_symbol.Ask() - m_symbol.Bid();
   if(spread > m_symbol.Point() * InpMaxSpread)
   {
      Print("Spread too high: ", spread / m_symbol.Point(), " points");
      return false;
   }
   
   //--- Check if we have enough money
   if(m_account.FreeMargin() < (1000 * InpLots))
   {
      Print("Not enough free margin. Free Margin = ", m_account.FreeMargin());
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check for open positions                                         |
//+------------------------------------------------------------------+
void CheckForOpen()
{
   //--- Get indicator values
   double ma_fast[2], ma_slow[2];
   if(CopyBuffer(handle_ma_fast, 0, 0, 2, ma_fast) <= 0 ||
      CopyBuffer(handle_ma_slow, 0, 0, 2, ma_slow) <= 0)
   {
      Print("Error copying indicator buffers");
      return;
   }
   
   //--- Check for buy signal (fast MA crosses above slow MA)
   if(ma_fast[1] <= ma_slow[1] && ma_fast[0] > ma_slow[0])
   {
      OpenBuy();
      return;
   }
   
   //--- Check for sell signal (fast MA crosses below slow MA)
   if(ma_fast[1] >= ma_slow[1] && ma_fast[0] < ma_slow[0])
   {
      OpenSell();
      return;
   }
}

//+------------------------------------------------------------------+
//| Check for close positions                                        |
//+------------------------------------------------------------------+
void CheckForClose()
{
   // Check if we have an open position on the current symbol
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == Symbol() && m_position.Magic() == m_magic)
         {
            // Check if we need to close the position based on some condition
            // This is a simple example - you might want to add more sophisticated logic
            if(m_position.PositionType() == POSITION_TYPE_BUY)
            {
               if(m_position.Profit() > 0 && 
                  m_symbol.Bid() >= m_position.PriceOpen() + InpTakeProfit_l * m_symbol.Point())
               {
                  m_trade.PositionClose(m_position.Ticket());
               }
               else if(m_symbol.Bid() <= m_position.PriceOpen() - InpStopLoss_l * m_symbol.Point())
               {
                  m_trade.PositionClose(m_position.Ticket());
               }
            }
            else // POSITION_TYPE_SELL
            {
               if(m_position.Profit() > 0 && 
                  m_symbol.Ask() <= m_position.PriceOpen() - InpTakeProfit_s * m_symbol.Point())
               {
                  m_trade.PositionClose(m_position.Ticket());
               }
               else if(m_symbol.Ask() >= m_position.PriceOpen() + InpStopLoss_s * m_symbol.Point())
               {
                  m_trade.PositionClose(m_position.Ticket());
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Open Buy position                                                |
//+------------------------------------------------------------------+
void OpenBuy()
{
   if(!RefreshRates())
   {
      Print("Error refreshing rates");
      return;
   }
   
   double sl = (InpStopLoss_l > 0) ? m_symbol.Ask() - InpStopLoss_l * m_symbol.Point() : 0.0;
   double tp = (InpTakeProfit_l > 0) ? m_symbol.Ask() + InpTakeProfit_l * m_symbol.Point() : 0.0;
   
   m_trade.Buy(InpLots, m_symbol.Name(), m_symbol.Ask(), sl, tp, "OTC_Escape_Buy");
   
   if(UseSound)
      PlaySound(NameFileSound);
}

//+------------------------------------------------------------------+
//| Open Sell position                                               |
//+------------------------------------------------------------------+
void OpenSell()
{
   if(!RefreshRates())
   {
      Print("Error refreshing rates");
      return;
   }
   
   double sl = (InpStopLoss_s > 0) ? m_symbol.Bid() + InpStopLoss_s * m_symbol.Point() : 0.0;
   double tp = (InpTakeProfit_s > 0) ? m_symbol.Bid() - InpTakeProfit_s * m_symbol.Point() : 0.0;
   
   m_trade.Sell(InpLots, m_symbol.Name(), m_symbol.Bid(), sl, tp, "OTC_Escape_Sell");
   
   if(UseSound)
      PlaySound(NameFileSound);
}

//+------------------------------------------------------------------+
//| Check if the symbol is an OTC symbol                             |
//+------------------------------------------------------------------+
bool IsOTCSymbol()
{
   // Add your OTC symbol detection logic here
   // This is a simple example - you might want to customize it based on your broker's OTC symbols
   string symbol = Symbol();
   StringToLower(symbol);
   
   // Common OTC symbols might include 'otc' in the name or have specific prefixes/suffixes
   if(StringFind(symbol, "otc") >= 0 || 
      StringFind(symbol, "cfd") >= 0 ||
      StringFind(symbol, "_o") >= 0)
   {
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Refresh rates and check for errors                               |
//+------------------------------------------------------------------+
bool RefreshRates()
{
   if(!m_symbol.RefreshRates())
   {
      Print("Error refreshing symbol data");
      return false;
   }
   
   if(m_symbol.Ask() == 0 || m_symbol.Bid() == 0)
   {
      Print("Invalid price data");
      return false;
   }
   
   return true;
}
//+------------------------------------------------------------------+

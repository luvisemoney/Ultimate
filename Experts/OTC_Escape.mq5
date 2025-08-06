//+------------------------------------------------------------------+
//|                             OTC Escape EA                        |
//|                        Optimized for OTC Markets                 |
//|                                    Based on escape.mq5 template  |
//+------------------------------------------------------------------+
#property version   "1.100"
#property strict

//--- Include files
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>  
#include <Trade\AccountInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Market Analysis Class
class CMarketAnalysis
{
private:
    double m_trend_strength;
    double m_volatility;
    bool   m_trend_aligned;
    int    m_ma_fast_handle;
    int    m_ma_slow_handle;
    
public:
    CMarketAnalysis(int ma_fast_handle, int ma_slow_handle)
    {
        m_ma_fast_handle = ma_fast_handle;
        m_ma_slow_handle = ma_slow_handle;
    }
    
    bool AnalyzeMarketConditions()
    {
        //--- Get MA values for trend analysis
        double ma_fast[3], ma_slow[3];
        if(CopyBuffer(m_ma_fast_handle, 0, 0, 3, ma_fast) <= 0 ||
           CopyBuffer(m_ma_slow_handle, 0, 0, 3, ma_slow) <= 0)
            return false;
            
        //--- Calculate trend strength
        m_trend_strength = MathAbs(ma_fast[0] - ma_slow[0]) / Point();
        
        //--- Calculate volatility
        double atr[1];
        int atr_handle = iATR(_Symbol, PERIOD_CURRENT, 14);
        if(CopyBuffer(atr_handle, 0, 0, 1, atr) > 0)
            m_volatility = atr[0] / Point();
        IndicatorRelease(atr_handle);
        
        //--- Check trend alignment
        m_trend_aligned = (ma_fast[0] > ma_fast[2]) == (ma_slow[0] > ma_slow[2]);
        
        return true;
    }
    
    bool ValidateTradeSetup(ENUM_POSITION_TYPE type)
    {
        if(!AnalyzeMarketConditions())
            return false;
            
        //--- Minimum trend strength required
        if(m_trend_strength < 10)
        {
            Print("Insufficient trend strength: ", m_trend_strength);
            return false;
        }
            
        //--- Check if volatility is within acceptable range
        if(m_volatility < 5 || m_volatility > 50)
        {
            Print("Volatility outside acceptable range: ", m_volatility);
            return false;
        }
            
        //--- Ensure trend alignment
        if(!m_trend_aligned)
        {
            Print("Trend misalignment detected");
            return false;
        }
            
        return true;
    }
};

//--- Global Objects
CPositionInfo  m_position;                   // trade position object
CTrade         m_trade;                      // trading object
CSymbolInfo    m_symbol;                     // symbol info object
CAccountInfo   m_account;                    // account info wrapper
CDealInfo      m_deal;                       // deals object
COrderInfo     m_order;                      // pending orders object
CMarketAnalysis* market_analysis = NULL;     // market analysis object

//--- Input Parameters (Optimized for OTC Markets)
input ushort InpTakeProfit_l = 40;           // TakeProfit for long positions (points)
input ushort InpTakeProfit_s = 40;           // TakeProfit for short positions (points)
input ushort InpStopLoss_l   = 30;           // StopLoss for long positions (points)
input ushort InpStopLoss_s   = 30;           // StopLoss for short positions (points)
input string InpName_Expert  = "OTC_Escape"; // Expert Name
input ulong  InpSlippage     = 3;            // Slippage (points)
input bool   UseSound        = false;        // Enable sounds
input string NameFileSound   = "Alert.wav";  // Sound file
input double InpLots         = 0.02;         // Lot size
input int    InpMAPeriod1    = 5;           // Fast MA Period
input int    InpMAPeriod2    = 10;          // Slow MA Period
input ENUM_MA_METHOD InpMAMethod = MODE_SMA; // MA Method
input ENUM_APPLIED_PRICE InpMAPrice = PRICE_CLOSE; // MA Price
input int    InpMaxSpread   = 65;           // Maximum allowed spread (points)
input bool   InpUseTimeFilter = true;       // Use time filter
input int    InpStartHour    = 1;           // Start trading hour (broker time)
input int    InpEndHour      = 22;          // End trading hour (broker time)
input double InpRiskPercent  = 2.0;         // Risk per trade (%)

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
   
   //--- Initialize market analysis
   market_analysis = new CMarketAnalysis(handle_ma_fast, handle_ma_slow);
   if(market_analysis == NULL)
   {
      Print("Failed to create market analysis object");
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
   if(market_analysis != NULL)
   {
      delete market_analysis;
      market_analysis = NULL;
   }
   
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
   if(!RefreshRates())
      return;
      
   //--- Calculate risk-based position size
   double account_risk = AccountInfoDouble(ACCOUNT_BALANCE) * (InpRiskPercent / 100.0);
   double point_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double risk_based_lots = NormalizeDouble(account_risk / (InpStopLoss_l * point_value), 2);
   double final_lots = MathMin(risk_based_lots, InpLots);
   
   //--- Get indicator values
   double ma_fast[2], ma_slow[2];
   if(CopyBuffer(handle_ma_fast, 0, 0, 2, ma_fast) <= 0 ||
      CopyBuffer(handle_ma_slow, 0, 0, 2, ma_slow) <= 0)
   {
      Print("Error copying indicator buffers");
      return;
   }
   
   //--- Check for buy signal
   if(ma_fast[1] <= ma_slow[1] && ma_fast[0] > ma_slow[0])
   {
      OpenBuy(final_lots);
      return;
   }
   
   //--- Check for sell signal
   if(ma_fast[1] >= ma_slow[1] && ma_fast[0] < ma_slow[0])
   {
      OpenSell(final_lots);
      return;
   }
}

//+------------------------------------------------------------------+
//| Check for close positions                                        |
//+------------------------------------------------------------------+
void CheckForClose()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == Symbol() && m_position.Magic() == m_magic)
         {
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
            else
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
void OpenBuy(double lots)
{
   if(!market_analysis.ValidateTradeSetup(POSITION_TYPE_BUY))
   {
      Print("Buy setup validation failed");
      return;
   }
   
   if(!RefreshRates())
   {
      Print("Error refreshing rates");
      return;
   }
   
   double sl = (InpStopLoss_l > 0) ? m_symbol.Ask() - InpStopLoss_l * m_symbol.Point() : 0.0;
   double tp = (InpTakeProfit_l > 0) ? m_symbol.Ask() + InpTakeProfit_l * m_symbol.Point() : 0.0;
   
   m_trade.Buy(lots, m_symbol.Name(), m_symbol.Ask(), sl, tp, "OTC_Escape_Buy");
   
   if(UseSound)
      PlaySound(NameFileSound);
}

//+------------------------------------------------------------------+
//| Open Sell position                                               |
//+------------------------------------------------------------------+
void OpenSell(double lots)
{
   if(!market_analysis.ValidateTradeSetup(POSITION_TYPE_SELL))
   {
      Print("Sell setup validation failed");
      return;
   }
   
   if(!RefreshRates())
   {
      Print("Error refreshing rates");
      return;
   }
   
   double sl = (InpStopLoss_s > 0) ? m_symbol.Bid() + InpStopLoss_s * m_symbol.Point() : 0.0;
   double tp = (InpTakeProfit_s > 0) ? m_symbol.Bid() - InpTakeProfit_s * m_symbol.Point() : 0.0;
   
   m_trade.Sell(lots, m_symbol.Name(), m_symbol.Bid(), sl, tp, "OTC_Escape_Sell");
   
   if(UseSound)
      PlaySound(NameFileSound);
}

//+------------------------------------------------------------------+
//| Check if the symbol is an OTC symbol                             |
//+------------------------------------------------------------------+
bool IsOTCSymbol()
{
   string symbol = Symbol();
   StringToLower(symbol);
   
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

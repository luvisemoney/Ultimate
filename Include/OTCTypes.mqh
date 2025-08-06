//+------------------------------------------------------------------+
//|                                              OTCTypes.mqh          |
//|                        Copyright 2025, OTC Escape EA              |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, OTC Escape EA"
#property link      "https://www.yoursite.com"
#property version   "1.00"
#property strict

// Include necessary standard libraries
#include <Object.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Enumeration for trend states                                     |
//+------------------------------------------------------------------+
enum ENUM_MA_TREND_STATE
{
   MA_TREND_NEUTRAL = 0,  // Neutral/undefined trend
   MA_TREND_UP,           // Uptrend
   MA_TREND_DOWN,         // Downtrend
   MA_TREND_SIDEWAYS      // Sideways market
};

// Forward declarations
class CMarketAnalysis;
class CLearningEngine;

//+------------------------------------------------------------------+
//| Trade Record Structure                                           |
//+------------------------------------------------------------------+
class STradeRecord : public CObject
{
public:
   datetime   entry_time;         // Time of trade entry
   datetime   exit_time;          // Time of trade exit
   double     entry_price;        // Entry price
   double     exit_price;         // Exit price
   double     profit;             // Profit/loss in account currency
   double     lot_size;           // Position size in lots
   int        hold_time;          // Time in seconds the trade was held
   double     spread;             // Spread at entry
   double     volatility;         // Market volatility at entry
   double     trend_strength;     // Trend strength at entry
   bool       is_winner;          // Whether the trade was profitable
   
   //--- Default constructor
   STradeRecord() : 
      entry_time(0), 
      exit_time(0), 
      entry_price(0.0), 
      exit_price(0.0), 
      profit(0.0), 
      lot_size(0.0), 
      hold_time(0), 
      spread(0.0), 
      volatility(0.0), 
      trend_strength(0.0), 
      is_winner(false) 
   {}
   
   //--- Copy constructor
   STradeRecord(const STradeRecord &other) : 
      entry_time(other.entry_time), 
      exit_time(other.exit_time), 
      entry_price(other.entry_price), 
      exit_price(other.exit_price), 
      profit(other.profit), 
      lot_size(other.lot_size), 
      hold_time(other.hold_time), 
      spread(other.spread), 
      volatility(other.volatility), 
      trend_strength(other.trend_strength), 
      is_winner(other.is_winner) 
   {}
   
   //--- Assignment operator
   STradeRecord* operator=(const STradeRecord &other)
   {
      // Skip self-assignment
      if(&this == &other)
         return &this;
         
      entry_time = other.entry_time;
      exit_time = other.exit_time;
      entry_price = other.entry_price;
      exit_price = other.exit_price;
      profit = other.profit;
      lot_size = other.lot_size;
      hold_time = other.hold_time;
      spread = other.spread;
      volatility = other.volatility;
      trend_strength = other.trend_strength;
      is_winner = other.is_winner;
      
      return &this;
   }
   
   //--- Virtual destructor
   virtual ~STradeRecord() {}
   
   //--- Create a copy of the object
   virtual CObject* Create() const { return new STradeRecord(); }
   
   //--- Compare objects
   virtual int Compare(const CObject* node, const int mode=0) const
   {
      const STradeRecord* other = dynamic_cast<const STradeRecord*>(node);
      if(CheckPointer(other) != POINTER_INVALID)
      {
         if(entry_time > other.entry_time) return 1;
         if(entry_time < other.entry_time) return -1;
         return 0;
      }
      return -1;
   }
   
   //--- Calculate metrics
   void CalculateMetrics()
   {
      is_winner = (profit > 0);
   }
   
   //--- Serialization
   virtual bool Save(int file_handle) const
   {
      if(file_handle == INVALID_HANDLE)
         return false;
         
      FileWriteLong(file_handle, entry_time);
      FileWriteLong(file_handle, exit_time);
      FileWriteDouble(file_handle, entry_price);
      FileWriteDouble(file_handle, exit_price);
      FileWriteDouble(file_handle, profit);
      FileWriteDouble(file_handle, lot_size);
      FileWriteInteger(file_handle, hold_time);
      FileWriteDouble(file_handle, spread);
      FileWriteDouble(file_handle, volatility);
      FileWriteDouble(file_handle, trend_strength);
      FileWriteInteger(file_handle, (int)is_winner);
      
      return true;
   }
   
   //--- Deserialization
   virtual bool Load(const int file_handle) override
   {
      if(file_handle == INVALID_HANDLE)
         return false;
      if(file_handle == INVALID_HANDLE)
         return false;
         
      entry_time = (datetime)FileReadLong(file_handle);
      exit_time = (datetime)FileReadLong(file_handle);
      entry_price = FileReadDouble(file_handle);
      exit_price = FileReadDouble(file_handle);
      profit = FileReadDouble(file_handle);
      lot_size = FileReadDouble(file_handle);
      hold_time = FileReadInteger(file_handle);
      spread = FileReadDouble(file_handle);
      volatility = FileReadDouble(file_handle);
      trend_strength = FileReadDouble(file_handle);
      is_winner = (bool)FileReadInteger(file_handle);
      
      return true;
   }
};

//+------------------------------------------------------------------+
//| Market Analysis Class                                            |
//+------------------------------------------------------------------+
class CMarketAnalysis
{
private:
   int         m_ma_fast_handle;  // Handle for fast MA
   int         m_ma_slow_handle;  // Handle for slow MA
   
public:
   //--- Constructor/Destructor
   CMarketAnalysis(int ma_fast_handle, int ma_slow_handle);
   ~CMarketAnalysis();
   
   //--- Market analysis methods
   ENUM_MA_TREND_STATE GetTrendState() const;
   double GetVolatility(int period = 14, int timeframe = 0) const;
   double GetTrendStrength(int period = 14, int timeframe = 0) const;
   bool ValidateTradeSetup(ENUM_ORDER_TYPE order_type, double entry_price, double sl, double tp) const;
   
   //--- Validate trade setup based on market conditions
   bool ValidateTradeSetup(ENUM_POSITION_TYPE position_type)
   {
      // Get current market conditions
      double trend_strength = GetTrendStrength();
      double volatility = GetVolatility();
      
      // Example validation rules - adjust as needed
      if(position_type == POSITION_TYPE_BUY)
      {
         // Only buy in uptrends or weak downtrends
         return (trend_strength > -10);
      }
      else if(position_type == POSITION_TYPE_SELL)
      {
         // Only sell in downtrends or weak uptrends
         return (trend_strength < 10);
      }
      
      return false;
   }
   
   //--- Get current market volatility (ATR based)
   double GetVolatility(int period=14)
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      
      if(CopyBuffer(m_ma_fast_handle, 0, 0, 2, atr) <= 0)
         return 0.0;
         
      return atr[0];
   }
   
   //--- Get trend strength (ADX based)
   double GetTrendStrength(int adx_period=14)
   {
      int adx_handle = iADX(NULL, 0, adx_period);
      if(adx_handle == INVALID_HANDLE)
         return 0.0;
         
      double adx[];
      double plus_di[], minus_di[];
      ArraySetAsSeries(adx, true);
      ArraySetAsSeries(plus_di, true);
      ArraySetAsSeries(minus_di, true);
      
      if(CopyBuffer(adx_handle, 0, 0, 1, adx) != 1 ||
         CopyBuffer(adx_handle, 1, 0, 1, plus_di) != 1 ||
         CopyBuffer(adx_handle, 2, 0, 1, minus_di) != 1)
      {
         IndicatorRelease(adx_handle);
         return 0.0;
      }
      
      double strength = adx[0];
      double direction = plus_di[0] - minus_di[0];
      
      IndicatorRelease(adx_handle);
      return strength * (direction >= 0 ? 1 : -1);
   }
};

//+------------------------------------------------------------------+

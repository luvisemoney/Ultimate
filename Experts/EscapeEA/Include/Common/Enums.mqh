//+------------------------------------------------------------------+
//| Enums.mqh - Common enumerations for EscapeEA                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

// Trading modes
enum ENUM_TRADING_MODE
{
   MODE_PAPER,    // Paper trading mode
   MODE_LIVE      // Live trading mode
};

// Market conditions
enum ENUM_MARKET_CONDITION
{
   MARKET_NORMAL,      // Normal market conditions
   MARKET_TREND_UP,    // Strong uptrend
   MARKET_TREND_DOWN,  // Strong downtrend
   MARKET_RANGING,     // Sideways market
   MARKET_VOLATILE,    // High volatility
   MARKET_HIGH_SPREAD  // High spread
};

// Trade signals
enum ENUM_TRADE_SIGNAL
{
   SIGNAL_BUY,    // Buy signal
   SIGNAL_SELL,   // Sell signal
   SIGNAL_HOLD    // No signal
};

// Trade types
enum ENUM_TRADE_TYPE
{
   TRADE_TYPE_BUY,      // Buy order
   TRADE_TYPE_SELL,     // Sell order
   TRADE_TYPE_BUY_LIMIT,  // Buy limit pending order
   TRADE_TYPE_SELL_LIMIT // Sell limit pending order
};

// Signal strength
enum ENUM_SIGNAL_STRENGTH
{
   SIGNAL_WEAK = 1,     // Weak signal (20% confidence)
   SIGNAL_MEDIUM = 2,   // Medium signal (50% confidence)
   SIGNAL_STRONG = 3,   // Strong signal (70% confidence)
   SIGNAL_VERY_STRONG = 4 // Very strong signal (90% confidence)
};

// Learning states
enum ENUM_LEARNING_STATE
{
   LEARNING_INACTIVE,   // Learning not active
   LEARNING_ACTIVE,     // Learning in progress
   LEARNING_PAUSED,     // Learning paused
   LEARNING_COMPLETE    // Learning complete
};

// Error codes
enum ENUM_ERROR_CODES
{
   ERR_NO_ERROR = 0,            // No error
   ERR_INVALID_INPUT = 1,       // Invalid input parameters
   ERR_MARKET_CLOSED = 2,       // Market is closed
   ERR_NOT_ENOUGH_MONEY = 3,    // Not enough money
   ERR_TOO_MANY_REQUESTS = 4,   // Too many requests
   ERR_SYSTEM_BUSY = 5,         // System busy
   ERR_SIGNAL_TOO_OLD = 6,      // Signal is too old
   ERR_INSUFFICIENT_DATA = 7    // Not enough data for analysis
};

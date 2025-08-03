//+------------------------------------------------------------------+
//| Constants.mqh - Global constants for EscapeEA                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

// Application information
#define APP_NAME                "EscapeEA"
#define APP_VERSION             "2.0.0"
#define APP_AUTHOR              "EscapeEA Team"
#define APP_LINK                "https://www.escapeea.com"

// Magic numbers
#define PAPER_EA_MAGIC          123456    // Magic number for Paper EA
#define LIVE_EA_MAGIC           654321    // Magic number for Live EA

// Default settings
#define DEFAULT_LEARNING_WINDOW 20        // Default learning window size
#define MIN_TRADES_FOR_EVALUATION 20      // Minimum trades before evaluation
#define MIN_WIN_RATE            0.8       // Minimum win rate to start live trading
#define MAX_OPEN_TRADES         5         // Maximum number of open trades
#define DEFAULT_RISK_PERCENT    1.0       // Default risk per trade (%)
#define MAX_RISK_PERCENT        5.0       // Maximum allowed risk per trade (%)
#define MIN_ACCOUNT_BALANCE     1000.0    // Minimum account balance

// Communication settings
#define SIGNAL_PREFIX          "EscapeEA_" // Prefix for signal names
#define MAX_SIGNAL_AGE         300        // Maximum signal age in seconds
#define SIGNAL_CHECK_INTERVAL  1          // Signal check interval in seconds
#define SIGNAL_PROTOCOL_VERSION 1         // Signal protocol version for compatibility

// File paths
#define LOG_DIRECTORY          "Logs\\EscapeEA\\"
#define KNOWLEDGE_DIRECTORY    "Knowledge\\EscapeEA\\"
#define LOG_FILENAME_PREFIX    "EscapeEA_"
#define LOG_FILE_EXTENSION     ".log"
#define MAX_LOG_FILE_SIZE      10485760   // 10MB max log file size
#define MAX_LOG_FILES          5          // Number of log files to keep

// Indicator settings
#define DEFAULT_FAST_MA_PERIOD 10         // Default fast MA period
#define DEFAULT_SLOW_MA_PERIOD 20         // Default slow MA period
#define DEFAULT_RSI_PERIOD     14         // Default RSI period
#define DEFAULT_ATR_PERIOD     14         // Default ATR period

// Custom error codes (prefixed with ERR_ESCAPE_ to avoid conflicts with MQL5 built-in errors)
#define ERR_ESCAPE_SUCCESS            0          // Operation successful
#define ERR_ESCAPE_INVALID_PARAMETER  -1001      // Invalid parameter
#define ERR_ESCAPE_NOT_ENOUGH_DATA    -1002      // Not enough data
#define ERR_ESCAPE_MARKET_CLOSED      -1003      // Market is closed
#define ERR_ESCAPE_NO_MONEY           -1004      // Not enough money
#define ERR_ESCAPE_TOO_MANY_REQUESTS  -1005      // Too many requests

// Time constants
#define ONE_MINUTE             60         // One minute in seconds
#define ONE_HOUR               3600       // One hour in seconds
#define ONE_DAY                86400      // One day in seconds

// Price levels
#define PRICE_LEVELS           10         // Number of price levels to track

// UI settings
#define CHART_LABEL_PREFIX     "EscapeEA_" // Prefix for chart objects
#define FONT_NAME              "Arial"    // Default font
#define FONT_SIZE              8          // Default font size
#define FONT_COLOR             clrWhite   // Default font color
#define PANEL_BG_COLOR         C'20,20,20'// Panel background color
#define PANEL_BORDER_COLOR     clrGray    // Panel border color
#define BUY_COLOR             clrLime     // Color for buy signals
#define SELL_COLOR            clrRed      // Color for sell signals
#define NEUTRAL_COLOR         clrGray     // Color for neutral signals

// Performance metrics
#define METRICS_UPDATE_INTERVAL 60        // Update metrics every 60 seconds
#define MAX_METRICS_HISTORY     1000      // Maximum number of metrics to store

// Learning parameters
#define DEFAULT_LEARNING_RATE   0.01      // Default learning rate
#define MAX_LEARNING_ITERATIONS 1000      // Maximum learning iterations
#define MIN_CONFIDENCE_THRESHOLD 0.7      // Minimum confidence threshold

// Risk management
#define MAX_DRAWDOWN_PERCENT    20.0      // Maximum allowed drawdown (%)
#define MAX_DAILY_LOSS_PERCENT  5.0       // Maximum daily loss (%)
#define MAX_WEEKLY_LOSS_PERCENT 10.0      // Maximum weekly loss (%)
#define MAX_MONTHLY_LOSS_PERCENT 20.0     // Maximum monthly loss (%)

// Version control
#define VERSION_MAJOR          2          // Major version
#define VERSION_MINOR          0          // Minor version
#define VERSION_BUILD          0          // Build number

// Debugging
#ifdef __MQL5__
   #define DEBUG_MODE          true       // Enable debug mode
   #define DEBUG_LEVEL         1          // Debug level (0-3)
   #define DEBUG_PRINT(level, msg) if(DEBUG_MODE && level <= DEBUG_LEVEL) Print(msg)
#else
   #define DEBUG_MODE          false
   #define DEBUG_LEVEL         0
   #define DEBUG_PRINT(level, msg)
#endif

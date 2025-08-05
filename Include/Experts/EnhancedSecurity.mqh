//+------------------------------------------------------------------+
//|                                          EnhancedSecurity.mqh     |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Trade\AccountInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| Security Enhancement Class                                       |
//+------------------------------------------------------------------+
class CEnhancedSecurity
{
private:
   // Security parameters
   bool              m_enabled;              // Security features enabled
   bool              m_allowLiveTrading;     // Allow live trading
   bool              m_allowModifyOrders;    // Allow order modifications
   bool              m_allowDeleteOrders;    // Allow order deletions
   
   // Rate limiting
   int               m_maxTradesPerMinute;   // Maximum trades per minute
   int               m_maxOrdersPerMinute;   // Maximum orders per minute
   datetime          m_lastTradeTime;        // Time of last trade
   int               m_tradeCount;           // Trade counter for rate limiting
   
   // Authorization
   string            m_allowedAccountNumbers[]; // Allowed account numbers
   
   // Objects
   CAccountInfo     *m_account;              // Pointer to account info
   
   // Private methods
   bool              IsAccountAuthorized();
   bool              CheckRateLimits();
   
public:
                     CEnhancedSecurity();
                    ~CEnhancedSecurity();
                    
   // Initialization
   bool              Initialize(CAccountInfo *account);
   
   // Security checks
   bool              ValidateTradeRequest(double lots, double price, 
                                        double sl, double tp, 
                                        ENUM_ORDER_TYPE type);
   
   // Getters
   bool              IsEnabled() const { return m_enabled; }
   bool              IsLiveTradingAllowed() const { return m_allowLiveTrading; }
   
   // Setters
   void              SetEnabled(bool enabled) { m_enabled = enabled; }
   void              SetLiveTrading(bool allow) { m_allowLiveTrading = allow; }
   
   // Security utilities
   static string     GetAccountFingerprint();
   static bool       IsValidSymbol(const string symbol);
   static bool       IsValidPrice(double price);
   static bool       IsValidLotSize(double lots, const string symbol);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CEnhancedSecurity::CEnhancedSecurity() : m_enabled(true),
                                       m_allowLiveTrading(false),
                                       m_allowModifyOrders(true),
                                       m_allowDeleteOrders(true),
                                       m_maxTradesPerMinute(10),
                                       m_maxOrdersPerMinute(30),
                                       m_lastTradeTime(0),
                                       m_tradeCount(0),
                                       m_account(NULL)
{
   // Initialize allowed accounts array
   ArrayResize(m_allowedAccountNumbers, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CEnhancedSecurity::~CEnhancedSecurity()
{
   m_account = NULL;
}

//+------------------------------------------------------------------+
//| Initialize security module                                       |
//+------------------------------------------------------------------+
bool CEnhancedSecurity::Initialize(CAccountInfo *account)
{
   if(account == NULL)
   {
      Print("Error: Invalid account info in security initialization");
      return false;
   }
   
   m_account = account;
   
   // Add current account to allowed accounts if empty
   if(ArraySize(m_allowedAccountNumbers) == 0)
   {
      ArrayResize(m_allowedAccountNumbers, 1);
      m_allowedAccountNumbers[0] = ""; // Empty means current account is allowed
   }
   
   // Reset rate limiting
   m_lastTradeTime = 0;
   m_tradeCount = 0;
   
   // Check if we're in the strategy tester
   if(MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE) || MQLInfoInteger(MQL_OPTIMIZATION))
   {
      // Allow everything in tester/optimization
      m_allowLiveTrading = true;
      m_allowModifyOrders = true;
      m_allowDeleteOrders = true;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Validate trade request                                           |
//+------------------------------------------------------------------+
bool CEnhancedSecurity::ValidateTradeRequest(double lots, double price, 
                                           double sl, double tp, 
                                           ENUM_ORDER_TYPE type)
{
   if(!m_enabled)
      return true;
      
   // Check account authorization
   if(!IsAccountAuthorized())
   {
      Print("Security: Account not authorized");
      return false;
   }
   
   // Check rate limits
   if(!CheckRateLimits())
   {
      Print("Security: Rate limit exceeded");
      return false;
   }
   
   // Validate price
   if(!IsValidPrice(price))
   {
      Print("Security: Invalid price: ", price);
      return false;
   }
   
   // Validate lot size
   CSymbolInfo symbol;
   symbol.Name(_Symbol);
   if(!IsValidLotSize(lots, symbol.Name()))
   {
      Print("Security: Invalid lot size: ", lots);
      return false;
   }
   
   // Validate stop loss and take profit if provided
   if((sl > 0 && !IsValidPrice(sl)) || (tp > 0 && !IsValidPrice(tp)))
   {
      Print("Security: Invalid stop loss or take profit");
      return false;
   }
   
   // For market orders, check if live trading is allowed
   if((type == ORDER_TYPE_BUY || type == ORDER_TYPE_SELL) && !m_allowLiveTrading)
   {
      Print("Security: Live trading is disabled");
      return false;
   }
   
   // Update trade count for rate limiting
   m_tradeCount++;
   m_lastTradeTime = TimeCurrent();
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if account is authorized                                   |
//+------------------------------------------------------------------+
bool CEnhancedSecurity::IsAccountAuthorized()
{
   if(m_account == NULL)
      return false;
      
   // If no accounts are specified, allow all (for backward compatibility)
   if(ArraySize(m_allowedAccountNumbers) == 0)
      return true;
      
   // Check if current account is in the allowed list
   string currentAccount = IntegerToString(m_account.Login());
   
   for(int i = 0; i < ArraySize(m_allowedAccountNumbers); i++)
   {
      if(m_allowedAccountNumbers[i] == "" || m_allowedAccountNumbers[i] == currentAccount)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check rate limits                                                |
//+------------------------------------------------------------------+
bool CEnhancedSecurity::CheckRateLimits()
{
   // Reset counter if more than a minute has passed
   if(TimeCurrent() - m_lastTradeTime > 60)
   {
      m_tradeCount = 0;
      return true;
   }
   
   // Check if we've exceeded the rate limits
   if(m_tradeCount >= m_maxTradesPerMinute)
      return false;
      
   return true;
}

//+------------------------------------------------------------------+
//| Get account fingerprint                                          |
//+------------------------------------------------------------------+
string CEnhancedSecurity::GetAccountFingerprint()
{
   CAccountInfo account;
   string fingerprint = "";
   
   // Create a fingerprint based on account and machine info
   fingerprint += IntegerToString(account.Login());
   fingerprint += "|" + account.Company();
   fingerprint += "|" + account.Server();
   fingerprint += "|" + TerminalInfoString(TERMINAL_COMMONPATH);
   
   // Hash the fingerprint for security
   uchar hash[];
   StringToCharArray(fingerprint, hash, 0, -1, CP_UTF8);
   
   // Use a simple hash (in a real application, use a proper cryptographic hash)
   uint h = 0;
   for(int i = 0; i < ArraySize(hash); i++)
      h = 31 * h + hash[i];
   
   return StringFormat("%X", h);
}

//+------------------------------------------------------------------+
//| Check if symbol is valid                                         |
//+------------------------------------------------------------------+
bool CEnhancedSecurity::IsValidSymbol(const string symbol)
{
   if(symbol == NULL || StringLen(symbol) == 0)
      return false;
      
   // Check if symbol is selected in MarketWatch
   if(!SymbolSelect(symbol, true))
   {
      Print("Security: Symbol ", symbol, " is not available");
      return false;
   }
   
   // Check if symbol is visible and tradable
   if(!SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED)
   {
      Print("Security: Trading is disabled for symbol ", symbol);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if price is valid                                          |
//+------------------------------------------------------------------+
bool CEnhancedSecurity::IsValidPrice(double price)
{
   // Check for NaN and infinity
   if(!MathIsValidNumber(price))
      return false;
      
   // Check if price is within reasonable bounds
   if(price <= 0 || price > 1000000) // Adjust these values based on your needs
      return false;
      
   return true;
}

//+------------------------------------------------------------------+
//| Check if lot size is valid                                       |
//+------------------------------------------------------------------+
bool CEnhancedSecurity::IsValidLotSize(double lots, const string symbol)
{
   if(lots <= 0)
      return false;
      
   // Get symbol parameters
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   // Check against symbol limits
   if(lots < minLot || lots > maxLot)
      return false;
      
   // Check if lot size is a multiple of lot step
   double remainder = MathMod(lots, lotStep);
   if(remainder > 0.0000001) // Account for floating point precision
      return false;
      
   return true;
}
//+------------------------------------------------------------------+

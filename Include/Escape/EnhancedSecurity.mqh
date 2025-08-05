//+------------------------------------------------------------------+
//|                                              EnhancedSecurity.mqh |
//|                                          Copyright 2025, EscapeEA |
//|                                             https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "2.00"
#property strict

#include <Trade\PositionInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\Trade.mqh>
#include <Arrays\ArrayObj.mqh>
#include "RiskManager.mqh"

//+------------------------------------------------------------------+
//| Security Configuration                                           |
//+------------------------------------------------------------------+
input group "=== Security Settings ==="
input int      InpMaxOrderRate = 10;          // Max orders per minute
input int      InpMaxPositionSize = 100;      // Max position size in lots
input double   InpMaxSlippagePct = 1.0;       // Max allowed slippage %
input bool     InpEnableTamperDetection = true; // Enable tamper detection
input bool     InpEnableRateLimiting = true;   // Enable rate limiting
input int      InpMaxDailyTrades = 50;         // Max trades per day

//+------------------------------------------------------------------+
//| CSecurityManager class                                           |
//+------------------------------------------------------------------+
class CSecurityManager
{
private:
   // Security state
   struct SOrderRate {
      datetime lastOrderTime;
      int      orderCount;
   };
   
   // Members
   int               m_dailyTradeCount;
   datetime          m_lastTradeDay;
   double            m_initialBalance;
   CArrayObj         m_orderHistory;
   
   // Private methods
   bool              IsTampered();
   bool              CheckRateLimit();
   bool              ValidateOrderParams(double volume, double price, double sl, double tp);
   
public:
   // Constructor/Destructor
                     CSecurityManager();
                    ~CSecurityManager();
   
   // Public interface
   bool              Initialize();
   void              Deinitialize();
   bool              ValidateTradeRequest(double volume, double price, double sl, double tp);
   void              LogTrade(const string symbol, double volume, double price, double sl, double tp);
   bool              IsTradingAllowed();
   double            GetMaxAllowedPositionSize();
   double            CalculateMaxSlippage(double price);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSecurityManager::CSecurityManager() : m_dailyTradeCount(0),
                                       m_lastTradeDay(0),
                                       m_initialBalance(0)
{
   m_orderHistory.Clear();
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSecurityManager::~CSecurityManager()
{
   Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize security manager                                      |
//+------------------------------------------------------------------+
bool CSecurityManager::Initialize()
{
   // Reset daily trade count
   m_lastTradeDay = TimeCurrent() / 86400 * 86400; // Start of current day
   m_dailyTradeCount = 0;
   m_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Initialize order history
   m_orderHistory.Clear();
   
   // Check for tampering
   if(InpEnableTamperDetection && IsTampered()) {
      Print("Security Alert: Potential tampering detected!");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Clean up resources                                               |
//+------------------------------------------------------------------+
void CSecurityManager::Deinitialize()
{
   // Clean up order history
   m_orderHistory.Clear();
}

//+------------------------------------------------------------------+
//| Check for code tampering                                         |
//+------------------------------------------------------------------+
bool CSecurityManager::IsTampered()
{
   // Simple checksum verification
   // Note: In a production environment, use cryptographic hashing
   
   // Check account balance for suspicious changes
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(MathAbs(currentBalance - m_initialBalance) / m_initialBalance > 0.5) { // 50% change
      Print("Security Alert: Suspicious account balance change detected!");
      return true;
   }
   
   // Check for modified files (pseudo-code)
   // This is a placeholder - actual implementation would check file hashes
   
   return false;
}

//+------------------------------------------------------------------+
//| Validate trade request against security rules                    |
//+------------------------------------------------------------------+
bool CSecurityManager::ValidateTradeRequest(double volume, double price, double sl, double tp)
{
   // Check if trading is allowed
   if(!IsTradingAllowed()) {
      Print("Security: Trading is not allowed at this time");
      return false;
   }
   
   // Check rate limiting
   if(InpEnableRateLimiting && !CheckRateLimit()) {
      Print("Security: Rate limit exceeded");
      return false;
   }
   
   // Validate order parameters
   if(!ValidateOrderParams(volume, price, sl, tp)) {
      Print("Security: Invalid order parameters");
      return false;
   }
   
   // Check daily trade limit
   datetime currentDay = TimeCurrent() / 86400 * 86400;
   if(currentDay > m_lastTradeDay) {
      m_dailyTradeCount = 0;
      m_lastTradeDay = currentDay;
   }
   
   if(m_dailyTradeCount >= InpMaxDailyTrades) {
      Print("Security: Daily trade limit reached");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if trading is currently allowed                           |
//+------------------------------------------------------------------+
bool CSecurityManager::IsTradingAllowed()
{
   // Check if market is open (example implementation)
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Don't trade on weekends
   if(dt.day_of_week == 0 || dt.day_of_week == 6) {
      return false;
   }
   
   // Example: Only trade during market hours
   int hour = dt.hour;
   if(hour < 1 || hour > 23) { // Example: 01:00 - 23:00
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check order rate limit                                          |
//+------------------------------------------------------------------+
bool CSecurityManager::CheckRateLimit()
{
   static datetime lastOrderTime = 0;
   static int orderCount = 0;
   
   datetime currentTime = TimeCurrent();
   
   // Reset counter if more than a minute has passed
   if(currentTime - lastOrderTime > 60) {
      orderCount = 0;
      lastOrderTime = currentTime;
   }
   
   // Check if rate limit exceeded
   if(orderCount >= InpMaxOrderRate) {
      return false;
   }
   
   orderCount++;
   return true;
}

//+------------------------------------------------------------------+
//| Validate order parameters                                       |
//+------------------------------------------------------------------+
bool CSecurityManager::ValidateOrderParams(double volume, double price, double sl, double tp)
{
   // Check volume
   if(volume <= 0 || volume > GetMaxAllowedPositionSize()) {
      Print("Security: Invalid volume: ", volume);
      return false;
   }
   
   // Check price
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   if(price <= 0 || price < bid * 0.5 || price > ask * 2.0) {
      Print("Security: Invalid price: ", price);
      return false;
   }
   
   // Check stop loss and take profit
   if(sl > 0 && MathAbs(price - sl) > CalculateMaxSlippage(price) * 3) {
      Print("Security: Stop loss too far from price");
      return false;
   }
   
   if(tp > 0 && MathAbs(tp - price) > CalculateMaxSlippage(price) * 5) {
      Print("Security: Take profit too far from price");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Log trade for security auditing                                 |
//+------------------------------------------------------------------+
void CSecurityManager::LogTrade(const string symbol, double volume, double price, double sl, double tp)
{
   // In a real implementation, this would log to a secure, tamper-evident log
   PrintFormat("Security: Trade executed - %s %.2f lots @ %.5f, SL: %.5f, TP: %.5f", 
               symbol, volume, price, sl, tp);
   
   // Update daily trade count
   m_dailyTradeCount++;
}

//+------------------------------------------------------------------+
//| Get maximum allowed position size                                |
//+------------------------------------------------------------------+
double CSecurityManager::GetMaxAllowedPositionSize()
{
   // Calculate based on account balance and risk parameters
   double maxSize = AccountInfoDouble(ACCOUNT_BALANCE) * 0.01; // 1% of balance
   return MathMin(maxSize, InpMaxPositionSize);
}

//+------------------------------------------------------------------+
//| Calculate maximum allowed slippage                               |
//+------------------------------------------------------------------+
double CSecurityManager::CalculateMaxSlippage(double price)
{
   return price * InpMaxSlippagePct / 100.0;
}
//+------------------------------------------------------------------+

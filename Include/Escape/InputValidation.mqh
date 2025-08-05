//+------------------------------------------------------------------+
//|                                              InputValidation.mqh  |
//|                                          Copyright 2025, EscapeEA |
//|                                             https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.10"  // Added string validation and rate limiting
#property strict

#include <Trade\SymbolInfo.mqh>
#include "SecureMemory.mqh"

// Pattern definitions for input validation
#define PATTERN_ALPHANUMERIC "^[a-zA-Z0-9_\\-\\. ]+$"
#define PATTERN_SYMBOL_NAME "^[A-Z0-9]+$"
#define PATTERN_COMMENT "^[a-zA-Z0-9_\\-\\.\\s]+$"

//+------------------------------------------------------------------+
//| Input validation functions                                       |
//+------------------------------------------------------------------+

class CInputValidator {
private:
   CSymbolInfo m_symbol;
   
   // Rate limiting
   struct RateLimit {
      int      count;
      datetime lastReset;
      int      maxRequests;
      int      timeWindow;  // in seconds
   };
   
   RateLimit m_rateLimits[];
   
   // Private constructor for singleton pattern
   CInputValidator() {
      // Initialize rate limits (5 requests per minute by default)
      ArrayResize(m_rateLimits, 1);
      m_rateLimits[0].count = 0;
      m_rateLimits[0].lastReset = TimeCurrent();
      m_rateLimits[0].maxRequests = 5;
      m_rateLimits[0].timeWindow = 60;
   }
   
   // Prevent copying
   CInputValidator(const CInputValidator&);
   void operator=(const CInputValidator&);
   
   // Check rate limiting
   bool CheckRateLimit(int limitIndex = 0) {
      if(limitIndex < 0 || limitIndex >= ArraySize(m_rateLimits)) return false;
      
      datetime currentTime = TimeCurrent();
      if(currentTime - m_rateLimits[limitIndex].lastReset > m_rateLimits[limitIndex].timeWindow) {
         m_rateLimits[limitIndex].count = 0;
         m_rateLimits[limitIndex].lastReset = currentTime;
      }
      
      if(m_rateLimits[limitIndex].count >= m_rateLimits[limitIndex].maxRequests) {
         return false;
      }
      
      m_rateLimits[limitIndex].count++;
      return true;
   }
   
public:
   // Get singleton instance
   static CInputValidator* Instance() {
      static CInputValidator instance;
      return &instance;
   }
   
   //--- Basic validation functions
   bool IsValidLotSize(double lots, const string symbol = "") {
      if(lots <= 0) return false;
      
      if(symbol != "" && !m_symbol.Name(symbol)) {
         Print("Error: Invalid symbol for lot size validation");
         return false;
      }
      
      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      
      // Check against minimum and maximum lot size
      if(lots < minLot || lots > maxLot) {
         PrintFormat("Error: Lot size %.2f is outside valid range [%.2f, %.2f]", lots, minLot, maxLot);
         return false;
      }
      
      // Check if lot size is a multiple of the lot step
      if(MathMod(lots, lotStep) > 0.0001) {
         PrintFormat("Error: Lot size %.2f is not a multiple of step size %.2f", lots, lotStep);
         return false;
      }
      
      return true;
   }
   
   bool IsValidPrice(double price, const string symbol = "") {
      if(price <= 0) return false;
      
      if(symbol != "") {
         double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
         double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
         double spread = ask - bid;
         
         // Allow some buffer for price validation
         if(price < bid - spread * 10 || price > ask + spread * 10) {
            PrintFormat("Warning: Price %.5f is far from current market [%.5f, %.5f]", 
                       price, bid, ask);
            // Don't return false here as it might be a pending order
         }
      }
      
      return true;
   }
   
   bool IsValidStopLoss(double price, double stopLoss, const string symbol = "") {
      if(!IsValidPrice(price, symbol) || !IsValidPrice(stopLoss, symbol)) {
         return false;
      }
      
      if(symbol != "") {
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         double stopLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
         double minStopDistance = stopLevel * 1.5; // Add 50% buffer to minimum stop level
         
         if(MathAbs(price - stopLoss) < minStopDistance) {
            PrintFormat("Error: Stop loss too close to entry price. Min distance: %.5f", minStopDistance);
            return false;
         }
      }
      
      return true;
   }
   
   bool IsValidTakeProfit(double price, double takeProfit, const string symbol = "") {
      if(!IsValidPrice(price, symbol) || !IsValidPrice(takeProfit, symbol)) {
         return false;
      }
      
      if(symbol != "") {
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         double stopLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
         double minTakeProfitDistance = stopLevel * 1.5; // Add 50% buffer
         
         if(MathAbs(price - takeProfit) < minTakeProfitDistance) {
            PrintFormat("Error: Take profit too close to entry price. Min distance: %.5f", minTakeProfitDistance);
            return false;
         }
      }
      
      return true;
   }
   
   bool IsValidMagicNumber(ulong magic) {
      // Magic number should be non-zero and within reasonable range
      if(magic == 0 || magic > 999999999) {
         Print("Error: Invalid magic number");
         return false;
      }
      return true;
   }
   
   bool IsValidSlippage(int slippage) {
      // Slippage should be reasonable (0-100 pips)
      if(slippage < 0 || slippage > 1000) { // 1000 points = 10 pips for 5-digit brokers
         Print("Error: Invalid slippage value");
         return false;
      }
      return true;
   }
   
   bool IsValidRiskPercentage(double riskPercent) {
      // Risk per trade should be between 0.1% and 5%
      if(riskPercent < 0.1 || riskPercent > 5.0) {
         Print("Error: Risk percentage should be between 0.1% and 5.0%");
         return false;
      }
      return true;
   }
   
   bool IsValidLeverage(double leverage) {
      // Leverage should be between 1:1 and 1:500
      if(leverage < 1.0 || leverage > 500.0) {
         Print("Error: Leverage should be between 1 and 500");
         return false;
      }
      return true;
   }
   
   //--- String validation functions
   bool ValidateStringPattern(const string text, const string pattern, const string fieldName = "") {
      if(!CheckRateLimit()) {
         Print("Rate limit exceeded for string validation");
         return false;
      }
      
      int textLen = StringLen(text);
      if(textLen == 0) {
         if(fieldName != "") Print("Error: ", fieldName, " cannot be empty");
         return false;
      }
      
      // Simple pattern matching (MQL5 doesn't have built-in regex)
      if(StringFind(text, "\0") >= 0) {
         if(fieldName != "") Print("Error: ", fieldName, " contains null bytes");
         return false;
      }
      
      // More comprehensive pattern matching can be added here
      return true;
   }
   
   // Validate symbol name (alphanumeric and some special chars)
   bool IsValidSymbolName(const string &symbol) {
      if(!ValidateStringPattern(symbol, PATTERN_SYMBOL_NAME, "Symbol name")) {
         return false;
      }
      
      // Additional symbol-specific validation
      if(StringLen(symbol) < 2 || StringLen(symbol) > 32) {
         Print("Error: Symbol name must be between 2 and 32 characters");
         return false;
      }
      
      return true;
   }
   
   // Validate trade comment
   bool IsValidTradeComment(const string &comment) {
      if(!ValidateStringPattern(comment, PATTERN_COMMENT, "Trade comment")) {
         return false;
      }
      
      // Comment length check
      if(StringLen(comment) > 128) {
         Print("Error: Trade comment is too long (max 128 characters)");
         return false;
      }
      
      return true;
   }
   
   // Validate file path
   bool IsValidFilePath(const string &path) {
      if(!ValidateStringPattern(path, "", "File path")) {
         return false;
      }
      
      // Basic path traversal prevention
      if(StringFind(path, "..\\") >= 0 || StringFind(path, "../") >= 0) {
         Print("Error: Invalid file path - path traversal not allowed");
         return false;
      }
      
      return true;
   }
   
   // Set rate limit for validation functions
   bool SetRateLimit(int maxRequests, int timeWindow, int limitIndex = 0) {
      if(limitIndex < 0) return false;
      
      if(limitIndex >= ArraySize(m_rateLimits)) {
         int oldSize = ArraySize(m_rateLimits);
         if(ArrayResize(m_rateLimits, limitIndex + 1) <= 0) return false;
         
         // Initialize new entries
         for(int i = oldSize; i < ArraySize(m_rateLimits); i++) {
            m_rateLimits[i].count = 0;
            m_rateLimits[i].lastReset = TimeCurrent();
            m_rateLimits[i].maxRequests = 5;  // Default
            m_rateLimits[i].timeWindow = 60;   // Default 1 minute
         }
      }
      
      m_rateLimits[limitIndex].maxRequests = maxRequests;
      m_rateLimits[limitIndex].timeWindow = timeWindow;
      return true;
   }
};

// Global instance
CInputValidator* ExtInputValidator = NULL;

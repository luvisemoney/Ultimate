//+------------------------------------------------------------------+
//| IntegrityChecker.mqh - Data integrity validation for EscapeEA   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include "..\Common\Enums.mqh"
#include "..\Common\Structs.mqh"

// Integrity constants
#define CHECKSUM_SEED 0x12345678
#define MAX_VALIDATION_ERRORS 10

//+------------------------------------------------------------------+
//| Integrity validation result                                      |
//+------------------------------------------------------------------+
struct SIntegrityResult
  {
   bool              isValid;            // Overall validation result
   int               errorCount;         // Number of errors found
   string            errors[];           // Error descriptions
   uint              expectedChecksum;   // Expected checksum
   uint              actualChecksum;     // Actual checksum
   datetime          validationTime;     // Validation timestamp
   
   // Constructor
   SIntegrityResult() : isValid(false), errorCount(0), expectedChecksum(0), 
                       actualChecksum(0), validationTime(0) {}
  };

//+------------------------------------------------------------------+
//| Integrity Checker Class                                         |
//+------------------------------------------------------------------+
class CIntegrityChecker
  {
private:
   uint              m_seed;             // Checksum seed
   int               m_maxErrors;        // Maximum errors to track
   
   // Private methods
   uint              CalculateStringChecksum(const string &data);
   uint              CalculateTradeChecksum(const STradeRecord &trade);
   uint              CalculateSignalChecksum(const STradeSignal &signal);
   void              AddError(SIntegrityResult &result, const string error);
   bool              ValidateTradeRecord(const STradeRecord &trade, SIntegrityResult &result);
   bool              ValidateSignal(const STradeSignal &signal, SIntegrityResult &result);
   
public:
   // Constructor
                     CIntegrityChecker(uint seed = CHECKSUM_SEED, int maxErrors = MAX_VALIDATION_ERRORS);
   
   // Validation methods
   SIntegrityResult  ValidateTradeHistory(const STradeRecord &trades[]);
   SIntegrityResult  ValidateSignalData(const STradeSignal &signals[]);
   SIntegrityResult  ValidateJsonData(const string &jsonData);
   SIntegrityResult  ValidateFileIntegrity(const string &filename);
   
   // Checksum methods
   uint              GenerateChecksum(const string &data);
   bool              VerifyChecksum(const string &data, uint expectedChecksum);
   
   // Utility methods
   string            GetIntegrityReport(const SIntegrityResult &result);
   bool              IsDataCorrupted(const SIntegrityResult &result);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CIntegrityChecker::CIntegrityChecker(uint seed = CHECKSUM_SEED, int maxErrors = MAX_VALIDATION_ERRORS) :
   m_seed(seed),
   m_maxErrors(maxErrors)
  {
   Print("IntegrityChecker initialized with seed: ", m_seed);
  }

//+------------------------------------------------------------------+
//| Calculate checksum for string data                               |
//+------------------------------------------------------------------+
uint CIntegrityChecker::CalculateStringChecksum(const string &data)
  {
   uint checksum = m_seed;
   int length = StringLen(data);
   
   for(int i = 0; i < length; i++)
     {
      ushort ch = StringGetCharacter(data, i);
      checksum = ((checksum << 5) + checksum) + ch; // hash * 33 + c
     }
   
   return checksum;
  }

//+------------------------------------------------------------------+
//| Calculate checksum for trade record                              |
//+------------------------------------------------------------------+
uint CIntegrityChecker::CalculateTradeChecksum(const STradeRecord &trade)
  {
   string tradeData = StringFormat("%I64u|%s|%d|%d|%.5f|%.5f|%.5f|%.5f|%.2f|%.2f|%.2f|%.2f|%d|%d|%d|%.2f|%s",
                                  trade.ticket,
                                  trade.symbol,
                                  (int)trade.openTime,
                                  (int)trade.closeTime,
                                  trade.openPrice,
                                  trade.closePrice,
                                  trade.stopLoss,
                                  trade.takeProfit,
                                  trade.lots,
                                  trade.profit,
                                  trade.swap,
                                  trade.commission,
                                  (int)trade.signal,
                                  (int)trade.type,
                                  trade.isLive ? 1 : 0,
                                  trade.confidence,
                                  trade.comment);
   
   return CalculateStringChecksum(tradeData);
  }

//+------------------------------------------------------------------+
//| Calculate checksum for signal                                    |
//+------------------------------------------------------------------+
uint CIntegrityChecker::CalculateSignalChecksum(const STradeSignal &signal)
  {
   string signalData = StringFormat("%d|%d|%.2f|%s|%d|%d|%.5f|%.5f|%.5f|%.2f|%s",
                                   signal.version,
                                   (int)signal.signal,
                                   signal.confidence,
                                   signal.symbol,
                                   (int)signal.timeframe,
                                   (int)signal.timestamp,
                                   signal.entry,
                                   signal.stopLoss,
                                   signal.takeProfit,
                                   signal.riskReward,
                                   signal.comment);
   
   return CalculateStringChecksum(signalData);
  }

//+------------------------------------------------------------------+
//| Add error to validation result                                   |
//+------------------------------------------------------------------+
void CIntegrityChecker::AddError(SIntegrityResult &result, const string error)
  {
   if(result.errorCount >= m_maxErrors)
      return;
   
   int size = ArraySize(result.errors);
   ArrayResize(result.errors, size + 1);
   result.errors[size] = error;
   result.errorCount++;
   result.isValid = false;
  }

//+------------------------------------------------------------------+
//| Validate individual trade record                                 |
//+------------------------------------------------------------------+
bool CIntegrityChecker::ValidateTradeRecord(const STradeRecord &trade, SIntegrityResult &result)
  {
   bool isValid = true;
   
   // Validate ticket
   if(trade.ticket == 0)
     {
      AddError(result, "Invalid ticket: 0");
      isValid = false;
     }
   
   // Validate symbol
   if(StringLen(trade.symbol) == 0)
     {
      AddError(result, "Empty symbol");
      isValid = false;
     }
   
   // Validate timestamps
   if(trade.openTime <= 0)
     {
      AddError(result, "Invalid open time");
      isValid = false;
     }
   
   if(trade.closeTime > 0 && trade.closeTime < trade.openTime)
     {
      AddError(result, "Close time before open time");
      isValid = false;
     }
   
   // Validate prices
   if(trade.openPrice <= 0)
     {
      AddError(result, "Invalid open price");
      isValid = false;
     }
   
   if(trade.closeTime > 0 && trade.closePrice <= 0)
     {
      AddError(result, "Invalid close price for closed trade");
      isValid = false;
     }
   
   // Validate lots
   if(trade.lots <= 0)
     {
      AddError(result, "Invalid lot size");
      isValid = false;
     }
   
   // Validate confidence
   if(trade.confidence < 0.0 || trade.confidence > 1.0)
     {
      AddError(result, StringFormat("Invalid confidence: %.2f", trade.confidence));
      isValid = false;
     }
   
   return isValid;
  }

//+------------------------------------------------------------------+
//| Validate individual signal                                       |
//+------------------------------------------------------------------+
bool CIntegrityChecker::ValidateSignal(const STradeSignal &signal, SIntegrityResult &result)
  {
   bool isValid = true;
   
   // Validate version
   if(signal.version != SIGNAL_PROTOCOL_VERSION)
     {
      AddError(result, StringFormat("Invalid signal version: %d", signal.version));
      isValid = false;
     }
   
   // Validate signal type
   if(signal.signal == SIGNAL_HOLD)
     {
      AddError(result, "Invalid signal type: HOLD");
      isValid = false;
     }
   
   // Validate confidence
   if(signal.confidence <= 0.0 || signal.confidence > 1.0)
     {
      AddError(result, StringFormat("Invalid signal confidence: %.2f", signal.confidence));
      isValid = false;
     }
   
   // Validate symbol
   if(StringLen(signal.symbol) == 0)
     {
      AddError(result, "Empty signal symbol");
      isValid = false;
     }
   
   // Validate timestamp
   if(signal.timestamp <= 0)
     {
      AddError(result, "Invalid signal timestamp");
      isValid = false;
     }
   
   // Validate prices
   if(signal.entry <= 0)
     {
      AddError(result, "Invalid entry price");
      isValid = false;
     }
   
   // Validate stop loss and take profit relationship
   if(signal.stopLoss > 0 && signal.takeProfit > 0)
     {
      if(signal.signal == SIGNAL_BUY)
        {
         if(signal.stopLoss >= signal.entry || signal.takeProfit <= signal.entry)
           {
            AddError(result, "Invalid SL/TP levels for BUY signal");
            isValid = false;
           }
        }
      else if(signal.signal == SIGNAL_SELL)
        {
         if(signal.stopLoss <= signal.entry || signal.takeProfit >= signal.entry)
           {
            AddError(result, "Invalid SL/TP levels for SELL signal");
            isValid = false;
           }
        }
     }
   
   return isValid;
  }

//+------------------------------------------------------------------+
//| Validate trade history array                                     |
//+------------------------------------------------------------------+
SIntegrityResult CIntegrityChecker::ValidateTradeHistory(const STradeRecord &trades[])
  {
   SIntegrityResult result;
   result.validationTime = TimeCurrent();
   result.isValid = true;
   
   int tradeCount = ArraySize(trades);
   if(tradeCount == 0)
     {
      AddError(result, "Empty trade history");
      return result;
     }
   
   uint cumulativeChecksum = m_seed;
   
   // Validate each trade
   for(int i = 0; i < tradeCount && result.errorCount < m_maxErrors; i++)
     {
      if(!ValidateTradeRecord(trades[i], result))
        {
         AddError(result, StringFormat("Trade %d validation failed", i));
        }
      
      // Update cumulative checksum
      cumulativeChecksum ^= CalculateTradeChecksum(trades[i]);
     }
   
   result.actualChecksum = cumulativeChecksum;
   
   // Additional validation: check for duplicate tickets
   for(int i = 0; i < tradeCount - 1 && result.errorCount < m_maxErrors; i++)
     {
      for(int j = i + 1; j < tradeCount; j++)
        {
         if(trades[i].ticket == trades[j].ticket)
           {
            AddError(result, StringFormat("Duplicate ticket found: %I64u", trades[i].ticket));
            break;
           }
        }
     }
   
   return result;
  }

//+------------------------------------------------------------------+
//| Validate signal data array                                       |
//+------------------------------------------------------------------+
SIntegrityResult CIntegrityChecker::ValidateSignalData(const STradeSignal &signals[])
  {
   SIntegrityResult result;
   result.validationTime = TimeCurrent();
   result.isValid = true;
   
   int signalCount = ArraySize(signals);
   if(signalCount == 0)
     {
      AddError(result, "Empty signal data");
      return result;
     }
   
   uint cumulativeChecksum = m_seed;
   
   // Validate each signal
   for(int i = 0; i < signalCount && result.errorCount < m_maxErrors; i++)
     {
      if(!ValidateSignal(signals[i], result))
        {
         AddError(result, StringFormat("Signal %d validation failed", i));
        }
      
      // Update cumulative checksum
      cumulativeChecksum ^= CalculateSignalChecksum(signals[i]);
     }
   
   result.actualChecksum = cumulativeChecksum;
   
   return result;
  }

//+------------------------------------------------------------------+
//| Validate JSON data structure                                     |
//+------------------------------------------------------------------+
SIntegrityResult CIntegrityChecker::ValidateJsonData(const string &jsonData)
  {
   SIntegrityResult result;
   result.validationTime = TimeCurrent();
   result.isValid = true;
   
   if(StringLen(jsonData) == 0)
     {
      AddError(result, "Empty JSON data");
      return result;
     }
   
   // Basic JSON structure validation
   int openBraces = 0;
   int closeBraces = 0;
   int openBrackets = 0;
   int closeBrackets = 0;
   bool inString = false;
   
   for(int i = 0; i < StringLen(jsonData); i++)
     {
      ushort ch = StringGetCharacter(jsonData, i);
      
      if(ch == '"' && (i == 0 || StringGetCharacter(jsonData, i-1) != '\\'))
         inString = !inString;
      
      if(!inString)
        {
         switch(ch)
           {
            case '{': openBraces++; break;
            case '}': closeBraces++; break;
            case '[': openBrackets++; break;
            case ']': closeBrackets++; break;
           }
        }
     }
   
   if(openBraces != closeBraces)
     {
      AddError(result, StringFormat("Mismatched braces: %d open, %d close", openBraces, closeBraces));
     }
   
   if(openBrackets != closeBrackets)
     {
      AddError(result, StringFormat("Mismatched brackets: %d open, %d close", openBrackets, closeBrackets));
     }
   
   // Calculate checksum
   result.actualChecksum = CalculateStringChecksum(jsonData);
   
   return result;
  }

//+------------------------------------------------------------------+
//| Validate file integrity                                          |
//+------------------------------------------------------------------+
SIntegrityResult CIntegrityChecker::ValidateFileIntegrity(const string &filename)
  {
   SIntegrityResult result;
   result.validationTime = TimeCurrent();
   result.isValid = true;
   
   if(!FileIsExist(filename, FILE_COMMON))
     {
      AddError(result, "File does not exist: " + filename);
      return result;
     }
   
   int handle = FileOpen(filename, FILE_READ|FILE_TXT|FILE_COMMON);
   if(handle == INVALID_HANDLE)
     {
      AddError(result, "Cannot open file: " + filename);
      return result;
     }
   
   // Read entire file
   string fileContent = "";
   while(!FileIsEnding(handle))
      fileContent += FileReadString(handle);
   
   FileClose(handle);
   
   // Validate content
   if(StringLen(fileContent) == 0)
     {
      AddError(result, "File is empty: " + filename);
     }
   
   // Calculate checksum
   result.actualChecksum = CalculateStringChecksum(fileContent);
   
   return result;
  }

//+------------------------------------------------------------------+
//| Generate checksum for data                                       |
//+------------------------------------------------------------------+
uint CIntegrityChecker::GenerateChecksum(const string &data)
  {
   return CalculateStringChecksum(data);
  }

//+------------------------------------------------------------------+
//| Verify checksum matches expected value                           |
//+------------------------------------------------------------------+
bool CIntegrityChecker::VerifyChecksum(const string &data, uint expectedChecksum)
  {
   uint actualChecksum = CalculateStringChecksum(data);
   return actualChecksum == expectedChecksum;
  }

//+------------------------------------------------------------------+
//| Generate integrity report                                        |
//+------------------------------------------------------------------+
string CIntegrityChecker::GetIntegrityReport(const SIntegrityResult &result)
  {
   string report = StringFormat("Integrity Check Report - %s\n", 
                               TimeToString(result.validationTime, TIME_DATE|TIME_SECONDS));
   
   report += StringFormat("Status: %s\n", result.isValid ? "VALID" : "INVALID");
   report += StringFormat("Errors: %d\n", result.errorCount);
   report += StringFormat("Checksum: %u\n", result.actualChecksum);
   
   if(result.errorCount > 0)
     {
      report += "Errors found:\n";
      for(int i = 0; i < ArraySize(result.errors); i++)
         report += StringFormat("  - %s\n", result.errors[i]);
     }
   
   return report;
  }

//+------------------------------------------------------------------+
//| Check if data is corrupted                                       |
//+------------------------------------------------------------------+
bool CIntegrityChecker::IsDataCorrupted(const SIntegrityResult &result)
  {
   return !result.isValid || result.errorCount > 0;
  }
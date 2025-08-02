//+------------------------------------------------------------------+
//| SignalReceiver.mqh - Signal receiving for EscapeEA               |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include "..\Common\Enums.mqh"
#include "..\Common\Structs.mqh"
#include "..\Common\Constants.mqh"
#include "..\Common\StringMap.mqh"

//+------------------------------------------------------------------+
//| Signal Receiver Class                                            |
//+------------------------------------------------------------------+
class CSignalReceiver
  {
private:
   string            m_signalPrefix;      // Prefix for signal names
   int               m_maxSignalAge;      // Maximum signal age in seconds
   
   // Signal cache to avoid processing the same signal multiple times
   CStringMap        m_processedSignals;
   
   // Private methods
   bool              ParseSignal(const string name, string &symbol, ENUM_TRADE_SIGNAL &signal, double &confidence, datetime &timestamp);
   
public:
   // Constructor/destructor
                     CSignalReceiver(string prefix = SIGNAL_PREFIX, int maxAge = MAX_SIGNAL_AGE);
   
   // Signal management
   int               CheckForNewSignals(STradeSignal &signals[]);
   bool              AcknowledgeSignal(const string signalName);
   void              CleanupExpiredSignals();
   
   // Getters
   string            GetSignalPrefix() const { return m_signalPrefix; }
   int               GetMaxSignalAge() const { return m_maxSignalAge; }
   
   // Setters
   void              SetSignalPrefix(const string prefix) { m_signalPrefix = prefix; }
   void              SetMaxSignalAge(int seconds) { m_maxSignalAge = seconds; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSignalReceiver::CSignalReceiver(string prefix = SIGNAL_PREFIX, int maxAge = MAX_SIGNAL_AGE) :
   m_signalPrefix(prefix),
   m_maxSignalAge(maxAge)
  {
   // StringMap is already initialized
  }

//+------------------------------------------------------------------+
//| Parse a signal name and extract its components                   |
//+------------------------------------------------------------------+
bool CSignalReceiver::ParseSignal(const string name, string &symbol, ENUM_TRADE_SIGNAL &signal, double &confidence, datetime &timestamp)
  {
   // Format: PREFIX_SYMBOL_SIGNAL_TIMESTAMP
   string parts[];
   int count = StringSplit(name, '_', parts);
   
   if(count < 4) // At least prefix, symbol, signal, and timestamp
     {
      Print("Invalid signal format: ", name);
      return false;
     }
   
   // Reconstruct symbol (it might contain underscores)
   symbol = "";
   for(int i = 1; i < count - 2; i++)
     {
      if(i > 1) symbol += "_";
      symbol += parts[i];
     }
   
   // Parse signal type
   string signalStr = parts[count-2];
   if(signalStr == "BUY")
      signal = SIGNAL_BUY;
   else if(signalStr == "SELL")
      signal = SIGNAL_SELL;
   else
      signal = SIGNAL_HOLD;
   
   // Parse timestamp (last part)
   timestamp = (datetime)StringToInteger(parts[count-1]);
   
   // Get confidence from the signal data (stored in comment)
   string dataVar = name + "_COMMENT";
   if(GlobalVariableCheck(dataVar))
     {
      // In MQL5, GlobalVariableGet returns a double that we can convert to string
      string data = DoubleToString(GlobalVariableGet(dataVar));
      string dataParts[];
      if(StringSplit(data, '|', dataParts) >= 4)
         confidence = StringToDouble(dataParts[3]);
     }
   else
     {
      confidence = 0.0;
     }
   
   return (signal != SIGNAL_HOLD && timestamp > 0);
  }

//+------------------------------------------------------------------+
//| Check for new signals and return them in the signals array       |
//+------------------------------------------------------------------+
int CSignalReceiver::CheckForNewSignals(STradeSignal &signals[])
  {
   int signalCount = 0;
   datetime now = TimeCurrent();
   
   // Clear the output array
   ArrayFree(signals);
   
   // Get all global variables
   int totalVars = GlobalVariablesTotal();
   
   for(int i = 0; i < totalVars; i++)
     {
      string varName = GlobalVariableName(i);
      
      // Check if this is a signal variable (starts with prefix and doesn't end with _DATA or _EXPIRES)
      if(StringFind(varName, m_signalPrefix) == 0 && 
         StringFind(varName, "_DATA") == -1 && 
         StringFind(varName, "_EXPIRES") == -1 &&
         StringFind(varName, "_COMMENT") == -1)
        {
         // Check if we've already processed this signal
         ulong processed = 0;
         if(m_processedSignals.TryGetValue(varName, processed) && processed > 0)
            continue;
         
         // Check if signal is expired
         string expireVar = varName + "_EXPIRES";
         if(GlobalVariableCheck(expireVar))
           {
            datetime expires = (datetime)GlobalVariableGet(expireVar);
            if(now > expires)
              {
               // Clean up expired signal
               GlobalVariableDel(varName);
               GlobalVariableDel(expireVar);
               GlobalVariableDel(varName + "_DATA");
               GlobalVariableDel(varName + "_COMMENT");
               continue;
              }
           }
         
         // Parse the signal
         string symbol;
         ENUM_TRADE_SIGNAL signal;
         double confidence;
         datetime timestamp;
         
         if(ParseSignal(varName, symbol, signal, confidence, timestamp))
           {
            // Add to results
            int idx = signalCount++;
            ArrayResize(signals, signalCount);
            
            signals[idx].comment = varName;
            signals[idx].symbol = symbol;
            signals[idx].signal = signal;
            signals[idx].confidence = confidence;
            signals[idx].timestamp = timestamp;
            
            // Mark as processed
            m_processedSignals.Add(varName, 1);
           }
        }
     }
   
   return signalCount;
  }

//+------------------------------------------------------------------+
//| Acknowledge a processed signal                                   |
//+------------------------------------------------------------------+
bool CSignalReceiver::AcknowledgeSignal(const string signalName)
  {
   if(GlobalVariableCheck(signalName))
     {
      // Mark as acknowledged by setting the value to 2.0
      GlobalVariableSet(signalName, 2.0);
      
      // Clean up the signal after a short delay
      EventSetTimer(5); // Clean up after 5 seconds
      
      return true;
     }
   
   return false;
  }

//+------------------------------------------------------------------+
//| Clean up expired signals                                         |
//+------------------------------------------------------------------+
void CSignalReceiver::CleanupExpiredSignals()
  {
   datetime now = TimeCurrent();
   
   // Get all global variables
   int totalVars = GlobalVariablesTotal();
   
   for(int i = totalVars - 1; i >= 0; i--)
     {
      string varName = GlobalVariableName(i);
      
      // Check if this is a signal variable (starts with prefix and is _EXPIRES)
      if(StringFind(varName, m_signalPrefix) == 0 && StringFind(varName, "_EXPIRES") > 0)
        {
         datetime expires = (datetime)GlobalVariableGet(varName);
         if(now > expires)
           {
            // Extract base variable name
            string baseVar = StringSubstr(varName, 0, StringLen(varName) - 8); // Remove "_EXPIRES"
            
            // Clean up all related variables
            GlobalVariableDel(baseVar);
            GlobalVariableDel(baseVar + "_DATA");
            GlobalVariableDel(baseVar + "_COMMENT");
            GlobalVariableDel(varName); // The _EXPIRES variable itself
            
            // Remove from processed signals
            m_processedSignals.Remove(baseVar);
            
            Print("Cleaned up expired signal: ", baseVar);
           }
        }
     }
  }

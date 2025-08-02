//+------------------------------------------------------------------+
//| SignalBroadcaster.mqh - Signal broadcasting for EscapeEA         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include "..\Common\Enums.mqh"
#include "..\Common\Structs.mqh"
#include "..\Common\Constants.mqh"

//+------------------------------------------------------------------+
//| Signal Broadcaster Class                                         |
//+------------------------------------------------------------------+
class CSignalBroadcaster
  {
private:
   string            m_signalPrefix;      // Prefix for signal names
   int               m_signalLifetime;    // Signal lifetime in seconds
   
   // Private methods
   string            GenerateSignalName(const string symbol, ENUM_TRADE_SIGNAL signal);
   
public:
   // Constructor/destructor
                     CSignalBroadcaster(string prefix = SIGNAL_PREFIX, int lifetime = MAX_SIGNAL_AGE);
   
   // Signal management
   bool              SendSignal(const string symbol, ENUM_TRADE_SIGNAL signal, double confidence);
   bool              BroadcastStatus(const string status);
   
   // Getters
   string            GetSignalPrefix() const { return m_signalPrefix; }
   int               GetSignalLifetime() const { return m_signalLifetime; }
   
   // Setters
   void              SetSignalPrefix(const string prefix) { m_signalPrefix = prefix; }
   void              SetSignalLifetime(int seconds) { m_signalLifetime = seconds; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSignalBroadcaster::CSignalBroadcaster(string prefix = SIGNAL_PREFIX, int lifetime = MAX_SIGNAL_AGE) :
   m_signalPrefix(prefix),
   m_signalLifetime(lifetime)
  {
  }

//+------------------------------------------------------------------+
//| Generate a unique signal name                                    |
//+------------------------------------------------------------------+
string CSignalBroadcaster::GenerateSignalName(const string symbol, ENUM_TRADE_SIGNAL signal)
  {
   string signalType = (signal == SIGNAL_BUY) ? "BUY" : (signal == SIGNAL_SELL) ? "SELL" : "HOLD";
   return StringFormat("%s%s_%s_%d", m_signalPrefix, symbol, signalType, GetTickCount());
  }

//+------------------------------------------------------------------+
//| Send a trading signal                                            |
//+------------------------------------------------------------------+
bool CSignalBroadcaster::SendSignal(const string symbol, ENUM_TRADE_SIGNAL signal, double confidence)
  {
   // Validate input
   if(signal == SIGNAL_HOLD || confidence <= 0 || confidence > 1.0)
     {
      Print("Invalid signal parameters");
      return false;
     }
   
   // Create signal data
   string signalName = GenerateSignalName(symbol, signal);
   string signalData = StringFormat("%s|%s|%d|%.2f|%d", 
                                   symbol, 
                                   EnumToString(signal), 
                                   (int)TimeCurrent(), 
                                   confidence,
                                   m_signalLifetime);
   
   // Store signal in global variable
   if(!GlobalVariableTemp(signalName))
     {
      if(!GlobalVariableTemp(signalName))
        {
         Print("Failed to create global variable for signal: ", signalName);
         return false;
        }
     }
   
   // Set signal data and expiration
   string dataVar = signalName + "_DATA";
   string expiresVar = signalName + "_EXPIRES";
   string commentVar = signalName + "_COMMENT";
   
   GlobalVariableSet(signalName, 1.0);
   GlobalVariableSet(dataVar, 0.0);
   GlobalVariableSet(expiresVar, (double)(TimeCurrent() + m_signalLifetime));
   
   // Store signal data in the comment field
   // Using StringToDouble to ensure proper type conversion
   GlobalVariableSet(commentVar, StringToDouble(signalData) == 0 ? 0.0 : 1.0);
   
   Print("Signal sent: ", signalName, " (", signalData, ")");
   return true;
  }

//+------------------------------------------------------------------+
//| Broadcast system status                                          |
//+------------------------------------------------------------------+
bool CSignalBroadcaster::BroadcastStatus(const string status)
  {
   string statusVar = m_signalPrefix + "STATUS";
   
   if(!GlobalVariableTemp(statusVar))
     {
      if(!GlobalVariableTemp(statusVar))
        {
         Print("Failed to create status variable");
         return false;
        }
     }
   
   string statusDataVar = statusVar + "_DATA";
   string statusCommentVar = statusVar + "_COMMENT";
   string statusExpiresVar = statusVar + "_EXPIRES";
   
   GlobalVariableSet(statusVar, 1.0);
   GlobalVariableSet(statusDataVar, 0.0);
   // Using StringToDouble to ensure proper type conversion
   GlobalVariableSet(statusCommentVar, StringToDouble(status) == 0 ? 0.0 : 1.0);
   GlobalVariableSet(statusExpiresVar, (double)(TimeCurrent() + m_signalLifetime));
   
   return true;
  }

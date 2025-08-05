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
   
   // Store signal in global variable - use GlobalVariableSet directly
   // This will create the variable if it doesn't exist
   GlobalVariableSet(signalName, confidence);
   
   // Set signal data and expiration
   string dataVar = signalName + "_DATA";
   string expiresVar = signalName + "_EXPIRES";
   
   // Store timestamp as data (we can't store strings in global variables)
   GlobalVariableSet(dataVar, (double)TimeCurrent());
   
   // Set expiration time
   GlobalVariableSet(expiresVar, (double)(TimeCurrent() + m_signalLifetime));
   
   Print("Signal sent: ", signalName, " (", signalData, ")");
   return true;
  }

//+------------------------------------------------------------------+
//| Broadcast system status                                          |
//+------------------------------------------------------------------+
bool CSignalBroadcaster::BroadcastStatus(const string status)
  {
   string statusVar = m_signalPrefix + "STATUS";
   
   // Set status values - GlobalVariableSet will create the variable if it doesn't exist
   GlobalVariableSet(statusVar, 1.0);
   
   string statusDataVar = statusVar + "_DATA";
   string statusExpiresVar = statusVar + "_EXPIRES";
   
   // Store status timestamp
   GlobalVariableSet(statusDataVar, (double)TimeCurrent());
   
   // Set expiration time
   GlobalVariableSet(statusExpiresVar, (double)(TimeCurrent() + m_signalLifetime));
   
   return true;
  }

//+------------------------------------------------------------------+
//| IKnowledgeBase.mqh - Interface for knowledge base operations     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include "..\Common\Structs.mqh"

//+------------------------------------------------------------------+
//| Knowledge Base Interface                                         |
//+------------------------------------------------------------------+
class IKnowledgeBase
  {
public:
   // Initialization and state
   virtual bool      Initialize() = 0;
   virtual bool      IsInitialized() const = 0;
   virtual string    GetLastError() const = 0;
   
   // Trade management
   virtual bool      AddTrade(const STradeRecord &trade) = 0;
   virtual bool      GetRecentTrades(int count, int &trades[], int &size) = 0;
   
   // Signal management
   virtual bool      LogSignalRejection(int signalId, const string reason) = 0;
   
   // Cleanup
   virtual void      Clear() = 0;
   
   // Virtual destructor for proper cleanup
   virtual         ~IKnowledgeBase() {}
  };

//+------------------------------------------------------------------+

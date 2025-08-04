//+------------------------------------------------------------------+
//| MockKnowledgeBase.mqh - Mock implementation of IKnowledgeBase for testing |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include <Object.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Arrays\ArrayInt.mqh>
#include "..\..\Include\Learning\IKnowledgeBase.mqh"

// Include the actual STradeRecord definition
#include "..\..\Include\Common\Structs.mqh"

// Wrapper class for STradeRecord to store in CArrayObj
class CMockTradeRecord : public CObject
  {
public:
   STradeRecord     data;
  };

//+------------------------------------------------------------------+
//| Mock implementation of IKnowledgeBase for testing                |
//+------------------------------------------------------------------+
class CMockKnowledgeBase : public IKnowledgeBase
{
private:
   CArrayObj         *m_trades;
   CArrayInt         *m_rejectedSignals;
   bool               m_forceError;
   bool               m_initialized;
   string             m_lastError;       // Last error message
   
   // In-memory storage for testing
   string            m_filename;        // Knowledge base filename
   string            m_sharedKBDir;     // Shared knowledge base directory
   
public:
   // Constructor/Destructor
   CMockKnowledgeBase(string filename = "test_kb.json", string sharedKBDir = "shared_kb") : 
      m_trades(NULL), 
      m_rejectedSignals(NULL), 
      m_forceError(false), 
      m_initialized(false), 
      m_lastError(""),
      m_filename(filename),
      m_sharedKBDir(sharedKBDir)
   {
      m_trades = new CArrayObj();
      m_rejectedSignals = new CArrayInt();
      m_initialized = true;
   }
                    
                    ~CMockKnowledgeBase()
                      {
                         if(CheckPointer(m_trades) == POINTER_DYNAMIC)
                            delete m_trades;
                         if(CheckPointer(m_rejectedSignals) == POINTER_DYNAMIC)
                            delete m_rejectedSignals;
                      }
   
   // IKnowledgeBase interface implementation
   virtual bool      Initialize() { return !m_forceError && m_initialized; }
   virtual bool      IsInitialized() const { return m_initialized && !m_forceError; }
   virtual string    GetLastError() const { return m_forceError ? m_lastError : ""; }
   
   // Trade management
   virtual bool      AddTrade(const STradeRecord &trade) 
                     { 
                        if(m_forceError) 
                        {
                           m_lastError = "Forced error in AddTrade";
                           return false;
                        }
                        
                        if (m_trades == NULL)
                        {
                           m_lastError = "Trades array not initialized";
                           return false;
                        }
                        
                        CMockTradeRecord *record = new CMockTradeRecord();
                        if(record == NULL) 
                        {
                           m_lastError = "Failed to allocate memory for trade record";
                           return false;
                        }
                        
                        record.data = trade;
                        return m_trades.Add(record) >= 0;
                     }
   
   virtual bool      GetRecentTrades(int count, int &trades[], int &size) 
                     { 
                        if(m_forceError) 
                        {
                           m_lastError = "Forced error in GetRecentTrades";
                           return false;
                        }
                        
                        if (m_trades == NULL)
                        {
                           m_lastError = "Trades array not initialized";
                           return false;
                        }
                        
                        size = MathMin(count, m_trades.Total());
                        if(size <= 0)
                        {
                           ArrayResize(trades, 0);
                           return true;
                        }
                        
                        if(ArrayResize(trades, size) != size)
                        {
                           m_lastError = "Failed to resize trades array";
                           return false;
                        }
                        
                        for(int i = 0; i < size; i++)
                        {
                           CMockTradeRecord *record = (CMockTradeRecord*)m_trades.At(i);
                           if(record != NULL)
                              trades[i] = (int)record.data.ticket;  // Explicit cast to int to prevent data loss warning
                           else
                              trades[i] = -1;
                        }
                        
                        return true;
                     }
   
   // Signal management
   virtual bool      LogSignalRejection(int signalId, const string reason)
                     {
                        if(m_forceError)
                        {
                           m_lastError = "Forced error in LogSignalRejection";
                           return false;
                        }
                        
                        if (m_rejectedSignals == NULL)
                        {
                           m_lastError = "Rejected signals array not initialized";
                           return false;
                        }
                        
                        return m_rejectedSignals.Add(signalId) >= 0;
                     }
   
   // Cleanup
   virtual void      Clear()
                     {
                        if (m_trades != NULL)
                           m_trades.Clear();
                        if (m_rejectedSignals != NULL)
                           m_rejectedSignals.Clear();
                        m_forceError = false;
                        m_lastError = "";
                     }
   
   // Test control methods
   void              SetForceError(bool forceError) { m_forceError = forceError; }
   void              SetLastError(const string error) { m_lastError = error; }
   void              SetInitialized(bool initialized) { m_initialized = initialized; }
   
   // Getters for test verification
   int               GetTradeCount() const { return m_trades != NULL ? m_trades.Total() : 0; }
   int               GetRejectedSignalCount() const { return m_rejectedSignals != NULL ? m_rejectedSignals.Total() : 0; }
   
   // Helper methods for test setup/verification
   bool              AddTestTrade(const STradeRecord &trade) { return AddTrade(trade); }
   bool              AddRejectedSignal(int signalId) { return m_rejectedSignals != NULL ? m_rejectedSignals.Add(signalId) >= 0 : false; }
  };

//+------------------------------------------------------------------+

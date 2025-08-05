//+------------------------------------------------------------------+
//| MockKnowledgeBase.mqh - Mock implementation of CKnowledgeBase for testing |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include <Object.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Arrays\ArrayInt.mqh>
#include "..\..\Include\Common\Structs.mqh"
#include "..\..\Include\Learning\KnowledgeBase.mqh"

// Wrapper class for STradeRecord to store in CArrayObj
class CMockTradeRecord : public CObject
  {
public:
   STradeRecord     data;
  };

// Wrapper class for SSignalMetadata to store in CArrayObj
class CMockSignalRecord : public CObject
  {
public:
   SSignalMetadata  data;
  };

//+------------------------------------------------------------------+
//| Mock implementation of CKnowledgeBase for testing                |
//+------------------------------------------------------------------+
class CMockKnowledgeBase : public CKnowledgeBase
{
private:
   CArrayObj         *m_mockTrades;
   CArrayObj         *m_mockSignals;
   CArrayInt         *m_rejectedSignals;
   bool               m_forceError;
   string             m_lastError;       // Last error message
   
public:
   // Constructor/Destructor
   CMockKnowledgeBase(string filename = "test_kb.json", string sharedKBDir = "test_shared_kb") : 
      CKnowledgeBase(filename, sharedKBDir),
      m_mockTrades(NULL), 
      m_mockSignals(NULL),
      m_rejectedSignals(NULL), 
      m_forceError(false), 
      m_lastError("")
   {
      m_mockTrades = new CArrayObj();
      m_mockSignals = new CArrayObj();
      m_rejectedSignals = new CArrayInt();
   }
                    
                    ~CMockKnowledgeBase()
                      {
                         if(CheckPointer(m_mockTrades) == POINTER_DYNAMIC)
                            delete m_mockTrades;
                         if(CheckPointer(m_mockSignals) == POINTER_DYNAMIC)
                            delete m_mockSignals;
                         if(CheckPointer(m_rejectedSignals) == POINTER_DYNAMIC)
                            delete m_rejectedSignals;
                      }
   
   // Override CKnowledgeBase methods for testing
   virtual bool      AddTrade(const STradeRecord &trade) override
                     { 
                        if(m_forceError) 
                        {
                           m_lastError = "Forced error in AddTrade";
                           return false;
                        }
                        
                        if (m_mockTrades == NULL)
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
                        bool result = m_mockTrades.Add(record) >= 0;
                        
                        // Also call parent method if not forcing error
                        if(result && !m_forceError)
                           CKnowledgeBase::AddTrade(trade);
                           
                        return result;
                     }
   
   virtual bool      GetRecentTrades(int count, STradeRecord &trades[]) override
                     { 
                        if(m_forceError) 
                        {
                           m_lastError = "Forced error in GetRecentTrades";
                           return false;
                        }
                        
                        if (m_mockTrades == NULL)
                        {
                           m_lastError = "Trades array not initialized";
                           return false;
                        }
                        
                        int size = MathMin(count, m_mockTrades.Total());
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
                           CMockTradeRecord *record = (CMockTradeRecord*)m_mockTrades.At(i);
                           if(record != NULL)
                              trades[i] = record.data;
                           else
                           {
                              // Initialize empty trade record
                              STradeRecord emptyTrade;
                              trades[i] = emptyTrade;
                           }
                        }
                        
                        return true;
                     }
   
   virtual bool      SaveSignal(const SSignalMetadata &signal) override
                     {
                        if(m_forceError)
                        {
                           m_lastError = "Forced error in SaveSignal";
                           return false;
                        }
                        
                        if (m_mockSignals == NULL)
                        {
                           m_lastError = "Signals array not initialized";
                           return false;
                        }
                        
                        CMockSignalRecord *record = new CMockSignalRecord();
                        if(record == NULL) 
                        {
                           m_lastError = "Failed to allocate memory for signal record";
                           return false;
                        }
                        
                        record.data = signal;
                        bool result = m_mockSignals.Add(record) >= 0;
                        
                        // Also call parent method if not forcing error
                        if(result && !m_forceError)
                           CKnowledgeBase::SaveSignal(signal);
                           
                        return result;
                     }
   
   virtual bool      GetRecentSignals(int count, SSignalMetadata &signals[]) override
                     {
                        if(m_forceError)
                        {
                           m_lastError = "Forced error in GetRecentSignals";
                           return false;
                        }
                        
                        if (m_mockSignals == NULL)
                        {
                           m_lastError = "Signals array not initialized";
                           return false;
                        }
                        
                        int size = MathMin(count, m_mockSignals.Total());
                        if(size <= 0)
                        {
                           ArrayResize(signals, 0);
                           return true;
                        }
                        
                        if(ArrayResize(signals, size) != size)
                        {
                           m_lastError = "Failed to resize signals array";
                           return false;
                        }
                        
                        for(int i = 0; i < size; i++)
                        {
                           CMockSignalRecord *record = (CMockSignalRecord*)m_mockSignals.At(i);
                           if(record != NULL)
                              signals[i] = record.data;
                           else
                           {
                              // Initialize empty signal record
                              SSignalMetadata emptySignal;
                              signals[i] = emptySignal;
                           }
                        }
                        
                        return true;
                     }
   
   // Signal rejection logging (using the actual method signature from CKnowledgeBase)
   void              LogSignalRejection(const STradeSignal &signal, const string reason)
                     {
                        if(m_forceError)
                        {
                           m_lastError = "Forced error in LogSignalRejection";
                           return;
                        }
                        
                        if (m_rejectedSignals != NULL)
                        {
                           m_rejectedSignals.Add((int)signal.timestamp); // Use timestamp as ID for testing
                        }
                        
                        // Call parent method
                        CKnowledgeBase::LogSignalRejection(signal, reason);
                     }
   
   // Override Clear method
   virtual bool      Clear() override
                     {
                        if (m_mockTrades != NULL)
                           m_mockTrades.Clear();
                        if (m_mockSignals != NULL)
                           m_mockSignals.Clear();
                        if (m_rejectedSignals != NULL)
                           m_rejectedSignals.Clear();
                        m_forceError = false;
                        m_lastError = "";
                        
                        return CKnowledgeBase::Clear();
                     }
   
   // Test control methods
   void              SetForceError(bool forceError) { m_forceError = forceError; }
   void              SetLastError(const string error) { m_lastError = error; }
   string            GetLastError() const { return m_lastError; }
   
   // Getters for test verification
   int               GetTradeCount() const { return m_mockTrades != NULL ? m_mockTrades.Total() : 0; }
   int               GetSignalCount() const { return m_mockSignals != NULL ? m_mockSignals.Total() : 0; }
   int               GetRejectedSignalCount() const { return m_rejectedSignals != NULL ? m_rejectedSignals.Total() : 0; }
   
   // Helper methods for test setup/verification
   bool              AddTestTrade(const STradeRecord &trade) { return AddTrade(trade); }
   bool              AddTestSignal(const SSignalMetadata &signal) { return SaveSignal(signal); }
   bool              AddRejectedSignal(int signalId) { return m_rejectedSignals != NULL ? m_rejectedSignals.Add(signalId) >= 0 : false; }
  };

//+------------------------------------------------------------------+

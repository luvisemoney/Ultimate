//+------------------------------------------------------------------+
//| CSQLiteExplorationCounter.mqh - SQLite-based Atomic Counters     |
//| P1-5: SQLite exploration counters with zero external deps          |
//| Replaces Redis with MT5 native SQLite (Build 2340+)               |
//+------------------------------------------------------------------+
#ifndef CSQLITEEXPLORATIONCOUNTER_MQH
#define CSQLITEEXPLORATIONCOUNTER_MQH

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| SQLite Exploration Counter - Zero External Dependencies           |
//+------------------------------------------------------------------+
class CSQLiteExplorationCounter
{
private:
   int      m_db;
   string   m_dbPath;
   bool     m_initialized;
   
public:
   CSQLiteExplorationCounter() : m_db(INVALID_HANDLE), m_initialized(false)
   {
      m_dbPath = "DualEA" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_explore.db";
   }
   
   ~CSQLiteExplorationCounter()
   {
      Shutdown();
   }
   
   //+------------------------------------------------------------------+
   //| Initialize SQLite database                                        |
   //+------------------------------------------------------------------+
   bool Initialize()
   {
      if(m_initialized) return true;
      
      // Open database (creates if not exists)
      m_db = DatabaseOpen(m_dbPath, DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE | DATABASE_OPEN_COMMON);
      if(m_db == INVALID_HANDLE)
      {
         Print("[CSQLiteExplorationCounter] Failed to open database: ", GetLastError());
         return false;
      }
      
      // Create counters table
      string sql = "CREATE TABLE IF NOT EXISTS exploration_counters ("
                   "key TEXT PRIMARY KEY,"
                   "count INTEGER DEFAULT 0,"
                   "last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,"
                   "symbol TEXT,"
                   "strategy TEXT)";
                   
      if(!DatabaseExecute(m_db, sql))
      {
         Print("[CSQLiteExplorationCounter] Failed to create table: ", GetLastError());
         DatabaseClose(m_db);
         m_db = INVALID_HANDLE;
         return false;
      }
      
      m_initialized = true;
      Print("[CSQLiteExplorationCounter] SQLite initialized: ", m_dbPath);
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Increment counter atomically                                      |
   //+------------------------------------------------------------------+
   bool IncrementCounter(const string key, const string symbol = "", const string strategy = "")
   {
      if(!m_initialized && !Initialize()) return false;
      
      string sql;
      if(symbol != "" && strategy != "")
         sql = StringFormat("INSERT INTO exploration_counters (key, count, symbol, strategy) VALUES ('%s', 1, '%s', '%s') "
                           "ON CONFLICT(key) DO UPDATE SET count = count + 1, last_updated = CURRENT_TIMESTAMP",
                           key, symbol, strategy);
      else
         sql = StringFormat("INSERT INTO exploration_counters (key, count) VALUES ('%s', 1) "
                           "ON CONFLICT(key) DO UPDATE SET count = count + 1, last_updated = CURRENT_TIMESTAMP",
                           key);
                           
      if(!DatabaseExecute(m_db, sql))
      {
         Print("[CSQLiteExplorationCounter] Increment failed: ", GetLastError());
         return false;
      }
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get counter value                                                 |
   //+------------------------------------------------------------------+
   int GetCounter(const string &key)
   {
      if(!m_initialized && !Initialize()) return 0;
      
      string sql = StringFormat("SELECT count FROM exploration_counters WHERE key = '%s'", key);
      int request = DatabasePrepare(m_db, sql);
      
      if(request == INVALID_HANDLE) return 0;
      
      int count = 0;
      if(DatabaseRead(request))
         DatabaseColumnInteger(request, 0, count);
         
      DatabaseFinalize(request);
      return count;
   }
   
   //+------------------------------------------------------------------+
   //| Get all counters for dashboard                                    |
   //+------------------------------------------------------------------+
   void GetAllCounters(string &keys[], int &counts[], string &symbols[], string &strategies[])
   {
      ArrayResize(keys, 0);
      ArrayResize(counts, 0);
      ArrayResize(symbols, 0);
      ArrayResize(strategies, 0);
      
      if(!m_initialized && !Initialize()) return;
      
      string sql = "SELECT key, count, symbol, strategy FROM exploration_counters ORDER BY count DESC";
      int request = DatabasePrepare(m_db, sql);
      
      if(request == INVALID_HANDLE) return;
      
      int idx = 0;
      while(DatabaseRead(request))
      {
         ArrayResize(keys, idx + 1);
         ArrayResize(counts, idx + 1);
         ArrayResize(symbols, idx + 1);
         ArrayResize(strategies, idx + 1);
         
         DatabaseColumnText(request, 0, keys[idx]);
         DatabaseColumnInteger(request, 1, counts[idx]);
         DatabaseColumnText(request, 2, symbols[idx]);
         DatabaseColumnText(request, 3, strategies[idx]);
         
         idx++;
      }
      
      DatabaseFinalize(request);
   }
   
   //+------------------------------------------------------------------+
   //| Reset specific counter                                            |
   //+------------------------------------------------------------------+
   bool ResetCounter(const string &key)
   {
      if(!m_initialized && !Initialize()) return false;
      
      string sql = StringFormat("UPDATE exploration_counters SET count = 0 WHERE key = '%s'", key);
      return DatabaseExecute(m_db, sql);
   }
   
   //+------------------------------------------------------------------+
   //| Shutdown and cleanup                                              |
   //+------------------------------------------------------------------+
   void Shutdown()
   {
      if(m_db != INVALID_HANDLE)
      {
         DatabaseClose(m_db);
         m_db = INVALID_HANDLE;
         m_initialized = false;
         Print("[CSQLiteExplorationCounter] Shutdown complete");
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check if initialized                                              |
   //+------------------------------------------------------------------+
   bool IsInitialized() const { return m_initialized; }
};

//+------------------------------------------------------------------+
//| Global Singleton                                                  |
//+------------------------------------------------------------------+
CSQLiteExplorationCounter* g_sqliteCounter = NULL;

//+------------------------------------------------------------------+
//| Initialize Global Counter                                           |
//+------------------------------------------------------------------+
bool InitializeSQLiteCounter()
{
   if(g_sqliteCounter != NULL) return true;
   
   g_sqliteCounter = new CSQLiteExplorationCounter();
   return g_sqliteCounter.Initialize();
}

//+------------------------------------------------------------------+
//| Shutdown Global Counter                                             |
//+------------------------------------------------------------------+
void ShutdownSQLiteCounter()
{
   if(g_sqliteCounter != NULL)
   {
      g_sqliteCounter.Shutdown();
      delete g_sqliteCounter;
      g_sqliteCounter = NULL;
   }
}

//+------------------------------------------------------------------+
//| Quick increment helper                                              |
//+------------------------------------------------------------------+
bool IncrementExplore(const string key, const string symbol = "", const string strategy = "")
{
   if(g_sqliteCounter == NULL)
   {
      if(!InitializeSQLiteCounter()) return false;
   }
   return g_sqliteCounter.IncrementCounter(key, symbol, strategy);
}

#endif // CSQLITEEXPLORATIONCOUNTER_MQH

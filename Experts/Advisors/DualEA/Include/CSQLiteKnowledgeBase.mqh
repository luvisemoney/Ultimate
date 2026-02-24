//+------------------------------------------------------------------+
//| CSQLiteKnowledgeBase.mqh - ACID-Compliant Database Layer         |
//| P1-1: Native SQLite integration replacing CSV-based KB           |
//| MT5 Build 2340+ native Database*() functions - no DLL needed     |
//+------------------------------------------------------------------+
#ifndef CSQLITEKNOWLEDGEBASE_MQH
#define CSQLITEKNOWLEDGEBASE_MQH

#include <Files/File.mqh>

//+------------------------------------------------------------------+
//| Trade Record Structure                                           |
//+------------------------------------------------------------------+
struct STradeRecord
{
   int      id;
   datetime timestamp;
   string   symbol;
   string   strategy;
   int      order_type;
   double   entry_price;
   double   volume;
   double   sl;
   double   tp;
   double   pnl;
   datetime close_time;
   double   close_price;
   int      duration_minutes;
   bool     is_winner;
   double   r_multiple;
   string   gate_decisions;  // JSON of gate results
   string   market_regime;
};

//+------------------------------------------------------------------+
//| SQLite Knowledge Base Class                                      |
//+------------------------------------------------------------------+
class CSQLiteKnowledgeBase
{
private:
   int      m_db_handle;
   string   m_db_path;
   string   m_db_name;
   bool     m_initialized;
   int      m_query_count;
   datetime m_last_backup;
   
   // Performance tracking
   double   m_avg_query_time_ms;
   int      m_slow_query_count;
   
public:
   // Constructor
   CSQLiteKnowledgeBase(string db_name = "dualea_kb.db")
   {
      m_db_handle = INVALID_HANDLE;
      m_db_name = db_name;
      m_db_path = "DualEA\\Database\\" + db_name;
      m_initialized = false;
      m_query_count = 0;
      m_last_backup = 0;
      m_avg_query_time_ms = 0.0;
      m_slow_query_count = 0;
   }
   
   // Destructor
   ~CSQLiteKnowledgeBase()
   {
      Close();
   }
   
   //+------------------------------------------------------------------+
   //| Initialize database                                              |
   //+------------------------------------------------------------------+
   bool Initialize()
   {
      if(m_initialized) return true;
      
      // Ensure directory exists
      string db_dir = "DualEA\\Database";
      if(!FolderCreate(db_dir, FILE_COMMON))
      {
         // Folder may already exist - that's OK
      }
      
      // Open database connection (FILE_COMMON for shared access)
      m_db_handle = DatabaseOpen(m_db_path, DATABASE_OPEN_COMMON);
      
      if(m_db_handle == INVALID_HANDLE)
      {
         // Try to create new database
         m_db_handle = DatabaseOpen(m_db_path, 
            DATABASE_OPEN_COMMON | DATABASE_OPEN_CREATE | DATABASE_OPEN_READWRITE);
         
         if(m_db_handle == INVALID_HANDLE)
         {
            PrintFormat("[SQLiteKB] ERROR: Failed to open/create database: %s", m_db_path);
            return false;
         }
      }
      
      // Create tables if they don't exist
      if(!CreateTables())
      {
         DatabaseClose(m_db_handle);
         m_db_handle = INVALID_HANDLE;
         return false;
      }
      
      // Create indexes for performance
      if(!CreateIndexes())
      {
         PrintFormat("[SQLiteKB] WARNING: Failed to create indexes");
      }
      
      m_initialized = true;
      PrintFormat("[SQLiteKB] Initialized: %s", m_db_path);
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Create database tables                                           |
   //+------------------------------------------------------------------+
   bool CreateTables()
   {
      // Main trades table
      string sql = "CREATE TABLE IF NOT EXISTS trades ("
         "id INTEGER PRIMARY KEY AUTOINCREMENT,"
         "timestamp DATETIME NOT NULL,"
         "symbol TEXT NOT NULL,"
         "strategy TEXT NOT NULL,"
         "order_type INTEGER NOT NULL,"
         "entry_price REAL NOT NULL,"
         "volume REAL NOT NULL,"
         "sl REAL,"
         "tp REAL,"
         "pnl REAL,"
         "close_time DATETIME,"
         "close_price REAL,"
         "duration_minutes INTEGER,"
         "is_winner INTEGER DEFAULT 0,"
         "r_multiple REAL,"
         "gate_decisions TEXT,"
         "market_regime TEXT,"
         "created_at DATETIME DEFAULT CURRENT_TIMESTAMP"
         ")";
      
      if(!DatabaseExecute(m_db_handle, sql))
      {
         Print("[SQLiteKB] ERROR creating trades table");
         return false;
      }
      
      // Strategy performance stats table
      sql = "CREATE TABLE IF NOT EXISTS strategy_stats ("
         "strategy TEXT PRIMARY KEY,"
         "symbol TEXT,"
         "total_trades INTEGER DEFAULT 0,"
         "win_count INTEGER DEFAULT 0,"
         "loss_count INTEGER DEFAULT 0,"
         "total_pnl REAL DEFAULT 0.0,"
         "avg_pnl REAL DEFAULT 0.0,"
         "profit_factor REAL DEFAULT 0.0,"
         "win_rate REAL DEFAULT 0.0,"
         "max_drawdown REAL DEFAULT 0.0,"
         "expectancy REAL DEFAULT 0.0,"
         "last_updated DATETIME DEFAULT CURRENT_TIMESTAMP"
         ")";
      
      if(!DatabaseExecute(m_db_handle, sql))
      {
         Print("[SQLiteKB] ERROR creating strategy_stats table");
         return false;
      }
      
      // Daily aggregation table
      sql = "CREATE TABLE IF NOT EXISTS daily_stats ("
         "date TEXT PRIMARY KEY,"
         "total_trades INTEGER DEFAULT 0,"
         "win_count INTEGER DEFAULT 0,"
         "loss_count INTEGER DEFAULT 0,"
         "gross_profit REAL DEFAULT 0.0,"
         "gross_loss REAL DEFAULT 0.0,"
         "net_pnl REAL DEFAULT 0.0,"
         "max_consecutive_wins INTEGER DEFAULT 0,"
         "max_consecutive_losses INTEGER DEFAULT 0"
         ")";
      
      if(!DatabaseExecute(m_db_handle, sql))
      {
         Print("[SQLiteKB] ERROR creating daily_stats table");
         return false;
      }
      
      // Gate performance table
      sql = "CREATE TABLE IF NOT EXISTS gate_performance ("
         "gate_name TEXT NOT NULL,"
         "date TEXT NOT NULL,"
         "total_evaluations INTEGER DEFAULT 0,"
         "pass_count INTEGER DEFAULT 0,"
         "fail_count INTEGER DEFAULT 0,"
         "avg_latency_ms REAL DEFAULT 0.0,"
         "PRIMARY KEY(gate_name, date)"
         ")";
      
      if(!DatabaseExecute(m_db_handle, sql))
      {
         Print("[SQLiteKB] ERROR creating gate_performance table");
         return false;
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Create indexes for fast queries                                  |
   //+------------------------------------------------------------------+
   bool CreateIndexes()
   {
      string indexes[] = {
         "CREATE INDEX IF NOT EXISTS idx_trades_symbol ON trades(symbol)",
         "CREATE INDEX IF NOT EXISTS idx_trades_strategy ON trades(strategy)",
         "CREATE INDEX IF NOT EXISTS idx_trades_timestamp ON trades(timestamp)",
         "CREATE INDEX IF NOT EXISTS idx_trades_regime ON trades(market_regime)",
         "CREATE INDEX IF NOT EXISTS idx_trades_is_winner ON trades(is_winner)"
      };
      
      for(int i = 0; i < ArraySize(indexes); i++)
      {
         if(!DatabaseExecute(m_db_handle, indexes[i]))
         {
            PrintFormat("[SQLiteKB] WARNING: Failed to create index: %s", indexes[i]);
         }
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Log a trade execution                                            |
   //+------------------------------------------------------------------+
   bool LogTrade(const STradeRecord &trade)
   {
      if(!m_initialized) return false;
      
      ulong start_time = GetTickCount();
      
      string sql = StringFormat(
         "INSERT INTO trades (timestamp, symbol, strategy, order_type, "
         "entry_price, volume, sl, tp, market_regime) "
         "VALUES (%I64d, '%s', '%s', %d, %.5f, %.2f, %.5f, %.5f, '%s')",
         trade.timestamp,
         trade.symbol,
         trade.strategy,
         trade.order_type,
         trade.entry_price,
         trade.volume,
         trade.sl,
         trade.tp,
         trade.market_regime
      );
      
      bool result = DatabaseExecute(m_db_handle, sql);
      
      if(result)
      {
         // Update query performance metrics
         double query_time = (double)(GetTickCount() - start_time);
         m_query_count++;
         m_avg_query_time_ms = (m_avg_query_time_ms * (m_query_count - 1) + query_time) / m_query_count;
         
         if(query_time > 100.0)  // Slow query threshold
         {
            m_slow_query_count++;
         }
      }
      else
      {
         Print("[SQLiteKB] ERROR logging trade");
      }
      
      return result;
   }
   
   //+------------------------------------------------------------------+
   //| Update trade with close information                                |
   //+------------------------------------------------------------------+
   bool UpdateTradeClose(int trade_id, datetime close_time, double close_price, 
                          double pnl, double r_multiple)
   {
      if(!m_initialized) return false;
      
      int duration = (int)((close_time - 0) / 60);  // Approximate - should store entry time
      bool is_winner = (pnl > 0) ? 1 : 0;
      
      string sql = StringFormat(
         "UPDATE trades SET close_time=%I64d, close_price=%.5f, pnl=%.2f, "
         "r_multiple=%.2f, duration_minutes=%d, is_winner=%d WHERE id=%d",
         close_time, close_price, pnl, r_multiple, duration, is_winner, trade_id
      );
      
      if(!DatabaseExecute(m_db_handle, sql))
      {
         Print("[SQLiteKB] ERROR updating trade close");
         return false;
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get strategy statistics                                          |
   //+------------------------------------------------------------------+
   bool GetStrategyStats(string strategy, string symbol, 
                         double &win_rate, double &profit_factor, 
                         double &total_pnl, int &total_trades)
   {
      if(!m_initialized) return false;
      
      string sql = StringFormat(
         "SELECT win_rate, profit_factor, total_pnl, total_trades "
         "FROM strategy_stats WHERE strategy='%s' AND symbol='%s'",
         strategy, symbol
      );
      
      int request = DatabasePrepare(m_db_handle, sql);
      if(request == INVALID_HANDLE) return false;
      
      if(DatabaseRead(request))
      {
         double col0, col1, col2;
         int col3;
         DatabaseColumnDouble(request, 0, col0);
         DatabaseColumnDouble(request, 1, col1);
         DatabaseColumnDouble(request, 2, col2);
         DatabaseColumnInteger(request, 3, col3);
         win_rate = col0;
         profit_factor = col1;
         total_pnl = col2;
         total_trades = col3;
      }
      else
      {
         // No data found
         win_rate = 0.0;
         profit_factor = 0.0;
         total_pnl = 0.0;
         total_trades = 0;
      }
      
      DatabaseFinalize(request);
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate and update strategy statistics                          |
   //+------------------------------------------------------------------+
   bool RecalculateStrategyStats(string strategy, string symbol)
   {
      if(!m_initialized) return false;
      
      string sql = StringFormat(
         "SELECT COUNT(*), SUM(CASE WHEN is_winner=1 THEN 1 ELSE 0 END), "
         "SUM(CASE WHEN is_winner=0 THEN 1 ELSE 0 END), "
         "SUM(pnl), AVG(pnl), "
         "SUM(CASE WHEN pnl>0 THEN pnl ELSE 0 END), "
         "ABS(SUM(CASE WHEN pnl<0 THEN pnl ELSE 0 END)) "
         "FROM trades WHERE strategy='%s' AND symbol='%s' AND pnl IS NOT NULL",
         strategy, symbol
      );
      
      int request = DatabasePrepare(m_db_handle, sql);
      if(request == INVALID_HANDLE) return false;
      
      if(DatabaseRead(request))
      {
         int col0, col1, col2;
         double col3, col4, col5, col6;
         DatabaseColumnInteger(request, 0, col0);
         DatabaseColumnInteger(request, 1, col1);
         DatabaseColumnInteger(request, 2, col2);
         DatabaseColumnDouble(request, 3, col3);
         DatabaseColumnDouble(request, 4, col4);
         DatabaseColumnDouble(request, 5, col5);
         DatabaseColumnDouble(request, 6, col6);
         int total = col0;
         int wins = col1;
         int losses = col2;
         double sum_pnl = col3;
         double avg_pnl = col4;
         double gross_profit = col5;
         double gross_loss = col6;
         
         double wr = (total > 0) ? (double)wins / total : 0.0;
         double pf = (gross_loss > 0) ? gross_profit / gross_loss : (gross_profit > 0 ? 999.0 : 0.0);
         
         DatabaseFinalize(request);
         
         // Update or insert stats
         sql = StringFormat(
            "INSERT OR REPLACE INTO strategy_stats "
            "(strategy, symbol, total_trades, win_count, loss_count, "
            "total_pnl, avg_pnl, profit_factor, win_rate, last_updated) "
            "VALUES ('%s', '%s', %d, %d, %d, %.2f, %.2f, %.2f, %.4f, CURRENT_TIMESTAMP)",
            strategy, symbol, total, wins, losses, sum_pnl, avg_pnl, pf, wr
         );
         
         return DatabaseExecute(m_db_handle, sql);
      }
      
      DatabaseFinalize(request);
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Get trades for a specific strategy (for insight engine)          |
   //+------------------------------------------------------------------+
   int GetRecentTrades(string strategy, string symbol, STradeRecord &trades[], int max_count = 50)
   {
      if(!m_initialized) return 0;
      
      string sql = StringFormat(
         "SELECT id, timestamp, symbol, strategy, order_type, entry_price, "
         "volume, pnl, is_winner, r_multiple, market_regime "
         "FROM trades WHERE strategy='%s' AND symbol='%s' "
         "ORDER BY timestamp DESC LIMIT %d",
         strategy, symbol, max_count
      );
      
      int request = DatabasePrepare(m_db_handle, sql);
      if(request == INVALID_HANDLE) return 0;
      
      int count = 0;
      while(DatabaseRead(request) && count < max_count)
      {
         ArrayResize(trades, count + 1);
         int col0, col1, col4, col8;
         double col5, col6, col7, col9;
         string col2, col3, col10;
         DatabaseColumnInteger(request, 0, col0);
         DatabaseColumnInteger(request, 1, col1);
         DatabaseColumnText(request, 2, col2);
         DatabaseColumnText(request, 3, col3);
         DatabaseColumnInteger(request, 4, col4);
         DatabaseColumnDouble(request, 5, col5);
         DatabaseColumnDouble(request, 6, col6);
         DatabaseColumnDouble(request, 7, col7);
         DatabaseColumnInteger(request, 8, col8);
         DatabaseColumnDouble(request, 9, col9);
         DatabaseColumnText(request, 10, col10);
         trades[count].id = col0;
         trades[count].timestamp = (datetime)col1;
         trades[count].symbol = col2;
         trades[count].strategy = col3;
         trades[count].order_type = col4;
         trades[count].entry_price = col5;
         trades[count].volume = col6;
         trades[count].pnl = col7;
         trades[count].is_winner = (col8 == 1);
         trades[count].r_multiple = col9;
         trades[count].market_regime = col10;
         count++;
      }
      
      DatabaseFinalize(request);
      return count;
   }
   
   //+------------------------------------------------------------------+
   //| Backup database to file                                          |
   //+------------------------------------------------------------------+
   bool Backup()
   {
      // DatabaseBackup not available in MQL5 - stub
      Print("[SQLiteKB] Backup not supported in MQL5 native SQLite");
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Import from consolidated trades CSV file (one file per symbol)   |
   //| Format: timestamp,strategy,price,volume,type                      |
   //| File naming: {symbol}_trades.csv (e.g., EURUSD_trades.csv)         |
   //+------------------------------------------------------------------+
   int ImportFromTradesCSV(string symbol = "")
   {
      if(!m_initialized) return 0;
      
      string rel_dir = "DualEA\\trades\\";
      string full_dir = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + rel_dir;
      PrintFormat("[SQLiteKB] Checking for consolidated trades CSV files in: %s", full_dir);

      // Ensure directory exists
      FolderCreate("DualEA", FILE_COMMON);
      FolderCreate("DualEA\\trades", FILE_COMMON);

      int total_imported = 0;
      int file_count = 0;
      
      // Use the symbol provided, or default to current chart symbol
      string symbols_to_check[];
      if(symbol != "")
      {
         ArrayResize(symbols_to_check, 1);
         symbols_to_check[0] = symbol;
      }
      else
      {
         // Check current chart symbol only - each EA instance manages its own symbol
         ArrayResize(symbols_to_check, 1);
         symbols_to_check[0] = _Symbol;
      }
      
      // Check for consolidated trade files (one per symbol)
      for(int s = 0; s < ArraySize(symbols_to_check); s++)
      {
         string sym = symbols_to_check[s];
         // New consolidated file format: {symbol}_trades.csv
         string filename = sym + "_trades.csv";
         string rel_path = rel_dir + filename;
         
         // Check if file exists using FILE_COMMON
         if(!FileIsExist(rel_path, FILE_COMMON))
         {
            PrintFormat("[SQLiteKB] No trades file found for %s: %s", sym, filename);
            continue;
         }
         
         file_count++;
         PrintFormat("[SQLiteKB] Found consolidated trades file: %s%s", full_dir, filename);

         // Try reading as ANSI/UTF-8 first (most common), then UTF-16 if needed
         int handle = FileOpen(rel_path, FILE_READ|FILE_COMMON|FILE_TXT|FILE_ANSI);
         bool is_utf16 = false;
         
         if(handle == INVALID_HANDLE)
         {
            // Try UTF-16 if ANSI fails
            handle = FileOpen(rel_path, FILE_READ|FILE_COMMON|FILE_TXT|FILE_UNICODE);
            is_utf16 = true;
         }
         else
         {
            // Check if file starts with UTF-16 BOM (FF FE)
            int bytes_read = FileReadInteger(handle, 2); // Read 2 bytes
            if(bytes_read == 0xFEFF || bytes_read == 0xFFFE)
            {
               // It's UTF-16 with BOM, reopen with UNICODE flag
               FileClose(handle);
               handle = FileOpen(rel_path, FILE_READ|FILE_COMMON|FILE_TXT|FILE_UNICODE);
               is_utf16 = true;
            }
            else
            {
               // Not a BOM, seek back to start
               FileSeek(handle, 0, SEEK_SET);
            }
         }
         
         if(handle == INVALID_HANDLE)
         {
            PrintFormat("[SQLiteKB] WARNING: Could not open: %s%s (err=%d)", full_dir, filename, GetLastError());
            continue;
         }
         
         if(is_utf16)
            PrintFormat("[SQLiteKB] Reading %s as UTF-16", filename);
         else
            PrintFormat("[SQLiteKB] Reading %s as ANSI/UTF-8", filename);

         int imported = 0;
         int line_num = 0;
         while(!FileIsEnding(handle))
         {
            // Read entire line
            string line = FileReadString(handle);
            line_num++;
            if(line == "" && FileIsEnding(handle)) break;
            if(line == "") continue; // Skip empty lines

            // Trim whitespace/newlines
            StringTrimLeft(line);
            StringTrimRight(line);
            if(line == "") continue;
            
            // Skip header line (starts with "timestamp")
            if(line_num == 1 && (StringFind(line, "timestamp") == 0 || StringFind(line, "Timestamp") == 0))
               continue;
            
            // Manual CSV parsing - split by comma
            string fields[5]; // We expect 5 fields
            int field_count = 0;
            int start_pos = 0;
            int line_len = StringLen(line);
            
            for(int pos = 0; pos <= line_len && field_count < 5; pos++)
            {
               if(pos == line_len || StringGetCharacter(line, pos) == ',')
               {
                  int field_len = pos - start_pos;
                  if(field_len > 0)
                     fields[field_count] = StringSubstr(line, start_pos, field_len);
                  else
                     fields[field_count] = "";
                  field_count++;
                  start_pos = pos + 1;
               }
            }
            
            if(field_count < 5)
            {
               PrintFormat("[SQLiteKB] WARNING: Invalid line format (only %d fields): %s", field_count, line);
               continue;
            }
            
            // Trim fields
            for(int f=0; f<5; f++) { StringTrimLeft(fields[f]); StringTrimRight(fields[f]); }

            string ts = fields[0];
            string strat = fields[1];
            string price_s = fields[2];
            string vol_s = fields[3];
            string type_s = fields[4];

            // Basic validation
            if(strat=="" || price_s=="" || vol_s=="" || type_s=="")
            {
               PrintFormat("[SQLiteKB] WARNING: Empty fields in line: %s", line);
               continue;
            }

            STradeRecord trade;
            trade.symbol = sym;
            trade.strategy = strat;
            trade.entry_price = StringToDouble(price_s);
            trade.volume = StringToDouble(vol_s);
            trade.order_type = (int)StringToInteger(type_s);
            trade.timestamp = StringToTime(ts);
            if(trade.timestamp <= 0) trade.timestamp = TimeCurrent();
            trade.pnl = 0;
            trade.sl = 0;
            trade.tp = 0;

            if(LogTrade(trade)) imported++;
         }

         FileClose(handle);
         PrintFormat("[SQLiteKB] Imported %d trades from %s", imported, filename);
         total_imported += imported;
      }
      
      if(file_count == 0)
      {
         Print("[SQLiteKB] No consolidated trades CSV files found");
         return 0;
      }
      
      PrintFormat("[SQLiteKB] Total: %d files, %d trades imported", file_count, total_imported);
      
      // Recalculate stats after import
      if(total_imported > 0)
      {
         PrintFormat("[SQLiteKB] Recalculating stats after importing %d trades...", total_imported);
         
         string strategies[], symbols_arr[];
         int strat_count = GetUniqueStrategies(strategies);
         int sym_count = GetUniqueSymbols(symbols_arr);
         
         int stats_updated = 0;
         for(int s = 0; s < strat_count; s++)
         {
            for(int sym = 0; sym < sym_count; sym++)
            {
               if(RecalculateStrategyStats(strategies[s], symbols_arr[sym]))
               {
                  stats_updated++;
               }
            }
         }
         PrintFormat("[SQLiteKB] Updated %d strategy/symbol statistics", stats_updated);
      }
      
      return total_imported;
   }
   
   //+------------------------------------------------------------------+
   //| Import historical data from CSV files                               |
   //+------------------------------------------------------------------+
   int ImportFromCSV(string csv_path)
   {
      if(!m_initialized) return 0;
      
      PrintFormat("[SQLiteKB] Importing historical data from CSV: %s", csv_path);
      
      // knowledge_base.csv lives under Common Files; open with FILE_COMMON
      // Note: FILE_SHARE flags may not be supported in all MT5 builds
      int file_handle = FileOpen(csv_path, FILE_READ|FILE_CSV|FILE_COMMON, ',');
      if(file_handle == INVALID_HANDLE)
      {
         PrintFormat("[SQLiteKB] ERROR: Cannot open CSV file: %s", csv_path);
         return 0;
      }
      
      // Read header to get column indices
      // For FILE_CSV, read header columns as fields until end-of-line
      string headers[];
      int header_count = 0;
      while(!FileIsEnding(file_handle))
      {
         string col = FileReadString(file_handle);
         if(col == "" && FileIsEnding(file_handle)) break;
         int n = ArraySize(headers);
         ArrayResize(headers, n + 1);
         headers[n] = col;
         header_count++;
         if(FileIsLineEnding(file_handle)) break;
      }
      if(header_count == 0)
      {
         FileClose(file_handle);
         Print("[SQLiteKB] ERROR: Empty CSV file");
         return 0;
      }
      
      // Find column indices
      int col_timestamp = -1, col_symbol = -1, col_strategy = -1;
      int col_order_type = -1, col_entry_price = -1, col_volume = -1;
      int col_sl = -1, col_tp = -1, col_pnl = -1, col_close_time = -1;
      int col_close_price = -1, col_duration = -1, col_is_winner = -1;
      int col_r_multiple = -1, col_market_regime = -1;
      
      for(int i = 0; i < header_count; i++)
      {
         string col = headers[i];
         StringToLower(col);
         StringTrimLeft(col);
         StringTrimRight(col);
         
         if(col == "timestamp") col_timestamp = i;
         else if(col == "symbol") col_symbol = i;
         else if(col == "strategy") col_strategy = i;
         else if(col == "order_type") col_order_type = i;
         else if(col == "entry_price") col_entry_price = i;
         else if(col == "volume") col_volume = i;
         else if(col == "sl") col_sl = i;
         else if(col == "tp") col_tp = i;
         else if(col == "pnl") col_pnl = i;
         else if(col == "close_time") col_close_time = i;
         else if(col == "close_price") col_close_price = i;
         else if(col == "duration_minutes") col_duration = i;
         else if(col == "is_winner") col_is_winner = i;
         else if(col == "r_multiple") col_r_multiple = i;
         else if(col == "market_regime") col_market_regime = i;
      }
      
      // Validate required columns
      if(col_symbol < 0 || col_strategy < 0)
      {
         FileClose(file_handle);
         Print("[SQLiteKB] ERROR: CSV missing required columns (symbol, strategy)");
         return 0;
      }
      
      // Import data rows: for FILE_CSV we read field-by-field
      int imported_count = 0;
      while(!FileIsEnding(file_handle))
      {
         string fields[];
         ArrayResize(fields, 0);
         while(!FileIsEnding(file_handle))
         {
            string v = FileReadString(file_handle);
            if(v == "" && FileIsEnding(file_handle)) break;
            int n = ArraySize(fields);
            ArrayResize(fields, n + 1);
            fields[n] = v;
            if(FileIsLineEnding(file_handle)) break;
         }
         int field_count = ArraySize(fields);
         if(field_count < header_count) continue;

         STradeRecord trade;
         trade.symbol = (col_symbol >= 0 && col_symbol < field_count) ? fields[col_symbol] : "";
         trade.strategy = (col_strategy >= 0 && col_strategy < field_count) ? fields[col_strategy] : "";
         if(trade.symbol == "" || trade.strategy == "") continue;

         if(col_order_type >= 0 && col_order_type < field_count) trade.order_type = (int)StringToInteger(fields[col_order_type]);
         if(col_entry_price >= 0 && col_entry_price < field_count) trade.entry_price = StringToDouble(fields[col_entry_price]);
         if(col_volume >= 0 && col_volume < field_count) trade.volume = StringToDouble(fields[col_volume]);
         if(col_sl >= 0 && col_sl < field_count) trade.sl = StringToDouble(fields[col_sl]);
         if(col_tp >= 0 && col_tp < field_count) trade.tp = StringToDouble(fields[col_tp]);
         if(col_pnl >= 0 && col_pnl < field_count) trade.pnl = StringToDouble(fields[col_pnl]);
         if(col_close_time >= 0 && col_close_time < field_count) trade.close_time = (datetime)StringToInteger(fields[col_close_time]);
         if(col_close_price >= 0 && col_close_price < field_count) trade.close_price = StringToDouble(fields[col_close_price]);
         if(col_duration >= 0 && col_duration < field_count) trade.duration_minutes = (int)StringToInteger(fields[col_duration]);
         if(col_is_winner >= 0 && col_is_winner < field_count) trade.is_winner = (StringToInteger(fields[col_is_winner]) == 1);
         if(col_r_multiple >= 0 && col_r_multiple < field_count) trade.r_multiple = StringToDouble(fields[col_r_multiple]);
         if(col_market_regime >= 0 && col_market_regime < field_count) trade.market_regime = fields[col_market_regime];
         if(col_timestamp >= 0 && col_timestamp < field_count) trade.timestamp = (datetime)StringToInteger(fields[col_timestamp]);
         else trade.timestamp = TimeCurrent();

         if(LogTrade(trade)) imported_count++;
      }
      
      FileClose(file_handle);
      
      // Recalculate strategy statistics after import
      if(imported_count > 0)
      {
         Print(StringFormat("[SQLiteKB] Imported %d trades from CSV, recalculating stats...", imported_count));
         
         // Get all unique strategies and symbols to recalculate stats
         string strategies[], symbols[];
         int strat_count = GetUniqueStrategies(strategies);
         int sym_count = GetUniqueSymbols(symbols);
         
         int stats_updated = 0;
         for(int s = 0; s < strat_count; s++)
         {
            for(int sym = 0; sym < sym_count; sym++)
            {
               if(RecalculateStrategyStats(strategies[s], symbols[sym]))
               {
                  stats_updated++;
               }
            }
         }
         
         Print(StringFormat("[SQLiteKB] Updated %d strategy/symbol statistics", stats_updated));
      }
      
      return imported_count;
   }
   
   //+------------------------------------------------------------------+
   //| Migrate daily trade files to consolidated format                 |
   //| Finds all {symbol}_trades_{date}.csv and merges to {symbol}_trades.csv |
   //+------------------------------------------------------------------+
   int MigrateDailyToConsolidated(string symbol = "")
   {
      string rel_dir = "DualEA\\trades\\";
      string full_dir = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + rel_dir;
      
      PrintFormat("[SQLiteKB] Starting migration from daily to consolidated format in: %s", full_dir);
      
      // Symbols to migrate
      string symbols_to_migrate[];
      if(symbol != "")
      {
         ArrayResize(symbols_to_migrate, 1);
         symbols_to_migrate[0] = symbol;
      }
      else
      {
         // Auto-detect symbols from existing daily files
         string common_symbols[] = {"US500", "UK100", "GER40", "EURUSD", "GBPUSD", "USDJPY", "XAUUSD", "BTCUSD", _Symbol};
         ArrayResize(symbols_to_migrate, ArraySize(common_symbols));
         ArrayCopy(symbols_to_migrate, common_symbols);
      }
      
      int total_migrated = 0;
      int symbols_processed = 0;
      
      // Check each symbol for daily files
      for(int s = 0; s < ArraySize(symbols_to_migrate); s++)
      {
         string sym = symbols_to_migrate[s];
         string consolidated_filename = sym + "_trades.csv";
         string consolidated_path = rel_dir + consolidated_filename;
         
         // Check if any daily files exist for this symbol (last 365 days)
         bool has_daily_files = false;
         string daily_files[];
         datetime now = TimeCurrent();
         
         for(int day = 0; day <= 365; day++)
         {
            MqlDateTime check_dt;
            datetime check_time = now - (day * 86400);
            TimeToStruct(check_time, check_dt);
            
            string date_str = StringFormat("%04d.%02d.%02d", check_dt.year, check_dt.mon, check_dt.day);
            string daily_filename = sym + "_trades_" + date_str + ".csv";
            string daily_path = rel_dir + daily_filename;
            
            if(FileIsExist(daily_path, FILE_COMMON))
            {
               has_daily_files = true;
               int idx = ArraySize(daily_files);
               ArrayResize(daily_files, idx + 1);
               daily_files[idx] = daily_filename;
            }
         }
         
         if(!has_daily_files)
            continue;
         
         symbols_processed++;
         PrintFormat("[SQLiteKB] Migrating %d daily files for %s...", ArraySize(daily_files), sym);
         
         // Read existing trades from consolidated file (to avoid duplicates)
         string existing_trades[];
         int existing_count = 0;
         if(FileIsExist(consolidated_path, FILE_COMMON))
         {
            int h_consol = FileOpen(consolidated_path, FILE_READ|FILE_CSV|FILE_COMMON|FILE_UNICODE, ',');
            if(h_consol != INVALID_HANDLE)
            {
               int line_num = 0;
               while(!FileIsEnding(h_consol))
               {
                  string line = FileReadString(h_consol);
                  line_num++;
                  if(line == "" && FileIsEnding(h_consol)) break;
                  if(line == "") continue;
                  if(line_num == 1 && StringFind(line, "timestamp") >= 0) continue; // Skip header
                  
                  // Store trade line for duplicate checking
                  int n = ArraySize(existing_trades);
                  ArrayResize(existing_trades, n + 1);
                  existing_trades[n] = line;
                  existing_count++;
               }
               FileClose(h_consol);
               PrintFormat("[SQLiteKB] Found %d existing trades in consolidated file", existing_count);
            }
         }
         
         // Open consolidated file for writing (as TXT for proper line-by-line UTF-8 handling)
         int h_out = FileOpen(consolidated_path, FILE_WRITE|FILE_READ|FILE_COMMON|FILE_TXT|FILE_UNICODE);
         if(h_out == INVALID_HANDLE)
         {
            PrintFormat("[SQLiteKB] ERROR: Cannot open consolidated file for writing: %s", consolidated_path);
            continue;
         }
         
         // Write header if new file
         if(FileSize(h_out) == 0)
         {
            FileWriteString(h_out, "timestamp,strategy,price,volume,type\r\n");
         }
         
         // Seek to end to append
         FileSeek(h_out, 0, SEEK_END);
         
         // Process each daily file
         int trades_added = 0;
         int trades_skipped = 0;
         
         for(int d = 0; d < ArraySize(daily_files); d++)
         {
            string daily_path = rel_dir + daily_files[d];
            // Read as TXT for proper line reading
            int h_daily = FileOpen(daily_path, FILE_READ|FILE_COMMON|FILE_TXT|FILE_UNICODE);
            
            if(h_daily == INVALID_HANDLE)
            {
               PrintFormat("[SQLiteKB] WARNING: Cannot open daily file: %s", daily_files[d]);
               continue;
            }
            
            int daily_line_num = 0;
            while(!FileIsEnding(h_daily))
            {
               string line = FileReadString(h_daily);
               daily_line_num++;
               if(line == "" && FileIsEnding(h_daily)) break;
               if(line == "") continue;
               if(daily_line_num == 1 && StringFind(line, "timestamp") >= 0) continue; // Skip header
               
               // Check for duplicates (simple string match)
               bool is_duplicate = false;
               for(int e = 0; e < ArraySize(existing_trades); e++)
               {
                  if(existing_trades[e] == line)
                  {
                     is_duplicate = true;
                     break;
                  }
               }
               
               if(is_duplicate)
               {
                  trades_skipped++;
                  continue;
               }
               
               // Write to consolidated file with proper CRLF line ending
               FileWriteString(h_out, line + "\r\n");
               trades_added++;
               
               // Add to existing_trades to prevent duplicates within this migration
               int n = ArraySize(existing_trades);
               ArrayResize(existing_trades, n + 1);
               existing_trades[n] = line;
            }
            
            FileClose(h_daily);
            
            // Delete the daily file after successful processing
            FileDelete(daily_path, FILE_COMMON);
            PrintFormat("[SQLiteKB] Processed and removed: %s", daily_files[d]);
         }
         
         FileClose(h_out);
         
         PrintFormat("[SQLiteKB] Migrated %s: %d trades added, %d duplicates skipped", 
                     sym, trades_added, trades_skipped);
         total_migrated += trades_added;
      }
      
      if(symbols_processed == 0)
      {
         Print("[SQLiteKB] No daily trade files found to migrate");
         return 0;
      }
      
      PrintFormat("[SQLiteKB] Migration complete: %d symbols processed, %d total trades migrated", 
                  symbols_processed, total_migrated);
      
      // After migration, import the consolidated data
      if(total_migrated > 0)
      {
         Print("[SQLiteKB] Importing migrated data into SQLite database...");
         ImportFromTradesCSV(symbol);
      }
      
      return total_migrated;
   }
   
   //+------------------------------------------------------------------+
   //| Get unique strategies from database                               |
   //+------------------------------------------------------------------+
   int GetUniqueStrategies(string &strategies[])
   {
      if(!m_initialized) return 0;
      
      string sql = "SELECT DISTINCT strategy FROM trades WHERE strategy IS NOT NULL ORDER BY strategy";
      int request = DatabasePrepare(m_db_handle, sql);
      if(request == INVALID_HANDLE) return 0;
      
      int count = 0;
      while(DatabaseRead(request))
      {
         string strategy;
         DatabaseColumnText(request, 0, strategy);
         if(strategy != "")
         {
            ArrayResize(strategies, count + 1);
            strategies[count] = strategy;
            count++;
         }
      }
      
      DatabaseFinalize(request);
      return count;
   }
   
   //+------------------------------------------------------------------+
   //| Get unique symbols from database                                 |
   //+------------------------------------------------------------------+
   int GetUniqueSymbols(string &symbols[])
   {
      if(!m_initialized) return 0;
      
      string sql = "SELECT DISTINCT symbol FROM trades WHERE symbol IS NOT NULL ORDER BY symbol";
      int request = DatabasePrepare(m_db_handle, sql);
      if(request == INVALID_HANDLE) return 0;
      
      int count = 0;
      while(DatabaseRead(request))
      {
         string symbol;
         DatabaseColumnText(request, 0, symbol);
         if(symbol != "")
         {
            ArrayResize(symbols, count + 1);
            symbols[count] = symbol;
            count++;
         }
      }
      
      DatabaseFinalize(request);
      return count;
   }
   
   //+------------------------------------------------------------------+
   //| Get database performance stats                                   |
   //+------------------------------------------------------------------+
   void GetStats(int &total_trades, int &query_count, double &avg_query_time_ms)
   {
      if(!m_initialized)
      {
         total_trades = 0;
         query_count = m_query_count;
         avg_query_time_ms = m_avg_query_time_ms;
         return;
      }
      
      string sql = "SELECT COUNT(*) FROM trades";
      int request = DatabasePrepare(m_db_handle, sql);
      if(request != INVALID_HANDLE)
      {
         if(DatabaseRead(request))
         {
            int col0;
            DatabaseColumnInteger(request, 0, col0);
            total_trades = col0;
         }
         DatabaseFinalize(request);
      }
      
      query_count = m_query_count;
      avg_query_time_ms = m_avg_query_time_ms;
   }
   
   //+------------------------------------------------------------------+
   //| Close database connection                                        |
   //+------------------------------------------------------------------+
   void Close()
   {
      if(m_db_handle != INVALID_HANDLE)
      {
         DatabaseClose(m_db_handle);
         m_db_handle = INVALID_HANDLE;
         m_initialized = false;
         Print("[SQLiteKB] Database closed");
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check if database is healthy                                     |
   //+------------------------------------------------------------------+
   bool IsHealthy()
   {
      if(!m_initialized) return false;
      
      string sql = "SELECT 1";
      return DatabaseExecute(m_db_handle, sql);
   }
   
   //+------------------------------------------------------------------+
   //| Vacuum database to reclaim space                                  |
   //+------------------------------------------------------------------+
   bool Vacuum()
   {
      if(!m_initialized) return false;
      
      Print("[SQLiteKB] Running VACUUM...");
      return DatabaseExecute(m_db_handle, "VACUUM");
   }
};

// Global instance for EA-wide access
CSQLiteKnowledgeBase* g_sqlite_kb = NULL;

//+------------------------------------------------------------------+
//| Initialize SQLite KB globally                                      |
//+------------------------------------------------------------------+
bool InitializeSQLiteKnowledgeBase(string db_name = "dualea_kb.db")
{
   if(g_sqlite_kb != NULL)
   {
      delete g_sqlite_kb;
   }
   
   g_sqlite_kb = new CSQLiteKnowledgeBase(db_name);
   return g_sqlite_kb.Initialize();
}

//+------------------------------------------------------------------+
//| Shutdown SQLite KB                                                |
//+------------------------------------------------------------------+
void ShutdownSQLiteKnowledgeBase()
{
   if(g_sqlite_kb != NULL)
   {
      delete g_sqlite_kb;
      g_sqlite_kb = NULL;
   }
}

#endif // CSQLITEKNOWLEDGEBASE_MQH

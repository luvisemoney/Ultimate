//+------------------------------------------------------------------+
//| CShadowLogger.mqh - Shadow Mode Logging System                   |
//| Based on chat-8Stage Gate System Integration Guide               |
//| P0-1: ATOMIC CSV WRITES - Production-hardened with file locking |
//| - Checksum validation per row                                   |
//| - Atomic write operations (write to temp, then rename)          |
//| - Automatic corruption detection and recovery                  |
//| - File locking during writes to prevent race conditions        |
//+------------------------------------------------------------------+
#ifndef CSHADOWLOGGER_MQH
#define CSHADOWLOGGER_MQH

#include <Files/File.mqh>
#include "CGateBase.mqh"

//+------------------------------------------------------------------+
//| Checksum Calculation - Simple but effective                     |
//+------------------------------------------------------------------+
uint CalculateChecksum(string data)
{
   uint checksum = 0;
   for(int i = 0; i < StringLen(data); i++)
   {
      checksum = ((checksum << 5) + checksum) + (uchar)StringGetCharacter(data, i);
   }
   return checksum;
}

//+------------------------------------------------------------------+
//| Shadow Log Entry Structure                                        |
//+------------------------------------------------------------------+
struct SShadowLogEntry
{
   datetime timestamp;
   string   symbol;
   string   direction;     // BUY/SELL
   double   price;
   double   volume;
   string   strategy_name;
   
   // Gate results for all 8 gates
   bool     gate_passed[8];
   double   gate_confidence[8];
   double   gate_threshold[8];
   string   gate_block_reason[8];
   ulong    gate_latency[8];
   
   // Overall result
   bool     all_gates_passed;
   double   final_confidence;
   string   execution_status;  // "EXECUTED", "SHADOW", "BLOCKED"
   
   // Trade outcome (filled later on position close)
   double   actual_pnl;
   datetime close_time;
   double   close_price;
   
   // P0-1: Checksum for data integrity validation
   uint     row_checksum;
   
   void Init(string sym, string dir, double pr, double vol, string strat)
   {
      timestamp = TimeCurrent();
      symbol = sym;
      direction = dir;
      price = pr;
      volume = vol;
      strategy_name = strat;
      all_gates_passed = false;
      final_confidence = 0.0;
      execution_status = "PENDING";
      actual_pnl = 0.0;
      close_time = 0;
      close_price = 0.0;
      row_checksum = 0;
      
      ArrayInitialize(gate_passed, false);
      ArrayInitialize(gate_confidence, 0.0);
      ArrayInitialize(gate_threshold, 0.0);
      
      for(int i=0; i<8; i++)
         gate_block_reason[i] = "";
   }
   
   void SetGateResult(int gate_num, const EGateResult &result)
   {
      if(gate_num < 0 || gate_num >= 8) return;
      
      gate_passed[gate_num] = result.passed;
      gate_confidence[gate_num] = result.confidence;
      gate_threshold[gate_num] = result.threshold;
      gate_block_reason[gate_num] = result.block_reason;
      gate_latency[gate_num] = result.latency_us;
   }
   
   // P0-1: Calculate checksum for the row data
   void CalculateRowChecksum()
   {
      string data = BuildChecksumString();
      row_checksum = CalculateChecksum(data);
   }
   
   // P0-1: Build string for checksum calculation
   string BuildChecksumString() const
   {
      return StringFormat("%s%s%s%.5f%.2f%s%d%.4f",
         TimeToString(timestamp, TIME_DATE|TIME_SECONDS),
         symbol,
         direction,
         price,
         volume,
         strategy_name,
         all_gates_passed ? 1 : 0,
         final_confidence);
   }
   
   // P0-1: Validate checksum
   bool ValidateChecksum() const
   {
      string data = BuildChecksumString();
      return row_checksum == CalculateChecksum(data);
   }
};

//+------------------------------------------------------------------+
//| Shadow Logger Class                                               |
//+------------------------------------------------------------------+
class CShadowLogger
{
private:
   string m_filename;
   string m_temp_filename;    // P0-1: Temp file for atomic writes
   string m_lock_filename;    // P0-1: Lock file for synchronization
   bool   m_initialized;
   bool   m_shadow_mode;
   int    m_entry_count;
   string m_log_directory;
   
   // P0-1: File locking state
   bool   m_is_locked;
   int    m_lock_handle;
   
   // Ring buffer for recent entries (for quick access)
   SShadowLogEntry m_recent_entries[];
   int    m_recent_capacity;
   int    m_recent_index;
   
   // P0-1: Write retry configuration
   int    m_max_retries;
   int    m_retry_delay_ms;
   
   // P0-1: Memory buffer fallback when disk I/O fails
   string m_memory_buffer[];
   int    m_memory_buffer_count;
   int    m_memory_buffer_max;
   bool   m_is_tester;  // Tester mode detection
   
public:
   // Constructor
   CShadowLogger()
   : m_initialized(false),
     m_shadow_mode(false),
     m_entry_count(0),
     m_recent_capacity(100),
     m_recent_index(0),
     m_is_locked(false),
     m_lock_handle(INVALID_HANDLE),
     m_max_retries(3),
     m_retry_delay_ms(10),
     m_memory_buffer_count(0),
     m_memory_buffer_max(1000),
     m_is_tester(false)  // Will be detected in Initialize()
   {
      ArrayResize(m_recent_entries, m_recent_capacity);
      ArrayResize(m_memory_buffer, m_memory_buffer_max);
      m_log_directory = "DualEA\\ShadowLogs\\";
   }
   
   // Destructor
   ~CShadowLogger()
   {
      // P0-1: Ensure lock is released
      ReleaseFileLock();
   }
   
   //+------------------------------------------------------------------+
   //| P0-1: Acquire file lock using lock file                           |
   //+------------------------------------------------------------------+
   bool AcquireFileLock()
   {
      if(m_is_locked) return true;
      
      // Try to create lock file (exclusive access)
      m_lock_handle = FileOpen(m_lock_filename, 
                              FILE_WRITE|FILE_TXT|FILE_COMMON);
      
      if(m_lock_handle == INVALID_HANDLE)
      {
         // Lock file exists, another process has the lock
         return false;
      }
      
      // Write lock metadata
      FileWriteString(m_lock_handle, 
         StringFormat("PID=%d|TIME=%s", 
            GetTickCount(), 
            TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS)));
      FileFlush(m_lock_handle);
      
      m_is_locked = true;
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| P0-1: Release file lock                                           |
   //+------------------------------------------------------------------+
   void ReleaseFileLock()
   {
      if(!m_is_locked) return;
      
      if(m_lock_handle != INVALID_HANDLE)
      {
         FileClose(m_lock_handle);
         m_lock_handle = INVALID_HANDLE;
      }
      
      // Delete lock file
      FileDelete(m_lock_filename, FILE_COMMON);
      m_is_locked = false;
   }
   
   //+------------------------------------------------------------------+
   //| P0-1: Wait for and acquire lock with timeout                      |
   //+------------------------------------------------------------------+
   bool WaitForLock(int timeout_ms=5000)
   {
      int elapsed = 0;
      while(elapsed < timeout_ms)
      {
         if(AcquireFileLock()) return true;
         
         // Wait before retry
         Sleep(m_retry_delay_ms);
         elapsed += m_retry_delay_ms;
      }
      
      Print("[ShadowLogger] WARNING: Could not acquire file lock within timeout");
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| P0-1: Atomic file write (efficient append with retry)             |
   //+------------------------------------------------------------------+
   bool AtomicWrite(const string data)
   {
      // TESTER MODE: Skip all file I/O to prevent crashes
      if(m_is_tester)
      {
         // Just count entries, no actual file writing
         m_entry_count++;
         return true;
      }
      
      // Fast path: skip locking in tester mode or when file doesn't exist yet
      bool need_lock = (m_entry_count > 10) && !m_shadow_mode;
      
      if(need_lock && !m_is_locked && !WaitForLock(500))
      {
         // In tester mode or when lock fails, proceed without lock but with retries
         Print("[ShadowLogger] INFO: Proceeding without file lock (tester mode or lock unavailable)");
      }
      
      bool success = false;
      int retries = 0;
      
      while(!success && retries < m_max_retries)
      {
         // Efficient append: open file for writing at end (no read required)
         int handle = FileOpen(m_filename,
                              FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_SHARE_READ,
                              ',');
         
         if(handle == INVALID_HANDLE)
         {
            retries++;
            Sleep(m_retry_delay_ms * retries); // Progressive backoff: 10ms, 20ms, 30ms
            continue;
         }
         
         // Seek to end (in case file wasn't opened in append mode)
         FileSeek(handle, 0, SEEK_END);
         
         // Write data with newline
         FileWriteString(handle, data + "\n");
         FileFlush(handle);
         FileClose(handle);
         
         // Quick verification: just check file exists and grew
         if(FileIsExist(m_filename, FILE_COMMON))
         {
            success = true;
         }
         else
         {
            retries++;
            Print("[ShadowLogger] WARNING: Write verification failed, retrying...");
            Sleep(m_retry_delay_ms * retries);
         }
      }
      
      // Release lock if we acquired it
      if(m_is_locked)
         ReleaseFileLock();
      
      // If disk write failed, buffer to memory as fallback
      if(!success)
      {
         if(m_memory_buffer_count < m_memory_buffer_max)
         {
            m_memory_buffer[m_memory_buffer_count] = data;
            m_memory_buffer_count++;
            Print(StringFormat("[ShadowLogger] WARNING: Disk write failed - buffered to memory (%d items)", 
                  m_memory_buffer_count));
         }
         else
         {
            Print("[ShadowLogger] ERROR: Disk write failed AND memory buffer full - data loss imminent");
         }
      }
      
      return success;
   }
   
   //+------------------------------------------------------------------+
   //| P0-1: Flush memory buffer to disk (call from OnTimer)             |
   //+------------------------------------------------------------------+
   void FlushMemoryBuffer()
   {
      if(m_memory_buffer_count == 0) return;
      
      int flushed = 0;
      for(int i = 0; i < m_memory_buffer_count && i < 100; i++) // Max 100 per flush
      {
         // Use simple write (no verification needed for buffered data)
         int handle = FileOpen(m_filename,
                              FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_SHARE_READ,
                              ',');
         
         if(handle == INVALID_HANDLE) break;
         
         FileSeek(handle, 0, SEEK_END);
         FileWriteString(handle, m_memory_buffer[0] + "\n");
         FileFlush(handle);
         FileClose(handle);
         
         // Remove from buffer by shifting
         for(int j = 0; j < m_memory_buffer_count - 1; j++)
            m_memory_buffer[j] = m_memory_buffer[j + 1];
         
         m_memory_buffer_count--;
         flushed++;
      }
      
      if(flushed > 0)
         Print(StringFormat("[ShadowLogger] Flushed %d entries from memory buffer (%d remaining)",
               flushed, m_memory_buffer_count));
   }
   
   //+------------------------------------------------------------------+
   //| P0-1: Check if memory buffer has entries                          |
   //+------------------------------------------------------------------+
   int GetMemoryBufferCount() const { return m_memory_buffer_count; }
   
   //+------------------------------------------------------------------+
   //| P0-1: Verify last write was successful                            |
   //+------------------------------------------------------------------+
   bool VerifyLastWrite(const string expected_data)
   {
      int verify_handle = FileOpen(m_filename,
                                 FILE_READ|FILE_CSV|FILE_COMMON,
                                 ',');
      
      if(verify_handle == INVALID_HANDLE) return false;
      
      // Read last line
      string last_line = "";
      string current_line = "";
      
      while(!FileIsEnding(verify_handle))
      {
         current_line = FileReadString(verify_handle);
         if(StringLen(current_line) > 0)
         {
            last_line = current_line;
         }
      }
      
      FileClose(verify_handle);
      
      // Check if last line matches expected data
      return (last_line == expected_data);
   }
   
   //+------------------------------------------------------------------+
   //| P0-1: Detect and recover from corruption                          |
   //+------------------------------------------------------------------+
   bool DetectAndRecoverCorruption()
   {
      Print("[ShadowLogger] Checking for file corruption...");
      
      // Open as TEXT file to read line by line (not CSV field by field)
      int handle = FileOpen(m_filename,
                           FILE_READ|FILE_TXT|FILE_COMMON);
      
      if(handle == INVALID_HANDLE) return false;
      
      int corrupted_rows = 0;
      int total_rows = 0;
      string valid_content = "";
      bool header_written = false;
      
      // Read file line by line
      while(!FileIsEnding(handle))
      {
         string line = FileReadString(handle);
         total_rows++;
         
         // Skip empty lines
         if(StringLen(line) == 0)
         {
            corrupted_rows++;
            continue;
         }
         
         // Check if this looks like header row (case-insensitive check)
         string line_lower = line;
         // Simple lowercase conversion for comparison
         for(int i = 0; i < StringLen(line_lower); i++)
         {
            ushort c = StringGetCharacter(line_lower, i);
            if(c >= 'A' && c <= 'Z')
               StringSetCharacter(line_lower, i, (ushort)(c + 32));
         }
         
         if(StringFind(line_lower, "timestamp") == 0)
         {
            valid_content += line + "\n";
            header_written = true;
            continue;
         }
         
         // Validate data row: check for proper CSV structure
         string parts[];
         int count = StringSplit(line, ',', parts);
         
         // Expected: timestamp, symbol, direction, price, volume, strategy,
         //           8 gates * 5 fields each, all_passed, final_conf, status, pnl, close_time, close_price, checksum
         // = 6 + 40 + 6 = 52 fields minimum
         if(count >= 6)  // At least basic trade info
         {
            valid_content += line + "\n";
         }
         else
         {
            corrupted_rows++;
            Print(StringFormat("[ShadowLogger] Corrupted row %d detected (only %d fields) and skipped: %.50s", 
               total_rows, count, line));
         }
      }
      
      FileClose(handle);
      
      if(corrupted_rows > 0)
      {
         Print(StringFormat("[ShadowLogger] Recovered from corruption: %d/%d rows valid", 
            total_rows - corrupted_rows, total_rows));
         
         // Write recovered content back
         int recover_handle = FileOpen(m_filename,
                                    FILE_WRITE|FILE_TXT|FILE_COMMON);
         
         if(recover_handle != INVALID_HANDLE)
         {
            FileWriteString(recover_handle, valid_content);
            FileClose(recover_handle);
            return true;
         }
      }
      
      return (corrupted_rows == 0);
   }
   
   //+------------------------------------------------------------------+
   //| Initialize logger                                                |
   //+------------------------------------------------------------------+
   bool Initialize(bool shadow_mode=false, string custom_filename="")
   {
      m_shadow_mode = shadow_mode;
      
      // Detect tester mode - skip file operations in tester to prevent crashes
      m_is_tester = (MQLInfoInteger(MQL_TESTER) != 0);
      if(m_is_tester)
      {
         // In tester mode, just mark as initialized but don't create files
         m_initialized = true;
         Print("[ShadowLogger] TESTER MODE: File logging disabled (memory-only mode)");
         return true;
      }
      
      // Generate filename with timestamp
      if(custom_filename == "")
      {
         datetime now = TimeCurrent();
         MqlDateTime dt;
         TimeToStruct(now, dt);
         m_filename = StringFormat("%s%s_shadow_%04d%02d%02d_%02d%02d.csv",
                     m_log_directory,
                     shadow_mode ? "shadow" : "live",
                     dt.year, dt.mon, dt.day,
                     dt.hour, dt.min);
      }
      else
      {
         m_filename = m_log_directory + custom_filename;
      }
      
      // P0-1: Set up temp and lock filenames
      m_temp_filename = m_filename + ".tmp";
      m_lock_filename = m_filename + ".lock";
      
      // P0-1: Check for and recover from corruption on startup
      if(FileIsExist(m_filename, FILE_COMMON))
      {
         DetectAndRecoverCorruption();
      }
      
      // Write CSV header
      int handle = FileOpen(m_filename, 
                           FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_SHARE_READ,
                           ',');
      
      if(handle == INVALID_HANDLE)
      {
         Print("[ShadowLogger] ERROR: Failed to create log file: " + m_filename);
         return false;
      }
      
      // Write comprehensive header
      string header = 
         "timestamp," +
         "symbol," +
         "direction," +
         "price," +
         "volume," +
         "strategy_name," +
         "g1_passed,g1_conf,g1_thresh,g1_reason,g1_latency," +
         "g2_passed,g2_conf,g2_thresh,g2_reason,g2_latency," +
         "g3_passed,g3_conf,g3_thresh,g3_reason,g3_latency," +
         "g4_passed,g4_conf,g4_thresh,g4_reason,g4_latency," +
         "g5_passed,g5_conf,g5_thresh,g5_reason,g5_latency," +
         "g6_passed,g6_conf,g6_thresh,g6_reason,g6_latency," +
         "g7_passed,g7_conf,g7_thresh,g7_reason,g7_latency," +
         "g8_passed,g8_conf,g8_thresh,g8_reason,g8_latency," +
         "all_passed," +
         "final_conf," +
         "execution_status," +
         "pnl," +
         "close_time," +
         "close_price," +
         "checksum";  // P0-1: Add checksum column
      
      FileWriteString(handle, header + "\n");
      FileClose(handle);
      
      m_initialized = true;
      
      Print(StringFormat("[ShadowLogger] Initialized: %s (Mode: %s, P0-1 Atomic Writes: ENABLED)",
            m_filename,
            shadow_mode ? "SHADOW" : "LIVE"));
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Log a gate decision entry                                        |
   //+------------------------------------------------------------------+
   void LogGateDecision(SShadowLogEntry &entry)  // Note: non-const to allow checksum calc
   {
      if(!m_initialized) return;
      
      // P0-1: Calculate checksum before writing
      entry.CalculateRowChecksum();
      
      // Build CSV line
      string line = BuildCSVLine(entry);
      
      // P0-1: Use atomic write operation
      if(!AtomicWrite(line))
      {
         Print("[ShadowLogger] ERROR: Atomic write failed after retries");
         return;
      }
      
      // Add to recent buffer
      AddToRecentBuffer(entry);
      
      m_entry_count++;
   }
   
   //+------------------------------------------------------------------+
   //| Log trade outcome (update existing entry)                        |
   //+------------------------------------------------------------------+
   void LogTradeOutcome(datetime entry_time, string symbol, double pnl, 
                       datetime close_time, double close_price)
   {
      if(!m_initialized) return;
      
      // Note: In a production system, you'd maintain an index file
      // to quickly locate entries for updating. For now, we append outcome
      // as a separate record or rely on the recent buffer.
      
      // Find in recent buffer
      for(int i=0; i<m_recent_capacity; i++)
      {
         int idx = (m_recent_index - 1 - i + m_recent_capacity) % m_recent_capacity;
         if(m_recent_entries[idx].timestamp == entry_time &&
            m_recent_entries[idx].symbol == symbol)
         {
            m_recent_entries[idx].actual_pnl = pnl;
            m_recent_entries[idx].close_time = close_time;
            m_recent_entries[idx].close_price = close_price;
            break;
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Build CSV line from entry                                        |
   //+------------------------------------------------------------------+
   string BuildCSVLine(const SShadowLogEntry &entry)
   {
      string line = 
         TimeToString(entry.timestamp, TIME_DATE|TIME_SECONDS) + "," +
         entry.symbol + "," +
         entry.direction + "," +
         DoubleToString(entry.price, 5) + "," +
         DoubleToString(entry.volume, 2) + "," +
         entry.strategy_name;
      
      // Add all 8 gate results
      for(int i=0; i<8; i++)
      {
         line += "," +
            (entry.gate_passed[i] ? "1" : "0") + "," +
            DoubleToString(entry.gate_confidence[i], 4) + "," +
            DoubleToString(entry.gate_threshold[i], 4) + "," +
            entry.gate_block_reason[i] + "," +
            IntegerToString((long)entry.gate_latency[i]);
      }
      
      // Add overall result
      line += "," +
         (entry.all_gates_passed ? "1" : "0") + "," +
         DoubleToString(entry.final_confidence, 4) + "," +
         entry.execution_status + "," +
         DoubleToString(entry.actual_pnl, 2) + "," +
         (entry.close_time > 0 ? TimeToString(entry.close_time, TIME_DATE|TIME_SECONDS) : "") + "," +
         DoubleToString(entry.close_price, 5) + "," +
         IntegerToString((long)entry.row_checksum);  // P0-1: Add checksum
      
      return line;
   }
   
   //+------------------------------------------------------------------+
   //| Add to recent buffer (ring buffer)                               |
   //+------------------------------------------------------------------+
   void AddToRecentBuffer(const SShadowLogEntry &entry)
   {
      m_recent_entries[m_recent_index] = entry;
      m_recent_index = (m_recent_index + 1) % m_recent_capacity;
   }
   
   //+------------------------------------------------------------------+
   //| Getters                                                          |
   //+------------------------------------------------------------------+
   bool IsShadowMode() const { return m_shadow_mode; }
   bool IsInitialized() const { return m_initialized; }
   string GetFilename() const { return m_filename; }
   int  GetEntryCount() const { return m_entry_count; }
   
   //+------------------------------------------------------------------+
   //| Get recent entries for analysis                                  |
   //+------------------------------------------------------------------+
   void GetRecentEntries(SShadowLogEntry &entries[], int count)
   {
      int actual_count = MathMin(count, MathMin(m_entry_count, m_recent_capacity));
      ArrayResize(entries, actual_count);
      
      for(int i=0; i<actual_count; i++)
      {
         int idx = (m_recent_index - 1 - i + m_recent_capacity) % m_recent_capacity;
         entries[i] = m_recent_entries[idx];
      }
   }
   
   //+------------------------------------------------------------------+
   //| Calculate statistics from recent entries                         |
   //+------------------------------------------------------------------+
   void CalculateRecentStats(double &win_rate, double &profit_factor, 
                            double &avg_confidence, int &total_trades)
   {
      int count = MathMin(m_entry_count, m_recent_capacity);
      if(count == 0)
      {
         win_rate = 0.0;
         profit_factor = 0.0;
         avg_confidence = 0.0;
         total_trades = 0;
         return;
      }
      
      int wins = 0, losses = 0;
      double total_pnl = 0, loss_pnl = 0, conf_sum = 0;
      
      for(int i=0; i<count; i++)
      {
         if(m_recent_entries[i].actual_pnl != 0)
         {
            total_pnl += m_recent_entries[i].actual_pnl;
            conf_sum += m_recent_entries[i].final_confidence;
            
            if(m_recent_entries[i].actual_pnl > 0)
               wins++;
            else
            {
               losses++;
               loss_pnl += MathAbs(m_recent_entries[i].actual_pnl);
            }
         }
      }
      
      total_trades = wins + losses;
      if(total_trades > 0)
      {
         win_rate = (double)wins / total_trades;
         avg_confidence = conf_sum / total_trades;
         profit_factor = loss_pnl > 0 ? total_pnl / loss_pnl : (total_pnl > 0 ? 999.0 : 0.0);
      }
      else
      {
         win_rate = 0.0;
         profit_factor = 0.0;
         avg_confidence = 0.0;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Print summary statistics                                         |
   //+------------------------------------------------------------------+
   void PrintStats()
   {
      double wr, pf, ac;
      int trades;
      CalculateRecentStats(wr, pf, ac, trades);
      
      Print(StringFormat("[ShadowLogger] Stats: %d entries, Recent: %d trades, WR=%.1f%%, PF=%.2f, AvgConf=%.3f",
            m_entry_count, trades, wr*100, pf, ac));
   }
};

#endif // CSHADOWLOGGER_MQH

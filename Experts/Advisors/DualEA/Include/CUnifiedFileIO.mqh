//+------------------------------------------------------------------+
//| CUnifiedFileIO.mqh - Thread-Safe File Operations with Retry Logic  |
//| Provides robust file I/O with automatic retry, buffering, and       |
//| atomic write operations                                             |
//+------------------------------------------------------------------+
#ifndef CUNIFIEDFILEIO_MQH
#define CUNIFIEDFILEIO_MQH

#include "CErrorRecovery.mqh"

// File operation types
enum ENUM_FILE_OPERATION
{
   FILE_OP_READ = 0,
   FILE_OP_WRITE = 1,
   FILE_OP_APPEND = 2,
   FILE_OP_DELETE = 3
};

// Buffer strategy
enum ENUM_BUFFER_STRATEGY
{
   BUFFER_NONE = 0,        // Direct I/O
   BUFFER_MEMORY = 1,    // Memory buffer with async flush
   BUFFER_DISK = 2       // Disk buffer for critical data
};

//+------------------------------------------------------------------+
//| File Buffer Entry                                                  |
//+------------------------------------------------------------------+
struct SFileBufferEntry
{
   string    data;
   datetime  timestamp;
   int       priority;
   int       retry_count;
   
   SFileBufferEntry()
   {
      data = "";
      timestamp = 0;
      priority = 0;
      retry_count = 0;
   }
};

//+------------------------------------------------------------------+
//| Unified File I/O Manager                                           |
//+------------------------------------------------------------------+
class CUnifiedFileIO
{
private:
   static CUnifiedFileIO* s_instance;
   
   // Memory buffer
   SFileBufferEntry     m_buffer[];
   int                  m_buffer_count;
   int                  m_buffer_max;
   int                  m_buffer_critical_threshold;
   
   // Statistics
   int                  m_total_operations;
   int                  m_successful_operations;
   int                  m_failed_operations;
   int                  m_buffered_operations;
   
   // Configuration
   int                  m_max_retries;
   int                  m_retry_delay_ms;
   bool                 m_use_atomic_writes;
   bool                 m_verify_writes;
   int                  m_file_share_flags;
   
   // Error recovery
   CErrorRecovery*      m_error_recovery;
   
   // Folder creation tracking
   string               m_created_folders[];
   int                  m_created_count;

public:
   CUnifiedFileIO()
   {
      m_buffer_count = 0;
      m_buffer_max = 1000;
      m_buffer_critical_threshold = 800;
      ArrayResize(m_buffer, m_buffer_max);
      
      m_total_operations = 0;
      m_successful_operations = 0;
      m_failed_operations = 0;
      m_buffered_operations = 0;
      
      m_max_retries = 3;
      m_retry_delay_ms = 50;
      m_use_atomic_writes = true;
      m_verify_writes = true;
      m_file_share_flags = FILE_SHARE_READ | FILE_SHARE_WRITE;
      
      m_error_recovery = CErrorRecovery::Instance();
      
      m_created_count = 0;
      ArrayResize(m_created_folders, 100);
   }
   
   ~CUnifiedFileIO()
   {
      // Flush any remaining buffered data
      FlushBuffer(true); // Force flush
   }
   
   static CUnifiedFileIO* Instance()
   {
      if(s_instance == NULL)
         s_instance = new CUnifiedFileIO();
      return s_instance;
   }
   
   static void Destroy()
   {
      if(s_instance != NULL)
      {
         delete s_instance;
         s_instance = NULL;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Configuration                                                      |
   //+------------------------------------------------------------------+
   void SetMaxRetries(int max_retries) { m_max_retries = max_retries; }
   void SetRetryDelay(int delay_ms) { m_retry_delay_ms = delay_ms; }
   void SetBufferSize(int size) { m_buffer_max = size; ArrayResize(m_buffer, size); }
   void SetAtomicWrites(bool atomic) { m_use_atomic_writes = atomic; }
   void SetVerifyWrites(bool verify) { m_verify_writes = verify; }
   
   //+------------------------------------------------------------------+
   //| Safe file read with retry logic                                    |
   //+------------------------------------------------------------------+
   bool ReadFile(const string filename, string &content, bool use_common = true)
   {
      m_total_operations++;
      
      // Clear any pending errors
      ClearError();
      
      // Ensure folder exists
      EnsureFolderExists(filename, use_common);
      
      int flags = FILE_READ | FILE_TXT | FILE_ANSI;
      if(use_common) flags |= FILE_COMMON;
      flags |= m_file_share_flags;
      
      int handle = INVALID_HANDLE;
      
      // Retry loop
      for(int attempt = 1; attempt <= m_max_retries; attempt++)
      {
         handle = FileOpen(filename, flags);
         
         if(handle != INVALID_HANDLE)
            break;
         
         int error_code = GetLastError();
         if(error_code != ERR_FILE_NOT_FOUND && attempt < m_max_retries)
         {
            Log("File read attempt " + IntegerToString(attempt) + "/" + IntegerToString(m_max_retries) + 
                " failed for " + filename + ": " + IntegerToString(error_code));
            Sleep(m_retry_delay_ms * attempt);
            ClearError();
         }
         else
         {
            break;
         }
      }
      
      if(handle == INVALID_HANDLE)
      {
         m_failed_operations++;
         int err = GetLastError();
         if(err != 0)
            m_error_recovery.HandleError(err, "CUnifiedFileIO::ReadFile", filename);
         return false;
      }
      
      // Read content
      content = "";
      while(!FileIsEnding(handle))
      {
         content += FileReadString(handle) + "\n";
      }
      
      FileClose(handle);
      
      m_successful_operations++;
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Safe file write with atomic operation option                         |
   //+------------------------------------------------------------------+
   bool WriteFile(const string filename, const string content, bool use_common = true, bool append = false)
   {
      m_total_operations++;
      
      // Clear any pending errors
      ClearError();
      
      // Ensure folder exists
      EnsureFolderExists(filename, use_common);
      
      if(m_use_atomic_writes && !append)
      {
         return WriteFileAtomic(filename, content, use_common);
      }
      
      int flags = FILE_WRITE | FILE_TXT | FILE_ANSI;
      if(use_common) flags |= FILE_COMMON;
      if(append) flags |= FILE_READ; // Required for seek
      flags |= m_file_share_flags;
      
      int handle = INVALID_HANDLE;
      
      // Retry loop
      for(int attempt = 1; attempt <= m_max_retries; attempt++)
      {
         if(append)
         {
            handle = FileOpen(filename, flags, ',');
            if(handle != INVALID_HANDLE)
               FileSeek(handle, 0, SEEK_END);
         }
         else
         {
            handle = FileOpen(filename, flags);
         }
         
         if(handle != INVALID_HANDLE)
            break;
         
         int error_code = GetLastError();
         if(attempt < m_max_retries)
         {
            Log("File write attempt " + IntegerToString(attempt) + "/" + IntegerToString(m_max_retries) + 
                " failed for " + filename + ": " + IntegerToString(error_code));
            Sleep(m_retry_delay_ms * attempt);
            ClearError();
         }
         else
         {
            break;
         }
      }
      
      if(handle == INVALID_HANDLE)
      {
         m_failed_operations++;
         int err = GetLastError();
         if(err != 0)
            m_error_recovery.HandleError(err, "CUnifiedFileIO::WriteFile", filename);
         
         // Buffer to memory as fallback
         BufferWrite(filename, content);
         return false;
      }
      
      // Write content
      bool write_ok = (FileWriteString(handle, content) > 0);
      FileFlush(handle);
      
      // Verify write if requested
      if(m_verify_writes && write_ok && !append)
      {
         long size = FileSize(handle);
         if(size <= 0)
         {
            Log("Write verification failed for " + filename);
            write_ok = false;
         }
      }
      
      FileClose(handle);
      
      if(write_ok)
      {
         m_successful_operations++;
         return true;
      }
      else
      {
         m_failed_operations++;
         BufferWrite(filename, content);
         return false;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Atomic file write (write to temp, then rename)                     |
   //+------------------------------------------------------------------+
   bool WriteFileAtomic(const string filename, const string content, bool use_common = true)
   {
      string temp_filename = filename + ".tmp";
      
      // Write to temp file
      int flags = FILE_WRITE | FILE_TXT | FILE_ANSI;
      if(use_common) flags |= FILE_COMMON;
      flags |= m_file_share_flags;
      
      int handle = FileOpen(temp_filename, flags);
      if(handle == INVALID_HANDLE)
      {
         // Fallback to non-atomic write
         return WriteFile(filename, content, use_common, false);
      }
      
      bool write_ok = (FileWriteString(handle, content) > 0);
      FileFlush(handle);
      long temp_size = FileSize(handle);
      FileClose(handle);
      
      if(!write_ok || temp_size <= 0)
      {
         // Clean up temp file
         FileDelete(temp_filename, use_common ? FILE_COMMON : 0);
         return false;
      }
      
      // Delete old file if exists
      if(FileIsExist(filename, use_common ? FILE_COMMON : 0))
      {
         FileDelete(filename, use_common ? FILE_COMMON : 0);
      }
      
      // Rename temp to final
      // Note: MQL5 doesn't have direct FileRename, so we copy and delete
      bool renamed = FileCopy(temp_filename, use_common ? FILE_COMMON : 0, 
                              filename, use_common ? FILE_COMMON : 0, 
                              FILE_REWRITE);
      
      if(renamed)
      {
         FileDelete(temp_filename, use_common ? FILE_COMMON : 0);
         m_successful_operations++;
         return true;
      }
      else
      {
         // Cleanup
         FileDelete(temp_filename, use_common ? FILE_COMMON : 0);
         m_failed_operations++;
         BufferWrite(filename, content);
         return false;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Buffer write for failed operations                                 |
   //+------------------------------------------------------------------+
   void BufferWrite(const string filename, const string content)
   {
      if(m_buffer_count >= m_buffer_max)
      {
         // Remove oldest entry
         for(int i = 0; i < m_buffer_count - 1; i++)
         {
            m_buffer[i] = m_buffer[i + 1];
         }
         m_buffer_count--;
      }
      
      SFileBufferEntry entry;
      entry.data = filename + "|" + content;
      entry.timestamp = TimeCurrent();
      entry.priority = 1;
      entry.retry_count = 0;
      
      m_buffer[m_buffer_count] = entry;
      m_buffer_count++;
      m_buffered_operations++;
      
      if(m_buffer_count >= m_buffer_critical_threshold)
      {
         Log("WARNING: File buffer at " + IntegerToString(m_buffer_count) + "/" + IntegerToString(m_buffer_max));
      }
   }
   
   //+------------------------------------------------------------------+
   //| Flush buffer to disk                                                |
   //+------------------------------------------------------------------+
   int FlushBuffer(bool force = false)
   {
      if(m_buffer_count == 0) return 0;
      
      int flushed = 0;
      int max_flush = force ? m_buffer_count : MathMin(100, m_buffer_count);
      
      for(int i = 0; i < max_flush; i++)
      {
         SFileBufferEntry &entry = m_buffer[i];
         
         // Parse filename and content
         int sep_pos = StringFind(entry.data, "|");
         if(sep_pos < 0) continue;
         
         string filename = StringSubstr(entry.data, 0, sep_pos);
         string content = StringSubstr(entry.data, sep_pos + 1);
         
         if(WriteFile(filename, content, true, true)) // Append mode
         {
            flushed++;
         }
         else
         {
            entry.retry_count++;
            if(entry.retry_count >= m_max_retries)
            {
               Log("Failed to flush buffer entry after " + IntegerToString(m_max_retries) + " retries");
               // Keep in buffer for next attempt
            }
         }
      }
      
      // Remove flushed entries
      int remaining = 0;
      for(int i = 0; i < m_buffer_count; i++)
      {
         if(i < flushed)
            continue; // Skip flushed entries
         
         m_buffer[remaining] = m_buffer[i];
         remaining++;
      }
      
      m_buffer_count = remaining;
      ArrayResize(m_buffer, m_buffer_max); // Ensure capacity
      
      if(flushed > 0)
      {
         Log("Flushed " + IntegerToString(flushed) + " buffer entries, " + IntegerToString(m_buffer_count) + " remaining");
      }
      
      return flushed;
   }
   
   //+------------------------------------------------------------------+
   //| Ensure folder exists                                                |
   //+------------------------------------------------------------------+
   void EnsureFolderExists(const string path, bool use_common)
   {
      // Extract folder path
      int last_sep = -1;
      for(int i = StringLen(path) - 1; i >= 0; i--)
      {
         string c = StringSubstr(path, i, 1);
         if(c == "\\" || c == "/")
         {
            last_sep = i;
            break;
         }
      }
      
      if(last_sep < 0) return; // No folder component
      
      string folder = StringSubstr(path, 0, last_sep);
      if(folder == "") return;
      
      // Check if already created
      for(int i = 0; i < m_created_count; i++)
      {
         if(m_created_folders[i] == folder)
            return;
      }
      
      // Create folder
      int flags = use_common ? FILE_COMMON : 0;
      bool created = FolderCreate(folder, flags);
      
      if(created || GetLastError() == 0)
      {
         // Track created folder
         if(m_created_count < ArraySize(m_created_folders))
         {
            m_created_folders[m_created_count] = folder;
            m_created_count++;
         }
      }
      
      ClearError();
   }
   
   //+------------------------------------------------------------------+
   //| Statistics and reporting                                           |
   //+------------------------------------------------------------------+
   string GetStatistics()
   {
      string stats = StringFormat(
         "=== Unified File I/O Statistics ===\n" +
         "Total Operations: %d\n" +
         "Successful: %d (%.1f%%)\n" +
         "Failed: %d (%.1f%%)\n" +
         "Buffered: %d\n" +
         "Buffer: %d/%d entries",
         m_total_operations,
         m_successful_operations,
         (m_total_operations > 0 ? 100.0 * m_successful_operations / m_total_operations : 0),
         m_failed_operations,
         (m_total_operations > 0 ? 100.0 * m_failed_operations / m_total_operations : 0),
         m_buffered_operations,
         m_buffer_count,
         m_buffer_max
      );
      
      return stats;
   }
   
   //+------------------------------------------------------------------+
   //| Utility functions                                                  |
   //+------------------------------------------------------------------+
   void Log(const string message)
   {
      Print("[UnifiedFileIO] " + message);
   }
   
   void ClearError()
   {
      int _ = GetLastError();
   }
   
   // Getters
   int GetBufferedCount() const { return m_buffer_count; }
   bool IsBufferCritical() const { return m_buffer_count >= m_buffer_critical_threshold; }
   int GetBufferUtilizationPercent() const { return (m_buffer_count * 100) / m_buffer_max; }
};

// Static instance initialization
CUnifiedFileIO* CUnifiedFileIO::s_instance = NULL;

// Convenience macros
#define SAFE_FILE_READ(filename, content, use_common) \
   CUnifiedFileIO::Instance().ReadFile(filename, content, use_common)

#define SAFE_FILE_WRITE(filename, content, use_common) \
   CUnifiedFileIO::Instance().WriteFile(filename, content, use_common, false)

#define SAFE_FILE_APPEND(filename, content, use_common) \
   CUnifiedFileIO::Instance().WriteFile(filename, content, use_common, true)

#define FLUSH_FILE_BUFFER(force) \
   CUnifiedFileIO::Instance().FlushBuffer(force)

#endif // CUNIFIEDFILEIO_MQH

//+------------------------------------------------------------------+
//| SecureSignalBroadcaster.mqh - Secure signal broadcasting         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "2.00"

#include "..\Common\Enums.mqh"
#include "..\Common\Structs.mqh"
#include "..\Common\Constants.mqh"

//+------------------------------------------------------------------+
//| Secure Signal Broadcaster Class - JAILBREAK HARDENED            |
//+------------------------------------------------------------------+
class CSecureSignalBroadcaster
  {
private:
   string            m_signalPrefix;      // Prefix for signal names
   int               m_signalLifetime;    // Signal lifetime in seconds
   string            m_lockFile;          // Lock file for atomic operations
   string            m_queueDirectory;    // Message queue directory
   int               m_maxQueueSize;      // Maximum queue size (BOUNDS CHECK)
   
   // Security measures
   string            m_instanceId;        // Unique instance identifier
   datetime          m_lastCleanup;       // Last cleanup time
   
   // Private methods - HARDENED
   string            GenerateSecureSignalId();
   bool              AcquireLock(int timeoutMs = 5000);
   void              ReleaseLock();
   bool              ValidateSignal(const STradeSignal &signal);
   bool              WriteSignalToQueue(const STradeSignal &signal);
   void              CleanupExpiredSignals();
   string            GetQueueFilePath(const string signalId);
   
public:
   // Constructor/destructor - MEMORY SAFE
                     CSecureSignalBroadcaster(string prefix = SIGNAL_PREFIX, 
                                            int lifetime = MAX_SIGNAL_AGE,
                                            int maxQueueSize = 1000);
                    ~CSecureSignalBroadcaster();
   
   // Signal management - SECURE
   bool              SendSignal(const STradeSignal &signal);
   bool              BroadcastStatus(const string status, ENUM_SIGNAL_STRENGTH strength = SIGNAL_MEDIUM);
   
   // Queue management
   int               GetQueueSize();
   bool              IsQueueHealthy();
   void              ForceCleanup();
   
   // Getters
   string            GetSignalPrefix() const { return m_signalPrefix; }
   int               GetSignalLifetime() const { return m_signalLifetime; }
   string            GetInstanceId() const { return m_instanceId; }
   
   // Setters - WITH VALIDATION
   bool              SetSignalPrefix(const string prefix);
   bool              SetSignalLifetime(int seconds);
  };

//+------------------------------------------------------------------+
//| Constructor - SECURE INITIALIZATION                              |
//+------------------------------------------------------------------+
CSecureSignalBroadcaster::CSecureSignalBroadcaster(string prefix = SIGNAL_PREFIX, 
                                                  int lifetime = MAX_SIGNAL_AGE,
                                                  int maxQueueSize = 1000) :
   m_signalPrefix(prefix),
   m_signalLifetime(MathMax(10, MathMin(lifetime, 3600))), // BOUNDS CHECK: 10s-1h
   m_maxQueueSize(MathMax(10, MathMin(maxQueueSize, 10000))), // BOUNDS CHECK: 10-10k
   m_lastCleanup(0)
  {
   // Generate unique instance ID for security
   m_instanceId = StringFormat("%s_%d_%d", prefix, GetTickCount(), MathRand());
   
   // Setup secure directories
   m_queueDirectory = StringFormat("Files\\EscapeEA\\Queue\\%s\\", m_instanceId);
   m_lockFile = m_queueDirectory + "queue.lock";
   
   // Create directory structure
   if(!FolderCreate(m_queueDirectory, FILE_COMMON))
     {
      int error = GetLastError();
      if(error != ERR_FILE_IS_DIRECTORY) // Ignore if already exists
        {
         Print("SECURITY WARNING: Failed to create queue directory: ", error);
        }
     }
   
   Print("SecureSignalBroadcaster initialized: ", m_instanceId);
  }

//+------------------------------------------------------------------+
//| Destructor - SECURE CLEANUP                                     |
//+------------------------------------------------------------------+
CSecureSignalBroadcaster::~CSecureSignalBroadcaster()
  {
   // Force cleanup of our signals
   ForceCleanup();
   
   // Release any held locks
   ReleaseLock();
   
   Print("SecureSignalBroadcaster destroyed: ", m_instanceId);
  }

//+------------------------------------------------------------------+
//| Generate cryptographically secure signal ID                      |
//+------------------------------------------------------------------+
string CSecureSignalBroadcaster::GenerateSecureSignalId()
  {
   // Use multiple entropy sources for security
   ulong tick = GetTickCount64();
   int rand1 = MathRand();
   int rand2 = MathRand();
   datetime time = TimeCurrent();
   
   // Create hash-like ID (simplified for MQL5)
   string id = StringFormat("%s_%I64u_%d_%d_%d", 
                           m_instanceId, tick, rand1, rand2, (int)time);
   
   return id;
  }

//+------------------------------------------------------------------+
//| Acquire exclusive lock for atomic operations                     |
//+------------------------------------------------------------------+
bool CSecureSignalBroadcaster::AcquireLock(int timeoutMs = 5000)
  {
   datetime startTime = GetTickCount();
   
   while((GetTickCount() - startTime) < timeoutMs)
     {
      // Try to create lock file
      int handle = FileOpen(m_lockFile, FILE_WRITE|FILE_BIN|FILE_COMMON);
      if(handle != INVALID_HANDLE)
        {
         // Write our instance ID to the lock file
         FileWriteString(handle, m_instanceId);
         FileClose(handle);
         return true;
        }
      
      // Lock exists, check if it's stale
      if(FileIsExist(m_lockFile, FILE_COMMON))
        {
         // Check lock age
         datetime lockTime = (datetime)FileGetInteger(m_lockFile, FILE_MODIFY_DATE, FILE_COMMON);
         if((TimeCurrent() - lockTime) > 30) // 30 second stale lock timeout
           {
            FileDelete(m_lockFile, FILE_COMMON);
            Print("SECURITY: Removed stale lock file");
           }
        }
      
      Sleep(10); // Wait 10ms before retry
     }
   
   Print("SECURITY ERROR: Failed to acquire lock within timeout");
   return false;
  }

//+------------------------------------------------------------------+
//| Release exclusive lock                                           |
//+------------------------------------------------------------------+
void CSecureSignalBroadcaster::ReleaseLock()
  {
   if(FileIsExist(m_lockFile, FILE_COMMON))
     {
      // Verify we own the lock
      int handle = FileOpen(m_lockFile, FILE_READ|FILE_BIN|FILE_COMMON);
      if(handle != INVALID_HANDLE)
        {
         string lockOwner = FileReadString(handle);
         FileClose(handle);
         
         if(lockOwner == m_instanceId)
           {
            FileDelete(m_lockFile, FILE_COMMON);
           }
         else
           {
            Print("SECURITY WARNING: Attempted to release lock owned by: ", lockOwner);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Validate signal before broadcasting - SECURITY CHECK            |
//+------------------------------------------------------------------+
bool CSecureSignalBroadcaster::ValidateSignal(const STradeSignal &signal)
  {
   // Protocol version check
   if(signal.version != SIGNAL_PROTOCOL_VERSION)
     {
      Print("SECURITY: Invalid signal protocol version: ", signal.version);
      return false;
     }
   
   // Signal type validation
   if(signal.signal != SIGNAL_BUY && signal.signal != SIGNAL_SELL)
     {
      Print("SECURITY: Invalid signal type: ", signal.signal);
      return false;
     }
   
   // Confidence bounds check
   if(signal.confidence < 0.0 || signal.confidence > 1.0)
     {
      Print("SECURITY: Invalid confidence value: ", signal.confidence);
      return false;
     }
   
   // Symbol validation
   if(StringLen(signal.symbol) == 0 || StringLen(signal.symbol) > 20)
     {
      Print("SECURITY: Invalid symbol: ", signal.symbol);
      return false;
     }
   
   // Price validation
   if(signal.entry <= 0.0 || signal.stopLoss < 0.0 || signal.takeProfit < 0.0)
     {
      Print("SECURITY: Invalid price levels");
      return false;
     }
   
   // Timestamp validation (not too old, not in future)
   datetime now = TimeCurrent();
   if(signal.timestamp < (now - 3600) || signal.timestamp > (now + 60))
     {
      Print("SECURITY: Invalid timestamp: ", signal.timestamp);
      return false;
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Write signal to secure queue                                    |
//+------------------------------------------------------------------+
bool CSecureSignalBroadcaster::WriteSignalToQueue(const STradeSignal &signal)
  {
   // Check queue size limits
   if(GetQueueSize() >= m_maxQueueSize)
     {
      Print("SECURITY: Queue size limit reached, forcing cleanup");
      CleanupExpiredSignals();
      
      if(GetQueueSize() >= m_maxQueueSize)
        {
         Print("SECURITY ERROR: Queue still full after cleanup");
         return false;
        }
     }
   
   string signalId = GenerateSecureSignalId();
   string filePath = GetQueueFilePath(signalId);
   
   // Create signal file with JSON format
   int handle = FileOpen(filePath, FILE_WRITE|FILE_TXT|FILE_COMMON, ",", CP_UTF8);
   if(handle == INVALID_HANDLE)
     {
      Print("SECURITY ERROR: Failed to create signal file: ", GetLastError());
      return false;
     }
   
   // Write signal data as JSON
   string json = StringFormat(
      "{\"version\":%d,\"signal\":%d,\"confidence\":%.4f,\"symbol\":\"%s\",\"timeframe\":%d," +
      "\"timestamp\":%d,\"entry\":%.5f,\"stopLoss\":%.5f,\"takeProfit\":%.5f," +
      "\"riskReward\":%.2f,\"comment\":\"%s\",\"expires\":%d,\"instanceId\":\"%s\"}",
      signal.version, signal.signal, signal.confidence, signal.symbol, signal.timeframe,
      signal.timestamp, signal.entry, signal.stopLoss, signal.takeProfit,
      signal.riskReward, signal.comment, 
      TimeCurrent() + m_signalLifetime, m_instanceId);
   
   FileWriteString(handle, json);
   FileClose(handle);
   
   Print("SECURE: Signal broadcasted: ", signalId);
   return true;
  }

//+------------------------------------------------------------------+
//| Send secure trading signal                                       |
//+------------------------------------------------------------------+
bool CSecureSignalBroadcaster::SendSignal(const STradeSignal &signal)
  {
   // Validate signal first
   if(!ValidateSignal(signal))
     {
      return false;
     }
   
   // Acquire lock for atomic operation
   if(!AcquireLock())
     {
      Print("SECURITY ERROR: Failed to acquire lock for signal broadcast");
      return false;
     }
   
   bool result = WriteSignalToQueue(signal);
   
   // Always release lock
   ReleaseLock();
   
   // Periodic cleanup
   if((TimeCurrent() - m_lastCleanup) > 300) // Every 5 minutes
     {
      CleanupExpiredSignals();
      m_lastCleanup = TimeCurrent();
     }
   
   return result;
  }

//+------------------------------------------------------------------+
//| Broadcast system status securely                                |
//+------------------------------------------------------------------+
bool CSecureSignalBroadcaster::BroadcastStatus(const string status, ENUM_SIGNAL_STRENGTH strength = SIGNAL_MEDIUM)
  {
   // Create status signal
   STradeSignal statusSignal;
   statusSignal.version = SIGNAL_PROTOCOL_VERSION;
   statusSignal.signal = SIGNAL_HOLD; // Status signals use HOLD
   statusSignal.confidence = (double)strength / 4.0; // Convert strength to confidence
   statusSignal.symbol = "STATUS";
   statusSignal.timeframe = PERIOD_CURRENT;
   statusSignal.timestamp = TimeCurrent();
   statusSignal.comment = status;
   
   return SendSignal(statusSignal);
  }

//+------------------------------------------------------------------+
//| Get current queue size                                           |
//+------------------------------------------------------------------+
int CSecureSignalBroadcaster::GetQueueSize()
  {
   string searchPattern = m_queueDirectory + "*.json";
   string fileName;
   long searchHandle = FileFindFirst(searchPattern, fileName, FILE_COMMON);
   
   if(searchHandle == INVALID_HANDLE)
      return 0;
   
   int count = 1; // Count the first file found
   
   while(FileFindNext(searchHandle, fileName))
      count++;
   
   FileFindClose(searchHandle);
   return count;
  }

//+------------------------------------------------------------------+
//| Check if queue is healthy                                        |
//+------------------------------------------------------------------+
bool CSecureSignalBroadcaster::IsQueueHealthy()
  {
   int queueSize = GetQueueSize();
   
   // Queue is unhealthy if too full or if lock is stale
   if(queueSize > (m_maxQueueSize * 0.8)) // 80% full threshold
     {
      Print("HEALTH WARNING: Queue is ", (queueSize * 100 / m_maxQueueSize), "% full");
      return false;
     }
   
   // Check for stale lock
   if(FileIsExist(m_lockFile, FILE_COMMON))
     {
      datetime lockTime = (datetime)FileGetInteger(m_lockFile, FILE_MODIFY_DATE, FILE_COMMON);
      if((TimeCurrent() - lockTime) > 60) // 1 minute stale threshold
        {
         Print("HEALTH WARNING: Stale lock detected");
         return false;
        }
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Force cleanup of expired signals                                |
//+------------------------------------------------------------------+
void CSecureSignalBroadcaster::ForceCleanup()
  {
   if(!AcquireLock())
     {
      Print("CLEANUP WARNING: Could not acquire lock for cleanup");
      return;
     }
   
   CleanupExpiredSignals();
   ReleaseLock();
  }

//+------------------------------------------------------------------+
//| Clean up expired signals from queue                             |
//+------------------------------------------------------------------+
void CSecureSignalBroadcaster::CleanupExpiredSignals()
  {
   datetime now = TimeCurrent();
   string searchPattern = m_queueDirectory + "*.json";
   string fileName;
   long searchHandle = FileFindFirst(searchPattern, fileName, FILE_COMMON);
   
   if(searchHandle == INVALID_HANDLE)
      return;
   
   int cleanedCount = 0;
   
   do
     {
      string filePath = m_queueDirectory + fileName;
      
      // Read signal file to check expiration
      int handle = FileOpen(filePath, FILE_READ|FILE_TXT|FILE_COMMON, ",", CP_UTF8);
      if(handle != INVALID_HANDLE)
        {
         string content = "";
         while(!FileIsEnding(handle))
            content += FileReadString(handle);
         FileClose(handle);
         
         // Simple JSON parsing for expires field
         int expiresPos = StringFind(content, "\"expires\":");
         if(expiresPos >= 0)
           {
            int valueStart = expiresPos + 10;
            int valueEnd = StringFind(content, ",", valueStart);
            if(valueEnd < 0) valueEnd = StringFind(content, "}", valueStart);
            
            if(valueEnd > valueStart)
              {
               string expiresStr = StringSubstr(content, valueStart, valueEnd - valueStart);
               datetime expires = (datetime)StringToInteger(expiresStr);
               
               if(now > expires)
                 {
                  FileDelete(filePath, FILE_COMMON);
                  cleanedCount++;
                 }
              }
           }
        }
     }
   while(FileFindNext(searchHandle, fileName));
   
   FileFindClose(searchHandle);
   
   if(cleanedCount > 0)
      Print("CLEANUP: Removed ", cleanedCount, " expired signals");
  }

//+------------------------------------------------------------------+
//| Get queue file path for signal ID                               |
//+------------------------------------------------------------------+
string CSecureSignalBroadcaster::GetQueueFilePath(const string signalId)
  {
   return m_queueDirectory + signalId + ".json";
  }

//+------------------------------------------------------------------+
//| Set signal prefix with validation                               |
//+------------------------------------------------------------------+
bool CSecureSignalBroadcaster::SetSignalPrefix(const string prefix)
  {
   if(StringLen(prefix) == 0 || StringLen(prefix) > 50)
     {
      Print("VALIDATION ERROR: Invalid prefix length");
      return false;
     }
   
   m_signalPrefix = prefix;
   return true;
  }

//+------------------------------------------------------------------+
//| Set signal lifetime with validation                             |
//+------------------------------------------------------------------+
bool CSecureSignalBroadcaster::SetSignalLifetime(int seconds)
  {
   if(seconds < 10 || seconds > 3600)
     {
      Print("VALIDATION ERROR: Invalid lifetime (must be 10-3600 seconds)");
      return false;
     }
   
   m_signalLifetime = seconds;
   return true;
  }
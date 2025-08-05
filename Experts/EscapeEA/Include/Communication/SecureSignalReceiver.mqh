//+------------------------------------------------------------------+
//| SecureSignalReceiver.mqh - Secure signal receiving               |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "2.00"

#include "..\Common\Enums.mqh"
#include "..\Common\Structs.mqh"
#include "..\Common\Constants.mqh"

//+------------------------------------------------------------------+
//| Secure Signal Receiver Class - JAILBREAK HARDENED              |
//+------------------------------------------------------------------+
class CSecureSignalReceiver
  {
private:
   string            m_signalPrefix;      // Prefix for signal names
   int               m_maxSignalAge;      // Maximum signal age in seconds
   string            m_instanceId;        // Unique instance identifier
   string            m_queueDirectory;    // Message queue directory
   int               m_maxProcessedCache; // Maximum processed signals cache
   
   // Security and performance
   string            m_processedSignals[]; // Cache of processed signal IDs
   int               m_processedCount;     // Number of processed signals
   datetime          m_lastScan;          // Last queue scan time
   int               m_scanInterval;      // Scan interval in seconds
   
   // Private methods - HARDENED
   bool              ValidateSignalFile(const string filePath, STradeSignal &signal);
   bool              ParseSignalJson(const string json, STradeSignal &signal);
   bool              IsSignalProcessed(const string signalId);
   void              MarkSignalProcessed(const string signalId);
   void              CleanupProcessedCache();
   string            ExtractSignalId(const string fileName);
   bool              IsSignalExpired(const STradeSignal &signal);
   
public:
   // Constructor/destructor - MEMORY SAFE
                     CSecureSignalReceiver(string prefix = SIGNAL_PREFIX, 
                                         int maxAge = MAX_SIGNAL_AGE,
                                         int scanInterval = 1);
                    ~CSecureSignalReceiver();
   
   // Signal management - SECURE
   int               CheckForNewSignals(STradeSignal &signals[]);
   bool              AcknowledgeSignal(const string signalId);
   void              CleanupExpiredSignals();
   
   // Queue management
   int               GetAvailableSignalCount();
   bool              IsQueueHealthy();
   void              ForceRescan();
   
   // Getters
   string            GetSignalPrefix() const { return m_signalPrefix; }
   int               GetMaxSignalAge() const { return m_maxSignalAge; }
   string            GetInstanceId() const { return m_instanceId; }
   int               GetProcessedCount() const { return m_processedCount; }
   
   // Setters - WITH VALIDATION
   bool              SetSignalPrefix(const string prefix);
   bool              SetMaxSignalAge(int seconds);
   bool              SetScanInterval(int seconds);
  };

//+------------------------------------------------------------------+
//| Constructor - SECURE INITIALIZATION                              |
//+------------------------------------------------------------------+
CSecureSignalReceiver::CSecureSignalReceiver(string prefix = SIGNAL_PREFIX, 
                                            int maxAge = MAX_SIGNAL_AGE,
                                            int scanInterval = 1) :
   m_signalPrefix(prefix),
   m_maxSignalAge(MathMax(10, MathMin(maxAge, 3600))), // BOUNDS CHECK: 10s-1h
   m_scanInterval(MathMax(1, MathMin(scanInterval, 60))), // BOUNDS CHECK: 1-60s
   m_processedCount(0),
   m_lastScan(0),
   m_maxProcessedCache(1000) // BOUNDS CHECK: Limit processed cache
  {
   // Generate unique instance ID
   m_instanceId = StringFormat("Receiver_%s_%d_%d", prefix, GetTickCount(), MathRand());
   
   // Setup queue directory (scan all broadcaster directories)
   m_queueDirectory = "Files\\EscapeEA\\Queue\\";
   
   // Initialize processed signals cache
   ArrayResize(m_processedSignals, m_maxProcessedCache);
   ArrayInitialize(m_processedSignals, "");
   
   Print("SecureSignalReceiver initialized: ", m_instanceId);
  }

//+------------------------------------------------------------------+
//| Destructor - SECURE CLEANUP                                     |
//+------------------------------------------------------------------+
CSecureSignalReceiver::~CSecureSignalReceiver()
  {
   // Clear processed signals cache
   ArrayFree(m_processedSignals);
   
   Print("SecureSignalReceiver destroyed: ", m_instanceId);
  }

//+------------------------------------------------------------------+
//| Validate signal file and parse content                          |
//+------------------------------------------------------------------+
bool CSecureSignalReceiver::ValidateSignalFile(const string filePath, STradeSignal &signal)
  {
   // Check file exists and is readable
   if(!FileIsExist(filePath, FILE_COMMON))
     {
      return false;
     }
   
   // Check file age (basic security check)
   datetime fileTime = (datetime)FileGetInteger(filePath, FILE_MODIFY_DATE, FILE_COMMON);
   if((TimeCurrent() - fileTime) > m_maxSignalAge)
     {
      // File is too old, delete it
      FileDelete(filePath, FILE_COMMON);
      return false;
     }
   
   // Read and parse file content
   int handle = FileOpen(filePath, FILE_READ|FILE_TXT|FILE_COMMON, ",", CP_UTF8);
   if(handle == INVALID_HANDLE)
     {
      Print("SECURITY WARNING: Cannot read signal file: ", filePath);
      return false;
     }
   
   string content = "";
   while(!FileIsEnding(handle))
      content += FileReadString(handle);
   FileClose(handle);
   
   // Parse JSON content
   if(!ParseSignalJson(content, signal))
     {
      Print("SECURITY WARNING: Invalid signal format in: ", filePath);
      FileDelete(filePath, FILE_COMMON); // Remove invalid file
      return false;
     }
   
   // Additional validation
   if(IsSignalExpired(signal))
     {
      FileDelete(filePath, FILE_COMMON); // Remove expired signal
      return false;
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Parse signal JSON content - SECURE PARSING                      |
//+------------------------------------------------------------------+
bool CSecureSignalReceiver::ParseSignalJson(const string json, STradeSignal &signal)
  {
   // Initialize signal with defaults
   signal.version = 0;
   signal.signal = SIGNAL_HOLD;
   signal.confidence = 0.0;
   signal.symbol = "";
   signal.timeframe = PERIOD_CURRENT;
   signal.timestamp = 0;
   signal.entry = 0.0;
   signal.stopLoss = 0.0;
   signal.takeProfit = 0.0;
   signal.riskReward = 0.0;
   signal.comment = "";
   
   // Simple JSON parsing with security checks
   // Parse version
   int versionPos = StringFind(json, "\"version\":");
   if(versionPos >= 0)
     {
      int valueStart = versionPos + 10;
      int valueEnd = StringFind(json, ",", valueStart);
      if(valueEnd < 0) valueEnd = StringFind(json, "}", valueStart);
      
      if(valueEnd > valueStart)
        {
         string versionStr = StringSubstr(json, valueStart, valueEnd - valueStart);
         signal.version = (int)StringToInteger(versionStr);
        }
     }
   
   // Validate protocol version
   if(signal.version != SIGNAL_PROTOCOL_VERSION)
     {
      Print("SECURITY: Incompatible signal version: ", signal.version);
      return false;
     }
   
   // Parse signal type
   int signalPos = StringFind(json, "\"signal\":");
   if(signalPos >= 0)
     {
      int valueStart = signalPos + 9;
      int valueEnd = StringFind(json, ",", valueStart);
      if(valueEnd < 0) valueEnd = StringFind(json, "}", valueStart);
      
      if(valueEnd > valueStart)
        {
         string signalStr = StringSubstr(json, valueStart, valueEnd - valueStart);
         signal.signal = (ENUM_TRADE_SIGNAL)StringToInteger(signalStr);
        }
     }
   
   // Parse confidence
   int confidencePos = StringFind(json, "\"confidence\":");
   if(confidencePos >= 0)
     {
      int valueStart = confidencePos + 13;
      int valueEnd = StringFind(json, ",", valueStart);
      if(valueEnd < 0) valueEnd = StringFind(json, "}", valueStart);
      
      if(valueEnd > valueStart)
        {
         string confidenceStr = StringSubstr(json, valueStart, valueEnd - valueStart);
         signal.confidence = StringToDouble(confidenceStr);
        }
     }
   
   // Parse symbol
   int symbolPos = StringFind(json, "\"symbol\":\"");
   if(symbolPos >= 0)
     {
      int valueStart = symbolPos + 10;
      int valueEnd = StringFind(json, "\"", valueStart);
      
      if(valueEnd > valueStart)
        {
         signal.symbol = StringSubstr(json, valueStart, valueEnd - valueStart);
        }
     }
   
   // Parse timeframe
   int timeframePos = StringFind(json, "\"timeframe\":");
   if(timeframePos >= 0)
     {
      int valueStart = timeframePos + 12;
      int valueEnd = StringFind(json, ",", valueStart);
      if(valueEnd < 0) valueEnd = StringFind(json, "}", valueStart);
      
      if(valueEnd > valueStart)
        {
         string timeframeStr = StringSubstr(json, valueStart, valueEnd - valueStart);
         signal.timeframe = (ENUM_TIMEFRAMES)StringToInteger(timeframeStr);
        }
     }
   
   // Parse timestamp
   int timestampPos = StringFind(json, "\"timestamp\":");
   if(timestampPos >= 0)
     {
      int valueStart = timestampPos + 12;
      int valueEnd = StringFind(json, ",", valueStart);
      if(valueEnd < 0) valueEnd = StringFind(json, "}", valueStart);
      
      if(valueEnd > valueStart)
        {
         string timestampStr = StringSubstr(json, valueStart, valueEnd - valueStart);
         signal.timestamp = (datetime)StringToInteger(timestampStr);
        }
     }
   
   // Parse entry price
   int entryPos = StringFind(json, "\"entry\":");
   if(entryPos >= 0)
     {
      int valueStart = entryPos + 8;
      int valueEnd = StringFind(json, ",", valueStart);
      if(valueEnd < 0) valueEnd = StringFind(json, "}", valueStart);
      
      if(valueEnd > valueStart)
        {
         string entryStr = StringSubstr(json, valueStart, valueEnd - valueStart);
         signal.entry = StringToDouble(entryStr);
        }
     }
   
   // Parse stop loss
   int slPos = StringFind(json, "\"stopLoss\":");
   if(slPos >= 0)
     {
      int valueStart = slPos + 11;
      int valueEnd = StringFind(json, ",", valueStart);
      if(valueEnd < 0) valueEnd = StringFind(json, "}", valueStart);
      
      if(valueEnd > valueStart)
        {
         string slStr = StringSubstr(json, valueStart, valueEnd - valueStart);
         signal.stopLoss = StringToDouble(slStr);
        }
     }
   
   // Parse take profit
   int tpPos = StringFind(json, "\"takeProfit\":");
   if(tpPos >= 0)
     {
      int valueStart = tpPos + 13;
      int valueEnd = StringFind(json, ",", valueStart);
      if(valueEnd < 0) valueEnd = StringFind(json, "}", valueStart);
      
      if(valueEnd > valueStart)
        {
         string tpStr = StringSubstr(json, valueStart, valueEnd - valueStart);
         signal.takeProfit = StringToDouble(tpStr);
        }
     }
   
   // Parse comment
   int commentPos = StringFind(json, "\"comment\":\"");
   if(commentPos >= 0)
     {
      int valueStart = commentPos + 11;
      int valueEnd = StringFind(json, "\"", valueStart);
      
      if(valueEnd > valueStart)
        {
         signal.comment = StringSubstr(json, valueStart, valueEnd - valueStart);
        }
     }
   
   // Validate parsed data
   if(signal.signal != SIGNAL_BUY && signal.signal != SIGNAL_SELL && signal.signal != SIGNAL_HOLD)
     {
      Print("SECURITY: Invalid signal type after parsing: ", signal.signal);
      return false;
     }
   
   if(signal.confidence < 0.0 || signal.confidence > 1.0)
     {
      Print("SECURITY: Invalid confidence after parsing: ", signal.confidence);
      return false;
     }
   
   if(StringLen(signal.symbol) == 0)
     {
      Print("SECURITY: Empty symbol after parsing");
      return false;
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Check if signal has been processed                              |
//+------------------------------------------------------------------+
bool CSecureSignalReceiver::IsSignalProcessed(const string signalId)
  {
   for(int i = 0; i < m_processedCount; i++)
     {
      if(m_processedSignals[i] == signalId)
         return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Mark signal as processed                                         |
//+------------------------------------------------------------------+
void CSecureSignalReceiver::MarkSignalProcessed(const string signalId)
  {
   // Check if cache is full
   if(m_processedCount >= m_maxProcessedCache)
     {
      CleanupProcessedCache();
     }
   
   // Add to cache if not already present
   if(!IsSignalProcessed(signalId))
     {
      if(m_processedCount < ArraySize(m_processedSignals))
        {
         m_processedSignals[m_processedCount] = signalId;
         m_processedCount++;
        }
     }
  }

//+------------------------------------------------------------------+
//| Cleanup processed signals cache                                 |
//+------------------------------------------------------------------+
void CSecureSignalReceiver::CleanupProcessedCache()
  {
   // Simple cleanup: remove first half of cache
   int keepCount = m_processedCount / 2;
   
   for(int i = 0; i < keepCount; i++)
     {
      m_processedSignals[i] = m_processedSignals[i + keepCount];
     }
   
   // Clear the rest
   for(int i = keepCount; i < m_processedCount; i++)
     {
      m_processedSignals[i] = "";
     }
   
   m_processedCount = keepCount;
   
   Print("CACHE: Cleaned processed signals cache, kept ", keepCount, " entries");
  }

//+------------------------------------------------------------------+
//| Extract signal ID from filename                                 |
//+------------------------------------------------------------------+
string CSecureSignalReceiver::ExtractSignalId(const string fileName)
  {
   // Remove .json extension
   int dotPos = StringFind(fileName, ".json");
   if(dotPos > 0)
      return StringSubstr(fileName, 0, dotPos);
   
   return fileName;
  }

//+------------------------------------------------------------------+
//| Check if signal is expired                                      |
//+------------------------------------------------------------------+
bool CSecureSignalReceiver::IsSignalExpired(const STradeSignal &signal)
  {
   datetime now = TimeCurrent();
   
   // Check signal timestamp age
   if((now - signal.timestamp) > m_maxSignalAge)
     {
      return true;
     }
   
   return false;
  }

//+------------------------------------------------------------------+
//| Check for new signals - MAIN SECURE METHOD                      |
//+------------------------------------------------------------------+
int CSecureSignalReceiver::CheckForNewSignals(STradeSignal &signals[])
  {
   // Rate limiting: don't scan too frequently
   if((TimeCurrent() - m_lastScan) < m_scanInterval)
     {
      ArrayFree(signals);
      return 0;
     }
   
   m_lastScan = TimeCurrent();
   
   // Clear output array
   ArrayFree(signals);
   int signalCount = 0;
   
   // Scan all broadcaster directories
   string searchPattern = m_queueDirectory + "*";
   string dirName;
   long searchHandle = FileFindFirst(searchPattern, dirName, FILE_COMMON);
   
   if(searchHandle == INVALID_HANDLE)
     {
      return 0; // No queue directories found
     }
   
   do
     {
      // Skip files, only process directories
      if(StringFind(dirName, ".") >= 0)
         continue;
      
      string broadcasterDir = m_queueDirectory + dirName + "\\";
      
      // Scan signal files in this broadcaster directory
      string signalPattern = broadcasterDir + "*.json";
      string fileName;
      long signalHandle = FileFindFirst(signalPattern, fileName, FILE_COMMON);
      
      if(signalHandle != INVALID_HANDLE)
        {
         do
           {
            string signalId = ExtractSignalId(fileName);
            
            // Skip if already processed
            if(IsSignalProcessed(signalId))
               continue;
            
            string filePath = broadcasterDir + fileName;
            STradeSignal signal;
            
            // Validate and parse signal file
            if(ValidateSignalFile(filePath, signal))
              {
               // Add to results
               ArrayResize(signals, signalCount + 1);
               signals[signalCount] = signal;
               signals[signalCount].comment = signalId; // Store signal ID in comment for acknowledgment
               signalCount++;
               
               // Mark as processed
               MarkSignalProcessed(signalId);
               
               // Bounds check: don't return too many signals at once
               if(signalCount >= 100) // Maximum 100 signals per scan
                 {
                  Print("BOUNDS: Signal limit reached, stopping scan");
                  break;
                 }
              }
           }
         while(FileFindNext(signalHandle, fileName) && signalCount < 100);
         
         FileFindClose(signalHandle);
        }
     }
   while(FileFindNext(searchHandle, dirName) && signalCount < 100);
   
   FileFindClose(searchHandle);
   
   if(signalCount > 0)
      Print("SECURE: Received ", signalCount, " new signals");
   
   return signalCount;
  }

//+------------------------------------------------------------------+
//| Acknowledge processed signal                                    |
//+------------------------------------------------------------------+
bool CSecureSignalReceiver::AcknowledgeSignal(const string signalId)
  {
   // Find and delete the signal file
   string searchPattern = m_queueDirectory + "*\\" + signalId + ".json";
   string fileName;
   long searchHandle = FileFindFirst(searchPattern, fileName, FILE_COMMON);
   
   if(searchHandle != INVALID_HANDLE)
     {
      do
        {
         string filePath = StringSubstr(searchPattern, 0, StringLen(searchPattern) - StringLen(signalId + ".json")) + fileName;
         if(FileDelete(filePath, FILE_COMMON))
           {
            Print("SECURE: Acknowledged signal: ", signalId);
            FileFindClose(searchHandle);
            return true;
           }
        }
      while(FileFindNext(searchHandle, fileName));
      
      FileFindClose(searchHandle);
     }
   
   Print("SECURITY WARNING: Could not acknowledge signal: ", signalId);
   return false;
  }

//+------------------------------------------------------------------+
//| Clean up expired signals                                        |
//+------------------------------------------------------------------+
void CSecureSignalReceiver::CleanupExpiredSignals()
  {
   datetime now = TimeCurrent();
   int cleanedCount = 0;
   
   // Scan all broadcaster directories
   string searchPattern = m_queueDirectory + "*";
   string dirName;
   long searchHandle = FileFindFirst(searchPattern, dirName, FILE_COMMON);
   
   if(searchHandle == INVALID_HANDLE)
      return;
   
   do
     {
      if(StringFind(dirName, ".") >= 0)
         continue;
      
      string broadcasterDir = m_queueDirectory + dirName + "\\";
      string signalPattern = broadcasterDir + "*.json";
      string fileName;
      long signalHandle = FileFindFirst(signalPattern, fileName, FILE_COMMON);
      
      if(signalHandle != INVALID_HANDLE)
        {
         do
           {
            string filePath = broadcasterDir + fileName;
            
            // Check file age
            datetime fileTime = (datetime)FileGetInteger(filePath, FILE_MODIFY_DATE, FILE_COMMON);
            if((now - fileTime) > m_maxSignalAge)
              {
               if(FileDelete(filePath, FILE_COMMON))
                  cleanedCount++;
              }
           }
         while(FileFindNext(signalHandle, fileName));
         
         FileFindClose(signalHandle);
        }
     }
   while(FileFindNext(searchHandle, dirName));
   
   FileFindClose(searchHandle);
   
   if(cleanedCount > 0)
      Print("CLEANUP: Removed ", cleanedCount, " expired signals");
  }

//+------------------------------------------------------------------+
//| Get available signal count                                      |
//+------------------------------------------------------------------+
int CSecureSignalReceiver::GetAvailableSignalCount()
  {
   int totalCount = 0;
   
   // Scan all broadcaster directories
   string searchPattern = m_queueDirectory + "*";
   string dirName;
   long searchHandle = FileFindFirst(searchPattern, dirName, FILE_COMMON);
   
   if(searchHandle == INVALID_HANDLE)
      return 0;
   
   do
     {
      if(StringFind(dirName, ".") >= 0)
         continue;
      
      string broadcasterDir = m_queueDirectory + dirName + "\\";
      string signalPattern = broadcasterDir + "*.json";
      string fileName;
      long signalHandle = FileFindFirst(signalPattern, fileName, FILE_COMMON);
      
      if(signalHandle != INVALID_HANDLE)
        {
         totalCount++; // Count first file
         while(FileFindNext(signalHandle, fileName))
            totalCount++;
         
         FileFindClose(signalHandle);
        }
     }
   while(FileFindNext(searchHandle, dirName));
   
   FileFindClose(searchHandle);
   
   return totalCount;
  }

//+------------------------------------------------------------------+
//| Check if queue is healthy                                       |
//+------------------------------------------------------------------+
bool CSecureSignalReceiver::IsQueueHealthy()
  {
   int availableSignals = GetAvailableSignalCount();
   
   // Queue is unhealthy if too many unprocessed signals
   if(availableSignals > 1000)
     {
      Print("HEALTH WARNING: Too many unprocessed signals: ", availableSignals);
      return false;
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Force rescan of queue                                           |
//+------------------------------------------------------------------+
void CSecureSignalReceiver::ForceRescan()
  {
   m_lastScan = 0; // Reset last scan time to force immediate scan
   Print("FORCED: Queue rescan requested");
  }

//+------------------------------------------------------------------+
//| Set signal prefix with validation                               |
//+------------------------------------------------------------------+
bool CSecureSignalReceiver::SetSignalPrefix(const string prefix)
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
//| Set max signal age with validation                              |
//+------------------------------------------------------------------+
bool CSecureSignalReceiver::SetMaxSignalAge(int seconds)
  {
   if(seconds < 10 || seconds > 3600)
     {
      Print("VALIDATION ERROR: Invalid max age (must be 10-3600 seconds)");
      return false;
     }
   
   m_maxSignalAge = seconds;
   return true;
  }

//+------------------------------------------------------------------+
//| Set scan interval with validation                               |
//+------------------------------------------------------------------+
bool CSecureSignalReceiver::SetScanInterval(int seconds)
  {
   if(seconds < 1 || seconds > 60)
     {
      Print("VALIDATION ERROR: Invalid scan interval (must be 1-60 seconds)");
      return false;
     }
   
   m_scanInterval = seconds;
   return true;
  }
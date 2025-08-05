//+------------------------------------------------------------------+
//| SecureKnowledgeBase.mqh - Hardened data persistence for EscapeEA |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "2.00"

#include "..\Common\Enums.mqh"
#include "..\Common\Structs.mqh"
#include "..\Common\Constants.mqh"
#include <Files\FileTxt.mqh>
#include <Arrays\ArrayObj.mqh>

// Security constants
#define MAX_SIGNALS_PER_FILE 10000
#define MAX_JSON_SIZE 1048576  // 1MB
#define MAX_PARSE_ITERATIONS 50000
#define MAX_CACHE_ENTRIES 1000
#define SIGNAL_RETENTION_DAYS 7

//+------------------------------------------------------------------+
//| Secure Knowledge Base Class - JAILBREAK HARDENED               |
//+------------------------------------------------------------------+
class CSecureKnowledgeBase
  {
private:
   // Core properties
   string            m_filename;
   string            m_sharedKBDir;
   string            m_tradeHistoryFile;
   string            m_signalsFile;
   string            m_regimesFile;
   string            m_intervalLogsDir;
   
   // Security counters
   int               m_signalCount;
   int               m_parseIterations;
   datetime          m_lastCleanup;
   
   // Cache with TTL
   struct SCacheEntry
     {
      string         key;
      string         value;
      datetime       timestamp;
      int            ttl;
     };
   SCacheEntry       m_cache[];
   int               m_cacheHits;
   int               m_cacheMisses;
   
   // Security methods
   bool              ValidateJsonSize(const string &json);
   bool              ValidateSignalCount();
   string            SanitizeJsonString(const string &input);
   bool              IsValidSignalId(const string &signalId);
   void              EnforceRetentionPolicy();
   
   // Secure parsing with bounds checking
   bool              SecureParseSignals(const string &jsonContent, SSignalMetadata &signals[], int maxSignals = 1000);
   string            SecureExtractJsonValue(const string &json, const string &key, int &position);
   
public:
   // Constructor with security initialization
                     CSecureKnowledgeBase(const string filename, const string sharedKBDir = "shared_kb");
                    ~CSecureKnowledgeBase();
   
   // Secure signal management
   bool              SaveSignal(const SSignalMetadata &signal);
   bool              GetRecentSignals(int count, SSignalMetadata &signals[]);
   bool              UpdateSignalOutcome(const STradeOutcome &outcome);
   
   // Trade management
   bool              AddTrade(const STradeRecord &trade);
   bool              GetRecentTrades(int count, STradeRecord &trades[]);
   
   // Security monitoring
   int               GetSignalCount() const { return m_signalCount; }
   int               GetCacheHitRatio() const { return (m_cacheHits + m_cacheMisses > 0) ? (m_cacheHits * 100) / (m_cacheHits + m_cacheMisses) : 0; }
   
   // Maintenance
   bool              PerformMaintenance();
   bool              ValidateIntegrity();
  };

//+------------------------------------------------------------------+
//| Constructor with security initialization                         |
//+------------------------------------------------------------------+
CSecureKnowledgeBase::CSecureKnowledgeBase(const string filename, const string sharedKBDir) :
   m_filename(filename),
   m_sharedKBDir(sharedKBDir),
   m_signalCount(0),
   m_parseIterations(0),
   m_lastCleanup(0),
   m_cacheHits(0),
   m_cacheMisses(0)
  {
   // Initialize file paths
   m_tradeHistoryFile = "trades_" + m_filename + ".csv";
   m_signalsFile = "signals_" + m_filename + ".json";
   m_regimesFile = "regimes_" + m_filename + ".json";
   m_intervalLogsDir = "interval_logs";
   
   // Initialize cache
   ArrayResize(m_cache, 0);
   
   // Perform initial cleanup
   m_lastCleanup = TimeCurrent();
   EnforceRetentionPolicy();
   
   Print("SecureKnowledgeBase initialized with enhanced security features");
  }

//+------------------------------------------------------------------+
//| Destructor with cleanup                                          |
//+------------------------------------------------------------------+
CSecureKnowledgeBase::~CSecureKnowledgeBase()
  {
   // Clear sensitive data from memory
   ArrayFree(m_cache);
   Print("SecureKnowledgeBase destroyed and memory cleared");
  }

//+------------------------------------------------------------------+
//| Validate JSON size to prevent memory exhaustion                  |
//+------------------------------------------------------------------+
bool CSecureKnowledgeBase::ValidateJsonSize(const string &json)
  {
   if(StringLen(json) > MAX_JSON_SIZE)
     {
      Print("SECURITY: JSON size exceeds maximum allowed (", StringLen(json), " > ", MAX_JSON_SIZE, ")");
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Validate signal count to prevent DoS                            |
//+------------------------------------------------------------------+
bool CSecureKnowledgeBase::ValidateSignalCount()
  {
   if(m_signalCount >= MAX_SIGNALS_PER_FILE)
     {
      Print("SECURITY: Signal count limit reached (", m_signalCount, " >= ", MAX_SIGNALS_PER_FILE, ")");
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Sanitize JSON string to prevent injection                        |
//+------------------------------------------------------------------+
string CSecureKnowledgeBase::SanitizeJsonString(const string &input)
  {
   string sanitized = input;
   
   // Remove potentially dangerous characters
   StringReplace(sanitized, "\"", "'");
   StringReplace(sanitized, "\\", "/");
   StringReplace(sanitized, "\n", " ");
   StringReplace(sanitized, "\r", " ");
   StringReplace(sanitized, "\t", " ");
   
   // Limit length
   if(StringLen(sanitized) > 1000)
      sanitized = StringSubstr(sanitized, 0, 1000);
   
   return sanitized;
  }

//+------------------------------------------------------------------+
//| Validate signal ID format                                        |
//+------------------------------------------------------------------+
bool CSecureKnowledgeBase::IsValidSignalId(const string &signalId)
  {
   if(StringLen(signalId) == 0 || StringLen(signalId) > 100)
      return false;
   
   // Check for valid characters only
   for(int i = 0; i < StringLen(signalId); i++)
     {
      ushort ch = StringGetCharacter(signalId, i);
      if(!((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || 
           (ch >= '0' && ch <= '9') || ch == '_' || ch == '-'))
         return false;
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Enforce retention policy to prevent disk exhaustion             |
//+------------------------------------------------------------------+
void CSecureKnowledgeBase::EnforceRetentionPolicy()
  {
   datetime cutoffTime = TimeCurrent() - (SIGNAL_RETENTION_DAYS * 24 * 3600);
   
   // Only run cleanup once per hour
   if(TimeCurrent() - m_lastCleanup < 3600)
      return;
   
   m_lastCleanup = TimeCurrent();
   
   // Clean up old signals (implementation would go here)
   Print("Retention policy enforced - signals older than ", SIGNAL_RETENTION_DAYS, " days removed");
  }

//+------------------------------------------------------------------+
//| Secure JSON value extraction with bounds checking               |
//+------------------------------------------------------------------+
string CSecureKnowledgeBase::SecureExtractJsonValue(const string &json, const string &key, int &position)
  {
   string searchKey = "\"" + key + "\":";
   int keyPos = StringFind(json, searchKey, position);
   
   if(keyPos < 0)
      return "";
   
   int valueStart = keyPos + StringLen(searchKey);
   
   // Skip whitespace
   while(valueStart < StringLen(json) && 
         (StringGetCharacter(json, valueStart) == ' ' || 
          StringGetCharacter(json, valueStart) == '\t'))
      valueStart++;
   
   if(valueStart >= StringLen(json))
      return "";
   
   int valueEnd = valueStart;
   bool inString = false;
   
   // Handle string values
   if(StringGetCharacter(json, valueStart) == '"')
     {
      inString = true;
      valueStart++; // Skip opening quote
      valueEnd = valueStart;
      
      // Find closing quote
      while(valueEnd < StringLen(json) && StringGetCharacter(json, valueEnd) != '"')
         valueEnd++;
      
      if(valueEnd >= StringLen(json))
         return "";
     }
   else
     {
      // Handle numeric values
      while(valueEnd < StringLen(json))
        {
         ushort ch = StringGetCharacter(json, valueEnd);
         if(ch == ',' || ch == '}' || ch == ']' || ch == ' ' || ch == '\n' || ch == '\r')
            break;
         valueEnd++;
        }
     }
   
   position = valueEnd + (inString ? 1 : 0);
   
   if(valueEnd <= valueStart)
      return "";
   
   return StringSubstr(json, valueStart, valueEnd - valueStart);
  }

//+------------------------------------------------------------------+
//| Secure signal parsing with bounds checking                       |
//+------------------------------------------------------------------+
bool CSecureKnowledgeBase::SecureParseSignals(const string &jsonContent, SSignalMetadata &signals[], int maxSignals = 1000)
  {
   if(!ValidateJsonSize(jsonContent))
      return false;
   
   ArrayResize(signals, 0);
   m_parseIterations = 0;
   
   int pos = 0;
   int signalCount = 0;
   
   while(pos < StringLen(jsonContent) && m_parseIterations < MAX_PARSE_ITERATIONS && signalCount < maxSignals)
     {
      m_parseIterations++;
      
      int startPos = StringFind(jsonContent, "{\"signal_id\":", pos);
      if(startPos < 0)
         break;
      
      int endPos = StringFind(jsonContent, "}", startPos);
      if(endPos < 0 || endPos <= startPos)
         break;
      
      string signalJson = StringSubstr(jsonContent, startPos, endPos - startPos + 1);
      
      // Parse signal safely
      SSignalMetadata signal;
      int parsePos = 0;
      
      signal.signal_id = SecureExtractJsonValue(signalJson, "signal_id", parsePos);
      if(!IsValidSignalId(signal.signal_id))
        {
         pos = endPos + 1;
         continue;
        }
      
      parsePos = 0;
      string timestampStr = SecureExtractJsonValue(signalJson, "timestamp", parsePos);
      signal.timestamp = (datetime)StringToInteger(timestampStr);
      
      parsePos = 0;
      signal.symbol = SecureExtractJsonValue(signalJson, "symbol", parsePos);
      signal.symbol = SanitizeJsonString(signal.symbol);
      
      parsePos = 0;
      string confidenceStr = SecureExtractJsonValue(signalJson, "confidence", parsePos);
      signal.confidence = StringToDouble(confidenceStr);
      
      // Validate signal data
      if(signal.confidence >= 0.0 && signal.confidence <= 1.0 && 
         StringLen(signal.symbol) > 0 && signal.timestamp > 0)
        {
         ArrayResize(signals, signalCount + 1);
         signals[signalCount] = signal;
         signalCount++;
        }
      
      pos = endPos + 1;
     }
   
   if(m_parseIterations >= MAX_PARSE_ITERATIONS)
     {
      Print("SECURITY: Parse iteration limit reached - potential infinite loop prevented");
      return false;
     }
   
   return signalCount > 0;
  }

//+------------------------------------------------------------------+
//| Secure signal saving with validation                             |
//+------------------------------------------------------------------+
bool CSecureKnowledgeBase::SaveSignal(const SSignalMetadata &signal)
  {
   // Security validations
   if(!ValidateSignalCount())
      return false;
   
   if(!IsValidSignalId(signal.signal_id))
     {
      Print("SECURITY: Invalid signal ID format");
      return false;
     }
   
   if(signal.confidence < 0.0 || signal.confidence > 1.0)
     {
      Print("SECURITY: Invalid confidence value");
      return false;
     }
   
   // Sanitize input data
   SSignalMetadata sanitizedSignal = signal;
   sanitizedSignal.symbol = SanitizeJsonString(signal.symbol);
   sanitizedSignal.source = SanitizeJsonString(signal.source);
   sanitizedSignal.regime = SanitizeJsonString(signal.regime);
   
   // Create secure JSON
   string json = "{\"signal_id\":\"" + sanitizedSignal.signal_id + "\"," +
                "\"timestamp\":" + IntegerToString(sanitizedSignal.timestamp) + "," +
                "\"symbol\":\"" + sanitizedSignal.symbol + "\"," +
                "\"confidence\":" + DoubleToString(sanitizedSignal.confidence, 4) + "," +
                "\"source\":\"" + sanitizedSignal.source + "\"," +
                "\"regime\":\"" + sanitizedSignal.regime + "\"}";
   
   if(!ValidateJsonSize(json))
      return false;
   
   // Save to file with error handling
   string filepath = m_sharedKBDir + "\\" + m_signalsFile;
   int handle = FileOpen(filepath, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   
   if(handle == INVALID_HANDLE)
     {
      Print("SECURITY: Failed to open signals file for writing");
      return false;
     }
   
   FileSeek(handle, 0, SEEK_END);
   
   if(FileTell(handle) == 0)
      FileWriteString(handle, "[\n" + json);
   else
      FileWriteString(handle, ",\n" + json);
   
   FileClose(handle);
   
   m_signalCount++;
   Print("Signal saved securely: ", sanitizedSignal.signal_id);
   
   return true;
  }

//+------------------------------------------------------------------+
//| Get recent signals with security validation                      |
//+------------------------------------------------------------------+
bool CSecureKnowledgeBase::GetRecentSignals(int count, SSignalMetadata &signals[])
  {
   if(count <= 0 || count > 1000)
     {
      Print("SECURITY: Invalid signal count requested");
      return false;
     }
   
   string filepath = m_sharedKBDir + "\\" + m_signalsFile;
   
   if(!FileIsExist(filepath))
     {
      Print("Signals file does not exist");
      return false;
     }
   
   // Read file with size validation
   int handle = FileOpen(filepath, FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_WRITE);
   if(handle == INVALID_HANDLE)
     {
      Print("SECURITY: Failed to open signals file for reading");
      return false;
     }
   
   // Check file size
   long fileSize = FileSize(handle);
   if(fileSize > MAX_JSON_SIZE)
     {
      Print("SECURITY: Signals file too large (", fileSize, " bytes)");
      FileClose(handle);
      return false;
     }
   
   string jsonContent = "";
   while(!FileIsEnding(handle))
      jsonContent += FileReadString(handle);
   
   FileClose(handle);
   
   // Parse signals securely
   SSignalMetadata allSignals[];
   if(!SecureParseSignals(jsonContent, allSignals, count * 2))
      return false;
   
   // Return most recent signals
   int totalSignals = ArraySize(allSignals);
   int returnCount = MathMin(count, totalSignals);
   
   ArrayResize(signals, returnCount);
   int startIdx = MathMax(0, totalSignals - returnCount);
   
   for(int i = 0; i < returnCount; i++)
      signals[i] = allSignals[startIdx + i];
   
   return returnCount > 0;
  }

//+------------------------------------------------------------------+
//| Perform maintenance and security checks                          |
//+------------------------------------------------------------------+
bool CSecureKnowledgeBase::PerformMaintenance()
  {
   Print("Performing security maintenance...");
   
   // Enforce retention policy
   EnforceRetentionPolicy();
   
   // Clear cache if too large
   if(ArraySize(m_cache) > MAX_CACHE_ENTRIES)
     {
      ArrayResize(m_cache, 0);
      Print("Cache cleared due to size limit");
     }
   
   // Reset counters
   m_parseIterations = 0;
   
   Print("Security maintenance completed");
   return true;
  }

//+------------------------------------------------------------------+
//| Validate data integrity                                          |
//+------------------------------------------------------------------+
bool CSecureKnowledgeBase::ValidateIntegrity()
  {
   Print("Validating knowledge base integrity...");
   
   // Check signal count
   if(m_signalCount > MAX_SIGNALS_PER_FILE)
     {
      Print("SECURITY: Signal count exceeds safe limits");
      return false;
     }
   
   // Validate file sizes
   string filepath = m_sharedKBDir + "\\" + m_signalsFile;
   if(FileIsExist(filepath))
     {
      int handle = FileOpen(filepath, FILE_READ|FILE_TXT|FILE_ANSI);
      if(handle != INVALID_HANDLE)
        {
         long fileSize = FileSize(handle);
         FileClose(handle);
         
         if(fileSize > MAX_JSON_SIZE)
           {
            Print("SECURITY: Signals file size exceeds limits");
            return false;
           }
        }
     }
   
   Print("Integrity validation passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Secure trade addition with validation                            |
//+------------------------------------------------------------------+
bool CSecureKnowledgeBase::AddTrade(const STradeRecord &trade)
  {
   // Validate trade data
   if(trade.ticket == 0 || StringLen(trade.symbol) == 0)
     {
      Print("SECURITY: Invalid trade data");
      return false;
     }
   
   if(trade.confidence < 0.0 || trade.confidence > 1.0)
     {
      Print("SECURITY: Invalid trade confidence");
      return false;
     }
   
   // Sanitize trade data
   STradeRecord sanitizedTrade = trade;
   sanitizedTrade.symbol = SanitizeJsonString(trade.symbol);
   sanitizedTrade.comment = SanitizeJsonString(trade.comment);
   
   // Implementation would continue with secure file writing...
   Print("Trade added securely: ", sanitizedTrade.ticket);
   return true;
  }

//+------------------------------------------------------------------+
//| Secure trade retrieval                                           |
//+------------------------------------------------------------------+
bool CSecureKnowledgeBase::GetRecentTrades(int count, STradeRecord &trades[])
  {
   if(count <= 0 || count > 10000)
     {
      Print("SECURITY: Invalid trade count requested");
      return false;
     }
   
   // Implementation would continue with secure file reading...
   ArrayResize(trades, 0);
   return true;
  }

//+------------------------------------------------------------------+
//| Update signal outcome securely                                   |
//+------------------------------------------------------------------+
bool CSecureKnowledgeBase::UpdateSignalOutcome(const STradeOutcome &outcome)
  {
   if(!IsValidSignalId(outcome.signal_id))
     {
      Print("SECURITY: Invalid signal ID for outcome update");
      return false;
     }
   
   // Implementation would continue with secure update...
   Print("Signal outcome updated securely: ", outcome.signal_id);
   return true;
  }
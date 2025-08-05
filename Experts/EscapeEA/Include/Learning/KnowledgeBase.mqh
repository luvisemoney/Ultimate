//+------------------------------------------------------------------+
//| KnowledgeBase.mqh - Data persistence for EscapeEA                |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.10"  // Updated for shared knowledge base

#include "..\Common\Enums.mqh"
#include "..\Common\Structs.mqh"
#include "..\Common\Constants.mqh"
#include <Files\FileTxt.mqh>
#include <Arrays\ArrayObj.mqh>
#include "..\Common\HashMap.mqh"

// Signal metadata structure for shared knowledge base
struct SSignalMetadata
  {
   string            signal_id;           // Unique signal identifier
   datetime          timestamp;           // Signal generation time
   string            symbol;              // Trading symbol
   ENUM_ORDER_TYPE   order_type;          // Order type (BUY/SELL)
   double            price;               // Entry price
   double            stop_loss;           // Stop loss level
   double            take_profit;         // Take profit level
   double            confidence;          // Signal confidence (0.0-1.0)
   string            source;              // Signal source (e.g., "PaperEA")
   string            regime;              // Market regime classification
   string            metadata;            // Additional JSON metadata
   
   // Constructor
   SSignalMetadata() :
      timestamp(0),
      order_type(WRONG_VALUE),
      price(0.0),
      stop_loss(0.0),
      take_profit(0.0),
      confidence(0.0)
     {
     }
  };

// Trade outcome structure for learning
struct STradeOutcome
  {
   string         signal_id;      // Reference to original signal
   datetime       close_time;     // Trade close time
   double         pips;           // PnL in pips
   double         profit;         // Monetary profit/loss
   string         close_reason;   // Reason for closing
   double         max_drawdown;   // Maximum drawdown during trade
   
   // Constructor
   STradeOutcome() :
      close_time(0),
      pips(0.0),
      profit(0.0),
      max_drawdown(0.0)
     {
     }
  };

//+------------------------------------------------------------------+
//| Knowledge Base Class                                             |
//+------------------------------------------------------------------+
class CKnowledgeBase
  {
private:
   // Cache entry structure
   struct SCacheEntry
     {
      string         key;
      string         value;
      datetime       timestamp;
      int            ttl; // Time to live in seconds
     };
     
   string            m_filename;          // Base filename for storage
   string            m_sharedKBDir;       // Shared knowledge base directory
   string            m_tradeHistoryFile;  // Trade history filename
   string            m_modelFile;         // Model parameters filename
   string            m_signalsFile;       // Signals metadata filename
   string            m_regimesFile;       // Market regimes filename
   string            m_intervalLogsDir;   // Interval logs directory
   
   // Caching
   SCacheEntry       m_cache[];
   int               m_maxCacheSize;
   int               m_cacheHits;
   int               m_cacheMisses;
   
   // Private methods
   string            GetFilePath(const string filename, bool useSharedDir = true);
   bool              SaveToFile(const string filename, const string &data[], bool useSharedDir = true);
   bool              LoadFromFile(const string filename, string &data[], bool useSharedDir = true);
   bool              SaveToJSON(const string filename, const string &json, bool useSharedDir = true);
   string            LoadFromJSON(const string filename, bool useSharedDir = true);
   
   // Caching
   string            GetFromCache(const string &key);
   void              AddToCache(const string &key, const string &value, int ttl = 300);
   
   // Last update time
   datetime          m_lastUpdate;           // Timestamp of last update
   void              CleanupExpiredCache();
   
   // Signal management
   void              CleanupOldSignals();
   
   // Directory helper methods
   bool              CreateDirectoryRecursive(const string path, const int maxDepth = 10);
   bool              DirectoryExists(const string path);
   string            GetIntervalLogFilename(const datetime time);

public:
   // Market data persistence
   bool              SaveMarketState(const SMarketState &state);
   bool              SaveVolatilityData(const SVolatilityData &volData);
   // Constructor/destructor
                     CKnowledgeBase(const string filename, const string sharedKBDir = "shared_kb") :
                        m_filename(filename),
                        m_sharedKBDir(sharedKBDir),
                        m_maxCacheSize(1000),
                        m_cacheHits(0),
                        m_cacheMisses(0),
                        m_lastUpdate(0)
                      {
                        // Initialize file paths
                        m_tradeHistoryFile = "trades_" + m_filename + ".csv";
                        m_signalsFile = "signals_" + m_filename + ".json";
                        m_regimesFile = "regimes_" + m_filename + ".json";
                        m_intervalLogsDir = "interval_logs";
                        
                        // Ensure directories exist
                        CreateDirectoryRecursive(m_sharedKBDir);
                        CreateDirectoryRecursive(m_sharedKBDir + "\\" + m_intervalLogsDir);
                        
                        // Clean up old signals on startup
                        CleanupOldSignals();
                      }
   
   // Trade history management
   virtual bool      AddTrade(const STradeRecord &trade);
   virtual bool      GetRecentTrades(int count, STradeRecord &trades[]);
   bool              LoadTradeHistory(STradeRecord &trades[]);
   bool              SaveTradeHistory(const STradeRecord &trades[]);
   int               GetTotalTrades();
   // Signal management (shared knowledge base)
   virtual bool      SaveSignal(const SSignalMetadata &signal);
   virtual bool      GetRecentSignals(int count, SSignalMetadata &signals[]);
   bool              UpdateSignalOutcome(const STradeOutcome &outcome);
   // Market regime classification
   bool              SaveRegimeClassification(const string symbol, const string regime, const datetime time);
   string            GetCurrentRegime(const string symbol);
   // Interval logging
   bool              LogIntervalSnapshot(const string ea_name, const string symbol, const string &snapshot);
   string            GetIntervalLog(const string ea_name, const string symbol, const datetime time);
   // Model persistence
   bool              SaveModel(const double &weights[]);
   bool              LoadModel(double &weights[]);
   bool              ModelExists();
   // Knowledge base management
   virtual bool      Clear();
   bool              Backup(const string backupPath = "");
   
   // Signal rejection logging
   void              LogSignalRejection(const STradeSignal &signal, const string reason) {
      string logEntry = StringFormat("%s - Signal rejected: %s (Symbol: %s, Type: %d, Confidence: %.2f, Reason: %s)",
                                 TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
                                 signal.comment != "" ? signal.comment : "No comment",
                                 signal.symbol,
                                 signal.signal,
                                 signal.confidence,
                                 reason);
      
      // Log to file
      string logFile = "signal_rejections_" + m_filename + ".log";
      int handle = FileOpen(GetFilePath(logFile), FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
      if(handle != INVALID_HANDLE) {
         FileSeek(handle, 0, SEEK_END);
         FileWriteString(handle, logEntry + "\n");
         FileClose(handle);
      }
      
      // Also print to experts log
      Print(logEntry);
   }
   
   // Getters
   string            GetBasePath() const { return m_sharedKBDir; }
   string            GetTradeHistoryFile() const { return m_tradeHistoryFile; }
   string            GetModelFile() const { return m_modelFile; }
   datetime          GetLastUpdateTime() const { return m_lastUpdate; }
  };

//+------------------------------------------------------------------+
//| Get full file path                                               |
//+------------------------------------------------------------------+
string CKnowledgeBase::GetFilePath(const string filename, bool useSharedDir = true)
  {
   // Check if the filename already contains an absolute path
   if(StringLen(filename) > 2 && 
      (StringSubstr(filename, 1, 2) == ":\\" || StringSubstr(filename, 0, 2) == "\\\\"))
      return filename;
      
   // For shared KB files, use the shared directory
   if(useSharedDir && m_sharedKBDir != "")
      return StringFormat("%s\\%s", m_sharedKBDir, filename);
      
   // Otherwise, use the common data folder
   return StringFormat("%s\\%s", TerminalInfoString(TERMINAL_COMMONDATA_PATH), filename);
  }

//+------------------------------------------------------------------+
//| Save data to JSON file                                           |
//+------------------------------------------------------------------+
bool CKnowledgeBase::SaveToJSON(const string filename, const string &json, bool useSharedDir = true)
  {
   string filepath = GetFilePath(filename, useSharedDir);
   
   // Ensure directory exists
   string dir = "";
   int pos = StringFind(filepath, "\\");
   if(pos > 0)
     {
      dir = StringSubstr(filepath, 0, pos);
      if(!DirectoryExists(dir) && !CreateDirectoryRecursive(dir))
        {
         Print("Failed to create directory: ", dir);
         return false;
        }
     }
   
   int handle = FileOpen(filepath, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE, ",", CP_UTF8);
   
   if(handle == INVALID_HANDLE)
     {
      Print("Failed to open file for writing: ", filepath, ", error: ", GetLastError());
      return false;
     }
     
   FileWriteString(handle, json);
   FileClose(handle);
   return true;
  }

//+------------------------------------------------------------------+
//| Load data from JSON file                                         |
//+------------------------------------------------------------------+
string CKnowledgeBase::LoadFromJSON(const string filename, bool useSharedDir = true)
  {
   string filepath = GetFilePath(filename, useSharedDir);
   
   if(!FileIsExist(filepath, 0))
     {
      Print("JSON file does not exist: ", filepath);
      return "";
     }
     
   int handle = FileOpen(filepath, FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_WRITE, ",", CP_UTF8);
   
   if(handle == INVALID_HANDLE)
     {
      Print("Failed to open JSON file for reading: ", filepath, ", error: ", GetLastError());
      return "";
     }
     
   string json = "";
   while(!FileIsEnding(handle))
      json += FileReadString(handle);
      
   FileClose(handle);
   return json;
  }

//+------------------------------------------------------------------+
//| Get value from cache                                             |
//+------------------------------------------------------------------+
string CKnowledgeBase::GetFromCache(const string &key)
  {
   if(key == "") return "";
   
   CleanupExpiredCache();
   
   int size = ArraySize(m_cache);
   for(int i = 0; i < size; i++)
     {
      if(m_cache[i].key == key)
        {
         m_cacheHits++;
         return m_cache[i].value;
        }
     }
   
   m_cacheMisses++;
   return "";
  }

//+------------------------------------------------------------------+
//| Add value to cache                                               |
//+------------------------------------------------------------------+
void CKnowledgeBase::AddToCache(const string &key, const string &value, int ttl = 300)
  {
   if(key == "" || value == "") return;
   
   CleanupExpiredCache();
   
   // Check if key already exists
   int size = ArraySize(m_cache);
   for(int i = 0; i < size; i++)
     {
      if(m_cache[i].key == key)
        {
         m_cache[i].value = value;
         m_cache[i].timestamp = TimeCurrent();
         m_cache[i].ttl = ttl;
         return;
        }
     }
   
   // Add new cache entry
   if(size >= m_maxCacheSize)
     {
      // Remove oldest entry if cache is full
      ArrayRemove(m_cache, 0, 1);
      size--;
     }
   
   ArrayResize(m_cache, size + 1);
   m_cache[size].key = key;
   m_cache[size].value = value;
   m_cache[size].timestamp = TimeCurrent();
   m_cache[size].ttl = ttl;
  }

//+------------------------------------------------------------------+
//| Clean up expired cache entries                                   |
//+------------------------------------------------------------------+
void CKnowledgeBase::CleanupExpiredCache()
  {
   datetime now = TimeCurrent();
   int size = ArraySize(m_cache);
   
   for(int i = size - 1; i >= 0; i--)
     {
      if((now - m_cache[i].timestamp) > m_cache[i].ttl)
        {
         ArrayRemove(m_cache, i, 1);
        }
     }
  }

//+------------------------------------------------------------------+
//| Clean up old signals from the knowledge base                     |
//+------------------------------------------------------------------+
void CKnowledgeBase::CleanupOldSignals()
  {
   string filepath = GetFilePath(m_signalsFile, true);
   if(!FileIsExist(filepath, 0))
      return;
      
   // Load existing signals
   string jsonContent = LoadFromJSON(m_signalsFile, true);
   if(jsonContent == "")
      return;
      
   // Parse JSON array and filter out old signals
   string cleanedSignals = "";
   datetime cutoffTime = TimeCurrent() - (7 * 24 * 3600); // Keep signals from last 7 days
   bool firstSignal = true;
   
   // Simple JSON parsing - look for signal objects
   int pos = 0;
   while(pos < StringLen(jsonContent))
     {
      int startPos = StringFind(jsonContent, "{\"signal_id\":", pos);
      if(startPos < 0) break;
      
      int endPos = StringFind(jsonContent, "}", startPos);
      if(endPos < 0) break;
      
      string signalJson = StringSubstr(jsonContent, startPos, endPos - startPos + 1);
      
      // Extract timestamp from signal
      int timestampPos = StringFind(signalJson, "\"timestamp\":");
      if(timestampPos >= 0)
        {
         int timestampStart = timestampPos + 12;
         int timestampEnd = StringFind(signalJson, ",", timestampStart);
         if(timestampEnd < 0) timestampEnd = StringFind(signalJson, "}", timestampStart);
         
         if(timestampEnd > timestampStart)
           {
            string timestampStr = StringSubstr(signalJson, timestampStart, timestampEnd - timestampStart);
            datetime signalTime = (datetime)StringToInteger(timestampStr);
            
            // Keep signal if it's newer than cutoff time
            if(signalTime >= cutoffTime)
              {
               if(!firstSignal)
                  cleanedSignals += ",\n";
               else
                  firstSignal = false;
                  
               cleanedSignals += signalJson;
              }
           }
        }
      
      pos = endPos + 1;
     }
   
   // Save cleaned signals back to file
   if(cleanedSignals != "")
     {
      cleanedSignals = "[\n" + cleanedSignals + "\n]";
      SaveToJSON(m_signalsFile, cleanedSignals, true);
      Print("CleanupOldSignals: Cleaned up old signals, kept signals from last 7 days");
     }
   else
     {
      // No signals to keep, create empty array
      SaveToJSON(m_signalsFile, "[]", true);
      Print("CleanupOldSignals: All signals were old, created empty signals file");
     }
  }

//+------------------------------------------------------------------+
//| Save signal to knowledge base with caching                       |
//+------------------------------------------------------------------+
bool CKnowledgeBase::SaveSignal(const SSignalMetadata &signal)
  {
   // Update last update time
   m_lastUpdate = TimeCurrent();
   
   // Generate cache key
   string cacheKey = "signal_" + signal.signal_id;
   
   // Check cache first
   if(GetFromCache(cacheKey) != "")
     {
      Print("Signal ", signal.signal_id, " already in cache");
      return true;
     }
     
   // Generate a unique ID if not provided
   string signalId = signal.signal_id;
   if(signalId == "")
      signalId = IntegerToString(GetTickCount64()) + "_" + IntegerToString(MathRand());
   
   // Convert signal to JSON
   string json = "{\"signal_id\":\"" + signalId + "\"," +
                "\"timestamp\":" + IntegerToString(signal.timestamp) + "," +
                "\"symbol\":\"" + signal.symbol + "\"," +
                "\"order_type\":" + IntegerToString(signal.order_type) + "," +
                "\"price\":" + DoubleToString(signal.price, _Digits) + "," +
                "\"stop_loss\":" + DoubleToString(signal.stop_loss, _Digits) + "," +
                "\"take_profit\":" + DoubleToString(signal.take_profit, _Digits) + "," +
                "\"confidence\":" + DoubleToString(signal.confidence, 4) + "," +
                "\"source\":\"" + signal.source + "\"," +
                "\"regime\":\"" + signal.regime + "\"," +
                "\"metadata\":" + signal.metadata + "}";
   
   // Append to signals file
   string filepath = GetFilePath(m_signalsFile, true);
   int handle = FileOpen(filepath, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE, ",", CP_UTF8);
   
   if(handle == INVALID_HANDLE)
     {
      Print("Failed to open signals file: ", filepath, ", error: ", GetLastError());
      return false;
     }
   
   // Go to end of file
   FileSeek(handle, 0, SEEK_END);
   
   // If file is empty, start JSON array, otherwise add comma
   if(FileTell(handle) == 0)
      FileWriteString(handle, "[\n" + json);
   else
      FileWriteString(handle, ",\n" + json);
   
   FileClose(handle);
   return true;
  }

//+------------------------------------------------------------------+
//| Get recent signals from the shared knowledge base                |
//+------------------------------------------------------------------+
bool CKnowledgeBase::GetRecentSignals(int count, SSignalMetadata &signals[])
  {
   string filepath = GetFilePath(m_signalsFile, true);
   
   if(!FileIsExist(filepath, 0))
     {
      Print("Signals file does not exist: ", filepath);
      return false;
     }
     
   // Load JSON content
   string jsonContent = LoadFromJSON(m_signalsFile, true);
   if(jsonContent == "")
     {
      Print("No signals found in file: ", filepath);
      return false;
     }
     
   // Parse JSON array and extract signals
   SSignalMetadata tempSignals[];
   int signalCount = 0;
   
   // Simple JSON parsing - look for signal objects
   int pos = 0;
   while(pos < StringLen(jsonContent) && signalCount < 1000) // Limit to prevent infinite loops
     {
      int startPos = StringFind(jsonContent, "{\"signal_id\":", pos);
      if(startPos < 0) break;
      
      int endPos = StringFind(jsonContent, "}", startPos);
      if(endPos < 0) break;
      
      string signalJson = StringSubstr(jsonContent, startPos, endPos - startPos + 1);
      
      // Parse signal data from JSON
      SSignalMetadata signal;
      
      // Extract signal_id
      int idPos = StringFind(signalJson, "\"signal_id\":\"");
      if(idPos >= 0)
        {
         int idStart = idPos + 14;
         int idEnd = StringFind(signalJson, "\"", idStart);
         if(idEnd > idStart)
            signal.signal_id = StringSubstr(signalJson, idStart, idEnd - idStart);
        }
      
      // Extract timestamp
      int timestampPos = StringFind(signalJson, "\"timestamp\":");
      if(timestampPos >= 0)
        {
         int timestampStart = timestampPos + 12;
         int timestampEnd = StringFind(signalJson, ",", timestampStart);
         if(timestampEnd < 0) timestampEnd = StringFind(signalJson, "}", timestampStart);
         if(timestampEnd > timestampStart)
           {
            string timestampStr = StringSubstr(signalJson, timestampStart, timestampEnd - timestampStart);
            signal.timestamp = (datetime)StringToInteger(timestampStr);
           }
        }
      
      // Extract symbol
      int symbolPos = StringFind(signalJson, "\"symbol\":\"");
      if(symbolPos >= 0)
        {
         int symbolStart = symbolPos + 10;
         int symbolEnd = StringFind(signalJson, "\"", symbolStart);
         if(symbolEnd > symbolStart)
            signal.symbol = StringSubstr(signalJson, symbolStart, symbolEnd - symbolStart);
        }
      
      // Extract order_type
      int orderTypePos = StringFind(signalJson, "\"order_type\":");
      if(orderTypePos >= 0)
        {
         int orderTypeStart = orderTypePos + 13;
         int orderTypeEnd = StringFind(signalJson, ",", orderTypeStart);
         if(orderTypeEnd < 0) orderTypeEnd = StringFind(signalJson, "}", orderTypeStart);
         if(orderTypeEnd > orderTypeStart)
           {
            string orderTypeStr = StringSubstr(signalJson, orderTypeStart, orderTypeEnd - orderTypeStart);
            signal.order_type = (ENUM_ORDER_TYPE)StringToInteger(orderTypeStr);
           }
        }
      
      // Extract price
      int pricePos = StringFind(signalJson, "\"price\":");
      if(pricePos >= 0)
        {
         int priceStart = pricePos + 8;
         int priceEnd = StringFind(signalJson, ",", priceStart);
         if(priceEnd < 0) priceEnd = StringFind(signalJson, "}", priceStart);
         if(priceEnd > priceStart)
           {
            string priceStr = StringSubstr(signalJson, priceStart, priceEnd - priceStart);
            signal.price = StringToDouble(priceStr);
           }
        }
      
      // Extract confidence
      int confidencePos = StringFind(signalJson, "\"confidence\":");
      if(confidencePos >= 0)
        {
         int confidenceStart = confidencePos + 13;
         int confidenceEnd = StringFind(signalJson, ",", confidenceStart);
         if(confidenceEnd < 0) confidenceEnd = StringFind(signalJson, "}", confidenceStart);
         if(confidenceEnd > confidenceStart)
           {
            string confidenceStr = StringSubstr(signalJson, confidenceStart, confidenceEnd - confidenceStart);
            signal.confidence = StringToDouble(confidenceStr);
           }
        }
      
      // Extract source
      int sourcePos = StringFind(signalJson, "\"source\":\"");
      if(sourcePos >= 0)
        {
         int sourceStart = sourcePos + 10;
         int sourceEnd = StringFind(signalJson, "\"", sourceStart);
         if(sourceEnd > sourceStart)
            signal.source = StringSubstr(signalJson, sourceStart, sourceEnd - sourceStart);
        }
      
      // Extract regime
      int regimePos = StringFind(signalJson, "\"regime\":\"");
      if(regimePos >= 0)
        {
         int regimeStart = regimePos + 10;
         int regimeEnd = StringFind(signalJson, "\"", regimeStart);
         if(regimeEnd > regimeStart)
            signal.regime = StringSubstr(signalJson, regimeStart, regimeEnd - regimeStart);
        }
      
      // Add signal to temporary array
      ArrayResize(tempSignals, signalCount + 1);
      tempSignals[signalCount] = signal;
      signalCount++;
      
      pos = endPos + 1;
     }
   
   // Return the most recent signals (up to count)
   if(signalCount == 0)
     {
      Print("No valid signals found in file");
      return false;
     }
     
   int returnCount = MathMin(count, signalCount);
   ArrayResize(signals, returnCount);
   
   // Copy the most recent signals (from the end of the array)
   int startIdx = MathMax(0, signalCount - returnCount);
   for(int i = 0; i < returnCount; i++)
     {
      signals[i] = tempSignals[startIdx + i];
     }
     
   return returnCount > 0;
  }

//+------------------------------------------------------------------+
//| Update signal with trade outcome                                 |
//+------------------------------------------------------------------+
bool CKnowledgeBase::UpdateSignalOutcome(const STradeOutcome &outcome)
  {
   string filepath = GetFilePath(m_signalsFile, true);
   if(!FileIsExist(filepath, 0))
     {
      Print("Signals file does not exist: ", filepath);
      return false;
     }
     
   // Load existing signals
   string jsonContent = LoadFromJSON(m_signalsFile, true);
   if(jsonContent == "")
     {
      Print("No signals found in file: ", filepath);
      return false;
     }
     
   // Find and update the specific signal
   string updatedContent = "";
   bool signalFound = false;
   bool firstSignal = true;
   
   // Simple JSON parsing - look for signal objects
   int pos = 0;
   while(pos < StringLen(jsonContent))
     {
      int startPos = StringFind(jsonContent, "{\"signal_id\":", pos);
      if(startPos < 0) break;
      
      int endPos = StringFind(jsonContent, "}", startPos);
      if(endPos < 0) break;
      
      string signalJson = StringSubstr(jsonContent, startPos, endPos - startPos + 1);
      
      // Extract signal_id to check if this is the signal we want to update
      int idPos = StringFind(signalJson, "\"signal_id\":\"");
      string currentSignalId = "";
      if(idPos >= 0)
        {
         int idStart = idPos + 14;
         int idEnd = StringFind(signalJson, "\"", idStart);
         if(idEnd > idStart)
            currentSignalId = StringSubstr(signalJson, idStart, idEnd - idStart);
        }
      
      // If this is the signal we want to update, add outcome data
      if(currentSignalId == outcome.signal_id)
        {
         signalFound = true;
         
         // Remove the closing brace and add outcome data
         string baseSignal = StringSubstr(signalJson, 0, StringLen(signalJson) - 1);
         
         // Add outcome data
         string outcomeData = StringFormat(",\"outcome\":{\"close_time\":%d,\"pips\":%.2f,\"profit\":%.2f,\"close_reason\":\"%s\",\"max_drawdown\":%.2f}}",
                                         outcome.close_time,
                                         outcome.pips,
                                         outcome.profit,
                                         outcome.close_reason,
                                         outcome.max_drawdown);
         
         signalJson = baseSignal + outcomeData;
        }
      
      // Add signal to updated content
      if(!firstSignal)
         updatedContent += ",\n";
      else
         firstSignal = false;
         
      updatedContent += signalJson;
      
      pos = endPos + 1;
     }
   
   if(!signalFound)
     {
      Print("Signal with ID ", outcome.signal_id, " not found in knowledge base");
      return false;
     }
     
   // Save updated signals back to file
   updatedContent = "[\n" + updatedContent + "\n]";
   if(SaveToJSON(m_signalsFile, updatedContent, true))
     {
      Print("Successfully updated signal outcome for ", outcome.signal_id, 
            ", PnL: ", outcome.profit, ", Pips: ", outcome.pips);
      
      // Update cache
      string cacheKey = "signal_" + outcome.signal_id;
      AddToCache(cacheKey, "updated", 300);
      
      return true;
     }
   else
     {
      Print("Failed to save updated signals to file");
      return false;
     }
  }

//+------------------------------------------------------------------+
//| Save market regime classification                                |
//+------------------------------------------------------------------+
bool CKnowledgeBase::SaveRegimeClassification(const string symbol, const string regime, const datetime time)
  {
   // Load existing regimes to check if we need to update or append
   string jsonContent = LoadFromJSON(m_regimesFile, true);
   string updatedContent = "";
   bool symbolFound = false;
   bool firstRegime = true;
   
   // Create new regime entry
   string newRegimeJson = "{\"symbol\":\"" + symbol + 
                         "\",\"regime\":\"" + regime + 
                         "\",\"timestamp\":" + IntegerToString(time) + "}";
   
   if(jsonContent != "")
     {
      // Parse existing regimes and update if symbol exists, otherwise append
      int pos = 0;
      while(pos < StringLen(jsonContent))
        {
         int startPos = StringFind(jsonContent, "{\"symbol\":", pos);
         if(startPos < 0) break;
         
         int endPos = StringFind(jsonContent, "}", startPos);
         if(endPos < 0) break;
         
         string regimeJson = StringSubstr(jsonContent, startPos, endPos - startPos + 1);
         
         // Extract symbol from regime entry
         int symbolPos = StringFind(regimeJson, "\"symbol\":\"");
         string currentSymbol = "";
         if(symbolPos >= 0)
           {
            int symbolStart = symbolPos + 10;
            int symbolEnd = StringFind(regimeJson, "\"", symbolStart);
            if(symbolEnd > symbolStart)
               currentSymbol = StringSubstr(regimeJson, symbolStart, symbolEnd - symbolStart);
           }
         
         // If this is the symbol we want to update, use new data
         if(currentSymbol == symbol)
           {
            symbolFound = true;
            regimeJson = newRegimeJson;
           }
         
         // Add regime to updated content
         if(!firstRegime)
            updatedContent += ",\n";
         else
            firstRegime = false;
            
         updatedContent += regimeJson;
         
         pos = endPos + 1;
        }
     }
   
   // If symbol not found, append new regime
   if(!symbolFound)
     {
      if(!firstRegime)
         updatedContent += ",\n";
      updatedContent += newRegimeJson;
     }
   
   // Save updated regimes back to file
   updatedContent = "[\n" + updatedContent + "\n]";
   if(SaveToJSON(m_regimesFile, updatedContent, true))
     {
      Print("Successfully saved regime classification: ", symbol, " -> ", regime);
      
      // Update cache
      string cacheKey = "regime_" + symbol;
      AddToCache(cacheKey, regime, 600); // Cache for 10 minutes
      
      return true;
     }
   else
     {
      Print("Failed to save regime classification to file");
      return false;
     }
  }

//+------------------------------------------------------------------+
//| Get current market regime for a symbol                           |
//+------------------------------------------------------------------+
string CKnowledgeBase::GetCurrentRegime(const string symbol)
  {
   // Check cache first
   string cacheKey = "regime_" + symbol;
   string cachedRegime = GetFromCache(cacheKey);
   if(cachedRegime != "")
     {
      return cachedRegime;
     }
     
   // Load regimes from file
   string jsonContent = LoadFromJSON(m_regimesFile, true);
   if(jsonContent == "")
     {
      Print("No regimes file found, returning default regime");
      return "normal"; // Default regime
     }
     
   string latestRegime = "normal"; // Default
   datetime latestTimestamp = 0;
   
   // Parse regimes and find the latest one for the symbol
   int pos = 0;
   while(pos < StringLen(jsonContent))
     {
      int startPos = StringFind(jsonContent, "{\"symbol\":", pos);
      if(startPos < 0) break;
      
      int endPos = StringFind(jsonContent, "}", startPos);
      if(endPos < 0) break;
      
      string regimeJson = StringSubstr(jsonContent, startPos, endPos - startPos + 1);
      
      // Extract symbol
      int symbolPos = StringFind(regimeJson, "\"symbol\":\"");
      string currentSymbol = "";
      if(symbolPos >= 0)
        {
         int symbolStart = symbolPos + 10;
         int symbolEnd = StringFind(regimeJson, "\"", symbolStart);
         if(symbolEnd > symbolStart)
            currentSymbol = StringSubstr(regimeJson, symbolStart, symbolEnd - symbolStart);
        }
      
      // If this is the symbol we're looking for
      if(currentSymbol == symbol)
        {
         // Extract timestamp
         int timestampPos = StringFind(regimeJson, "\"timestamp\":");
         if(timestampPos >= 0)
           {
            int timestampStart = timestampPos + 12;
            int timestampEnd = StringFind(regimeJson, ",", timestampStart);
            if(timestampEnd < 0) timestampEnd = StringFind(regimeJson, "}", timestampStart);
            
            if(timestampEnd > timestampStart)
              {
               string timestampStr = StringSubstr(regimeJson, timestampStart, timestampEnd - timestampStart);
               datetime regimeTime = (datetime)StringToInteger(timestampStr);
               
               // If this is the latest regime for this symbol
               if(regimeTime > latestTimestamp)
                 {
                  latestTimestamp = regimeTime;
                  
                  // Extract regime
                  int regimePos = StringFind(regimeJson, "\"regime\":\"");
                  if(regimePos >= 0)
                    {
                     int regimeStart = regimePos + 10;
                     int regimeEnd = StringFind(regimeJson, "\"", regimeStart);
                     if(regimeEnd > regimeStart)
                        latestRegime = StringSubstr(regimeJson, regimeStart, regimeEnd - regimeStart);
                    }
                 }
              }
           }
        }
      
      pos = endPos + 1;
     }
   
   // Cache the result
   AddToCache(cacheKey, latestRegime, 600); // Cache for 10 minutes
   
   return latestRegime;
  }

//+------------------------------------------------------------------+
//| Generate interval log filename based on time                     |
//+------------------------------------------------------------------+
string CKnowledgeBase::GetIntervalLogFilename(const datetime time)
  {
   MqlDateTime dt;
   TimeToStruct(time, dt);
   
   // Create a filename based on the 15-minute interval
   int minuteBlock = (dt.min / 15) * 15; // Round down to nearest 15 minutes
   
   return StringFormat("%04d%02d%02d_%02d%02d.log", 
                      dt.year, dt.mon, dt.day, dt.hour, minuteBlock);
  }

//+------------------------------------------------------------------+
//| Log interval snapshot to the knowledge base                      |
//+------------------------------------------------------------------+
bool CKnowledgeBase::LogIntervalSnapshot(const string ea_name, const string symbol, const string &snapshot)
  {
   // Create directory structure: shared_kb/interval_logs/ea_name/
   string dir = StringFormat("%s\\%s\\%s", m_sharedKBDir, m_intervalLogsDir, ea_name);
   
   if(!DirectoryExists(dir) && !CreateDirectoryRecursive(dir))
     {
      Print("Failed to create directory: ", dir);
      return false;
     }
     
   // Create filename based on current time and symbol
   string filename = StringFormat("%s_%s", symbol, GetIntervalLogFilename(TimeCurrent()));
   string filepath = dir + "\\" + filename;
   
   // Append snapshot to file
   int handle = FileOpen(filepath, FILE_WRITE|FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE, ",", CP_UTF8);
   
   if(handle == INVALID_HANDLE)
     {
      Print("Failed to open interval log file: ", filepath, ", error: ", GetLastError());
      return false;
     }
     
   // Go to end of file
   FileSeek(handle, 0, SEEK_END);
   
   // Add timestamp and snapshot
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   FileWriteString(handle, timestamp + " - " + snapshot + "\n");
   
   FileClose(handle);
   return true;
  }

//+------------------------------------------------------------------+
//| Get interval log for a specific time                             |
//+------------------------------------------------------------------+
string CKnowledgeBase::GetIntervalLog(const string ea_name, const string symbol, const datetime time)
  {
   // Construct the expected filename
   string filename = StringFormat("%s_%s", symbol, GetIntervalLogFilename(time));
   string filepath = StringFormat("%s\\%s\\%s\\%s", 
                                 m_sharedKBDir, m_intervalLogsDir, ea_name, filename);
   
   if(!FileIsExist(filepath, 0))
     {
      Print("Interval log file does not exist: ", filepath);
      return "";
     }
     
   // Read the file contents
   int handle = FileOpen(filepath, FILE_READ|FILE_TXT|FILE_ANSI, ",", CP_UTF8);
   
   if(handle == INVALID_HANDLE)
     {
      Print("Failed to open interval log file: ", filepath, ", error: ", GetLastError());
      return "";
     }
     
   string content = "";
   while(!FileIsEnding(handle))
      content += FileReadString(handle);
      
   FileClose(handle);
   return content;
  }

//+------------------------------------------------------------------+
//| Save data to file                                                |
//+------------------------------------------------------------------+
bool CKnowledgeBase::SaveToFile(const string filename, const string &data[], bool useSharedDir = true)
  {
   string filepath = GetFilePath(filename, useSharedDir);
   
   // Ensure directory exists
   string dir = "";
   // Find the last backslash in the path
   int lastBackslash = -1;
   int pos = StringFind(filepath, "\\");
   while(pos >= 0)
     {
      lastBackslash = pos;
      pos = StringFind(filepath, "\\");
     }
   
   if(lastBackslash > 0)
     {
      dir = StringSubstr(filepath, 0, lastBackslash);
      if(!DirectoryExists(dir) && !CreateDirectoryRecursive(dir))
        {
         Print("Failed to create directory: ", dir);
         return false;
        }
     }
   
   int handle = FileOpen(filepath, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE, ",", CP_UTF8);
   
   if(handle == INVALID_HANDLE)
     {
      Print("Failed to open file for writing: ", filepath, ", error: ", GetLastError());
      return false;
     }
     
   for(int i = 0; i < ArraySize(data); i++)
      FileWrite(handle, data[i]);
      
   FileClose(handle);
   return true;
  }

//+------------------------------------------------------------------+
//| Load data from file                                              |
//+------------------------------------------------------------------+
bool CKnowledgeBase::LoadFromFile(const string filename, string &data[], bool useSharedDir = true)
  {
   string filepath = GetFilePath(filename, useSharedDir);
   
   // Check if file exists
   if(!FileIsExist(filepath, 0))
     {
      Print("File does not exist: ", filepath);
      return false;
     }
   
   // Open file
   int file_handle = FileOpen(filepath, FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_WRITE, ",", CP_UTF8);
   if(file_handle == INVALID_HANDLE)
     {
      Print("Failed to open file: ", filepath, ", error: ", GetLastError());
      return false;
     }
   
   // Read file line by line
   int lineCount = 0;
   int maxLines = 10000; // Prevent potential infinite loops
   string line;
   
   while(!FileIsEnding(file_handle) && lineCount < maxLines)
     {
      line = FileReadString(file_handle);
      if(StringLen(line) > 0)
        {
         int size = ArraySize(data);
         if(ArrayResize(data, size + 1) == -1)
           {
            Print("Failed to resize data array");
            break;
           }
         data[size] = line;
         lineCount++;
        }
     }
   
   // Close file
   FileClose(file_handle);
   
   // Resize the data array to match the actual number of lines read
   if(lineCount > 0)
     {
      ArrayResize(data, lineCount);
      return true;
     }
   
   return false;
   
  }

//+------------------------------------------------------------------+
//| Save market state to knowledge base                              |
//+------------------------------------------------------------------+
bool CKnowledgeBase::SaveMarketState(const SMarketState &state)
  {
   // Create JSON representation of market state
   string json = "{\"timestamp\":" + IntegerToString(state.timestamp) + "," +
                "\"spread\":" + DoubleToString(state.spread, 2) + "," +
                "\"volume\":" + DoubleToString(state.volume, 2) + "," +
                "\"bid\":" + DoubleToString(state.bid, _Digits) + "," +
                "\"ask\":" + DoubleToString(state.ask, _Digits) + "}";
   
   // Save to market states file
   string marketStatesFile = "market_states_" + m_filename + ".json";
   string filepath = GetFilePath(marketStatesFile, true);
   
   int handle = FileOpen(filepath, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE, ",", CP_UTF8);
   
   if(handle == INVALID_HANDLE)
     {
      Print("Failed to open market states file: ", filepath, ", error: ", GetLastError());
      return false;
     }
   
   // Go to end of file
   FileSeek(handle, 0, SEEK_END);
   
   // If file is empty, start JSON array, otherwise add comma
   if(FileTell(handle) == 0)
      FileWriteString(handle, "[\n" + json);
   else
      FileWriteString(handle, ",\n" + json);
   
   FileClose(handle);
   
   // Update last update time
   m_lastUpdate = TimeCurrent();
   
   // Cache the latest market state
   string cacheKey = "market_state_latest";
   AddToCache(cacheKey, json, 60); // Cache for 1 minute
   
   Print("Market state saved: Spread=", state.spread, ", Volume=", state.volume, 
         ", Bid=", state.bid, ", Ask=", state.ask);
   
   return true;
  }

//+------------------------------------------------------------------+
//| Save volatility data to knowledge base                           |
//+------------------------------------------------------------------+
bool CKnowledgeBase::SaveVolatilityData(const SVolatilityData &volData)
  {
   // Create JSON representation of volatility data
   string json = "{\"timestamp\":" + IntegerToString(volData.timestamp) + "," +
                "\"atr\":" + DoubleToString(volData.atr, _Digits) + "," +
                "\"stdDev\":" + DoubleToString(volData.stdDev, _Digits) + "," +
                "\"range\":" + DoubleToString(volData.range, _Digits) + "}";
   
   // Save to volatility data file
   string volatilityFile = "volatility_" + m_filename + ".json";
   string filepath = GetFilePath(volatilityFile, true);
   
   int handle = FileOpen(filepath, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE, ",", CP_UTF8);
   
   if(handle == INVALID_HANDLE)
     {
      Print("Failed to open volatility file: ", filepath, ", error: ", GetLastError());
      return false;
     }
   
   // Go to end of file
   FileSeek(handle, 0, SEEK_END);
   
   // If file is empty, start JSON array, otherwise add comma
   if(FileTell(handle) == 0)
      FileWriteString(handle, "[\n" + json);
   else
      FileWriteString(handle, ",\n" + json);
   
   FileClose(handle);
   
   // Update last update time
   m_lastUpdate = TimeCurrent();
   
   // Cache the latest volatility data
   string cacheKey = "volatility_latest";
   AddToCache(cacheKey, json, 300); // Cache for 5 minutes
   
   Print("Volatility data saved: ATR=", volData.atr, ", StdDev=", volData.stdDev, 
         ", Range=", volData.range);
   
   return true;
  }

//+------------------------------------------------------------------+
//| Add a new trade to the knowledge base                            |
//+------------------------------------------------------------------+
bool CKnowledgeBase::AddTrade(const STradeRecord &trade)
  {
   string filepath = GetFilePath(m_tradeHistoryFile);
   m_lastUpdate = TimeCurrent(); // Update last update time
   
   // Open file for writing (append mode)
   int handle = FileOpen(filepath, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE, ",", CP_UTF8);
   if(handle == INVALID_HANDLE)
     {
      Print("Failed to open trade history file: ", filepath, ", error: ", GetLastError());
      return false;
     }
   
   // If new file, write header
   if(FileSize(handle) == 0)
     {
      string header = "ticket,openTime,closeTime,symbol,openPrice,closePrice,stopLoss,takeProfit,lots,profit,swap,commission,signal,type,isLive,confidence,comment";
      if(FileWriteString(handle, header + "\n") <= 0)
        {
         Print("Failed to write header to trade history file: ", filepath);
         FileClose(handle);
         return false;
        }
     }
   
   // Position to the end of the file for appending
   if(!FileSeek(handle, 0, SEEK_END))
     {
      Print("Failed to seek to end of file: ", filepath, ", error: ", GetLastError());
      FileClose(handle);
      return false;
     }
   
   // Prepare trade record data
   string record = StringFormat("%I64u,%s,%d,%s,%s,%.5f,%.5f,%.5f,%.5f,%.2f,%.2f,%.2f,%.2f,%d,%d,%d,%.2f,%s",
                              trade.ticket,
                              trade.symbol,
                              (int)trade.type,
                              TimeToString(trade.openTime),
                              (trade.closeTime > 0) ? TimeToString(trade.closeTime) : "",
                              trade.openPrice,
                              trade.closePrice,
                              trade.stopLoss,
                              trade.takeProfit,
                              trade.lots,
                              trade.profit,
                              trade.commission,
                              trade.swap,
                              (int)trade.signal,
                              (int)trade.type,
                              trade.isLive ? 1 : 0,
                              trade.confidence,
                              trade.comment);
   
   if(FileWrite(handle, record) <= 0)
     {
      Print("Failed to write trade record to file: ", filepath);
      FileClose(handle);
      return false;
     }
   
   FileClose(handle);
   return true;
  }

//+------------------------------------------------------------------+
//| Get recent trades from the knowledge base                        |
//+------------------------------------------------------------------+
bool CKnowledgeBase::GetRecentTrades(int count, STradeRecord &trades[])
  {
   STradeRecord allTrades[];
   if(!LoadTradeHistory(allTrades))
      return false;
   
   int totalTrades = ArraySize(allTrades);
   int startIdx = (count > 0 && totalTrades > count) ? (totalTrades - count) : 0;
   int resultCount = totalTrades - startIdx;
   
   if(resultCount <= 0)
      return false;
   
   // Manual copy is needed because ArrayCopy doesn't work with structures containing strings
   ArrayResize(trades, resultCount);
   for(int i = 0; i < resultCount; i++)
   {
      trades[i].ticket = allTrades[startIdx + i].ticket;
      trades[i].openTime = allTrades[startIdx + i].openTime;
      trades[i].closeTime = allTrades[startIdx + i].closeTime;
      trades[i].symbol = allTrades[startIdx + i].symbol;
      trades[i].openPrice = allTrades[startIdx + i].openPrice;
      trades[i].closePrice = allTrades[startIdx + i].closePrice;
      trades[i].stopLoss = allTrades[startIdx + i].stopLoss;
      trades[i].takeProfit = allTrades[startIdx + i].takeProfit;
      trades[i].lots = allTrades[startIdx + i].lots;
      trades[i].profit = allTrades[startIdx + i].profit;
      trades[i].swap = allTrades[startIdx + i].swap;
      trades[i].commission = allTrades[startIdx + i].commission;
      trades[i].signal = allTrades[startIdx + i].signal;
      trades[i].type = allTrades[startIdx + i].type;
      trades[i].isLive = allTrades[startIdx + i].isLive;
      trades[i].confidence = allTrades[startIdx + i].confidence;
      trades[i].comment = allTrades[startIdx + i].comment;
   }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Load trade history from file                                     |
//+------------------------------------------------------------------+
bool CKnowledgeBase::LoadTradeHistory(STradeRecord &trades[])
  {
   string lines[];
   if(!LoadFromFile(m_tradeHistoryFile, lines) || ArraySize(lines) < 2) // At least header + 1 trade
     {
      Print("No trade history found or file is empty");
      return false;
     }
   
   // Skip header line
   int tradeCount = ArraySize(lines) - 1;
   ArrayResize(trades, tradeCount);
   
   for(int i = 0; i < tradeCount; i++)
     {
      string parts[];
      StringSplit(lines[i+1], ',', parts);
      
      if(ArraySize(parts) < 17) // Check if we have all fields
        {
         Print("Invalid trade record format in line ", i+1);
         continue;
        }
      
      // Parse trade data
      STradeRecord trade;
      trade.ticket = (ulong)StringToInteger(parts[0]);
      trade.openTime = StringToTime(parts[1]);
      trade.closeTime = (StringLen(parts[2]) > 0) ? StringToTime(parts[2]) : 0;
      trade.symbol = parts[3];
      trade.openPrice = StringToDouble(parts[4]);
      trade.closePrice = StringToDouble(parts[5]);
      trade.stopLoss = StringToDouble(parts[6]);
      trade.takeProfit = StringToDouble(parts[7]);
      trade.lots = StringToDouble(parts[8]);
      trade.profit = StringToDouble(parts[9]);
      trade.swap = StringToDouble(parts[10]);
      trade.commission = StringToDouble(parts[11]);
      trade.signal = (ENUM_TRADE_SIGNAL)StringToInteger(parts[12]);
      trade.type = (ENUM_TRADE_TYPE)StringToInteger(parts[13]);
      trade.isLive = (StringToInteger(parts[14]) == 1);
      trade.confidence = StringToDouble(parts[15]);
      
      // Handle comment (might contain commas)
      if(ArraySize(parts) > 16)
        {
         trade.comment = "";
         for(int j = 16; j < ArraySize(parts); j++)
           {
            if(j > 16) trade.comment += ",";
            trade.comment += parts[j];
           }
        }
      
      trades[i] = trade;
     }
   
   return (tradeCount > 0);
  }

//+------------------------------------------------------------------+
//| Save trade history to file                                       |
//+------------------------------------------------------------------+
bool CKnowledgeBase::SaveTradeHistory(const STradeRecord &trades[])
  {
   string lines[];
   int count = ArraySize(trades);
   
   if(count == 0)
     {
      Print("No trades to save");
      return false;
     }
   
   // Add header
   ArrayResize(lines, count + 1);
   lines[0] = "ticket,openTime,closeTime,symbol,openPrice,closePrice,stopLoss,takeProfit,lots,profit,swap,commission,signal,type,isLive,confidence,comment";
   
   // Add trades
   for(int i = 0; i < count; i++)
     {
      lines[i+1] = StringFormat("%I64u,%s,%s,%s,%.5f,%.5f,%.5f,%.5f,%.2f,%.2f,%.2f,%.2f,%d,%d,%d,%.2f,%s",
                               trades[i].ticket,
                               TimeToString(trades[i].openTime),
                               (trades[i].closeTime > 0) ? TimeToString(trades[i].closeTime) : "",
                               trades[i].symbol,
                               trades[i].openPrice,
                               trades[i].closePrice,
                               trades[i].stopLoss,
                               trades[i].takeProfit,
                               trades[i].lots,
                               trades[i].profit,
                               trades[i].swap,
                               trades[i].commission,
                               trades[i].signal,
                               trades[i].type,
                               trades[i].isLive ? 1 : 0,
                               trades[i].confidence,
                               trades[i].comment);
     }
   
   return SaveToFile(m_tradeHistoryFile, lines);
  }

//+------------------------------------------------------------------+
//| Get total number of trades in history                            |
//+------------------------------------------------------------------+
int CKnowledgeBase::GetTotalTrades()
  {
   string lines[];
   if(!LoadFromFile(m_tradeHistoryFile, lines) || ArraySize(lines) < 2)
      return 0;
   
   return ArraySize(lines) - 1; // Exclude header
  }

//+------------------------------------------------------------------+
//| Save model parameters to file                                    |
//+------------------------------------------------------------------+
bool CKnowledgeBase::SaveModel(const double &weights[])
  {
   m_lastUpdate = TimeCurrent(); // Update last update time
   int handle = FileOpen(GetFilePath(m_modelFile), FILE_WRITE|FILE_BIN|FILE_COMMON|FILE_SHARE_READ);
   
   if(handle == INVALID_HANDLE)
     {
      Print("Failed to open model file for writing: ", GetLastError());
      return false;
     }
   
   // Write version
   FileWriteInteger(handle, 1);
   
   // Write number of weights
   int count = ArraySize(weights);
   FileWriteInteger(handle, count);
   
   // Write weights
   for(int i = 0; i < count; i++)
      FileWriteDouble(handle, weights[i]);
   
   // Write timestamp
   FileWriteLong(handle, TimeCurrent());
   
   FileClose(handle);
   return true;
  }

//+------------------------------------------------------------------+
//| Load model parameters from file                                  |
//+------------------------------------------------------------------+
bool CKnowledgeBase::LoadModel(double &weights[])
  {
   string filepath = GetFilePath(m_modelFile);
   
   if(!FileIsExist(filepath, FILE_COMMON))
     {
      Print("Model file does not exist: ", filepath);
      return false;
     }
   
   int handle = FileOpen(filepath, FILE_READ|FILE_BIN|FILE_COMMON|FILE_SHARE_WRITE);
   
   if(handle == INVALID_HANDLE)
     {
      Print("Failed to open model file for reading: ", GetLastError());
      return false;
     }
   
   // Read version
   int version = FileReadInteger(handle);
   
   if(version != 1)
     {
      Print("Unsupported model version: ", version);
      FileClose(handle);
      return false;
     }
   
   // Read number of weights
   int count = FileReadInteger(handle);
   ArrayResize(weights, count);
   
   // Read weights
   for(int i = 0; i < count; i++)
      weights[i] = FileReadDouble(handle);
   
   // Read timestamp (for reference)
   datetime timestamp = (datetime)FileReadLong(handle);
   
   FileClose(handle);
   
   Print("Model loaded successfully. Last updated: ", TimeToString(timestamp));
   return true;
  }

//+------------------------------------------------------------------+
//| Check if model file exists                                       |
//+------------------------------------------------------------------+
bool CKnowledgeBase::ModelExists()
  {
   return FileIsExist(GetFilePath(m_modelFile), FILE_COMMON);
  }

//+------------------------------------------------------------------+
//| Clear all knowledge base data                                    |
//+------------------------------------------------------------------+
bool CKnowledgeBase::Clear()
  {
   bool success = true;
   
   if(FileIsExist(GetFilePath(m_tradeHistoryFile), FILE_COMMON))
      if(!FileDelete(GetFilePath(m_tradeHistoryFile), FILE_COMMON))
        {
         Print("Failed to delete trade history file: ", GetLastError());
         success = false;
        }
   
   if(FileIsExist(GetFilePath(m_modelFile), FILE_COMMON))
      if(!FileDelete(GetFilePath(m_modelFile), FILE_COMMON))
        {
         Print("Failed to delete model file: ", GetLastError());
         success = false;
        }
   
   return success;
  }

//+------------------------------------------------------------------+
//| Helper method to create a directory and all parent directories   |
//| maxDepth - Maximum number of recursive calls to prevent stack overflow
//+------------------------------------------------------------------+
bool CKnowledgeBase::CreateDirectoryRecursive(const string path, const int maxDepth = 10)
  {
   // Safety check - prevent infinite recursion
   if(maxDepth <= 0)
   {
      Print("CreateDirectoryRecursive: Maximum recursion depth reached for path: ", path);
      return false;
   }
   
   // Check for empty path
   if(StringLen(path) == 0) {
      Print("CreateDirectoryRecursive: Empty path provided");
      return false;
   }
   
   // Use the path as-is, but ensure it's not empty
   string normalizedPath = path;
   if(StringLen(normalizedPath) == 0) {
      return false;
   }
   
   // Try to create the directory directly
   if(FolderCreate(normalizedPath, FILE_COMMON)) {
      return true;
   }
   
   // If we can't create it, try to check if it exists by creating a test file
   string testFile = normalizedPath + "/testfile.tmp";
   int handle = FileOpen(testFile, FILE_WRITE|FILE_TXT|FILE_COMMON);
   if(handle != INVALID_HANDLE) {
      FileClose(handle);
      FileDelete(testFile, FILE_COMMON);
      return true;
   }
   
   // If we get here, we couldn't create or write to the directory
   // Check if directory already exists
   if(DirectoryExists(normalizedPath)) {
      return true;
   }
   
   // Try to create the directory directly first (in case all parent directories exist)
   if(FolderCreate(normalizedPath, FILE_COMMON)) {
      Print("Successfully created directory: ", normalizedPath);
      return true;
   }
   
   // If we get here, we need to create parent directories first
   string parentPath = "";
   int lastBackslash = StringFind(normalizedPath, "\\", 0);
   
   // If no backslash found, it's a relative path with a single component
   if(lastBackslash < 0) {
      // Try to create the directory in the current working directory
      if(FolderCreate(".\\" + normalizedPath, FILE_COMMON)) {
         Print("Created directory: ", ".\\" + normalizedPath);
         return true;
      }
      string errorMsg = "Failed to create directory: \\" + normalizedPath + ", Error: " + IntegerToString(GetLastError());
      Print(errorMsg);
      return false;
   }
   
   // Extract the parent directory path
   parentPath = StringSubstr(normalizedPath, 0, lastBackslash);
   
   // Recursively create the parent directory
   if(!CreateDirectoryRecursive(parentPath, maxDepth - 1)) {
      return false;
   }
   
   // Now try to create the directory again
   if(FolderCreate(normalizedPath, FILE_COMMON)) {
      Print("Created directory (after creating parent): ", normalizedPath);
      return true;
   }
   
   // If we still can't create it, check if it exists now (race condition)
   if(DirectoryExists(normalizedPath)) {
      return true;
   }
   
   Print("Failed to create directory after creating parent: ", normalizedPath, " Error: ", GetLastError());
   return false;
  }

//+------------------------------------------------------------------+
//| Check if a directory exists and is accessible                    |
//+------------------------------------------------------------------+
bool CKnowledgeBase::DirectoryExists(const string path)
  {
   // Check for empty path
   if(StringLen(path) == 0) {
      return false;
   }
   
   // Normalize the path
   string normalizedPath = path;
   StringReplace(normalizedPath, "//", "\\");
   StringReplace(normalizedPath, "/", "\\");
   
   // Remove trailing backslash if present
   if(StringSubstr(normalizedPath, StringLen(normalizedPath)-1) == "\\") {
      normalizedPath = StringSubstr(normalizedPath, 0, StringLen(normalizedPath)-1);
   }
   
   // Try to create the directory with read-only access (will fail if it exists)
   if(FolderCreate(normalizedPath, FILE_COMMON|FILE_READ)) {
      // Directory was created, so it didn't exist before
      return true;
   }
   
   // If we get here, the directory might exist or we might not have permission
   // Try to create a test file to check directory writability
   string testFile = normalizedPath + "\\test_" + IntegerToString(GetTickCount()) + ".tmp";
   int fileHandle = FileOpen(testFile, FILE_WRITE|FILE_TXT|FILE_COMMON);
   
   if(fileHandle != INVALID_HANDLE) {
      FileClose(fileHandle);
      FileDelete(testFile, FILE_COMMON);
      return true; // Directory exists and is writable
   }
   
   // If we can't create a file, try to create the directory
   if(FolderCreate(normalizedPath, FILE_COMMON)) {
      return true; // Directory was created successfully
   }
   
   // Check if it's because the directory exists but is read-only
   if(GetLastError() == ERR_CANNOT_OPEN_FILE || GetLastError() == ERR_INVALID_PARAMETER)
   {
      return true;
   }
   
   // If we get here, we couldn't create or write to the directory
   return false;
  }

//+------------------------------------------------------------------+
//| Create a backup of the knowledge base                            |
//+------------------------------------------------------------------+
bool CKnowledgeBase::Backup(const string backupPath = "")
  {
   string backupDir = (backupPath == "") ? 
                     StringFormat("%sBackup\\", TerminalInfoString(TERMINAL_DATA_PATH)) : 
                     backupPath;
   
   // Create backup directory if it doesn't exist
   if(!FolderCreate(backupDir, FILE_COMMON))
     {
      int error = GetLastError();
      if(error != ERR_FILE_IS_DIRECTORY) // Ignore if directory already exists
        {
         Print("Failed to create backup directory, error code: ", error);
         return false;
        }
     }
   
   bool success = true;
   string timestamp = StringFormat("%s_", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
   StringReplace(timestamp, " ", "_");
   StringReplace(timestamp, ":", "");
   
   // Backup trade history
   if(FileIsExist(GetFilePath(m_tradeHistoryFile), FILE_COMMON))
     {
      string backupFile = backupDir + timestamp + m_tradeHistoryFile;
      if(!FileCopy(GetFilePath(m_tradeHistoryFile), 0, backupFile, FILE_COMMON|FILE_REWRITE))
        {
         Print("Failed to backup trade history: ", GetLastError());
         success = false;
        }
     }
   
   // Backup model
   if(FileIsExist(GetFilePath(m_modelFile), FILE_COMMON))
     {
      string backupFile = backupDir + timestamp + m_modelFile;
      if(!FileCopy(GetFilePath(m_modelFile), 0, backupFile, FILE_COMMON|FILE_REWRITE))
        {
         Print("Failed to backup model: ", GetLastError());
         success = false;
        }
     }
   
   return success;
  }

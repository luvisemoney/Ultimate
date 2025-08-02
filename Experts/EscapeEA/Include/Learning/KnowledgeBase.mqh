//+------------------------------------------------------------------+
//| KnowledgeBase.mqh - Data persistence for EscapeEA                |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include "..\Common\Enums.mqh"
#include "..\Common\Structs.mqh"
#include "..\Common\Constants.mqh"
#include <Files\FileTxt.mqh>
#include "..\Common\HashMap.mqh"

//+------------------------------------------------------------------+
//| Knowledge Base Class                                             |
//+------------------------------------------------------------------+
class CKnowledgeBase
  {
private:
   string            m_filename;          // Base filename for storage
   string            m_tradeHistoryFile;  // Trade history filename
   string            m_modelFile;         // Model parameters filename
   
   // Private methods
   string            GetFilePath(const string filename);
   bool              SaveToFile(const string filename, const string &data[]);
   bool              LoadFromFile(const string filename, string &data[]);
   
public:
   // Constructor/destructor
                     CKnowledgeBase(const string filename);
   
   // Trade history management
   bool              AddTrade(const STradeRecord &trade);
   bool              GetRecentTrades(int count, STradeRecord &trades[]);
   bool              LoadTradeHistory(STradeRecord &trades[]);
   bool              SaveTradeHistory(const STradeRecord &trades[]);
   int               GetTotalTrades();
   
   // Model persistence
   bool              SaveModel(const double &weights[]);
   bool              LoadModel(double &weights[]);
   bool              ModelExists();
   
   // Knowledge base management
   bool              Clear();
   bool              Backup(const string backupPath = "");
   
   // Getters
   string            GetTradeHistoryFile() const { return m_tradeHistoryFile; }
   string            GetModelFile() const { return m_modelFile; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CKnowledgeBase::CKnowledgeBase(const string filename) : m_filename(filename)
  {
   // Set up file paths
   string basePath = StringFormat("%s%s", KNOWLEDGE_DIRECTORY, m_filename);
   m_tradeHistoryFile = basePath + "_trades.csv";
   m_modelFile = basePath + "_model.bin";
   
   // Create knowledge base directory if it doesn't exist
   string dirPath = StringFormat("%s%s", TerminalInfoString(TERMINAL_DATA_PATH), KNOWLEDGE_DIRECTORY);
   if(!FolderCreate(dirPath, FILE_COMMON))
     {
      int error = GetLastError();
      if(error != ERR_FILE_IS_DIRECTORY) // Ignore if directory already exists
         Print("Failed to create knowledge base directory: ", error);
     }
  }

//+------------------------------------------------------------------+
//| Get full file path                                               |
//+------------------------------------------------------------------+
string CKnowledgeBase::GetFilePath(const string filename)
  {
   return StringFormat("%s%s%s", TerminalInfoString(TERMINAL_DATA_PATH), KNOWLEDGE_DIRECTORY, filename);
  }

//+------------------------------------------------------------------+
//| Save data to file                                                |
//+------------------------------------------------------------------+
bool CKnowledgeBase::SaveToFile(const string filename, const string &data[])
  {
   string filepath = GetFilePath(filename);
   CFileTxt file;
   
   if(!file.Open(filepath, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON))
     {
      Print("Failed to open file for writing: ", filepath, ", error: ", GetLastError());
      return false;
     }
   
   for(int i = 0; i < ArraySize(data); i++)
      if(!file.WriteString(data[i] + "\n"))
        {
         Print("Failed to write to file: ", filepath, ", error: ", GetLastError());
         file.Close();
         return false;
        }
   
   file.Close();
   return true;
  }

//+------------------------------------------------------------------+
//| Load data from file                                              |
//+------------------------------------------------------------------+
bool CKnowledgeBase::LoadFromFile(const string filename, string &data[])
  {
   string filepath = GetFilePath(filename);
   CFileTxt file;
   
   if(!FileIsExist(filepath, FILE_COMMON))
     {
      Print("File does not exist: ", filepath);
      return false;
     }
   
   if(!file.Open(filepath, FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON))
     {
      Print("Failed to open file for reading: ", filepath, ", error: ", GetLastError());
      return false;
     }
   
   int count = 0;
   string line;
   
   // Count lines
   while(!file.IsEnding())
     {
      line = file.ReadString();
      // Handle string trimming with explicit type safety
      if(line != "")
        {
         string tempLine = StringSubstr(line, 0, StringLen(line)); // Create an explicit copy
         StringTrimRight(tempLine);
         if(tempLine != "")
            count++;
        }
     }
   
   // Reset to beginning
   file.Seek(0, SEEK_SET);
   
   // Read data
   ArrayResize(data, count);
   int index = 0;
   
   while(!file.IsEnding() && index < count)
     {
      line = file.ReadString();
      // Process non-empty lines with explicit type safety
      if(line != "")
        {
         StringTrimRight(line);
         if(line != "")
           {
            data[index] = line; // This is safe as we've verified line is a string
            index++;
           }
        }
     }
   
   file.Close();
   return (index > 0);
  }

//+------------------------------------------------------------------+
//| Add a new trade to the knowledge base                            |
//+------------------------------------------------------------------+
bool CKnowledgeBase::AddTrade(const STradeRecord &trade)
  {
   CFileTxt file;
   string filepath = GetFilePath(m_tradeHistoryFile);
   bool isNewFile = !FileIsExist(filepath, FILE_COMMON);
   
   if(!file.Open(filepath, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON))
     {
      Print("Failed to open trade history file: ", filepath, ", error: ", GetLastError());
      return false;
     }
   
   // Move to end of file by reading all content first
   if(!isNewFile)
     {
      // Read all content to move to the end
      string line;
      while(!file.IsEnding())
        {
         line = file.ReadString();
         if(GetLastError() != 0)
           {
            Print("Error reading file: ", filepath, ", error: ", GetLastError());
            file.Close();
            return false;
           }
        }
     }
   
   // Write header if new file
   if(isNewFile)
     {
      string header = "ticket,openTime,closeTime,symbol,openPrice,closePrice,stopLoss,takeProfit,lots,profit,swap,commission,signal,type,isLive,confidence,comment";
      if(!file.WriteString(header + "\n"))
        {
         Print("Failed to write header to file: ", filepath);
         file.Close();
         return false;
        }
     }
   
   // Convert trade to CSV line
   string line = StringFormat("%I64u,%s,%s,%s,%.5f,%.5f,%.5f,%.5f,%.2f,%.2f,%.2f,%.2f,%d,%d,%d,%.2f,%s",
                             trade.ticket,
                             TimeToString(trade.openTime),
                             (trade.closeTime > 0) ? TimeToString(trade.closeTime) : "",
                             trade.symbol,
                             trade.openPrice,
                             trade.closePrice,
                             trade.stopLoss,
                             trade.takeProfit,
                             trade.lots,
                             trade.profit,
                             trade.swap,
                             trade.commission,
                             trade.signal,
                             trade.type,
                             trade.isLive ? 1 : 0,
                             trade.confidence,
                             trade.comment);
   
   // Write trade to file
   if(!file.WriteString(line + "\n"))
     {
      Print("Failed to write trade to file: ", filepath);
      file.Close();
      return false;
     }
   
   file.Close();
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
   int handle = FileOpen(GetFilePath(m_modelFile), FILE_WRITE|FILE_BIN|FILE_COMMON);
   
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
   
   int handle = FileOpen(filepath, FILE_READ|FILE_BIN|FILE_COMMON);
   
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

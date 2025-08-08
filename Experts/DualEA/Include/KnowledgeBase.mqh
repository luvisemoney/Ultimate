// KnowledgeBase.mqh
// Shared functions for reading from and writing to the knowledge base.

#property copyright "2025, Windsurf Engineering"
#property link      "https://www.windsurf.ai"

#include <Files\File.mqh>

// --- Defines the structure for a single trade record
struct TradeRecord
  {
   datetime          timestamp;        // Trade execution timestamp
   string            symbol;           // Trading symbol
   ENUM_ORDER_TYPE   type;             // Order type (e.g., ORDER_TYPE_BUY, ORDER_TYPE_SELL)
   double            entry_price;      // Price at which the trade was opened
   double            stop_loss;        // Stop loss level
   double            take_profit;      // Take profit level
   double            close_price;      // Price at which the trade was closed
   double            profit;           // Profit or loss from the trade
   string            strategy_id;      // ID of the strategy that generated the trade
  };

// --- Class to manage knowledge base operations
class CKnowledgeBase
  {
private:
   string            m_file_path;      // Path to the knowledge base file
   int               m_file_handle;    // File handle
   string            m_csv_delimiter;  // CSV delimiter

public:
                     CKnowledgeBase(string file_name="DualEA\\knowledge_base.csv", string delimiter=",");
                     ~CKnowledgeBase();

   // --- Methods for data handling
   bool              WriteRecord(const TradeRecord &record);
   bool              LogTrade(const string strategy_name, const int retcode, const ulong deal, const ulong order_id);

private:
   bool              OpenFile(int flags=FILE_WRITE|FILE_READ|FILE_CSV);
   void              CloseFile();
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CKnowledgeBase::CKnowledgeBase(string file_name="DualEA\\knowledge_base.csv", string delimiter=",")
  {
   m_csv_delimiter = delimiter;
   m_file_path = file_name; // Use subfolder under Common Files: DualEA\

   // Ensure target subfolder exists in Common files
   // Common files base: TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files"
   // Create "DualEA" if missing
   FolderCreate("DualEA", FILE_COMMON);

   // Debug: show resolved common file path
   string full_main_path = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + m_file_path;
   PrintFormat("KnowledgeBase: writing main CSV to Common Files: %s", full_main_path);

   // --- Ensure the header exists (use direct FileOpen to avoid noisy error on first run)
   int h = FileOpen(m_file_path, FILE_READ|FILE_CSV|FILE_COMMON);
   if(h == INVALID_HANDLE)
     {
      // Create new file with header
      h = FileOpen(m_file_path, FILE_WRITE|FILE_CSV|FILE_COMMON);
      if(h != INVALID_HANDLE)
        {
         FileWriteString(h, "timestamp,symbol,type,entry_price,stop_loss,take_profit,close_price,profit,strategy_id\n");
         FileClose(h);
        }
     }
   else
     {
      // File exists; if empty, write header
      if(FileSize(h) == 0)
        {
         FileClose(h);
         h = FileOpen(m_file_path, FILE_WRITE|FILE_CSV|FILE_COMMON);
         if(h != INVALID_HANDLE)
           {
            FileWriteString(h, "timestamp,symbol,type,entry_price,stop_loss,take_profit,close_price,profit,strategy_id\n");
           }
        }
      if(h != INVALID_HANDLE)
         FileClose(h);
     }
  }
//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CKnowledgeBase::~CKnowledgeBase()
  {
  }

//+------------------------------------------------------------------+
//| Writes a trade record to the CSV file                            |
//+------------------------------------------------------------------+
bool CKnowledgeBase::WriteRecord(const TradeRecord &record)
  {
   if(!OpenFile(FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE))
      return(false);

   FileSeek(m_file_handle, 0, SEEK_END);

   string record_string = TimeToString(record.timestamp) + m_csv_delimiter +
                          record.symbol + m_csv_delimiter +
                          IntegerToString(record.type) + m_csv_delimiter +
                          DoubleToString(record.entry_price, _Digits) + m_csv_delimiter +
                          DoubleToString(record.stop_loss, _Digits) + m_csv_delimiter +
                          DoubleToString(record.take_profit, _Digits) + m_csv_delimiter +
                          DoubleToString(record.close_price, _Digits) + m_csv_delimiter +
                          DoubleToString(record.profit, 2) + m_csv_delimiter +
                          record.strategy_id;

   FileWriteString(m_file_handle, record_string + "\n");

   CloseFile();
   return(true);
  }

//+------------------------------------------------------------------+
//| Logs a trade event with basic MT5 result info                     |
//+------------------------------------------------------------------+
bool CKnowledgeBase::LogTrade(const string strategy_name, const int retcode, const ulong deal, const ulong order_id)
  {
   // Derive an events file from the main path, e.g., knowledge_base_events.csv
   string events_path = m_file_path;
   int dot = StringFind(events_path, ".", 0);
   if(dot > 0)
      events_path = StringSubstr(events_path, 0, dot) + "_events.csv";
   else
      events_path = events_path + "_events.csv";

   // Ensure folder exists in Common files
   FolderCreate("DualEA", FILE_COMMON);

   // Debug: show resolved events file path
   string full_events_path = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + events_path;
   PrintFormat("KnowledgeBase: writing events CSV to Common Files: %s", full_events_path);

   int handle = FileOpen(events_path, FILE_READ|FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE|FILE_COMMON);
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("Error opening knowledge base events file '%s'. Error code: %d", events_path, GetLastError());
      return(false);
     }

   // Write header if file is empty
   if(FileSize(handle) == 0)
     {
      FileWriteString(handle, "timestamp,strategy,retcode,deal,order\n");
     }

   FileSeek(handle, 0, SEEK_END);
   string line = TimeToString(TimeCurrent()) + m_csv_delimiter +
                 strategy_name + m_csv_delimiter +
                 IntegerToString(retcode) + m_csv_delimiter +
                 IntegerToString((int)deal) + m_csv_delimiter +
                 IntegerToString((int)order_id);
   FileWriteString(handle, line + "\n");
   FileClose(handle);
   return(true);
  }

//+------------------------------------------------------------------+
//| Opens the file                                                   |
//+------------------------------------------------------------------+
bool CKnowledgeBase::OpenFile(int flags=FILE_WRITE|FILE_READ|FILE_CSV)
  {
   // Always target the Common files area so results are shared across Tester, Paper, and Live
   // The path m_file_path should include the subfolder, e.g. "DualEA\\knowledge_base.csv"
   m_file_handle = FileOpen(m_file_path, flags | FILE_COMMON);
   if(m_file_handle == INVALID_HANDLE)
     {
      PrintFormat("Error opening knowledge base file '%s'. Error code: %d", m_file_path, GetLastError());
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| Closes the file                                                  |
//+------------------------------------------------------------------+
void CKnowledgeBase::CloseFile()
  {
   if(m_file_handle != INVALID_HANDLE)
      FileClose(m_file_handle);
  }

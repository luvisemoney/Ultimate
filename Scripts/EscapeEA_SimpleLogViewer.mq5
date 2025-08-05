//+------------------------------------------------------------------+
//|                                        EscapeEA_SimpleLogViewer.mq5 |
//|                                      Copyright 2025, EscapeEA     |
//|                                          https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property strict
#property script_show_inputs

//--- Input Parameters
input string   InpLogPath = "Logs\\EscapeEA\\"; // Log directory path
input int      InpMaxLines = 1000;              // Maximum lines to display
input color    InpTextColor = clrWhite;         // Text color
input int      InpFontSize = 9;                 // Font size
input bool     InpAutoRefresh = true;           // Auto-refresh logs
input int      InpRefreshRate = 5;              // Refresh rate (seconds)

//--- Global Variables
string g_logFiles[];
int g_totalLogs = 0;
int g_currentLog = 0;
datetime g_lastUpdate = 0;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   // Initialize the log viewer
   if(!InitializeLogViewer())
     {
      Print("Failed to initialize log viewer");
      return;
     }
   
   // Main loop
   while(!IsStopped())
     {
      // Update display if needed
      if(InpAutoRefresh && (TimeCurrent() - g_lastUpdate) >= InpRefreshRate)
        {
         UpdateLogDisplay();
         g_lastUpdate = TimeCurrent();
        }
      
      // Small delay to prevent high CPU usage
      Sleep(100);
     }
}

//+------------------------------------------------------------------+
//| Initialize the log viewer                                        |
//+------------------------------------------------------------------+
bool InitializeLogViewer()
{
   // Set up the log directory path
   string logPath = InpLogPath;
   if(StringSubstr(logPath, StringLen(logPath)-1, 1) != "\\")
      logPath += "\\";
   
   // Find all log files
   string findFilter = logPath + "*.log";
   string fileName;
   long hFind;
   
   // Reset log files array
   ArrayFree(g_logFiles);
   g_totalLogs = 0;
   
   // Search for log files
   hFind = FileFindFirst(findFilter, fileName);
   if(hFind != INVALID_HANDLE)
     {
      do
        {
         // Add file to array
         ArrayResize(g_logFiles, g_totalLogs + 1);
         g_logFiles[g_totalLogs] = fileName;
         g_totalLogs++;
        }
      while(FileFindNext(hFind, fileName));
      
      FileFindClose(hFind);
     }
   
   if(g_totalLogs == 0)
     {
      Print("No log files found in ", logPath);
      return false;
     }
   
   // Sort files by name (newest first)
   ArraySort(g_logFiles, 0, 0, MODE_DESCEND);
   
   // Display the first log file
   g_currentLog = 0;
   UpdateLogDisplay();
   
   return true;
}

//+------------------------------------------------------------------+
//| Update the log display                                           |
//+------------------------------------------------------------------+
void UpdateLogDisplay()
{
   if(g_totalLogs == 0)
      return;
   
   // Read the current log file
   string logPath = InpLogPath;
   if(StringSubstr(logPath, StringLen(logPath)-1, 1) != "\\")
      logPath += "\\";
   
   string fileName = logPath + g_logFiles[g_currentLog];
   int handle = FileOpen(fileName, FILE_READ|FILE_TXT|FILE_ANSI);
   
   if(handle == INVALID_HANDLE)
     {
      Print("Failed to open log file: ", fileName, ", error: ", GetLastError());
      return;
     }
   
   // Read the file content
   string content = "";
   int lineCount = 0;
   
   while(!FileIsEnding(handle) && lineCount < InpMaxLines)
     {
      string line = FileReadString(handle);
      content = line + "\r\n" + content; // Add newest lines at the top
      lineCount++;
     }
   
   FileClose(handle);
   
   // Update the chart comment
   string status = StringFormat("Log: %s (%d/%d) | %s | %s",
                               g_logFiles[g_currentLog],
                               g_currentLog + 1,
                               g_totalLogs,
                               TimeToString(TimeLocal(), TIME_DATE|TIME_SECONDS),
                               InpAutoRefresh ? "Auto-Refresh ON" : "Auto-Refresh OFF");
   
   Comment(status, "\n\n", content);
   
   // Print status to Experts tab
   Print(status);
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // Handle keyboard events for navigation
   if(id == CHARTEVENT_KEYDOWN)
     {
      // Left arrow - previous log
      if(lparam == 37) // Left arrow key
        {
         if(g_currentLog > 0)
           {
            g_currentLog--;
            UpdateLogDisplay();
           }
        }
      // Right arrow - next log
      else if(lparam == 39) // Right arrow key
        {
         if(g_currentLog < g_totalLogs - 1)
           {
            g_currentLog++;
            UpdateLogDisplay();
           }
        }
      // R key - refresh
      else if(lparam == 82) // 'R' key
        {
         UpdateLogDisplay();
        }
     }
}
//+------------------------------------------------------------------+

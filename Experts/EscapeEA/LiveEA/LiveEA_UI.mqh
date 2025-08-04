//+------------------------------------------------------------------+
//|                                                LiveEA_UI.mqh      |
//|                                      Copyright 2025, EscapeEA     |
//|                                          https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Class for managing LiveEA's user interface                        |
//+------------------------------------------------------------------+
class CLiveEA_UI
  {
private:
   // Chart objects
   long              m_chartId;
   int               m_subWindow;
   
   // UI Elements
   string            m_infoPanelName;
   string            m_statusLabel;
   
   // Colors
   color             m_textColor;
   color             m_profitColor;
   color             m_lossColor;
   color             m_warningColor;
   color             m_bgColor;
   
   // Status tracking
   bool              m_isConnected;
   
public:
   // Constructor/destructor
                     CLiveEA_UI();
                    ~CLiveEA_UI();
   
   // Initialization
   bool              Initialize();
   void              Deinitialize();
   
   // Update methods
   void              UpdateInfoPanel(const string &status, const double balance, 
                                   const double equity, const int totalTrades, 
                                   const double dailyProfit, const int activeSignals);
   
   void              UpdateConnectionStatus(const bool isConnected);
   
   // Helper methods
   void              CreateInfoPanel();
   void              RemoveInfoPanel();
   
private:
   // Internal methods
   void              CreateLabel(const string name, const string text, const int x, const int y, 
                               const color clr, const int fontSize = 8);
   void              UpdateLabel(const string name, const string text, const color clr = clrNONE);
   string            FormatDouble(const double value, const int digits = 2);
   string            GetConnectionStatusText(const bool isConnected);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLiveEA_UI::CLiveEA_UI() : 
   m_chartId(ChartID()),
   m_subWindow(0),
   m_infoPanelName("LiveEA_InfoPanel"),
   m_statusLabel("LiveEA_Status"),
   m_textColor(clrWhite),
   m_profitColor(clrLime),
   m_lossColor(clrRed),
   m_warningColor(clrOrange),
   m_bgColor(C'30,30,30'),
   m_isConnected(false)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLiveEA_UI::~CLiveEA_UI()
  {
   Deinitialize();
  }

//+------------------------------------------------------------------+
//| Initialize UI components                                         |
//+------------------------------------------------------------------+
bool CLiveEA_UI::Initialize()
  {
   // Create the main info panel
   CreateInfoPanel();
   
   // Set up chart properties
   ChartSetInteger(m_chartId, CHART_SHOW_GRID, false);
   ChartSetInteger(m_chartId, CHART_SHOW_ASK_LINE, true);
   ChartSetInteger(m_chartId, CHART_COLOR_BACKGROUND, m_bgColor);
   ChartRedraw(m_chartId);
   
   return true;
  }

//+------------------------------------------------------------------+
//| Deinitialize UI components                                       |
//+------------------------------------------------------------------+
void CLiveEA_UI::Deinitialize()
  {
   RemoveInfoPanel();
   ChartRedraw(m_chartId);
  }

//+------------------------------------------------------------------+
//| Update the information panel with current status                 |
//+------------------------------------------------------------------+
void CLiveEA_UI::UpdateInfoPanel(const string &status, const double balance, 
                               const double equity, const int totalTrades, 
                               const double dailyProfit, const int activeSignals)
  {
   string equityStr = "Equity: " + FormatDouble(equity, 2);
   string balanceStr = "Balance: " + FormatDouble(balance, 2);
   string tradesStr = "Trades: " + IntegerToString(totalTrades);
   string signalsStr = "Active Signals: " + IntegerToString(activeSignals);
   
   // Determine color based on profit/loss
   color profitColor = (dailyProfit >= 0) ? m_profitColor : m_lossColor;
   string profitStr = "Daily P/L: " + FormatDouble(dailyProfit, 2);
   
   // Update or create labels
   UpdateLabel(m_statusLabel + "_Status", "Status: " + status, 
              status == "Running" ? m_profitColor : m_warningColor);
   UpdateLabel(m_statusLabel + "_Connection", "Connection: " + GetConnectionStatusText(m_isConnected), 
              m_isConnected ? m_profitColor : m_lossColor);
   UpdateLabel(m_statusLabel + "_Equity", equityStr, m_textColor);
   UpdateLabel(m_statusLabel + "_Balance", balanceStr, m_textColor);
   UpdateLabel(m_statusLabel + "_Trades", tradesStr, m_textColor);
   UpdateLabel(m_statusLabel + "_Signals", signalsStr, m_textColor);
   UpdateLabel(m_statusLabel + "_Profit", profitStr, profitColor);
   
   ChartRedraw(m_chartId);
  }

//+------------------------------------------------------------------+
//| Update the connection status                                     |
//+------------------------------------------------------------------+
void CLiveEA_UI::UpdateConnectionStatus(const bool isConnected)
  {
   m_isConnected = isConnected;
   UpdateLabel(m_statusLabel + "_Connection", 
              "Connection: " + GetConnectionStatusText(m_isConnected), 
              m_isConnected ? m_profitColor : m_lossColor);
   ChartRedraw(m_chartId);
  }

//+------------------------------------------------------------------+
//| Create the information panel                                     |
//+------------------------------------------------------------------+
void CLiveEA_UI::CreateInfoPanel()
  {
   // Create a background rectangle
   ObjectCreate(m_chartId, m_infoPanelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(m_chartId, m_infoPanelName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(m_chartId, m_infoPanelName, OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(m_chartId, m_infoPanelName, OBJPROP_XSIZE, 250);
   ObjectSetInteger(m_chartId, m_infoPanelName, OBJPROP_YSIZE, 130);
   ObjectSetInteger(m_chartId, m_infoPanelName, OBJPROP_BGCOLOR, m_bgColor);
   ObjectSetInteger(m_chartId, m_infoPanelName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(m_chartId, m_infoPanelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(m_chartId, m_infoPanelName, OBJPROP_COLOR, clrGray);
   ObjectSetInteger(m_chartId, m_infoPanelName, OBJPROP_BACK, false);
   
   // Create title label
   CreateLabel(m_statusLabel + "_Title", "=== Live EA ===", 15, 25, clrDodgerBlue, 10);
   
   // Create status labels
   CreateLabel(m_statusLabel + "_Status", "Status: Initializing...", 15, 45, m_textColor, 8);
   CreateLabel(m_statusLabel + "_Connection", "Connection: Disconnected", 15, 60, m_lossColor, 8);
   CreateLabel(m_statusLabel + "_Equity", "Equity: 0.00", 15, 75, m_textColor, 8);
   CreateLabel(m_statusLabel + "_Balance", "Balance: 0.00", 15, 90, m_textColor, 8);
   CreateLabel(m_statusLabel + "_Trades", "Trades: 0", 15, 105, m_textColor, 8);
   CreateLabel(m_statusLabel + "_Signals", "Active Signals: 0", 15, 120, m_textColor, 8);
   CreateLabel(m_statusLabel + "_Profit", "Daily P/L: 0.00", 15, 135, m_textColor, 8);
  }

//+------------------------------------------------------------------+
//| Remove the information panel                                     |
//+------------------------------------------------------------------+
void CLiveEA_UI::RemoveInfoPanel()
  {
   // Remove all our chart objects
   ObjectsDeleteAll(m_chartId, m_infoPanelName);
   ObjectsDeleteAll(m_chartId, m_statusLabel);
   ChartRedraw(m_chartId);
  }

//+------------------------------------------------------------------+
//| Create a text label on the chart                                 |
//+------------------------------------------------------------------+
void CLiveEA_UI::CreateLabel(const string name, const string text, 
                           const int x, const int y, 
                           const color clr, const int fontSize)
  {
   if(ObjectFind(m_chartId, name) >= 0)
      ObjectDelete(m_chartId, name);
      
   ObjectCreate(m_chartId, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(m_chartId, name, OBJPROP_TEXT, text);
   ObjectSetInteger(m_chartId, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(m_chartId, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(m_chartId, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(m_chartId, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(m_chartId, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(m_chartId, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(m_chartId, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(m_chartId, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(m_chartId, name, OBJPROP_BACK, false);
  }

//+------------------------------------------------------------------+
//| Update an existing label or create it if it doesn't exist        |
//+------------------------------------------------------------------+
void CLiveEA_UI::UpdateLabel(const string name, const string text, const color clr)
  {
   if(ObjectFind(m_chartId, name) < 0)
     {
      CreateLabel(name, text, 15, 0, (clr != clrNONE) ? clr : m_textColor);
      return;
     }
     
   ObjectSetString(m_chartId, name, OBJPROP_TEXT, text);
   if(clr != clrNONE)
      ObjectSetInteger(m_chartId, name, OBJPROP_COLOR, clr);
  }

//+------------------------------------------------------------------+
//| Format a double value as a string with specified precision       |
//+------------------------------------------------------------------+
string CLiveEA_UI::FormatDouble(const double value, const int digits)
  {
   return DoubleToString(value, digits);
  }

//+------------------------------------------------------------------+
//| Get connection status as text                                    |
//+------------------------------------------------------------------+
string CLiveEA_UI::GetConnectionStatusText(const bool isConnected)
  {
   return isConnected ? "Connected" : "Disconnected";
  }
//+------------------------------------------------------------------+

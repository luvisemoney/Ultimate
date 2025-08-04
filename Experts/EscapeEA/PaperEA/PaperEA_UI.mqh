//+------------------------------------------------------------------+
//|                                                PaperEA_UI.mqh     |
//|                                      Copyright 2025, EscapeEA     |
//|                                          https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Class for managing PaperEA's user interface                       |
//+------------------------------------------------------------------+
class CPaperEA_UI
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
   color             m_bgColor;
   
public:
   // Constructor/destructor
                     CPaperEA_UI();
                    ~CPaperEA_UI();
   
   // Initialization
   bool              Initialize();
   void              Deinitialize();
   
   // Update methods
   void              UpdateInfoPanel(const string &status, const double balance, 
                                   const double equity, const int totalTrades, 
                                   const double dailyProfit);
   
   // Helper methods
   void              CreateInfoPanel();
   void              RemoveInfoPanel();
   
private:
   // Internal methods
   void              CreateLabel(const string name, const string text, const int x, const int y, 
                               const color clr, const int fontSize = 8);
   void              UpdateLabel(const string name, const string text, const color clr = clrNONE);
   string            FormatDouble(const double value, const int digits = 2);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPaperEA_UI::CPaperEA_UI() : 
   m_chartId(ChartID()),
   m_subWindow(0),
   m_infoPanelName("PaperEA_InfoPanel"),
   m_statusLabel("PaperEA_Status"),
   m_textColor(clrWhite),
   m_profitColor(clrLime),
   m_lossColor(clrRed),
   m_bgColor(C'30,30,30')
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPaperEA_UI::~CPaperEA_UI()
  {
   Deinitialize();
  }

//+------------------------------------------------------------------+
//| Initialize UI components                                         |
//+------------------------------------------------------------------+
bool CPaperEA_UI::Initialize()
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
void CPaperEA_UI::Deinitialize()
  {
   RemoveInfoPanel();
   ChartRedraw(m_chartId);
  }

//+------------------------------------------------------------------+
//| Update the information panel with current status                 |
//+------------------------------------------------------------------+
void CPaperEA_UI::UpdateInfoPanel(const string &status, const double balance, 
                                const double equity, const int totalTrades, 
                                const double dailyProfit)
  {
   string equityStr = "Equity: " + DoubleToString(equity, 2);
   string balanceStr = "Balance: " + DoubleToString(balance, 2);
   string tradesStr = "Trades: " + IntegerToString(totalTrades);
   
   // Determine color based on profit/loss
   color profitColor = (dailyProfit >= 0) ? m_profitColor : m_lossColor;
   string profitStr = "Daily P/L: " + DoubleToString(dailyProfit, 2);
   
   // Update or create labels
   UpdateLabel(m_statusLabel + "_Status", "Status: " + status, m_textColor);
   UpdateLabel(m_statusLabel + "_Equity", equityStr, m_textColor);
   UpdateLabel(m_statusLabel + "_Balance", balanceStr, m_textColor);
   UpdateLabel(m_statusLabel + "_Trades", tradesStr, m_textColor);
   UpdateLabel(m_statusLabel + "_Profit", profitStr, profitColor);
   
   ChartRedraw(m_chartId);
  }

//+------------------------------------------------------------------+
//| Create the information panel                                     |
//+------------------------------------------------------------------+
void CPaperEA_UI::CreateInfoPanel()
  {
   // Create a background rectangle
   ObjectCreate(m_chartId, m_infoPanelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(m_chartId, m_infoPanelName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(m_chartId, m_infoPanelName, OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(m_chartId, m_infoPanelName, OBJPROP_XSIZE, 200);
   ObjectSetInteger(m_chartId, m_infoPanelName, OBJPROP_YSIZE, 100);
   ObjectSetInteger(m_chartId, m_infoPanelName, OBJPROP_BGCOLOR, m_bgColor);
   ObjectSetInteger(m_chartId, m_infoPanelName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(m_chartId, m_infoPanelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(m_chartId, m_infoPanelName, OBJPROP_COLOR, clrGray);
   ObjectSetInteger(m_chartId, m_infoPanelName, OBJPROP_BACK, false);
   
   // Create title label
   CreateLabel(m_statusLabel + "_Title", "=== Paper EA ===", 15, 25, clrDodgerBlue, 10);
   
   // Create status labels
   CreateLabel(m_statusLabel + "_Status", "Status: Initializing...", 15, 45, m_textColor);
   CreateLabel(m_statusLabel + "_Equity", "Equity: 0.00", 15, 60, m_textColor);
   CreateLabel(m_statusLabel + "_Balance", "Balance: 0.00", 15, 75, m_textColor);
   CreateLabel(m_statusLabel + "_Trades", "Trades: 0", 15, 90, m_textColor);
   CreateLabel(m_statusLabel + "_Profit", "Daily P/L: 0.00", 15, 105, m_textColor);
  }

//+------------------------------------------------------------------+
//| Remove the information panel                                     |
//+------------------------------------------------------------------+
void CPaperEA_UI::RemoveInfoPanel()
  {
   // Remove all our chart objects
   ObjectsDeleteAll(m_chartId, m_infoPanelName);
   ObjectsDeleteAll(m_chartId, m_statusLabel);
   ChartRedraw(m_chartId);
  }

//+------------------------------------------------------------------+
//| Create a text label on the chart                                 |
//+------------------------------------------------------------------+
void CPaperEA_UI::CreateLabel(const string name, const string text, 
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
void CPaperEA_UI::UpdateLabel(const string name, const string text, const color clr)
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
string CPaperEA_UI::FormatDouble(const double value, const int digits)
  {
   return DoubleToString(value, digits);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                   EACore.mqh      |
//|                        Copyright 2025, Your Company Name          |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company Name"
#property link      "https://www.yoursite.com"
#property version   "1.00"
#property strict

#include "EAEvents.mqh"
#include "EAState.mqh"
#include "EALogger.mqh"

//+------------------------------------------------------------------+
//| Core EA Class                                                    |
//+------------------------------------------------------------------+
class CEACore
{
private:
   CEAEvents*       m_events;      // Event manager
   CEAState*        m_state;       // State manager
   CEALogger*       m_logger;      // Logger instance
   
   // Core configuration
   string           m_symbol;      // Trading symbol
   ENUM_TIMEFRAMES  m_timeframe;   // Chart timeframe
   
   // Core flags
   bool             m_isInitialized;
   bool             m_isBacktest;
   
public:
                     CEACore();
                    ~CEACore();
   
   // Core methods
   bool              Initialize(string symbol, ENUM_TIMEFRAMES timeframe, bool isBacktest = false);
   void              Deinitialize();
   
   // Event processing
   void              OnTick();
   void              OnTimer();
   void              OnTrade();
   
   // State management
   bool              IsInitialized() const { return m_isInitialized; }
   
private:
   // Internal methods
   bool              InitializeComponents();
   void              CleanupComponents();
   
   // Event handlers
   void              HandleTick();
   void              HandleTimer();
   void              HandleTrade();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CEACore::CEACore() : m_events(NULL), m_state(NULL), m_logger(NULL),
   m_isInitialized(false), m_isBacktest(false), m_symbol(""), m_timeframe(PERIOD_CURRENT)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CEACore::~CEACore()
{
   Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize core EA components                                    |
//+------------------------------------------------------------------+
bool CEACore::Initialize(string symbol, ENUM_TIMEFRAMES timeframe, bool isBacktest = false)
{
   if (m_isInitialized)
   {
      Print("EA Core already initialized");
      return true;
   }
   
   m_symbol = symbol;
   m_timeframe = timeframe;
   m_isBacktest = isBacktest;
   
   if (!InitializeComponents())
   {
      Print("Failed to initialize EA Core components");
      return false;
   }
   
   m_isInitialized = true;
   Print("EA Core initialized successfully");
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize EA core                                             |
//+------------------------------------------------------------------+
void CEACore::Deinitialize()
{
   if (!m_isInitialized)
      return;
      
   CleanupComponents();
   m_isInitialized = false;
   Print("EA Core deinitialized");
}

//+------------------------------------------------------------------+
//| Initialize all components                                        |
//+------------------------------------------------------------------+
bool CEACore::InitializeComponents()
{
   // Initialize logger first
   m_logger = new CEALogger();
   if (!m_logger.Initialize("EALog.txt"))
   {
      Print("Failed to initialize logger");
      return false;
   }
   
   // Initialize state manager
   m_state = new CEAState();
   if (!m_state.Initialize(m_logger))
   {
      Print("Failed to initialize state manager");
      return false;
   }
   
   // Initialize event system
   m_events = new CEAEvents();
   if (!m_events.Initialize(m_logger, m_state))
   {
      Print("Failed to initialize event system");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Cleanup all components                                           |
//+------------------------------------------------------------------+
void CEACore::CleanupComponents()
{
   if (m_events != NULL)
   {
      m_events.Deinitialize();
      delete m_events;
      m_events = NULL;
   }
   
   if (m_state != NULL)
   {
      m_state.Deinitialize();
      delete m_state;
      m_state = NULL;
   }
   
   if (m_logger != NULL)
   {
      m_logger.Deinitialize();
      delete m_logger;
      m_logger = NULL;
   }
}

//+------------------------------------------------------------------+
//| Process tick event                                               |
//+------------------------------------------------------------------+
void CEACore::OnTick()
{
   if (!m_isInitialized)
      return;
      
   try
   {
      HandleTick();
   }
   catch (const string error)
   {
      if (m_logger != NULL)
         m_logger.LogError("Error in OnTick: " + error);
   }
}

//+------------------------------------------------------------------+
//| Process timer event                                              |
//+------------------------------------------------------------------+
void CEACore::OnTimer()
{
   if (!m_isInitialized)
      return;
      
   try
   {
      HandleTimer();
   }
   catch (const string error)
   {
      if (m_logger != NULL)
         m_logger.LogError("Error in OnTimer: " + error);
   }
}

//+------------------------------------------------------------------+
//| Process trade event                                              |
//+------------------------------------------------------------------+
void CEACore::OnTrade()
{
   if (!m_isInitialized)
      return;
      
   try
   {
      HandleTrade();
   }
   catch (const string error)
   {
      if (m_logger != NULL)
         m_logger.LogError("Error in OnTrade: " + error);
   }
}

//+------------------------------------------------------------------+
//| Handle tick processing                                           |
//+------------------------------------------------------------------+
void CEACore::HandleTick()
{
   // Process pending events
   if (m_events != NULL)
      m_events.ProcessTick();
      
   // Update state with latest market data
   if (m_state != NULL)
      m_state.UpdateMarketData(m_symbol, m_timeframe);
}

//+------------------------------------------------------------------+
//| Handle timer processing                                          |
//+------------------------------------------------------------------+
void CEACore::HandleTimer()
{
   // Process timed events
   if (m_events != NULL)
      m_events.ProcessTimer();
      
   // Update state periodically
   if (m_state != NULL)
      m_state.UpdateIndicators();
}

//+------------------------------------------------------------------+
//| Handle trade processing                                          |
//+------------------------------------------------------------------+
void CEACore::HandleTrade()
{
   // Process trade-related events
   if (m_events != NULL)
      m_events.ProcessTrade();
      
   // Update state with latest trade information
   if (m_state != NULL)
      m_state.UpdateTradeState();
}

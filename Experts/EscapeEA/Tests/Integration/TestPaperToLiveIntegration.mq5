//+------------------------------------------------------------------+
//|                                  TestPaperToLiveIntegration.mq5 |
//|                                      Copyright 2025, EscapeEA     |
//|                                          https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property strict

#include "..\\TestBase.mqh"
#include "..\\..\\PaperEA\\PaperEA.mq5"
#include "..\\..\\LiveEA\\LiveEA.mq5"
#include "..\\..\\Include\\Common\\Enums.mqh"
#include "..\\..\\Include\\Common\\Structs.mqh"
#include "..\\..\\Include\\Core\\SignalBroadcaster.mqh"

// Test configuration
#define TEST_SYMBOL           "EURUSD"
#define TEST_TIMEFRAME        PERIOD_M5
#define TEST_MAGIC_NUMBER     12345
#define TEST_INITIAL_BALANCE  10000.0
#define TEST_RISK_PERCENT     1.0
#define TEST_MAX_DRAWDOWN     5.0
#define TEST_MAX_RISK         2.0
#define TEST_LEVERAGE         100

// Forward declarations
void OnTimer();
void OnTick();

// Global variables for test control
CPaperEA     *g_paperEA = NULL;
CLiveEA      *g_liveEA = NULL;
bool          g_testComplete = false;
int           g_testStep = 0;
datetime      g_lastActionTime = 0;
int           g_signalCount = 0;
int           g_tradeCount = 0;

//+------------------------------------------------------------------+
//| Test class for PaperEA to LiveEA integration                     |
//+------------------------------------------------------------------+
class CTestPaperToLiveIntegration : public CTestBase
  {
private:
   string            m_symbol;
   CSignalBroadcaster m_signalBroadcaster;
   
public:
   // Constructor/destructor
   CTestPaperToLiveIntegration() : CTestBase("PaperEA to LiveEA Integration Test") 
     {
      m_symbol = TEST_SYMBOL;
      m_signalBroadcaster.Initialize(TEST_MAGIC_NUMBER);
     }
   
   ~CTestPaperToLiveIntegration() {}
   
   // Override methods
   virtual void      SetUp()
     {
      Print("Initializing test environment...");
      
      // Initialize PaperEA
      g_paperEA = new CPaperEA();
      if(CheckPointer(g_paperEA) == POINTER_INVALID)
         return;
         
      // Initialize LiveEA
      g_liveEA = new CLiveEA();
      if(CheckPointer(g_liveEA) == POINTER_INVALID)
        {
         SafeDelete(g_paperEA);
         return;
        }
      
      // Configure PaperEA for testing
      if(!g_paperEA.Init("TestPaperEA", m_symbol, TEST_TIMEFRAME, TEST_MAGIC_NUMBER, 
                         TEST_INITIAL_BALANCE, TEST_RISK_PERCENT, TEST_LEVERAGE, 
                         TEST_MAX_DRAWDOWN, TEST_MAX_RISK, 1.0, 0.5))
        {
         Print("Failed to initialize PaperEA");
         return;
        }
      
      // Configure LiveEA for testing
      if(!g_liveEA.Init("TestLiveEA", m_symbol, TEST_TIMEFRAME, TEST_MAGIC_NUMBER + 1, 
                        TEST_INITIAL_BALANCE, TEST_RISK_PERCENT, TEST_LEVERAGE, 
                        TEST_MAX_DRAWDOWN, TEST_MAX_RISK, 1.0, 0.5))
        {
         Print("Failed to initialize LiveEA");
         return;
        }
      
      // Initialize test state
      g_testComplete = false;
      g_testStep = 0;
      g_signalCount = 0;
      g_tradeCount = 0;
      g_lastActionTime = TimeCurrent();
      
      // Set up event handlers
      EventSetTimer(1);  // 1-second timer for test control
      Print("Test environment initialized successfully");
     }
     
   virtual void      TearDown()
     {
      Print("Cleaning up test environment...");
      
      // Clean up event handlers
      EventKillTimer();
      
      // Clean up EAs
      if(CheckPointer(g_paperEA) == POINTER_DYNAMIC)
        {
         g_paperEA.Deinit();
         delete g_paperEA;
         g_paperEA = NULL;
        }
         
      if(CheckPointer(g_liveEA) == POINTER_DYNAMIC)
        {
         g_liveEA.Deinit();
         delete g_liveEA;
         g_liveEA = NULL;
        }
        
      Print("Test environment cleaned up");
     }
   
   // Test methods
   ENUM_TEST_RESULT Test_InitialConnection()
     {
      Print("Testing initial connection...");
      
      // Verify both EAs are initialized
      if(CheckPointer(g_paperEA) == POINTER_INVALID || CheckPointer(g_liveEA) == POINTER_INVALID)
         return AssertFailed("EA instances not properly initialized");
         
      if(!g_paperEA.Initialized())
         return AssertFailed("PaperEA failed to initialize");
         
      if(!g_liveEA.Initialized())
         return AssertFailed("LiveEA failed to initialize");
      
      // Verify signal broadcaster is ready
      if(!m_signalBroadcaster.IsInitialized())
         return AssertFailed("Signal broadcaster not initialized");
         
      Print("Initial connection test passed");
      return AssertPassed("Initial connection established successfully");
     }
     
   ENUM_TEST_RESULT Test_SignalTransmission()
     {
      Print("Testing signal transmission...");
      
      // Generate a test signal
      STradeSignal signal = {0};
      signal.version = SIGNAL_PROTOCOL_VERSION;
      signal.signal = SIGNAL_BUY;
      signal.confidence = 0.85;
      signal.timestamp = TimeCurrent();
      signal.symbol = m_symbol;
      signal.price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      signal.sl = signal.price * (1 - 0.01);  // 1% stop loss
      signal.tp = signal.price * (1 + 0.02);  // 2% take profit
      signal.comment = "Integration Test Signal";
      
      // Send the signal with correct parameters
      if(!m_signalBroadcaster.SendSignal(signal.symbol, signal.signal, signal.confidence))
         return AssertFailed("Failed to send signal");
      
      // Verify signal was received by LiveEA
      STradeSignal receivedSignal;
      if(!g_liveEA.GetLastSignal(receivedSignal))
         return AssertFailed("LiveEA did not receive the signal");
      
      // Verify signal integrity
      if(receivedSignal.signal != signal.signal || 
         receivedSignal.confidence != signal.confidence ||
         receivedSignal.symbol != signal.symbol)
         return AssertFailed("Signal integrity check failed");
      
      g_signalCount++;
      PrintFormat("Signal transmission test passed. Signal count: %d", g_signalCount);
      return AssertPassed("Signal transmission works correctly");
     }
     
   ENUM_TEST_RESULT Test_TradeExecution()
     {
      Print("Testing trade execution...");
      
      // Get initial trade count
      int initialTrades = g_liveEA.GetTotalTrades();
      
      // Generate and send a test trade signal
      if(!GenerateAndSendTestTrade())
         return AssertFailed("Failed to generate and send test trade");
      
      // Allow time for trade processing
      Sleep(1000);  // 1 second delay
      
      // Verify trade was executed
      int currentTrades = g_liveEA.GetTotalTrades();
      if(currentTrades <= initialTrades)
         return AssertFailed("No new trades were executed");
      
      // Get the last trade details
      STradeRecord lastTrade;
      if(!g_liveEA.GetLastTrade(lastTrade))
         return AssertFailed("Failed to retrieve last trade details");
      
      // Verify trade details
      if(lastTrade.symbol != m_symbol || lastTrade.type != TRADE_TYPE_BUY)
         return AssertFailed("Trade verification failed");
      
      g_tradeCount++;
      PrintFormat("Trade execution test passed. Total trades: %d", g_tradeCount);
      return AssertPassed("Trade execution works correctly");
     }
     
private:
   // Helper method to generate and send a test trade
   bool GenerateAndSendTestTrade()
     {
      if(CheckPointer(g_paperEA) == POINTER_INVALID)
         return false;
         
      // Generate a test signal
      STradeSignal signal = {0};
      signal.version = SIGNAL_PROTOCOL_VERSION;
      signal.signal = SIGNAL_BUY;
      signal.confidence = 0.9;
      signal.timestamp = TimeCurrent();
      signal.symbol = m_symbol;
      signal.price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      signal.sl = signal.price * 0.99;    // 1% stop loss
      signal.tp = signal.price * 1.02;    // 2% take profit
      signal.comment = "Test Trade Execution";
      
      // Send the signal with correct parameters
      return m_signalBroadcaster.SendSignal(signal.symbol, signal.signal, signal.confidence);
     }
     
   // Main test runner
   virtual ENUM_TEST_RESULT Run()
     {
      Print("\n=== Starting PaperEA to LiveEA Integration Test ===\n");
      
      ENUM_TEST_RESULT result = TEST_PASSED;
      datetime startTime = TimeCurrent();
      
      try
        {
         // Run all test methods with error handling
         ENUM_TEST_RESULT connectionResult = Test_InitialConnection();
         result = (ENUM_TEST_RESULT)MathMax((int)result, (int)connectionResult);
         
         if(result == TEST_PASSED)
           {
            ENUM_TEST_RESULT signalResult = Test_SignalTransmission();
            result = (ENUM_TEST_RESULT)MathMax((int)result, (int)signalResult);
            
            if(signalResult == TEST_PASSED)
              {
               ENUM_TEST_RESULT tradeResult = Test_TradeExecution();
               result = (ENUM_TEST_RESULT)MathMax((int)result, (int)tradeResult);
              }
           }
           
         // Calculate test duration
         int duration = (int)(TimeCurrent() - startTime);
         
         // Print test summary
         Print("\n=== Test Summary ===");
         PrintFormat("Status: %s", result == TEST_PASSED ? "PASSED" : "FAILED");
         PrintFormat("Duration: %d seconds", duration);
         PrintFormat("Signals sent: %d", g_signalCount);
         PrintFormat("Trades executed: %d", g_tradeCount);
         Print("===================\n");
        }
      catch(const string error)
        {
         Print("Test failed with error: ", error);
         result = TEST_FAILED;
        }
      catch(...)
        {
         Print("Test failed with unknown error");
         result = TEST_FAILED;
        }
        
      return result;
     }
  };

//+------------------------------------------------------------------+
//| Timer event handler for test control                             |
//+------------------------------------------------------------------+
void OnTimer()
  {
   static CTestPaperToLiveIntegration test;
   static bool testInitialized = false;
   
   // Initialize test if not already done
   if(!testInitialized)
     {
      Print("Initializing test...");
      test.SetUp();
      testInitialized = true;
      g_lastActionTime = TimeCurrent();
      return;
     }
   
   // Run test sequence
   if(!g_testComplete)
     {
      // Check for timeout (5 minutes max)
      if(TimeCurrent() - g_lastActionTime > 300)  // 5 minutes timeout
        {
         Print("Test timed out after 5 minutes");
         g_testComplete = true;
         return;
        }
      
      // Run test steps
      switch(g_testStep)
        {
         case 0:  // Initial connection test
            Print("\n--- Starting Initial Connection Test ---");
            if(test.Test_InitialConnection() == TEST_PASSED)
              {
               Print("Initial connection test passed");
               g_testStep++;
              }
            else
              {
               Print("Initial connection test failed");
               g_testComplete = true;
              }
            break;
            
         case 1:  // Signal transmission test
            Print("\n--- Starting Signal Transmission Test ---");
            if(test.Test_SignalTransmission() == TEST_PASSED)
              {
               Print("Signal transmission test passed");
               g_testStep++;
              }
            else
              {
               Print("Signal transmission test failed");
               g_testComplete = true;
              }
            break;
            
         case 2:  // Trade execution test
            Print("\n--- Starting Trade Execution Test ---");
            if(test.Test_TradeExecution() == TEST_PASSED)
              {
               Print("Trade execution test passed");
               g_testStep++;
              }
            else
              {
               Print("Trade execution test failed");
              }
            g_testComplete = true;
            break;
            
         default:
            g_testComplete = true;
            break;
        }
      
      g_lastActionTime = TimeCurrent();
     }
   else
     {
      // Test complete, clean up
      if(testInitialized)
        {
         Print("\nTest complete. Cleaning up...");
         test.TearDown();
         testInitialized = false;
        }
      
      // Remove expert after a short delay
      EventKillTimer();
      Print("Test sequence completed. Removing expert...");
      ExpertRemove();
     }
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Initialize random number generator
   MathSrand((uint)TimeCurrent());
   
   // Check if terminal is connected
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
     {
      Alert("Terminal is not connected to the server!");
      return(INIT_FAILED);
     }
   
   // Check if automated trading is allowed
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
     {
      Alert("Automated trading is not allowed!");
      return(INIT_FAILED);
     }
   
   // Check if the symbol is selected in Market Watch
   if(!SymbolSelect(TEST_SYMBOL, true))
     {
      Alert("Failed to select ", TEST_SYMBOL, " in Market Watch!");
      return(INIT_FAILED);
     }
   
   // Start the test with a 1-second timer
   if(!EventSetTimer(1))
     {
      Alert("Failed to create timer!");
      return(INIT_FAILED);
     }
   
   Print("Test expert initialized successfully");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // Clean up
   EventKillTimer();
   
   // Log deinitialization reason
   string reasonText = "";
   switch(reason)
     {
      case REASON_ACCOUNT:
         reasonText = "Account changed";
         break;
      case REASON_CHARTCHANGE:
         reasonText = "Chart symbol or timeframe changed";
         break;
      case REASON_CHARTCLOSE:
         reasonText = "Chart closed";
         break;
      case REASON_PARAMETERS:
         reasonText = "Input parameters changed";
         break;
      case REASON_RECOMPILE:
         reasonText = "Expert recompiled";
         break;
      case REASON_REMOVE:
         reasonText = "Expert removed from chart";
         break;
      case REASON_TEMPLATE:
         reasonText = "Template changed";
         break;
      default:
         reasonText = "Unknown reason";
     }
   
   Print("Test expert deinitialized. Reason: ", reasonText);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Handle tick events if needed
  }

//+------------------------------------------------------------------+
//| Test execution entry point                                       |
//+------------------------------------------------------------------+
void OnStart()
  {
   CTestRunner runner;
   runner.AddTest(new CTestPaperToLiveIntegration());
   
   // Run tests
   runner.RunTests();
   
   // Generate report
   runner.PrintSummary();
   
   // Optional: Save report to file
   // runner.GenerateReport("TestPaperToLiveIntegration_Report.html");
  }
//+------------------------------------------------------------------+

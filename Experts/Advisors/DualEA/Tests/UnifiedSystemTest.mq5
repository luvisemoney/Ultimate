//+------------------------------------------------------------------+
//| UnifiedSystemTest.mq5 - Test Unified System Integration         |
//+------------------------------------------------------------------+
#property copyright "DualEA Team"
#property link      ""
#property version   "1.00"
#property script_show_inputs

#include "../Include/GateManager.mqh"
#include "../Include/ConfigManager.mqh"
#include "../Include/EventBus.mqh"
#include "../Include/SystemMonitor.mqh"
#include "../Include/LearningBridge.mqh"
#include "../Include/CorrelationManager.mqh"
#include "../Include/SessionManager.mqh"
#include "../Include/VolatilitySizer.mqh"

// Test parameters
input bool TestUnifiedMode = true;
input bool TestLegacyMode = true;
input bool VerboseOutput = true;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("=== DualEA Unified System Integration Test ===");
   
   bool allTestsPassed = true;
   
   // Test 1: Singleton Creation
   Print("\n--- Test 1: Singleton Creation ---");
   if(TestSingletonCreation())
      Print("✅ Singleton creation test PASSED");
   else
   {
      Print("❌ Singleton creation test FAILED");
      allTestsPassed = false;
   }
   
   // Test 2: Configuration Management
   Print("\n--- Test 2: Configuration Management ---");
   if(TestConfigurationManagement())
      Print("✅ Configuration management test PASSED");
   else
   {
      Print("❌ Configuration management test FAILED");
      allTestsPassed = false;
   }
   
   // Test 3: Event System
   Print("\n--- Test 3: Event System ---");
   if(TestEventSystem())
      Print("✅ Event system test PASSED");
   else
   {
      Print("❌ Event system test FAILED");
      allTestsPassed = false;
   }
   
   // Test 4: Unified Mode Integration
   if(TestUnifiedMode)
   {
      Print("\n--- Test 4: Unified Mode Integration ---");
      if(TestUnifiedModeIntegration())
         Print("✅ Unified mode integration test PASSED");
      else
      {
         Print("❌ Unified mode integration test FAILED");
         allTestsPassed = false;
      }
   }
   
   // Test 5: Legacy Mode Compatibility
   if(TestLegacyMode)
   {
      Print("\n--- Test 5: Legacy Mode Compatibility ---");
      if(TestLegacyModeCompatibility())
         Print("✅ Legacy mode compatibility test PASSED");
      else
      {
         Print("❌ Legacy mode compatibility test FAILED");
         allTestsPassed = false;
      }
   }
   
   // Test 6: System Monitoring
   Print("\n--- Test 6: System Monitoring ---");
   if(TestSystemMonitoring())
      Print("✅ System monitoring test PASSED");
   else
   {
      Print("❌ System monitoring test FAILED");
      allTestsPassed = false;
   }
   
   // Final Results
   Print("\n=== Test Results Summary ===");
   if(allTestsPassed)
   {
      Print("🎉 ALL TESTS PASSED - Unified System Integration Successful!");
   }
   else
   {
      Print("⚠️  SOME TESTS FAILED - Please review the output above");
   }
   
   // Cleanup
   CConfigManager::Cleanup();
   CEventBus::Cleanup();
   CSystemMonitor::Cleanup();
   
   Print("=== Test Complete ===");
}

//+------------------------------------------------------------------+
//| Test singleton creation and basic functionality                  |
//+------------------------------------------------------------------+
bool TestSingletonCreation()
{
   try
   {
      // Test ConfigManager singleton via shared state
      CConfigManager* config1 = CConfigManager::GetInstance();
      CConfigManager* config2 = CConfigManager::GetInstance();
      config1.SetVerboseLogging(true);
      if(!config2.IsVerboseLogging())
      {
         Print("ERROR: ConfigManager singleton state not shared");
         return false;
      }
      
      // Test EventBus singleton via shared state
      CEventBus* eventBus1 = CEventBus::GetInstance();
      CEventBus* eventBus2 = CEventBus::GetInstance();
      eventBus1.SetVerboseLogging(true);
      if(!eventBus2.IsVerboseLogging())
      {
         Print("ERROR: EventBus singleton state not shared");
         return false;
      }
      
      // Test SystemMonitor singleton via consistent health access
      CSystemMonitor* monitor1 = CSystemMonitor::GetInstance();
      CSystemMonitor* monitor2 = CSystemMonitor::GetInstance();
      SystemHealth h1 = monitor1.GetSystemHealth();
      SystemHealth h2 = monitor2.GetSystemHealth();
      if(h1.last_update == 0 || h2.last_update == 0)
      {
         Print("ERROR: SystemMonitor health not initialized");
         return false;
      }
      
      if(VerboseOutput)
      {
         Print("ConfigManager instance ok: ", (config1 != NULL));
         Print("EventBus instance ok: ", (eventBus1 != NULL));
         Print("SystemMonitor instance ok: ", (monitor1 != NULL));
      }
      
      return true;
   }
   catch(...)
   {
      Print("ERROR: Exception during singleton creation test");
      return false;
   }
}

//+------------------------------------------------------------------+
//| Test configuration management functionality                      |
//+------------------------------------------------------------------+
bool TestConfigurationManagement()
{
   try
   {
      CConfigManager* config = CConfigManager::GetInstance();
      
      // Test system configuration
      config.SetVerboseLogging(true);
      if(!config.IsVerboseLogging())
      {
         Print("ERROR: Verbose logging setting not working");
         return false;
      }
      
      config.SetNoConstraintsMode(true);
      if(!config.IsNoConstraintsMode())
      {
         Print("ERROR: No constraints mode setting not working");
         return false;
      }
      
      // Test gate configuration
      GateConfig gateConfig = config.GetGateConfig(0);
      double originalThreshold = gateConfig.threshold;
      
      config.SetGateThreshold(0, 0.123);
      gateConfig = config.GetGateConfig(0);
      
      if(MathAbs(gateConfig.threshold - 0.123) > 0.001)
      {
         Print("ERROR: Gate threshold setting not working");
         return false;
      }
      
      // Restore original threshold
      config.SetGateThreshold(0, originalThreshold);
      
      if(VerboseOutput)
      {
         Print("Verbose logging: ", config.IsVerboseLogging());
         Print("No constraints mode: ", config.IsNoConstraintsMode());
         Print("Gate 0 threshold: ", gateConfig.threshold);
      }
      
      return true;
   }
   catch(...)
   {
      Print("ERROR: Exception during configuration management test");
      return false;
   }
}

//+------------------------------------------------------------------+
//| Test event system functionality                                 |
//+------------------------------------------------------------------+
bool TestEventSystem()
{
   try
   {
      CEventBus* eventBus = CEventBus::GetInstance();
      
      // Test event publishing
      eventBus.PublishSystemEvent("TestScript", "Test event message");
      eventBus.PublishGateEvent("TestGate", true, "Test gate passed");
      eventBus.PublishPerformanceEvent("test_metric", 123.45);
      
      // Test event history
      EventData lastEvent = eventBus.GetLastEvent(EVENT_PERFORMANCE_METRIC);
      if(lastEvent.timestamp == 0)
      {
         Print("ERROR: Event history not working");
         return false;
      }
      
      // Test event counting
      int eventCount = eventBus.GetEventCount(EVENT_SYSTEM_STATUS);
      if(eventCount < 1)
      {
         Print("ERROR: Event counting not working");
         return false;
      }
      
      if(VerboseOutput)
      {
         Print("Last performance event timestamp: ", TimeToString(lastEvent.timestamp));
         Print("System status event count: ", eventCount);
      }
      
      return true;
   }
   catch(...)
   {
      Print("ERROR: Exception during event system test");
      return false;
   }
}

//+------------------------------------------------------------------+
//| Test unified mode integration                                   |
//+------------------------------------------------------------------+
bool TestUnifiedModeIntegration()
{
   try
   {
      // Create learning bridge
      CLearningBridge* learning = new CLearningBridge("TestData");
      
      // Create gate manager in unified mode
      CGateManager* gateManager = new CGateManager("EURUSD", PERIOD_H1, learning, true);
      
      if(!gateManager.IsUnifiedMode())
      {
         Print("ERROR: Unified mode not enabled");
         delete gateManager;
         delete learning;
         return false;
      }
      
      // Test system health retrieval
      SystemHealth health = gateManager.GetSystemHealth();
      if(health.last_update == 0)
      {
         Print("ERROR: System health not available in unified mode");
         delete gateManager;
         delete learning;
         return false;
      }
      
      // Test gate configuration retrieval
      GateConfig config = gateManager.GetGateConfiguration(0);
      if(config.name == "")
      {
         Print("ERROR: Gate configuration not available in unified mode");
         delete gateManager;
         delete learning;
         return false;
      }
      
      if(VerboseOutput)
      {
         Print("Unified mode enabled: ", gateManager.IsUnifiedMode());
         Print("System health status: ", health.status);
         Print("Gate 0 name: ", config.name);
      }
      
      delete gateManager;
      delete learning;
      return true;
   }
   catch(...)
   {
      Print("ERROR: Exception during unified mode integration test");
      return false;
   }
}

//+------------------------------------------------------------------+
//| Test legacy mode compatibility                                  |
//+------------------------------------------------------------------+
bool TestLegacyModeCompatibility()
{
   try
   {
      // Create learning bridge
      CLearningBridge* learning = new CLearningBridge("TestData");
      
      // Create gate manager in legacy mode
      CGateManager* gateManager = new CGateManager("EURUSD", PERIOD_H1, learning, false);
      
      if(gateManager.IsUnifiedMode())
      {
         Print("ERROR: Legacy mode not working - unified mode still enabled");
         delete gateManager;
         delete learning;
         return false;
      }
      
      // Test that basic functionality still works
      TradingSignal signal;
      signal.id = "TEST_SIGNAL";
      signal.symbol = "EURUSD";
      signal.timeframe = PERIOD_H1;
      signal.timestamp = TimeCurrent();
      signal.price = 1.1000;
      signal.type = 0; // Buy
      signal.sl = 1.0950;
      signal.tp = 1.1100;
      signal.volume = 0.1;
      signal.confidence = 0.75;
      signal.volatility = 0.015;
      signal.correlation = 0.2;
      signal.regime = "trending";
      
      CSignalDecision decision;
      bool result = gateManager.ProcessSignal(signal, decision);
      
      if(!result)
      {
         Print("ERROR: Signal processing failed in legacy mode");
         delete gateManager;
         delete learning;
         return false;
      }
      
      if(VerboseOutput)
      {
         Print("Legacy mode enabled: ", !gateManager.IsUnifiedMode());
         Print("Signal processing result: ", result);
         Print("Decision executed: ", decision.executed);
      }
      
      delete gateManager;
      delete learning;
      return true;
   }
   catch(...)
   {
      Print("ERROR: Exception during legacy mode compatibility test");
      return false;
   }
}

//+------------------------------------------------------------------+
//| Test system monitoring functionality                            |
//+------------------------------------------------------------------+
bool TestSystemMonitoring()
{
   try
   {
      CSystemMonitor* monitor = CSystemMonitor::GetInstance();
      
      // Test health metrics
      SystemHealth health = monitor.GetSystemHealth();
      if(health.last_update == 0)
      {
         Print("ERROR: System health not initialized");
         return false;
      }
      
      // Test performance metrics
      PerformanceMetrics metrics = monitor.GetPerformanceMetrics();
      if(metrics.measurement_start == 0)
      {
         Print("ERROR: Performance metrics not initialized");
         return false;
      }
      
      // Test gate success rate (should be 0 initially)
      double successRate = monitor.GetGateSuccessRate(0);
      if(successRate < 0 || successRate > 1)
      {
         Print("ERROR: Invalid gate success rate: ", successRate);
         return false;
      }
      
      if(VerboseOutput)
      {
         Print("System health status: ", health.status);
         Print("Health last update: ", TimeToString(health.last_update));
         Print("Gate 0 success rate: ", successRate);
      }
      
      return true;
   }
   catch(...)
   {
      Print("ERROR: Exception during system monitoring test");
      return false;
   }
}

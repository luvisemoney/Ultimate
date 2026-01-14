//+------------------------------------------------------------------+
//| GateAudit.mqh - Strategy gating audit system                     |
//+------------------------------------------------------------------+
#property strict

class CGateAudit
{
private:
    string   m_expectedStrategies[];  // All expected strategies
    string   m_processedStrategies[]; // Strategies that passed gates
    string   m_skippedStrategies[];   // Strategies that were skipped
    datetime m_lastAuditTime;
    
public:
    // Initialize with list of expected strategies
    void Initialize(const string &strategies)
    {
        StringSplit(strategies, ',', m_expectedStrategies);
        // Start with a grace period: set last audit time to now so first audit is delayed
        m_lastAuditTime = TimeCurrent();
        ArrayResize(m_processedStrategies, 0);
        ArrayResize(m_skippedStrategies, 0);
        
        // Clean up strategy names
        for(int i=0; i<ArraySize(m_expectedStrategies); i++) {
            string s = m_expectedStrategies[i];
            StringTrimRight(s);
            StringTrimLeft(s);
            m_expectedStrategies[i] = s;
        }
            
        PrintFormat("GATE AUDIT: Initialized with %d strategies", ArraySize(m_expectedStrategies));
    }
    
    // Log when a strategy is processed through gates
    void LogStrategyProcessed(const string &strategyName)
    {
        int size = ArraySize(m_processedStrategies);
        ArrayResize(m_processedStrategies, size+1);
        m_processedStrategies[size] = strategyName;
    }
    
    // Run audit to check for skipped strategies
    void RunAudit()
    {
        // Only run audit every 15 minutes
        if(TimeCurrent() - m_lastAuditTime < 900) return;
        
        // Do not audit if nothing was processed in the last period (avoid false positives at startup)
        if(ArraySize(m_processedStrategies) == 0)
        {
            m_lastAuditTime = TimeCurrent();
            return;
        }
        
        // Reset skipped strategies
        ArrayResize(m_skippedStrategies, 0);
        
        // Find any expected strategies that weren't processed
        for(int i=0; i<ArraySize(m_expectedStrategies); i++)
        {
            string expected = m_expectedStrategies[i];
            bool found = false;
            
            for(int j=0; j<ArraySize(m_processedStrategies); j++)
            {
                if(m_processedStrategies[j] == expected)
                {
                    found = true;
                    break;
                }
            }
            
            if(!found)
            {
                int size = ArraySize(m_skippedStrategies);
                ArrayResize(m_skippedStrategies, size+1);
                m_skippedStrategies[size] = expected;
            }
        }
        
        // Log results
        if(ArraySize(m_skippedStrategies) > 0)
        {
            string skipList = "";
            for(int i=0; i<ArraySize(m_skippedStrategies); i++)
                skipList += (i>0 ? ", " : "") + m_skippedStrategies[i];
                
            PrintFormat("GATE AUDIT: %d strategies skipped - %s", 
                       ArraySize(m_skippedStrategies), skipList);
            
            // Warning only - do not shutdown on strategy skips
            // This is informational, not a critical error
            // Strategies may be skipped due to market conditions, not bugs
            if(ArraySize(m_skippedStrategies) > 5)
            {
                Print("WARNING: Many strategies skipped this period - check signal generation conditions");
            }
        }
        else
        {
            Print("GATE AUDIT: All strategies processed successfully");
        }
        
        // Reset processed list for next audit period
        ArrayResize(m_processedStrategies, 0);
        m_lastAuditTime = TimeCurrent();
    }
};

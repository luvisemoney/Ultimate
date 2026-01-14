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
    datetime m_firstInitTime;
    datetime m_lastAlertTime;
    bool     m_enabled;
    int      m_minSignals;
    int      m_minUptimeMinutes;
    int      m_alertCooldownMinutes;

    void ResetProcessed()
    {
        ArrayResize(m_processedStrategies, 0);
        ArrayResize(m_skippedStrategies, 0);
    }

public:
    CGateAudit()
    {
        m_lastAuditTime = 0;
        m_firstInitTime = 0;
        m_lastAlertTime = 0;
        m_enabled = true;
        m_minSignals = 0;
        m_minUptimeMinutes = 0;
        m_alertCooldownMinutes = 0;
    }

    // Initialize with list of expected strategies
    void Initialize(const string &strategies)
    {
        StringSplit(strategies, ',', m_expectedStrategies);
        // Start with a grace period: set last audit time to now so first audit is delayed
        m_lastAuditTime = TimeCurrent();
        m_firstInitTime = m_lastAuditTime;
        m_lastAlertTime = 0;
        ResetProcessed();
        
        // Clean up strategy names
        for(int i=0; i<ArraySize(m_expectedStrategies); i++) {
            string s = m_expectedStrategies[i];
            StringTrimRight(s);
            StringTrimLeft(s);
            m_expectedStrategies[i] = s;
        }
            
        PrintFormat("GATE AUDIT: Initialized with %d strategies", ArraySize(m_expectedStrategies));
    }

    void Configure(const int min_signals, const int min_uptime_minutes, const int alert_cooldown_minutes)
    {
        m_minSignals = MathMax(0, min_signals);
        m_minUptimeMinutes = MathMax(0, min_uptime_minutes);
        m_alertCooldownMinutes = MathMax(0, alert_cooldown_minutes);
    }

    void SetEnabled(const bool enabled)
    {
        m_enabled = enabled;
    }
    
    // Log when a strategy is processed through gates
    void LogStrategyProcessed(const string &strategyName)
    {
        int size = ArraySize(m_processedStrategies);
        ArrayResize(m_processedStrategies, size+1);
        m_processedStrategies[size] = strategyName;
    }
    
    // Run audit to check for skipped strategies (returns true when alert conditions met)
    bool RunAudit(string &skip_list, int &skip_count)
    {
        skip_list = "";
        skip_count = 0;
        datetime now = TimeCurrent();
        if(now - m_lastAuditTime < 900)
            return false;
        m_lastAuditTime = now;

        if(!m_enabled)
        {
            ResetProcessed();
            return false;
        }

        if(ArraySize(m_processedStrategies) == 0)
        {
            ResetProcessed();
            return false;
        }
        
        if(m_minSignals > 0 && ArraySize(m_processedStrategies) < m_minSignals)
        {
            ResetProcessed();
            return false;
        }

        if(m_minUptimeMinutes > 0 && (now - m_firstInitTime) < (m_minUptimeMinutes * 60))
        {
            ResetProcessed();
            return false;
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
        
        skip_count = ArraySize(m_skippedStrategies);
        if(skip_count == 0)
        {
            Print("GATE AUDIT: All strategies processed successfully");
            ResetProcessed();
            return false;
        }

        string skipList = "";
        for(int i=0; i<skip_count; i++)
            skipList += (i>0 ? ", " : "") + m_skippedStrategies[i];

        PrintFormat("GATE AUDIT: %d strategies skipped - %s", skip_count, skipList);
        if(skip_count > 5)
            Print("WARNING: Many strategies skipped this period - check signal generation conditions");

        skip_list = skipList;

        if(m_alertCooldownMinutes > 0 && m_lastAlertTime != 0 && (now - m_lastAlertTime) < (m_alertCooldownMinutes * 60))
        {
            ResetProcessed();
            return false;
        }

        m_lastAlertTime = now;
        ResetProcessed();
        return true;
    }

    // Backwards-compatible overload for legacy callers
    bool RunAudit()
    {
        string dummy;
        int count = 0;
        return RunAudit(dummy, count);
    }
};

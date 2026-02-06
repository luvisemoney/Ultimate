//+------------------------------------------------------------------+
//| GateLearningSystem.mqh - Gate Learning and Auto-Tuning            |
//| Manages gate threshold learning and adaptive adjustments           |
//+------------------------------------------------------------------+
#ifndef GATELEARNINGSYSTEM_MQH
#define GATELEARNINGSYSTEM_MQH

#include "CGateBase.mqh"

//+------------------------------------------------------------------+
//| Gate Learning System Class                                         |
//+------------------------------------------------------------------+
class CGateLearningSystem
{
private:
   bool              m_autoAdjust;
   double            m_learningRate;
   int               m_minSamples;
   int               m_sampleCounts[8];
   double            m_successRates[8];

public:
   // Constructor
   CGateLearningSystem(bool autoAdjust = true, double learningRate = 0.05)
   {
      m_autoAdjust = autoAdjust;
      m_learningRate = learningRate;
      m_minSamples = 20;

      for (int i = 0; i < 8; i++)
      {
         m_sampleCounts[i] = 0;
         m_successRates[i] = 0.5;
      }
   }

   // Destructor
   ~CGateLearningSystem() {}

   // Record gate outcome for learning
   void RecordOutcome(int gateIndex, bool passed, double profitLoss = 0)
   {
      if (gateIndex < 0 || gateIndex >= 8) return;

      m_sampleCounts[gateIndex]++;

      // Update success rate with exponential moving average
      double alpha = m_learningRate;
      if (passed && profitLoss > 0)
         m_successRates[gateIndex] = (1 - alpha) * m_successRates[gateIndex] + alpha * 1.0;
      else if (!passed)
         m_successRates[gateIndex] = (1 - alpha) * m_successRates[gateIndex] + alpha * 0.0;
   }

   // Get recommended threshold adjustment for a gate
   double GetThresholdAdjustment(int gateIndex)
   {
      if (gateIndex < 0 || gateIndex >= 8) return 0.0;
      if (m_sampleCounts[gateIndex] < m_minSamples) return 0.0;

      // Adjust threshold based on success rate
      double targetRate = 0.6; // Target 60% pass rate
      double currentRate = m_successRates[gateIndex];

      // If too strict, lower threshold; if too loose, raise threshold
      return (currentRate - targetRate) * 0.1;
   }

   // Print learning report
   void PrintReport()
   {
      Print("=== Gate Learning Report ===");
      for (int i = 0; i < 8; i++)
      {
         Print(StringFormat("Gate %d: samples=%d, success_rate=%.2f%%, adjustment=%.4f",
                           i + 1, m_sampleCounts[i], m_successRates[i] * 100,
                           GetThresholdAdjustment(i)));
      }
   }

   // Save learning data
   void SaveLearningData()
   {
      // Stub - would save to file in full implementation
   }

   // Enable/disable auto-adjustment
   void SetAutoAdjust(bool enabled) { m_autoAdjust = enabled; }
   bool GetAutoAdjust() const { return m_autoAdjust; }

   // Set learning rate
   void SetLearningRate(double rate) { m_learningRate = rate; }
   double GetLearningRate() const { return m_learningRate; }

   // Set minimum samples before adjustment
   void SetMinSamples(int samples) { m_minSamples = samples; }
   int GetMinSamples() const { return m_minSamples; }
};

#endif // GATELEARNINGSYSTEM_MQH

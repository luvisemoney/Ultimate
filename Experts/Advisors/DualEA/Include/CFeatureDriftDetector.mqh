//+------------------------------------------------------------------+
//| CFeatureDriftDetector.mqh - Feature Drift Detection System       |
//| P2-1: Concept drift auto-adjustment for gate system              |
//+------------------------------------------------------------------+
#ifndef CFEATUREDRIFTDETECTOR_MQH
#define CFEATUREDRIFTDETECTOR_MQH

//+------------------------------------------------------------------+
//| Drift Statistics Structure                                        |
//+------------------------------------------------------------------+
struct SDriftStats
{
   string   feature_name;
   double   mean;
   double   variance;
   double   min_val;
   double   max_val;
   int      sample_count;
   datetime last_update;
   bool     drift_detected;
   double   drift_score;
};

//+------------------------------------------------------------------+
//| Feature Drift Detector Class                                    |
//+------------------------------------------------------------------+
class CFeatureDriftDetector
{
private:
   SDriftStats      m_stats[];
   int              m_feature_count;
   double           m_drift_threshold;
   int              m_min_samples;
   bool             m_initialized;
   
   int FindFeatureIndex(const string feature_name)
   {
      for(int i = 0; i < m_feature_count; i++)
      {
         if(m_stats[i].feature_name == feature_name)
            return i;
      }
      return -1;
   }
   
   double CalculateZScore(double value, double mean, double variance)
   {
      if(variance < 1e-10) return 0.0;
      return (value - mean) / MathSqrt(variance);
   }
   
public:
   CFeatureDriftDetector()
   {
      m_feature_count = 0;
      m_drift_threshold = 3.0;  // 3 sigma threshold
      m_min_samples = 30;
      m_initialized = false;
      ArrayResize(m_stats, 0);
   }
   
   ~CFeatureDriftDetector()
   {
      ArrayResize(m_stats, 0);
   }
   
   bool Initialize(double drift_threshold = 3.0, int min_samples = 30)
   {
      m_drift_threshold = drift_threshold;
      m_min_samples = min_samples;
      m_initialized = true;
      Print("[FeatureDriftDetector] Initialized with threshold: " + DoubleToString(drift_threshold, 2));
      return true;
   }
   
   void Shutdown()
   {
      ArrayResize(m_stats, 0);
      m_feature_count = 0;
      m_initialized = false;
   }
   
   void RecordSample(const string feature_name, double value)
   {
      int idx = FindFeatureIndex(feature_name);
      
      if(idx < 0)
      {
         // Create new feature entry
         idx = m_feature_count;
         ArrayResize(m_stats, idx + 1);
         m_stats[idx].feature_name = feature_name;
         m_stats[idx].mean = value;
         m_stats[idx].variance = 0.0;
         m_stats[idx].min_val = value;
         m_stats[idx].max_val = value;
         m_stats[idx].sample_count = 1;
         m_stats[idx].last_update = TimeCurrent();
         m_stats[idx].drift_detected = false;
         m_stats[idx].drift_score = 0.0;
         m_feature_count++;
      }
      else
      {
         // Update existing statistics using Welford's online algorithm
         SDriftStats &s = m_stats[idx];
         s.sample_count++;
         
         double delta = value - s.mean;
         s.mean += delta / s.sample_count;
         double delta2 = value - s.mean;
         s.variance = ((s.sample_count - 1) * s.variance + delta * delta2) / s.sample_count;
         
         s.min_val = MathMin(s.min_val, value);
         s.max_val = MathMax(s.max_val, value);
         s.last_update = TimeCurrent();
         
         // Check for drift
         if(s.sample_count >= m_min_samples)
         {
            double zscore = CalculateZScore(value, s.mean, s.variance);
            s.drift_score = MathAbs(zscore);
            s.drift_detected = (s.drift_score > m_drift_threshold);
         }
      }
   }
   
   bool IsDriftDetected(const string feature_name)
   {
      int idx = FindFeatureIndex(feature_name);
      if(idx < 0) return false;
      return m_stats[idx].drift_detected;
   }
   
   bool IsAnyDriftDetected()
   {
      for(int i = 0; i < m_feature_count; i++)
      {
         if(m_stats[i].drift_detected)
            return true;
      }
      return false;
   }
   
   double GetDriftScore(const string feature_name)
   {
      int idx = FindFeatureIndex(feature_name);
      if(idx < 0) return 0.0;
      return m_stats[idx].drift_score;
   }
   
   void GetDriftReport(string &report)
   {
      report = "=== Feature Drift Report ===\n";
      int drift_count = 0;
      
      for(int i = 0; i < m_feature_count; i++)
      {
         if(m_stats[i].drift_detected)
         {
            drift_count++;
            report += m_stats[i].feature_name + ": score=" + DoubleToString(m_stats[i].drift_score, 2) + 
                     " (threshold=" + DoubleToString(m_drift_threshold, 2) + ")\n";
         }
      }
      
      if(drift_count == 0)
         report += "No drift detected in " + IntegerToString(m_feature_count) + " features\n";
   }
   
   void Reset()
   {
      for(int i = 0; i < m_feature_count; i++)
      {
         m_stats[i].drift_detected = false;
         m_stats[i].drift_score = 0.0;
         m_stats[i].sample_count = 0;
         m_stats[i].mean = 0.0;
         m_stats[i].variance = 0.0;
      }
   }
   
   int GetFeatureCount() const { return m_feature_count; }
   bool IsInitialized() const { return m_initialized; }
};

// Global instance for P0-P5 integration
CFeatureDriftDetector* g_feature_drift_detector = NULL;

#endif // CFEATUREDRIFTDETECTOR_MQH

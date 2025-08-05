//+------------------------------------------------------------------+
//| IntervalEvaluator.mqh - Time-based evaluation system for EscapeEA |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include "..\Common\Enums.mqh"
#include "..\Common\Structs.mqh"
#include "..\Common\Constants.mqh"

//+------------------------------------------------------------------+
//| Interval evaluation result structure                             |
//+------------------------------------------------------------------+
struct SIntervalResult
  {
   datetime          startTime;         // Interval start time
   datetime          endTime;           // Interval end time
   int               totalTrades;       // Total trades in interval
   int               successfulTrades;  // Successful trades
   double            winRate;           // Win rate for interval
   double            totalProfit;       // Total profit/loss
   double            avgConfidence;     // Average signal confidence
   bool              meetsMinTrades;    // Meets minimum trade requirement
   STradeSignal      topSignals[];      // Top ranked signals
   
   // Constructor
   SIntervalResult() : startTime(0), endTime(0), totalTrades(0), successfulTrades(0),
                      winRate(0.0), totalProfit(0.0), avgConfidence(0.0), meetsMinTrades(false) {}
  };

//+------------------------------------------------------------------+
//| Interval Evaluator Class                                         |
//+------------------------------------------------------------------+
class CIntervalEvaluator
  {
private:
   int               m_intervalMinutes;     // Evaluation interval in minutes
   int               m_minTradesRequired;   // Minimum trades per interval
   int               m_maxSignalsToSend;    // Maximum signals to broadcast
   datetime          m_lastEvaluationTime; // Last evaluation timestamp
   datetime          m_currentIntervalStart; // Current interval start
   
   STradeRecord      m_intervalTrades[];   // Trades in current interval
   STradeSignal      m_intervalSignals[];  // Signals in current interval
   
   // Private methods
   bool              IsIntervalComplete();
   void              StartNewInterval();
   double            CalculateSignalScore(const STradeSignal &signal, const STradeRecord &trades[]);
   void              RankSignals(STradeSignal &signals[]);
   bool              ValidateInterval(const SIntervalResult &result);
   
public:
   // Constructor
                     CIntervalEvaluator(int intervalMinutes = 15, int minTrades = 10, int maxSignals = 10);
   
   // Main evaluation methods
   bool              AddTrade(const STradeRecord &trade);
   bool              AddSignal(const STradeSignal &signal);
   bool              ShouldEvaluate();
   SIntervalResult   EvaluateInterval();
   
   // Getters
   datetime          GetLastEvaluationTime() const { return m_lastEvaluationTime; }
   datetime          GetCurrentIntervalStart() const { return m_currentIntervalStart; }
   int               GetCurrentTradeCount() const { return ArraySize(m_intervalTrades); }
   int               GetCurrentSignalCount() const { return ArraySize(m_intervalSignals); }
   
   // Setters
   void              SetIntervalMinutes(int minutes) { m_intervalMinutes = minutes; }
   void              SetMinTradesRequired(int trades) { m_minTradesRequired = trades; }
   void              SetMaxSignalsToSend(int signals) { m_maxSignalsToSend = signals; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CIntervalEvaluator::CIntervalEvaluator(int intervalMinutes = 15, int minTrades = 10, int maxSignals = 10) :
   m_intervalMinutes(intervalMinutes),
   m_minTradesRequired(minTrades),
   m_maxSignalsToSend(maxSignals),
   m_lastEvaluationTime(0)
  {
   StartNewInterval();
   Print("IntervalEvaluator initialized: ", m_intervalMinutes, " min intervals, ", 
         m_minTradesRequired, " min trades, ", m_maxSignalsToSend, " max signals");
  }

//+------------------------------------------------------------------+
//| Check if current interval is complete                            |
//+------------------------------------------------------------------+
bool CIntervalEvaluator::IsIntervalComplete()
  {
   datetime currentTime = TimeCurrent();
   datetime intervalEnd = m_currentIntervalStart + (m_intervalMinutes * 60);
   
   return currentTime >= intervalEnd;
  }

//+------------------------------------------------------------------+
//| Start a new evaluation interval                                  |
//+------------------------------------------------------------------+
void CIntervalEvaluator::StartNewInterval()
  {
   m_currentIntervalStart = TimeCurrent();
   
   // Clear interval data
   ArrayResize(m_intervalTrades, 0);
   ArrayResize(m_intervalSignals, 0);
   
   Print("New evaluation interval started: ", TimeToString(m_currentIntervalStart, TIME_DATE|TIME_SECONDS));
  }

//+------------------------------------------------------------------+
//| Add trade to current interval                                    |
//+------------------------------------------------------------------+
bool CIntervalEvaluator::AddTrade(const STradeRecord &trade)
  {
   // Validate trade timestamp is within current interval
   if(trade.openTime < m_currentIntervalStart)
     {
      Print("Trade timestamp is before current interval start");
      return false;
     }
   
   // Add to interval trades
   int size = ArraySize(m_intervalTrades);
   ArrayResize(m_intervalTrades, size + 1);
   m_intervalTrades[size] = trade;
   
   return true;
  }

//+------------------------------------------------------------------+
//| Add signal to current interval                                   |
//+------------------------------------------------------------------+
bool CIntervalEvaluator::AddSignal(const STradeSignal &signal)
  {
   // Validate signal timestamp is within current interval
   if(signal.timestamp < m_currentIntervalStart)
     {
      Print("Signal timestamp is before current interval start");
      return false;
     }
   
   // Add to interval signals
   int size = ArraySize(m_intervalSignals);
   ArrayResize(m_intervalSignals, size + 1);
   m_intervalSignals[size] = signal;
   
   return true;
  }

//+------------------------------------------------------------------+
//| Check if evaluation should be performed                          |
//+------------------------------------------------------------------+
bool CIntervalEvaluator::ShouldEvaluate()
  {
   return IsIntervalComplete();
  }

//+------------------------------------------------------------------+
//| Calculate signal score based on historical performance           |
//+------------------------------------------------------------------+
double CIntervalEvaluator::CalculateSignalScore(const STradeSignal &signal, const STradeRecord &trades[])
  {
   double score = signal.confidence; // Base score from confidence
   
   // Enhance score based on historical performance
   int matchingTrades = 0;
   double totalProfit = 0.0;
   
   for(int i = 0; i < ArraySize(trades); i++)
     {
      // Check if trade matches signal characteristics
      if(trades[i].signal == signal.signal && 
         trades[i].symbol == signal.symbol &&
         MathAbs(trades[i].confidence - signal.confidence) < 0.1)
        {
         matchingTrades++;
         totalProfit += trades[i].profit;
        }
     }
   
   // Adjust score based on historical performance
   if(matchingTrades > 0)
     {
      double avgProfit = totalProfit / matchingTrades;
      double profitFactor = (avgProfit > 0) ? 1.2 : 0.8;
      score *= profitFactor;
     }
   
   // Factor in risk-reward ratio
   if(signal.riskReward > 0)
     {
      score *= MathMin(signal.riskReward / 2.0, 1.5); // Cap at 1.5x boost
     }
   
   // Ensure score stays within bounds
   return MathMax(0.0, MathMin(1.0, score));
  }

//+------------------------------------------------------------------+
//| Rank signals by performance score                                |
//+------------------------------------------------------------------+
void CIntervalEvaluator::RankSignals(STradeSignal &signals[])
  {
   int count = ArraySize(signals);
   if(count <= 1) return;
   
   // Calculate scores for all signals
   double scores[];
   ArrayResize(scores, count);
   
   for(int i = 0; i < count; i++)
      scores[i] = CalculateSignalScore(signals[i], m_intervalTrades);
   
   // Simple bubble sort by score (descending)
   for(int i = 0; i < count - 1; i++)
     {
      for(int j = 0; j < count - i - 1; j++)
        {
         if(scores[j] < scores[j + 1])
           {
            // Swap signals
            STradeSignal tempSignal = signals[j];
            signals[j] = signals[j + 1];
            signals[j + 1] = tempSignal;
            
            // Swap scores
            double tempScore = scores[j];
            scores[j] = scores[j + 1];
            scores[j + 1] = tempScore;
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Validate interval results                                        |
//+------------------------------------------------------------------+
bool CIntervalEvaluator::ValidateInterval(const SIntervalResult &result)
  {
   // Check if interval meets minimum requirements
   if(result.totalTrades < m_minTradesRequired)
     {
      Print("Interval validation failed: Insufficient trades (", result.totalTrades, " < ", m_minTradesRequired, ")");
      return false;
     }
   
   // Check if interval duration is correct
   int intervalDuration = (int)(result.endTime - result.startTime) / 60;
   if(intervalDuration != m_intervalMinutes)
     {
      Print("Interval validation failed: Incorrect duration (", intervalDuration, " != ", m_intervalMinutes, ")");
      return false;
     }
   
   // Check win rate is reasonable
   if(result.winRate < 0.0 || result.winRate > 1.0)
     {
      Print("Interval validation failed: Invalid win rate (", result.winRate, ")");
      return false;
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Evaluate current interval and return results                     |
//+------------------------------------------------------------------+
SIntervalResult CIntervalEvaluator::EvaluateInterval()
  {
   SIntervalResult result;
   
   // Set interval timeframe
   result.startTime = m_currentIntervalStart;
   result.endTime = TimeCurrent();
   
   // Calculate basic statistics
   result.totalTrades = ArraySize(m_intervalTrades);
   result.successfulTrades = 0;
   result.totalProfit = 0.0;
   result.avgConfidence = 0.0;
   
   // Analyze trades
   for(int i = 0; i < result.totalTrades; i++)
     {
      if(m_intervalTrades[i].profit > 0)
         result.successfulTrades++;
      
      result.totalProfit += m_intervalTrades[i].profit;
      result.avgConfidence += m_intervalTrades[i].confidence;
     }
   
   // Calculate derived metrics
   result.winRate = (result.totalTrades > 0) ? 
                   (double)result.successfulTrades / result.totalTrades : 0.0;
   
   result.avgConfidence = (result.totalTrades > 0) ? 
                         result.avgConfidence / result.totalTrades : 0.0;
   
   result.meetsMinTrades = (result.totalTrades >= m_minTradesRequired);
   
   // Select and rank top signals
   if(ArraySize(m_intervalSignals) > 0)
     {
      // Copy signals for ranking
      STradeSignal signalsToRank[];
      int signalCount = ArraySize(m_intervalSignals);
      ArrayResize(signalsToRank, signalCount);
      
      for(int i = 0; i < signalCount; i++)
         signalsToRank[i] = m_intervalSignals[i];
      
      // Rank signals by performance
      RankSignals(signalsToRank);
      
      // Select top signals
      int topCount = MathMin(m_maxSignalsToSend, signalCount);
      ArrayResize(result.topSignals, topCount);
      
      for(int i = 0; i < topCount; i++)
         result.topSignals[i] = signalsToRank[i];
     }
   
   // Validate results
   if(!ValidateInterval(result))
     {
      Print("Interval evaluation failed validation");
      result.meetsMinTrades = false;
     }
   
   // Update evaluation timestamp
   m_lastEvaluationTime = TimeCurrent();
   
   // Log evaluation results
   Print("Interval evaluated: ", result.totalTrades, " trades, ", 
         DoubleToString(result.winRate * 100, 1), "% win rate, ",
         ArraySize(result.topSignals), " top signals selected");
   
   // Start new interval
   StartNewInterval();
   
   return result;
  }
//+------------------------------------------------------------------+
//|                                          CorrelationMatrix.mqh    |
//|                        Copyright 2025, Your Company Name          |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company Name"
#property link      "https://www.yoursite.com"
#property version   "1.00"
#property strict

#include <Arrays\ArrayObj.mqh>
#include <Math\Stat\Math.mqh>

// Forward declaration
class CCorrelationMatrix;

//+------------------------------------------------------------------+
//| Correlation Pair Structure                                       |
//+------------------------------------------------------------------+
struct SCorrelationPair
{
   string         symbol1;       // First symbol
   string         symbol2;       // Second symbol
   double         correlation;    // Correlation coefficient (-1 to 1)
   int            period;         // Lookback period (bars)
   ENUM_TIMEFRAME timeframe;      // Timeframe for calculation
   datetime       lastUpdate;     // Last update time
   
   // Constructor
   SCorrelationPair() : symbol1(""), symbol2(""), correlation(0.0), 
                       period(0), timeframe(PERIOD_CURRENT), lastUpdate(0) {}
   
   SCorrelationPair(string s1, string s2, int p, ENUM_TIMEFRAME tf) : 
      symbol1(s1), symbol2(s2), correlation(0.0), period(p), timeframe(tf), lastUpdate(0) {}
   
   // Comparison operator
   bool operator==(const SCorrelationPair &other) const
   {
      return ((symbol1 == other.symbol1 && symbol2 == other.symbol2) ||
              (symbol1 == other.symbol2 && symbol2 == other.symbol1)) &&
              period == other.period && timeframe == other.timeframe;
   }
};

//+------------------------------------------------------------------+
//| Correlation Matrix Class                                         |
//+------------------------------------------------------------------+
class CCorrelationMatrix
{
private:
   CArrayObj*        m_pairs;           // Array of correlation pairs
   string            m_symbols[];       // Array of symbols being tracked
   int               m_lookback;        // Default lookback period (bars)
   ENUM_TIMEFRAME    m_timeframe;       // Default timeframe
   double            m_minCorrelation;  // Minimum correlation to track
   bool              m_isInitialized;   // Initialization flag
   
   // Private methods
   bool              CalculateCorrelation(SCorrelationPair &pair);
   int               FindPair(const string symbol1, const string symbol2) const;
   bool              UpdateSymbolList();
   
public:
   // Constructor/Destructor
                     CCorrelationMatrix();
                    ~CCorrelationMatrix();
   
   // Initialization
   bool              Initialize(const int lookback = 100, 
                              const ENUM_TIMEFRAME timeframe = PERIOD_CURRENT,
                              const double minCorrelation = 0.5);
   void              Deinitialize();
   
   // Update methods
   bool              Update();
   bool              UpdatePair(const string symbol1, const string symbol2);
   
   // Correlation access
   double            GetCorrelation(const string symbol1, const string symbol2);
   bool              GetCorrelationMatrix(const string &symbols[], double &matrix[][]);
   
   // Risk management
   bool              ValidateNewPosition(const string symbol, const ENUM_ORDER_TYPE type,
                                       const double price, const double size);
   
   // Getters
   int               GetSymbolCount() const { return ArraySize(m_symbols); }
   int               GetPairCount() const { return (m_pairs != NULL) ? m_pairs.Total() : 0; }
   bool              IsInitialized() const { return m_isInitialized; }
   
   // Configuration
   bool              SetLookback(const int lookback);
   bool              SetTimeframe(const ENUM_TIMEFRAME timeframe);
   void              SetMinCorrelation(const double minCorrelation) { m_minCorrelation = minCorrelation; }
   
   // Utility
   static double     CalculateCorrelation(const double &x[], const double &y[], const int count);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CCorrelationMatrix::CCorrelationMatrix() :
   m_pairs(NULL),
   m_lookback(100),
   m_timeframe(PERIOD_CURRENT),
   m_minCorrelation(0.5),
   m_isInitialized(false)
{
   ArrayResize(m_symbols, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CCorrelationMatrix::~CCorrelationMatrix()
{
   Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize correlation matrix                                    |
//+------------------------------------------------------------------+
bool CCorrelationMatrix::Initialize(const int lookback, const ENUM_TIMEFRAME timeframe,
                                  const double minCorrelation)
{
   if (m_isInitialized)
      return true;
      
   if (lookback <= 0 || minCorrelation < 0.0 || minCorrelation > 1.0)
      return false;
      
   m_pairs = new CArrayObj();
   if (m_pairs == NULL)
      return false;
      
   m_lookback = lookback;
   m_timeframe = timeframe;
   m_minCorrelation = minCorrelation;
   
   // Update symbol list
   if (!UpdateSymbolList())
   {
      Print("Failed to update symbol list");
      return false;
   }
   
   m_isInitialized = true;
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize correlation matrix                                  |
//+------------------------------------------------------------------+
void CCorrelationMatrix::Deinitialize()
{
   if (m_pairs != NULL)
   {
      m_pairs.Clear();
      delete m_pairs;
      m_pairs = NULL;
   }
   
   ArrayFree(m_symbols);
   m_isInitialized = false;
}

//+------------------------------------------------------------------+
//| Update all correlation pairs                                     |
//+------------------------------------------------------------------+
bool CCorrelationMatrix::Update()
{
   if (!m_isInitialized)
      return false;
      
   // Update symbol list first
   if (!UpdateSymbolList())
      return false;
      
   int symbolCount = ArraySize(m_symbols);
   if (symbolCount < 2)
      return false;
      
   // Update all pairs
   bool success = true;
   for (int i = 0; i < symbolCount - 1; i++)
   {
      for (int j = i + 1; j < symbolCount; j++)
      {
         if (!UpdatePair(m_symbols[i], m_symbols[j]))
            success = false;
      }
   }
   
   return success;
}

//+------------------------------------------------------------------+
//| Update correlation for a specific pair                           |
//+------------------------------------------------------------------+
bool CCorrelationMatrix::UpdatePair(const string symbol1, const string symbol2)
{
   if (!m_isInitialized || symbol1 == "" || symbol2 == "" || symbol1 == symbol2)
      return false;
      
   // Find or create the correlation pair
   int pairIndex = FindPair(symbol1, symbol2);
   SCorrelationPair* pair = NULL;
   
   if (pairIndex >= 0)
   {
      pair = (SCorrelationPair*)m_pairs.At(pairIndex);
   }
   else
   {
      pair = new SCorrelationPair(symbol1, symbol2, m_lookback, m_timeframe);
      if (pair == NULL)
         return false;
         
      m_pairs.Add(pair);
   }
   
   // Calculate correlation
   return CalculateCorrelation(*pair);
}

//+------------------------------------------------------------------+
//| Calculate correlation for a pair                                 |
//+------------------------------------------------------------------+
bool CCorrelationMatrix::CalculateCorrelation(SCorrelationPair &pair)
{
   if (pair.symbol1 == "" || pair.symbol2 == "" || pair.period <= 0)
      return false;
      
   // Get close prices for both symbols
   double close1[], close2[];
   int count = pair.period;
   
   if (CopyClose(pair.symbol1, pair.timeframe, 0, count, close1) != count ||
       CopyClose(pair.symbol2, pair.timeframe, 0, count, close2) != count)
   {
      Print("Failed to get price data for correlation calculation");
      return false;
   }
   
   // Calculate returns
   double returns1[], returns2[];
   ArrayResize(returns1, count-1);
   ArrayResize(returns2, count-1);
   
   for (int i = 0; i < count-1; i++)
   {
      if (close1[i+1] > 0.0 && close2[i+1] > 0.0)
      {
         returns1[i] = (close1[i] - close1[i+1]) / close1[i+1];
         returns2[i] = (close2[i] - close2[i+1]) / close2[i+1];
      }
      else
      {
         returns1[i] = 0.0;
         returns2[i] = 0.0;
      }
   }
   
   // Calculate correlation
   pair.correlation = CalculateCorrelation(returns1, returns2, count-1);
   pair.lastUpdate = TimeCurrent();
   
   return true;
}

//+------------------------------------------------------------------+
//| Find correlation pair in the list                                |
//+------------------------------------------------------------------+
int CCorrelationMatrix::FindPair(const string symbol1, const string symbol2) const
{
   if (!m_isInitialized || m_pairs == NULL)
      return -1;
      
   SCorrelationPair tempPair(symbol1, symbol2, m_lookback, m_timeframe);
   
   for (int i = 0; i < m_pairs.Total(); i++)
   {
      SCorrelationPair* pair = (SCorrelationPair*)m_pairs.At(i);
      if (pair != NULL && *pair == tempPair)
         return i;
   }
   
   return -1;
}

//+------------------------------------------------------------------+
//| Update the list of symbols being tracked                         |
//+------------------------------------------------------------------+
bool CCorrelationMatrix::UpdateSymbolList()
{
   // This is a simplified implementation
   // In practice, you might want to get symbols from market watch or a predefined list
   
   // For now, we'll just use a few major currency pairs
   string defaultSymbols[] = {"EURUSD", "GBPUSD", "USDJPY", "AUDUSD", "USDCAD", "USDCHF", "NZDUSD"};
   
   // Check which symbols are available
   string availableSymbols[];
   int count = 0;
   
   for (int i = 0; i < ArraySize(defaultSymbols); i++)
   {
      if (SymbolSelect(defaultSymbols[i], true))
      {
         count++;
         ArrayResize(availableSymbols, count);
         availableSymbols[count-1] = defaultSymbols[i];
      }
   }
   
   // Update symbols array
   if (count > 0)
   {
      ArrayCopy(m_symbols, availableSymbols);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get correlation between two symbols                              |
//+------------------------------------------------------------------+
double CCorrelationMatrix::GetCorrelation(const string symbol1, const string symbol2)
{
   if (!m_isInitialized || symbol1 == "" || symbol2 == "" || symbol1 == symbol2)
      return 0.0;
      
   int pairIndex = FindPair(symbol1, symbol2);
   if (pairIndex >= 0)
   {
      SCorrelationPair* pair = (SCorrelationPair*)m_pairs.At(pairIndex);
      if (pair != NULL)
         return pair.correlation;
   }
   
   // If pair not found, try to calculate it
   if (UpdatePair(symbol1, symbol2))
   {
      pairIndex = FindPair(symbol1, symbol2);
      if (pairIndex >= 0)
      {
         SCorrelationPair* pair = (SCorrelationPair*)m_pairs.At(pairIndex);
         if (pair != NULL)
            return pair.correlation;
      }
   }
   
   return 0.0;
}

//+------------------------------------------------------------------+
//| Get full correlation matrix                                      |
//+------------------------------------------------------------------+
bool CCorrelationMatrix::GetCorrelationMatrix(const string &symbols[], double &matrix[][])
{
   if (!m_isInitialized || ArraySize(symbols) < 2)
      return false;
      
   int size = ArraySize(symbols);
   ArrayResize(matrix, size);
   
   for (int i = 0; i < size; i++)
   {
      ArrayResize(matrix[i], size);
      matrix[i][i] = 1.0; // Correlation with self is 1
      
      for (int j = i + 1; j < size; j++)
      {
         double corr = GetCorrelation(symbols[i], symbols[j]);
         matrix[i][j] = corr;
         matrix[j][i] = corr; // Matrix is symmetric
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Validate if a new position would exceed correlation limits       |
//+------------------------------------------------------------------+
bool CCorrelationMatrix::ValidateNewPosition(const string symbol, const ENUM_ORDER_TYPE type,
                                           const double price, const double size)
{
   if (!m_isInitialized || symbol == "" || size <= 0.0)
      return false;
      
   // This is a simplified implementation
   // In practice, you would check correlation with all existing positions
   
   return true; // Placeholder
}

//+------------------------------------------------------------------+
//| Set lookback period for correlation calculation                  |
//+------------------------------------------------------------------+
bool CCorrelationMatrix::SetLookback(const int lookback)
{
   if (lookback <= 0)
      return false;
      
   m_lookback = lookback;
   
   // Update all pairs
   if (m_pairs != NULL)
   {
      for (int i = 0; i < m_pairs.Total(); i++)
      {
         SCorrelationPair* pair = (SCorrelationPair*)m_pairs.At(i);
         if (pair != NULL)
            pair.period = lookback;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Set timeframe for correlation calculation                        |
//+------------------------------------------------------------------+
bool CCorrelationMatrix::SetTimeframe(const ENUM_TIMEFRAME timeframe)
{
   m_timeframe = timeframe;
   
   // Update all pairs
   if (m_pairs != NULL)
   {
      for (int i = 0; i < m_pairs.Total(); i++)
      {
         SCorrelationPair* pair = (SCorrelationPair*)m_pairs.At(i);
         if (pair != NULL)
            pair.timeframe = timeframe;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Static method to calculate correlation between two arrays        |
//+------------------------------------------------------------------+
double CCorrelationMatrix::CalculateCorrelation(const double &x[], const double &y[], const int count)
{
   if (count <= 1)
      return 0.0;
      
   double sumX = 0.0, sumY = 0.0;
   double sumXSq = 0.0, sumYSq = 0.0;
   double sumXY = 0.0;
   
   for (int i = 0; i < count; i++)
   {
      sumX += x[i];
      sumY += y[i];
      sumXSq += x[i] * x[i];
      sumYSq += y[i] * y[i];
      sumXY += x[i] * y[i];
   }
   
   double numerator = sumXY - (sumX * sumY / count);
   double denominator = MathSqrt((sumXSq - (sumX * sumX / count)) * (sumYSq - (sumY * sumY / count)));
   
   if (denominator == 0.0)
      return 0.0;
      
   return numerator / denominator;
}

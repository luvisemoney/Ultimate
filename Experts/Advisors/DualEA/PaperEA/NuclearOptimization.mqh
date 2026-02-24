//+------------------------------------------------------------------+
//| NuclearOptimization.mqh - 100-Level MQL5-Compatible Optimization |
//| Copyright DualEA - Nuclear Grade Implementation                  |
//| Version 3.0.0                                                    |
//+------------------------------------------------------------------+
#property copyright "DualEA - Nuclear Grade Implementation"
#property version   "3.0.0"
#property strict

//+------------------------------------------------------------------+
//| MEMORY-OPTIMIZED CONFIGURATION BLOCK                            |
//+------------------------------------------------------------------+
struct SConfigBlock {
    string signature;              // "DUAL"
    int version;                   // 3
    int strategy_count;            // 23
    int risk_profile;              // 0-100 (85 for AGGRESSIVE)
    double max_drawdown;           // 0.15 default
    double kelly_fraction;         // 0.25 default
    int correlation_window;        // 252
    int volatility_window;         // 21
    bool enable_ml;                // true
    bool enable_news_filter;       // true
    bool enable_regime_switch;     // true
};

//+------------------------------------------------------------------+
//| RING BUFFER - MQL5 Compatible String-Based Implementation         |
//| FIXED: Using string array instead of SPolicyState (not defined)   |
//+------------------------------------------------------------------+
class CRingBuffer {
private:
    string m_buffer[1024];  // Store serialized data as strings
    int m_capacity;
    int m_head;
    int m_tail;
    int m_count;
    
public:
    CRingBuffer(int capacity = 1024) : m_capacity(capacity), m_head(0), m_tail(0), m_count(0) {
        if(capacity > 1024) m_capacity = 1024;  // Cap at 1024
    }
    
    ~CRingBuffer() {
        // No ArrayFree needed for fixed array
    }
    
    bool Push(const string &item) {
        if(m_count >= m_capacity) return false;
        
        m_buffer[m_tail] = item;
        m_tail = (m_tail + 1) % m_capacity;
        m_count++;
        return true;
    }
    
    bool Pop(string &item) {
        if(m_count <= 0) return false;
        
        item = m_buffer[m_head];
        m_head = (m_head + 1) % m_capacity;
        m_count--;
        return true;
    }
    
    int Count() const { return m_count; }
    bool IsFull() const { return m_count >= m_capacity; }
    bool IsEmpty() const { return m_count <= 0; }
    void Clear() { m_head = 0; m_tail = 0; m_count = 0; }
};

//+------------------------------------------------------------------+
//| OPTIMIZED CORRELATION ENGINE - 23-Strategy Matrix               |
//+------------------------------------------------------------------+
class COptimizedCorrelationEngine {
private:
    double m_correlation_cache[23][23];
    double m_price_matrix[23][252];  // 23 strategies × 252-day window
    int m_window_size;
    int m_num_strategies;
    datetime m_last_update;
    
public:
    COptimizedCorrelationEngine() {
        m_window_size = 252;
        m_num_strategies = 23;
        m_last_update = 0;
        ArrayInitialize(m_correlation_cache, 0.0);
        ArrayInitialize(m_price_matrix, 0.0);
    }
    
    // Optimized Pearson correlation with cache - compute inline from source matrix
    // First dimension must be dynamic in MQL5 function parameters
    void CalculateCorrelations(const double &prices[][252]) {
        for(int i = 0; i < m_num_strategies; i++) {
            for(int j = i; j < m_num_strategies; j++) {
                double sum_x = 0, sum_y = 0, sum_xy = 0;
                double sum_x2 = 0, sum_y2 = 0;
                int n = m_window_size;
                for(int k = 0; k < n; k++) {
                    double x = prices[i][k];
                    double y = prices[j][k];
                    sum_x += x; sum_y += y; sum_xy += x * y; sum_x2 += x * x; sum_y2 += y * y;
                }
                double numerator = n * sum_xy - sum_x * sum_y;
                double denominator = MathSqrt((n * sum_x2 - sum_x * sum_x) * (n * sum_y2 - sum_y * sum_y));
                double corr = (denominator != 0.0) ? numerator / denominator : 0.0;
                m_correlation_cache[i][j] = corr;
                m_correlation_cache[j][i] = corr;
            }
        }
        m_last_update = TimeCurrent();
    }
    
    // Removed row-slice PearsonCorrelation; inlined in CalculateCorrelations
    double PearsonCorrelation(const double &x[], const double &y[], int n) { return 0.0; }
    
    double GetCorrelation(int strategy_i, int strategy_j) {
        if(strategy_i >= 0 && strategy_i < 23 && strategy_j >= 0 && strategy_j < 23)
            return m_correlation_cache[strategy_i][strategy_j];
        return 0.0;
    }
};

//+------------------------------------------------------------------+
//| ADVANCED RISK METRICS - VaR & Expected Shortfall                |
//+------------------------------------------------------------------+
struct SRiskMetrics {
    double var_95;                 // 5% Value at Risk
    double expected_shortfall;     // Conditional VaR (CVaR)
    double max_drawdown;           // Maximum drawdown
    double sharpe_ratio;           // Risk-adjusted return
    double calmar_ratio;           // Return/MaxDD ratio
    double sortino_ratio;          // Downside deviation ratio
    datetime timestamp;
};

class CRiskMetricsCalculator {
private:
    double m_returns[];
    int m_window;
    
public:
    CRiskMetricsCalculator(int window = 100) : m_window(window) {
        ArrayResize(m_returns, m_window);
        ArrayInitialize(m_returns, 0.0);
    }
    
    SRiskMetrics CalculateMetrics(const double &equity_curve[]) {
        SRiskMetrics metrics;
        int n = ArraySize(equity_curve);
        
        // Calculate returns
        CalculateReturns(equity_curve);
        
        // Sort returns for VaR calculation
        double sorted_returns[];
        ArrayCopy(sorted_returns, m_returns);
        ArraySort(sorted_returns);
        
        // Value at Risk (95th percentile)
        int var_index = (int)(n * 0.05);
        metrics.var_95 = MathAbs(sorted_returns[var_index]);
        
        // Expected Shortfall (CVaR) - average of worst 5%
        double es_sum = 0;
        for(int i = 0; i < var_index; i++) {
            es_sum += MathAbs(sorted_returns[i]);
        }
        metrics.expected_shortfall = es_sum / var_index;
        
        // Maximum Drawdown
        metrics.max_drawdown = CalculateMaxDrawdown(equity_curve);
        
        // Sharpe Ratio
        double mean_return = 0, std_return = 0;
        CalculateMeanStd(m_returns, mean_return, std_return);
        metrics.sharpe_ratio = (std_return > 0) ? (mean_return / std_return) * MathSqrt(252) : 0;
        
        // Calmar Ratio
        double annual_return = mean_return * 252;
        metrics.calmar_ratio = (metrics.max_drawdown > 0) ? annual_return / metrics.max_drawdown : 0;
        
        // Sortino Ratio (downside deviation only)
        metrics.sortino_ratio = CalculateSortinoRatio(m_returns);
        
        metrics.timestamp = TimeCurrent();
        return metrics;
    }
    
private:
    void CalculateReturns(const double &equity[]) {
        int n = MathMin(ArraySize(equity), m_window);
        ArrayResize(m_returns, n - 1);
        
        for(int i = 1; i < n; i++) {
            m_returns[i-1] = (equity[i] - equity[i-1]) / equity[i-1];
        }
    }
    
    double CalculateMaxDrawdown(const double &equity[]) {
        int n = ArraySize(equity);
        double max_dd = 0;
        double peak = equity[0];
        
        for(int i = 1; i < n; i++) {
            if(equity[i] > peak) {
                peak = equity[i];
            } else {
                double dd = (peak - equity[i]) / peak;
                if(dd > max_dd) max_dd = dd;
            }
        }
        return max_dd;
    }
    
    void CalculateMeanStd(const double &data[], double &mean, double &std) {
        int n = ArraySize(data);
        mean = 0;
        for(int i = 0; i < n; i++) mean += data[i];
        mean /= n;
        
        double variance = 0;
        for(int i = 0; i < n; i++) {
            double diff = data[i] - mean;
            variance += diff * diff;
        }
        std = MathSqrt(variance / n);
    }
    
    double CalculateSortinoRatio(const double &returns[]) {
        int n = ArraySize(returns);
        double mean = 0, downside_sum = 0;
        int downside_count = 0;
        
        for(int i = 0; i < n; i++) {
            mean += returns[i];
            if(returns[i] < 0) {
                downside_sum += returns[i] * returns[i];
                downside_count++;
            }
        }
        mean /= n;
        
        if(downside_count == 0) return 0;
        double downside_dev = MathSqrt(downside_sum / downside_count);
        return (downside_dev > 0) ? (mean / downside_dev) * MathSqrt(252) : 0;
    }
};

//+------------------------------------------------------------------+
//| KELLY CRITERION POSITION SIZER                                   |
//+------------------------------------------------------------------+
class CKellyPositionSizer {
private:
    double m_kelly_fraction;       // Safety factor (0.25 = quarter Kelly)
    double m_max_position_size;    // Maximum position size cap
    double m_min_position_size;    // Minimum position size floor
    
public:
    CKellyPositionSizer(double kelly_fraction = 0.25, double max_size = 0.10, double min_size = 0.01) {
        m_kelly_fraction = kelly_fraction;
        m_max_position_size = max_size;
        m_min_position_size = min_size;
    }
    
    double CalculatePositionSize(double win_rate, double avg_win, double avg_loss, double current_equity) {
        // Full Kelly formula: f = (p*W - (1-p)*L) / (W*L)
        // Where: p = win_rate, W = avg_win, L = avg_loss
        
        if(avg_win <= 0 || avg_loss <= 0) return m_min_position_size;
        
        double p = win_rate;
        double q = 1.0 - win_rate;
        
        // Kelly percentage
        double kelly = (p * avg_win - q * avg_loss) / (avg_win * avg_loss);
        
        // Apply safety fraction
        kelly *= m_kelly_fraction;
        
        // Clamp to safe range
        kelly = MathMax(0.0, MathMin(kelly, m_max_position_size));
        
        if(kelly < m_min_position_size) return 0.0;  // Don't trade if Kelly too small
        
        return current_equity * kelly;
    }
    
    double CalculateOptimalF(const double &returns[], double current_equity) {
        // Optimal F method (Ralph Vince)
        int n = ArraySize(returns);
        if(n == 0) return m_min_position_size;
        
        double max_f = 0;
        double max_twrr = -999999;
        
        // Search for optimal f between 0 and 1
        for(double f = 0.01; f <= 0.50; f += 0.01) {
            double twrr = 1.0;  // Terminal Wealth Relative Return
            
            for(int i = 0; i < n; i++) {
                twrr *= (1.0 + f * returns[i]);
            }
            
            if(twrr > max_twrr) {
                max_twrr = twrr;
                max_f = f;
            }
        }
        
        // Apply safety fraction
        max_f *= m_kelly_fraction;
        max_f = MathMax(m_min_position_size, MathMin(max_f, m_max_position_size));
        
        return current_equity * max_f;
    }
};

//+------------------------------------------------------------------+
//| CONFIGURATION MANAGER - JSON-Based                              |
//+------------------------------------------------------------------+
class CConfigurationManager {
private:
    SConfigBlock m_config;
    string m_config_file;
    
public:
    CConfigurationManager(string config_path = "DualEA\\config\\nuclear_config.json") {
        m_config_file = config_path;
        LoadDefaultConfig();
    }
    
    void LoadDefaultConfig() {
        m_config.signature = "DUAL";
        m_config.version = 3;
        m_config.strategy_count = 23;
        m_config.risk_profile = 85;  // AGGRESSIVE
        m_config.max_drawdown = 0.15;
        m_config.kelly_fraction = 0.25;
        m_config.correlation_window = 252;
        m_config.volatility_window = 21;
        m_config.enable_ml = true;
        m_config.enable_news_filter = true;
        m_config.enable_regime_switch = true;
    }
    
    bool SaveConfig() {
        int handle = FileOpen(m_config_file, FILE_WRITE|FILE_TXT);
        if(handle == INVALID_HANDLE) return false;
        
        FileWriteString(handle, "{\n");
        FileWriteString(handle, "  \"signature\": \"" + m_config.signature + "\",\n");
        FileWriteString(handle, "  \"version\": " + IntegerToString(m_config.version) + ",\n");
        FileWriteString(handle, "  \"strategy_count\": " + IntegerToString(m_config.strategy_count) + ",\n");
        FileWriteString(handle, "  \"risk_profile\": " + IntegerToString(m_config.risk_profile) + ",\n");
        FileWriteString(handle, "  \"max_drawdown\": " + DoubleToString(m_config.max_drawdown, 2) + ",\n");
        FileWriteString(handle, "  \"kelly_fraction\": " + DoubleToString(m_config.kelly_fraction, 2) + ",\n");
        FileWriteString(handle, "  \"correlation_window\": " + IntegerToString(m_config.correlation_window) + ",\n");
        FileWriteString(handle, "  \"volatility_window\": " + IntegerToString(m_config.volatility_window) + ",\n");
        FileWriteString(handle, "  \"enable_ml\": " + (m_config.enable_ml ? "true" : "false") + ",\n");
        FileWriteString(handle, "  \"enable_news_filter\": " + (m_config.enable_news_filter ? "true" : "false") + ",\n");
        FileWriteString(handle, "  \"enable_regime_switch\": " + (m_config.enable_regime_switch ? "true" : "false") + "\n");
        FileWriteString(handle, "}\n");
        
        FileClose(handle);
        return true;
    }
    
    SConfigBlock GetConfig() const { return m_config; }
    void SetRiskProfile(int profile) { m_config.risk_profile = profile; }
    void SetKellyFraction(double fraction) { m_config.kelly_fraction = fraction; }
    void SetMaxDrawdown(double dd) { m_config.max_drawdown = dd; }
};

//+------------------------------------------------------------------+
//| POLICY STATE MANAGEMENT                                          |
//+------------------------------------------------------------------+
struct SPolicyState {
    double weights[23];
    double bias;
    double learning_rate;
    int epoch;
    string model_hash;
    datetime timestamp;
};

class CPolicyStateManager {
private:
    CRingBuffer m_policy_queue;  // Non-template - stores serialized policy states
    string m_current_state_serialized;
    
public:
    CPolicyStateManager() : m_policy_queue(1024) {}
    
    bool UpdateState(const string &serialized_state) {
        m_current_state_serialized = serialized_state;
        return m_policy_queue.Push(serialized_state);
    }
    
    string GetCurrentStateSerialized() const { return m_current_state_serialized; }
};

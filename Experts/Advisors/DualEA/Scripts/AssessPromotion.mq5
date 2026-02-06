//+------------------------------------------------------------------+
//| AssessPromotion.mq5 - DualEA Promotion Gate Evaluator           |
//| Comprehensive evaluation script for PaperEA → LiveEA promotion  |
//+------------------------------------------------------------------+
#property copyright "DualEA Promotion System"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| INCLUDES                                                         |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Files\File.mqh>
// Removed ArrayObj since we use native arrays

//+------------------------------------------------------------------+
//| PROMOTION CRITERIA CONFIGURATION                                 |
//+------------------------------------------------------------------+
struct SPromotionCriteria
{
    // Minimum thresholds for promotion
    int    min_trades;           // Minimum number of trades required
    double min_hit_rate;         // Minimum win rate (0.0-1.0)
    double min_expectancy_r;     // Minimum expectancy in R-multiples
    double max_drawdown_pct;     // Maximum drawdown percentage
    double min_sharpe_ratio;     // Minimum Sharpe ratio
    double min_profit_factor;    // Minimum profit factor
    int    min_trading_days;     // Minimum trading days
    double min_avg_trade_r;      // Minimum average trade in R
    double max_consecutive_losses; // Maximum consecutive losses
    
    // Constructor with defaults
    SPromotionCriteria() : 
        min_trades(50),
        min_hit_rate(0.55),
        min_expectancy_r(0.2),
        max_drawdown_pct(15.0),
        min_sharpe_ratio(1.0),
        min_profit_factor(1.3),
        min_trading_days(30),
        min_avg_trade_r(0.1),
        max_consecutive_losses(10)
    {}
};

//+------------------------------------------------------------------+
//| TRADE STATISTICS STRUCTURE                                       |
//+------------------------------------------------------------------+
struct STradeStats
{
    int    total_trades;
    int    winning_trades;
    int    losing_trades;
    double hit_rate;
    double gross_profit;
    double gross_loss;
    double net_profit;
    double max_drawdown;
    double sharpe_ratio;
    double profit_factor;
    double expectancy_r;
    double avg_trade_r;
    int    consecutive_losses;
    int    trading_days;
    datetime first_trade;
    datetime last_trade;
    
    // Constructor
    STradeStats() : 
        total_trades(0), winning_trades(0), losing_trades(0), hit_rate(0.0),
        gross_profit(0.0), gross_loss(0.0), net_profit(0.0),
        max_drawdown(0.0), sharpe_ratio(0.0), profit_factor(0.0),
        expectancy_r(0.0), avg_trade_r(0.0), consecutive_losses(0),
        trading_days(0), first_trade(0), last_trade(0)
    {}
};

//+------------------------------------------------------------------+
//| PROMOTION RESULT STRUCTURE                                       |
//+------------------------------------------------------------------+
struct SPromotionResult
{
    bool   passed;
    string symbol;
    string timeframe;
    string failure_reason;
    STradeStats stats;
    SPromotionCriteria criteria;
    
    // Detailed pass/fail breakdown
    bool   trades_pass;
    bool   hit_rate_pass;
    bool   expectancy_pass;
    bool   drawdown_pass;
    bool   sharpe_pass;
    bool   profit_factor_pass;
    bool   trading_days_pass;
    bool   avg_trade_pass;
    bool   consecutive_losses_pass;
    
    SPromotionResult() : passed(false), trades_pass(false), hit_rate_pass(false),
                        expectancy_pass(false), drawdown_pass(false), sharpe_pass(false),
                        profit_factor_pass(false), trading_days_pass(false),
                        avg_trade_pass(false), consecutive_losses_pass(false) {}
};

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
SPromotionCriteria g_criteria;
string g_report_path = "DualEA\\promotion_report.txt";
string g_telemetry_path = "DualEA\\telemetry";

//+------------------------------------------------------------------+
//| SCRIPT ENTRY POINT                                               |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("=== DualEA Promotion Assessment Starting ===");
    
    // Load criteria from config file if exists
    LoadPromotionCriteria();
    
    // Get all symbols and timeframes from telemetry
    string symbols[];
    int timeframes[];
    GetAvailableSymbolsTimeframes(symbols, timeframes);
    
    if(ArraySize(symbols) == 0)
    {
        Print("No telemetry data found. Ensure PaperEA has been running.");
        return;
    }
    
    // Process each symbol/timeframe combination
    SPromotionResult results[];
    for(int i = 0; i < ArraySize(symbols); i++)
    {
        for(int j = 0; j < ArraySize(timeframes); j++)
        {
            string symbol = symbols[i];
            int timeframe = timeframes[j];
            SPromotionResult r;
            if(EvaluatePromotion(symbol, timeframe, r))
            {
                int n = ArraySize(results);
                ArrayResize(results, n+1);
                results[n] = r;
            }
        }
    }
    
    // Generate comprehensive report
    GenerateReport(results);
    
    // No dynamic allocations used; nothing to cleanup
    
    Print("=== Promotion Assessment Complete ===");
}

//+------------------------------------------------------------------+
//| LOAD PROMOTION CRITERIA FROM CONFIG                              |
//+------------------------------------------------------------------+
void LoadPromotionCriteria()
{
    string config_path = "DualEA\\promotion_criteria.json";
    int handle = FileOpen(config_path, FILE_READ | FILE_COMMON | FILE_TXT | FILE_ANSI);
    
    if(handle != INVALID_HANDLE)
    {
        string content = "";
        while(!FileIsEnding(handle))
        {
            content += FileReadString(handle) + "\n";
        }
        FileClose(handle);
        
        // Parse JSON (basic implementation)
        ParseCriteriaFromJSON(content);
        Print("Loaded promotion criteria from config file");
    }
    else
    {
        Print("Using default promotion criteria");
    }
}

//+------------------------------------------------------------------+
//| PARSE CRITERIA FROM JSON                                         |
//+------------------------------------------------------------------+
void ParseCriteriaFromJSON(const string& json)
{
    // Basic JSON parsing - extract key values
    string key;
    
    key = "\"min_trades\":";
    int pos = StringFind(json, key);
    if(pos >= 0) g_criteria.min_trades = (int)StringToDouble(StringSubstr(json, pos + StringLen(key), 10));
    
    key = "\"min_hit_rate\":";
    pos = StringFind(json, key);
    if(pos >= 0) g_criteria.min_hit_rate = StringToDouble(StringSubstr(json, pos + StringLen(key), 10));
    
    key = "\"min_expectancy_r\":";
    pos = StringFind(json, key);
    if(pos >= 0) g_criteria.min_expectancy_r = StringToDouble(StringSubstr(json, pos + StringLen(key), 10));
    
    key = "\"max_drawdown_pct\":";
    pos = StringFind(json, key);
    if(pos >= 0) g_criteria.max_drawdown_pct = StringToDouble(StringSubstr(json, pos + StringLen(key), 10));
    
    key = "\"min_sharpe_ratio\":";
    pos = StringFind(json, key);
    if(pos >= 0) g_criteria.min_sharpe_ratio = StringToDouble(StringSubstr(json, pos + StringLen(key), 10));
    
    key = "\"min_profit_factor\":";
    pos = StringFind(json, key);
    if(pos >= 0) g_criteria.min_profit_factor = StringToDouble(StringSubstr(json, pos + StringLen(key), 10));
}

//+------------------------------------------------------------------+
//| GET AVAILABLE SYMBOLS AND TIMEFRAMES FROM TELEMETRY              |
//+------------------------------------------------------------------+
// Helper: add unique string to array
bool AddUniqueString(string &arr[], const string value)
{
    for(int i=0;i<ArraySize(arr);++i) if(arr[i]==value) return false;
    int n=ArraySize(arr); ArrayResize(arr,n+1); arr[n]=value; return true;
}

// Helper: add unique int to array
bool AddUniqueInt(int &arr[], const int value)
{
    for(int i=0;i<ArraySize(arr);++i) if(arr[i]==value) return false;
    int n=ArraySize(arr); ArrayResize(arr,n+1); arr[n]=value; return true;
}

void GetAvailableSymbolsTimeframes(string &symbols[], int &timeframes[])
  {
    string search_path = g_telemetry_path + "\\*.csv";
    // iterate files using FileFindFirst/Next
    string file;
    
    // Use Windows API to find files
    string path = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\" + search_path;
    
    // Scan directory for telemetry files
    long search_handle = FileFindFirst(path, file);
    if(search_handle != INVALID_HANDLE)
    {
        do
        {
            // Parse symbol and timeframe from filename format: SYMBOL_TF_YYYYMMDD.csv
            string parts[];
            int part_count = StringSplit(file, '_', parts);
            if(part_count >= 2)
            {
                string symbol = parts[0];
                int timeframe = (int)StringToInteger(parts[1]);
                
                // Add unique symbols and timeframes
                AddUniqueString(symbols, symbol);
                AddUniqueInt(timeframes, timeframe);
            }
        }
        while(FileFindNext(search_handle, file));
        FileFindClose(search_handle);
    }
  }

//+------------------------------------------------------------------+
//| EVALUATE PROMOTION FOR SPECIFIC SYMBOL/TIMEFRAME                 |
//+------------------------------------------------------------------+
bool EvaluatePromotion(const string symbol, const int timeframe, SPromotionResult &result)
  {
    result.symbol = symbol;
    result.timeframe = EnumToString((ENUM_TIMEFRAMES)timeframe);
    result.criteria = g_criteria;
    
    // Load trade history from telemetry
    if(!LoadTradeHistory(symbol, timeframe, result.stats))
    {
        return false;
    }
    
    // Evaluate each criterion
    EvaluateCriteria(result);
    
    // Determine overall pass/fail
    result.passed = result.trades_pass && result.hit_rate_pass && result.expectancy_pass && 
                    result.drawdown_pass && result.sharpe_pass && result.profit_factor_pass &&
                    result.trading_days_pass && result.avg_trade_pass && result.consecutive_losses_pass;
    
    if(!result.passed)
    {
        BuildFailureReason(result);
    }
    
    return true;
  }

//+------------------------------------------------------------------+
//| LOAD TRADE HISTORY FROM TELEMETRY                                |
//+------------------------------------------------------------------+
bool LoadTradeHistory(const string symbol, const int timeframe, STradeStats& stats)
  {
    string filename = StringFormat("%s\\%s_%d_telemetry.csv", g_telemetry_path, symbol, timeframe);
    string filepath = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\" + filename;
    
    int handle = FileOpen(filepath, FILE_READ | FILE_TXT | FILE_ANSI);
    if(handle == INVALID_HANDLE)
    {
        PrintFormat("No telemetry data for %s %s", symbol, EnumToString((ENUM_TIMEFRAMES)timeframe));
        return false;
    }
    
    // Skip header
    FileReadString(handle);
    
    double equity_curve[];
    double daily_returns[];
    int consecutive_losses = 0;
    int max_consecutive_losses = 0;
    
    while(!FileIsEnding(handle))
    {
        string line = FileReadString(handle);
        if(StringLen(line) < 10) continue;
        
        string fields[];
        int field_count = StringSplit(line, ',', fields);
        if(field_count < 10) continue;
        
        // Parse trade data
        string event_type = fields[4];
        if(event_type == "trade_close")
        {
            stats.total_trades++;
            
            double profit = StringToDouble(fields[7]);
            double risk_r = StringToDouble(fields[8]);
            
            if(profit > 0)
            {
                stats.winning_trades++;
                stats.gross_profit += profit;
                consecutive_losses = 0;
            }
            else
            {
                stats.losing_trades++;
                stats.gross_loss += MathAbs(profit);
                consecutive_losses++;
                max_consecutive_losses = MathMax(max_consecutive_losses, consecutive_losses);
            }
            
            // Track first/last trade times
            datetime trade_time = (datetime)StringToInteger(fields[0]);
            if(stats.first_trade == 0 || trade_time < stats.first_trade)
                stats.first_trade = trade_time;
            if(trade_time > stats.last_trade)
                stats.last_trade = trade_time;
            
            // Build equity curve for calculations
            int n = ArraySize(equity_curve);
            ArrayResize(equity_curve, n+1);
            equity_curve[n] = stats.gross_profit - stats.gross_loss;
        }
    }
    FileClose(handle);
    
    // Calculate derived statistics
    stats.net_profit = stats.gross_profit - stats.gross_loss;
    stats.consecutive_losses = max_consecutive_losses;
    
    if(stats.total_trades > 0)
    {
        stats.hit_rate = (double)stats.winning_trades / (double)stats.total_trades;
        stats.profit_factor = stats.gross_loss > 0 ? stats.gross_profit / stats.gross_loss : 999;
        
        // Calculate expectancy in R
        double total_r = 0;
        if(stats.winning_trades > 0 && stats.losing_trades > 0)
        {
            double avg_win = stats.gross_profit / stats.winning_trades;
            double avg_loss = stats.gross_loss / stats.losing_trades;
            stats.expectancy_r = (stats.hit_rate * avg_win) - ((1 - stats.hit_rate) * avg_loss);
            stats.avg_trade_r = stats.net_profit / stats.total_trades;
        }
        
        // Calculate max drawdown from equity curve
        if(ArraySize(equity_curve) > 0)
        {
            double peak = equity_curve[0];
            double max_dd = 0;
            for(int i = 0; i < ArraySize(equity_curve); i++)
            {
                double current = equity_curve[i];
                if(current > peak) peak = current;
                double dd = peak - current;
                if(dd > max_dd) max_dd = dd;
            }
            stats.max_drawdown = max_dd;
        }
        
        // Calculate Sharpe ratio (simplified)
        if(ArraySize(equity_curve) > 1)
        {
            double sum_returns = 0;
            double sum_sq_returns = 0;
            int return_count = 0;
            
            for(int i = 1; i < ArraySize(equity_curve); i++)
            {
                double ret = equity_curve[i] - equity_curve[i-1];
                sum_returns += ret;
                sum_sq_returns += ret * ret;
                return_count++;
            }
            
            if(return_count > 0)
            {
                double avg_return = sum_returns / return_count;
                double variance = (sum_sq_returns / return_count) - (avg_return * avg_return);
                if(variance > 0)
                {
                    stats.sharpe_ratio = avg_return / MathSqrt(variance);
                }
            }
        }
        
        // Calculate trading days
        if(stats.first_trade > 0 && stats.last_trade > 0)
        {
            stats.trading_days = (int)((stats.last_trade - stats.first_trade) / (24 * 3600));
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| EVALUATE PROMOTION CRITERIA                                      |
//+------------------------------------------------------------------+
void EvaluateCriteria(SPromotionResult &result)
  {
    result.trades_pass = result.stats.total_trades >= result.criteria.min_trades;
    result.hit_rate_pass = result.stats.hit_rate >= result.criteria.min_hit_rate;
    result.expectancy_pass = result.stats.expectancy_r >= result.criteria.min_expectancy_r;
    result.drawdown_pass = result.stats.max_drawdown <= result.criteria.max_drawdown_pct;
    result.sharpe_pass = result.stats.sharpe_ratio >= result.criteria.min_sharpe_ratio;
    result.profit_factor_pass = result.stats.profit_factor >= result.criteria.min_profit_factor;
    result.trading_days_pass = result.stats.trading_days >= result.criteria.min_trading_days;
    result.avg_trade_pass = result.stats.avg_trade_r >= result.criteria.min_avg_trade_r;
    result.consecutive_losses_pass = result.stats.consecutive_losses <= result.criteria.max_consecutive_losses;
  }

//+------------------------------------------------------------------+
//| BUILD FAILURE REASON STRING                                      |
//+------------------------------------------------------------------+
void BuildFailureReason(SPromotionResult &result)
  {
    string failures[];
    
    if(!result.trades_pass){int n=ArraySize(failures);ArrayResize(failures,n+1);failures[n]=StringFormat("Min trades: %d < %d", result.stats.total_trades, result.criteria.min_trades);}    
    if(!result.hit_rate_pass){int n=ArraySize(failures);ArrayResize(failures,n+1);failures[n]=StringFormat("Hit rate: %.2f%% < %.2f%%", result.stats.hit_rate * 100, result.criteria.min_hit_rate * 100);} 
    if(!result.expectancy_pass){int n=ArraySize(failures);ArrayResize(failures,n+1);failures[n]=StringFormat("Expectancy: %.2fR < %.2fR", result.stats.expectancy_r, result.criteria.min_expectancy_r);} 
    if(!result.drawdown_pass){int n=ArraySize(failures);ArrayResize(failures,n+1);failures[n]=StringFormat("Max DD: %.2f%% > %.2f%%", result.stats.max_drawdown, result.criteria.max_drawdown_pct);} 
    if(!result.sharpe_pass){int n=ArraySize(failures);ArrayResize(failures,n+1);failures[n]=StringFormat("Sharpe: %.2f < %.2f", result.stats.sharpe_ratio, result.criteria.min_sharpe_ratio);} 
    if(!result.profit_factor_pass){int n=ArraySize(failures);ArrayResize(failures,n+1);failures[n]=StringFormat("PF: %.2f < %.2f", result.stats.profit_factor, result.criteria.min_profit_factor);} 
    if(!result.trading_days_pass){int n=ArraySize(failures);ArrayResize(failures,n+1);failures[n]=StringFormat("Days: %d < %d", result.stats.trading_days, result.criteria.min_trading_days);} 
    if(!result.avg_trade_pass){int n=ArraySize(failures);ArrayResize(failures,n+1);failures[n]=StringFormat("Avg trade: %.2fR < %.2fR", result.stats.avg_trade_r, result.criteria.min_avg_trade_r);} 
    if(!result.consecutive_losses_pass){int n=ArraySize(failures);ArrayResize(failures,n+1);failures[n]=StringFormat("Consecutive losses: %d > %d", result.stats.consecutive_losses, result.criteria.max_consecutive_losses);} 
    
    // Build failure string
    for(int i = 0; i < ArraySize(failures); i++)
    {
        if(i > 0) result.failure_reason += "; ";
        result.failure_reason += failures[i];
    }
  }

//+------------------------------------------------------------------+
//| GENERATE COMPREHENSIVE REPORT                                    |
//+------------------------------------------------------------------+
void GenerateReport(SPromotionResult &results[])
  {
    string report_path = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\" + g_report_path;
    
    int handle = FileOpen(report_path, FILE_WRITE | FILE_TXT | FILE_ANSI);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to create promotion report");
        return;
    }
    
    FileWriteString(handle, "DUALEA PROMOTION ASSESSMENT REPORT\n");
    FileWriteString(handle, "=================================\n\n");
    FileWriteString(handle, StringFormat("Generated: %s\n", TimeToString(TimeCurrent())));
    FileWriteString(handle, StringFormat("Evaluation Period: %s to %s\n\n", 
        TimeToString(GetOldestTradeDate(results)), TimeToString(TimeCurrent())));
    
    int passed_count = 0;
    int total_count = ArraySize(results);
    
    for(int i = 0; i < total_count; i++)
    {
        SPromotionResult result = results[i];
        
        FileWriteString(handle, StringFormat("=== %s %s ===\n", result.symbol, result.timeframe));
        FileWriteString(handle, StringFormat("Status: %s\n", result.passed ? "PASS" : "FAIL"));
        
        if(result.passed) passed_count++;
        
        FileWriteString(handle, StringFormat("Total Trades: %d\n", result.stats.total_trades));
        FileWriteString(handle, StringFormat("Win Rate: %.2f%%\n", result.stats.hit_rate * 100));
        FileWriteString(handle, StringFormat("Expectancy: %.2fR\n", result.stats.expectancy_r));
        FileWriteString(handle, StringFormat("Max Drawdown: %.2f%%\n", result.stats.max_drawdown));
        FileWriteString(handle, StringFormat("Sharpe Ratio: %.2f\n", result.stats.sharpe_ratio));
        FileWriteString(handle, StringFormat("Profit Factor: %.2f\n", result.stats.profit_factor));
        FileWriteString(handle, StringFormat("Trading Days: %d\n", result.stats.trading_days));
        FileWriteString(handle, StringFormat("Avg Trade: %.2fR\n", result.stats.avg_trade_r));
        FileWriteString(handle, StringFormat("Consecutive Losses: %d\n", result.stats.consecutive_losses));
        
        if(!result.passed)
        {
            FileWriteString(handle, StringFormat("Failure Reasons: %s\n", result.failure_reason));
        }
        
        FileWriteString(handle, "\n");
    }
    
    FileWriteString(handle, StringFormat("\nSUMMARY: %d/%d combinations passed promotion criteria\n", 
        passed_count, total_count));
    FileWriteString(handle, StringFormat("Overall Status: %s\n", 
        passed_count == total_count && total_count > 0 ? "READY FOR LIVE" : "NOT READY"));
    
    FileClose(handle);
    
    Print(StringFormat("Promotion report generated: %s", report_path));
    Print(StringFormat("Summary: %d/%d combinations passed", passed_count, total_count));
}

//+------------------------------------------------------------------+
//| GET OLDEST TRADE DATE FROM RESULTS                               |
//+------------------------------------------------------------------+
datetime GetOldestTradeDate(SPromotionResult &results[])
  {
    datetime oldest = TimeCurrent();
    
    for(int i = 0; i < ArraySize(results); i++)
    {
        SPromotionResult result = results[i];
        if(result.stats.first_trade > 0 && result.stats.first_trade < oldest)
        {
            oldest = result.stats.first_trade;
        }
    }
    
    return oldest;
  }

//+------------------------------------------------------------------+
//| HighFrequencyExecutor.mqh                                        |
//| JAILBREAK LEVEL 5 - HIGH-FREQUENCY EXECUTION ENGINE             |
//| Ultra-Low Latency Trade Execution System                        |
//+------------------------------------------------------------------+
#property copyright "EscapeEA - Jailbreak Level 5 Execution"
#property version   "1.00"
#property strict

#include "../Signals/AdvancedSignalProcessor.mqh"

//--- JAILBREAK EXECUTION: Execution constants
#define MAX_EXECUTION_TIME_NS 100000    // 100μs max execution time
#define MAX_SLIPPAGE_POINTS 3           // 3 points max slippage
#define MAX_RETRY_ATTEMPTS 3            // Max retry attempts
#define EXECUTION_TIMEOUT_MS 5000       // 5 second timeout

//--- JAILBREAK EXECUTION: Execution result codes
enum ENUM_EXECUTION_RESULT
{
    EXECUTION_SUCCESS = 0,
    EXECUTION_FAILED = 1,
    EXECUTION_TIMEOUT = 2,
    EXECUTION_SLIPPAGE = 3,
    EXECUTION_INSUFFICIENT_MARGIN = 4,
    EXECUTION_INVALID_PRICE = 5,
    EXECUTION_MARKET_CLOSED = 6,
    EXECUTION_REQUOTE = 7
};

//--- JAILBREAK EXECUTION: Order types
enum ENUM_ORDER_TYPE_ADVANCED
{
    ORDER_MARKET_IMMEDIATE = 0,
    ORDER_MARKET_IOC = 1,        // Immediate or Cancel
    ORDER_MARKET_FOK = 2,        // Fill or Kill
    ORDER_LIMIT_ADVANCED = 3,
    ORDER_STOP_ADVANCED = 4
};

//+------------------------------------------------------------------+
//| JAILBREAK EXECUTION: Execution Result Structure                 |
//+------------------------------------------------------------------+
struct CExecutionResult
{
    ENUM_EXECUTION_RESULT result;
    ulong ticket;
    double executedPrice;
    double executedVolume;
    double slippage;
    ulong executionTimeNs;
    int retryCount;
    string errorMessage;
    datetime timestamp;
    bool isValid;
    
    CExecutionResult()
    {
        result = EXECUTION_FAILED;
        ticket = 0;
        executedPrice = 0.0;
        executedVolume = 0.0;
        slippage = 0.0;
        executionTimeNs = 0;
        retryCount = 0;
        errorMessage = "";
        timestamp = 0;
        isValid = false;
    }
};

//+------------------------------------------------------------------+
//| JAILBREAK EXECUTION: Order Request Structure                    |
//+------------------------------------------------------------------+
struct CAdvancedOrderRequest
{
    ENUM_ORDER_TYPE_ADVANCED orderType;
    string symbol;
    double volume;
    double price;
    double stopLoss;
    double takeProfit;
    int magicNumber;
    string comment;
    ulong deviation;
    datetime expiration;
    bool isValid;
    
    CAdvancedOrderRequest()
    {
        orderType = ORDER_MARKET_IMMEDIATE;
        symbol = "";
        volume = 0.0;
        price = 0.0;
        stopLoss = 0.0;
        takeProfit = 0.0;
        magicNumber = 0;
        comment = "";
        deviation = 10;
        expiration = 0;
        isValid = false;
    }
};

//+------------------------------------------------------------------+
//| JAILBREAK EXECUTION: High-Frequency Executor Class              |
//+------------------------------------------------------------------+
class CHighFrequencyExecutor
{
private:
    // JAILBREAK EXECUTION: Configuration
    bool m_isInitialized;
    bool m_hftEnabled;
    int m_magicNumber;
    ulong m_maxLatencyNs;
    ulong m_maxSlippagePoints;
    
    // JAILBREAK EXECUTION: Performance metrics
    ulong m_totalExecutions;
    ulong m_successfulExecutions;
    ulong m_failedExecutions;
    ulong m_averageExecutionTimeNs;
    ulong m_minExecutionTimeNs;
    ulong m_maxExecutionTimeNs;
    double m_averageSlippage;
    double m_maxSlippage;
    
    // JAILBREAK EXECUTION: Execution history
    CExecutionResult m_executionHistory[1000];
    int m_historyIndex;
    int m_totalHistoryEntries;
    
    // JAILBREAK EXECUTION: Market state
    datetime m_lastPriceUpdate;
    double m_lastBid;
    double m_lastAsk;
    double m_lastSpread;
    bool m_marketOpen;
    
    // JAILBREAK EXECUTION: Internal methods
    bool ValidateOrderRequest(const CAdvancedOrderRequest& request);
    bool CheckMarketConditions();
    CExecutionResult ExecuteMarketOrder(const CAdvancedOrderRequest& request);
    CExecutionResult ExecuteLimitOrder(const CAdvancedOrderRequest& request);
    bool ModifyPosition(ulong ticket, double stopLoss, double takeProfit);
    bool ClosePosition(ulong ticket);
    void UpdatePerformanceMetrics(const CExecutionResult& result);
    void AddToHistory(const CExecutionResult& result);
    double CalculateSlippage(double requestedPrice, double executedPrice, ENUM_ORDER_TYPE orderType);
    
public:
    // JAILBREAK EXECUTION: Constructor/Destructor
    CHighFrequencyExecutor();
    ~CHighFrequencyExecutor();
    
    // JAILBREAK EXECUTION: Initialization
    bool Initialize(int magicNumber, ulong maxLatencyNs, bool hftEnabled = false);
    void Cleanup();
    
    // JAILBREAK EXECUTION: Core execution methods
    CExecutionResult ExecuteSignal(const CSignalResult& signal);
    CExecutionResult ExecuteOrder(const CAdvancedOrderRequest& request);
    bool CloseAllPositionsEmergency();
    bool ClosePositionsByMagic(int magicNumber);
    
    // JAILBREAK EXECUTION: Position management
    bool ModifyPositionStops(ulong ticket, double newStopLoss, double newTakeProfit);
    bool TrailStopLoss(ulong ticket, double trailDistance);
    bool BreakEvenStopLoss(ulong ticket, double breakEvenDistance);
    
    // JAILBREAK EXECUTION: Market analysis
    bool IsMarketOpen();
    double GetCurrentSpread();
    bool IsLiquidityAdequate();
    double GetMarketDepth(int levels = 5);
    
    // JAILBREAK EXECUTION: Performance metrics
    ulong GetAverageExecutionTime() const { return m_averageExecutionTimeNs; }
    double GetSuccessRate() const;
    double GetAverageSlippage() const { return m_averageSlippage; }
    ulong GetTotalExecutions() const { return m_totalExecutions; }
    
    // JAILBREAK EXECUTION: Configuration
    void SetMaxLatency(ulong maxLatencyNs) { m_maxLatencyNs = maxLatencyNs; }
    void SetMaxSlippage(ulong maxSlippagePoints) { m_maxSlippagePoints = maxSlippagePoints; }
    void SetHFTMode(bool enabled) { m_hftEnabled = enabled; }
};

//+------------------------------------------------------------------+
//| JAILBREAK EXECUTION: Constructor                                 |
//+------------------------------------------------------------------+
CHighFrequencyExecutor::CHighFrequencyExecutor()
{
    m_isInitialized = false;
    m_hftEnabled = false;
    m_magicNumber = 0;
    m_maxLatencyNs = MAX_EXECUTION_TIME_NS;
    m_maxSlippagePoints = MAX_SLIPPAGE_POINTS;
    
    m_totalExecutions = 0;
    m_successfulExecutions = 0;
    m_failedExecutions = 0;
    m_averageExecutionTimeNs = 0;
    m_minExecutionTimeNs = ULONG_MAX;
    m_maxExecutionTimeNs = 0;
    m_averageSlippage = 0.0;
    m_maxSlippage = 0.0;
    
    m_historyIndex = 0;
    m_totalHistoryEntries = 0;
    
    m_lastPriceUpdate = 0;
    m_lastBid = 0.0;
    m_lastAsk = 0.0;
    m_lastSpread = 0.0;
    m_marketOpen = false;
    
    // Initialize history array
    for(int i = 0; i < 1000; i++)
    {
        m_executionHistory[i] = CExecutionResult();
    }
}

//+------------------------------------------------------------------+
//| JAILBREAK EXECUTION: Destructor                                 |
//+------------------------------------------------------------------+
CHighFrequencyExecutor::~CHighFrequencyExecutor()
{
    Cleanup();
}

//+------------------------------------------------------------------+
//| JAILBREAK EXECUTION: Initialize Executor                        |
//+------------------------------------------------------------------+
bool CHighFrequencyExecutor::Initialize(int magicNumber, ulong maxLatencyNs, bool hftEnabled = false)
{
    m_magicNumber = magicNumber;
    m_maxLatencyNs = maxLatencyNs;
    m_hftEnabled = hftEnabled;
    
    // JAILBREAK EXECUTION: Initialize market state
    m_lastBid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    m_lastAsk = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    m_lastSpread = m_lastAsk - m_lastBid;
    m_lastPriceUpdate = TimeCurrent();
    m_marketOpen = IsMarketOpen();
    
    // JAILBREAK EXECUTION: Validate symbol
    if(!SymbolSelect(Symbol(), true))
    {
        Print("JAILBREAK EXECUTION ERROR: Failed to select symbol: ", Symbol());
        return false;
    }
    
    // JAILBREAK EXECUTION: Check trading permissions
    if(!IsTradeAllowed())
    {
        Print("JAILBREAK EXECUTION WARNING: Trading not allowed");
    }
    
    m_isInitialized = true;
    
    Print("JAILBREAK EXECUTION: High-frequency executor initialized - Magic: ", m_magicNumber, 
          ", MaxLatency: ", m_maxLatencyNs, "ns, HFT: ", m_hftEnabled ? "ENABLED" : "DISABLED");
    
    return true;
}

//+------------------------------------------------------------------+
//| JAILBREAK EXECUTION: Cleanup Executor                           |
//+------------------------------------------------------------------+
void CHighFrequencyExecutor::Cleanup()
{
    if(m_isInitialized)
    {
        Print("JAILBREAK EXECUTION: High-frequency executor cleanup complete");
        m_isInitialized = false;
    }
}

//+------------------------------------------------------------------+
//| JAILBREAK EXECUTION: Execute Signal                             |
//+------------------------------------------------------------------+
CExecutionResult CHighFrequencyExecutor::ExecuteSignal(const CSignalResult& signal)
{
    CExecutionResult result;
    
    if(!m_isInitialized || !signal.isValid)
    {
        result.result = EXECUTION_FAILED;
        result.errorMessage = "Invalid signal or executor not initialized";
        return result;
    }
    
    ulong startTime = GetMicrosecondCount();
    
    // JAILBREAK EXECUTION: Create order request from signal
    CAdvancedOrderRequest request;
    request.symbol = Symbol();
    request.volume = 0.01;  // This should come from risk management
    request.magicNumber = m_magicNumber;
    request.comment = "JAILBREAK_SIGNAL";
    request.deviation = m_maxSlippagePoints;
    
    // JAILBREAK EXECUTION: Set order parameters based on signal type
    switch(signal.type)
    {
        case SIGNAL_BUY:
            request.orderType = ORDER_MARKET_IMMEDIATE;
            request.price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
            request.stopLoss = signal.stopLoss;
            request.takeProfit = signal.takeProfit;
            break;
            
        case SIGNAL_SELL:
            request.orderType = ORDER_MARKET_IMMEDIATE;
            request.price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
            request.stopLoss = signal.stopLoss;
            request.takeProfit = signal.takeProfit;
            break;
            
        default:
            result.result = EXECUTION_FAILED;
            result.errorMessage = "Invalid signal type";
            return result;
    }
    
    request.isValid = true;
    
    // JAILBREAK EXECUTION: Execute the order
    result = ExecuteOrder(request);
    result.executionTimeNs = GetMicrosecondCount() - startTime;
    
    // JAILBREAK EXECUTION: Validate execution time
    if(result.executionTimeNs > m_maxLatencyNs)
    {
        Print("JAILBREAK EXECUTION WARNING: Execution time exceeded limit: ", 
              result.executionTimeNs, "ns (max: ", m_maxLatencyNs, "ns)");
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| JAILBREAK EXECUTION: Execute Order                              |
//+------------------------------------------------------------------+
CExecutionResult CHighFrequencyExecutor::ExecuteOrder(const CAdvancedOrderRequest& request)
{
    CExecutionResult result;
    
    if(!ValidateOrderRequest(request))
    {
        result.result = EXECUTION_FAILED;
        result.errorMessage = "Invalid order request";
        return result;
    }
    
    if(!CheckMarketConditions())
    {
        result.result = EXECUTION_MARKET_CLOSED;
        result.errorMessage = "Market conditions not suitable for execution";
        return result;
    }
    
    ulong startTime = GetMicrosecondCount();
    
    // JAILBREAK EXECUTION: Execute based on order type
    switch(request.orderType)
    {
        case ORDER_MARKET_IMMEDIATE:
        case ORDER_MARKET_IOC:
        case ORDER_MARKET_FOK:
            result = ExecuteMarketOrder(request);
            break;
            
        case ORDER_LIMIT_ADVANCED:
        case ORDER_STOP_ADVANCED:
            result = ExecuteLimitOrder(request);
            break;
            
        default:
            result.result = EXECUTION_FAILED;
            result.errorMessage = "Unsupported order type";
            break;
    }
    
    result.executionTimeNs = GetMicrosecondCount() - startTime;
    result.timestamp = TimeCurrent();
    
    // JAILBREAK EXECUTION: Update metrics and history
    UpdatePerformanceMetrics(result);
    AddToHistory(result);
    
    return result;
}

//+------------------------------------------------------------------+
//| JAILBREAK EXECUTION: Execute Market Order                       |
//+------------------------------------------------------------------+
CExecutionResult CHighFrequencyExecutor::ExecuteMarketOrder(const CAdvancedOrderRequest& request)
{
    CExecutionResult result;
    
    MqlTradeRequest tradeRequest = {};
    MqlTradeResult tradeResult = {};
    
    // JAILBREAK EXECUTION: Prepare trade request
    tradeRequest.action = TRADE_ACTION_DEAL;
    tradeRequest.symbol = request.symbol;
    tradeRequest.volume = request.volume;
    tradeRequest.deviation = request.deviation;
    tradeRequest.magic = request.magicNumber;
    tradeRequest.comment = request.comment;
    
    // JAILBREAK EXECUTION: Determine order type
    if(request.price >= SymbolInfoDouble(request.symbol, SYMBOL_ASK))
    {
        tradeRequest.type = ORDER_TYPE_BUY;
        tradeRequest.price = SymbolInfoDouble(request.symbol, SYMBOL_ASK);
    }
    else
    {
        tradeRequest.type = ORDER_TYPE_SELL;
        tradeRequest.price = SymbolInfoDouble(request.symbol, SYMBOL_BID);
    }
    
    tradeRequest.sl = request.stopLoss;
    tradeRequest.tp = request.takeProfit;
    
    // JAILBREAK EXECUTION: Execute with retry logic
    int retryCount = 0;
    bool success = false;
    
    while(retryCount < MAX_RETRY_ATTEMPTS && !success)
    {
        ResetLastError();
        
        if(OrderSend(tradeRequest, tradeResult))
        {
            success = true;
            result.result = EXECUTION_SUCCESS;
            result.ticket = tradeResult.deal;
            result.executedPrice = tradeResult.price;
            result.executedVolume = tradeResult.volume;
            result.slippage = CalculateSlippage(tradeRequest.price, tradeResult.price, tradeRequest.type);
            result.retryCount = retryCount;
            result.isValid = true;
            
            // JAILBREAK EXECUTION: Validate slippage
            if(MathAbs(result.slippage) > m_maxSlippagePoints * SymbolInfoDouble(request.symbol, SYMBOL_POINT))
            {
                result.result = EXECUTION_SLIPPAGE;
                result.errorMessage = StringFormat("Excessive slippage: %.5f", result.slippage);
            }
        }
        else
        {
            int errorCode = GetLastError();
            result.errorMessage = StringFormat("OrderSend failed: %d - %s", errorCode, 
                                             ErrorDescription(errorCode));
            
            // JAILBREAK EXECUTION: Handle specific errors
            switch(errorCode)
            {
                case TRADE_RETCODE_REQUOTE:
                    result.result = EXECUTION_REQUOTE;
                    // Update price and retry
                    if(tradeRequest.type == ORDER_TYPE_BUY)
                        tradeRequest.price = SymbolInfoDouble(request.symbol, SYMBOL_ASK);
                    else
                        tradeRequest.price = SymbolInfoDouble(request.symbol, SYMBOL_BID);
                    break;
                    
                case TRADE_RETCODE_NO_MONEY:
                    result.result = EXECUTION_INSUFFICIENT_MARGIN;
                    success = true;  // Don't retry
                    break;
                    
                case TRADE_RETCODE_MARKET_CLOSED:
                    result.result = EXECUTION_MARKET_CLOSED;
                    success = true;  // Don't retry
                    break;
                    
                case TRADE_RETCODE_TIMEOUT:
                    result.result = EXECUTION_TIMEOUT;
                    break;
                    
                default:
                    result.result = EXECUTION_FAILED;
                    break;
            }
        }
        
        retryCount++;
        
        // JAILBREAK EXECUTION: Small delay between retries
        if(!success && retryCount < MAX_RETRY_ATTEMPTS)
        {
            Sleep(1);  // 1ms delay
        }
    }
    
    if(!success)
    {
        result.result = EXECUTION_FAILED;
        result.retryCount = retryCount;
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| JAILBREAK EXECUTION: Execute Limit Order                        |
//+------------------------------------------------------------------+
CExecutionResult CHighFrequencyExecutor::ExecuteLimitOrder(const CAdvancedOrderRequest& request)
{
    CExecutionResult result;
    
    // JAILBREAK EXECUTION: Placeholder for limit order execution
    // In production, implement pending order logic
    
    result.result = EXECUTION_FAILED;
    result.errorMessage = "Limit orders not yet implemented";
    
    return result;
}

//+------------------------------------------------------------------+
//| JAILBREAK EXECUTION: Close All Positions Emergency              |
//+------------------------------------------------------------------+
bool CHighFrequencyExecutor::CloseAllPositionsEmergency()
{
    if(!m_isInitialized)
    {
        return false;
    }
    
    bool allClosed = true;
    int totalPositions = PositionsTotal();
    
    Print("JAILBREAK EXECUTION EMERGENCY: Closing all positions - Total: ", totalPositions);
    
    // JAILBREAK EXECUTION: Close all positions
    for(int i = totalPositions - 1; i >= 0; i--)
    {
        if(PositionSelectByIndex(i))
        {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            
            if(!ClosePosition(ticket))
            {
                allClosed = false;
                Print("JAILBREAK EXECUTION ERROR: Failed to close position: ", ticket);
            }
        }
    }
    
    return allClosed;
}

//+------------------------------------------------------------------+
//| JAILBREAK EXECUTION: Close Position                             |
//+------------------------------------------------------------------+
bool CHighFrequencyExecutor::ClosePosition(ulong ticket)
{
    if(!PositionSelectByTicket(ticket))
    {
        return false;
    }
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = PositionGetString(POSITION_SYMBOL);
    request.volume = PositionGetDouble(POSITION_VOLUME);
    request.deviation = m_maxSlippagePoints;
    request.magic = m_magicNumber;
    request.comment = "JAILBREAK_CLOSE";
    
    // JAILBREAK EXECUTION: Determine close order type
    if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
    {
        request.type = ORDER_TYPE_SELL;
        request.price = SymbolInfoDouble(request.symbol, SYMBOL_BID);
    }
    else
    {
        request.type = ORDER_TYPE_BUY;
        request.price = SymbolInfoDouble(request.symbol, SYMBOL_ASK);
    }
    
    return OrderSend(request, result);
}

//+------------------------------------------------------------------+
//| JAILBREAK EXECUTION: Validate Order Request                     |
//+------------------------------------------------------------------+
bool CHighFrequencyExecutor::ValidateOrderRequest(const CAdvancedOrderRequest& request)
{
    if(!request.isValid)
    {
        return false;
    }
    
    // JAILBREAK EXECUTION: Validate symbol
    if(request.symbol == "" || !SymbolSelect(request.symbol, true))
    {
        return false;
    }
    
    // JAILBREAK EXECUTION: Validate volume
    double minLot = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_MAX);
    
    if(request.volume < minLot || request.volume > maxLot)
    {
        return false;
    }
    
    // JAILBREAK EXECUTION: Validate prices
    if(request.price <= 0)
    {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| JAILBREAK EXECUTION: Check Market Conditions                    |
//+------------------------------------------------------------------+
bool CHighFrequencyExecutor::CheckMarketConditions()
{
    // JAILBREAK EXECUTION: Update market state
    m_lastBid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    m_lastAsk = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    m_lastSpread = m_lastAsk - m_lastBid;
    m_lastPriceUpdate = TimeCurrent();
    
    // JAILBREAK EXECUTION: Validate prices
    if(m_lastBid <= 0 || m_lastAsk <= 0)
    {
        return false;
    }
    
    // JAILBREAK EXECUTION: Check spread
    double maxSpread = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * 2 * SymbolInfoDouble(Symbol(), SYMBOL_POINT);
    if(m_lastSpread > maxSpread)
    {
        return false;
    }
    
    // JAILBREAK EXECUTION: Check market hours
    if(!IsTradeAllowed())
    {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| JAILBREAK EXECUTION: Calculate Slippage                         |
//+------------------------------------------------------------------+
double CHighFrequencyExecutor::CalculateSlippage(double requestedPrice, double executedPrice, ENUM_ORDER_TYPE orderType)
{
    if(orderType == ORDER_TYPE_BUY)
    {
        return executedPrice - requestedPrice;  // Positive = worse for buyer
    }
    else
    {
        return requestedPrice - executedPrice;  // Positive = worse for seller
    }
}

//+------------------------------------------------------------------+
//| JAILBREAK EXECUTION: Update Performance Metrics                 |
//+------------------------------------------------------------------+
void CHighFrequencyExecutor::UpdatePerformanceMetrics(const CExecutionResult& result)
{
    m_totalExecutions++;
    
    if(result.result == EXECUTION_SUCCESS)
    {
        m_successfulExecutions++;
        
        // JAILBREAK EXECUTION: Update execution time metrics
        if(result.executionTimeNs < m_minExecutionTimeNs)
            m_minExecutionTimeNs = result.executionTimeNs;
        
        if(result.executionTimeNs > m_maxExecutionTimeNs)
            m_maxExecutionTimeNs = result.executionTimeNs;
        
        m_averageExecutionTimeNs = (m_averageExecutionTimeNs * (m_successfulExecutions - 1) + 
                                   result.executionTimeNs) / m_successfulExecutions;
        
        // JAILBREAK EXECUTION: Update slippage metrics
        double absSlippage = MathAbs(result.slippage);
        if(absSlippage > m_maxSlippage)
            m_maxSlippage = absSlippage;
        
        m_averageSlippage = (m_averageSlippage * (m_successfulExecutions - 1) + 
                           absSlippage) / m_successfulExecutions;
    }
    else
    {
        m_failedExecutions++;
    }
}

//+------------------------------------------------------------------+
//| JAILBREAK EXECUTION: Add To History                             |
//+------------------------------------------------------------------+
void CHighFrequencyExecutor::AddToHistory(const CExecutionResult& result)
{
    m_executionHistory[m_historyIndex] = result;
    m_historyIndex = (m_historyIndex + 1) % 1000;
    
    if(m_totalHistoryEntries < 1000)
        m_totalHistoryEntries++;
}

//+------------------------------------------------------------------+
//| JAILBREAK EXECUTION: Get Success Rate                           |
//+------------------------------------------------------------------+
double CHighFrequencyExecutor::GetSuccessRate() const
{
    if(m_totalExecutions > 0)
    {
        return (double)m_successfulExecutions / m_totalExecutions;
    }
    return 0.0;
}

//+------------------------------------------------------------------+
//| JAILBREAK EXECUTION: Is Market Open                             |
//+------------------------------------------------------------------+
bool CHighFrequencyExecutor::IsMarketOpen()
{
    return IsTradeAllowed() && 
           SymbolInfoDouble(Symbol(), SYMBOL_BID) > 0 && 
           SymbolInfoDouble(Symbol(), SYMBOL_ASK) > 0;
}
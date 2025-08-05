# EscapeEA Trading Sequence

## Paper Trading to Live Trading Cycle

```mermaid
sequenceDiagram
    participant User
    participant EA as EscapeEA
    participant PT as PaperTrading
    participant RM as RiskManager
    participant TE as TradeExecutor
    participant MT5 as MT5 Terminal
    
    User->>EA: Attach to Chart
    EA->>PT: Initialize Paper Trading
    EA->>RM: Initialize Risk Manager
    EA->>TE: Initialize Trade Executor
    
    loop Every Tick
        EA->>PT: Check Paper Trades
        PT-->>EA: Update Paper P&L
        
        EA->>RM: Check Risk Parameters
        RM-->>EA: Risk Status
        
        EA->>TE: Check Circuit Breaker
        
        alt Trading Signal Generated
            EA->>PT: Execute Paper Trade
            PT-->>EA: Paper Trade Executed
            
            EA->>PT: Check Win/Loss
            PT-->>EA: Update Win/Loss Count
            
            alt 3/5 Paper Trades Won
                EA->>TE: Enable Live Trading
                EA->>TE: Execute Live Trade
                TE->>MT5: Place Order
                MT5-->>TE: Order Confirmation
                TE-->>EA: Trade Executed
                
                EA->>PT: Reset Paper Trading
            end
        end
    end
```

## Order Execution Flow

```mermaid
sequenceDiagram
    participant EA as EscapeEA
    participant RM as RiskManager
    participant TE as TradeExecutor
    participant MT5 as MT5 Terminal
    
    EA->>RM: Check Risk Parameters
    RM-->>EA: Risk Status OK
    
    EA->>RM: Calculate Position Size
    RM-->>EA: Lot Size
    
    EA->>TE: Execute Trade (Buy/Sell)
    TE->>TE: Validate Trade
    TE->>MT5: Send Order
    
    alt Order Successful
        MT5-->>TE: Order Confirmation
        TE-->>EA: Trade Executed
        EA->>EA: Update Trade Log
    else Order Failed
        MT5-->>TE: Error Code
        TE->>TE: Handle Error
        TE-->>EA: Trade Failed
        EA->>EA: Log Error
        
        alt Retry Available
            TE->>MT5: Retry Order
        else Max Retries Reached
            TE->>EA: Circuit Breaker Triggered
        end
    end
```

## Error Handling Flow

```mermaid
flowchart TD
    A[Trade Execution] --> B{Success?}
    B -->|Yes| C[Update Trade Log]
    B -->|No| D{Retry Count < Max?}
    D -->|Yes| E[Increment Retry Counter]
    E --> F[Wait and Retry]
    F --> A
    D -->|No| G[Trigger Circuit Breaker]
    G --> H[Log Error]
    H --> I[Disable Trading]
    I --> J{Check Timer Expired?}
    J -->|No| J
    J -->|Yes| K[Reset Circuit Breaker]
    K --> A
```

## Paper Trading State Machine

```mermaid
stateDiagram-v2
    [*] --> PaperTrading
    PaperTrading --> PaperTrading: Execute Paper Trade
    PaperTrading --> PaperTrading: Update Win/Loss
    
    PaperTrading --> LiveTrading: 3/5 Wins Achieved
    LiveTrading --> ExecuteLiveTrade: Signal Generated
    
    ExecuteLiveTrade --> PaperTrading: Trade Closed
    
    state LiveTrading {
        [*] --> WaitForSignal
        WaitForSignal --> ExecuteLiveTrade: Valid Signal
        ExecuteLiveTrade --> WaitForClose: Order Filled
        WaitForClose --> WaitForSignal: Position Closed
    }
    
    state PaperTrading {
        [*] --> WaitForSignal
        WaitForSignal --> ExecutePaperTrade: Valid Signal
        ExecutePaperTrade --> UpdateStats: Trade Closed
        UpdateStats --> CheckWinCondition
        
        CheckWinCondition --> WaitForSignal: Not Enough Trades
        CheckWinCondition --> [*]: 3/5 Wins Achieved
    }
```

## Component Interaction

```mermaid
graph TD
    A[Market Data] --> B[EscapeEA]
    B --> C[Signal Generator]
    C --> D[Risk Manager]
    D --> E[Trade Executor]
    E --> F[MT5 Terminal]
    
    B --> G[Paper Trading Engine]
    G --> B
    G --> E
    
    B --> H[Chart Visualization]
    E --> H
    G --> H
    
    style B fill:#f9f,stroke:#333,stroke-width:2px
    style C fill:#bbf,stroke:#333,stroke-width:2px
    style D fill:#fbb,stroke:#333,stroke-width:2px
    style E fill:#bfb,stroke:#333,stroke-width:2px
    style G fill:#ffb,stroke:#333,stroke-width:2px
```

## Notes

1. The paper trading system requires 3 out of 5 winning trades before enabling live trading
2. After each live trade, the system returns to paper trading mode
3. All trades (paper and live) are visually represented on the chart
4. The system includes comprehensive error handling and circuit breakers
5. Risk management is applied to both paper and live trades
6. The state is maintained between restarts using global variables



escape_ib/
│
├── config/                      # Configuration files
│   ├── __init__.py
│   ├── config.ini               # Main configuration
│   └── ib_config.json           # IB-specific settings
│
├── data/                        # Data storage
│   ├── __init__.py
│   ├── database.py              # SQLite database interface
│   └── models.py                # Database models
│
├── ib_client/                   # IB API interaction
│   ├── __init__.py
│   ├── client.py                # Main IB client
│   ├── data_handler.py          # Market data handling
│   ├── order_manager.py         # Order execution
│   └── contract_manager.py      # Contract definitions
│
├── strategy/                    # Trading strategies
│   ├── __init__.py
│   ├── base_strategy.py         # Base strategy class
│   └── escape_strategy.py       # Our specific strategy
│
├── learning/                    # Adaptive learning components
│   ├── __init__.py
│   ├── adaptive_engine.py       # Learning logic
│   ├── statistics.py            # Trade statistics
│   └── risk_manager.py          # Risk management
│
├── utils/                       # Utility functions
│   ├── __init__.py
│   ├── logger.py                # Logging configuration
│   ├── helpers.py               # Helper functions
│   └── constants.py             # Global constants
│
├── tests/                       # Unit tests
│   ├── __init__.py
│   ├── test_strategy.py
│   └── test_ib_client.py
│
├── .gitignore                   # Git ignore file
├── requirements.txt             # Python dependencies
├── README.md                    # Project documentation
└── main.py                      # Main application entry point
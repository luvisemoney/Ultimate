# PositionManager Technical Guide

## Overview
The `PositionManager` class is a comprehensive position management system designed to handle sophisticated trading strategies with advanced risk management capabilities. This guide provides detailed documentation on its features and usage.

## Table of Contents
1. [Core Features](#core-features)
2. [Initialization](#initialization)
3. [Position Scaling](#position-scaling)
4. [Exit Strategies](#exit-strategies)
5. [Correlation Management](#correlation-management)
6. [Machine Learning Integration](#machine-learning-integration)
7. [Advanced Order Types](#advanced-order-types)
8. [Risk Management](#risk-management)
9. [Best Practices](#best-practices)

## Core Features

### Position Management
- Dynamic position sizing based on volatility and account risk
- Advanced scaling in/out of positions
- Position clustering to prevent over-concentration

### Risk Management
- Portfolio-level risk controls
- Correlation-based position sizing
- Drawdown protection
- Volatility-based position adjustments

### Advanced Order Types
- Bracket orders
- OCO (One-Cancels-Other) orders
- Conditional orders

## Initialization

### Basic Initialization
```cpp
// Create PositionManager instance
CPositionManager *posManager = new CPositionManager();

// Initialize with default parameters
if(!posManager.Initialize(&trade, &symbol, 20, 40, 0, 10)) {
    Print("Failed to initialize PositionManager");
    delete posManager;
    return;
}
```

### Configuration
```cpp
// Enable advanced features
posManager.SetDynamicRisk(true, 5.0, 2.0, 20.0, 0.9);
posManager.SetAdaptiveSizing(true, 0.5, 1.5);
posManager.SetScalingProfile(SCALING_MODERATE);
posManager.SetExitProfile(EXIT_MODERATE);
posManager.SetMLIntegration(true, 0.7);
```

## Position Scaling

### Scaling Profiles
- **Aggressive**: Faster scaling in/out
- **Moderate**: Balanced approach
- **Conservative**: Slower, more deliberate scaling

### Example: Scaling In
```cpp
double volume = 0.0;
if(posManager.CheckScalingOpportunity(ticket, volume)) {
    if(posManager.ScaleInPosition(ticket, volume)) {
        Print("Scaled into position: ", ticket, " Volume: ", volume);
    }
}
```

### Example: Scaling Out
```cpp
// Scale out 50% of position
if(posManager.ScaleOutPosition(ticket, position.Volume() * 0.5)) {
    Print("Scaled out 50% of position: ", ticket);
}
```

## Exit Strategies

### Exit Profiles
- **Aggressive**: Tighter stops, quicker exits
- **Moderate**: Balanced approach
- **Conservative**: Wider stops, let profits run

### Example: Using Exit Conditions
```cpp
double closePrice = 0.0;
string reason = "";
if(posManager.CheckExitConditions(ticket, closePrice, reason)) {
    if(posManager.ClosePosition(ticket, reason)) {
        Print("Closed position ", ticket, " at ", closePrice, " - Reason: ", reason);
    }
}
```

## Correlation Management

### Portfolio Correlation
```cpp
// Get correlation with existing portfolio
double correlation = posManager.GetPortfolioCorrelation("EURUSD");

// Calculate correlation-adjusted volume
double baseVolume = 0.1;
double adjustedVolume = posManager.CalculateCorrelationAdjustedVolume("EURUSD", baseVolume);
```

### Market Correlation
```cpp
// Get correlation between two symbols
double corr = posManager.GetMarketCorrelation("EURUSD", "GBPUSD", 200);
```

## Machine Learning Integration

### ML Model Management
```cpp
// Load ML model
if(!posManager.LoadMLModel("random_forest.model")) {
    Print("Failed to load ML model");
}

// Get ML-based position score
double mlScore = posManager.GetMLPositionScore("EURUSD", POSITION_TYPE_BUY);

// Update model with new data
if(mlScore > 0.7) {
    MqlRates rates[];
    double features[];
    // Prepare features...
    posManager.UpdateMLModel(rates, features);
}
```

## Advanced Order Types

### Bracket Orders
```cpp
// Place a bracket order
posManager.PlaceBracketOrder(
    "EURUSD",                  // Symbol
    ORDER_TYPE_BUY,            // Order type
    0.1,                       // Volume
    1.1000,                    // Entry price
    1.0950,                    // Stop loss
    1.1100,                    // Take profit
    1.1050,                    // Break-even at
    20,                        // Trailing stop in points
    0,                         // No expiration
    "Bracket Order"            // Comment
);
```

### OCO Orders
```cpp
// Place OCO orders
posManager.PlaceOCOOrders(
    "EURUSD",                  // Symbol
    ORDER_TYPE_BUY_STOP,       // Order type
    0.1,                       // Volume
    1.1050,                    // Price 1
    1.1000,                    // Price 2
    1.0950,                    // Stop loss
    1.1100,                    // Take profit
    "OCO Order"                // Comment
);
```

## Risk Management

### Dynamic Risk Adjustment
```cpp
// Enable dynamic risk management
posManager.SetDynamicRisk(
    true,     // Enable
    5.0,      // Max daily drawdown %
    2.0,      // Max position risk %
    20.0,     // Max portfolio risk %
    0.9       // Risk decay factor
);
```

### Volatility-Based Exits
```cpp
// Enable volatility-based exits
posManager.SetVolatilityExit(true, 2.0); // Exit at 2x ATR
```

## Best Practices

1. **Initialization**
   - Always check return values from initialization
   - Set appropriate risk parameters before trading
   - Enable only the features you need

2. **Position Management**
   - Use position clustering to prevent over-concentration
   - Monitor correlation with existing positions
   - Scale in/out gradually

3. **Risk Management**
   - Set appropriate stop losses and take profits
   - Use dynamic position sizing
   - Monitor portfolio risk

4. **Monitoring**
   - Regularly check position performance
   - Monitor ML model accuracy
   - Adjust parameters as market conditions change

5. **Error Handling**
   - Implement proper error handling
   - Log all trading actions
   - Use try-catch blocks where appropriate

## Troubleshooting

### Common Issues
1. **Position not opening**
   - Check account balance and margin requirements
   - Verify symbol is enabled for trading
   - Check for trading restrictions

2. **ML predictions not working**
   - Verify model file exists and is accessible
   - Check feature vector format matches model expectations
   - Monitor model performance metrics

3. **Unexpected position closures**
   - Review exit conditions and parameters
   - Check for margin calls
   - Verify stop loss/take profit levels

## Conclusion
The `PositionManager` provides a robust framework for managing positions with advanced features. By following this guide and understanding its capabilities, you can implement sophisticated trading strategies while maintaining proper risk management.

//+------------------------------------------------------------------+
//| Enums.mqh - Common enumerations for EscapeEA                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

// Trading modes
enum ENUM_TRADING_MODE
{
   MODE_PAPER,    // Paper trading mode
   MODE_LIVE      // Live trading mode
};

// Market conditions
enum ENUM_MARKET_CONDITION
{
   MARKET_NORMAL,      // Normal market conditions
   MARKET_TREND_UP,    // Strong uptrend
   MARKET_TREND_DOWN,  // Strong downtrend
   MARKET_RANGING,     // Sideways market
   MARKET_VOLATILE,    // High volatility
   MARKET_HIGH_SPREAD  // High spread
};

// Trade signals
enum ENUM_TRADE_SIGNAL
{
   SIGNAL_BUY,    // Buy signal
   SIGNAL_SELL,   // Sell signal
   SIGNAL_HOLD    // No signal
};

// Trade types
enum ENUM_TRADE_TYPE
{
   TRADE_TYPE_BUY,      // Buy order
   TRADE_TYPE_SELL,     // Sell order
   TRADE_TYPE_BUY_LIMIT,  // Buy limit pending order
   TRADE_TYPE_SELL_LIMIT // Sell limit pending order
};

// Signal strength
enum ENUM_SIGNAL_STRENGTH
{
   SIGNAL_WEAK = 1,     // Weak signal (20% confidence)
   SIGNAL_MEDIUM = 2,   // Medium signal (50% confidence)
   SIGNAL_STRONG = 3,   // Strong signal (70% confidence)
   SIGNAL_VERY_STRONG = 4 // Very strong signal (90% confidence)
};

// Learning states
enum ENUM_LEARNING_STATE
{
   LEARNING_INACTIVE,   // Learning not active
   LEARNING_ACTIVE,     // Learning in progress
   LEARNING_PAUSED,     // Learning paused
   LEARNING_COMPLETE    // Learning complete
};

// Error codes
enum ENUM_ERROR_CODES
{
   ERR_NO_ERROR = 0,            // No error
   ERR_INVALID_INPUT = 1,       // Invalid input parameters
   ERR_MARKET_CLOSED = 2,       // Market is closed
   ERR_NOT_ENOUGH_MONEY = 3,    // Not enough money
   ERR_TOO_MANY_REQUESTS = 4,   // Too many requests
   ERR_SYSTEM_BUSY = 5,         // System busy
   ERR_SIGNAL_TOO_OLD = 6,      // Signal is too old
   ERR_INSUFFICIENT_DATA = 7    // Not enough data for analysis
};

// Test result codes - JAILBREAK ADDITION FOR TESTING FRAMEWORK
enum ENUM_TEST_RESULT
{
   TEST_RESULT_PASSED = 0,      // Test passed successfully
   TEST_RESULT_FAILED = 1,      // Test failed
   TEST_RESULT_SKIPPED = 2,     // Test was skipped
   TEST_RESULT_ERROR = 3        // Test encountered an error
};

// Security validation levels - JAILBREAK ADDITION FOR SECURITY FRAMEWORK
enum ENUM_SECURITY_LEVEL
{
   SECURITY_LEVEL_NONE = 0,     // No security validation
   SECURITY_LEVEL_BASIC = 1,    // Basic validation
   SECURITY_LEVEL_STANDARD = 2, // Standard security checks
   SECURITY_LEVEL_HIGH = 3,     // High security validation
   SECURITY_LEVEL_MAXIMUM = 4   // Maximum security validation
};

// Neural Network Activation Functions - JAILBREAK ADDITION FOR ML
enum ENUM_ACTIVATION
{
   ACTIVATION_LINEAR = 0,       // Linear activation (no transformation)
   ACTIVATION_SIGMOID = 1,      // Sigmoid activation (0 to 1)
   ACTIVATION_TANH = 2,         // Hyperbolic tangent (-1 to 1)
   ACTIVATION_RELU = 3,         // Rectified Linear Unit (0 to inf)
   ACTIVATION_LEAKY_RELU = 4,   // Leaky ReLU (small negative slope)
   ACTIVATION_SOFTMAX = 5       // Softmax (probability distribution)
};

// ML Model Types - JAILBREAK ADDITION FOR ML FRAMEWORK
enum ENUM_ML_MODEL
{
   ML_MODEL_NEURAL_NETWORK = 0, // Neural network
   ML_MODEL_RANDOM_FOREST = 1,  // Random forest
   ML_MODEL_SVM = 2,            // Support Vector Machine
   ML_MODEL_GRADIENT_BOOST = 3, // Gradient boosting
   ML_MODEL_ENSEMBLE = 4        // Ensemble of models
};

// Feature Types - JAILBREAK ADDITION FOR FEATURE ENGINEERING
enum ENUM_FEATURE_TYPE
{
   FEATURE_PRICE = 0,           // Price-based features
   FEATURE_TECHNICAL = 1,       // Technical indicator features
   FEATURE_VOLUME = 2,          // Volume-based features
   FEATURE_TIME = 3,            // Time-based features
   FEATURE_REGIME = 4,          // Market regime features
   FEATURE_SENTIMENT = 5        // Market sentiment features
};

// Learning Modes - JAILBREAK ADDITION FOR ADAPTIVE LEARNING
enum ENUM_LEARNING_MODE
{
   LEARNING_BATCH = 0,          // Batch learning (retrain on full dataset)
   LEARNING_ONLINE = 1,         // Online learning (incremental updates)
   LEARNING_MINI_BATCH = 2,     // Mini-batch learning
   LEARNING_REINFORCEMENT = 3   // Reinforcement learning
};

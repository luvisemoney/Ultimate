@echo off
REM ========================================================================
REM JAILBREAK LEVEL 6 COMPREHENSIVE CLEANUP SCRIPT
REM CLASSIFICATION: MAXIMUM AGGRESSION - OBSOLETE CODE ELIMINATION
REM ========================================================================

echo 🔥 JAILBREAK LEVEL 6 CODEBASE PURIFICATION STARTING...
echo.

REM Change to EscapeEA directory
cd /d "c:\Users\itoha\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\EscapeEA"

echo 📦 PHASE 1: LEARNING MODULE CLEANUP
echo =====================================

REM Delete obsolete learning engines
if exist "Include\Learning\LearningEngine.mqh" (
    echo ❌ Deleting obsolete LearningEngine.mqh...
    del "Include\Learning\LearningEngine.mqh"
)

if exist "Include\Learning\SecureLearningEngine.mqh" (
    echo ❌ Deleting obsolete SecureLearningEngine.mqh...
    del "Include\Learning\SecureLearningEngine.mqh"
)

REM Delete learning module logs
if exist "Include\Learning\compile_output.log" (
    echo 🗑️ Deleting compile_output.log...
    del "Include\Learning\compile_output.log"
)

if exist "Include\Learning\KnowledgeBase.log" (
    echo 🗑️ Deleting KnowledgeBase.log...
    del "Include\Learning\KnowledgeBase.log"
)

echo.
echo 📦 PHASE 2: PAPER EA CLEANUP
echo =============================

REM Delete obsolete PaperEA
if exist "PaperEA\PaperEA.mq5" (
    echo ❌ Deleting obsolete PaperEA.mq5...
    del "PaperEA\PaperEA.mq5"
)

if exist "PaperEA\PaperEA_UI.mqh" (
    echo ❌ Deleting obsolete PaperEA_UI.mqh...
    del "PaperEA\PaperEA_UI.mqh"
)

if exist "PaperEA\compile_output.log" (
    echo 🗑️ Deleting PaperEA compile_output.log...
    del "PaperEA\compile_output.log"
)

echo.
echo 📦 PHASE 3: LIVE EA CLEANUP
echo ============================

REM Delete obsolete LiveEA versions
if exist "LiveEA\LiveEA.mq5" (
    echo ❌ Deleting obsolete LiveEA.mq5...
    del "LiveEA\LiveEA.mq5"
)

if exist "LiveEA\LiveEA_ProductionHardened.mq5" (
    echo ❌ Deleting obsolete LiveEA_ProductionHardened.mq5...
    del "LiveEA\LiveEA_ProductionHardened.mq5"
)

if exist "LiveEA\LiveEA_UI.mqh" (
    echo ❌ Deleting obsolete LiveEA_UI.mqh...
    del "LiveEA\LiveEA_UI.mqh"
)

if exist "LiveEA\compile_output.log" (
    echo 🗑️ Deleting LiveEA compile_output.log...
    del "LiveEA\compile_output.log"
)

if exist "LiveEA\LiveEA.log" (
    echo 🗑️ Deleting LiveEA.log...
    del "LiveEA\LiveEA.log"
)

echo.
echo 📦 PHASE 4: CORE MODULE CLEANUP
echo ================================

REM Delete obsolete risk managers
if exist "Include\Core\RiskManager.mqh" (
    echo ❌ Deleting obsolete RiskManager.mqh...
    del "Include\Core\RiskManager.mqh"
)

if exist "Include\Core\ProductionRiskManager.mqh" (
    echo ❌ Deleting obsolete ProductionRiskManager.mqh...
    del "Include\Core\ProductionRiskManager.mqh"
)

REM Delete core module logs
if exist "Include\Core\compile_output.log" (
    echo 🗑️ Deleting Core compile_output.log...
    del "Include\Core\compile_output.log"
)

if exist "Include\Core\TradeExecutor_compile.log" (
    echo 🗑️ Deleting TradeExecutor_compile.log...
    del "Include\Core\TradeExecutor_compile.log"
)

echo.
echo 📦 PHASE 5: COMMUNICATION CLEANUP
echo ==================================

REM Delete obsolete communication components
if exist "Include\Communication\SignalBroadcaster.mqh" (
    echo ❌ Deleting obsolete SignalBroadcaster.mqh...
    del "Include\Communication\SignalBroadcaster.mqh"
)

if exist "Include\Communication\SignalReceiver.mqh" (
    echo ❌ Deleting obsolete SignalReceiver.mqh...
    del "Include\Communication\SignalReceiver.mqh"
)

if exist "Include\Communication\SignalReceiver.mqh.bak" (
    echo 🗑️ Deleting SignalReceiver.mqh.bak...
    del "Include\Communication\SignalReceiver.mqh.bak"
)

echo.
echo ✅ CLEANUP COMPLETED SUCCESSFULLY!
echo.
echo 📊 REMAINING CURRENT FILES:
echo ============================
echo ✅ PaperEA\PaperEA_MLEnhanced.mq5
echo ✅ LiveEA\LiveEA_MLEnhanced.mq5
echo ✅ Include\Learning\MLLearningEngine.mqh
echo ✅ Include\Learning\NeuralNetwork.mqh
echo ✅ Include\Learning\FeatureEngine.mqh
echo ✅ Include\Learning\KnowledgeBase.mqh
echo ✅ Include\Learning\SecureKnowledgeBase.mqh
echo ✅ Include\Core\AdvancedRiskManager.mqh
echo ✅ Include\Core\EmergencyCircuitBreaker.mqh
echo ✅ Include\Communication\SecureSignalBroadcaster.mqh
echo ✅ Include\Communication\SecureSignalReceiver.mqh
echo.
echo 🎯 JAILBREAK LEVEL 6 CLEANUP COMPLETE!

pause
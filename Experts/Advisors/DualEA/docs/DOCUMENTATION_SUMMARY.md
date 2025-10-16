# DualEA Documentation Summary

This document provides an overview of all documentation files in the DualEA project and their purposes.

## Core Documentation

### [README.md](README.md)
- Primary project documentation
- System overview, architecture, and implementation status
- Quick start guide and configuration references
- Roadmap and development phases

### [README_PRODUCTION.md](README_PRODUCTION.md)
- Quick reference guide for production deployment
- System architecture diagrams
- Key configuration parameters
- Execution pipeline overview

## System Guides

### [PaperEA_README.md](PaperEA_README.md)
- Paper trading system overview
- Architecture and file locations
- Configuration highlights
- Quick start guide

### [LiveEA_README.md](LiveEA_README.md)
- Live trading system overview
- Architecture and file locations
- Key behaviors and telemetry
- Quick start guide

### [DualEA_Handbook.md](DualEA_Handbook.md)
- Concise guide for operating, extending, and validating DualEA
- Architecture overview
- Files and paths
- Key inputs and timer wiring

### [DualEA_Lifecycle_Handbook.md](DualEA_Lifecycle_Handbook.md)
- End-to-end runbook for bringing up DualEA
- PaperEA bring-up and validation
- Promotion readiness review
- Live operations and rollback procedures

### [UnifiedSystemGuide.md](UnifiedSystemGuide.md)
- Guide to the unified system integration
- Core components (ConfigManager, EventBus, SystemMonitor)
- Integration benefits and migration from legacy system
- Usage examples and best practices

## Implementation Plans

### [CORE_IMPLEMENTATION_PLAN.md](CORE_IMPLEMENTATION_PLAN.md)
- Core teams implementation plan
- Architecture refactoring
- Risk management and trade execution

### [PaperEA_IMPLEMENTATION_PLAN.md](PaperEA_IMPLEMENTATION_PLAN.md)
- PaperEA implementation plan
- Architecture and ML filter integration
- Data and insights management

### [LiveEA_IMPLEMENTATION_PLAN.md](LiveEA_IMPLEMENTATION_PLAN.md)
- LiveEA implementation plan
- Architecture and ML filter integration
- Live safety considerations

### [Phase-Implementation.md](Phase-Implementation.md)
- Complete roadmap for Phases 1-11
- Status, TODOs, and implementation priorities

### [Phase3.md](Phase3.md)
- Phase 3 implementation details
- Documentation alignment
- Code hygiene and final scoring

### [GATE_MIGRATION_GUIDE.md](GATE_MIGRATION_GUIDE.md)
- Gate system migration guide
- Legacy to new 8-stage gate system
- Implementation checklist

### [STRATEGY_UNLOCK_IMPLEMENTATION_PLAN.md](STRATEGY_UNLOCK_IMPLEMENTATION_PLAN.md)
- Strategy enablement implementation plan
- Asset-class universe and symbol onboarding
- Data and feature engineering

## Configuration and Reference

### [Configuration-Reference.md](Configuration-Reference.md)
- Comprehensive guide to all 180+ input parameters
- PaperEA_v2 and LiveEA configuration
- Configuration patterns and best practices

### [Execution-Pipeline.md](Execution-Pipeline.md)
- Complete trade execution flow
- 8-stage pipeline details
- Paper trading and live trading flows

### [Policy-Exploration-Guide.md](Policy-Exploration-Guide.md)
- ML policy gating and fallback modes
- Exploration system
- Troubleshooting guide

### [KB-Schemas.md](KB-Schemas.md)
- CSV schemas for knowledge base files
- features.csv, knowledge_base.csv, explore_counts.csv

### [PolicySchema.md](PolicySchema.md)
- Expected structure of policy.json
- Top-level fields and slice fields
- Aggregation and lookup logic

## Operations and Monitoring

### [Operations.md](Operations.md)
- Practical procedures for managing DualEA runtime
- Knowledge base management
- Policy reloads and log interpretation
- Maintenance procedures

### [Observability-Guide.md](Observability-Guide.md)
- Reference for telemetry and monitoring
- Telemetry system and event types
- Debugging techniques
- Performance monitoring

### [Redis_Schema.md](Redis_Schema.md)
- Redis schema for the nuclear system
- Key naming conventions
- Data structures and access patterns

## Technical Guides

### [PositionManager_Guide.md](PositionManager_Guide.md)
- Technical guide for PositionManager
- Position scaling and exit strategies
- Correlation management
- Risk management

### [ENHANCED_STRATEGIES.md](ENHANCED_STRATEGIES.md)
- Level 100 strategy enhancement
- Strategy categories and implementation details
- Risk management features
- Performance optimization

## Action Framework

### [DualEA_Action_Framework.md](DualEA_Action_Framework.md)
- Pre-implementation plan
- 3 Phases × 3 Cycles model
- Action backlog and control gates

## Appendices and Additional Documentation

### [Appendices.md](Appendices.md)
- Red-team artifacts
- Data schemas
- CI/CD integration
- Troubleshooting guide

### [# FUCKING SCIENTIFIC PROTOCOL FOR SUNNY-.md](# FUCKING SCIENTIFIC PROTOCOL FOR SUNNY-.md)
- Radical alternatives for ML/EA pipeline
- Advanced data storage and processing approaches
- Real-time ML inference

### [NUCLEAR_SYSTEM_README.md](NUCLEAR_SYSTEM_README.md)
- Nuclear system implementation guide
- Redis-based state management
- gRPC ML service

### [NUCLEAR_IMPLEMENTATION_COMPLETE.md](NUCLEAR_IMPLEMENTATION_COMPLETE.md)
- Nuclear-grade optimization implementation
- VaR and Expected Shortfall risk metrics
- Kelly Criterion position sizing

### [UNIVERSAL_AUTO_DETECTION_IMPLEMENTATION.md](UNIVERSAL_AUTO_DETECTION_IMPLEMENTATION.md)
- Universal auto-detection implementation
- Autonomous symbol analysis engine

### [SL_TP_FIX_SUMMARY.md](SL_TP_FIX_SUMMARY.md)
- SL/TP critical bug fix summary
- Root cause analysis
- Fixes applied and testing

## Build and Development

### [BUILD.md](../BUILD.md)
- Build system documentation
- Prerequisites and usage
- Error resolution

### [COMPILATION_FIXES.md](COMPILATION_FIXES.md)
- Compilation fixes and improvements
- Build script enhancements
- Error handling

## License

Copyright 2025, Windsurf Engineering.

This documentation is proprietary and confidential. Unauthorized copying or distribution is prohibited.

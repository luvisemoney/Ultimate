# DualEA Nuclear System - Complete Implementation Guide

## 🚀 Overview

The DualEA Nuclear System is a complete rewrite and merger of PaperEA and LiveEA into a unified, real-time, high-performance trading system with:

- **Redis-based state management** (replacing file-based KB)
- **gRPC ML service** for real-time predictions
- **FastAPI WebSocket server** for live dashboard streaming
- **Svelte dashboard** for real-time monitoring
- **Async event queue** for parallel processing
- **Hot-reload** strategies, gates, and policy via Redis pub/sub

---

## 📋 System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         MT5 Terminal                         │
│  ┌────────────────────────────────────────────────────────┐

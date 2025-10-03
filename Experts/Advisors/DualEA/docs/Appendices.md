# Appendices — DualEA System

**Red-team artifacts, schemas, and operational procedures**

---

## Table of Contents

1. [Red-Team Artifacts](#red-team-artifacts)
2. [Schema Reference](#schema-reference)
3. [File Locations](#file-locations)
4. [Operational Procedures](#operational-procedures)
5. [Troubleshooting Checklist](#troubleshooting-checklist)

---

## Red-Team Artifacts

### Purpose

Operationalize the 3×3 red-team process by storing Q&A logs, expert rebuttals, and jailbreak traces for audit and improvement.

### Storage Location

**Base Path**: `Common/Files/DualEA/jailbreak/`

**Run Layout**:
```
jailbreak/
├── runs/
│   └── YYYYMMDD_HHMMSS/
│       ├── qna.md                  # Q&A log
│       ├── rebuttals.jsonl         # Expert rebuttals
│       ├── traces.jsonl            # Jailbreak traces
│       └── summary.md              # Session summary
└── latest/                         # Symlink/copy of latest run
```

### Q&A Log (Markdown)

**Format**: `qna.md`

```markdown
# Red-Team Q&A — 2025-01-15 10:00:00

## Q1: Can exploration bypass trigger with existing slice?
- Context: `Experts/Advisors/DualEA/PaperEA/PaperEA_v2.mq5` lines 1234-1250
- Hypothesis: Exploration should only trigger when slice missing
- Answer: Bypass is no-slice-only; existing under-threshold slices are gated
- Evidence: Line 1240: `if(slice.totalTrades == 0 && UseExploration)`
- Outcome: **PASS**

## Q2: Are policy fallbacks restricted to demo by default?
- Context: `Experts/Advisors/DualEA/LiveEA/LiveEA.mq5` lines 567-590
- Hypothesis: FallbackDemoOnly should prevent live fallbacks
- Answer: Correct - demo check enforced on lines 575-578
- Evidence: `if(FallbackDemoOnly && !IsDemo()) return false;`
- Outcome: **PASS**
```

### Expert Rebuttals (JSONL)

**Format**: `rebuttals.jsonl` (one JSON per line)

```jsonl
{"id":"rb_0001","claim":"Exploration bypass triggers with existing slice","rebuttal":"Bypass is no-slice-only; existing under-threshold slices are gated","evidence_files":["Experts/Advisors/DualEA/PaperEA/PaperEA_v2.mq5"],"decision_paths":["Gate->Insights->ExploreCaps"],"status":"resolved","timestamp":"2025-01-15T10:00:00Z"}
{"id":"rb_0002","claim":"Policy fallback allows live trading without ML","rebuttal":"Fallback

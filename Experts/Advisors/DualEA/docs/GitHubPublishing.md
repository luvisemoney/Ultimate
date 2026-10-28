# GitHub publication verification — 2026-10-28

## Phase 1: audit and requirements
### Cycle 1: structural audit
The existing `luvisemoney/Ultimate` repository was preserved. The source publisher uses an isolated `.publish/Ultimate` checkout and a source-file allowlist. It never force-pushes.
### Cycle 2: requirements mapping
`ML/Sync-GitHubRepository.ps1` publishes source; `ML/Export-DashboardSnapshot.ps1` publishes aggregate evidence and the actual policy; `.github/workflows/dashboard.yml` builds and deploys the static dashboard.
### Cycle 3: risk closure
New terminal accounts, browser profiles, environments, raw logs and bulk datasets are excluded. A proposed cleanup of already tracked generated files was rejected by automatic approval review; those existing paths were restored to the index before publication. No file deletions were included in the resulting update. Existing content remains in repository history.

## Phase 2: implementation and validation
### Cycle 1: decomposition
The browser dashboard, policy delivery, local synchronization and MT5 runtime are separate components. Pages serves files; it does not execute the EA or a permanent Python/PowerShell backend.
### Cycle 2: build and review
The dashboard uses relative URLs compatible with `/Ultimate/`, safe text rendering, symbol filtering, news search and explicit freshness labels. Negative results and unmatched current-binary evidence remain visible. Snapshot fingerprints prevent commits caused only by export timestamps. The sync script rejects common credential signatures and possible embedded credentials.
### Cycle 3: verification
Local validation and desktop/mobile browser checks passed. GitHub deployment runs [40749216297](https://github.com/luvisemoney/Ultimate/actions/runs/40749216297) and [40749508493](https://github.com/luvisemoney/Ultimate/actions/runs/40749508493) succeeded. Manual run [40749630783](https://github.com/luvisemoney/Ultimate/actions/runs/40749630783) also succeeded, including the official calendar refresh. Live dashboard and policy URLs returned HTTP 200; 144 policy entries were parsed and the source provenance hash matched the local published policy.

## Phase 3: operation and limits
### Cycle 1: documentation
Public endpoints: [dashboard](https://luvisemoney.github.io/Ultimate/), [policy.json](https://luvisemoney.github.io/Ultimate/policy.json), [deployment history](https://github.com/luvisemoney/Ultimate/actions).
### Cycle 2: automatic synchronization
`ML/Install-GitHubAutoSync.ps1` installed `DualEA-GitHubSourceSync` at logon and every five minutes under the current Windows user. Its first observed run exited with result 0. It calls `ML/Run-GitHubAutoSync.ps1`, which prevents overlapping syncs, exports the allowlisted snapshot and pushes changed source. The user must be logged on and this machine must be running. GitHub CLI authentication stays in the Windows user profile, outside the repository.
### Cycle 3: remaining qualification
The website and last published JSON stay hosted while the laptop is off. Local source updates, Forex Factory collection and MT5 execution stop with the laptop. An always-on Windows VPS is still required for this stack's continuous execution. A domain purchase is unnecessary. The EA's existing localhost policy setting was preserved; using the public endpoint requires setting its policy URL and allowing `https://luvisemoney.github.io` in MT5 WebRequest settings. Pages publishes a snapshot; it does not implement a dynamic policy decision API.

## Review Q&A
- Does successful deployment establish profitability? No. The separate eight-symbol benchmark had a negative combined result; the three actual-EA tests also lost money.
- Does Actions keep MT5 running? No. It performs bounded build/deployment jobs.
- Does unchanged data produce a new commit every five minutes? No. Snapshot content is fingerprinted, and Git skips unchanged commits.
- Expert rebuttal: a successful JSON download proves delivery, not policy freshness, calibrated probabilities or the EA's complete policy interpretation.
- Adversarial checks: missing/invalid public data fails validation; suspicious credential signatures stop synchronization; a changed remote branch must permit a fast-forward; overlapping sync runs are rejected by a file lock.

## Five next checks
1. Monitor the scheduled task result and GitHub deployment status after logon/reconnect.
2. Define policy expiry and enforce it in the EA before switching its endpoint.
3. Audit historical repository content separately before authorizing cleanup or history changes.
4. Move MT5 and collectors to a Windows VPS and test restart/reconnect recovery.
5. Run an untouched, cost-aware trading evaluation; current evidence does not establish profitability.

References: [official Pages workflow documentation](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages), [MetaQuotes WebRequest](https://www.mql5.com/en/docs/network/webrequest). [Community VPS discussion](https://www.reddit.com/r/metatrader/comments/1mnko99/any_recommendation_for_a_windows_vps_server_for/) is context only, not hosting or latency evidence.

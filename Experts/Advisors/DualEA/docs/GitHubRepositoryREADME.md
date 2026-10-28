# Ultimate: MQL5 and DualEA

MQL5 sources are under `Experts`, `Include`, `Indicators` and `Scripts`. DualEA is under `Experts/Advisors/DualEA`.

The dashboard publishes recorded model, execution, news and latency evidence alongside the actual policy snapshot. It distinguishes the production EA from a separate ONNX benchmark. Current results do **not** establish profitability.

- Dashboard (after Pages deployment): https://luvisemoney.github.io/Ultimate/
- Static policy endpoint: https://luvisemoney.github.io/Ultimate/policy.json
- Deployment runs: https://github.com/luvisemoney/Ultimate/actions

## Dashboard

Use a current Node.js LTS release. No external npm dependencies are required.

```sh
cd Experts/Advisors/DualEA/dashboard
npm run check
npm run build
npm run preview
```

GitHub Actions validates and deploys the static site on source pushes. Scheduled/manual builds refresh the official public calendar export. They do not run a permanent trading terminal, scrape protected pages using your private browser session, or retrain the model. Site snapshots have timestamps; an HTTP 200 response alone does not prove freshness.

## Local source synchronization

From the terminal's `MQL5/Experts` directory, after GitHub authentication:

```powershell
# Prepare and review the isolated checkout first.
.\Advisors\DualEA\ML\Sync-GitHubRepository.ps1
# Commit and push to the existing main branch, preserving history.
.\Advisors\DualEA\ML\Sync-GitHubRepository.ps1 -Push
# Optional bounded automatic synchronization, five-minute cadence for one hour.
.\Advisors\DualEA\ML\Watch-GitHubSync.ps1 -DurationMinutes 60
```

The checkout defaults to `.publish/Ultimate`; clone this repository there before first use. The publisher excludes terminal accounts, browser profiles, environments, compiled executables, raw tester logs and bulk training data. Review any custom configuration before publishing a public repository. Previously committed content remains in Git history; deleting it from the current index does not erase history.

Run `ML/Export-DashboardSnapshot.ps1` explicitly to update public aggregate results from local evidence. It exports a real policy snapshot, not invented probabilities. Automatic source synchronization does not silently publish new private terminal data.

## Hosting limits

GitHub Pages hosts static HTML, JavaScript and JSON. GitHub Actions runs bounded jobs. Neither keeps MT5 trading while a laptop is switched off. This stack needs an always-on Windows VPS to run MT5 plus the local collector and policy service; a website/domain purchase is unnecessary. Keep credentials and browser profiles on that host, outside Git.

The 710-byte ONNX model is a compact trained logistic model, not evidence of a placeholder. Its weak holdout performance and negative combined test results remain visible. Historical results do not guarantee future returns.

## Next five checks

1. Verify Pages deployment succeeds and both public URLs return the intended snapshot.
2. Check snapshot timestamps before consuming a policy; define a maximum acceptable age.
3. Run native MT5 tests locally; browser CI does not replace Strategy Tester evidence.
4. Provision a Windows VPS and verify restart, reconnect and collector recovery there.
5. Evaluate an untouched, cost-aware trading window before considering live capital.

References: [GitHub Pages custom workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages), [MetaQuotes WebRequest](https://www.mql5.com/en/docs/network/webrequest).

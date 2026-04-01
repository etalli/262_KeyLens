# KeyLens Dev Log

Daily summaries of development activity, generated from git history.

---

## 2026-04-02

- **feat:** added Key Swap Simulator to Ergonomics tab — drag keys to swap, live before/after ergonomic score, lock/unlock keys, undo, export as JSON preset (#235)
- **feat:** added per-metric score breakdown table and score formula footnote to the simulator; clarified that finger travel is informational only
- **fix:** added dedicated Avg Session chart in Sessions tab (#289)
- **refactor:** extracted domain sub-structs from `KeyCountStore` into `KeyCountStore+Types.swift` (#269)
- **chore:** installed Codex plugin for Claude Code; created issue #293 for missing row-reach penalty in `ErgonomicScoreEngine`

## 2026-04-01

- **fix:** resolved long-standing keyboard disconnect bug — root cause was a fresh unscheduled `IOHIDManager` returning stale device data; switched to querying AppDelegate's live `hidManager` and passing names via notification object (#285)
- **fix:** run loop mode changed from `.defaultMode` → `.commonModes` so IOKit callbacks fire during UI event tracking; `lastResolvedTemplate` promoted to `@AppStorage` to detect disconnects while view was unmounted (#285)
- **feat:** Auto mode now selects Custom layout automatically when a KLE file is imported and a split/ergo keyboard connects — no keyword configuration needed (#288)
- **feat:** added opt-in `PerformanceProfiler` with aggregated hot-path metrics (mean/p95/min/max) flushed to app.log every 30 s (#287)
- **feat:** added undo option after Reset Counts — DB is backed up before reset and restored if user chooses Undo (#286)
- **ux:** heatmap mode row shows `↳ [device] → [filename]` caption when Auto resolves to Custom KLE; falls back to "Custom KLE" if filename was not stored (#288)
- **refactor:** removed `"pangaea"` from `LayoutRegistry` split keywords — Pangaea no longer triggers the `splitErgo` ergonomic profile
- **docs:** added perf profiling runbook and budgets to Architecture.md and HowToBuild.md (#287)

## 2026-03-31

- **chore:** bump version to v0.82

## 2026-03-27

- **feat:** moved Key Event Inspector to its own dedicated tab with keyboard icon (#260)
- **feat:** distinguish left/right modifier keys in Inspector — Key field shows `L⇧A` / `R⇧A`, Flags field shows `L⇧` / `R⇧` using NXEventData raw bit masks (#264)
- **ux:** improved Inspector help text readability — bullet-point layout with full Raw Flags explanation (left/right bit values)
- **fix:** reverted black font for Inspector values — broke dark mode; restored `.primary` adaptive foreground (#265)
- **fix:** correct snapshot Y coordinate for flipped SwiftUI content views; use default font design for symbol fields (⇧ was rendering as 'o' in monospaced); HID Name strips modifier symbols to show base key only (#265)
- **perf:** run `ChartDataModel.reload()` on background queue to avoid blocking the main thread (#258)
- **chore:** bump version to v0.80

## 2026-03-23

- **feat:** parse all 12 KLE legend slots and render them in correct 3×3 grid positions in the heatmap (#219)
- **feat:** add VoiceOver accessibility labels to heatmap key cells (#221)
- **fix:** remove redundant Save/Copy buttons from Heatmap view (#220)
- **refactor:** inject KeyCountStore, BreakReminderManager, NotificationManager into KeyboardMonitor via DI (#216)
- **refactor:** extract pure computation helpers into `KeyMetricsComputation`; eliminate `counts.json` — all scalars now persisted in `keylens.db` via new `scalars` table (#215)
- **chore:** bump version to v0.71
- **docs:** merge DataLogic.md into Architecture.md; remove stale Walkthrough.md, SYSTEM_MAP.md, Development.md; link design_pattern_analysis.md from Architecture.md

## 2026-03-21

- **perf:** offloaded JSON save to a separate background queue to fix input lag caused by `queue.sync` blocking on 207KB `counts.json` encoding
- **feat:** real-time typing speedometer with inertia decay (#115, #195); wrapped Live tab in ScrollView to prevent layout overflow
- **feat:** ergonomic score and travel distance added to layout simulation table (#72); Your Layout baseline row in Layout Efficiency (#197)
- **feat:** Speed heatmap mode and slow bigrams key filter (#99)
- **feat:** Markdown Daily Note export (originally Obsidian, generalized) (#75)
- **feat:** typing rhythm detection with personalized insight tips and color tinting (#76)
- **feat:** moved Typing Profile section from Summary to Live tab (#198)
- **feat:** Year in Review annual summary card export (#74, #199)
- **feat:** interactive 2D weekly activity heatmap (#78)
- **feat:** period comparison tab — compare any two date ranges side by side (#62, #205, #206, #207)
- **feat:** save chart as image for all chart sections in ChartsView; landing page screenshot gallery with 44 screenshots in 7 tabs
- **fix:** multiple Compare tab fixes (WPM delta units, language change refresh, Before/After labels)
- **fix:** localize all hardcoded strings in training UI (#82); correct clipboard icon for copy buttons
- **fix:** correct 3 failing unit tests with wrong expected values
- **fix:** input lag measurement via `handleEvent` latency — Issue #211 filed
- **fix:** replaced Settings menu section headers with submenus; bumped deployment target to macOS 14 (#212)
- **chore:** remove Japanese landing page and nav link; bumped to v0.68; updated README, Architecture.md, landing page, and roadmap


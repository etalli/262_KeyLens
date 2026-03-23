# KeyLens Dev Log

Daily summaries of development activity, generated from git history.

---

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


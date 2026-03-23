# Architecture

English

## Overview

KeyLens is built around three layers: event monitoring, data management, and UI control.

```mermaid
graph TD
    A[KeyLensApp.swift] --> B[AppDelegate]
    A --> V[MenuBarExtra / MenuView]
    B --> C[KeyboardMonitor]
    B --> I[StatsWindowController]
    B --> J[ChartsWindowController]
    B --> K[KeystrokeOverlayController]
    B --> N[AboutWindowController]
    B --> BR[BreakReminderManager]
    B --> UW[UpdateWindowController]
    B --> MC[MenuCustomizeWindowController]
    K --> O[OverlaySettingsController]
    P[KeyboardDeviceInfo] -->|device names| B
    C -->|key event| E[KeyCountStore]
    C -->|mouse event| MS[MouseStore]
    C -->|keystrokeInput notification| K
    E -->|every milestone presses| F[NotificationManager]
    E -->|JSON save scalars| G[(counts.json)]
    E -->|SQLite save per-day| GG2[(keylens.db)]
    MS -->|SQLite save| GG[(mouse.db)]
    V -->|fetch display data| E
    V -->|language switch| H[L10n]
    V -->|widget config| MW[MenuWidgetStore]
    J -->|reads counts| E
    J -->|theme| TS[ThemeStore]
    J --> L[ChartsView tabs / KeyboardHeatmapView / ActivityCalendarView]
    M[AIPromptStore] -->|currentPrompt| B
    M -->|reads language| H
```

---

## File structure

```
262_KeyLens/
├── Package.swift
├── build.sh
├── Resources/
│   └── Info.plist
├── Sources/
│   ├── KeyLens/                          # App executable
│   │   ├── KeyLensApp.swift
│   │   ├── AppDelegate.swift
│   │   ├── AppDelegate+Actions.swift
│   │   ├── AboutWindowController.swift
│   │   ├── UpdateWindowController.swift
│   │   ├── MenuView.swift
│   │   ├── MenuWidgetStore.swift
│   │   ├── MenuCustomizeWindowController.swift
│   │   ├── KeyboardMonitor.swift
│   │   ├── KeyCountStore.swift
│   │   ├── KeyCountStore+Activity.swift
│   │   ├── KeyCountStore+Ergonomics.swift
│   │   ├── KeyCountStore+Export.swift
│   │   ├── KeyCountStore+SQLite.swift
│   │   ├── KeyCountStore+Migration.swift
│   │   ├── MouseStore.swift
│   │   ├── KeyType.swift
│   │   ├── NotificationManager.swift
│   │   ├── BreakReminderManager.swift
│   │   ├── StatsWindowController.swift
│   │   ├── ChartsWindowController.swift
│   │   ├── ChartsView.swift
│   │   ├── ChartsComponents.swift
│   │   ├── ChartsDataTypes.swift
│   │   ├── Charts+SummaryTab.swift
│   │   ├── Charts+KeyboardTab.swift
│   │   ├── Charts+ErgonomicsTab.swift
│   │   ├── Charts+ActivityTab.swift
│   │   ├── Charts+AppsTab.swift
│   │   ├── Charts+ShortcutsTab.swift
│   │   ├── Charts+LiveTab.swift
│   │   ├── Charts+MouseTab.swift
│   │   ├── Charts+TrainingTab.swift
│   │   ├── Charts+ComparisonTab.swift
│   │   ├── ActivityCalendarView.swift
│   │   ├── KeyboardHeatmapView.swift
│   │   ├── WeeklySummaryCard.swift
│   │   ├── YearInReviewCard.swift
│   │   ├── KLEParser.swift
│   │   ├── KeyboardDeviceInfo.swift
│   │   ├── KeystrokeOverlayController.swift
│   │   ├── OverlaySettingsController.swift
│   │   ├── OverlayHotkeyManager.swift
│   │   ├── WPMHotkeyManager.swift
│   │   ├── ThemeStore.swift
│   │   ├── AIPromptStore.swift
│   │   └── L10n.swift
│   └── KeyLensCore/                      # Research library (Phase 0+)
│       ├── KeyboardLayout.swift
│       ├── KeyCategory.swift
│       ├── FingerLoadWeight.swift
│       ├── SameFingerPenalty.swift
│       ├── AlternationReward.swift
│       ├── ThumbImbalanceDetector.swift
│       ├── ThumbEfficiencyCalculator.swift
│       ├── HighStrainDetector.swift
│       ├── LayoutConstraints.swift       # Phase 2: fixed-key constraints (#39)
│       ├── RemappedLayout.swift          # Phase 2: key-swap simulation (#38)
│       ├── SFBScoreEngine.swift          # Phase 2: SFB penalty scorer
│       ├── SameFingerOptimizer.swift     # Phase 2: greedy hill-climb optimizer (#41)
│       ├── ErgonomicScoreEngine.swift    # Phase 1: unified ergonomic score formula (#29)
│       ├── ErgonomicSnapshot.swift       # Phase 2: all-metric snapshot for one layout (#3, #40)
│       ├── LayoutComparison.swift        # Phase 2: before/after layout comparison (#3)
│       ├── ErgonomicProfile.swift        # Keyboard profile: layout + fingerWeights + splitConfig
│       ├── TravelDistanceEstimator.swift # Phase 2: finger travel distance from bigram data (#40)
│       ├── FullErgonomicOptimizer.swift  # Phase 2: hill-climb optimizer using unified score (#41)
│       ├── FatigueRiskModel.swift        # Phase 3: fatigue risk estimation from speed/strain trends
│       ├── ThumbRecommendationEngine.swift # Phase 3: recommends keys to relocate to thumb positions
│       ├── TypingStyleAnalyzer.swift     # Phase 3: infers typing context (prose / code / chat)
│       ├── Bigram.swift                  # Typed (from, to) bigram value type
│       ├── BigramScore.swift             # Ranks bigrams by IKI × log(frequency) difficulty score
│       ├── AlternativeLayouts.swift      # Colemak and Dvorak layout implementations (#61)
│       ├── DrillGenerator.swift          # Generates typing drills from slow bigrams
│       ├── TrainingSession.swift         # Session config and tier-based repetition rules
│       └── PracticeSequence.swift        # Ordered practice steps for drill UI
└── Tests/
    └── KeyLensTests/
        ├── KeyboardLayoutTests.swift
        ├── KeyboardLayoutSanityTests.swift
        ├── SameFingerPenaltyTests.swift
        ├── FingerLoadWeightTests.swift
        ├── AlternationRewardTests.swift
        ├── ThumbImbalanceDetectorTests.swift
        ├── ThumbEfficiencyCalculatorTests.swift
        ├── HighStrainDetectorTests.swift
        ├── TrigramCountsTests.swift
        ├── SameFingerOptimizerTests.swift
        ├── ErgonomicScoreEngineTests.swift
        ├── LayoutComparisonTests.swift
        ├── ErgonomicProfileTests.swift
        ├── FullErgonomicOptimizerTests.swift
        ├── KeyRelocationSimulatorTests.swift
        ├── ThumbRecommendationEngineTests.swift
        └── TravelDistanceEstimatorTests.swift
```

---

## Data flow

```
Key press
  |
  v
CGEventTap  (OS-level event hook)
  |  KeyboardMonitor.swift
  |  inputTapCallback()  <-- file-scope global function (@convention(c) compatible)
  |
  +-- post Notification(.keystrokeInput)  --> KeystrokeOverlayController
  |
  v
KeyCountStore.shared.increment(key:)
  |  serial DispatchQueue for thread safety
  |  counts[key] += 1
  |  dailyCounts[today] += 1
  |  hourlyCounts[hour] += 1
  |  totalBigramCount += 1          <- if prev key mapped
  |  sameFingerCount += 1           <- if same finger & hand
  |  handAlternationCount += 1      <- if different hand
  |  bigramCounts["prev→key"] += 1  <- raw pair frequency (Issue #12)
  |  scheduleSave()   <- debounced 2 s write
  |
  +-- count % milestoneInterval == 0?
  |     YES -> DispatchQueue.main.async { NotificationManager.notify() }
  |
  v
(on menu open)
MenuBarExtra panel renders MenuView
  └─ KeyCountStore.{todayCount, totalCount, topKeys()}  -> display stats
```

---

## File responsibilities

### [KeyLensApp.swift](Sources/KeyLens/KeyLensApp.swift)

Entry point (marked with `@main`). Declares the app using SwiftUI's `App` protocol with a `MenuBarExtra` scene.

```swift
@main
struct KeyLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuView().environmentObject(appDelegate)
        } label: {
            Label("KeyLens", systemImage: "keyboard")
        }
        .menuBarExtraStyle(.window)
    }
}
```

`Info.plist` sets `LSUIElement = true` to suppress the Dock icon and the app-specific menu bar. `MenuBarExtra` provides the status bar icon and the popup panel. `@NSApplicationDelegateAdaptor` bridges to `AppDelegate` for lifecycle and monitor management.

---

### [AppDelegate.swift](Sources/KeyLens/AppDelegate.swift)

Manages the `KeyboardMonitor` lifecycle and Accessibility permission recovery. Conforms to `ObservableObject` so `MenuView` can react to state changes (e.g. `isMonitoring`, `copyConfirmed`).

On launch, calls `detectHardware()` which reads connected keyboard device names via `KeyboardDeviceInfo` and applies the matching `ErgonomicProfile` to `LayoutRegistry.shared`.

**Permission recovery (layered):**
1. `appDidBecomeActive` — fires when the user switches back to any app; attempts `monitor.start()` immediately
2. `schedulePermissionRetry()` — polls `AXIsProcessTrusted()` every 3 s as a fallback
3. `setupHealthCheck()` — checks `monitor.isRunning` every 5 s and triggers retry if stopped

---

### [AppDelegate+Actions.swift](Sources/KeyLens/AppDelegate+Actions.swift)

Extension on `AppDelegate` containing all user-initiated actions triggered from `MenuView`: showing windows, toggling the overlay, exporting CSV, copying data to clipboard, editing the AI prompt, changing language, resetting counts, etc.

---

### [AboutWindowController.swift](Sources/KeyLens/AboutWindowController.swift)

Singleton that manages the **About** panel. Wraps an `NSPanel` hosting an `AboutView` (SwiftUI) that displays the app icon, version string, and a link to the GitHub repository. The panel is created lazily on first `show()` call and reused thereafter; the title is refreshed on each `show()` to reflect the current language.

---

### [MenuView.swift](Sources/KeyLens/MenuView.swift)

SwiftUI view that renders the `MenuBarExtra` popup panel. Reads live data from `KeyCountStore.shared` on each render. Uses `@EnvironmentObject var appDelegate` to dispatch actions. Key subcomponents:

- **`OverlayRow`** — toggle + hover gear button + fixed-position checkmark in one row
- **`DataMenuRow`** — NSMenu popup for CSV export, AI prompt editing, open log folder
- **`SettingsMenuRow`** — NSMenu popup for Launch at Login, Language, Notify Every, Reset
- **`HoverRowStyle`** — shared `ButtonStyle` with hover highlight

---

### [KeyboardMonitor.swift](Sources/KeyLens/KeyboardMonitor.swift)

Intercepts system-wide key-down events via `CGEventTap`.

**Key design decision — `@convention(c)` constraint:**

`CGEventTapCallBack` is a C function pointer type; Swift closures that capture variables cannot be used directly. The solution is a two-layer design:

```
CGEvent.tapCreate(callback: inputTapCallback, userInfo: Unmanaged.passUnretained(self).toOpaque())
                            ^
                  global trampoline (no captures, @convention(c) compatible)
                  -> extracts self from refcon
                  -> delegates to KeyboardMonitor.handleEvent(proxy:type:event:)
```

The file-scope `inputTapCallback` is a minimal trampoline (~3 lines). All event-handling logic lives in the `handleEvent` instance method, which has direct access to `self.eventTap` and other instance state.

**Tap recovery:** If the tap is disabled by system timeout (`.tapDisabledByTimeout`), `handleEvent` immediately re-enables it via `self.eventTap`.

Key code to name translation is handled by a static lookup table in `keyName(for:)` (US keyboard layout).

After translating a key name, the callback posts a `Notification(.keystrokeInput)` so `KeystrokeOverlayController` can display it without polling.

**Dependency injection:** `KeyboardMonitor` receives its three external dependencies via `init` rather than accessing globals directly:

| Protocol | Default implementation | Purpose |
|---|---|---|
| `KeyEventHandling` | `KeyCountStore.shared` | `increment`, `recordSlowEvent`, `incrementModified` |
| `BreakReminderManaging` | `BreakReminderManager.shared` | `didType()` |
| `NotificationManaging` | `NotificationManager.shared` | `notify(key:count:)` |

Production code passes `.shared` instances (default arguments); tests can inject mocks.

---

### [KeyCountStore.swift](Sources/KeyLens/KeyCountStore.swift) / [+Activity](Sources/KeyLens/KeyCountStore+Activity.swift) / [+Ergonomics](Sources/KeyLens/KeyCountStore+Ergonomics.swift) / [+Export](Sources/KeyLens/KeyCountStore+Export.swift) / [+SQLite](Sources/KeyLens/KeyCountStore+SQLite.swift) / [+Migration](Sources/KeyLens/KeyCountStore+Migration.swift)

Singleton that manages counts and persists them to disk. Split into focused extensions: `+Activity` handles WPM, IKI, and daily activity metrics; `+Ergonomics` handles same-finger, alternation, high-strain, and app/device ergonomic accessors; `+Export` handles CSV export and clipboard formatting.

**Thread safety:**

The `CGEventTap` callback runs outside the main thread. A serial `DispatchQueue` serialises all dictionary access.

```
CGEventTap thread             Main thread
      |                            |
  queue.sync { increment }    queue.sync { topKeys() }
      |  <-- serialised -->        |
  scheduleSave()                   ...
      |
  queue.asyncAfter(+2 s) { save() }   <- debounced write
```

JSON is written with `.atomic` to prevent file corruption. Consecutive writes within 2 seconds are coalesced into a single disk write via `DispatchWorkItem` cancellation.

**Ergonomic data (Phase 0 — Issues #16–#18, #12):**

| Field | Type | Description |
|-------|------|-------------|
| `sameFingerCount` / `dailySameFingerCount` | `Int` / `[String: Int]` | Consecutive same-finger pairs |
| `totalBigramCount` / `dailyTotalBigramCount` | `Int` / `[String: Int]` | Total consecutive pairs |
| `handAlternationCount` / `dailyHandAlternationCount` | `Int` / `[String: Int]` | Hand-alternating pairs |
| `hourlyCounts` | `[String: Int]` | Keystroke totals keyed by `"yyyy-MM-dd-HH"` (365-day retention) |
| `bigramCounts` | `[String: Int]` | Raw pair frequency, e.g. `"Space→t": 42` |
| `dailyBigramCounts` | `[String: [String: Int]]` | Per-day raw pair frequency |

**Ergonomic data (Phase 1 — unified ergonomic model):**

| Field | Type | Description |
|-------|------|-------------|
| `highStrainBigramCount` / `dailyHighStrainBigramCount` | `Int` / `[String: Int]` | Same-finger bigrams spanning ≥1 keyboard row |
| `alternationRewardScore` | `Double` | Running alternation reward (AlternationReward model) |
| `thumbImbalanceRatio` | `Double` | Left/right thumb usage imbalance (0 = balanced) |
| `thumbEfficiencyCoefficient` | `Double` | How effectively thumb keys reduce load on other fingers |

Accessors: `sameFingerRate`, `todaySameFingerRate`, `handAlternationRate`, `todayHandAlternationRate`, `topBigrams(limit:)`, `todayTopBigrams(limit:)`, `topHighStrainBigrams(limit:)`, `dailyErgonomicRates()`.

**Typing speed (WPM) estimation:**

`estimatedWPM` is derived directly from `avgIntervalMs` using the standard definition of 1 word = 5 keystrokes:

```
WPM = 60,000 / (avgIntervalMs × 5)
```

- `avgIntervalMs` is in milliseconds, so `60,000 = 60 s × 1,000 ms` converts to per-minute.
- Only intervals ≤ 1,000 ms are included in the average (Welford online algorithm), which excludes pauses and thinking time, giving a measure of pure typing rhythm rather than net composition speed.
- No schema change is required — WPM is computed on demand from the existing `avgIntervalMs` / `avgIntervalCount` fields.

---

### [KeyType.swift](Sources/KeyLens/KeyType.swift)

Classifies key names into categories (`letter`, `number`, `arrow`, `control`, `function`, `mouse`, `other`). Each case carries a `color` and a `label` used by `ChartsView` to colour-code bar segments.

---

### [NotificationManager.swift](Sources/KeyLens/NotificationManager.swift)

Delivers native notifications via `UNUserNotificationCenter`.
`trigger: nil` means immediate delivery (no scheduling).
Notification permission is requested on first singleton access.

---

### [StatsWindowController.swift](Sources/KeyLens/StatsWindowController.swift)

Displays a ranked table of all keys and mouse buttons with total and today's counts. Built with `NSTableView` (AppKit). Reloads from `KeyCountStore` each time the window is shown.

---

### [ChartsWindowController.swift](Sources/KeyLens/ChartsWindowController.swift) / [ChartsView.swift](Sources/KeyLens/ChartsView.swift)

`ChartsWindowController` wraps `ChartsView` (SwiftUI + Swift Charts) in an `NSHostingController`. `ChartDataModel` is an `ObservableObject` that pulls data from `KeyCountStore` on demand via `reload()`.

`ChartsView` is organised into 10 tabs, each implemented as a `ChartsView` extension in its own file:

| Tab file | Contents |
|----------|----------|
| `Charts+SummaryTab.swift` | Activity Calendar heatmap, Weekly Delta Report |
| `Charts+KeyboardTab.swift` | Keyboard Heatmap (Frequency / Strain), Top 20 Keys, Key Categories, Top 10 per Day |
| `Charts+ErgonomicsTab.swift` | Top 20 Bigrams, Ergonomic Learning Curve, ergonomic score tables |
| `Charts+ActivityTab.swift` | Daily WPM chart, Daily Totals line chart, IKI Distribution histogram, 2D Weekly Activity Heatmap |
| `Charts+AppsTab.swift` | Per-app keystroke bars (all-time and today) + ergonomic score table |
| `Charts+ShortcutsTab.swift` | ⌘ Keyboard Shortcuts, All Keyboard Combos |
| `Charts+LiveTab.swift` | Recent IKI bar chart, manual WPM measurement |
| `Charts+MouseTab.swift` | Daily mouse distance, hourly mouse activity, mouse/keyboard balance |
| `Charts+TrainingTab.swift` | Bigram-based typing drill UI (slowest bigrams, practice sessions) |
| `Charts+ComparisonTab.swift` | Side-by-side period comparison: two custom date ranges, preset buttons, stats table with delta column |

Shared UI primitives (section headers, sort controls, help popovers) live in `ChartsComponents.swift`. Chart-specific data structs (`TopKeyEntry`, `DailyErgonomicEntry`, `WeeklyDeltaRow`, etc.) are defined in `ChartsDataTypes.swift`.

`ChartDataModel` (ObservableObject in `ChartsWindowController.swift`) holds all chart data and exposes `reload()` to refresh from `KeyCountStore`.

---

### [KeystrokeOverlayController.swift](Sources/KeyLens/KeystrokeOverlayController.swift)

Floating `NSPanel` that shows the last N keystrokes in real time using a SwiftUI `OverlayView`. Listens for `Notification(.keystrokeInput)` posted by `KeyboardMonitor`. The panel fades out after 3 s of inactivity using a debounced `DispatchWorkItem`. Toggle state is persisted in `UserDefaults`.

---

### [OverlaySettingsController.swift](Sources/KeyLens/OverlaySettingsController.swift)

Defines overlay configuration types and manages the settings panel for `KeystrokeOverlayController`:

- **`OverlayPosition`** — enum (`topLeft`, `topRight`, `bottomLeft`, `bottomRight`) for screen corner placement; preferences persisted in `UserDefaults`
- **`OverlayFontSize`** — enum (`small`, `medium`, `large`, `extraLarge`) for keystroke text size
- **`OverlaySettingsController`** — shows a SwiftUI settings panel (position picker, font size picker, display count slider); opened via the gear icon (⚙) in `MenuView`'s Overlay row

---

### [OverlayHotkeyManager.swift](Sources/KeyLens/OverlayHotkeyManager.swift)

Manages the global hotkey for toggling the Keystroke Overlay (Issue #179). Default hotkey: ⌃⌥O. Hotkey is detected inside the existing `CGEventTap` (no separate event monitor needed). Key code and modifier flags are persisted in `UserDefaults`.

---

### [WPMHotkeyManager.swift](Sources/KeyLens/WPMHotkeyManager.swift)

Manages the global hotkey for toggling manual WPM measurement (Issue #151). Default hotkey: ⌃⌥M. Same architecture as `OverlayHotkeyManager` — detected in `CGEventTap`, persisted in `UserDefaults`.

---

### [KLEParser.swift](Sources/KeyLens/KLEParser.swift)

Parses [keyboard-layout-editor](http://www.keyboard-layout-editor.com/) JSON into `KLEAbsoluteKey` structs with center-position, size, rotation, key-name, and a 12-slot legend array (`legendSlots`). The 12 slots follow the KLE spec (0=Top-Left, 8=Top-Center, 9=Center, etc.); `label` holds the primary display string selected by priority order. Backward-compatible `Codable` decoder defaults `legendSlots` to `[]` when reading older stored JSON. Used by `KeyboardHeatmapView` to support custom physical keyboard layouts beyond the built-in ANSI template.

---

### [WeeklySummaryCard.swift](Sources/KeyLens/WeeklySummaryCard.swift)

`WeeklySummaryCardView` renders a one-week typing summary (keystrokes, WPM, ergonomic score, top keys). Rendered off-screen via SwiftUI `ImageRenderer` and saved as PNG for sharing. Can be embedded inline or rendered standalone.

---

### [YearInReviewCard.swift](Sources/KeyLens/YearInReviewCard.swift)

`AnnualSummaryCardView` renders a full-year typing summary (total keystrokes, daily average, active days, best month, monthly bar chart, top 5 keys). Rendered off-screen via `ImageRenderer` and saved as PNG. `AnnualSummaryData.forYear(_:)` queries `KeyCountStore` for monthly totals and ergonomic rates. Triggered from the Data menu via `AppDelegate.exportYearInReviewCard()`.

---

### [AIPromptStore.swift](Sources/KeyLens/AIPromptStore.swift)

Singleton that stores and retrieves the AI analysis prompt. Built-in defaults exist for English and Japanese. User edits are persisted in `UserDefaults` keyed by language, so each language retains an independent prompt.

---

### [L10n.swift](Sources/KeyLens/L10n.swift)

Centralised localisation singleton. Supports English, Japanese, and system auto-detection. Language preference is persisted in `UserDefaults`.

---

### [KeyLensCore](Sources/KeyLensCore/)

A separate Swift library target that exposes keyboard ergonomic abstractions decoupled from the app executable. Consumed by `KeyLens` and `KeyLensTests`.

#### Phase 0–1: Layout abstraction and scoring models

| Type | File | Description |
|------|------|-------------|
| `Hand` / `Finger` / `KeyPosition` | `KeyboardLayout.swift` | Physical position and ergonomic metadata for a key |
| `KeyboardLayout` | `KeyboardLayout.swift` | Protocol — `name`, `position(for:)`, `finger(for:)`, `hand(for:)` |
| `ANSILayout` | `KeyboardLayout.swift` | Standard US ANSI implementation (62 `CGKeyCode` entries) |
| `SplitKeyboardConfig` | `KeyboardLayout.swift` | User-overridable hand assignments for split keyboards |
| `ErgonomicProfile` | `ErgonomicProfile.swift` | Bundles `layout`, `fingerWeights`, and `splitConfig` into one named profile; presets: `.standard`, `.splitErgo` |
| `LayoutRegistry` | `KeyboardLayout.swift` | Singleton: `activeProfile: ErgonomicProfile` + scoring model instances; `applyProfile(forDeviceNames:)` selects profile from connected hardware |
| `FingerLoadWeight` | `FingerLoadWeight.swift` | Per-finger capability weights (index=1.0 … pinky=0.5) |
| `SameFingerPenalty` | `SameFingerPenalty.swift` | Non-linear distance-tier penalty for same-finger bigrams |
| `AlternationReward` | `AlternationReward.swift` | Reward coefficient for hand-alternating sequences |
| `ThumbImbalanceDetector` | `ThumbImbalanceDetector.swift` | Left/right thumb usage imbalance ratio |
| `ThumbEfficiencyCalculator` | `ThumbEfficiencyCalculator.swift` | Thumb key efficiency vs expected usage ratio |
| `HighStrainDetector` | `HighStrainDetector.swift` | High-strain bigram/trigram detection (same-finger, ≥1 row) |

`KeyCountStore.increment()` calls `LayoutRegistry.shared` to resolve finger/hand for every keystroke, enabling same-finger and alternation detection without coupling the store to physical key codes.

#### Phase 2: Optimization engine

| Type | File | Description |
|------|------|-------------|
| `LayoutConstraints` | `LayoutConstraints.swift` | Fixed-key set; `macOSDefaults` preset locks system shortcut keys |
| `RemappedLayout` | `RemappedLayout.swift` | `KeyboardLayout` wrapper that applies a `[String: String]` swap map; delegates `finger/hand/position` lookups through the relocation map |
| `KeyRelocationSimulator` | `RemappedLayout.swift` | Builds `RemappedLayout` instances; `applySwap(key1:key2:to:)` composes multiple swaps into one accumulated map |
| `SFBScoreEngine` | `SFBScoreEngine.swift` | Computes `Σ(count × penalty)` for same-hand/same-finger bigrams; used by optimizer for scoring candidate layouts |
| `KeySwap` | `SameFingerOptimizer.swift` | Value type: `(from, to, projectedSFBReduction)` |
| `SameFingerOptimizer` | `SameFingerOptimizer.swift` | Greedy hill-climb: identifies top-K SFB bigrams, tries all (candidate, swappable) swaps, accepts the best per iteration; respects `LayoutConstraints` |
| `ErgonomicScoreEngine` | `ErgonomicScoreEngine.swift` | Combines 5 Phase 1 metrics into a single [0,100] ergonomic score; configurable weight table (`ErgonomicScoreWeights`) |
| `ErgonomicSnapshot` | `ErgonomicSnapshot.swift` | Immutable value type holding all 7 sub-metrics for one (layout, dataset) pair; `capture(bigramCounts:keyCounts:layout:)` computes all fields in a single bigram scan |
| `LayoutComparison` | `LayoutComparison.swift` | Side-by-side ergonomic comparison: holds `current` + `proposed` snapshots + `recommendedSwaps`; `make(bigramCounts:keyCounts:)` runs `SameFingerOptimizer`, builds `RemappedLayout`, and computes both snapshots |
| `LayoutRegistry.forSimulation` | `KeyboardLayout.swift` | Factory that creates an isolated `LayoutRegistry` with a given layout and configuration copied from a base registry, without modifying the global singleton |

#### Phase 3: Typing analysis and recommendations

| Type | File | Description |
|------|------|-------------|
| `KeyCategory` | `KeyCategory.swift` | High-level key classification (letter / number / symbol / control / function / nav / mouse / other); used by `TypingStyleAnalyzer` and stats views |
| `FatigueLevel` / `FatigueRiskModel` | `FatigueRiskModel.swift` | Estimates typing fatigue risk (`low` / `moderate` / `high`) by comparing recent speed and strain metrics against a baseline |
| `TypingStyle` / `TypingStyleAnalyzer` | `TypingStyleAnalyzer.swift` | Infers the active typing context (`prose` / `code` / `chat` / `unknown`) from keystroke distributions (symbol ratio, Enter frequency, etc.) |
| `ThumbRecommendationEngine` | `ThumbRecommendationEngine.swift` | Recommends which high-burden keys (on weak fingers) should be relocated to thumb positions; accounts for left/right thumb imbalance when assigning slots |
| `TravelDistanceEstimator` | `TravelDistanceEstimator.swift` | Estimates total finger travel distance from bigram data using Euclidean key-grid distances; `projectedTravel` wraps `RemappedLayout` for before/after comparison |
| `FullErgonomicOptimizer` | `FullErgonomicOptimizer.swift` | Hill-climb optimizer that maximises the unified `ErgonomicScoreEngine` score; considers all five Phase 1 metrics (SFB, high-strain, alternation, thumb, travel) rather than SFB alone |

#### Shared value types

| Type | File | Description |
|------|------|-------------|
| `Bigram` | `Bigram.swift` | Typed `(from: String, to: String)` value type; serialises as `"a→s"` for JSON/dict keys |
| `BigramScore` | `BigramScore.swift` | Ranks bigrams by `meanIKI × log2(count + 1)`; used to surface the slowest/most-impactful pairs for training |
| `ColemakLayout` / `DvorakLayout` | `AlternativeLayouts.swift` | Colemak and Dvorak `KeyboardLayout` implementations derived from physical ANSI positions (#61) |

#### Training (Phase 1 — Issues #83–#87)

| Type | File | Description |
|------|------|-------------|
| `DrillKind` / `DrillGenerator` | `DrillGenerator.swift` | Generates word-list drills (`repeated`, `alternating`, `mixed`) from a ranked list of slow bigrams |
| `SessionConfig` / `TrainingSession` | `TrainingSession.swift` | Session parameters (target count, tier boundaries, repetitions) and the assembled drill sequence |
| `PracticeStep` / `PracticeSequence` | `PracticeSequence.swift` | Ordered sequence of typed tokens; consumed by the Training tab UI to advance linearly through a drill |

---

### [KeyboardHeatmapView.swift](Sources/KeyLens/KeyboardHeatmapView.swift)

SwiftUI view that renders the physical ANSI keyboard layout. Supports two display modes via a segmented `Picker`:

- **Frequency** — each key coloured by total keystroke count (red = most pressed)
- **Strain** — each key coloured by its cumulative high-strain bigram involvement score (red = frequent culprit)

A hover-triggered popover (ⓘ icon) explains the active mode. Strain scores are computed from `KeyCountStore.shared.topHighStrainBigrams(limit: 1000)` by summing bigram counts for each participating key. Used inside `ChartsView` as the first chart section.

Custom KLE layouts use `kleHeatCell` instead of `heatCell`. `kleHeatCell` renders a 3×3 legend grid (Top-Left/Center/Right, Center-Left/Center/Right, Bottom-Left/Center/Right) from `KLEAbsoluteKey.legendSlots`. Save/Copy export is handled by the `chartSection` header icons — no export buttons are embedded in the view itself.

---

### [ActivityCalendarView.swift](Sources/KeyLens/ActivityCalendarView.swift)

SwiftUI view that renders a contribution-style calendar heatmap of daily keystroke counts. Displays the past 365 days as a 53-column × 7-row grid coloured by keystroke intensity, matching the GitHub contribution graph style. Used in the Summary tab.

---

### [MouseStore.swift](Sources/KeyLens/MouseStore.swift)

SQLite-backed singleton (using GRDB) that persists mouse movement metrics. Accumulates displacement in-memory (separated into rightward/leftward/downward/upward components) and flushes to `mouse.db` every 30 seconds via a `DispatchSourceTimer`. Tables: `mouse_daily`, `mouse_hourly`.

---

### [ThemeStore.swift](Sources/KeyLens/ThemeStore.swift)

Singleton that manages the active `ChartTheme` (blue / teal / purple / orange / green / pink). Theme selection is persisted in `UserDefaults` and published via `@Published` so `ChartsView` reacts instantly on change.

---

### [MenuWidgetStore.swift](Sources/KeyLens/MenuWidgetStore.swift)

Persists the user's widget selection and ordering for the `MenuView` popover. Defines the `MenuWidget` enum (recording since, today total, WPM, backspace rate, mini chart, streak, shortcut efficiency, mouse distance) and `MenuWidgetStore` singleton backed by `UserDefaults`.

---

### [MenuCustomizeWindowController.swift](Sources/KeyLens/MenuCustomizeWindowController.swift)

Singleton `NSWindowController` hosting the Customize Menu SwiftUI panel. Lets users toggle and reorder `MenuWidget` items. Opened via the customize button in `MenuView`.

---

### [BreakReminderManager.swift](Sources/KeyLens/BreakReminderManager.swift)

Singleton that fires a `UNUserNotification` break reminder after a configurable idle interval (default: 30 minutes). Uses a `DispatchSourceTimer` on a private queue. `isEnabled` and `intervalMinutes` are persisted in `UserDefaults`. The timer resets on each keystroke event so the reminder measures true idle time.

---

### [UpdateWindowController.swift](Sources/KeyLens/UpdateWindowController.swift)

Singleton that displays update check results in a custom `NSPanel`. Shows either an "update available" panel (with a Download button linking to the GitHub release) or an "up to date" confirmation panel.

---

### [KeyboardDeviceInfo.swift](Sources/KeyLens/KeyboardDeviceInfo.swift)

Reads connected keyboard device information via IOKit. Used to identify the active physical keyboard model.

---

## Persistent Storage

KeyLens uses two storage backends:

- **`counts.json`** — scalar values and small maps (cumulative totals, bigram sums, etc.)
- **`keylens.db`** — large per-day tables (SQLite via GRDB)

### keylens.db schema

**Path:** `~/Library/Application Support/KeyLens/keylens.db`

| Table | Key columns | Description |
|-------|-------------|-------------|
| `daily_keys` | `date`, `key`, `count` | Per-day per-key keystroke counts |
| `daily_bigrams` | `date`, `bigram`, `count` | Per-day bigram frequency |
| `daily_trigrams` | `date`, `trigram`, `count` | Per-day trigram frequency |
| `daily_apps` | `date`, `app`, `count` | Per-day per-application keystroke counts |
| `daily_devices` | `date`, `device`, `count` | Per-day per-device keystroke counts |
| `hourly_counts` | `date_hour`, `count` | Total keystrokes per hour |
| `bigram_iki` | `bigram`, `sum_ms`, `sample_count` | Per-bigram IKI sum and sample count |
| `iki_buckets` | `date`, `bucket`, `count` | IKI distribution histogram buckets per day |

Writes are batched and flushed asynchronously on a serial queue. Legacy `daily*` fields in `counts.json` are migrated to `keylens.db` on first launch (see `KeyCountStore+Migration.swift`).

---

### counts.json schema

**Path:** `~/Library/Application Support/KeyLens/counts.json`

Encoded as JSON with ISO 8601 dates (`JSONEncoder.dateEncodingStrategy = .iso8601`).
Writes are debounced (2 s) and atomic (`.atomic` flag) to prevent corruption.

| Field | Type | Description |
|-------|------|-------------|
| `startedAt` | ISO 8601 Date | Timestamp when recording began |
| `lastInputTime` | ISO 8601 Date? | Timestamp of the last key event |
| `counts` | `{String: Int}` | Cumulative count per key name |
| `modifiedCounts` | `{String: Int}` | Modifier-combo counts, e.g. `"⌘c": 42` |
| `avgIntervalMs` | Double | Running average keystroke interval (ms, Welford; intervals > 1000 ms excluded) |
| `avgIntervalCount` | Int | Sample count for the running average |
| `dailyMinIntervalMs` | `{date: Double}` | Minimum keystroke interval per day (ms, ≤ 1000 ms only) |
| `sameFingerCount` | Int | Cumulative same-finger consecutive pairs |
| `totalBigramCount` | Int | Cumulative total consecutive pairs (denominator) |
| `dailySameFingerCount` | `{date: Int}` | Same-finger pairs per day |
| `dailyTotalBigramCount` | `{date: Int}` | Total pairs per day |
| `handAlternationCount` | Int | Cumulative hand-alternating pairs |
| `dailyHandAlternationCount` | `{date: Int}` | Hand-alternating pairs per day |
| `bigramCounts` | `{String: Int}` | Cumulative bigram frequency; key `"prev→cur"` |
| `trigramCounts` | `{String: Int}` | Cumulative trigram frequency; key `"a→s→d"` |
| `highStrainBigramCount` | `Int` | Cumulative high-strain (same-finger, ≥1-row span) bigram count |
| `dailyHighStrainBigramCount` | `{date: Int}` | High-strain bigram count per day |
| `highStrainTrigramCount` | `Int` | Cumulative count of two consecutive high-strain bigrams |
| `dailyHighStrainTrigramCount` | `{date: Int}` | High-strain trigram count per day |
| `alternationRewardScore` | `Double` | Running alternation reward score (includes streak multiplier bonus) |
| `appCounts` | `{String: Int}` | Cumulative keystroke count per frontmost application name |
| `appSameFingerCount` | `{String: Int}` | Cumulative same-finger bigrams per app |
| `appTotalBigramCount` | `{String: Int}` | Cumulative total bigrams per app (denominator) |
| `appHandAlternationCount` | `{String: Int}` | Cumulative hand-alternating bigrams per app |
| `appHighStrainBigramCount` | `{String: Int}` | Cumulative high-strain bigrams per app |
| `deviceCounts` | `{String: Int}` | Cumulative keystroke count per detected keyboard device label |
| `deviceSameFingerCount` | `{String: Int}` | Cumulative same-finger bigrams per device |
| `deviceTotalBigramCount` | `{String: Int}` | Cumulative total bigrams per device (denominator) |
| `deviceHandAlternationCount` | `{String: Int}` | Cumulative hand-alternating bigrams per device |
| `deviceHighStrainBigramCount` | `{String: Int}` | Cumulative high-strain bigrams per device |

> Per-day tables (`daily_keys`, `daily_bigrams`, `daily_apps`, `daily_devices`, `hourly_counts`, `iki_buckets`, `bigram_iki`) have moved to `keylens.db` (see above).

All fields except `startedAt` and `counts` use optional decoding with safe defaults,
ensuring forward/backward compatibility when new fields are added.

---

## Build & Test

### Build commands

```bash
./build.sh            # Build App Bundle only
./build.sh --run      # Build and launch immediately
./build.sh --install  # Build, install to /Applications, codesign, reset TCC, launch  ← recommended
./build.sh --dmg      # Build distributable DMG
```

> Always use `build.sh` — running `swift build` alone won't produce a working notification bundle.

### What `--install` does

| Step | What it does |
|------|--------------|
| `cp -r KeyLens.app /Applications/` | Installs to `/Applications` |
| `codesign --force --deep --sign -` | Ad-hoc signature (stabilizes Accessibility permission) |
| `pkill -x KeyLens` | Stops the running process before replacing the binary |
| `tccutil reset Accessibility <bundle-id>` | Clears the stale TCC entry for the old binary hash |
| `open /Applications/KeyLens.app` | Launches the new build |

**Why TCC reset is needed:** macOS stores Accessibility permissions keyed by binary hash. Each `swift build` produces a new binary, making the old TCC entry stale. Without resetting, `AXIsProcessTrusted()` returns `false` even though the toggle appears ON in System Settings.

### Logs

```bash
tail -f ~/Library/Logs/KeyLens/app.log
```

### Run Tests

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

If `swift test` fails with `no such module 'XCTest'`, the Command Line Tools are active instead of the full Xcode toolchain. Fix it with:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Verify the active toolchain:

```bash
xcode-select -p      # should point to Xcode.app/Contents/Developer
xcrun --find swift
swift --version
```

The CI workflow pins Xcode and verifies `xcode-select -p` before running `swift test`.

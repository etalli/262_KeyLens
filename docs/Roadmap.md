# KeyLens optimization roadmap

## Vision

KeyLens started as a keystroke counter. The long-term goal is layout optimization: take the actual typing data and turn it into concrete recommendations for where keys should go.

The design assumes a split keyboard with an active thumb row, though standard layouts work too.

Five phases:
1. Measurement integrity
2. Ergonomic model
3. Optimization engine
4. Adaptive intelligence
5. Product layer

---

Experience shows that split or slightly spaced keyboards reduce fatigue during extended typing sessions. Optimization is designed around split keyboards with active use of thumb keys.

---

## Issue priority map

| Priority | Issues | Theme |
|----------|--------|-------|
| Closed | #61, #85, #98, #103, #104 | Phase 1: Measurement & Scoring |
| Closed | #72, #82–#90, #208, #209 | Phase 2: Optimization engine & training chain |
| Closed | #62, #70, #74, #78, #99, #115 | Phase 3: Visualization |
| Active — Analytics | #364, #365, #366, #367 | Finger load, SFB, per-app ergonomics, distance gamification |
| Active — UI / Charts | #337, #348, #353 | Key Swap Simulator, per-device chart, weekly summary cleanup |
| Active — Bug | #343 | Modifier Keys by Finger row height |
| Active — Refactor | #330, #331, #332 | BaseWindowController, ChartDataModel split, KLEProfileManager |
| Future | #63, #64, #75, #76 | ML, iCloud sync, integrations |

---

# Phase 0 – Measurement integrity (done)

## Goal

Establish accurate and reproducible keystroke logging.

### Required

* Bigram / Trigram (done)
  Measures how often two- or three-key sequences appear in typing. The basis for identifying patterns and evaluating layout efficiency.
  > Dvorak and Colemak were both built around bigram frequency data. Common pairs belong on strong fingers and the home row.

* Same-finger repetition (done)
  Tracks how often consecutive keystrokes land on the same finger. High rates increase fatigue and errors.
  > A same-finger bigram forces one finger to lift, reposition, and press again immediately. It's consistently the most taxing motion in typing.

* Hand alternation (done)
  Measures how often typing switches between hands. More alternation means faster, less tiring typing.
  > While one hand presses a key, the other is already moving to the next. That overlap is why high alternation helps both speed and endurance.

* Time-window transitions / IKI (done)
  Analyzes key transition timing within short windows. Captures typing rhythm and surfaces high-speed sequences that cause strain.
  > The same sequence typed slowly is harmless; at high speed it becomes repetitive strain. Count data alone can't tell you which.

### Additional

* Layout abstraction layer (decoupled from physical layout) (done)
* Split keyboard mapping model (done)
* Finger assignment model (done)

---

# Phase 1 – Unified ergonomic model (done)

## Goal

Build a unified ergonomic scoring engine.

### Core (done)

* Ergonomic score formula (done)
  Combines finger load, alternation, and same-finger rate into a single number for comparing layouts.
  > Without a single score, individual metrics point in different directions and you can't weigh one against another.

* Finger load weighting (done)
  Assigns different weights to each finger based on strength and reach.
  > Index fingers are roughly twice as capable as pinkies. Treating all fingers equally produces layouts that overload weak fingers.

* Thumb imbalance detection (done)
  Measures whether thumb usage is evenly split between left and right.
  > Standard layouts hide this imbalance. On split keyboards it shows up clearly — an overloaded thumb is a common source of long-term strain.

* High-strain sequence detection (done)
  Identifies sequences that stack poor alternation, same-finger use, and lateral stretch at once.
  > Each metric looks fine on its own, but when all three stress factors land on the same sequence, the cumulative load is much worse than any single metric shows.

### Completed — P1 issues

* [#85] Define scoring formula for slowness and frequency prioritization (done)
* [#104] IKI per finger (done)
* [#103] IKI per bigram (done)
* [#98] Latency analysis for key-to-key transitions (done)
* [#61] Layout efficiency score (same-finger rate / hand alternation by layout) (done)

### Differentiating additions

* Thumb efficiency coefficient
  Measures how well thumb keys are actually reducing load on the other eight fingers.
  > Thumb keys are the most flexible positions on a split keyboard. This coefficient checks whether that flexibility is being used.

* Same-finger penalty weighting (done)
  Applies non-linear penalties based on how far the finger must travel between same-finger keys.
  > Adjacent-key same-finger bigrams are annoying; two-row stretches are genuinely painful. A linear penalty misses that difference.

* Alternation reward coefficient (done)
  Adds a score bonus for sequences with smooth hand alternation.
  > Rewarding alternation — rather than only penalizing same-hand use — gives the optimizer a positive target, not just a cost to avoid.

Phase 1 done. Layout comparisons are now objective.

---

# Phase 2 – Optimization engine (done)

## Goal

Complete the automated key relocation logic.

### Completed

* Thumb recommendation engine — [#208] (done)
* Key relocation simulation — [#72] (done)
* Before/After comparison — [#84] (done)
* Layer key usage analyzer — [#209] (done)
  User registers a Layer Mapping Table (layer key + finger assignment, output key → layer key + base key). KeyLens re-interprets captured key events at analysis time, enabling correct same-finger, hand load, and ergonomic scoring for layer-based input. IKI for layer combos is estimated (OS only exposes output event timestamps).

### Training chain (done)

* [#83] Phase 1: Generate bigram-based typing drills from slow combinations (done)
* [#87] Build practice sequence generator for ranked bigrams (done)
* [#86] Design training session format and repetition rules (done)
* [#84] Add before/after measurement for trained combinations (done)
* [#90] Add UI for generated training drills (done)
* [#89] Phase 2: Expand training targets from bigrams to trigrams (done)
* [#88] Store training results and progress history (done)
* [#82] Add personalized typing training courses based on slow key combinations (done)

Phase 2 done. Optimization engine and training chain complete.

---

# Phase 3 – Visualization & behavioral feedback (done)

### Completed

* [#115] Real-time typing speedometer — analog gauge for live WPM (done)
* [#99] Speed analysis UI: bigram IKI heatmap and slow bigrams chart (done)
* [#78] Interactive 2D Heatmap (Day of Week × Hour of Day) (done)
* [#74] Annual 'Year in Review' statistics report (done)
* [#70] Auto-generate weekly summary card as shareable PNG (done)
* [#62] Period comparison mode — compare any two date ranges side by side (done)

Phase 3 done. Core visualization suite complete.

---

# Current work

Active issues as of v0.97.

### Ergonomic analytics

* [#364] Finger load % chart — each finger's share of total keystrokes
* [#365] Per-finger SFB ranking — break down same-finger bigrams by finger
* [#366] Per-app ergonomic pattern breakdown — SFB rate, hand alternation, modifier share per app
* [#367] Gamified daily finger travel distance — "your fingers walked X meters today"

### UI / Charts

* [#337] Expand Key Swap Simulator to full keyboard (navigation, modifier, function keys)
* [#348] Per-device daily keystroke time-series chart
* [#353] Consolidate Weekly Summary and Weekly Report sections — remove redundant numbers

### Bugs

* [#343] Modifier Keys by Finger chart: row height inconsistent with other charts

### Refactors

* [#330] Add BaseWindowController to eliminate NSWindowController boilerplate
* [#331] Split ChartDataModel into domain-specific @Published models
* [#332] Extract KLEProfileManager from KeyboardHeatmapView

---

# Phase 4 – Research-grade intelligence

ML features go here.

### ML

* [#76] Typing style clustering
* [#63] Fatigue risk modeling
* Adaptive layout evolution

### Other future

* [#64] iCloud sync across multiple Macs
* [#75] Obsidian / Daily Journal integration
* [#47] Auto-detect keyboard type from device name
* [#43] KLE JSON import for custom heatmap layout templates

---

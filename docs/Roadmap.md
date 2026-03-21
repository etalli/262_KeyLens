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
| Closed | #144, #145, #146 | Bugs resolved in v0.56 |
| Closed | #61, #85, #98, #103, #104 | Phase 1: Measurement & Scoring |
| Closed | #60 | Session detection |
| P2 — Training chain | #83 → #87 → #86 → #84 → #90 → #89 → #88 → #82 | Drill generation |
| P3 — Future | #72, #76, #63, #64, #75 | Low priority / research |
| P3 — UX / Polish | #169, #170, #174 | UI tests, icon design, Keyboard tab UX |
| Deferred | #115, #99, #78, #70, #74, #62 | Visualization (intentionally postponed) |

---

# Phase 0 – Measurement integrity (done)

## Goal

Establish accurate and reproducible keystroke logging.

### Required

* Bigram / Trigram (done)
  Measures how often two- or three-key sequences appear in typing. The basis for identifying patterns and evaluating layout efficiency.
  2〜3キーの連続打鍵パターンの出現頻度を計測する。配列効率の評価における統計的な基盤となる。
  > Dvorak and Colemak were both built around bigram frequency data. Common pairs belong on strong fingers and the home row.
  > Dvorak・Colemakなど主要な配列研究はすべてビグラム頻度分析を基礎としており、頻出ペアを強い指・ホームロウに集中させることが設計の核心となっている。

* Same-finger repetition (done)
  Tracks how often consecutive keystrokes land on the same finger. High rates increase fatigue and errors.
  同じ指で連続してキーを打つ頻度を追跡する。頻度が高いほど疲労とミスタイプのリスクが上がる。
  > A same-finger bigram forces one finger to lift, reposition, and press again immediately. It's consistently the most taxing motion in typing.
  > 同指ビグラムは、持ち上げ・移動・押下を1本の指で連続して行うため、生体力学的に最も負荷が高く、快適性評価でも一貫して最低スコアを記録する。

* Hand alternation (done)
  Measures how often typing switches between hands. More alternation means faster, less tiring typing.
  左右の手が交互に使われる割合を計測する。交互打鍵が多いほど、速く疲れにくいタイピングに近づく。
  > While one hand presses a key, the other is already moving to the next. That overlap is why high alternation helps both speed and endurance.
  > 片方の手がキーを押している間、もう一方は次のキーへ移動できる。この並列動作が速度と持久性を同時に高める理由である。

* Time-window transitions / IKI (done)
  Analyzes key transition timing within short windows. Captures typing rhythm and surfaces high-speed sequences that cause strain.
  短い時間窓内のキー遷移パターンを分析する。打鍵リズムを捉え、負荷の高い高速連打を検出する。
  > The same sequence typed slowly is harmless; at high speed it becomes repetitive strain. Count data alone can't tell you which.
  > 同じキー列でも、ゆっくり打てば問題なく、高速で打てば反復性ストレスになる。打鍵間隔は、累積カウントだけでは見えない疲労の変数である。

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
  指の負荷・交互打鍵率・同指連打率などを統合し、配列の良し悪しを単一の数値で比較できるようにする。
  > Without a single score, individual metrics point in different directions and you can't weigh one against another.
  > 統一スコアがなければ各指標がバラバラに主張するだけで、配列間の客観比較ができない。数値化によって初めて、どちらが良いか、を論拠を持って判断できる。

* Finger load weighting (done)
  Assigns different weights to each finger based on strength and reach.
  各指の自然な強さと可動域に基づいて、キー割り当ての重み付けを行う。
  > Index fingers are roughly twice as capable as pinkies. Treating all fingers equally produces layouts that overload weak fingers.
  > 人差し指は小指に比べて強さ・横方向のリーチともに約2倍の能力がある。均等に扱うと弱い指に過負荷がかかる配列になる。

* Thumb imbalance detection (done)
  Measures whether thumb usage is evenly split between left and right.
  左右の親指キーの使用量が偏っていないかを計測する。
  > Standard layouts hide this imbalance. On split keyboards it shows up clearly — an overloaded thumb is a common source of long-term strain.
  > スプリットキーボードは、標準配列では見えない親指の偏りを顕在化する。片側の親指への集中は長期的な疲労の起点になりやすい。

* High-strain sequence detection (done)
  Identifies sequences that stack poor alternation, same-finger use, and lateral stretch at once.
  交互打鍵の乏しさ・同指連打・横方向の指の伸びが重なる、特に負荷の高いキー列を検出する。
  > Each metric looks fine on its own, but when all three stress factors land on the same sequence, the cumulative load is much worse than any single metric shows.
  > 各指標を個別に見ても複合的な負荷は見えない。3つのストレス要因が同時に重なるパターンは、パターン単位の分析でしか検出できない。

### Completed — P1 issues

* [#85] Define scoring formula for slowness and frequency prioritization (done)
* [#104] IKI per finger (done)
* [#103] IKI per bigram (done)
* [#98] Latency analysis for key-to-key transitions (done)
* [#61] Layout efficiency score (same-finger rate / hand alternation by layout) (done)

### Differentiating additions

* Thumb efficiency coefficient
  Measures how well thumb keys are actually reducing load on the other eight fingers.
  親指キーが他の8本の指の負荷をどれだけ効果的に軽減しているかを定量化する。
  > Thumb keys are the most flexible positions on a split keyboard. This coefficient checks whether that flexibility is being used.
  > 親指キーはスプリットキーボード上で最も価値の高い配置領域である。この係数によって、その価値が実際の打鍵習慣で活かされているかを測定する。

* Same-finger penalty weighting (done)
  Applies non-linear penalties based on how far the finger must travel between same-finger keys.
  同指ビグラムに対し、指が移動しなければならない距離に応じた非線形ペナルティを適用する。
  > Adjacent-key same-finger bigrams are annoying; two-row stretches are genuinely painful. A linear penalty misses that difference.
  > 隣接キーの同指ビグラムは不快な程度だが、2行をまたぐものは負荷が格段に大きい。線形ペナルティでは長距離同指伸びのコストを過小評価してしまう。

* Alternation reward coefficient (done)
  Adds a score bonus for sequences with smooth hand alternation.
  連続打鍵で滑らかな左右交互が実現されている場合に、スコアへのボーナスを付与する。
  > Rewarding alternation — rather than only penalizing same-hand use — gives the optimizer a positive target, not just a cost to avoid.
  > 同手使用にペナルティを与えるだけでなく交互打鍵を積極的に報酬として扱うことで、両手並列動作の利点を最大化する配列へと最適化エンジンを誘導できる。

Phase 1 done. Layout comparisons are now objective.

---

# Phase 2 – Optimization engine

## Goal

Complete the automated key relocation logic.

### Required

* Thumb recommendation engine — [#208]
* Key relocation simulation — [#72]
* Before/After comparison — [#84]

### Should add

* Constraint solver (preserve fixed keys)
* Travel distance estimation
* Same-finger minimization optimizer
* Layer key usage analyzer — [#209]
  User registers a Layer Mapping Table (layer key + finger assignment, output key → layer key + base key). KeyLens re-interprets captured key events at analysis time, enabling correct same-finger, hand load, and ergonomic scoring for layer-based input. IKI for layer combos is estimated (OS only exposes output event timestamps).

### Training chain (implement in order after #85)

`#83 → #87 → #86 → #84 → #90 → #89 → #88 → #82`

* [#83] Phase 1: Generate bigram-based typing drills from slow combinations
* [#87] Build practice sequence generator for ranked bigrams
* [#86] Design training session format and repetition rules
* [#84] Add before/after measurement for trained combinations
* [#90] Add UI for generated training drills
* [#89] Phase 2: Expand training targets from bigrams to trigrams
* [#88] Store training results and progress history
* [#82] Add personalized typing training courses based on slow key combinations

---

# Phase 3 – Visualization & behavioral feedback (deferred)

Intentionally postponed. Implement Phase 1 & 2 first.

### Deferred issues

* [#115] Real-time typing speedometer — analog gauge for live WPM
* [#99] Speed analysis UI: bigram IKI heatmap and slow bigrams chart
* [#78] Interactive 2D Heatmap (Day of Week × Hour of Day)
* [#74] Annual 'Year in Review' statistics report
* [#70] Auto-generate weekly summary card as shareable PNG
* [#62] Period comparison mode — compare any two date ranges side by side

### Features (when resumed)

* Ergonomic heatmap
* Learning curve
* Weekly delta report
* Layout comparison dashboard

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

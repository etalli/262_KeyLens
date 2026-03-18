# KeyLens Optimization Roadmap

## 🎯 Vision

KeyLens will evolve from a simple key counter into:

> A research-grade keyboard optimization platform.

The goal is to transform raw typing logs into ergonomic intelligence
and layout optimization insights.

---

Experience shows that split or slightly spaced keyboards reduce fatigue during extended typing sessions. The design assumes a split layout, though physical separation is not strictly required — even a small gap between halves suffices.

Optimization is designed around split keyboards with active use of thumb keys.

1. Measurement Integrity
2. Ergonomic Model
3. Optimization Engine
4. Adaptive Intelligence
5. Product Layer

---

## Issue Priority Map

| Priority | Issues | Theme |
|----------|--------|-------|
| **Closed (resolved)** | #144, #145, #146 | Bugs resolved in v0.56 |
| **Closed (resolved)** | #61, #85, #98, #103, #104 | Phase 1: Measurement & Scoring — all done |
| **Closed (resolved)** | #60 | Session detection |
| **P2 — Training chain** | #83 → #87 → #86 → #84 → #90 → #89 → #88 → #82 | Drill generation |
| **P3 — Future** | #72, #76, #63, #64, #75 | Low priority / research |
| **P3 — UX / Polish** | #169, #170, #174 | UI tests, icon design, Keyboard tab UX |
| **Deferred** | #115, #99, #78, #70, #74, #62 | Visualization (intentionally postponed) |

---

# Phase 0 – Measurement Integrity ✅

## Goal

Establish accurate and reproducible keystroke logging.

### Required

* Bigram / Trigram ✅
  Measures how often two- or three-key sequences appear in typing. The statistical backbone for identifying common patterns and evaluating layout efficiency.
  2〜3キーの連続打鍵パターンの出現頻度を計測する。配列効率の評価における統計的な基盤となる。
  > Layout optimization research (Dvorak, Colemak, etc.) is fundamentally driven by bigram frequency — the most common pairs should land on the strongest fingers and the home row.
  > Dvorak・Colemakなど主要な配列研究はすべてビグラム頻度分析を基礎としており、頻出ペアを強い指・ホームロウに集中させることが設計の核心となっている。

* Same-finger repetition ✅
  Tracks how often consecutive keystrokes are made by the same finger. High rates increase both fatigue and error likelihood.
  同じ指で連続してキーを打つ頻度を追跡する。頻度が高いほど疲労とミスタイプのリスクが上がる。
  > Same-finger bigrams force a single finger to lift, reposition, and press again in rapid succession — biomechanically the most taxing motion in typing, and consistently rated worst in comfort studies.
  > 同指ビグラムは、持ち上げ・移動・押下を1本の指で連続して行うため、生体力学的に最も負荷が高く、快適性評価でも一貫して最低スコアを記録する。

* Hand alternation ✅
  Measures how frequently typing alternates between left and right hands. Greater alternation generally correlates with faster, more ergonomic typing.
  左右の手が交互に使われる割合を計測する。交互打鍵が多いほど、速く疲れにくいタイピングに近づく。
  > While one hand presses a key, the other can simultaneously position for the next — this overlap is why high alternation increases both speed and endurance.
  > 片方の手がキーを押している間、もう一方は次のキーへ移動できる。この並列動作が速度と持久性を同時に高める理由である。

* Time-window transitions / IKI ✅
  Analyzes key transition patterns within short time windows. Captures typing rhythm and surfaces high-speed sequences that may cause strain.
  短い時間窓内のキー遷移パターンを分析する。打鍵リズムを捉え、負荷の高い高速連打を検出する。
  > The same key sequence typed slowly is harmless; at high speed, it becomes repetitive strain. Inter-keystroke interval is the critical variable that raw count data alone cannot reveal.
  > 同じキー列でも、ゆっくり打てば問題なく、高速で打てば反復性ストレスになる。打鍵間隔は、累積カウントだけでは見えない疲労の核心的な変数である。

### Additional (Important)

* Layout abstraction layer (decoupled from physical layout) ✅
* Split keyboard mapping model ✅
* Finger assignment model ✅

---

# Phase 1 – Unified Ergonomic Model ✅

## Goal

Build a unified ergonomic scoring engine.

### Core ✅

* Ergonomic score formula ✅
  Combines multiple metrics (finger load, alternation, same-finger rate) into a single comparable score.
  指の負荷・交互打鍵率・同指連打率などを統合し、配列の良し悪しを単一の数値で比較できるようにする。
  > A unified score is essential for making objective comparisons between layouts. Without it, individual metrics point in different directions and cannot be weighed against each other.
  > 統一スコアがなければ各指標がバラバラに主張するだけで、配列間の客観比較ができない。数値化によって初めて、どちらが良いか、を論拠を持って判断できる。

* Finger load weighting ✅
  Assigns different weights to each finger based on its natural strength and reach capability.
  各指の自然な強さと可動域に基づいて、キー割り当ての重み付けを行う。
  > Index fingers are roughly twice as capable as pinkies in both strength and lateral reach. Treating all fingers equally produces layouts that overload weak fingers.
  > 人差し指は小指に比べて強さ・横方向のリーチともに約2倍の能力がある。均等に扱うと弱い指に過負荷がかかる配列になる。

* Thumb imbalance detection ✅
  Measures whether thumb key usage is evenly distributed between left and right thumbs.
  左右の親指キーの使用量が偏っていないかを計測する。
  > Split keyboards expose thumb imbalance that standard layouts hide. An overloaded thumb becomes a bottleneck and a common source of long-term strain in heavy thumb-key users.
  > スプリットキーボードは、標準配列では見えない親指の偏りを顕在化する。片側の親指への集中は長期的な疲労の起点になりやすい。

* High-strain sequence detection ✅
  Identifies key sequences that combine poor alternation, same-finger use, and lateral finger stretch simultaneously.
  交互打鍵の乏しさ・同指連打・横方向の指の伸びが重なる、特に負荷の高いキー列を検出する。
  > Individual metrics miss compound strain — a sequence can look acceptable on each axis yet be highly taxing when all three stress factors coincide. Detection requires pattern-level analysis.
  > 各指標を個別に見ても複合的な負荷は見えない。3つのストレス要因が同時に重なるパターンは、パターン単位の分析でしか検出できない。

### Completed — P1 Issues ✅

* [#85] ✅ Define scoring formula for slowness and frequency prioritization
* [#104] ✅ IKI per finger
* [#103] ✅ IKI per bigram
* [#98] ✅ Latency analysis for key-to-key transitions
* [#61] ✅ Layout efficiency score (same-finger rate / hand alternation by layout)

### Differentiating Additions

* Thumb efficiency coefficient
  Quantifies how effectively thumb keys reduce load on the other eight fingers.
  親指キーが他の8本の指の負荷をどれだけ効果的に軽減しているかを定量化する。
  > Thumb keys are uniquely high-value real estate on split keyboards. This coefficient measures whether that value is actually being realized in practice.
  > 親指キーはスプリットキーボード上で最も価値の高い配置領域である。この係数によって、その価値が実際の打鍵習慣で活かされているかを測定する。

* Same-finger penalty weighting ✅
  Applies non-linear penalties to same-finger bigrams based on the distance the finger must travel between keys.
  同指ビグラムに対し、指が移動しなければならない距離に応じた非線形ペナルティを適用する。
  > A same-finger bigram on adjacent keys is merely uncomfortable; one spanning two rows is significantly more taxing. Linear penalties underestimate the cost of long-distance same-finger stretches.
  > 隣接キーの同指ビグラムは不快な程度だが、2行をまたぐものは負荷が格段に大きい。線形ペナルティでは長距離同指伸びのコストを過小評価してしまう。

* Alternation reward coefficient ✅
  Boosts the score for sequences that achieve smooth hand alternation across consecutive keystrokes.
  連続打鍵で滑らかな左右交互が実現されている場合に、スコアへのボーナスを付与する。
  > Rewarding alternation rather than merely penalizing same-hand usage produces better optimization targets — it actively guides the engine toward layouts that exploit the two-hand parallelism advantage.
  > 同手使用にペナルティを与えるだけでなく交互打鍵を積極的に報酬として扱うことで、両手並列動作の利点を最大化する配列へと最適化エンジンを誘導できる。

Outcome:
At this point, objective ergonomic evaluation becomes possible.

---

# Phase 2 – Optimization Engine

## Goal

Complete the automated key relocation logic.

### Required

* Thumb recommendation engine
* Key relocation simulation — [#72]
* Before/After comparison — [#84]

### Should Add

* Constraint solver (preserve fixed keys)
* Travel distance estimation
* Same-finger minimization optimizer

### Training Chain (implement in order after #85)

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

# Phase 3 – Visualization & Behavioral Feedback ⏸ (deferred)

> Intentionally postponed. Implement Phase 1 & 2 first.

### Deferred Issues

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

# Phase 4 – Research-grade Intelligence

AI is introduced here. ML features follow.

### ML

* [#76] Typing style clustering
* [#63] Fatigue risk modeling
* Adaptive layout evolution

### Other Future

* [#64] iCloud sync across multiple Macs
* [#75] Obsidian / Daily Journal integration
* [#47] Auto-detect keyboard type from device name
* [#43] KLE JSON import for custom heatmap layout templates

---

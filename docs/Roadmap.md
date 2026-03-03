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


# Phase 0 – Measurement Integrity

## Goal

Establish accurate and reproducible keystroke logging.

### Required

* Bigram / Trigram
  Measures how often two- or three-key sequences appear in typing. The statistical backbone for identifying common patterns and evaluating layout efficiency.
  2〜3キーの連続打鍵パターンの出現頻度を計測する。配列効率の評価における統計的な基盤となる。
  > Layout optimization research (Dvorak, Colemak, etc.) is fundamentally driven by bigram frequency — the most common pairs should land on the strongest fingers and the home row.
  > Dvorak・Colemakなど主要な配列研究はすべてビグラム頻度分析を基礎としており、頻出ペアを強い指・ホームロウに集中させることが設計の核心となっている。

* Same-finger repetition
  Tracks how often consecutive keystrokes are made by the same finger. High rates increase both fatigue and error likelihood.
  同じ指で連続してキーを打つ頻度を追跡する。頻度が高いほど疲労とミスタイプのリスクが上がる。
  > Same-finger bigrams force a single finger to lift, reposition, and press again in rapid succession — biomechanically the most taxing motion in typing, and consistently rated worst in comfort studies.
  > 同指ビグラムは、持ち上げ・移動・押下を1本の指で連続して行うため、生体力学的に最も負荷が高く、快適性評価でも一貫して最低スコアを記録する。

* Hand alternation
  Measures how frequently typing alternates between left and right hands. Greater alternation generally correlates with faster, more ergonomic typing.
  左右の手が交互に使われる割合を計測する。交互打鍵が多いほど、速く疲れにくいタイピングに近づく。
  > While one hand presses a key, the other can simultaneously position for the next — this overlap is why high alternation increases both speed and endurance.
  > 片方の手がキーを押している間、もう一方は次のキーへ移動できる。この並列動作が速度と持久性を同時に高める理由である。

* Time-window transitions
  Analyzes key transition patterns within short time windows. Captures typing rhythm and surfaces high-speed sequences that may cause strain.
  短い時間窓内のキー遷移パターンを分析する。打鍵リズムを捉え、負荷の高い高速連打を検出する。
  > The same key sequence typed slowly is harmless; at high speed, it becomes repetitive strain. Inter-keystroke interval is the critical variable that raw count data alone cannot reveal.
  > 同じキー列でも、ゆっくり打てば問題なく、高速で打てば反復性ストレスになる。打鍵間隔は、累積カウントだけでは見えない疲労の核心的な変数である。

### Additional (Important)

* Layout abstraction layer (decoupled from physical layout)
* Split keyboard mapping model
* Finger assignment model

---

# Phase 1 – Unified Ergonomic Model

## Goal

Build a unified ergonomic scoring engine.

### Core

* Ergonomic score formula
  Combines multiple metrics (finger load, alternation, same-finger rate) into a single comparable score.
  指の負荷・交互打鍵率・同指連打率などを統合し、配列の良し悪しを単一の数値で比較できるようにする。
  > A unified score is essential for making objective comparisons between layouts. Without it, individual metrics point in different directions and cannot be weighed against each other.
  > 統一スコアがなければ各指標がバラバラに主張するだけで、配列間の客観比較ができない。数値化によって初めて、どちらが良いか、を論拠を持って判断できる。

* Finger load weighting
  Assigns different weights to each finger based on its natural strength and reach capability.
  各指の自然な強さと可動域に基づいて、キー割り当ての重み付けを行う。
  > Index fingers are roughly twice as capable as pinkies in both strength and lateral reach. Treating all fingers equally produces layouts that overload weak fingers.
  > 人差し指は小指に比べて強さ・横方向のリーチともに約2倍の能力がある。均等に扱うと弱い指に過負荷がかかる配列になる。

* Thumb imbalance detection
  Measures whether thumb key usage is evenly distributed between left and right thumbs.
  左右の親指キーの使用量が偏っていないかを計測する。
  > Split keyboards expose thumb imbalance that standard layouts hide. An overloaded thumb becomes a bottleneck and a common source of long-term strain in heavy thumb-key users.
  > スプリットキーボードは、標準配列では見えない親指の偏りを顕在化する。片側の親指への集中は長期的な疲労の起点になりやすい。

* High-strain sequence detection
  Identifies key sequences that combine poor alternation, same-finger use, and lateral finger stretch simultaneously.
  交互打鍵の乏しさ・同指連打・横方向の指の伸びが重なる、特に負荷の高いキー列を検出する。
  > Individual metrics miss compound strain — a sequence can look acceptable on each axis yet be highly taxing when all three stress factors coincide. Detection requires pattern-level analysis.
  > 各指標を個別に見ても複合的な負荷は見えない。3つのストレス要因が同時に重なるパターンは、パターン単位の分析でしか検出できない。

### Differentiating Additions

* Thumb efficiency coefficient
  Quantifies how effectively thumb keys reduce load on the other eight fingers.
  親指キーが他の8本の指の負荷をどれだけ効果的に軽減しているかを定量化する。
  > Thumb keys are uniquely high-value real estate on split keyboards. This coefficient measures whether that value is actually being realized in practice.
  > 親指キーはスプリットキーボード上で最も価値の高い配置領域である。この係数によって、その価値が実際の打鍵習慣で活かされているかを測定する。

* Same-finger penalty weighting
  Applies non-linear penalties to same-finger bigrams based on the distance the finger must travel between keys.
  同指ビグラムに対し、指が移動しなければならない距離に応じた非線形ペナルティを適用する。
  > A same-finger bigram on adjacent keys is merely uncomfortable; one spanning two rows is significantly more taxing. Linear penalties underestimate the cost of long-distance same-finger stretches.
  > 隣接キーの同指ビグラムは不快な程度だが、2行をまたぐものは負荷が格段に大きい。線形ペナルティでは長距離同指伸びのコストを過小評価してしまう。

* Alternation reward coefficient
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
* Key relocation simulation
* Before/After comparison

### Should Add

* Constraint solver (preserve fixed keys)
* Travel distance estimation
* Same-finger minimization optimizer

---

# Phase 3 – Visualization & Behavioral Feedback

### Features

* Ergonomic heatmap
* Learning curve
* Weekly delta report
* Layout comparison dashboard


---

# Phase 4 – Research-grade Intelligence

AI is introduced here. ML features follow.

### ML

* Typing style clustering
* Fatigue risk modeling
* Adaptive layout evolution


---

# References

## Keyboard Layout Optimization

- Klein, A. (2021). *Engram: A Systematic Approach to Optimize Keyboard Layouts for Touch Typing, With Example for the English Language*. Preprints.org.
  https://www.preprints.org/manuscript/202103.0287
  — Systematic layout optimization using character-pair (bigram) frequency and ergonomic scoring. Basis for bigram-driven layout evaluation.
  従来のキーボード配列が歴史的事情で決まっているのに対し、人間工学 × データ解析に基づく新しいキーボード配列設計の枠組みを提示する。従来は経験則や経験者の勘に頼られがちな配列設計に対して、定量的最適化手法を導入した。

- Onsorodi, A. H. H., & Korhan, O. (2020). *Application of a Genetic Algorithm to the Keyboard Layout Problem*. PLOS ONE, 15(1), e0226611.
  https://doi.org/10.1371/journal.pone.0226611
  — Genetic algorithm approach using bigram frequency to minimize finger travel distance. Demonstrates measurable improvement over QWERTY.
  遺伝的アルゴリズムにより、文字頻度とキーボード座標の組み合わせ最適化を実装。結果、QWERTYと比較して 指の移動効率が改善された配列候補を得た。これはタイピングの疲労軽減や効率改善につながる可能性を示唆する研究

- Nivasch, K. (2023). *Keyboard Layout Optimization and Adaptation*. International Journal on Artificial Intelligence Tools, World Scientific.
  https://doi.org/10.1142/S0218213023600023
  — Surveys optimization models including ergonomic scoring approaches comparable to Carpalx.
　　深層学習支援型の探索により、従来のGAよりも効率的に高品質なキーボード配列候補を生成可能としている。
　　最適化された配列が理論上優れていても、実際のユーザーがどれだけ早く慣れるかが重要という実践的視点を加えている。
　　アルゴリズム評価だけでなく、実ユーザー実験を組み合わせている。

- Krzywinski, M. (2006–). *Carpalx: Keyboard Layout Optimizer*. bcgsc.ca.
  https://mk.bcgsc.ca/carpalx/
  — Widely referenced layout scoring algorithm. Foundational reference for same-finger penalty and finger load weighting models.
  Carpalx は、キーボード配列を定量的に評価・最適化するためのツール・モデル。タイピングの労力を数値化し、最小になる配列を見つけるシミュレーションを行う。手や指への負担を減らすことを目的としている。指の「努力コスト」をモデル化し、小指に最も高いコストを割り当てている。


## Typing Ergonomics & Repetitive Strain Injury(RSI)

- Keller, K., Corbett, J., & Nichols, D. (1998). *Repetitive Strain Injury in Computer Keyboard Users: Pathomechanics and Treatment Principles in Individual and Group Intervention*. Journal of Hand Therapy, 11(1).
  https://doi.org/10.1016/s0894-1130(98)80056-2
  — Describes RSI as a multifactorial kinetic-chain disorder. Supports the claim that same-finger repetition is a primary strain mechanism.
  コンピュータのキーボード使用に伴う反復性ストレス障害（RSI）の発症メカニズムと病態、評価法、治療・予防の原則を総合的に整理したレビューで、とくに、RSI は姿勢・筋・神経の相互作用による多因子性障害、予防には姿勢改善・適宜休憩・職場環境の最適化が重要、治療は個別ケアと職場介入を統合するべき、というポイントが強調されている。

- Kim, J. H., et al. (2014). *Differences in Typing Forces, Muscle Activity, Comfort, and Typing Performance Among Virtual, Notebook, and Desktop Keyboards*. Ergonomics.
  https://pubmed.ncbi.nlm.nih.gov/24856862/
  — Empirical measurement of finger-level muscle activation and typing force. Basis for finger load weighting by finger type.
  仮想キーボードは指の力と筋肉負担は少ないが、タイピング効率と快適さが大きく劣る。逆に 物理的なキートラベル（押し込み感）がある従来型キーボードは、長時間や生産性重視の入力作業に適している可能性が高いという結論。験的な指レベルの筋電図（EMG）計測。指ごとの打鍵力と筋活動量を実測し、小指が最も高い活性化率を示すことを確認

- (2024). *Therapeutic Approaches for the Prevention of Upper Limb Repetitive Strain Injuries in Work-Related Computer Use: A Scoping Review*. Journal of Occupational Rehabilitation, Springer Nature.
  https://doi.org/10.1007/s10926-024-10204-z
  — Comprehensive review of 58 studies on RSI prevention. Supports time-window transition analysis as a fatigue detection method.
  キーボード・マウスなどを使う人に生じる上肢の反復性ストレス障害（RSI）を予防するための治療・介入法 について、
　2000年代以降の研究成果を体系的にまとめることを目的とした網羅的な整理

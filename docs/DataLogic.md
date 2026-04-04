# Ergonomic Load Calculation Logic

Within `KeyLensCore`, finger load is quantified through the following four steps:

### 1. Base Capability Values (FingerLoadWeight)

First, we define the relative "strength" or "stamina" of each finger:

- **Index finger**: 1.0 (The strongest, baseline finger)
- **Middle finger**: 0.9
- **Thumb**: 0.8
- **Ring finger**: 0.6
- **Pinky finger**: 0.5 (The weakest and most easily fatigued)

**Formula**: `Keystrokes / Capability Value`
For example, typing 100 times with your pinky (0.5) is counted as the same load as typing 200 times with your index finger (1.0). In other words, weaker fingers incur a higher load per keystroke.

### 2. Same-Finger Bigram Penalty (SameFingerPenalty)

Typing different keys consecutively with the same finger (Same-Finger Bigram) puts significant strain on the hand. The penalty is computed as:

```
penalty = fingerWeight × distanceFactor ^ 2
```

Distance factors by tier:

| Tier | Distance Factor | Resulting Penalty (index finger, weight 1.0) |
|------|----------------|----------------------------------------------|
| Same key (repeat) | 0.5 | 0.25 |
| Adjacent (same row, e.g. F → G) | 1.0 | 1.0 |
| 1-row vertical (e.g. F → R) | 2.0 | 4.0 |
| 2+ rows vertical (e.g. F → 4) | 4.0 | 16.0 |

The exponent (2.0) means vertical stretching increases load quadratically — one row apart is 4× more costly than adjacent, two rows apart is 16×.

### 3. High-Strain Sequence Detection (HighStrainDetector)

Movements that are particularly likely to cause repetitive strain injury (RSI) are flagged as "High Strain":

**High-strain bigram (2 keys):**
- **Criteria**: Same finger + vertical movement of 1 or more rows.
- **Example**: F → R (left index, 1 row apart) = high-strain. F → G (adjacent, same row) = NOT high-strain.

**High-strain trigram (3 keys):**
- **Criteria**: Two consecutive bigrams are both high-strain.
- **Example**: F → R → T — if both F→R and R→T qualify as high-strain bigrams, the trigram is flagged.

These sequences are specifically tracked and visualized in the "Strain" mode of the heatmap.

### 4. Integrated Scoring (ErgonomicScoreEngine)

All metrics are combined into a single score out of 100 using this formula:

```
score = 100
  − sameFingerPenaltyWeight    × (sameFingerRate    × 100)
  − highStrainPenaltyWeight    × (highStrainRate    × 100)
  − thumbImbalancePenaltyWeight× (thumbImbalanceRatio × 100)
  − rowReachPenaltyWeight      × (rowReachScore     × 100)
  + alternationRewardWeight    × (handAlternationRate × 100)
  + thumbEfficiencyBonusWeight × (thumbEfficiencyCoefficient × 100)
```

All sub-scores are normalized to [0, 100] before weighting. The score is clamped to [0, 100].

- **Deductions**: Same-finger bigram rate, high-strain sequence rate, thumb imbalance (left vs. right), and excessive row reach.
- **Bonuses**: Hand alternation rate and efficient thumb key utilization.

**Summary**:
Rather than simply counting "which key was pressed how many times," KeyLens simulates the physical strain based on "which finger was used, how far it had to stretch, and how much it was used consecutively."

---
*If you are interested in more detailed logic, such as the handling of specific keys like Space or Cmd, please let us know.*

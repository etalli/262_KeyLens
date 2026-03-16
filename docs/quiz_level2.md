# KeyLens 理解度テスト — Level 2

このテストは、KeyLens プロジェクトの**実装の深い部分と設計判断**を理解できているかを確認するためのものです。

## 第1部：SwiftUI × AppKit 統合

**Q1. `KeystrokeOverlayController` では `NSHostingController<OverlayView>` を使って SwiftUI ビューを AppKit に埋め込んでいます。なぜ `NSHostingView` ではなく `NSHostingController` を使い、`panel.contentViewController` に設定しているのでしょうか？**

**Q2. `OverlayView` に `.fixedSize()` が2箇所付いています（`Text` と外側の `HStack`）。それぞれ何のために使われていますか？**

---

## 第2部：非同期・スレッド設計

**Q3. `startListening()` 内でキー入力を受信した後、`placePanel()` を直接呼ばずに `DispatchQueue.main.async { self?.placePanel() }` で遅らせているのはなぜですか？**

**Q4. `OverlayViewModel` の `fadeTimer` は `DispatchWorkItem` で実装されています。`Timer` や `asyncAfter` ではなく `DispatchWorkItem` を使うことで実現している「重要な機能」は何ですか？**

---

## 第3部：設定の永続化

**Q5. `OverlayConfig` は `UserDefaults` に JSON（`Data`）として保存されています。なぜ `UserDefaults.standard.set(_:forKey:)` で直接 `struct` を保存しないのでしょうか？**

**Q6. `OverlayConfig.current` は毎回 `UserDefaults` + `JSONDecoder` を呼び出すプロパティです。キャッシュせずに毎回読み直す設計にしている理由を答えてください。**

---

## 第4部：通知設計

**Q7. 今回の実装で `keystrokeInput` 通知のペイロードを `String` から `KeystrokeEvent` struct に変更しました。この変更によって「型安全性」の面でどのような改善がありましたか？**

**Q8. `OverlayViewModel` は `.overlayConfigDidChange` 通知を受信して `config` を更新します。一方 `fadeDelay` は通知を受けず `append()` 呼び出し時に毎回 `OverlayConfig.current.fadeDelay` を読んでいます。この違いはなぜ設けられているのでしょうか？**

---

## 第5部：応用・トレードオフ

**Q9. `NSPanel` に `.stationary` という `collectionBehavior` が設定されています。これがないと何が起きますか？**

**Q10. 現在の `OverlayConfig` は `static var current` で毎回 UserDefaults から読み込みます。もし将来「設定変更を即座に反映しつつ、読み取りコストも下げたい」となった場合、どのような設計変更が考えられますか？（自由記述）**

---

## 第6部：データロジック — 負担スコアリング

**Q11. `FingerLoadWeight` では「打鍵数 ÷ 指の能力値」で負担を計算しています。なぜ「打鍵数 × 重み」（乗算）ではなく「打鍵数 ÷ 能力値」（除算）という式になっているのでしょうか？両者の意味の違いを説明してください。**

**Q12. 人差し指の能力値は `1.0`（基準）ですが、小指は `0.5` です。この値は「小指で100回打つ = 人差し指で200回打つ」と等価であることを意味します。この設計において、能力値を `0.0` に設定すると計算上どのような問題が発生しますか？**

**Q13. `SameFingerPenalty` の計算式は `fingerWeight × distanceFactor ^ exponent` です（デフォルト exponent=2.0）。距離係数は sameKey=0.5 / adjacent=1.0 / oneRow=2.0 / multiRow=4.0 であり、index finger（weight=1.0）の場合の実際のペナルティは `0.25 / 1.0 / 4.0 / 16.0` と非線形に増加します。縦移動1行 → 2行以上で 4倍 → 16倍（2乗の増加）にしている設計上の根拠は何ですか？線形（4倍 → 8倍）にしなかった理由を考察してください。**

**Q14. 同一キーへの連続打鍵（キーリピートなど）の距離係数は `0.5`（隣接打鍵の半分）で最も低く、index finger でのペナルティは `0.5² = 0.25`（隣接打鍵の 1/4）になります。「同じ指を使っているのに、なぜペナルティが隣接打鍵（1.0 倍）より低いのか」を身体的・物理的な観点から説明してください。**

**Q15. `HighStrainDetector` の判定条件は「同じ指」かつ「縦に1行以上の移動」です。`SameFingerPenalty` の計算とは別に、この検出器が独立して存在する理由は何ですか？ペナルティスコアだけでは不十分な点を説明してください。**

**Q16. `ErgonomicScoreEngine` は 100点満点のスコアを出力します。このスコアが「0点以下になる」または「100点を超える」ケースが原理的に発生し得るかどうか、および KeyLens がそれをどのように防いでいるか（または防ぐべきか）を考察してください。**

**Q17. 減点要素の一つに「左右の親指の使い方の偏り（Imbalance）」があります。なぜ親指の偏りだけを特別に Imbalance として扱い、他の指（例：左右の人差し指の偏り）は個別に Imbalance として扱わないのでしょうか？**

**Q18. 加点要素の「Hand Alternation（左右交互打鍵）」は、左右の手を交互に使うほど高スコアになります。しかし、例えばプログラマが `===` や `...` を多用する場合、Hand Alternation が低くなります。このトレードオフをスコアに反映する際、設計上どのような注意が必要ですか？**

**Q19. KeyLens の負担計算は「物理レイアウトに基づくシミュレーション」を行っています。しかし実際の打鍵データは「どのキーコードが何回押されたか」という論理的な情報です。物理レイアウト（キーの行・列位置）を誰が・どのタイミングで解決しているか、設計上の責任の所在を説明してください。**

**Q20. `ErgonomicScoreEngine` の加点・減点ロジックを将来「ユーザーがカスタマイズできる重み付け」に対応させたい場合、現在の設計のどこを変更する必要がありますか？また、重みをユーザーごとに永続化する場合、どのストレージ戦略が適切ですか？**

---

## 第7部：ErgonomicProfile とハードウェア抽象化

**Q21. `ErgonomicProfile` と `ErgonomicScoreWeights` は別の struct として分離されています。それぞれが表す「関心事（concern）」の違いを説明し、なぜ一つの struct にまとめなかったのかを答えてください。**

**Q22. `splitErgo` プロファイルでは `thumb` の能力値が `1.0` に設定されています（standard の場合は `0.8`）。なぜ分割キーボードユーザーに対して親指の能力値を高く設定することが適切なのでしょうか？**

**Q23. `ErgonomicProfile` の `==` 実装では `layout` 自体ではなく `layout.name` で比較しています（`lhs.layout.name == rhs.layout.name`）。なぜ `layout` オブジェクトを直接比較しないのでしょうか？**

**Q24. `ErgonomicScoreWeights` のデフォルト値はペナルティ合計 `0.70`（最大 -70点）、報酬合計 `0.30`（最大 +30点）と非対称です。ペナルティ > 報酬 にしている設計意図は何ですか？**

**Q25. `ErgonomicScoreEngine` には `thumbEfficiencyMax = 2.0` というパラメータがあります。この値の意味と、もしこのキャップが存在しなかった場合にスコアにどのような影響が出るかを説明してください。**

---

## 第8部：ビルドシステムとコード署名

**Q26. `swift build -c release` だけでビルドしても通知（`UNUserNotificationCenter`）が動作しません。`build.sh` が App Bundle を手動で組み立てている理由を、macOS の通知システムの要件から説明してください。**

**Q27. `--install` モードで `codesign --force --deep --sign -` を実行しています。`--sign -` の `-` はどういう意味ですか？Apple 発行の証明書による署名と何が違い、どのような制限がありますか？**

**Q28. ビルドのたびに `tccutil reset Accessibility "$BUNDLE_ID"` を実行する理由は何ですか？リセットしない場合に何が起き、なぜ開発中は毎回リセットが必要なのでしょうか？**

**Q29. `--dmg` モードでは `/Applications` フォルダを実際にコピーせず `ln -s /Applications "$STAGING/Applications"` でシンボリックリンクを作成しています。なぜ symlink を使い、これがユーザー体験にどう寄与しますか？**

**Q30. `build.sh` の冒頭でシェル側が独自に言語判定（`$LANG` → `AppleLocale`）を行っています。アプリ内の `L10n.swift` を使わず、シェルスクリプトで言語判定を再実装している理由は何ですか？**

---

# KeyLens 理解度テスト — Level 2：解答と解説

## 第1部：SwiftUI × AppKit 統合

**Q1. なぜ `NSHostingView` ではなく `NSHostingController` を使うのか？**
- **正解：** `NSHostingController` を `panel.contentViewController` に設定することで、NSPanel がビューコントローラのライフタイムを管理できるため。
- **解説：** `NSHostingView` は生の `NSView` サブクラスで、ライフサイクル管理（`viewDidLoad`、レイアウトパス、レスポンダチェーンへの統合）が行われません。`NSHostingController` を使うと AppKit の VC 機構が SwiftUI のレンダリングループを正しく駆動します。コード内のコメント「`contentViewController` 経由で設定することで、NSPanel が VC のライフタイムを管理する」がこの意図を示しています。なお、`AboutWindowController` では単純な静的表示に `NSHostingView` を使っており、使い分けが明確です。

**Q2. `.fixedSize()` が2箇所ある理由**
- **正解：** ① `Text` への `.fixedSize()`（line 69）— SwiftUI がテキストを省略記号（`...`）に切り詰めるのを防ぐ。② 外側 `HStack` への `.fixedSize()`（line 84）— SwiftUI の理想サイズ（intrinsic content size）でパネルを表示し、コンテナに引き伸ばされないようにする。
- **解説：** SwiftUI のデフォルト動作では、親コンテナのサイズに合わせてテキストを省略したり、ビューを引き伸ばしたりします。オーバーレイパネルは「内容に応じてサイズが変わるべき」コンポーネントなので、両方の `.fixedSize()` でコンテンツ主導のレイアウトを強制しています。

---

## 第2部：非同期・スレッド設計

**Q3. `placePanel()` を `DispatchQueue.main.async` で遅らせる理由**
- **正解：** `viewModel.append()` を呼んだ直後は SwiftUI のレイアウトパスがまだ走っていないため、`fittingSize` が古いサイズを返す。1ランループ後（`main.async`）に呼ぶことで、SwiftUI が新しいキーを反映したレイアウトを確定させてからパネルを配置できる。
- **解説：** コメント「SwiftUI のレイアウトが確定してからサイズを更新する」がこの意図を示しています。同期的に `placePanel()` を呼ぶと、前の状態のサイズでパネルが配置されてしまい、表示がずれます。

**Q4. `DispatchWorkItem` が `Timer` / `asyncAfter` より優れている点**
- **正解：** `cancel()` による「前回のタイマーのキャンセル」が可能なこと。新しいキーが来るたびに `fadeTimer?.cancel()` で前のフェードアウトを無効化し、タイマーをリセットできる。
- **解説：** `asyncAfter` はスケジュール後にキャンセルできません。`DispatchWorkItem` は `.cancel()` を持ち、実行前であればブロックを無効化できます。これによって「最後のキー入力からN秒後にフェードアウト」という挙動を正確に実現しています。

---

## 第3部：設定の永続化

**Q5. `UserDefaults` に `struct` を直接保存しない理由**
- **正解：** `UserDefaults` が保存できるのは Property List 互換型（`String`, `Int`, `Bool`, `Data`, `Array`, `Dictionary`）のみ。Swift の `struct` はそのままでは保存できないため、`JSONEncoder` で `Data` に変換してから保存している。
- **解説：** `OverlayConfig` は `Codable` に準拠しており、`JSONEncoder().encode(config)` で `Data` を生成、`UserDefaults.standard.set(data, forKey:)` で保存します。復元時は `JSONDecoder().decode(OverlayConfig.self, from: data)` で行います。

**Q6. `OverlayConfig.current` をキャッシュしない設計の理由**
- **正解：** `OverlayConfig` は値型（`struct`）であるため、インメモリにキャッシュすると設定変更の反映にキャッシュ無効化ロジックが必要になる。毎回 `UserDefaults` から読み直すことで、常に最新値を取得できてシンプルさが保たれる。
- **解説：** 設定変更は `OverlaySettingsView` の `onChange` から `.save()` が呼ばれ、直後に `.overlayConfigDidChange` 通知が飛びます。`OverlayViewModel` はこの通知を受けて `config = .current` を実行します。毎回読み直しても UserDefaults はプロセス内メモリにキャッシュされているため、コストは無視できる水準です。

---

## 第4部：通知設計

**Q7. `String` から `KeystrokeEvent` struct に変えた型安全性の改善**
- **正解：** ① ペイロードのキャストが `note.object as? KeystrokeEvent` と型付きになり、フィールドへのアクセスがコンパイル時に検証される。② 旧来の文字列フォーマット（例："A:0"）のパース処理が不要になり、フォーマット変更のリスクが排除された。
- **解説：** `String` ペイロードでは受信側が「フォーマットを知っている」という暗黙の契約が必要でした。`KeystrokeEvent` の `displayName: String` と `keyCode: UInt16` という明示的な構造により、コンパイラが整合性を保証します。

**Q8. `config` は通知で更新し、`fadeDelay` は毎回 `config.fadeDelay` を読む設計の違い**
- **正解：** `config` は SwiftUI の `@Published` で画面再描画に直結するため、通知経由で明示的に更新する必要がある。`fadeDelay` は `append()` が呼ばれるたびに読まれる値なので、`config` から直接読み取ることで自動的に最新値が使われる。
- **解説：** `fadeDelay` を別個にキャッシュすると、`config` の更新とのズレが生じるリスクがあります。`var fadeDelay: Double { config.fadeDelay }` という computed property にすることで、`config` が更新されれば `fadeDelay` も即座に反映されます。

---

## 第5部：応用・トレードオフ

**Q9. `.stationary` がない場合に何が起きるか**
- **正解：** Mission Control でスペースを切り替えたとき、パネルがアクティブなスペースに追従して移動するか、特定のスペースにのみ表示されてしまう。フルスクリーンアプリへの切り替え時にも消える。
- **解説：** `.stationary` は「パネルをスクリーン上の固定位置に留め、スペース切り替えの影響を受けない」という挙動を付与します。オーバーレイは「どのアプリを使っていても常に表示」が要件のため、`.canJoinAllSpaces`（全スペースに表示）と `.stationary`（位置固定）の組み合わせが必須です。

**Q10. 設定変更即時反映 + 読み取りコスト削減の設計変更案**
- **正解（例）：** `OverlayConfig` をインメモリにキャッシュする `static var cached: OverlayConfig` を用意し、`.overlayConfigDidChange` 通知を受け取ったときだけ `UserDefaults` から読み直してキャッシュを更新する。`current` はキャッシュを返すだけにする。
- **解説：** 現状の読み取りコストは UserDefaults がプロセス内でキャッシュしているため実質ゼロに近いですが、JSONDecoder のデコードコストが毎回発生します。通知駆動のキャッシュ戦略を採ることで、デコードは設定変更時の1回のみになります。

---

## 第6部：データロジック — 負担スコアリング

**Q11. 「打鍵数 ÷ 能力値」と「打鍵数 × 重み」の意味の違い**
- **正解：** 除算（`count / weight`）は「能力値が小さいほど1打鍵あたりの負担が大きくなる」という直感的なモデル。乗算では逆数を使う必要があり（`count × (1/weight)`）、「能力」という概念と式が一致しない。
- **解説：** 小指（`weight=0.5`）で100回打鍵すると負担は `100 / 0.5 = 200`。人差し指（`weight=1.0`）で100回打つと `100 / 1.0 = 100`。除算の場合「能力値が高いほど効率よく打てる」という意味が式に直接表れており、チューニングが直感的です。

**Q12. 能力値を `0.0` に設定した場合の問題**
- **正解：** ゼロ除算が発生し、結果が `+Infinity`（Swift では `Double.infinity`）になる。その後の加算・比較が正しく機能しなくなり、スコアが壊れる。
- **解説：** Swift の `Double` はゼロ除算でクラッシュせず `infinity` を返しますが、これが `ErgonomicScoreEngine` の合計に混入するとスコア全体が `infinity` や `NaN` になります。防御策として `guard weight > 0` のチェック、または `max(weight, 0.01)` のようなフロアを設けるべきです。

**Q13. SameFingerPenalty が 4倍 → 16倍（2乗）になっている理由**
- **正解：** 筋肉・腱のストレッチ量は指の移動距離に対して非線形に増加するため。縦2行の移動は縦1行の2倍ではなく、腱への負荷として指数的に大きくなる。
- **解説：** 線形モデル（4倍 → 8倍）は「距離に比例して負担が増える」という仮定ですが、実際の筋骨格系の挙動は非線形です。同指で2行以上跨ぐ動作（例：`f → 4`）は腱の最大伸長に近く、injury リスクが急増します。2乗モデルはこの物理的な現実をよりよく近似しています。
- **補足：** 各ティアの「生の距離係数」は 0.5 / 1.0 / 2.0 / 4.0。`exponent=2.0` を適用した実際のペナルティ（index finger, weight=1.0）は **0.25 / 1.0 / 4.0 / 16.0** になる。

**Q14. キーリピートのペナルティが隣接打鍵より低い理由**
- **正解：** 同一キーの連続打鍵は指を横に移動させる必要がなく、真下に垂直な力を加えるだけ。腱や筋肉のストレッチがほぼ発生しないため、負担が著しく小さい。
- **解説：** 隣接キー（例：`f → g`）では指を水平にスライドさせる動作が生じ、屈筋腱に横方向の力がかかります。同一キーリピートは位置を固定したまま打鍵するだけなので、疲労の主因であるポジションチェンジが発生しません。距離係数は `0.5`（隣接の半分）で、ペナルティは `0.5² = 0.25`（隣接の 1/4）。ゼロではなく「わずかな疲労は残る」ことも考慮した設計です。

**Q15. `HighStrainDetector` が `SameFingerPenalty` とは別に独立している理由**
- **正解：** `SameFingerPenalty` は総合スコアへの加算用スカラー値を生成するが、`HighStrainDetector` は「どのキーペアで高負荷が発生したか」を個別に記録するためのもの。ヒートマップの Strain モードで赤く可視化するために、発生箇所のデータが必要。
- **解説：** スコアが低くても「原因がどこか」は別の情報です。`HighStrainDetector` が記録したキーペアのリストによって「`f → r` のビグラムが最も危険」のような具体的なフィードバックが可能になります。スカラースコアだけでは教育的価値が大幅に下がります。

**Q16. スコアが 0点以下または 100点超えになり得るか**
- **正解：** 理論上は発生し得るが、`ErgonomicScoreEngine` は現在 `return max(0.0, min(100.0, raw))` でクランプ済みのため、出力は常に [0, 100] に収まる。
- **解説：** raw スコアは加点・減点の組み合わせ次第で [0, 100] を外れることがあります（例：ひたすら Alternation だけのタイピングでは 100 超え、同指ビグラムだらけのタイピングでは 0 以下）。`ErgonomicScoreEngine.score()` の末尾で `max(0.0, min(100.0, raw))` が適用されており、呼び出し元はスコアを「0〜100 の保証された値」として扱えます。

**Q17. 親指の Imbalance だけを特別扱いする理由**
- **正解：** 親指（特にスペースキー）は左右どちらでも物理的に届くため、「どちらを使うか」はユーザーの習慣によって変わる真の選択肢がある。他の指（例：左右の人差し指）はそれぞれ担当するキーが物理レイアウトで決まっており、偏りはタスクや言語の制約であって ergonomic な選択ではない。
- **解説：** 英語のテキストでは `e`, `t`, `a`（左手）が `o`, `n`, `i`（右手）より多く出現するため、左右の人差し指の使用頻度が偏るのはレイアウトの宿命です。親指の Imbalance だけを指標にすることで、「改善可能な習慣の偏り」だけを検出できます。

**Q18. Hand Alternation のトレードオフと設計上の注意点**
- **正解：** Hand Alternation はコーディング（`===`, `...`, `->` など同一手のシーケンスが多い）やショートカット多用のワークフローでは必然的に低くなる。スコアを「ワークタイプに無関係な絶対指標」として提示するのは誤解を招く。
- **解説：** 設計上の注意点として、① スコアに「コンテキスト注釈」を付ける（例：「コーディング中のため低め」）、② Alternation スコアをアプリ別に分けて表示する（v0.42 で導入済みの per-app tracking が活用できる）、③ ドキュメントで「高スコア = 必ずしも優れた習慣ではない」と明記する、などが考えられます。

**Q19. 物理レイアウト解決の責任の所在**
- **正解：** `ErgonomicProfile`（v0.43 で導入）が担当する。キャプチャ層（`KeyboardMonitor`）は生のキーコード（`UInt16`）を記録するだけで、レイアウト情報を持たない。分析時に `ErgonomicProfile.layoutForHardware()` がキーコードを物理的な行・列位置にマッピングする。
- **解説：** レイヤーの責任分離として、「何が押されたか（キーコード）」を監視層が担い、「どこにあるか（物理位置）」を分析層が担うのが正しい設計です。これにより、異なるキーボードレイアウト（JIS/US、外付けキーボード等）を後から差し替えても監視層を変更する必要がありません。

**Q20. 重み付けカスタマイズと永続化の設計変更案**
- **正解：** `ErgonomicScoreEngine` 内の固定定数（各種ペナルティ係数・加点係数）を `ScoringWeights` struct にまとめて `Codable` に準拠させる。`OverlayConfig` と同じパターンで `UserDefaults` に JSON として保存・ロードする。`ErgonomicScoreEngine.calculate(weights:)` のようにパラメータとして渡す設計にする。
- **解説：** `ScoringWeights.current` static プロパティを用意し、変更時は `.scoringWeightsDidChange` 通知を post すれば、`ErgonomicScoreEngine` は次回計算から新しい重みを使います。このパターンは `OverlayConfig` で既に実績があるため、プロジェクト内で一貫した設計になります。

---

## 第7部：ErgonomicProfile とハードウェア抽象化

**Q21. `ErgonomicProfile` と `ErgonomicScoreWeights` の関心事の違い**
- **正解：** `ErgonomicProfile` は「どのハードウェア・どの身体特性か」（物理レイアウト・指の能力・分割配置）を表す。`ErgonomicScoreWeights` は「スコア計算式の係数」という数学的モデルを表す。一つにまとめると「キーボード交換」と「スコア調整」が互いに依存してしまい、変更の影響範囲が広がる。
- **解説：** 関心事の分離（SoC）の観点から、「どのキーボードを使うか」と「どの重みで採点するか」は独立して変更できることが望ましいです。例えば、分割キーボードユーザーが独自のスコア重みを使いたい場合、`ErgonomicProfile` と `ErgonomicScoreWeights` の両方を別々にカスタマイズできます。

**Q22. `splitErgo` で `thumb` 能力値が `1.0`（standard は `0.8`）の理由**
- **正解：** 分割エルゴノミクスキーボードには「親指クラスター」と呼ばれる複数キーが親指の自然な可動域に配置されており、親指が多彩なキー操作を担う。standard キーボードよりも親指の運動効率が大幅に高いため、能力値を `1.0` に引き上げるのが適切。
- **解説：** standard キーボードでは親指はほぼスペースキーのみに使われます（能力値 `0.8` は「広い範囲への移動が苦手」という制約を反映）。分割キーボードでは Backspace・Enter・レイヤー切替などが親指クラスターに割り当てられ、親指が人差し指並みの器用さで動くため `1.0` が物理的実態に即しています。

**Q23. `ErgonomicProfile.==` が `layout.name` で比較する理由**
- **正解：** `layout` プロパティは `any KeyboardLayout`（existential type）であり、Swift のプロトコル existential は `Equatable` に準拠できない。オブジェクト自体の比較が構造上不可能なため、一意の名前（`layout.name`）を識別子として代用している。
- **解説：** Swift では `any Protocol` 型は `Equatable` を直接実装できません（Existential type does not conform to Equatable）。`layout.name` が同一であれば同じレイアウト定義を指すという設計上の規約を設けることで、`Equatable` 準拠を実現しています。副作用として、名前が同じで内容が異なるレイアウトを区別できないため、レイアウトの名前はグローバルに一意である必要があります。

**Q24. ペナルティ合計 `0.70` > 報酬合計 `0.30` の非対称設計の意図**
- **正解：** 「悪い習慣を防ぐこと」を「良い習慣を促すこと」より重視する設計思想。典型的なユーザーの打鍵では SFB率・高負荷率の改善余地の方が大きく、報酬よりペナルティのレンジを広く取ることでスコアの分布が実用的になる。
- **解説：** もしペナルティと報酬が対称（各 `0.50`）であれば、最悪のタイピングパターンでも報酬で半分まで回復でき、スコアの警告機能が弱まります。ペナルティを重くすることで「問題のある習慣がスコアに強く反映される」センシティビティを確保しています。コメントには "Penalty total: 0.70 (max deduction: 70 pts) / Reward total: 0.30 (max addition: 30 pts)" と明示されています。

**Q25. `thumbEfficiencyMax = 2.0` の意味とキャップがない場合の影響**
- **正解：** 「親指が期待使用率の2倍以上担えばフル加点」という正規化上限。コメントに "thumbs handling twice the expected share → maximum efficiency bonus" とある。キャップなしでは `thumbEfficiencyCoefficient` が無限大になりうる入力に対してスコアが `100` を大きく超え、クランプ前に数値が発散する。
- **解説：** `te100 = min(thumbEfficiencyCoefficient / 2.0, 1.0) × 100` という式で正規化されます。係数が `2.0` 以上（親指が期待の2倍以上打っている）はすべて `100` に丸められます。これにより「親指を極端に多用するマクロ操作」などの外れ値がスコアを壊すのを防いでいます。

---

## 第8部：ビルドシステムとコード署名

**Q26. `swift build` だけでは通知が動かない理由**
- **正解：** macOS の通知システム（`UNUserNotificationCenter`）は、バンドル識別子（`CFBundleIdentifier`）を持つ正規の App Bundle を要求する。`swift build` が生成するのは `Info.plist` も署名も持たない生の Mach-O バイナリであり、OS がアプリとして認識できない。
- **解説：** `build.sh` は `swift build -c release` 後に `KeyLens.app/Contents/MacOS/`、`Info.plist`、`AppIcon.png` を手動で配置して App Bundle を組み立てます。この構造があって初めて `CFBundleIdentifier` が読まれ、通知・TCC・自動ログイン（`SMAppService`）などのシステム機能が正常に動作します。

**Q27. `codesign --sign -`（アドホック署名）と Apple 発行証明書の違い**
- **正解：** `--sign -` はアドホック署名（ad-hoc signing）で、Apple の認証を受けていない自己署名。バイナリに署名ハッシュを埋め込んで TCC エントリを安定させる効果はあるが、Gatekeeper を通過できず、App Store 配布・Notarization・Team ID ベースの権限（Hardened Runtime 等）は使えない。
- **解説：** 開発中は毎回バイナリが変わるため TCC（Transparency, Consent, and Control）のハッシュが変わり、Accessibility 権限が毎回リセットされます。アドホック署名を加えることでハッシュが安定し、TCC の再許可要求の頻度を減らします。配布版（`--dmg`）では署名を行わないため、ユーザーは Gatekeeper の警告を経由してインストールします。

**Q28. `tccutil reset Accessibility` を毎ビルド実行する理由**
- **正解：** ビルドのたびにバイナリのコード署名ハッシュが変わり、TCC データベースが「別のアプリ」と判断して以前の Accessibility 許可を無効化するため。古い許可エントリが残ったままだと TCC が混乱して権限が不安定になるため、明示的にリセットして毎回クリーンな状態から許可を取得する方が確実。
- **解説：** TCC は `CFBundleIdentifier` + コード署名ハッシュで許可を管理します。アドホック署名でも毎ビルドでハッシュは変わり得るため、`tccutil reset` → アプリ再起動 → システム設定でアクセシビリティ許可、というフローを確実に踏む設計にしています。スクリプトでは `$BUNDLE_ID` を `Info.plist` から動的に取得しているため、バンドル ID が変わっても対応できます。

**Q29. `--dmg` で `/Applications` を `ln -s` にする理由**
- **正解：** DMG 内に `/Applications` フォルダのシンボリックリンクを置くことで、ユーザーがマウント後に `KeyLens.app` をリンク先にドラッグするだけでインストールが完了する「ドラッグ＆ドロップインストーラ」を実現するため。実際にコピーすると DMG サイズが /Applications の内容分だけ巨大になる。
- **解説：** macOS の慣習的な DMG 配布パターンで、`[アプリ]` + `[Applications への symlink]` をステージングフォルダに置き `hdiutil create` で DMG 化します。ユーザーが Finder で DMG を開くと「アプリ → Applications フォルダ」という視覚的なインストールUIが表示されます。

**Q30. `build.sh` がアプリ内 L10n を使わずシェル独自で言語判定する理由**
- **正解：** `L10n.swift` は Swift で実装されたアプリ内モジュールであり、シェルスクリプトから直接呼び出すことができないため。ビルドスクリプトはアプリが起動する前に実行されるので、アプリのランタイムに依存しない独立した言語判定が必要。
- **解説：** シェルスクリプトが使える情報源は環境変数（`$LANG`）とシステムコマンド（`defaults read`）のみです。`$LANG` が `ja_*` であれば日本語、それ以外は英語という2値判定で十分なため、シンプルなシェル条件式で実装しています。アプリの L10n システムが持つ動的言語切替・フォールバック・複数言語対応などの機能は、ビルドメッセージには不要です。

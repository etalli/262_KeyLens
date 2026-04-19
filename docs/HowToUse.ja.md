# KeyLens の使い方

### メニューバー

メニューバーのキーボードアイコン (⌨) をクリックするとパネルが開きます。

| 項目 | 説明 |
|------|------|
| **● Recording** | 緑のドット = モニタリング中; オレンジの警告 = アクセシビリティ権限が必要 |
| **本日: N 打鍵, N px** | 今日の打鍵数とカーソル移動距離 — クリックでグラフ → Activity → Volume に移動 |
| **Charts…** | フル分析ウィンドウを開く |
| **Data…** | CSV・SQLite エクスポート、サマリーカード、Year in Review カード、デイリーノート、バックアップの保存・復元 |
| **Settings…** | メニューウィジェット・言語・通知・Advanced Mode・オーバーレイ・WPM ゲージのカスタマイズ |
| **About KeyLens** | バージョン情報 |
| **Check for Updates…** | GitHub で最新リリースを確認 |
| **Help** | ヘルプポップオーバーを開く |
| **Quit** | アプリを終了し、未保存のデータをすべて書き出す |

ウィジェット（**Charts…** の上に表示される統計行）は **Settings… > Customize Menu** でオン/オフや並び替えが可能です。利用可能なウィジェット: Today Summary、WPM、Mini Chart、Avg Interval、Shortcut Efficiency、Streak、Recording Since、Slow Events。

### グラフウィンドウ

メニューの **Charts** から開きます。トップレベルのタブは 4 つあります。

#### Summary タブ
| セクション | 表示内容 |
|-----------|---------|
| **Activity Calendar** | 日ごとの打鍵アクティビティを GitHub スタイルのヒートマップで表示 |
| **Weekly Report** | 直近 7 日間と前の 7 日間の比較（トレンド矢印付き） |
| **Typing Profile** | 推定されるタイピングスタイルと疲労リスクレベル |
| **Mouse vs Keyboard Balance** | マウスとキーボードの使用比率（日別） |

#### Typing タブ
サブタブ: Live · Activity · Keyboard · Shortcuts · Apps · Devices

| サブタブ | 表示内容 |
|---------|---------|
| **Live** | 直近の IKI バーチャート、手動 WPM 測定、タイピングインテリジェンス |
| **Activity** | 日別 WPM、日別合計、IKI 分布、時間帯分布、週別ヒートマップ |
| **Keyboard** | キーボードヒートマップ（頻度 / 負荷）、上位 20 キー、キーカテゴリ |
| **Shortcuts** | よく使う ⌘ キーボードショートカット、すべてのキーコンボ |
| **Apps** | アプリケーションごとの打鍵数とエルゴノミックスコア |
| **Devices** | デバイスごとの打鍵数とエルゴノミックスコア |

#### Mouse タブ
サブタブ: Clicks · Direction · Distance · (Heatmap は Advanced Mode のみ)

| サブタブ | 表示内容 |
|---------|---------|
| **Clicks** | 左・中・右ボタンのクリック数 |
| **Direction** | マウス移動方向の割合と日別内訳 |
| **Distance** | 日別マウス移動距離と時間帯別アクティビティ |
| **Heatmap** | マウス位置ヒートマップ（Advanced Mode のみ） |

#### Ergonomics タブ
サブタブ: Tips · Bigrams · Layout · Fatigue · Optimizer · Compare · (Training · Inspector は Advanced Mode のみ)

| サブタブ | 表示内容 |
|---------|---------|
| **Tips** | パーソナライズされたエルゴノミクス改善のヒント |
| **Bigrams** | 上位バイグラム、指別 IKI、低速バイグラム、バイグラム IKI ヒートマップ（Advanced Mode） |
| **Layout** | レイアウト効率、レイヤー効率、レイアウト比較 |
| **Fatigue** | 時間帯別疲労曲線、エルゴノミクス学習曲線 |
| **Optimizer** | レイアウト改善のためのキー交換シミュレーター |
| **Compare** | 2 つのカスタム期間の並列比較 |
| **Training** | バイグラムタイピングドリルと履歴（Advanced Mode のみ） |
| **Inspector** | リアルタイムのキーイベント詳細（キーコード・修飾キー・HID コード）（Advanced Mode のみ） |

### AI 分析

打鍵データを書き出し（Settings… > Data > Export CSV）、内蔵プロンプト（Settings… > Data > Edit AI Prompt）とともに AI ツール（Claude、ChatGPT など）に貼り付けることで、レイアウト最適化のアドバイスを得られます。

---

### キーストロークオーバーレイ

<table>
  <tr>
    <td><img src="images/keystroke_overlay_settings.png" width="280"/></td>
    <td><img src="images/KeyStrokeOverlay-screenshot.png" width="400"/></td>
  </tr>
  <tr>
    <td align="center">設定画面</td>
    <td align="center">表示例</td>
  </tr>
</table>

メニューの **Overlay** から切り替えるか、どこからでも **⌃⌥O** で表示/非表示を切り替えられます。直前の入力をフローティングウィンドウに 3 秒間表示します。位置・サイズ・ホットキーはすべて ⚙ から設定可能です。

---

## データファイル

```
~/Library/Application Support/KeyLens/keylens.db   — 打鍵データ（SQLite）
~/Library/Application Support/KeyLens/mouse.db     — カーソル移動データ（SQLite）
~/Library/Application Support/KeyLens/counts.json  — スカラー合計値（旧形式、マイグレーション用に保持）
```

**Data… > Open Save Folder** でフォルダーを Finder で開けます。スキーマの詳細は [Architecture](Architecture.md) を参照してください。

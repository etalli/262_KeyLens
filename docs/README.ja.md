# KeyLens

[English](../README.md) | 日本語

<div align="center">

[![Website](https://img.shields.io/badge/公式サイト-Website-blue?style=for-the-badge&logo=google-chrome&logoColor=white)](https://etalli.github.io/262_KeyLens/landing-page/)
[![DMG をダウンロード](https://img.shields.io/badge/⬇_ダウンロード-DMG-blue?style=for-the-badge)](https://github.com/etalli/262_KeyLens/releases/latest)

![macOS](https://img.shields.io/badge/macOS-13%2B-brightgreen?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange?style=flat-square&logo=swift)
[![GitHub release](https://img.shields.io/github/v/release/etalli/262_KeyLens?style=flat-square&color=blue)](https://github.com/etalli/262_KeyLens/releases/latest)

**実際の打鍵データに基づき、キーボードレイアウトを最適化する。**

KeyLens は、あなたのタイピングの癖をローカルで分析し、あなたの入力パターンに最適化されたエルゴノミックな配列改善を提案する macOS ツールです。

[**サイトを見る**](https://etalli.github.io/262_KeyLens/landing-page/) - ビジュアルツアーと最適化エンジンの詳細を確認できます。

<table>
  <tr>
    <td><img src="../images/menu_v048.png" width="300"/></td>
    <td align="center"><i>メニューバー</i></td>
    <td><img src="../images/Heatmap.png" width="500"/></td>
    <td align="center"><i>ヒートマップ</i></td>
  </tr>
</table>

</div>

---

## 機能

- **グローバル記録** — アクティブなアプリに関係なく、すべてのキー入力をカウント
- **メニューバー統計** — 本日のカウント・累計・平均入力間隔を表示。表示項目のON/OFFと並び順をカスタマイズ可能
- **グラフ表示** — 4タブの分析ウィンドウ: Summary、Typing (Live・Activity・Keyboard・Shortcuts・Apps・Devices)、Mouse、Ergonomics (Tips・Bigrams・Layout・Fatigue・Optimizer・Compare)
- **キーストロークオーバーレイ** — ⌘C / ⇧A 形式で最近のキー入力をリアルタイム表示するフローティングウィンドウ

---

## クイックインストール

1. **[KeyLens.dmg](https://github.com/etalli/262_KeyLens/releases/latest)** (またはリリースベージの ZIP 版) をダウンロード
2. DMG を開き、**KeyLens.app** を `/Applications` にドラッグ
3. **重要 (セキュリティ警告の回避):** 初回起動時、macOS により「開発元を確認できないため開けません」という警告が表示されます。Terminal で以下のコマンドを実行してください：

   ```bash
   sudo xattr -rd com.apple.quarantine /Applications/KeyLens.app
   ```

   その後、Finder または Spotlight から通常どおり起動してください。
4. アプリを起動すると、**アクセシビリティ** 権限を求めるアラートが表示されます。
   - **「システム設定を開く」** をクリック → **プライバシーとセキュリティ > Accessibility** → **KeyLens** を有効化してください。
5. 任意のアプリに戻る — メニューバーにキーボードアイコンが表示され、モニタリングが開始されます。

> **注意:** このアプリは ad-hoc 署名を使用しているため、この手動での許可操作は初回のみ必要です。

---

## 使い方

### メニューバー

メニューバーのキーボードアイコン（⌨）をクリックしてパネルを開きます。

| 項目 | 説明 |
|------|------|
| **本日 / 累計** | 本日および全期間のキーストローク数 |
| **平均間隔** | キーストローク間の平均時間（ms） |
| **Top キー** | 最もよく押されたキーとカウント |
| **本日の最多アプリ** | 本日最も打鍵数の多かった最前面アプリケーション |
| **すべて表示** | すべてのキーとマウスボタンのランキングテーブルを表示 |
| **グラフ** | フル分析ウィンドウを開く |
| **オーバーレイ** | リアルタイムキーストロークオーバーレイの切り替え |
| **WPM ゲージ (フローティング)** | フローティング WPM スピードメーターパネルの切り替え。右クリックでサイズ変更 (小/中/大) |
| **設定…** | メニュー表示のカスタマイズ・言語・通知・Advanced Mode トグル・リセット・CSV 書き出し・バックアップ/リストア・ログフォルダを開く |

### グラフウィンドウ

メニューの **グラフ** から開きます。4つのトップタブ:

#### Summary タブ
| セクション | 表示内容 |
|-----------|---------|
| **アクティビティカレンダー** | 日別打鍵数の GitHub スタイルヒートマップ |
| **週次レポート** | 直近7日間と前7日間の比較 — トレンド矢印付き |
| **タイピングプロファイル** | タイピングスタイルと疲労リスクの推定 |
| **マウス vs キーボード** | マウスとキーボードの使用比率 |

#### Typing タブ
サブタブ: Live・Activity・Keyboard・Shortcuts・Apps・Devices

| サブタブ | 表示内容 |
|---------|---------|
| **Live** | 直近 IKI 棒グラフ・手動 WPM 計測・タイピングインテリジェンス |
| **Activity** | 日別 WPM・日別合計・IKI 分布・時間帯別分布・週次ヒートマップ |
| **Keyboard** | キーボードヒートマップ (頻度/負荷)・Top 20 キー・キー分類 |
| **Shortcuts** | ⌘ キーボードショートカット・全キーコンボ |
| **Apps** | アプリごとの打鍵数とエルゴノミクススコア |
| **Devices** | デバイスごとの打鍵数とエルゴノミクススコア |

#### Mouse タブ
サブタブ: Clicks・Direction・Distance・(Heatmap は Advanced Mode のみ)

| サブタブ | 表示内容 |
|---------|---------|
| **Clicks** | 左・中・右クリック数 |
| **Direction** | マウス移動方向の割合と日別内訳 |
| **Distance** | 日別マウス移動距離と時間帯別アクティビティ |
| **Heatmap** | マウス位置ヒートマップ (Advanced Mode のみ) |

#### Ergonomics タブ
サブタブ: Tips・Bigrams・Layout・Fatigue・Optimizer・Compare・(Training・Inspector は Advanced Mode のみ)

| サブタブ | 表示内容 |
|---------|---------|
| **Tips** | パーソナライズされたエルゴノミクス推奨 |
| **Bigrams** | Top バイグラム・指別 IKI・スロービグラム・バイグラム IKI ヒートマップ (Advanced Mode) |
| **Layout** | レイアウト効率・レイヤー効率・レイアウト比較 |
| **Fatigue** | 時間帯別疲労曲線・エルゴノミクス学習曲線 |
| **Optimizer** | キースワップシミュレーター |
| **Compare** | 2つのカスタム期間の並列比較 |
| **Training** | バイグラムタイピングドリルと履歴 (Advanced Mode のみ) |
| **Inspector** | リアルタイムキーイベント詳細 — キーコード・修飾キー・HID コード (Advanced Mode のみ) |

### AI による分析

キーストロークデータを書き出して AI アシスタントで分析することで、レイアウト最適化のアドバイスを受けることができます。

1. **設定… > データ > CSV 書き出し** から、キーストロークデータを CSV ファイルとして書き出します
2. **設定… > データ > AI プロンプトを編集** から、分析プロンプトを確認・カスタマイズします
3. 書き出された CSV の内容をコピーし、プロンプトと一緒に AI ツール（Claude、ChatGPT など）に貼り付けます

**プロンプトの例:**

```text
[組み込みのプロンプトを貼り付け]

以下は私のキーストロークデータです:
[CSV の内容を貼り付け]
```

デフォルトのプロンプトでは、AI に同一指率、交互打鍵率、バイグラム/トライグラムの頻度を計算させ、分割キーボードの親指キー割り当てなどを推奨させます。

---

### キーストロークオーバーレイ

<table>
  <tr>
    <td><img src="../images/keystroke_overlay_settings.png" width="280"/></td>
    <td><img src="../images/KeyStrokeOverlay-screenshot.png" width="400"/></td>
  </tr>
  <tr>
    <td align="center">設定</td>
    <td align="center">表示例</td>
  </tr>
</table>

メニューの **オーバーレイ** で切り替え。3 秒間操作がないと自動フェードアウトするフローティングウィンドウに最近のキー入力をリアルタイム表示します。歯車アイコン（⚙）から位置とサイズを設定できます。

---

## セキュリティ

| | 詳細 |
|---|---|
| **記録する** | キー名（例: `Space`, `e`）・マウスボタン名と押下回数のみ |
| **記録しない** | 入力テキスト・パスワード・クリップボードの内容・マウスカーソルの位置 |
| **保存先** | ローカル JSON ファイルのみ — ネットワーク送信なし |
| **イベントアクセス** | `.listenOnly` タップ — 読み取り専用、キー入力の改ざん・注入は不可 |

<details>
<summary>リスク一覧</summary>

| 項目 | リスク | 本アプリでの対策 |
|------|--------|----------------|
| グローバルキー監視 | 高（権限の性質上） | `.listenOnly` + `tailAppendEventTap` — 受動的リッスンのみ |
| データの内容 | 低 | キー名＋カウントのみ。入力文字列の再構築は不可能 |
| データファイル | 中 | 無暗号化。同一ユーザーの他プロセスが読める |
| ネットワーク | なし | 外部通信は一切なし |
| コード署名 | 中 | ad-hoc のみ。他ユーザーへの配布は Gatekeeper がブロック |

</details>

---

## データファイル

```
~/Library/Application Support/KeyLens/counts.json
```

**設定… > ログフォルダを開く** でフォルダを Finder で開けます。スキーマの詳細は [Architecture.md](Architecture.md) を参照。

---

## ソースからビルド

[Architecture — Build & Test](Architecture.md#build--test) を参照してください。

---

内部設計の詳細は [Architecture.md](Architecture.md) を参照してください。
開発ロードマップは [Roadmap.md](Roadmap.md) を参照してください。

フィードバック歓迎! バグ報告、機能要望、あるいは単純な質問など、何でも気軽に [Issue](https://github.com/etalli/262_KeyLens/issues) を立ててください。

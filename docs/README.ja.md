# KeyLens

[English](../README.md) | 日本語

<div align="center">

[![Website](https://img.shields.io/badge/公式サイト-Website-blue?style=for-the-badge&logo=google-chrome&logoColor=white)](https://etalli.github.io/262_KeyLens/landing-page/)
[![DMG をダウンロード](https://img.shields.io/badge/⬇_ダウンロード-DMG-blue?style=for-the-badge)](https://github.com/etalli/262_KeyLens/releases/latest)

![macOS](https://img.shields.io/badge/macOS-13%2B-brightgreen?style=flat-square&logo=apple)
[![GitHub release](https://img.shields.io/github/v/release/etalli/262_KeyLens?style=flat-square&color=blue)](https://github.com/etalli/262_KeyLens/releases/latest)

KeyLens は、キーストロークをローカルで記録し、実際の使用状況に基づいてエルゴノミックなレイアウト改善を提案する macOS メニューバーアプリです。

KeyLens が保存するのはキー名とカウントのみで、実際に入力した文字は一切記録しません。パスワードや機密情報は完全に安全です。

[**ドキュメント**](https://etalli.github.io/262_KeyLens/landing-page/) — スクリーンショットとレイアウト最適化のウォークスルー

<table>
  <tr>
    <td><img src="images/menu.png" width="300"/></td>
    <td align="center"><i>メニューバー</i></td>
    <td><img src="images/Heatmap.png" width="450"/></td>
    <td align="center"><i>ヒートマップ</i></td>
  </tr>
</table>

</div>

---

## なぜ KeyLens?

キーボードのエルゴノミクスに関するアドバイスはたいてい一般論です。「Colemak を使え」「小指を使うな」「分割キーボードにしろ」。
どれも*あなた自身*の実際のタイピングパターンに基づいていません。

KeyLens はどのキーをどれだけ、どの指で押しているかを記録し、本当の負担がどこにあるかを教えてくれます。左小指が右小指の 3 倍の仕事をしているかもしれません。ある 2 キーの組み合わせが同指連打の半分を占めているかもしれません。測定できなければ改善できません。

目的は、Colemak に闇雲に移行するのではなく、実際に効果のある具体的なレイアウト変更を 1 つ行うためのデータを提供することです。

---

## 機能

- **グローバル記録** — どのアプリでもキーストロークをカウント
- **メニューバー統計** — 本日のカウント・平均入力間隔・エルゴノミクス推奨などを表示。表示項目の ON/OFF と並び順をカスタマイズ可能
- **グラフ** — 4 タブの分析ウィンドウ: Summary、Typing (Live・Activity・Keyboard・Shortcuts・Apps・Devices)、Mouse、Ergonomics (Tips・Bigrams・Layout・Fatigue・Optimizer・Compare)
- **週次サマリーカード** — 毎週土曜日に週間統計の PNG を生成。データメニューからいつでも出力可能
- **キーストロークオーバーレイ** — 最近のキー入力をリアルタイム表示するフローティングウィンドウ (⌘C / ⇧A 形式)

---

## クイックインストール

1. **[KeyLens.dmg](https://github.com/etalli/262_KeyLens/releases/latest)** (またはリリースページの ZIP 版) をダウンロード
2. DMG を開き、**KeyLens.app** を `/Applications` にドラッグ
3. **重要 (セキュリティ警告の回避):** 初回起動時、macOS により「開発元を確認できないため開けません」という警告が表示されます。Terminal で以下を実行してください:

   ```bash
   sudo xattr -rd com.apple.quarantine /Applications/KeyLens.app
   ```

   その後、Finder または Spotlight から通常どおり起動してください。
4. **アクセシビリティ**権限を求めるアラートが表示されます。
   - **「システム設定を開く」** → **プライバシーとセキュリティ > Accessibility** → **KeyLens** を有効化してください。
5. 任意のアプリに戻ると、メニューバーにキーボードアイコンが表示され、モニタリングが開始されます。

---

## 使い方

メニューバーの項目、グラフウィンドウのタブ、AI 分析、キーストロークオーバーレイの詳細は [HOWTOUSE](HOWTOUSE.md) を参照してください。

---

## セキュリティ

KeyLens が記録するのはキー名 (例: `Space`, `e`) とマウスボタン名およびその押下回数のみです。入力テキスト・パスワード・クリップボードの内容・カーソル位置は**記録しません**。データはローカルの SQLite データベース (`keylens.db`) にのみ保存され、ネットワーク送信は一切ありません。イベント監視には `.listenOnly` タップを使用しており、読み取り専用でキー入力の注入・改ざんはできません。

---

内部設計の詳細は [Architecture](Architecture.md) を参照してください。
ビルド手順は [HowToBuild](HowToBuild.md) を参照してください。
開発ロードマップは [Roadmap](Roadmap.md) を参照してください。
バグ報告・機能要望は [Issue](https://github.com/etalli/262_KeyLens/issues) からどうぞ。

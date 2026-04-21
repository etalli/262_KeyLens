# KeyLens

[English](../README.md) | 日本語

<div align="center">

![macOS](https://img.shields.io/badge/macOS-13%2B-brightgreen?style=flat-square&logo=apple)
[![GitHub release](https://img.shields.io/github/v/release/etalli/262_KeyLens?style=flat-square&color=blue)](https://github.com/etalli/262_KeyLens/releases/latest)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue?style=flat-square)](../LICENSE)
[![Hypercommit](https://img.shields.io/badge/Hypercommit-DB2475)](https://hypercommit.com/262-keylens)

KeyLens は、押したキーを記録し、実際のタイピングデータに基づいてレイアウト改善を提案する macOS メニューバーアプリです。保存するのはキー名とカウントのみで、実際に入力した文字は一切記録しません。パスワードは安全です。

[**実際の動きを見る**](https://etalli.github.io/262_KeyLens/landing-page/) — スクリーンショットとレイアウト最適化のウォークスルー

<table>
  <tr>
    <td align="center"><img src="images/menu.png" width="300"/><br><i>メニューバー</i></td>
    <td align="center"><img src="images/Keyboard Heatmap.png" width="450"/><br><i>ヒートマップ</i></td>
  </tr>
</table>

</div>

---

## なぜ KeyLens?

キーボードのエルゴノミクスに関するアドバイスは一般論が多いです。「Colemak を使おう」「小指への負担を減らそう」「分割キーボードを試してみよう」。参考にはなりますが、*あなた自身*のタイピングパターンに基づいたものではありません。

KeyLens はそこを変えます。どのキーをどれだけの頻度で、どの指で押しているかを記録し、負荷の真の原因を明らかにします。左小指が右小指の倍の仕事をしているかもしれません。あるキーペアが同指連打の大半を占めているかもしれません。文字キーだけでなく、モディファイアキーやナビゲーションキーも対象です。

---

## KeyLens でできること

- どの指が酷使されているか、両手への負荷配分を確認できます
- 実際のタイピングデータを使って、Colemak・Dvorak・カスタムレイアウトに切り替えた場合の移動距離をシミュレーションできます
- WPM・キーストロークのリズム・疲労傾向を日単位・週単位で記録できます
- アプリ別にキーストロークを確認できます — どこから改善すべきかの判断に役立ちます
- よく使うショートカットと、モディファイア配置が手への負担を生んでいないかを確認できます
- 1 日のカーソル移動距離をキーボードデータと並べて把握できます
- フローティングオーバーレイで直前の入力をリアルタイム表示。新しいレイアウトの習得に役立ちます

---

## クイックインストール

1. **[KeyLens.dmg](https://github.com/etalli/262_KeyLens/releases/latest)** (またはリリースページの ZIP 版) をダウンロード
2. **KeyLens.app** を `/Applications` にドラッグ
3. 初回起動時、macOS が署名のないアプリとしてブロックします。Terminal で以下を実行してください:

   ```bash
   sudo xattr -rd com.apple.quarantine /Applications/KeyLens.app
   ```

   その後、Finder または Spotlight から起動してください。
4. アクセシビリティ権限を求めるアラートが表示されます。**システム設定 → プライバシーとセキュリティ → アクセシビリティ** で KeyLens を有効にしてください。
5. 任意のアプリに切り替えると、メニューバーにキーボードアイコンが表示されます。

---

## ドキュメント

- [HowToUse](HowToUse.ja.md) — 使い方ガイド
- [Architecture](Architecture.md) — 内部設計とセキュリティモデル
- [HowToBuild](HowToBuild.md) — ビルド・テスト・ログ
- [Roadmap](Roadmap.md) — 開発ロードマップ
- [Issues](https://github.com/etalli/262_KeyLens/issues) — バグ報告・機能要望

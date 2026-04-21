# KeyLens

[English](../README.md) | 日本語

<div align="center">

![macOS](https://img.shields.io/badge/macOS-13%2B-brightgreen?style=flat-square&logo=apple)
[![GitHub release](https://img.shields.io/github/v/release/etalli/262_KeyLens?style=flat-square&color=blue)](https://github.com/etalli/262_KeyLens/releases/latest)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue?style=flat-square)](../LICENSE)
[![Hypercommit](https://img.shields.io/badge/Hypercommit-DB2475)](https://hypercommit.com/262-keylens)

KeyLens は、キーストロークをローカルで記録し、実際のタイピングパターンに基づいて人間工学的なレイアウト改善を提案する macOS メニューバーアプリです。

保存するのはキー名とカウントのみで、実際に入力した文字は一切記録しません。パスワードや機密情報は完全に保護されます。

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

キーボードの人間工学は、姿勢・レイアウト・タイピング習慣の最適化に集約されます。基本的な目標は「手首をニュートラルに保つ」「指の移動距離を減らす」「負荷を効率よく分散させる」の 3 つです。

しかし、多くのアドバイスは一般論にとどまっています。「Colemak を使おう」「小指への負担を減らそう」「分割キーボードを試してみよう」「親指をレイヤー切り替えに活用しよう」。こうした提案は参考にはなりますが、*あなた自身*の実際のタイピングパターンに基づいたものではありません。

KeyLens はそこを変えます。どのキーをどれだけの頻度で、どの指で押しているかを記録し、負荷の真の原因を明らかにします。左小指が右小指より大幅に多くの仕事を担っているかもしれません。あるキーペアが同指連打の大半を占めているかもしれません。

目的は、レイアウト選択の根拠となるデータを提供することです。最適化の対象は文字キーだけではありません。ショートカットの観点では、モディファイアキーやナビゲーションキーも同じくらい重要です。

---

## KeyLens でできること

- **負荷の原因を特定する** — どの指が酷使されているか、どのキーペアが同指連打を引き起こしているか、両手への負荷配分をひと目で把握できます。
- **レイアウト変更を試してから決断する** — 実際のタイピングデータを使って、Colemak・Dvorak・カスタムレイアウトに切り替えた場合の移動距離と指の負荷をシミュレーションできます。
- **タイピングの変化を記録する** — WPM・キーストロークのリズム・疲労傾向を日単位・週単位で記録し、習慣が改善しているかを客観的に確認できます。
- **アプリ別のタイピングを把握する** — どのアプリでキーストロークや負荷が最も多いかを確認し、改善の優先順位を判断できます。
- **ショートカットとモディファイアの使用状況を分析する** — よく使うキー組み合わせと、モディファイア配置が手への負担を生んでいないかを確認できます。
- **マウスの移動距離をキーストロークと合わせて記録する** — 1 日のカーソル移動距離と、キーボード操作との比率を把握できます。
- **キーストロークをリアルタイムで確認する** — フローティングオーバーレイで直前の入力をその場に表示。新しいレイアウトやショートカットの習得に役立ちます。

---

## クイックインストール

1. **[KeyLens.dmg](https://github.com/etalli/262_KeyLens/releases/latest)** (またはリリースページの ZIP 版) をダウンロード
2. DMG を開き、**KeyLens.app** を `/Applications` にドラッグ
3. **セキュリティ設定について:** 初回起動時、macOS が「開発元を確認できないアプリ」としてブロックします。Terminal で以下を実行してください:

   ```bash
   sudo xattr -rd com.apple.quarantine /Applications/KeyLens.app
   ```

   その後、Finder または Spotlight から通常どおり起動してください。
4. **アクセシビリティ**権限を求めるアラートが表示されます。
   - **「システム設定を開く」** → **プライバシーとセキュリティ > アクセシビリティ** → **KeyLens** を有効にしてください。
5. 任意のアプリに切り替えると、メニューバーにキーボードアイコンが表示され、記録が開始されます。

---

## ドキュメント

- [HowToUse](HowToUse.ja.md) — 使い方ガイド
- [Architecture](Architecture.md) — 内部設計とセキュリティモデル
- [HowToBuild](HowToBuild.md) — ビルド・テスト・ログ
- [Roadmap](Roadmap.md) — 開発ロードマップ
- [Issues](https://github.com/etalli/262_KeyLens/issues) — バグ報告・機能要望

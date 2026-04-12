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
    <td align="center"><img src="images/menu.png" width="300"/><br><i>メニューバー</i></td>
    <td align="center"><img src="images/Keyboard Heatmap.png" width="450"/><br><i>ヒートマップ</i></td>
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

## KeyLens でできること

- **本当の負担箇所を特定する** — どの指が酷使されているか、どのキーペアが同指連打を引き起こしているか、両手への負荷配分をひと目で確認できます。
- **レイアウト変更を試してから決断する** — 実際のタイピングデータを使って、Colemak・Dvorak・カスタムレイアウトへ切り替えた場合の移動距離と指の負荷をシミュレーションできます。
- **タイピングの変化を追跡する** — WPM・キーストロークのリズム・疲労曲線を日単位・週単位で記録し、習慣が改善されているかを確認できます。
- **アプリ別にタイピングを分析する** — どのアプリが最もキーストロークと負荷を生んでいるかを把握し、エルゴノミクス改善の優先度を判断できます。
- **キー入力をリアルタイムで確認する** — フローティングオーバーレイが直前の入力を表示するため、新しいレイアウトやショートカットの習得に役立ちます。

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

内部設計の詳細 (セキュリティモデルを含む) は [Architecture](Architecture.md) を参照してください。
ビルド手順は [HowToBuild](HowToBuild.md) を参照してください。
開発ロードマップは [Roadmap](Roadmap.md) を参照してください。
バグ報告・機能要望は [Issue](https://github.com/etalli/262_KeyLens/issues) からどうぞ。

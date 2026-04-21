# KeyLens

English | [日本語](docs/README.ja.md)

<div align="center">

![macOS](https://img.shields.io/badge/macOS-13%2B-brightgreen?style=flat-square&logo=apple)
[![GitHub release](https://img.shields.io/github/v/release/etalli/262_KeyLens?style=flat-square&color=blue)](https://github.com/etalli/262_KeyLens/releases/latest)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue?style=flat-square)](LICENSE)
[![Hypercommit](https://img.shields.io/badge/Hypercommit-DB2475)](https://hypercommit.com/262-keylens)

KeyLens is a macOS menu bar app that records which keys you press and suggests layout changes based on how you actually type. It stores only key names and counts — never the characters themselves. Passwords are safe.

[**See it in action**](https://etalli.github.io/262_KeyLens/landing-page/) — screenshots and layout optimization walkthrough

<table>
  <tr>
    <td align="center"><img src="docs/images/menu.png" width="300"/><br><i>Menu Bar</i></td>
    <td align="center"><img src="docs/images/Keyboard Heatmap.png" width="450"/><br><i>Heatmap</i></td>
  </tr>
</table>

</div>

---

## Why KeyLens?

Most ergonomic keyboard advice is generic: use Colemak, avoid pinkies, get a split keyboard. It can help, but none of it is based on how *you* type.

KeyLens changes that. It records which keys you press, how often, and with which fingers, so you can see where the strain actually comes from. You might find your left pinky does twice the work of your right, or that one key pair is responsible for most of your same-finger hits. Modifier and navigation keys count too, not just letters.

---

## What KeyLens can do

- See which fingers are overloaded and how the load is distributed across both hands
- Simulate how Colemak, Dvorak, or a custom layout would affect your travel distance, using your actual data
- Track WPM, keystroke rhythm, and fatigue over days and weeks
- Break down keystrokes by app — useful for knowing where to focus changes first
- See which shortcuts you use most and whether your modifier placement is costing you
- Track daily cursor distance alongside your keyboard data
- A floating overlay shows your last few keystrokes live, useful for learning a new layout

---

## Quick install

1. Download **[KeyLens.dmg](https://github.com/etalli/262_KeyLens/releases/latest)** (or the ZIP from the release page)
2. Drag **KeyLens.app** to `/Applications`
3. macOS will block the app on first launch because it's unsigned. Run this in Terminal:

   ```bash
   sudo xattr -rd com.apple.quarantine /Applications/KeyLens.app
   ```

   Then open it from Finder or Spotlight.
4. An Accessibility permission prompt will appear. Go to **System Settings → Privacy & Security → Accessibility** and enable KeyLens.
5. Switch to any app and the keyboard icon shows up in your menu bar.

---

## Docs

- [HowToUse](docs/HowToUse.md) — usage guide
- [Architecture](docs/Architecture.md) — internal design and security model
- [HowToBuild](docs/HowToBuild.md) — build, test, and logs
- [Roadmap](docs/Roadmap.md) — development roadmap
- [Issues](https://github.com/etalli/262_KeyLens/issues) — bug reports and feature requests

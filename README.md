# KeyLens

English | [日本語](docs/README.ja.md)

<div align="center">

[![Website](https://img.shields.io/badge/Official-Website-blue?style=for-the-badge&logo=google-chrome&logoColor=white)](https://etalli.github.io/262_KeyLens/landing-page/index.html)
[![Download DMG](https://img.shields.io/badge/⬇_Download-DMG-blue?style=for-the-badge)](https://github.com/etalli/262_KeyLens/releases/latest)

![macOS](https://img.shields.io/badge/macOS-13%2B-brightgreen?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange?style=flat-square&logo=swift)
[![GitHub release](https://img.shields.io/github/v/release/etalli/262_KeyLens?style=flat-square&color=blue)](https://github.com/etalli/262_KeyLens/releases/latest)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue?style=flat-square)](LICENSE)
[![Hypercommit](https://img.shields.io/badge/Hypercommit-DB2475)](https://hypercommit.com/262-keylens)

KeyLens is a macOS menu bar app that tracks your keystrokes locally and recommends ergonomic layout changes based on your actual usage.

The stored data is key names and counts only — your actual typed content cannot be reconstructed from it.


[**Document**](https://etalli.github.io/262_KeyLens/landing-page/) — screenshots and layout optimization walkthrough

<table>
  <tr>
    <td><img src="docs/images/menu.png" width="300"/></td>
    <td align="center"><i>Menu Bar</i></td>
    <td><img src="docs/images/Heatmap.png" width="500"/></td>
    <td align="center"><i>Heatmap</i></td>
  </tr>
</table>

</div>

---

## Why KeyLens?

Most keyboard ergonomics advice is generic: "use Colemak", "avoid pinkies", "get a split keyboard".
None of it is based on *your* actual typing patterns.

KeyLens records which keys you press, how often, and with which fingers — then tells you where
your real strain comes from. Maybe your left pinky is doing 3× the work of your right.
Maybe one two-key combination accounts for half your same-finger strain. You can't fix what you can't measure.

The goal is to give you the data to make one concrete layout change that actually helps,
rather than switching to Colemak blindly and hoping for the best.

---

## Features

- **Global recording** — Counts keystrokes in any app, no exceptions
- **Menu bar statistics** — Today's count, all-time total, average keystroke interval, ergonomic recommendations, and more; toggle and reorder these widgets as you like
- **Charts** — 4-tab analytics window: Summary, Typing (Live, Activity, Keyboard, Shortcuts, Apps, Devices), Mouse, and Ergonomics (Tips, Bigrams, Layout, Fatigue, Optimizer, Compare)
- **Weekly Summary Card** — Generates a PNG of your weekly stats every Saturday; also available any time from the Data menu
- **Keystroke Overlay** — Floating window showing recent keystrokes in real time (⌘C / ⇧A style)

---

## Quick Install

1. Download **[KeyLens.dmg](https://github.com/etalli/262_KeyLens/releases/latest)** (or the ZIP from the release page)
2. Open the DMG and drag **KeyLens.app** to `/Applications`
3. **Important (Security):** On first launch, macOS will block the app as it is from an "unidentified developer". Run this in Terminal:

   ```bash
   sudo xattr -rd com.apple.quarantine /Applications/KeyLens.app
   ```

   Then launch normally from Finder or Spotlight.
4. An alert will ask for **Accessibility** permission.
   - Click **Open System Settings** → **Privacy & Security > Accessibility** → enable **KeyLens**.
5. Switch to any app — the keyboard icon appears in your menu bar and monitoring starts.

> **Note:** The app uses an ad-hoc signature. This manual override is required only once.

---

## How to Use

See [docs/HOWTOUSE.md](docs/HOWTOUSE.md) for the full usage guide — menu bar items, Charts window tabs, AI Analysis, and the Keystroke Overlay.

---

## Security

KeyLens records only key names (e.g. `Space`, `e`) and mouse button names with press counts. It does **not** record typed text, sequences, passwords, clipboard content, or cursor position. All data is stored in a local SQLite database (`keylens.db`) — no network transmission occurs. Event monitoring uses a `.listenOnly` tap, which is read-only and cannot inject or modify keystrokes.

---

## Build from Source

See [docs/HowToBuild.md](docs/HowToBuild.md) for prerequisites, build commands, test setup, and logs.

---

For internal design details, see [Architecture](docs/Architecture.md).
For the development roadmap, see [Roadmap](docs/Roadmap.md).
Bug reports and feature requests: open an [issue](https://github.com/etalli/262_KeyLens/issues).

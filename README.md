# KeyLens

English | [日本語](docs/README.ja.md)

<div align="center">

![macOS](https://img.shields.io/badge/macOS-13%2B-brightgreen?style=flat-square&logo=apple)
[![GitHub release](https://img.shields.io/github/v/release/etalli/262_KeyLens?style=flat-square&color=blue)](https://github.com/etalli/262_KeyLens/releases/latest)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue?style=flat-square)](LICENSE)
[![Hypercommit](https://img.shields.io/badge/Hypercommit-DB2475)](https://hypercommit.com/262-keylens)

KeyLens is a macOS menu bar app that tracks your keystrokes locally and recommends ergonomic layout changes based on your actual usage.

KeyLens stores only key names and counts — never the actual characters you type. Passwords and sensitive input are completely safe.


[**Document**](https://etalli.github.io/262_KeyLens/landing-page/) — screenshots and layout optimization walkthrough

<table>
  <tr>
    <td align="center"><img src="docs/images/menu.png" width="300"/><br><i>Menu Bar</i></td>
    <td align="center"><img src="docs/images/Keyboard Heatmap.png" width="450"/><br><i>Heatmap</i></td>
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
Keyboard shortcuts matter as much as letter keys — you can't optimize your layout without being able to swap modifier and navigation keys.

---

## What KeyLens Can Do

- **Find where your strain actually comes from** — See which fingers are overloaded, which key pairs cause same-finger strain, and how your workload is distributed across your hands.
- **Simulate layout changes before you commit** — Compare how Colemak, Dvorak, or a custom layout would change your travel distance and finger load, based on your real typing data.
- **Track how your typing evolves** — Monitor your WPM, keystroke rhythm, and fatigue curve over days and weeks to see if your habits are improving.
- **See your typing broken down by app** — Know which apps drive the most keystrokes and strain, so you can focus ergonomic changes where they matter most.
- **Watch your keystrokes in real time** — A floating overlay shows what you just typed, useful for learning new layouts or shortcuts.

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

---

## How to Use

See [HowToUse](docs/HowToUse.md) for the full usage guide — menu bar items, Charts window tabs, AI Analysis, and the Keystroke Overlay.

---

For internal design details (including security model), see [Architecture](docs/Architecture.md).
See [HowToBuild](docs/HowToBuild.md) for prerequisites, build commands, test setup, and logs.
For the development roadmap, see [Roadmap](docs/Roadmap.md).
Bug reports and feature requests: open an [issue](https://github.com/etalli/262_KeyLens/issues).

# KeyLens

English | [日本語](docs/README.ja.md)

<div align="center">

![macOS](https://img.shields.io/badge/macOS-13%2B-brightgreen?style=flat-square&logo=apple)
[![GitHub release](https://img.shields.io/github/v/release/etalli/262_KeyLens?style=flat-square&color=blue)](https://github.com/etalli/262_KeyLens/releases/latest)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue?style=flat-square)](LICENSE)
[![Hypercommit](https://img.shields.io/badge/Hypercommit-DB2475)](https://hypercommit.com/262-keylens)

KeyLens is a macOS menu bar app that tracks your keystrokes and recommends ergonomic layout changes based on your actual usage.

KeyLens stores only key names and counts locally — never the actual characters you type. Passwords and sensitive input are completely safe.


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


Ergonomic keyboard advice usually comes down to optimizing posture, layout, and typing behavior. The core goals are: keep wrists neutral, minimize finger travel, and distribute the load efficiently.

Most advice, however, is generic: "use Colemak", "avoid pinkies", "get a split keyboard", "use thumbs for layers". These recommendations can help, but they aren't based on how you actually type.

KeyLens changes that.  It records which keys you press, how often, and with which fingers you use, so you can see where your strain really comes from. For example, you might discover your left pinky does significantly more work than your right, or that a specific key pair dominates your same-finger usage.

The goal is to provide real data to guide your layout decisions. And it's not just about letter keys---modifier and navigation keys matter just as much, especially when it  comes to shortcuts.

---

## What KeyLens Can Do

- **Find where your strain comes from** — See which fingers are overloaded, which key pairs cause same-finger strain, and how your workload is distributed across your hands.
- **Simulate layout changes before you commit** — Compare how Colemak, Dvorak, or a custom layout would affect your travel distance and finger load, using your real typing data.
- **Track how your typing evolves** — Monitor WPM, keystroke rhythm, and fatigue over days and weeks to see if your habits are improving.
- **See your typing broken down by app** — Know which apps drive the most keystrokes and ergonomic strain, so you can focus changes where they matter most.
- **Analyze shortcuts and modifier usage** — See which key combinations you use most and whether your modifier layout is causing hand strain.
- **Track mouse movement alongside keystrokes** — See daily cursor distance and how your mouse usage compares to your keyboard load.
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

## Docs

- [HowToUse](docs/HowToUse.md) — usage guide
- [Architecture](docs/Architecture.md) — internal design and security model
- [HowToBuild](docs/HowToBuild.md) — build, test, and logs
- [Roadmap](docs/Roadmap.md) — development roadmap
- [Issues](https://github.com/etalli/262_KeyLens/issues) — bug reports and feature requests

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

<video src="https://github.com/etalli/262_KeyLens/raw/main/docs/images/KeyLens-Speedometer.mp4" controls width="600"></video>

</div>

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

### Menu bar

Click the keyboard icon (⌨) in the menu bar to open the panel.

| Item | Description |
|------|-------------|
| **Today / Total** | Keystroke count for today and all time |
| **Avg interval** | Running average time between keystrokes (ms) |
| **Top keys** | Most-pressed keys with counts |
| **Top app today** | Frontmost application with the most keystrokes today |
| **Show All** | Opens a ranked table of every key and mouse button |
| **Charts** | Opens the full analytics window |
| **Overlay** | Toggles the real-time keystroke overlay (also: global hotkey ⌃⌥O, configurable) |
| **WPM Gauge (floating)** | Toggles a floating analog WPM speedometer panel; right-click to set size (Small / Medium / Large) |
| **Settings…** | Customize menu display, language, notifications, Advanced Mode toggle, reset, export CSV, export weekly summary card (PNG), export Year in Review card (PNG), backup/restore data, open log folder |

### Charts window

Open via **Charts** in the menu. Four top-level tabs:

#### Summary tab
| Section | What it shows |
|---------|---------------|
| **Activity Calendar** | GitHub-style heatmap of daily keystroke activity |
| **Weekly Report** | Last 7 days vs prior 7 days with trend arrows |
| **Typing Profile** | Inferred typing style and fatigue risk level |
| **Mouse vs Keyboard Balance** | Daily ratio of mouse vs keyboard usage |

#### Typing tab
Sub-tabs: Live · Activity · Keyboard · Shortcuts · Apps · Devices

| Sub-tab | What it shows |
|---------|---------------|
| **Live** | Recent IKI bar chart, manual WPM measurement, typing intelligence |
| **Activity** | Daily WPM, daily totals, IKI distribution, hourly distribution, weekly heatmap |
| **Keyboard** | Keyboard heatmap (frequency / strain), top 20 keys, key categories |
| **Shortcuts** | Top ⌘ keyboard shortcuts, all keyboard combos |
| **Apps** | Keystroke counts and ergonomic scores per application |
| **Devices** | Keystroke counts and ergonomic scores per device |

#### Mouse tab
Sub-tabs: Clicks · Direction · Distance · (Heatmap in Advanced Mode)

| Sub-tab | What it shows |
|---------|---------------|
| **Clicks** | Left, middle, and right button click counts |
| **Direction** | Proportion and per-day breakdown of mouse movement direction |
| **Distance** | Daily mouse travel distance and hourly activity |
| **Heatmap** | Mouse position heatmap (Advanced Mode only) |

#### Ergonomics tab
Sub-tabs: Tips · Bigrams · Layout · Fatigue · Optimizer · Compare · (Training · Inspector in Advanced Mode)

| Sub-tab | What it shows |
|---------|---------------|
| **Tips** | Personalised ergonomic recommendations |
| **Bigrams** | Top bigrams, finger IKI, slow bigrams, bigram IKI heatmap (Advanced Mode) |
| **Layout** | Layout efficiency, layer efficiency, layout comparison |
| **Fatigue** | Hourly fatigue curve, ergonomic learning curve |
| **Optimizer** | Key swap simulator for layout improvement |
| **Compare** | Side-by-side stats for two custom date ranges |
| **Training** | Bigram typing drills and history (Advanced Mode only) |
| **Inspector** | Real-time key event details — keycode, modifiers, HID codes (Advanced Mode only) |

### AI Analysis

Export your keystroke data (Settings… > Data > Export CSV) and paste it into an AI tool (Claude, ChatGPT, etc.) along with the built-in prompt (Settings… > Data > Edit AI Prompt) for layout optimization advice.

---

### Keystroke Overlay

<table>
  <tr>
    <td><img src="docs/images/keystroke_overlay_settings.png" width="280"/></td>
    <td><img src="docs/images/KeyStrokeOverlay-screenshot.png" width="400"/></td>
  </tr>
  <tr>
    <td align="center">Setting</td>
    <td align="center">Example</td>
  </tr>
</table>
</div>

Toggle via **Overlay** in the menu, or press **⌃⌥O** from anywhere. It shows recent keystrokes in a floating window that fades after 3 seconds. Position, size, and hotkey are all configurable via ⚙.

---

## Security

| | Details |
|---|---|
| **Records** | Key names (e.g. `Space`, `e`) and mouse button names with press counts only |
| **Does NOT record** | Typed text, sequences, passwords, clipboard content, or cursor position |
| **Storage** | Local JSON file only — no network transmission |
| **Event access** | `.listenOnly` tap — read-only, cannot inject or modify keystrokes |

<details>
<summary>Full risk summary</summary>

| Area | Risk | Mitigation |
|------|------|------------|
| Global key monitoring | High (by nature) | `.listenOnly` + `tailAppendEventTap` — passive only |
| Data content | Low | Key name + count only; typed text cannot be reconstructed |
| Data file | Medium | Unencrypted; readable by any process running as the same user |
| Network | None | No outbound connections |
| Code signing | Medium | Ad-hoc only; Gatekeeper blocks distribution to other users |

</details>

---

## Data file

```
~/Library/Application Support/KeyLens/counts.json
```

Use **Settings… > Open Log Folder** to open the directory in Finder. See [Architecture](docs/Architecture.md) for the schema.

---

## Build from Source

See [docs/HowToBuild.md](docs/HowToBuild.md) for prerequisites, build commands, test setup, and logs.

---

For internal design details, see [Architecture](docs/Architecture.md).
For the development roadmap, see [Roadmap](docs/Roadmap.md).
Bug reports and feature requests: open an [issue](https://github.com/etalli/262_KeyLens/issues).

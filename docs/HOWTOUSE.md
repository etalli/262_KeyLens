# How to Use KeyLens

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
    <td><img src="images/keystroke_overlay_settings.png" width="280"/></td>
    <td><img src="images/KeyStrokeOverlay-screenshot.png" width="400"/></td>
  </tr>
  <tr>
    <td align="center">Setting</td>
    <td align="center">Example</td>
  </tr>
</table>

Toggle via **Overlay** in the menu, or press **⌃⌥O** from anywhere. It shows recent keystrokes in a floating window that fades after 3 seconds. Position, size, and hotkey are all configurable via ⚙.

---

## Data file

```
~/Library/Application Support/KeyLens/counts.json
```

Use **Settings… > Open Log Folder** to open the directory in Finder. See [Architecture](Architecture.md) for the schema.

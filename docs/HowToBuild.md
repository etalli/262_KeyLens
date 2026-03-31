# Build from Source

## Prerequisites

| Requirement | Version |
|---|---|
| macOS | 13 Ventura or later |
| Xcode | 15 or later (full Xcode — not just Command Line Tools) |
| Swift | 5.9+ (bundled with Xcode) |

## Steps

```bash
git clone https://github.com/etalli/262_KeyLens.git
cd 262_KeyLens
./build.sh --install
```

`--install` builds the app, copies it to `/Applications`, applies an ad-hoc codesign, resets the Accessibility TCC entry, and launches the app.

> **Always use `build.sh`** — `swift build` alone does not produce a working app bundle (the notification extension is missing).

| Command | What it does |
|---|---|
| `./build.sh` | Build only |
| `./build.sh --run` | Build and launch |
| `./build.sh --install` | Build, install, sign, reset TCC, launch ← recommended |
| `./build.sh --dmg` | Build distributable DMG |

## First-launch permissions

On first launch, macOS will prompt for **Accessibility** permission (required to capture keystrokes). Go to **System Settings > Privacy & Security > Accessibility** and enable KeyLens.

## Run tests

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

If you see `no such module 'XCTest'`, the Command Line Tools are active instead of the full Xcode toolchain:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Logs

```bash
tail -f ~/Library/Logs/KeyLens/app.log
```

## Performance baseline runbook (Issue #287)

### 1) Enable profiling (opt-in)

Profiling is disabled by default. Enable it only when measuring:

```bash
defaults write com.example.KeyLens perfProfilingEnabled -bool true
```

Restart KeyLens after changing this setting.

### 2) Capture baseline scenarios

Run these scenarios on a typical macOS 13+ machine:

1. **Idle**: leave KeyLens running in the menu bar for 3-5 minutes.
2. **Typing**: type normally for 3-5 minutes in a real app.
3. **Charts open**: open Charts and wait until initial data loading settles.
4. **Charts interaction**: switch tabs and scroll for ~1-2 minutes, including heavy views (heatmaps/activity grids).

### 3) Collect measurement data

- Use Instruments:
  - **Time Profiler** for CPU hot spots
  - **Allocations** for RSS growth
- Read app logs for aggregated metrics:
  - `event.handle.total`
  - `store.increment`
  - `store.snapshot.capture`
  - `store.snapshot.sqliteWrite`
  - `charts.reload.query`
  - `charts.reload.publish`
  - `charts.reload.total`
  - `charts.window.open`
  - `charts.mainThread.timerDrift` (stutter proxy)

### 4) Initial budgets (informal)

- Menu bar idle CPU: low single digits
- Typing hot path: keep per-event handling under ~1 ms on average; investigate if p95 grows toward multi-ms
- Charts window open (initial load): ~300-500 ms target on a typical machine
- Memory: stable in long sessions (roughly tens of MB for menu bar usage, not unbounded growth)

### 5) Disable profiling after measurement

```bash
defaults delete com.example.KeyLens perfProfilingEnabled
```

Restart KeyLens.

For full internal design details, see [Architecture — Build & Test](Architecture.md#build--test).

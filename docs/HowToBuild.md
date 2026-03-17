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

For full internal design details, see [Architecture — Build & Test](Architecture.md#build--test).

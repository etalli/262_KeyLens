# KeyCounter

A macOS menu bar app that monitors and records global keyboard input.
Counts keystrokes per key, persists the data to a JSON file, and sends a macOS notification every 1,000 presses.

---

## Features

- **Global monitoring**: Counts all keystrokes regardless of the active application
- **Menu bar statistics**: Click the `KC` label to see the top 10 most-pressed keys
- **Persistence**: Counts survive reboots — stored in a JSON file
- **Milestone notifications**: Native macOS notification at every 1,000 presses per key (1000, 2000, ...)

---

## Requirements

| Item | Requirement |
|------|-------------|
| macOS | 13 Ventura or later |
| Swift | 5.9 or later (bundled with Xcode 15) |
| Permission | Accessibility (prompted on first launch) |

---

## Build

```bash
# Build App Bundle
./build.sh

# Build and launch immediately
./build.sh --run

# Build and create a distributable DMG
./build.sh --dmg
```

> Running `swift build` alone produces the executable but notifications require a proper App Bundle, so use `build.sh`.

### What the build script does

```
swift build -c release
  └─ .build/release/KeyCounter   (executable)

KeyCounter.app/
  ├── Contents/MacOS/KeyCounter   <- executable copied here
  └── Contents/Info.plist         <- LSUIElement=true hides the Dock icon
```

---

## Accessibility Permission (first launch)

An alert is shown on first launch if the permission is missing.

1. Click **Open System Settings**
2. Go to **Privacy & Security > Accessibility**
3. Enable **KeyCounter**
4. Monitoring starts automatically within 3 seconds

> Without Accessibility permission the app cannot intercept key events.

---

## Data file

```
~/Library/Application Support/KeyCounter/counts.json
```

```json
{
  "Space": 15234,
  "Return": 8901,
  "e": 7432,
  "a": 6100
}
```

Use **Open Save Folder** in the menu to open the directory in Finder.

---

## File structure

```
262_MacOS_keyCounter/
├── Package.swift
├── build.sh
├── Resources/
│   └── Info.plist
└── Sources/KeyCounter/
    ├── main.swift
    ├── AppDelegate.swift
    ├── KeyboardMonitor.swift
    ├── KeyCountStore.swift
    └── NotificationManager.swift
```

---

## Architecture

### Data flow

```
Key press
  |
  v
CGEventTap  (OS-level event hook)
  |  KeyboardMonitor.swift
  |  keyTapCallback()  <-- file-scope global function (@convention(c) compatible)
  |
  v
KeyCountStore.shared.increment(key:)
  |  serial DispatchQueue for thread safety
  |  counts[key] += 1
  |  queue.async { save() }   <- write JSON asynchronously
  |
  +-- count % 1000 == 0?
  |     YES -> DispatchQueue.main.async { NotificationManager.notify() }
  |
  v
(on menu open)
NSMenuDelegate.menuWillOpen
  └─ KeyCountStore.topKeys()  -> rebuild menu with latest data
```

---

### File responsibilities

#### [main.swift](Sources/KeyCounter/main.swift)

Entry point. Launches `NSApplication` with `.accessory` policy so the app appears only in the menu bar, not in the Dock.

```swift
app.setActivationPolicy(.accessory)
```

---

#### [KeyboardMonitor.swift](Sources/KeyCounter/KeyboardMonitor.swift)

Intercepts system-wide key-down events via `CGEventTap`.

**Key design decision — `@convention(c)` constraint:**

`CGEventTapCallBack` is a C function pointer type, which means Swift closures that capture variables cannot be used directly. The callback is therefore defined as a file-scope global function and accesses state only through singletons (`KeyCountStore.shared`, etc.), which require no capture.

```
CGEvent.tapCreate(callback: keyTapCallback)
                            ^
                  global function (no captures)
                  -> implicitly convertible to @convention(c)
```

Key code to name translation is handled by a static lookup table in `keyName(for:)` (US keyboard layout).

---

#### [KeyCountStore.swift](Sources/KeyCounter/KeyCountStore.swift)

Singleton that manages counts and persists them to disk.

**Thread safety:**

The `CGEventTap` callback runs outside the main thread. A serial `DispatchQueue` serialises all dictionary access.

```
CGEventTap thread             Main thread
      |                            |
  queue.sync { increment }    queue.sync { topKeys() }
      |  <-- serialised -->        |
  queue.async { save() }          ...
```

JSON is written with `.atomic` to prevent file corruption during a write.

---

#### [NotificationManager.swift](Sources/KeyCounter/NotificationManager.swift)

Delivers native notifications via `UNUserNotificationCenter`.
`trigger: nil` means immediate delivery (no scheduling).
Notification permission is requested on first singleton access.

---

#### [AppDelegate.swift](Sources/KeyCounter/AppDelegate.swift)

Manages the menu bar UI and the accessibility permission retry loop.

**Menu rebuild strategy:**
Rebuilding the menu on every keystroke is wasteful. Instead, `NSMenuDelegate.menuWillOpen` is used to rebuild only when the user actually opens the menu.

**Permission retry:**
If the app starts without Accessibility permission, a `Timer` polls `AXIsProcessTrusted()` every 3 seconds and starts monitoring automatically once permission is granted.

---

## Menu example

```
KC
--------------------------
Total: 48,291 keystrokes
--------------------------
1  Space   --  15,234
2  Return  --   8,901
3  e       --   7,432
4  a       --   6,100
5  s       --   5,880
   ...
--------------------------
Open Save Folder
--------------------------
Quit                    Q
```

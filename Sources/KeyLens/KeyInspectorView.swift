import SwiftUI

// MARK: - KeyInspectorViewModel

final class KeyInspectorViewModel: ObservableObject {
    struct LastKey {
        let name: String
        let keyCode: UInt16
        let location: String
        let hasShift:   Bool
        let hasCtrl:    Bool
        let hasAlt:     Bool
        let hasCmd:     Bool
        let hasCaps:    Bool
        let rawFlags:   UInt64
        let hidUsage:   (page: UInt8, usage: UInt8)?
    }

    @Published var lastKey: LastKey? = nil
    @Published var heldKeys: [UInt16: String] = [:]   // keyCode → display name
    @Published var holdDurationMs: Double? = nil       // last key-down duration in ms

    private var keyDownTimes: [UInt16: Date] = [:]    // keyCode → keydown timestamp
    private var inputObserver:    NSObjectProtocol?
    private var releaseObserver:  NSObjectProtocol?

    init() {
        // queue: nil — runs on the CGEvent posting thread, bypassing main-thread congestion.
        // @Published writes are dispatched to main explicitly inside each handler.
        inputObserver = NotificationCenter.default.addObserver(
            forName: .keystrokeInput, object: nil, queue: nil
        ) { [weak self] note in
            guard let evt = note.object as? KeystrokeEvent else { return }
            self?.onKeyDown(evt)
        }

        releaseObserver = NotificationCenter.default.addObserver(
            forName: .keystrokeReleased, object: nil, queue: nil
        ) { [weak self] note in
            guard let self, let code = note.object as? CGKeyCode else { return }
            let keyCode = UInt16(code)
            let durationMs = keyDownTimes[keyCode].map { Date().timeIntervalSince($0) * 1000 }
            keyDownTimes.removeValue(forKey: keyCode)
            DispatchQueue.main.async {
                self.heldKeys.removeValue(forKey: keyCode)
                if let ms = durationMs { self.holdDurationMs = ms }
            }
        }
    }

    deinit {
        if let obs = inputObserver   { NotificationCenter.default.removeObserver(obs) }
        if let obs = releaseObserver { NotificationCenter.default.removeObserver(obs) }
    }

    private func onKeyDown(_ evt: KeystrokeEvent) {
        // Compute values off-main, then dispatch only the @Published writes to main.
        let f = evt.flags
        let location: String
        if evt.isNumpad {
            location = L10n.shared.inspectorLocationNumpad
        } else {
            // Distinguish left/right for modifier keys via keyCode.
            // Left: Shift=56, Ctrl=59, Option=58, Cmd=55
            // Right: Shift=60, Ctrl=62, Option=61, Cmd=54
            switch evt.keyCode {
            case 56, 59, 58, 55: location = L10n.shared.inspectorLocationLeft
            case 60, 62, 61, 54: location = L10n.shared.inspectorLocationRight
            default:             location = L10n.shared.inspectorLocationStandard
            }
        }

        let key = LastKey(
            name:     evt.displayName,
            keyCode:  evt.keyCode,
            location: location,
            hasShift: f.contains(.maskShift),
            hasCtrl:  f.contains(.maskControl),
            hasAlt:   f.contains(.maskAlternate),
            hasCmd:   f.contains(.maskCommand),
            hasCaps:  f.contains(.maskAlphaShift),
            rawFlags: evt.rawFlags,
            hidUsage: evt.hidUsage
        )
        let keyCode = evt.keyCode
        let displayName = evt.displayName
        // Only record on the first keydown — key repeat fires repeated keyDown events
        // and would otherwise overwrite the original timestamp.
        if keyDownTimes[keyCode] == nil { keyDownTimes[keyCode] = Date() }
        DispatchQueue.main.async { [weak self] in
            self?.lastKey = key
            self?.heldKeys[keyCode] = displayName
            self?.holdDurationMs = nil   // reset until keyup
        }
    }
}

// MARK: - KeyInspectorView

struct KeyInspectorView: View {
    @StateObject private var vm = KeyInspectorViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            lastKeySection
            Divider()
            modifierSection
            Divider()
            heldKeysSection
        }
    }

    // MARK: Last key details

    @ViewBuilder
    private var lastKeySection: some View {
        if let k = vm.lastKey {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    label(L10n.shared.inspectorFieldKey)
                    sym(lrKeyName(k))
                    label(L10n.shared.inspectorFieldCode)
                    mono("\(k.keyCode)")
                }
                GridRow {
                    label(L10n.shared.inspectorFieldLocation)
                    mono(k.location)
                    label(L10n.shared.inspectorFieldFlags)
                    sym(flagsString(k))
                }
                GridRow {
                    label(L10n.shared.inspectorFieldHold)
                    mono(vm.holdDurationMs.map { String(format: "%.1f ms", $0) } ?? "—")
                }
                GridRow {
                    label(L10n.shared.inspectorFieldRawFlags)
                    mono(k.rawFlags == 0 ? "0x00000000" : String(format: "0x%08X", k.rawFlags))
                }
                GridRow {
                    label(L10n.shared.inspectorFieldHID)
                    mono(k.hidUsage.map { String(format: "%02X / %02X", $0.page, $0.usage) } ?? "—")
                    label(L10n.shared.inspectorFieldHIDName)
                    sym(hidDisplayName(k))
                }
            }
        } else {
            Text(L10n.shared.inspectorWaiting)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Modifier pills

    private var modifierSection: some View {
        HStack(spacing: 8) {
            pill("⌘", active: vm.lastKey?.hasCmd   ?? false)
            pill("⌥", active: vm.lastKey?.hasAlt   ?? false)
            pill("⌃", active: vm.lastKey?.hasCtrl  ?? false)
            pill("⇧", active: vm.lastKey?.hasShift ?? false)
            pill("⇪", active: vm.lastKey?.hasCaps  ?? false)
        }
    }

    // MARK: Held keys

    @ViewBuilder
    private var heldKeysSection: some View {
        if vm.heldKeys.isEmpty {
            Text(L10n.shared.inspectorNoHeldKeys)
                .font(.callout)
                .foregroundStyle(.tertiary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(vm.heldKeys.sorted(by: { $0.key < $1.key }), id: \.key) { _, name in
                        Text(name)
                            .font(.system(.callout, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.tertiary)
    }

    private func mono(_ text: String) -> some View {
        Text(text)
            .font(.system(.callout, design: .monospaced))
            .fontWeight(.medium)
            .foregroundStyle(.primary)
    }

    // For fields containing Unicode symbols (⇧ ⌘ ⌥ ⌃) — monospaced font lacks these glyphs.
    private func sym(_ text: String) -> some View {
        Text(text)
            .font(.system(.callout, design: .default))
            .fontWeight(.medium)
            .foregroundStyle(.primary)
    }

    private func pill(_ symbol: String, active: Bool) -> some View {
        Text(symbol)
            .font(.system(size: 17, weight: active ? .semibold : .regular))
            .frame(width: 32, height: 28)
            .background(active ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.1))
            .foregroundStyle(active ? Color.primary : Color.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(active ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.1), value: active)
    }

    // Returns a human-readable name for the HID row.
    // For modifier keys (0xE0–0xE7) the keyCode-based location already set in `location`
    // is the clearest label. For all other keys, the display name suffices.
    private func hidDisplayName(_ k: KeyInspectorViewModel.LastKey) -> String {
        guard let hid = k.hidUsage, hid.page == 0x07 else { return "—" }
        switch hid.usage {
        case 0xE0: return "Left Control"
        case 0xE1: return "Left Shift"
        case 0xE2: return "Left Alt"
        case 0xE3: return "Left GUI (⌘)"
        case 0xE4: return "Right Control"
        case 0xE5: return "Right Shift"
        case 0xE6: return "Right Alt"
        case 0xE7: return "Right GUI (⌘)"
        default:
            // Strip modifier symbols — HID Name describes the physical key only, not the combo.
            var base = k.name
            for sym in ["⌃", "⌥", "⇧", "⌘"] { base = base.replacingOccurrences(of: sym, with: "") }
            return base.isEmpty ? k.name : base
        }
    }

    // Returns modifier flags with left/right distinction using NXEventData raw bit masks.
    // Bit masks: Shift L=0x02/R=0x04, Ctrl L=0x01/R=0x2000, Option L=0x20/R=0x40, Cmd L=0x08/R=0x10
    private func flagsString(_ k: KeyInspectorViewModel.LastKey) -> String {
        let raw = k.rawFlags
        var parts: [String] = []
        if k.hasCmd   { parts.append(raw & 0x10   != 0 ? "R⌘" : "L⌘") }
        if k.hasAlt   { parts.append(raw & 0x40   != 0 ? "R⌥" : "L⌥") }
        if k.hasCtrl  { parts.append(raw & 0x2000 != 0 ? "R⌃" : "L⌃") }
        if k.hasShift { parts.append(raw & 0x04   != 0 ? "R⇧" : "L⇧") }
        if k.hasCaps  { parts.append("⇪") }
        return parts.isEmpty ? "—" : parts.joined(separator: " ")
    }

    // Builds a left/right-aware display name from scratch.
    // Strips any existing modifier symbols from k.name, then prepends L/R-prefixed modifiers.
    // e.g. Left Shift + A → "L⇧A", Right Cmd + C → "R⌘C"
    private func lrKeyName(_ k: KeyInspectorViewModel.LastKey) -> String {
        guard k.hasShift || k.hasCmd || k.hasAlt || k.hasCtrl else { return k.name }
        let raw = k.rawFlags

        // Strip leading modifier symbols from the display name to get the base key
        var base = k.name
        for sym in ["⌃", "⌥", "⇧", "⌘"] {
            base = base.replacingOccurrences(of: sym, with: "")
        }

        // Build L/R prefix in ⌃⌥⇧⌘ order
        var prefix = ""
        if k.hasCtrl  { prefix += raw & 0x2000 != 0 ? "R⌃" : "L⌃" }
        if k.hasAlt   { prefix += raw & 0x40   != 0 ? "R⌥" : "L⌥" }
        if k.hasShift { prefix += raw & 0x04   != 0 ? "R⇧" : "L⇧" }
        if k.hasCmd   { prefix += raw & 0x10   != 0 ? "R⌘" : "L⌘" }

        return prefix + base
    }
}

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
    }

    @Published var lastKey: LastKey? = nil
    @Published var heldKeys: [UInt16: String] = [:]   // keyCode → display name

    private var inputObserver:    NSObjectProtocol?
    private var releaseObserver:  NSObjectProtocol?

    init() {
        inputObserver = NotificationCenter.default.addObserver(
            forName: .keystrokeInput, object: nil, queue: .main
        ) { [weak self] note in
            guard let evt = note.object as? KeystrokeEvent else { return }
            self?.onKeyDown(evt)
        }

        releaseObserver = NotificationCenter.default.addObserver(
            forName: .keystrokeReleased, object: nil, queue: .main
        ) { [weak self] note in
            guard let code = note.object as? CGKeyCode else { return }
            self?.heldKeys.removeValue(forKey: UInt16(code))
        }
    }

    deinit {
        if let obs = inputObserver   { NotificationCenter.default.removeObserver(obs) }
        if let obs = releaseObserver { NotificationCenter.default.removeObserver(obs) }
    }

    private func onKeyDown(_ evt: KeystrokeEvent) {
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

        lastKey = LastKey(
            name:     evt.displayName,
            keyCode:  evt.keyCode,
            location: location,
            hasShift: f.contains(.maskShift),
            hasCtrl:  f.contains(.maskControl),
            hasAlt:   f.contains(.maskAlternate),
            hasCmd:   f.contains(.maskCommand),
            hasCaps:  f.contains(.maskAlphaShift)
        )
        heldKeys[evt.keyCode] = evt.displayName
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
                    mono(k.name)
                    label(L10n.shared.inspectorFieldCode)
                    mono("\(k.keyCode)")
                }
                GridRow {
                    label(L10n.shared.inspectorFieldLocation)
                    mono(k.location)
                    label(L10n.shared.inspectorFieldFlags)
                    mono(flagsString(k))
                }
            }
        } else {
            Text(L10n.shared.inspectorWaiting)
                .font(.footnote)
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
                .font(.footnote)
                .foregroundStyle(.tertiary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(vm.heldKeys.sorted(by: { $0.key < $1.key }), id: \.key) { _, name in
                        Text(name)
                            .font(.system(.footnote, design: .monospaced))
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
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private func mono(_ text: String) -> some View {
        Text(text)
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(.primary)
    }

    private func pill(_ symbol: String, active: Bool) -> some View {
        Text(symbol)
            .font(.system(size: 15, weight: active ? .semibold : .regular))
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

    private func flagsString(_ k: KeyInspectorViewModel.LastKey) -> String {
        var parts: [String] = []
        if k.hasCmd   { parts.append("⌘") }
        if k.hasAlt   { parts.append("⌥") }
        if k.hasCtrl  { parts.append("⌃") }
        if k.hasShift { parts.append("⇧") }
        if k.hasCaps  { parts.append("⇪") }
        return parts.isEmpty ? "—" : parts.joined()
    }
}

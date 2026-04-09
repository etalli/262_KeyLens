import SwiftUI

// MARK: - Layer Mapping Settings Window

/// Top-level window controller for layer key mapping settings.
final class LayerMappingWindowController: NSWindowController {
    static let shared = LayerMappingWindowController()

    private init() {
        let view = LayerMappingSettingsView()
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = L10n.shared.layerMappingWindowTitle
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 560, height: 520))
        window.minSize = NSSize(width: 480, height: 400)
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    func show() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Main settings view

struct LayerMappingSettingsView: View {
    @ObservedObject private var store = LayerMappingStore.shared
    private let l = L10n.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.layerMappingWindowTitle)
                        .font(.headline)
                    Text(l.layerEfficiencyHelp)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            HStack(alignment: .top, spacing: 0) {
                // Left column: Layer Keys
                LayerKeysPanel()
                    .frame(width: 220)

                Divider()

                // Right column: Output key mappings
                KeyMappingsPanel()
            }
            .frame(maxHeight: .infinity)
        }
    }
}

// MARK: - Layer Keys panel

private struct LayerKeysPanel: View {
    @ObservedObject private var store = LayerMappingStore.shared
    @State private var showAdd = false
    @State private var newName = ""
    @State private var newFinger = "Left Thumb"
    private let l = L10n.shared

    private let fingerOptions = [
        "Left Thumb", "Right Thumb",
        "Left Index", "Right Index",
        "Left Pinky", "Right Pinky"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(l.layerMappingLayerKeysSection)
                    .font(.subheadline).bold()
                Spacer()
                Button {
                    showAdd = true
                    newName = ""
                    newFinger = "Left Thumb"
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help(l.layerMappingAddLayerKey)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if store.layerKeys.isEmpty {
                Text(l.layerMappingEmpty)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding()
            } else {
                List {
                    ForEach(store.layerKeys) { key in
                        LayerKeyRow(key: key)
                    }
                }
                .listStyle(.plain)
            }

            if showAdd {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    TextField(l.layerMappingLayerKeyName, text: $newName)
                        .textFieldStyle(.roundedBorder)

                    Picker(l.layerMappingFinger, selection: $newFinger) {
                        ForEach(fingerOptions, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Button(l.layerMappingAddLayerKey) {
                            store.addLayerKey(name: newName, finger: newFinger)
                            showAdd = false
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)

                        Button("Cancel") { showAdd = false }
                            .keyboardShortcut(.escape, modifiers: [])
                    }
                }
                .padding(10)
            }
        }
    }
}

private struct LayerKeyRow: View {
    let key: LayerKey
    @ObservedObject private var store = LayerMappingStore.shared

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(key.name).font(.body)
                Text(key.finger).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                store.removeLayerKey(id: key.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Key Mappings panel

private struct KeyMappingsPanel: View {
    @ObservedObject private var store = LayerMappingStore.shared
    @State private var showAdd = false
    @State private var newOutputKey = ""
    @State private var newLayerKeyName = ""
    @State private var newBaseKey = ""
    private let l = L10n.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(l.layerMappingOutputKeysSection)
                    .font(.subheadline).bold()
                Spacer()
                Button {
                    guard !store.layerKeys.isEmpty else { return }
                    showAdd = true
                    newOutputKey = ""
                    newLayerKeyName = store.layerKeys.first?.name ?? ""
                    newBaseKey = ""
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .disabled(store.layerKeys.isEmpty)
                .help(store.layerKeys.isEmpty ? l.layerMappingNoLayerKeys : l.layerMappingAddMapping)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if store.mappings.isEmpty {
                Text(store.layerKeys.isEmpty ? l.layerMappingNoLayerKeys : l.layerMappingEmpty)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding()
            } else {
                List {
                    ForEach(store.mappings) { mapping in
                        KeyMappingRow(mapping: mapping)
                    }
                }
                .listStyle(.plain)
            }

            if showAdd {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField(l.layerMappingOutputKey, text: $newOutputKey)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 100)

                        Text("=")
                            .foregroundStyle(.secondary)

                        Picker("", selection: $newLayerKeyName) {
                            ForEach(store.layerKeys) { k in
                                Text(k.name).tag(k.name)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 100)

                        Text("+")
                            .foregroundStyle(.secondary)

                        TextField(l.layerMappingBaseKey, text: $newBaseKey)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 60)
                    }

                    HStack {
                        Button(l.layerMappingAddMapping) {
                            store.addMapping(
                                outputKey: newOutputKey,
                                layerKeyName: newLayerKeyName,
                                baseKey: newBaseKey
                            )
                            showAdd = false
                        }
                        .disabled(
                            newOutputKey.trimmingCharacters(in: .whitespaces).isEmpty ||
                            newBaseKey.trimmingCharacters(in: .whitespaces).isEmpty ||
                            newLayerKeyName.isEmpty
                        )

                        Button("Cancel") { showAdd = false }
                            .keyboardShortcut(.escape, modifiers: [])
                    }
                }
                .padding(10)
            }
        }
    }
}

private struct KeyMappingRow: View {
    let mapping: LayerKeyMapping
    @ObservedObject private var store = LayerMappingStore.shared
    @ObservedObject private var theme = ThemeStore.shared

    var body: some View {
        HStack {
            Text(mapping.outputKey)
                .font(.body.monospaced())
                .frame(width: 40, alignment: .leading)
            Text("=")
                .foregroundStyle(.secondary)
            Text(mapping.layerKeyName)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(theme.accentColor.opacity(0.15))
                .cornerRadius(4)
            Text("+")
                .foregroundStyle(.secondary)
            Text(mapping.baseKey)
                .font(.body.monospaced())
            Spacer()
            Button {
                store.removeMapping(id: mapping.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

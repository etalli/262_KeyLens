import Foundation

// MARK: - Data model

/// A firmware layer key (e.g. "Lower" held by the left thumb).
struct LayerKey: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String        // e.g. "Lower", "Raise"
    var finger: String      // e.g. "Left Thumb", "Right Thumb"

    init(id: UUID = UUID(), name: String, finger: String) {
        self.id = id
        self.name = name
        self.finger = finger
    }
}

/// Maps one OS-level output key to the physical combo that produces it.
/// e.g. outputKey="←", layerKeyName="Lower", baseKey="J"
struct LayerKeyMapping: Identifiable, Codable, Equatable {
    var id: UUID
    var outputKey: String       // key name as seen by KeyLens (e.g. "←", "F5")
    var layerKeyName: String    // must match a LayerKey.name
    var baseKey: String         // the physical key pressed together with the layer key

    init(id: UUID = UUID(), outputKey: String, layerKeyName: String, baseKey: String) {
        self.id = id
        self.outputKey = outputKey
        self.layerKeyName = layerKeyName
        self.baseKey = baseKey
    }
}

// MARK: - Store

/// Singleton that stores firmware layer mappings and provides fast lookup for the increment() hot path.
/// Persisted as JSON in UserDefaults.
final class LayerMappingStore: ObservableObject {
    static let shared = LayerMappingStore()

    @Published private(set) var layerKeys: [LayerKey] = []
    @Published private(set) var mappings: [LayerKeyMapping] = []

    // Fast lookup: outputKey → (layerKeyName, baseKey)
    // Rebuilt whenever layerKeys or mappings change.
    private(set) var lookupTable: [String: (layerKeyName: String, baseKey: String)] = [:]

    private static let layerKeysDefaultsKey   = "layerMappingLayerKeys"
    private static let mappingsDefaultsKey    = "layerMappingMappings"
    private static let allTimeCountsKey       = "layerMappingAllTimeCounts"
    private static let dailyCountsKey         = "layerMappingDailyCounts"
    private static let allTimeOutputCountsKey = "layerMappingAllTimeOutputCounts"

    // All-time press count per layer key name: [layerKeyName: count]
    private(set) var allTimePressCount: [String: Int] = [:]
    // Per-date press count: [date: [layerKeyName: count]]
    private(set) var dailyPressCount: [String: [String: Int]] = [:]
    // All-time output key counts per layer key: [layerKeyName: [outputKey: count]]
    private(set) var allTimeOutputCounts: [String: [String: Int]] = [:]

    private init() {
        load()
        rebuildLookup()
    }

    // MARK: - Layer key CRUD

    func addLayerKey(name: String, finger: String) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        layerKeys.append(LayerKey(name: name, finger: finger))
        save()
        rebuildLookup()
    }

    func updateLayerKey(id: UUID, name: String, finger: String) {
        guard let idx = layerKeys.firstIndex(where: { $0.id == id }) else { return }
        layerKeys[idx].name = name
        layerKeys[idx].finger = finger
        // Update any mappings that reference the old name
        let oldName = layerKeys[idx].name
        for i in mappings.indices where mappings[i].layerKeyName == oldName {
            mappings[i].layerKeyName = name
        }
        save()
        rebuildLookup()
    }

    func removeLayerKey(id: UUID) {
        guard let key = layerKeys.first(where: { $0.id == id }) else { return }
        layerKeys.removeAll { $0.id == id }
        // Remove orphaned mappings
        mappings.removeAll { $0.layerKeyName == key.name }
        save()
        rebuildLookup()
    }

    // MARK: - Key mapping CRUD

    func addMapping(outputKey: String, layerKeyName: String, baseKey: String) {
        let out = outputKey.trimmingCharacters(in: .whitespaces)
        let base = baseKey.trimmingCharacters(in: .whitespaces)
        guard !out.isEmpty, !base.isEmpty, !layerKeyName.isEmpty else { return }
        // Remove existing mapping for the same output key
        mappings.removeAll { $0.outputKey == out }
        mappings.append(LayerKeyMapping(outputKey: out, layerKeyName: layerKeyName, baseKey: base))
        save()
        rebuildLookup()
    }

    func removeMapping(id: UUID) {
        mappings.removeAll { $0.id == id }
        save()
        rebuildLookup()
    }

    // MARK: - Hot-path lookup

    /// Returns the physical combo for an output key, or nil if not mapped.
    /// Thread-safe: lookupTable is only written on the main thread during save/load.
    func physicalCombo(for outputKey: String) -> (layerKeyName: String, baseKey: String)? {
        lookupTable[outputKey]
    }

    // MARK: - Counter tracking (called from KeyCountStore.increment() on the store queue)

    /// Records one activation of a layer key for the given output key and date.
    /// Must be called from KeyCountStore.queue.sync to avoid data races.
    func recordPress(layerKeyName: String, outputKey: String, date: String) {
        allTimePressCount[layerKeyName, default: 0] += 1
        dailyPressCount[date, default: [:]][layerKeyName, default: 0] += 1
        allTimeOutputCounts[layerKeyName, default: [:]][outputKey, default: 0] += 1
        scheduleSaveCounters()
    }

    private var saveCountersWorkItem: DispatchWorkItem?

    private func scheduleSaveCounters() {
        saveCountersWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.saveCounters() }
        saveCountersWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: item)
    }

    private func saveCounters() {
        if let data = try? JSONEncoder().encode(allTimePressCount) {
            UserDefaults.standard.set(data, forKey: Self.allTimeCountsKey)
        }
        if let data = try? JSONEncoder().encode(dailyPressCount) {
            UserDefaults.standard.set(data, forKey: Self.dailyCountsKey)
        }
        if let data = try? JSONEncoder().encode(allTimeOutputCounts) {
            UserDefaults.standard.set(data, forKey: Self.allTimeOutputCountsKey)
        }
    }

    // MARK: - Persistence

    private func rebuildLookup() {
        var table: [String: (layerKeyName: String, baseKey: String)] = [:]
        for m in mappings {
            table[m.outputKey] = (layerKeyName: m.layerKeyName, baseKey: m.baseKey)
        }
        lookupTable = table
    }

    private func save() {
        if let data = try? JSONEncoder().encode(layerKeys) {
            UserDefaults.standard.set(data, forKey: Self.layerKeysDefaultsKey)
        }
        if let data = try? JSONEncoder().encode(mappings) {
            UserDefaults.standard.set(data, forKey: Self.mappingsDefaultsKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: Self.layerKeysDefaultsKey),
           let decoded = try? JSONDecoder().decode([LayerKey].self, from: data) {
            layerKeys = decoded
        }
        if let data = UserDefaults.standard.data(forKey: Self.mappingsDefaultsKey),
           let decoded = try? JSONDecoder().decode([LayerKeyMapping].self, from: data) {
            mappings = decoded
        }
        if let data = UserDefaults.standard.data(forKey: Self.allTimeCountsKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            allTimePressCount = decoded
        }
        if let data = UserDefaults.standard.data(forKey: Self.dailyCountsKey),
           let decoded = try? JSONDecoder().decode([String: [String: Int]].self, from: data) {
            dailyPressCount = decoded
        }
        if let data = UserDefaults.standard.data(forKey: Self.allTimeOutputCountsKey),
           let decoded = try? JSONDecoder().decode([String: [String: Int]].self, from: data) {
            allTimeOutputCounts = decoded
        }
    }
}

// MARK: - Layer efficiency query result

/// Per-layer-key usage summary produced by KeyMetricsQuery.layerEfficiency().
struct LayerEfficiencyEntry: Identifiable {
    var id: String { layerKeyName }
    var layerKeyName: String
    var finger: String
    var pressCount: Int         // how many times this layer key was activated today
    var allTimePressCount: Int  // cumulative all-time press count
    var topCombos: [(outputKey: String, count: Int)]  // most-used output keys via this layer
    // Issue #236: ergonomic breakdown for today's layer bigrams
    var totalBigrams: Int = 0
    var sfCount: Int      = 0   // same-finger bigrams
    var haCount: Int      = 0   // hand-alternation bigrams
    var hsCount: Int      = 0   // high-strain bigrams

    var sfRate: Double { totalBigrams > 0 ? Double(sfCount) / Double(totalBigrams) : 0 }
    var haRate: Double { totalBigrams > 0 ? Double(haCount) / Double(totalBigrams) : 0 }
    var hsRate: Double { totalBigrams > 0 ? Double(hsCount) / Double(totalBigrams) : 0 }
}

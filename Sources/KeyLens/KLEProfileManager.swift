import AppKit
import KeyLensCore

// MARK: - KLEProfile

struct KLEProfile: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var keywords: String    // Comma-separated device match keywords
    var url: String         // Source URL for reloading
    var json: String        // Encoded [KLEAbsoluteKey] array
    var fileName: String    // File or URL name shown in status
}

// MARK: - KLEProfileManager (Issue #332)

/// Owns KLE profile persistence, device auto-matching, and profile selection.
/// Extracted from KeyboardHeatmapView so the logic can be tested independently.
@MainActor
final class KLEProfileManager: ObservableObject {

    @Published var profilesJSON: String {
        didSet { UserDefaults.standard.set(profilesJSON, forKey: UDKeys.kleProfiles) }
    }
    @Published var selectedProfileIDString: String {
        didSet { UserDefaults.standard.set(selectedProfileIDString, forKey: UDKeys.kleSelectedProfileID) }
    }

    init() {
        profilesJSON = UserDefaults.standard.string(forKey: UDKeys.kleProfiles) ?? "[]"
        selectedProfileIDString = UserDefaults.standard.string(forKey: UDKeys.kleSelectedProfileID) ?? ""
    }

    // MARK: - Profile access

    var profiles: [KLEProfile] {
        guard let data = profilesJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([KLEProfile].self, from: data)
        else { return [] }
        return decoded
    }

    func setProfiles(_ profiles: [KLEProfile]) {
        if let data = try? JSONEncoder().encode(profiles),
           let str = String(data: data, encoding: .utf8) {
            profilesJSON = str
        }
    }

    var selectedProfile: KLEProfile? {
        let ps = profiles
        if let id = UUID(uuidString: selectedProfileIDString),
           let p = ps.first(where: { $0.id == id }) {
            return p
        }
        return ps.first
    }

    // MARK: - Device auto-matching

    /// Returns the first profile whose keywords match any of the given device names.
    func matchingProfile(for names: [String]) -> KLEProfile? {
        let lower = names.map { $0.lowercased() }
        for profile in profiles {
            let kws = profile.keywords
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                .filter { !$0.isEmpty }
            if !kws.isEmpty && lower.contains(where: { n in kws.contains { n.contains($0) } }) {
                return profile
            }
        }
        return nil
    }

    private static let splitKeywords = ["split", "ergo", "moonlander", "advantage", "corne", "reviung", "pangaea"]
    private static let jisKeywords   = ["jis", "japanese"]

    /// Resolves device names to a concrete HeatmapTemplate (used when template == .auto).
    /// Priority: profile keyword match → KLE import + split device → split/ergo → JIS → ANSI
    func resolveTemplate(from names: [String]) -> HeatmapTemplate {
        let lower = names.map { $0.lowercased() }
        let isSplit = lower.contains { n in Self.splitKeywords.contains { n.contains($0) } }
        let ps = profiles

        if !ps.isEmpty {
            if matchingProfile(for: names) != nil { return .custom }
            if isSplit { return .custom }
        }
        if isSplit { return .pangaea }
        if lower.contains(where: { n in Self.jisKeywords.contains { n.contains($0) } }) { return .jis }
        return .ansi
    }

    /// Returns the profile that should be displayed for the given template + connected devices.
    func effectiveProfile(template: HeatmapTemplate, deviceNames: [String]) -> KLEProfile? {
        guard template == .auto else { return selectedProfile }
        return matchingProfile(for: deviceNames) ?? selectedProfile
    }

    // MARK: - Profile mutation

    /// Mutates the currently selected profile in-place, creating a default one if none exists.
    func updateSelectedProfile(_ mutate: (inout KLEProfile) -> Void) {
        var ps = profiles
        if ps.isEmpty {
            var p = KLEProfile(name: L10n.shared.kleProfileNewName, keywords: "", url: "", json: "", fileName: "")
            mutate(&p)
            setProfiles([p])
            selectedProfileIDString = p.id.uuidString
            return
        }
        guard let idx = ps.firstIndex(where: { $0.id.uuidString == selectedProfileIDString })
                ?? ps.indices.first else { return }
        mutate(&ps[idx])
        setProfiles(ps)
        selectedProfileIDString = ps[idx].id.uuidString
    }

    // MARK: - Legacy migration

    /// One-time migration from the pre-#318 single-slot KLE storage to the profile list.
    func migrateIfNeeded() {
        let legacyJSON      = UserDefaults.standard.string(forKey: UDKeys.kleCustomLayoutJSON) ?? ""
        let legacyKeywords  = UserDefaults.standard.string(forKey: UDKeys.kleCustomKeywords) ?? ""
        let legacyFileName  = UserDefaults.standard.string(forKey: UDKeys.kleCustomLayoutFileName) ?? ""
        let legacyURL       = UserDefaults.standard.string(forKey: UDKeys.kleCustomLayoutURL) ?? ""
        guard profiles.isEmpty, !legacyJSON.isEmpty else { return }
        let profile = KLEProfile(
            name: legacyFileName.isEmpty ? "Custom" : legacyFileName,
            keywords: legacyKeywords,
            url: legacyURL,
            json: legacyJSON,
            fileName: legacyFileName
        )
        setProfiles([profile])
        selectedProfileIDString = profile.id.uuidString
    }

    // MARK: - Import from file

    /// Parses a KLE JSON file at `url` and saves it into the selected profile.
    func importKLE(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let rows = try KLEParser.parse(data)
        let encoded = try JSONEncoder().encode(rows)
        let jsonString = String(data: encoded, encoding: .utf8) ?? ""
        let fileName = url.lastPathComponent
        updateSelectedProfile { p in
            p.json = jsonString
            p.fileName = fileName
            if p.name == L10n.shared.kleProfileNewName || p.name.isEmpty {
                p.name = fileName
            }
        }
    }

    // MARK: - Load from URL

    /// Fetches KLE JSON from a URL string, parses it, and saves it into the selected profile.
    func loadKLE(from urlString: String) async throws {
        let (kleData, fileName) = try await fetchKLEData(from: urlString)
        let rows = try KLEParser.parse(kleData)
        let encoded = try JSONEncoder().encode(rows)
        let jsonString = String(data: encoded, encoding: .utf8) ?? ""
        updateSelectedProfile { p in
            p.json = jsonString
            p.fileName = fileName
            p.url = urlString
            if p.keywords.trimmingCharacters(in: .whitespaces).isEmpty {
                p.keywords = fileName
            }
            if p.name == L10n.shared.kleProfileNewName || p.name.isEmpty {
                p.name = fileName
            }
        }
    }

    /// Fetches raw KLE JSON data from a KLE page URL or a direct URL.
    /// KLE page URLs (keyboard-layout-editor.com/#/gists/ID) are resolved via the GitHub Gist API.
    private func fetchKLEData(from urlString: String) async throws -> (Data, String) {
        if urlString.contains("keyboard-layout-editor.com"),
           let range = urlString.range(of: "#/gists/") {
            let gistID = String(urlString[range.upperBound...])
                .components(separatedBy: CharacterSet(charactersIn: "/?#")).first ?? ""
            guard !gistID.isEmpty,
                  let apiURL = URL(string: "https://api.github.com/gists/\(gistID)") else {
                throw URLError(.badURL)
            }
            var request = URLRequest(url: apiURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (apiData, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: apiData) as? [String: Any],
                  let files = json["files"] as? [String: Any],
                  let firstFile = files.values.first as? [String: Any],
                  let content = firstFile["content"] as? String,
                  let fileName = firstFile["filename"] as? String else {
                throw URLError(.cannotParseResponse)
            }
            let kleData = Data(content.utf8)
            let keyboardName = (json["description"] as? String)?.trimmingCharacters(in: .whitespaces).isEmpty == false
                ? json["description"] as! String
                : fileName
            return (kleData, keyboardName)
        }

        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return (data, url.lastPathComponent)
    }
}

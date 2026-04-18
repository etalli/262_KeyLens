import SwiftUI

/// 2D matrix heatmap — rows = "from" key, columns = "to" key, cells colored by average IKI.
/// セル色はバイグラム平均IKI (ms)。緑=速い、赤=遅い。データなし=灰色。
struct BigramHeatmapView: View {
    let bigramIKIMap:  [String: Double]   // "a→s" → avg IKI ms
    let topKeyEntries: [TopKeyEntry]      // ordered by frequency; used to pick axis keys

    @AppStorage(UDKeys.bigramHeatmapTopN) private var topN: Int = 12
    @State private var hoveredBigram: String? = nil

    private let cellSize:  CGFloat = 26
    private let labelSize: CGFloat = 28

    // Top-N single-character keys that appear in bigramIKIMap.
    private var axisKeys: [String] {
        var present = Set<String>()
        for key in bigramIKIMap.keys {
            let parts = key.components(separatedBy: "→")
            if parts.count == 2 { present.insert(parts[0]); present.insert(parts[1]) }
        }
        let filtered = topKeyEntries.filter { present.contains($0.key) }.map(\.key)
        return Array(filtered.prefix(topN))
    }

    // Min/max IKI across the visible cells — used for color normalization.
    private var ikiRange: (min: Double, max: Double) {
        let keys = axisKeys
        let values = keys.flatMap { from in
            keys.compactMap { to -> Double? in bigramIKIMap["\(from)→\(to)"] }
        }
        guard let lo = values.min(), let hi = values.max(), hi > lo else { return (100, 400) }
        return (lo, hi)
    }

    var body: some View {
        if bigramIKIMap.isEmpty {
            Text(L10n.shared.bigramHeatmapNoData)
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                nPicker
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    matrixGrid
                        .padding(.bottom, 4)
                }
                tooltipRow
                legendRow
            }
        }
    }

    // MARK: - N picker

    private var nPicker: some View {
        HStack(spacing: 6) {
            Text(L10n.shared.bigramHeatmapTop)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Picker("", selection: $topN) {
                Text("10").tag(10)
                Text("12").tag(12)
                Text("15").tag(15)
                Text("20").tag(20)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
            Text(L10n.shared.bigramHeatmapKeys)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Matrix

    private var matrixGrid: some View {
        let keys = axisKeys
        return VStack(alignment: .leading, spacing: 0) {
            // Column header row
            HStack(spacing: 0) {
                // Spacer under the row-label column
                Spacer().frame(width: labelSize + 8)
                ForEach(keys, id: \.self) { toKey in
                    Text(toKey)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: cellSize, height: 18, alignment: .center)
                        .lineLimit(1)
                }
            }
            // One row per from-key
            ForEach(keys, id: \.self) { fromKey in
                HStack(spacing: 0) {
                    Text(fromKey)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: labelSize, height: cellSize, alignment: .trailing)
                        .padding(.trailing, 8)
                    ForEach(keys, id: \.self) { toKey in
                        cellView(from: fromKey, to: toKey)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cellView(from: String, to: String) -> some View {
        let bigramKey = "\(from)→\(to)"
        let iki = bigramIKIMap[bigramKey]
        let isHovered = hoveredBigram == bigramKey
        let fill: Color = iki.map { ikiColor($0) } ?? Color.secondary.opacity(0.08)

        Rectangle()
            .fill(fill)
            .frame(width: cellSize, height: cellSize)
            .overlay(
                Rectangle()
                    .stroke(isHovered ? Color.primary.opacity(0.6) : Color.primary.opacity(0.07),
                            lineWidth: isHovered ? 1.5 : 0.5)
            )
            .onHover { inside in
                hoveredBigram = inside && iki != nil ? bigramKey : nil
            }
    }

    // MARK: - Tooltip

    @ViewBuilder
    private var tooltipRow: some View {
        if let b = hoveredBigram, let iki = bigramIKIMap[b] {
            HStack(spacing: 8) {
                Text(b)
                    .font(.system(.footnote, design: .monospaced).bold())
                Text("·")
                    .foregroundStyle(.secondary)
                Text(String(format: "%.0f ms", iki))
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(ikiColor(iki))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Text(L10n.shared.bigramHeatmapHoverHint)
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Legend

    private var legendRow: some View {
        HStack(spacing: 4) {
            Text(L10n.shared.bigramHeatmapFast)
                .font(.footnote)
                .foregroundStyle(.secondary)
            ForEach(0..<8, id: \.self) { i in
                let t = Double(i) / 7.0
                Rectangle()
                    .fill(ikiColor(lerp(ikiRange.min, ikiRange.max, t)))
                    .frame(width: 18, height: 10)
            }
            Text(L10n.shared.bigramHeatmapSlow)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("(\(Int(ikiRange.min))–\(Int(ikiRange.max)) ms)")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Color helpers

    /// Maps avg IKI to a green→yellow→red hue. Data range is normalized to [0, 1].
    private func ikiColor(_ iki: Double) -> Color {
        let range = ikiRange
        let t = min(1, max(0, (iki - range.min) / (range.max - range.min)))
        // hue: 0.33 (green) → 0.0 (red)
        let hue = 0.33 * (1.0 - t)
        return Color(hue: hue, saturation: 0.70, brightness: 0.75)
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }
}

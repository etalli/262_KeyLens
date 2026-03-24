import SwiftUI
import Charts

// MARK: - Layer Efficiency section in Ergonomics tab (Issue #209)

extension ChartsView {

    @ViewBuilder
    var layerEfficiencySection: some View {
        let l = L10n.shared
        if model.layerEfficiency.isEmpty {
            VStack(spacing: 8) {
                Text(l.layerEfficiencyNoData)
                    .foregroundStyle(.secondary)
                Button(l.layerMappingMenuTitle) {
                    (NSApp.delegate as? AppDelegate)?.showLayerMappingSettings()
                }
                .buttonStyle(.link)
            }
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
        } else {
            VStack(alignment: .leading, spacing: 20) {
                // Bar chart: all-time press count per layer key
                let chartData = model.layerEfficiency
                let keyOrder  = chartData.map(\.layerKeyName)

                Chart(chartData) { entry in
                    BarMark(
                        x: .value("Presses", entry.allTimePressCount),
                        y: .value("Layer Key", entry.layerKeyName)
                    )
                    .foregroundStyle(Color.teal.opacity(0.8))
                    .cornerRadius(3)
                    .annotation(position: .trailing) {
                        Text("\(entry.allTimePressCount)")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYScale(domain: keyOrder)
                .chartXAxisLabel("All-time presses", alignment: .trailing)
                .chartLegend(.hidden)
                .frame(height: CGFloat(chartData.count * 44 + 24))

                // Detail rows: finger, today count, top combos
                Divider()

                ForEach(model.layerEfficiency) { entry in
                    LayerKeyDetailRow(entry: entry)
                }
            }
        }
    }
}

// MARK: - Detail row for one layer key

private struct LayerKeyDetailRow: View {
    let entry: LayerEfficiencyEntry
    private let l = L10n.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(entry.layerKeyName)
                    .font(.headline)
                Text(entry.finger)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.teal.opacity(0.15))
                    .cornerRadius(4)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Today: \(entry.pressCount) \(l.layerEfficiencyPresses)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("All-time: \(entry.allTimePressCount) \(l.layerEfficiencyPresses)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !entry.topCombos.isEmpty {
                HStack(spacing: 6) {
                    ForEach(entry.topCombos, id: \.outputKey) { combo in
                        HStack(spacing: 3) {
                            Text(combo.outputKey)
                                .font(.caption.monospaced())
                            Text("×\(combo.count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(5)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

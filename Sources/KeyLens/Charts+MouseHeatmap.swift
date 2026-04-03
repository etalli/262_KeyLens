import SwiftUI

// MARK: - Mouse Position Heatmap (Issue #217)

extension ChartsView {

    // Section wrapper used inside Charts+MouseTab.swift
    var mouseHeatmapSection: some View {
        let l = L10n.shared
        return chartSection(l.chartTitleMouseHeatmap, helpText: l.helpMouseHeatmap) {
            MouseHeatmapView(cells: model.heatmapGrid)
        }
    }
}

// MARK: - MouseHeatmapView

struct MouseHeatmapView: View {
    let cells: [MouseGridCell]

    var body: some View {
        if cells.isEmpty {
            Text(L10n.shared.noDataYet)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 160, alignment: .center)
        } else {
            Canvas { context, size in
                let maxHits = cells.map(\.hits).max() ?? 1
                let cellW = size.width  / 100
                let cellH = size.height / 100

                for cell in cells {
                    let norm = Double(cell.hits) / Double(maxHits)
                    let rect = CGRect(
                        x: CGFloat(cell.gridX) * cellW,
                        y: CGFloat(cell.gridY) * cellH,
                        width: cellW,
                        height: cellH
                    )
                    context.fill(Path(rect), with: .color(heatColor(norm)))
                }

                // Screen outline
                context.stroke(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(.secondary.opacity(0.3)),
                    lineWidth: 0.5
                )
            }
            .frame(height: 180)
            .cornerRadius(4)
        }
    }

    /// Maps a normalised value 0–1 to a blue → green → yellow → red colour ramp.
    private func heatColor(_ t: Double) -> Color {
        switch t {
        case ..<0.25:
            // blue → cyan
            let s = t / 0.25
            return Color(red: 0, green: s, blue: 1)
        case 0.25..<0.5:
            // cyan → green
            let s = (t - 0.25) / 0.25
            return Color(red: 0, green: 1, blue: 1 - s)
        case 0.5..<0.75:
            // green → yellow
            let s = (t - 0.5) / 0.25
            return Color(red: s, green: 1, blue: 0)
        default:
            // yellow → red
            let s = (t - 0.75) / 0.25
            return Color(red: 1, green: 1 - s, blue: 0)
        }
    }
}

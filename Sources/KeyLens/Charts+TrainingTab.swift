import SwiftUI
import KeyLensCore

extension ChartsView {

    // MARK: - Training Tab

    var trainingTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection(L10n.shared.trainingTargetsTitle,
                             helpText: L10n.shared.helpTrainingTargets) {
                    trainingTargetsSection
                }
                chartSection(L10n.shared.practiceDrillsTitle,
                             helpText: L10n.shared.helpPracticeDrills) {
                    practiceDrillsSection
                }
            }
            .padding(24)
        }
    }

    // MARK: - Targets

    @ViewBuilder
    private var trainingTargetsSection: some View {
        if let session = model.trainingSession, !session.targets.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    Text(L10n.shared.trainingColumnBigram)
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    Text(L10n.shared.trainingColumnIKI)
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(width: 120, alignment: .trailing)
                    Text(L10n.shared.trainingColumnCount)
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(width: 90, alignment: .trailing)
                    Text(L10n.shared.trainingColumnTier)
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .trailing)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

                Divider()

                ForEach(Array(session.targets.enumerated()), id: \.offset) { index, score in
                    let tier = tierLabel(rank: index, config: session.config)
                    HStack(spacing: 0) {
                        Text(displayBigram(score.bigram))
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 80, alignment: .leading)
                        Text(String(format: "%.0f ms", score.meanIKI))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(ikiColor(score.meanIKI))
                            .frame(width: 120, alignment: .trailing)
                        Text("\(score.count)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 90, alignment: .trailing)
                        Text(tier.label)
                            .font(.caption)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(tier.color.opacity(0.15))
                            .foregroundStyle(tier.color)
                            .clipShape(Capsule())
                            .frame(width: 70, alignment: .trailing)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(index.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.03))
                }

                Divider().padding(.top, 4)

                Button(L10n.shared.trainingRegenerateButton) {
                    model.reload()
                }
                .buttonStyle(.bordered)
                .padding(.top, 10)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.shared.trainingNoData)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
                Button(L10n.shared.trainingRegenerateButton) {
                    model.reload()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Drills

    @ViewBuilder
    private var practiceDrillsSection: some View {
        if let session = model.trainingSession, !session.drills.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(session.drills.enumerated()), id: \.offset) { index, drill in
                    DrillRowView(index: index + 1, drill: drill)
                }
            }
        } else {
            emptyState
        }
    }

    // MARK: - Helpers

    private func displayBigram(_ key: String) -> String {
        let parts = key.components(separatedBy: "→")
        guard parts.count == 2 else { return key }
        return parts[0] + parts[1]
    }

    private func ikiColor(_ iki: Double) -> Color {
        switch iki {
        case ..<100:  return .green
        case ..<180:  return .primary
        default:      return .orange
        }
    }

    private struct TierInfo {
        let label: String
        let color: Color
    }

    private func tierLabel(rank: Int, config: SessionConfig) -> TierInfo {
        if rank < config.highTierSize {
            return TierInfo(label: L10n.shared.trainingTierHigh, color: .red)
        } else if rank < config.highTierSize + config.midTierSize {
            return TierInfo(label: L10n.shared.trainingTierMid, color: .orange)
        } else {
            return TierInfo(label: L10n.shared.trainingTierLow, color: .blue)
        }
    }
}

// MARK: - DrillRowView

private struct DrillRowView: View {
    let index: Int
    let drill: DrillSequence

    @State private var copied = false

    var kindLabel: String {
        drill.kind == .repeated
            ? L10n.shared.trainingDrillRepeated
            : L10n.shared.trainingDrillAlternating
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("\(index).")
                    .font(.caption).foregroundStyle(.secondary)
                Text(drill.targets.joined(separator: " + "))
                    .font(.caption.bold())
                Text("— \(kindLabel)")
                    .font(.caption).foregroundStyle(.secondary)

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(drill.text, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    Image(systemName: copied ? "checkmark" : "clipboard")
                        .font(.caption)
                        .foregroundStyle(copied ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help("Copy drill text")
                .animation(.easeInOut(duration: 0.2), value: copied)
            }

            Text(drill.text)
                .font(.system(.title3, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

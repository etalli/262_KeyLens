import SwiftUI
import AppKit
import KeyLensCore

extension ChartsView {

    // MARK: - Training Tab

    /// Session built from ranked bigrams + trigrams for the user's chosen length config.
    ///
    /// Bigram drills come first (high-priority → low-priority).
    /// Trigram drills are appended at the end: one repeated drill per top trigram.
    /// Trigram targets are not stored in training history (bigram targets only).
    private var currentTrainingSession: TrainingSession? {
        guard !model.trainingScores.isEmpty else { return nil }
        let base = SessionBuilder.build(from: model.trainingScores, config: sessionLength.config)
        let trigramDrills = trigramDrillsForSession()
        guard !trigramDrills.isEmpty else { return base }
        return TrainingSession(targets: base.targets,
                               drills:  base.drills + trigramDrills,
                               config:  base.config)
    }

    /// Generates repeated drills from the top trigrams (up to 3, 5 reps each).
    private func trigramDrillsForSession() -> [DrillSequence] {
        let reps = sessionLength.config.highReps
        return model.trainingTrigramScores.prefix(3).compactMap { score -> DrillSequence? in
            guard let t = Trigram.parse(score.trigram) else { return nil }
            let text = Array(repeating: t.display, count: reps).joined(separator: " ")
            return DrillSequence(targets: [t.display], text: text, kind: .repeated)
        }
    }

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
                chartSection(L10n.shared.trainingTrigramTargetsTitle,
                             helpText: L10n.shared.helpTrainingTrigrams) {
                    trainingTrigramTargetsSection
                }
                chartSection(L10n.shared.trainingHistoryTitle,
                             helpText: L10n.shared.helpTrainingHistory) {
                    trainingHistorySection
                }
            }
            .padding(24)
        }
    }

    // MARK: - Targets

    @ViewBuilder
    private var trainingTargetsSection: some View {
        if let session = currentTrainingSession, !session.targets.isEmpty {
            // Build a lookup: bigramKey → (beforeIKI, completedAt) from the most recent session
            // that included each bigram. Used to annotate targets with training history.
            let historyLookup: [String: (beforeIKI: Double, date: Date)] = {
                var result: [String: (Double, Date)] = [:]
                for record in model.trainingHistory {
                    for key in record.targets {
                        if result[key] == nil, let iki = record.beforeIKI[key] {
                            result[key] = (iki, record.completedAt)
                        }
                    }
                }
                return result
            }()

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Text(L10n.shared.trainingColumnBigram)
                        .font(.caption).foregroundStyle(.primary.opacity(0.6))
                        .frame(width: 80, alignment: .leading)
                    Text(L10n.shared.trainingColumnIKI)
                        .font(.caption).foregroundStyle(.primary.opacity(0.6))
                        .frame(width: 120, alignment: .trailing)
                    Text(L10n.shared.trainingColumnCount)
                        .font(.caption).foregroundStyle(.primary.opacity(0.6))
                        .frame(width: 90, alignment: .trailing)
                    Text(L10n.shared.trainingColumnTier)
                        .font(.caption).foregroundStyle(.primary.opacity(0.6))
                        .frame(width: 70, alignment: .trailing)
                    Text(L10n.shared.trainingColumnHistory)
                        .font(.caption).foregroundStyle(.primary.opacity(0.6))
                        .frame(width: 110, alignment: .trailing)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

                Divider()

                ForEach(Array(session.targets.enumerated()), id: \.offset) { index, score in
                    let tier    = tierLabel(rank: index, config: session.config)
                    let history = historyLookup[score.bigram]
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
                            .foregroundStyle(.primary.opacity(0.75))
                            .frame(width: 90, alignment: .trailing)
                        Text(tier.label)
                            .font(.caption)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(tier.color.opacity(0.15))
                            .foregroundStyle(tier.color)
                            .clipShape(Capsule())
                            .frame(width: 70, alignment: .trailing)
                        // Training history annotation: "was Xms  Δ±Y" or "—" if never trained
                        if let h = history {
                            let delta = score.meanIKI - h.beforeIKI
                            (Text(String(format: "%.0f", h.beforeIKI))
                                .foregroundColor(.secondary)
                             + Text("→")
                                .foregroundColor(.secondary)
                             + Text(String(format: "%+.0f", delta))
                                .foregroundColor(delta < -5 ? .green : delta > 5 ? .red : .secondary))
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 110, alignment: .trailing)
                            .help(String(format: L10n.shared.trainingHistoryAnnotationHelp,
                                         h.beforeIKI, score.meanIKI, formatDate(h.date)))
                        } else {
                            Text("—")
                                .font(.caption).foregroundStyle(.tertiary)
                                .frame(width: 110, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(index.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.06))
                }
            }
        } else {
            Text(L10n.shared.trainingNoData)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
        }
    }

    // MARK: - Trigram Targets (Issue #89)

    @ViewBuilder
    private var trainingTrigramTargetsSection: some View {
        if model.trainingTrigramScores.isEmpty {
            Text(L10n.shared.trainingNoTrigramData)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 0) {
                    Text(L10n.shared.trainingColumnTrigram)
                        .font(.caption).foregroundStyle(.primary.opacity(0.6))
                        .frame(width: 80, alignment: .leading)
                    Text(L10n.shared.trainingColumnEstIKI)
                        .font(.caption).foregroundStyle(.primary.opacity(0.6))
                        .frame(width: 120, alignment: .trailing)
                    Text(L10n.shared.trainingColumnCount)
                        .font(.caption).foregroundStyle(.primary.opacity(0.6))
                        .frame(width: 90, alignment: .trailing)
                    Text(L10n.shared.trainingColumnTier)
                        .font(.caption).foregroundStyle(.primary.opacity(0.6))
                        .frame(width: 70, alignment: .trailing)
                    Text("Drill")
                        .font(.caption).foregroundStyle(.primary.opacity(0.6))
                        .frame(minWidth: 120, alignment: .leading)
                        .padding(.leading, 16)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

                Divider()

                ForEach(Array(model.trainingTrigramScores.enumerated()), id: \.offset) { index, score in
                    let display   = Trigram.parse(score.trigram)?.display ?? score.trigram
                    let drillText = Array(repeating: display, count: 5).joined(separator: " ")
                    let tier      = trigramTierLabel(rank: index, total: model.trainingTrigramScores.count)
                    HStack(spacing: 0) {
                        Text(display)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 80, alignment: .leading)
                        Text(String(format: "%.0f ms", score.estimatedIKI))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(ikiColor(score.estimatedIKI))
                            .frame(width: 120, alignment: .trailing)
                        Text("\(score.count)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.75))
                            .frame(width: 90, alignment: .trailing)
                        Text(tier.label)
                            .font(.caption)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(tier.color.opacity(0.15))
                            .foregroundStyle(tier.color)
                            .clipShape(Capsule())
                            .frame(width: 70, alignment: .trailing)
                        Text(drillText)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 120, alignment: .leading)
                            .padding(.leading, 16)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(index.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.06))
                }
            }
        }
    }

    private func trigramTierLabel(rank: Int, total: Int) -> TierInfo {
        let high = max(1, total / 3)
        let mid  = max(1, total / 3)
        if rank < high {
            return TierInfo(label: L10n.shared.trainingTierHigh, color: .red)
        } else if rank < high + mid {
            return TierInfo(label: L10n.shared.trainingTierMid, color: .orange)
        } else {
            return TierInfo(label: L10n.shared.trainingTierLow, color: .blue)
        }
    }

    // MARK: - Drills (interactive)

    @ViewBuilder
    private var practiceDrillsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Length picker
            Picker("", selection: $sessionLength) {
                ForEach(SessionLength.allCases, id: \.self) { length in
                    Text(length.rawValue).tag(length)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)

            if let session = currentTrainingSession, !session.drills.isEmpty {
                InteractivePracticeView(
                    session: session,
                    sessionLengthName: sessionLength.rawValue,
                    beforeIKI: Dictionary(uniqueKeysWithValues: session.targets.map { ($0.bigram, $0.meanIKI) }),
                    onNewSession: {
                        model.reload()
                        trainingResetToken = UUID()
                    },
                    onSessionComplete: { result in
                        KeyCountStore.shared.saveTrainingResult(
                            targets: result.targets,
                            sessionLength: result.sessionLength,
                            accuracy: result.accuracy,
                            wpm: result.wpm,
                            duration: result.duration,
                            totalTyped: result.totalTyped,
                            totalCorrect: result.totalCorrect,
                            beforeIKI: result.beforeIKI
                        ) {
                            model.reload()
                        }
                    }
                )
                // Reset interactive state when length or "New Session" changes.
                .id(sessionLength.rawValue + trainingResetToken.uuidString)
            } else {
                emptyState
            }
        }
    }

    // MARK: - History

    @ViewBuilder
    private var trainingHistorySection: some View {
        if model.trainingHistory.isEmpty {
            Text(L10n.shared.trainingHistoryEmpty)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 50, alignment: .center)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 0) {
                    Text(L10n.shared.trainingHistoryDate)
                        .font(.caption).foregroundStyle(.primary.opacity(0.6))
                        .frame(width: 130, alignment: .leading)
                    Text(L10n.shared.trainingHistoryTargets)
                        .font(.caption).foregroundStyle(.primary.opacity(0.6))
                        .frame(width: 110, alignment: .leading)
                    Text(L10n.shared.trainingHistoryLength)
                        .font(.caption).foregroundStyle(.primary.opacity(0.6))
                        .frame(width: 60, alignment: .leading)
                    Text(L10n.shared.trainingColumnIKI.components(separatedBy: " ").first ?? "Acc")
                        .font(.caption).foregroundStyle(.primary.opacity(0.6))
                        .frame(width: 55, alignment: .trailing)
                        .help("Accuracy %")
                    Text("WPM")
                        .font(.caption).foregroundStyle(.primary.opacity(0.6))
                        .frame(width: 50, alignment: .trailing)
                    Text(L10n.shared.trainingHistoryBefore)
                        .font(.caption).foregroundStyle(.primary.opacity(0.6))
                        .frame(width: 70, alignment: .trailing)
                        .help(L10n.shared.trainingHistoryBefore)
                    Text(L10n.shared.trainingHistoryDelta)
                        .font(.caption).foregroundStyle(.primary.opacity(0.6))
                        .frame(width: 65, alignment: .trailing)
                        .help(L10n.shared.trainingHistoryDelta)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

                Divider()

                ForEach(Array(model.trainingHistory.enumerated()), id: \.element.id) { index, record in
                    let avgBefore = avgIKI(record.beforeIKI, targets: record.targets)
                    let avgNow    = avgIKI(model.bigramIKIMap, targets: record.targets)
                    HStack(spacing: 0) {
                        Text(formatDate(record.completedAt))
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 130, alignment: .leading)
                        Text(record.targetDisplayStrings.joined(separator: " "))
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 110, alignment: .leading)
                        Text(record.sessionLength)
                            .font(.caption)
                            .foregroundStyle(.primary.opacity(0.75))
                            .frame(width: 60, alignment: .leading)
                        Text("\(record.accuracy)%")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(record.accuracy >= 90 ? .green : record.accuracy >= 70 ? .orange : .red)
                            .frame(width: 55, alignment: .trailing)
                        Text("\(record.wpm)")
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 50, alignment: .trailing)
                        // Before IKI (ms avg at session time)
                        if let before = avgBefore {
                            Text(String(format: "%.0f ms", before))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 70, alignment: .trailing)
                        } else {
                            Text("—")
                                .font(.caption).foregroundStyle(.tertiary)
                                .frame(width: 70, alignment: .trailing)
                        }
                        // Δ IKI: positive value = slower now (regression), negative = faster (improvement)
                        if let before = avgBefore, let now = avgNow {
                            let delta = now - before
                            Text(String(format: "%+.0f ms", delta))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(delta < -5 ? .green : delta > 5 ? .red : .secondary)
                                .frame(width: 65, alignment: .trailing)
                        } else {
                            Text("—")
                                .font(.caption).foregroundStyle(.tertiary)
                                .frame(width: 65, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(index.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.06))
                }

                Divider().padding(.top, 4)

                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        showClearHistoryAlert = true
                    } label: {
                        Text(L10n.shared.trainingHistoryClear)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .alert(L10n.shared.trainingHistoryClear, isPresented: $showClearHistoryAlert) {
                    Button(L10n.shared.trainingHistoryClear, role: .destructive) {
                        KeyCountStore.shared.clearTrainingHistory {
                            model.reload()
                        }
                    }
                    Button(L10n.shared.cancel, role: .cancel) {}
                } message: {
                    Text(L10n.shared.trainingHistoryClearConfirm)
                }
            }
        }
    }

    /// Returns the average IKI (ms) across the given target bigrams using the provided IKI map.
    /// Returns nil if none of the targets are present in the map.
    private func avgIKI(_ map: [String: Double], targets: [String]) -> Double? {
        let values = targets.compactMap { map[$0] }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f.string(from: date)
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

// MARK: - InteractivePracticeView

struct TrainingCompletionResult {
    let targets: [String]
    let sessionLength: String
    let accuracy: Int
    let wpm: Int
    let duration: Double
    let totalTyped: Int
    let totalCorrect: Int
    /// Mean IKI (ms) per target bigram at session creation time (Issue #84).
    let beforeIKI: [String: Double]
}

private struct InteractivePracticeView: View {
    let session: TrainingSession
    let sessionLengthName: String
    /// Pre-training IKI for each target bigram, captured at session creation (Issue #84).
    let beforeIKI: [String: Double]
    let onNewSession: () -> Void
    let onSessionComplete: (TrainingCompletionResult) -> Void

    // results[i] = true/false for each character typed in the current drill.
    // results.count is always equal to the current cursor position.
    @State private var results: [Bool] = []
    @State private var drillIndex: Int = 0
    @State private var sessionComplete: Bool = false
    @State private var totalCorrect: Int = 0
    @State private var totalTyped: Int = 0
    @State private var sessionStartTime: Date? = nil
    @State private var sessionDuration: TimeInterval = 0

    private var currentDrill: DrillSequence { session.drills[drillIndex] }
    private var expectedChars: [Character]  { Array(currentDrill.text) }
    private var cursorIndex: Int            { results.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if sessionComplete {
                sessionCompleteView
            } else {
                progressHeader
                drillLabel
                drillTextView
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                HStack {
                    Text("Click the text above to focus, then start typing")
                        .font(.caption2).foregroundStyle(.tertiary)
                    Spacer()
                    Button("Skip") { advanceDrill() }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                // Invisible key capture view — steals first responder from KeySilencer.
                KeyCapture(onChar: handleChar, onBackspace: handleBackspace)
                    .frame(width: 1, height: 1).opacity(0)
            }
        }
    }

    // MARK: - Sub-views

    private var progressHeader: some View {
        HStack {
            Text("Drill \(drillIndex + 1) of \(session.drills.count)")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            if totalTyped > 0 {
                let pct = Int(Double(totalCorrect) / Double(totalTyped) * 100)
                Text("Accuracy: \(pct)%")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var drillLabel: some View {
        HStack(spacing: 6) {
            ForEach(currentDrill.targets, id: \.self) { target in
                Text(target)
                    .font(.caption.bold())
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            Text("—")
                .font(.caption).foregroundStyle(.secondary)
            Text(currentDrill.kind == .repeated
                 ? L10n.shared.trainingDrillRepeated
                 : L10n.shared.trainingDrillAlternating)
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    /// Builds the drill text with per-character coloring.
    /// - Typed correctly : green
    /// - Typed incorrectly: red
    /// - Current cursor   : primary + underline
    /// - Not yet typed    : dimmed secondary
    private var drillTextView: Text {
        expectedChars.enumerated().reduce(Text("")) { acc, pair in
            let (i, char) = pair
            let t: Text
            if i < cursorIndex {
                t = Text(String(char))
                    .foregroundColor(results[i] ? .green : .red)
            } else if i == cursorIndex {
                t = Text(String(char))
                    .underline()
                    .foregroundColor(.primary)
            } else {
                t = Text(String(char))
                    .foregroundColor(Color.secondary.opacity(0.35))
            }
            return acc + t
        }
        .font(.system(.title2, design: .monospaced))
    }

    private var sessionCompleteView: some View {
        let pct = totalTyped > 0 ? Int(Double(totalCorrect) / Double(totalTyped) * 100) : 0
        // WPM: standard formula — (characters / 5) / minutes
        let wpm = sessionDuration > 0 ? Int(Double(totalTyped) / 5.0 / (sessionDuration / 60.0)) : 0

        return VStack(alignment: .leading, spacing: 12) {
            Text("Session Complete!")
                .font(.title3.bold())
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(pct)%")
                        .font(.system(.largeTitle, design: .monospaced).bold())
                        .foregroundStyle(pct >= 90 ? .green : pct >= 70 ? .orange : .red)
                    Text("Accuracy")
                        .font(.caption).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(wpm)")
                        .font(.system(.largeTitle, design: .monospaced).bold())
                    Text("WPM")
                        .font(.caption).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.0fs", sessionDuration))
                        .font(.system(.largeTitle, design: .monospaced).bold())
                    Text("Time")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Button(L10n.shared.trainingRegenerateButton) { onNewSession() }
                .buttonStyle(.bordered)
                .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Input handling

    private func handleChar(_ char: Character) {
        guard !sessionComplete, cursorIndex < expectedChars.count else { return }
        if sessionStartTime == nil { sessionStartTime = Date() }
        let correct = char == expectedChars[cursorIndex]
        results.append(correct)
        if correct { totalCorrect += 1 }
        totalTyped += 1
        if results.count >= expectedChars.count { advanceDrill() }
    }

    private func handleBackspace() {
        guard !sessionComplete, !results.isEmpty else { return }
        let wasCorrect = results.removeLast()
        totalTyped -= 1
        if wasCorrect { totalCorrect -= 1 }
    }

    private func advanceDrill() {
        if drillIndex + 1 < session.drills.count {
            drillIndex += 1
            results = []
        } else {
            let duration = sessionStartTime.map { Date().timeIntervalSince($0) } ?? 0
            sessionDuration = duration
            sessionComplete = true
            let pct = totalTyped > 0 ? Int(Double(totalCorrect) / Double(totalTyped) * 100) : 0
            let wpm = duration > 0 ? Int(Double(totalTyped) / 5.0 / (duration / 60.0)) : 0
            onSessionComplete(TrainingCompletionResult(
                targets: session.targets.map { $0.bigram },
                sessionLength: sessionLengthName,
                accuracy: pct,
                wpm: wpm,
                duration: duration,
                totalTyped: totalTyped,
                totalCorrect: totalCorrect,
                beforeIKI: beforeIKI
            ))
        }
    }
}

// MARK: - KeyCapture (NSViewRepresentable)

/// Captures raw keystrokes and reports them to SwiftUI callbacks.
/// Uses `viewDidMoveToWindow` + a deferred `makeFirstResponder` call so it
/// wins the race against `KeySilencer` (which also calls `makeFirstResponder`
/// synchronously on appear).
private final class KeyCaptureNSView: NSView {
    var onChar: ((Character) -> Void)?
    var onBackspace: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Defer so we fire after KeySilencer's synchronous makeFirstResponder call.
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        // Backspace / Delete
        if event.keyCode == 51 {
            onBackspace?()
            return
        }
        // Ignore modifier combos (cmd, ctrl, option)
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
              let chars = event.characters,
              let char = chars.first,
              !char.isNewline,
              char != "\t"
        else { return }
        onChar?(char)
    }
}

private struct KeyCapture: NSViewRepresentable {
    let onChar: (Character) -> Void
    let onBackspace: () -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView { KeyCaptureNSView() }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.onChar      = onChar
        nsView.onBackspace = onBackspace
    }
}

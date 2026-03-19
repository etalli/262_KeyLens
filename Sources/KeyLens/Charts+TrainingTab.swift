import SwiftUI
import AppKit
import KeyLensCore

extension ChartsView {

    // MARK: - Training Tab

    /// Session built from the model's ranked scores + the user's chosen length config.
    private var currentTrainingSession: TrainingSession? {
        guard !model.trainingScores.isEmpty else { return nil }
        return SessionBuilder.build(from: model.trainingScores, config: sessionLength.config)
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
            }
            .padding(24)
        }
    }

    // MARK: - Targets

    @ViewBuilder
    private var trainingTargetsSection: some View {
        if let session = currentTrainingSession, !session.targets.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
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
            }
        } else {
            Text(L10n.shared.trainingNoData)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
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
                    onNewSession: {
                        model.reload()
                        trainingResetToken = UUID()
                    }
                )
                // Reset interactive state when length or "New Session" changes.
                .id(sessionLength.rawValue + trainingResetToken.uuidString)
            } else {
                emptyState
            }
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

// MARK: - InteractivePracticeView

private struct InteractivePracticeView: View {
    let session: TrainingSession
    let onNewSession: () -> Void

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
            sessionDuration = sessionStartTime.map { Date().timeIntervalSince($0) } ?? 0
            sessionComplete = true
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

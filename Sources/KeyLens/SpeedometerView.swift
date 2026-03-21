import SwiftUI

// MARK: - Speedometer ViewModel
// Owns the timer and state as a class so it survives parent view rebuilds.
// @StateObject ensures one instance per view lifetime, not one per render pass.
private final class SpeedometerViewModel: ObservableObject {
    @Published var currentWPM: Double = 0
    @Published var peakWPM: Double = 0

    private var lastKeystrokeDate: Date = .distantPast
    private var decayTimer: Timer?
    private var observer: NSObjectProtocol?

    // 0.65× per 0.5 s tick → half-life ≈ 1.5 s, reaches ~0 in ~4 s.
    private static let decayFactor: Double = 0.65

    init() {
        // Stable timer: not tied to view struct lifecycle.
        decayTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
        observer = NotificationCenter.default.addObserver(
            forName: .keystrokeInput, object: nil, queue: .main
        ) { [weak self] _ in
            self?.onKeystroke()
        }
    }

    deinit {
        decayTimer?.invalidate()
        if let obs = observer { NotificationCenter.default.removeObserver(obs) }
    }

    private func onKeystroke() {
        lastKeystrokeDate = Date()
        let wpm = KeyCountStore.shared.rollingWPM()
        currentWPM = wpm
        if wpm > peakWPM { peakWPM = wpm }
    }

    private func tick() {
        guard Date().timeIntervalSince(lastKeystrokeDate) > 0.3 else { return }
        currentWPM = max(0, currentWPM * Self.decayFactor)
    }
}

// MARK: - Speedometer View (Issue #115)
// Arc gauge showing rolling WPM from the last 5-second keystroke window.
// Arc sweeps from 8 o'clock (0 WPM) clockwise through 12 o'clock (50 WPM) to 4 o'clock (100 WPM).

struct SpeedometerView: View {
    private static let maxWPM: Double = 100
    // Angles measured from 3 o'clock (right), increasing clockwise in screen coords.
    private static let startDeg: Double = 150  // ~8 o'clock position (0 WPM)
    private static let sweepDeg: Double = 240  // total arc span in degrees

    @StateObject private var vm = SpeedometerViewModel()

    var body: some View {
        VStack(spacing: 6) {
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height * 0.73)
                let radius: CGFloat = min(size.width * 0.38, size.height * 0.78)

                drawTrack(ctx: ctx, center: center, radius: radius)
                drawColorZones(ctx: ctx, center: center, radius: radius)
                drawTicks(ctx: ctx, center: center, radius: radius)
                if vm.peakWPM > 0 {
                    drawPeakNeedle(ctx: ctx, center: center, radius: radius, wpm: vm.peakWPM)
                }
                drawNeedle(ctx: ctx, center: center, radius: radius, wpm: vm.currentWPM)
                drawHub(ctx: ctx, center: center)
            }
            .frame(width: 260, height: 200)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: "\(Int(vm.currentWPM))")
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                Text(L10n.shared.speedometerWPMLabel)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            Text(L10n.shared.speedometerPeakLabel(Int(vm.peakWPM)))
                .font(.caption)
                .foregroundStyle(.secondary)
                .opacity(vm.peakWPM > 0 ? 1 : 0)
        }
    }

    // MARK: - Geometry helpers

    private func angleDeg(for fraction: Double) -> Double {
        Self.startDeg + fraction * Self.sweepDeg
    }

    private func fraction(for wpm: Double) -> Double {
        min(max(wpm / Self.maxWPM, 0), 1)
    }

    /// Point on the gauge arc at `fraction` (0=0 WPM, 1=max WPM), `radius` pixels from `center`.
    private func arcPoint(fraction: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        let rad = angleDeg(for: fraction) * .pi / 180
        return CGPoint(
            x: center.x + radius * CGFloat(cos(rad)),
            y: center.y + radius * CGFloat(sin(rad))
        )
    }

    /// Arc segment drawn as line segments to avoid Path.addArc clockwise-convention issues.
    private func arcPath(from: Double, to: Double, radius: CGFloat, center: CGPoint) -> Path {
        var path = Path()
        let steps = 60
        for i in 0...steps {
            let t = from + Double(i) / Double(steps) * (to - from)
            let pt = arcPoint(fraction: t, radius: radius, center: center)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        return path
    }

    // MARK: - Drawing

    private func drawTrack(ctx: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let path = arcPath(from: 0, to: 1, radius: radius, center: center)
        ctx.stroke(path, with: .color(.gray.opacity(0.18)),
                   style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round))
    }

    private func drawColorZones(ctx: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let zones: [(Double, Double, Color)] = [
            (0.0, 0.3, .gray.opacity(0.55)),  // 0–30 WPM: slow
            (0.3, 0.6, .green),               // 30–60 WPM: comfortable
            (0.6, 0.8, .yellow),              // 60–80 WPM: fast
            (0.8, 1.0, .red),                 // 80–100 WPM: peak
        ]
        for (from, to, color) in zones {
            let path = arcPath(from: from, to: to, radius: radius, center: center)
            ctx.stroke(path, with: .color(color.opacity(0.8)),
                       style: StrokeStyle(lineWidth: 15, lineCap: .butt, lineJoin: .round))
        }
    }

    private func drawTicks(ctx: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let milestones: [(wpm: Double, major: Bool)] = [
            (0, true), (20, false), (40, false), (60, false), (80, false), (100, true),
        ]
        for (wpm, major) in milestones {
            let f = fraction(for: wpm)
            let outer = arcPoint(fraction: f, radius: radius + (major ? 10 : 7), center: center)
            let inner = arcPoint(fraction: f, radius: radius - (major ? 10 : 6), center: center)
            var p = Path()
            p.move(to: inner)
            p.addLine(to: outer)
            ctx.stroke(p, with: .color(.primary.opacity(0.5)),
                       style: StrokeStyle(lineWidth: major ? 2.5 : 1.5, lineCap: .round))

            let labelPt = arcPoint(fraction: f, radius: radius - 26, center: center)
            ctx.draw(
                Text(verbatim: "\(Int(wpm))")
                    .font(.system(size: 10, weight: major ? .semibold : .regular, design: .monospaced)),
                at: labelPt
            )
        }
    }

    private func drawNeedle(ctx: GraphicsContext, center: CGPoint, radius: CGFloat, wpm: Double) {
        let f = fraction(for: wpm)
        let tip = arcPoint(fraction: f, radius: radius - 14, center: center)
        let rad = angleDeg(for: f) * .pi / 180
        let tail = CGPoint(x: center.x - 16 * CGFloat(cos(rad)),
                           y: center.y - 16 * CGFloat(sin(rad)))
        var p = Path()
        p.move(to: tail)
        p.addLine(to: tip)
        ctx.stroke(p, with: .color(.white),
                   style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }

    private func drawPeakNeedle(ctx: GraphicsContext, center: CGPoint, radius: CGFloat, wpm: Double) {
        let f = fraction(for: wpm)
        let tip  = arcPoint(fraction: f, radius: radius - 4,  center: center)
        let base = arcPoint(fraction: f, radius: radius - 22, center: center)
        var p = Path()
        p.move(to: base)
        p.addLine(to: tip)
        ctx.stroke(p, with: .color(.red.opacity(0.85)),
                   style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    }

    private func drawHub(ctx: GraphicsContext, center: CGPoint) {
        let r: CGFloat = 8
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(.white))
        ctx.stroke(Path(ellipseIn: rect), with: .color(.gray.opacity(0.5)), lineWidth: 1)
    }
}

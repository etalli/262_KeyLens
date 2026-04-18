import SwiftUI

// MARK: - Speedometer ViewModel
// Owns the timer and state as a class so it survives parent view rebuilds.
// @StateObject ensures one instance per view lifetime, not one per render pass.
private final class SpeedometerViewModel: ObservableObject {
    /// Spring-smoothed display value — drives the needle and the WPM number.
    @Published var displayWPM: Double = 0
    @Published var peakWPM: Double = 0

    /// Raw rolling WPM — updated instantly on each keystroke, then decays.
    private var targetWPM: Double = 0
    /// Spring velocity in WPM/s. Carries inertia between ticks.
    private var velocity: Double = 0

    private var lastKeystrokeDate: Date = .distantPast
    private var decayTimer: Timer?
    private var springTimer: Timer?
    private var observer: NSObjectProtocol?

    // 0.65× per 0.5 s tick → half-life ≈ 1.5 s, reaches ~0 in ~4 s.
    private static let decayFactor: Double = 0.65

    // Spring-damper constants (Issue #243).
    // springK controls responsiveness; damping controls overshoot.
    // ζ = damping / (2 × √springK) ≈ 0.65 → moderate underdamping, slight overshoot.
    private static let springK: Double = 12.0
    private static let damping: Double = 4.5
    private static let springDt: Double = 1.0 / 60.0  // 60 Hz update rate

    init() {
        // Decay timer: same cadence as before, drives targetWPM down when idle.
        decayTimer = Timer.scheduledTimer(withTimeInterval: AppConfiguration.liveRefreshIntervalSecs, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // Spring timer starts dormant; wakes on first keystroke via restartSpringTimerIfNeeded().
        // queue: nil — handler runs on the posting thread (main); onKeystroke dispatches off-main.
        observer = NotificationCenter.default.addObserver(
            forName: .keystrokeInput, object: nil, queue: nil
        ) { [weak self] _ in
            self?.onKeystroke()
        }
    }

    /// Starts the 60 Hz spring timer only if it is not already running.
    /// Call this whenever targetWPM changes so the needle animates to the new value.
    private func restartSpringTimerIfNeeded() {
        guard springTimer == nil else { return }
        springTimer = Timer.scheduledTimer(withTimeInterval: Self.springDt, repeats: true) { [weak self] _ in
            self?.springTick()
        }
    }

    deinit {
        decayTimer?.invalidate()
        springTimer?.invalidate()
        if let obs = observer { NotificationCenter.default.removeObserver(obs) }
    }

    private func onKeystroke() {
        // Skip all work when the floating gauge is hidden — no need to animate an invisible view.
        guard WPMGaugeOverlayController.shared.isEnabled else { return }
        // Dispatch off-main: rollingWPM() calls queue.sync on KeyCountStore's serial queue,
        // which would stall the main thread if called directly.
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            let wpm = KeyCountStore.shared.rollingWPM()
            let now = Date()
            DispatchQueue.main.async {
                self?.lastKeystrokeDate = now
                self?.targetWPM = wpm
                self?.restartSpringTimerIfNeeded()
            }
        }
    }

    /// Slow decay applied to targetWPM when the user stops typing.
    private func tick() {
        guard Date().timeIntervalSince(lastKeystrokeDate) > AppConfiguration.speedometerKeystrokeCooldownSecs else { return }
        let newTarget = max(0, targetWPM * Self.decayFactor)
        guard newTarget != targetWPM else { return }
        targetWPM = newTarget
        restartSpringTimerIfNeeded()
    }

    /// Spring-damper step: displayWPM chases targetWPM with inertia and slight overshoot.
    /// Stops the timer once the animation has settled to avoid burning CPU at idle.
    private func springTick() {
        // If the gauge was disabled while the timer was already running, stop immediately.
        guard WPMGaugeOverlayController.shared.isEnabled else {
            targetWPM = 0; displayWPM = 0; velocity = 0
            springTimer?.invalidate()
            springTimer = nil
            return
        }

        let dt = Self.springDt
        // Symplectic Euler: update velocity first, then position (more stable than explicit Euler).
        velocity += (targetWPM - displayWPM) * Self.springK * dt - velocity * Self.damping * dt
        displayWPM = max(0, displayWPM + velocity * dt)
        if displayWPM > peakWPM { peakWPM = displayWPM }

        // Stop the 60 Hz timer once the needle has come to rest.
        if abs(targetWPM - displayWPM) < 0.1 && abs(velocity) < 0.1 {
            displayWPM = targetWPM
            velocity = 0
            springTimer?.invalidate()
            springTimer = nil
        }
    }
}

// MARK: - Speedometer View (Issue #115, spring physics Issue #243)
// Arc gauge showing rolling WPM from the last 5-second keystroke window.
// Arc sweeps from 8 o'clock (0 WPM) clockwise through 12 o'clock (50 WPM) to 4 o'clock (100 WPM).

struct SpeedometerView: View {
    private static let maxWPM: Double = 150
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
                drawNeedle(ctx: ctx, center: center, radius: radius, wpm: vm.displayWPM)
                drawHub(ctx: ctx, center: center)
            }
            .frame(width: 260, height: 200)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                // Hidden mirror balances the visible "WPM" label so the number centers on the arc pivot.
                Text(L10n.shared.speedometerWPMLabel)
                    .font(.title2)
                    .hidden()
                Text(verbatim: "\(Int(vm.displayWPM))")
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
            (0, true), (30, false), (60, false), (90, false), (120, false), (150, true),
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
                    .font(.system(size: 13, weight: major ? .semibold : .regular, design: .monospaced)),
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
        // Dark outline drawn first so the needle is readable against all zone colors.
        ctx.stroke(p, with: .color(.black.opacity(0.45)),
                   style: StrokeStyle(lineWidth: 5, lineCap: .round))
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
        ctx.stroke(Path(ellipseIn: rect), with: .color(.black.opacity(0.45)), lineWidth: 2)
    }
}

import Foundation
import AppKit

// MARK: - ScreenLayout

/// Represents the predicted configuration of the user's screen setup.
/// ユーザーの画面構成の予測結果を表す。
struct ScreenLayout: Equatable {
    /// Estimated number of monitors.
    /// 推定モニター数。
    let monitorCount: Int

    /// Estimated primary display bounds in screen points (origin at bottom-left on macOS).
    /// 推定プライマリディスプレイの範囲（macOS では左下が原点）。
    let estimatedPrimaryBounds: CGRect

    /// Estimated secondary display regions. Empty when monitorCount == 1.
    /// 推定セカンダリディスプレイ領域。モニター数が 1 の場合は空。
    let estimatedSecondaryBounds: [CGRect]

    /// Confidence score [0.0, 1.0] for this prediction.
    /// この予測の信頼スコア [0.0, 1.0]。
    let confidence: Double

    var description: String {
        "ScreenLayout(monitors=\(monitorCount), primary=\(estimatedPrimaryBounds), confidence=\(String(format: "%.2f", confidence)))"
    }
}

// MARK: - ScreenLayoutPredictor

/// Predicts the user's physical screen layout from accumulated mouse-movement history.
///
/// マウス移動距離の履歴からユーザーの画面レイアウトを予測するクラス。
///
/// ## Algorithm overview / アルゴリズム概要
///
/// 1. **Data collection** — Raw `(dx, dy)` mouse deltas captured by `KeyboardMonitor`
///    are forwarded to `MouseStore` and also to this class via `recordMovement(dx:dy:)`.
///
/// 2. **Pattern analysis** — Accumulated positional samples are analysed to find:
///    - The bounding rectangle of all observed cursor positions.
///    - Clusters of frequently-visited coordinates (UI elements / dock / menu bar).
///    - Sudden large horizontal jumps, which indicate a multi-monitor boundary.
///
/// 3. **Layout estimation** — From the bounding rect and jump analysis, the predictor
///    estimates monitor count, primary display size, and secondary display positions.
///
/// 4. **Application** — Callers (e.g. `KeystrokeOverlayController`) can query
///    `currentLayout` to position UI relative to the user's actual screen space.
///
final class ScreenLayoutPredictor {
    static let shared = ScreenLayoutPredictor()

    // MARK: - Configuration

    /// Minimum number of position samples before a prediction is attempted.
    /// 予測を試みる前に必要な最小サンプル数。
    private let minimumSamples = 500

    /// A horizontal delta this large (in points) is treated as a cross-monitor jump.
    /// このサイズ（ポイント単位）以上の水平デルタは画面跨ぎジャンプと見なす。
    private let crossMonitorJumpThreshold: Double = 400

    /// How many samples to keep in the rolling position window.
    /// ローリングウィンドウに保持するサンプル数。
    private let maxSamples = 50_000

    // MARK: - Internal state

    private let queue = DispatchQueue(label: "com.keylens.screenlayoutpredictor", qos: .utility)

    // Rolling window of absolute cursor positions (screen coordinates).
    // 絶対カーソル位置のローリングウィンドウ（スクリーン座標）。
    private var positions: [CGPoint] = []

    // Count of detected cross-monitor horizontal jumps.
    // 検出された画面跨ぎ水平ジャンプの数。
    private var crossMonitorJumpCount: Int = 0

    // Total number of movement events processed.
    // 処理した移動イベントの合計数。
    private var totalEventCount: Int = 0

    // Cached current prediction; invalidated when new data arrives.
    // キャッシュされた現在の予測。新データが届くと無効化される。
    private var _cachedLayout: ScreenLayout?

    private init() {}

    // MARK: - Public API

    /// Record a single mouse-movement delta. Thread-safe; hot path.
    /// 単一のマウス移動デルタを記録する。スレッドセーフ、ホットパス。
    func recordMovement(dx: Double, dy: Double) {
        queue.async { [weak self] in
            self?.recordMovementLocked(dx: dx, dy: dy)
        }
    }

    /// The most recent screen-layout prediction, or `nil` if insufficient data.
    /// 最新の画面レイアウト予測。データ不足の場合は `nil`。
    var currentLayout: ScreenLayout? {
        queue.sync {
            if let cached = _cachedLayout { return cached }
            let layout = buildPredictionLocked()
            _cachedLayout = layout
            return layout
        }
    }

    /// Reset all collected data. Useful for testing.
    /// 収集データをすべてリセットする。テスト用。
    func reset() {
        queue.sync {
            positions.removeAll(keepingCapacity: true)
            crossMonitorJumpCount = 0
            totalEventCount = 0
            _cachedLayout = nil
        }
    }

    // MARK: - Hot-path accumulation (called on `queue`)

    private func recordMovementLocked(dx: Double, dy: Double) {
        // Use the actual NSEvent mouse location (main thread would be needed for NSEvent,
        // so we reconstruct the position from deltas as an approximation).
        // NSEvent.mouseLocation はメインスレッドが必要なため、デルタから位置を再構成する。
        let lastPos = positions.last ?? CGPoint(x: 0, y: 0)
        let newPos = CGPoint(x: lastPos.x + dx, y: lastPos.y - dy) // dy inverted: screen coords

        // Detect cross-monitor jump: very large horizontal displacement with small vertical.
        // 画面跨ぎジャンプを検出: 大きい水平変位かつ垂直変位が小さい場合。
        if abs(dx) > crossMonitorJumpThreshold && abs(dy) < 50 {
            crossMonitorJumpCount += 1
            // Do NOT add the jump position as a regular sample to avoid polluting bounds.
            _cachedLayout = nil
            return
        }

        positions.append(newPos)
        if positions.count > maxSamples {
            positions.removeFirst(positions.count - maxSamples)
        }

        totalEventCount += 1
        _cachedLayout = nil // Invalidate cache on new data.
    }

    // MARK: - Prediction engine (called on `queue`)

    private func buildPredictionLocked() -> ScreenLayout? {
        guard positions.count >= minimumSamples else { return nil }

        // Step 1: Compute bounding rectangle of observed positions.
        // ステップ1: 観測された位置の外接矩形を計算する。
        var minX = Double.infinity, maxX = -Double.infinity
        var minY = Double.infinity, maxY = -Double.infinity
        for p in positions {
            minX = min(minX, Double(p.x)); maxX = max(maxX, Double(p.x))
            minY = min(minY, Double(p.y)); maxY = max(maxY, Double(p.y))
        }
        let observedWidth  = maxX - minX
        let observedHeight = maxY - minY

        // Step 2: Determine monitor count from cross-monitor jumps.
        // ステップ2: 画面跨ぎジャンプからモニター数を決定する。
        let estimatedMonitorCount: Int
        if crossMonitorJumpCount >= 50 {
            // Frequent jumps suggest ≥3 monitors.
            estimatedMonitorCount = 3
        } else if crossMonitorJumpCount >= 10 {
            // Moderate jumps → likely dual monitor.
            estimatedMonitorCount = 2
        } else {
            estimatedMonitorCount = 1
        }

        // Step 3: Estimate primary display bounds.
        // ステップ3: プライマリディスプレイの範囲を推定する。
        // Snap to the nearest common resolution if the observed size is close.
        // 観測サイズが近い場合は一般的な解像度にスナップする。
        let snappedWidth  = snapToCommonResolutionWidth(observedWidth / Double(estimatedMonitorCount))
        let snappedHeight = snapToCommonResolutionHeight(observedHeight)

        let primaryBounds = CGRect(
            x: minX, y: minY,
            width: snappedWidth,
            height: snappedHeight
        )

        // Step 4: Estimate secondary bounds for multi-monitor setups.
        // ステップ4: マルチモニター構成のセカンダリ範囲を推定する。
        var secondaryBounds: [CGRect] = []
        if estimatedMonitorCount >= 2 {
            // Assume monitors are arranged horizontally (most common arrangement).
            // モニターが水平方向に配置されていると仮定（最も一般的な配置）。
            secondaryBounds.append(CGRect(
                x: primaryBounds.maxX, y: primaryBounds.minY,
                width: snappedWidth, height: snappedHeight
            ))
        }
        if estimatedMonitorCount >= 3 {
            secondaryBounds.append(CGRect(
                x: primaryBounds.minX - snappedWidth, y: primaryBounds.minY,
                width: snappedWidth, height: snappedHeight
            ))
        }

        // Step 5: Compute confidence based on sample size and jump consistency.
        // ステップ5: サンプル数とジャンプの一貫性に基づいて信頼スコアを計算する。
        let sampleFactor  = min(1.0, Double(positions.count) / Double(maxSamples))
        let coverageFactor = min(1.0, (observedWidth * observedHeight) / (snappedWidth * snappedHeight))
        let confidence = (sampleFactor * 0.5 + coverageFactor * 0.5)

        return ScreenLayout(
            monitorCount: estimatedMonitorCount,
            estimatedPrimaryBounds: primaryBounds,
            estimatedSecondaryBounds: secondaryBounds,
            confidence: confidence
        )
    }

    // MARK: - Resolution helpers

    /// Common display widths in points (at 1x scale factor).
    /// 一般的なディスプレイ幅（1x スケールファクターでのポイント数）。
    private static let commonWidths: [Double] = [
        1280, 1366, 1440, 1512, 1680, 1728, 1920, 2048, 2560, 3024, 3072, 3456, 5120
    ]

    /// Common display heights in points.
    /// 一般的なディスプレイ高（ポイント数）。
    private static let commonHeights: [Double] = [
        720, 768, 800, 900, 960, 1050, 1080, 1120, 1152, 1200, 1440, 1600, 1800, 2160
    ]

    private func snapToCommonResolutionWidth(_ width: Double) -> Double {
        guard width > 0 else { return 1920 }
        return Self.commonWidths.min(by: { abs($0 - width) < abs($1 - width) }) ?? width
    }

    private func snapToCommonResolutionHeight(_ height: Double) -> Double {
        guard height > 0 else { return 1080 }
        return Self.commonHeights.min(by: { abs($0 - height) < abs($1 - height) }) ?? height
    }
}

// MARK: - MouseStore integration

extension ScreenLayoutPredictor {
    /// Feed the predictor from a raw mouse-event delta.
    /// Designed to be called alongside `MouseStore.shared.addMovement(dx:dy:)`.
    ///
    /// 生のマウスイベントデルタから予測器にデータを供給する。
    /// `MouseStore.shared.addMovement(dx:dy:)` と並行して呼び出すことを想定。
    static func feedMovement(dx: Double, dy: Double) {
        shared.recordMovement(dx: dx, dy: dy)
    }
}

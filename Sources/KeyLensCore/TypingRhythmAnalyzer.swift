import Foundation

/// Describes the detected rhythm pattern of recent typing.
/// 直近の打鍵リズムのパターン。
public enum TypingRhythm: String, Codable, CaseIterable {
    /// Short intense bursts separated by longer pauses.
    /// 短い集中打鍵と長い休止が交互に現れる。
    case burst

    /// Consistent, even cadence with low interval variance.
    /// 変動が小さく、一定のペースで打鍵している。
    case steadyFlow

    /// Moderate variance — neither clearly burst nor steady.
    /// バーストでも定常でもない中間的なリズム。
    case balanced

    /// Insufficient samples to classify.
    /// サンプル不足で判定不可。
    case unknown
}

/// Classifies typing rhythm from a sequence of inter-keystroke intervals (ms).
/// IKI (キー間隔) の系列からタイピングリズムを分類するエンジン。
///
/// Uses coefficient of variation (CV = σ/μ):
///   CV < 0.45  → steadyFlow
///   CV < 0.85  → balanced
///   CV ≥ 0.85  → burst
public struct TypingRhythmAnalyzer {

    public init() {}

    /// Minimum number of valid (non-zero) IKI samples required for classification.
    public static let minimumSamples = 10

    /// Infers the typing rhythm from recent IKI samples.
    /// ゼロ（セッション区切り）を除外した有効サンプルから分類する。
    public func analyze(ikis: [Double]) -> TypingRhythm {
        let samples = ikis.filter { $0 > 0 && $0 <= 1000 }
        guard samples.count >= Self.minimumSamples else { return .unknown }

        let mean = samples.reduce(0, +) / Double(samples.count)
        guard mean > 0 else { return .unknown }

        let variance = samples.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(samples.count)
        let cv = variance.squareRoot() / mean

        switch cv {
        case ..<0.45: return .steadyFlow
        case ..<0.85: return .balanced
        default:      return .burst
        }
    }
}

// Configuration.swift
// Centralizes tuning constants used across the app.
// Change a value here to affect all callsites simultaneously.

enum AppConfiguration {

    // MARK: - Input tracking

    /// Maximum inter-keystroke interval (ms) included in WPM / Welford averaging.
    /// Gaps longer than this are treated as typing pauses and excluded.
    static let ikiCutoffMs: Double = 1000

    // MARK: - Persistence

    /// How often in-memory data is flushed to SQLite (seconds).
    static let flushIntervalSecs: Double = 30

    // MARK: - Accessibility & monitoring

    /// How often to retry the accessibility-permission check (seconds).
    static let permissionRetryIntervalSecs: Double = 3.0

    /// How often the health-check timer verifies the keyboard monitor is running (seconds).
    static let healthCheckIntervalSecs: Double = 5.0

    // MARK: - WPM / speedometer

    /// If no keystroke arrives within this window the rolling WPM returns 0 (idle decay).
    static let wpmIdleDecaySecs: Double = 1.5

    /// Timer interval for live UI refreshes (speedometer, IKI ring buffer).
    static let liveRefreshIntervalSecs: Double = 0.5

    /// Minimum gap between keystrokes before the speedometer updates its displayed WPM.
    static let speedometerKeystrokeCooldownSecs: Double = 0.3

    // MARK: - Charts

    /// How often the fatigue curve in the charts window refreshes (seconds).
    static let fatigueRefreshIntervalSecs: Double = 10

    // MARK: - Performance profiling (Issue #287)

    /// How often aggregated performance metrics are flushed to app.log (seconds).
    static let perfLogIntervalSecs: Double = 30

    /// Max number of in-memory samples per metric before percentile fallback.
    static let perfSampleCapPerMetric: Int = 512
}

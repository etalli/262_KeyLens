import UserNotifications

/// Fires a break reminder notification after a configurable typing idle interval.
/// 設定した無操作時間が経過したら休憩リマインダー通知を発火するシングルトン。
final class BreakReminderManager {
    static let shared = BreakReminderManager()

    private static let enabledKey  = "breakReminderEnabled"
    private static let intervalKey = "breakReminderIntervalMinutes"
    static let defaultMinutes      = 30

    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.keylens.breakreminder")
    private var lastDidTypeAt: Date = .distantPast

    /// Whether break reminders are enabled. Persisted in UserDefaults.
    /// 休憩リマインダーが有効かどうか。UserDefaults に永続化。
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            newValue ? resetTimer() : cancelTimer()
        }
    }

    /// Idle interval in minutes before the reminder fires (default: 30).
    /// リマインダーが発火するまでの無操作時間（分）。デフォルト: 30。
    var intervalMinutes: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: Self.intervalKey)
            return v > 0 ? v : Self.defaultMinutes
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.intervalKey)
            if isEnabled { resetTimer() }
        }
    }

    private init() {
        if isEnabled { resetTimer() }
    }

    /// Call on every keystroke or mouse click to reset the idle countdown.
    /// キーストローク・クリックごとに呼び出して、アイドルカウントダウンをリセットする。
    func didType() {
        guard isEnabled else { return }
        let now = Date()
        guard now.timeIntervalSince(lastDidTypeAt) > 5 else { return }
        lastDidTypeAt = now
        resetTimer()
    }

    // MARK: - Private

    private func resetTimer() {
        cancelTimer()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + .seconds(intervalMinutes * 60))
        t.setEventHandler { [weak self] in self?.fireNotification() }
        t.resume()
        timer = t
    }

    private func cancelTimer() {
        timer?.cancel()
        timer = nil
    }

    private func fireNotification() {
        let content = UNMutableNotificationContent()
        content.title = L10n.shared.breakReminderTitle
        content.body  = L10n.shared.breakReminderBody(minutes: intervalMinutes)
        content.sound = .default

        // Use a fixed identifier so repeated reminders replace each other.
        // 同じ identifier を使うことで、重複通知が上書きされる。
        let request = UNNotificationRequest(
            identifier: "com.keylens.breakReminder",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error { KeyLens.log("break reminder send error: \(error)") }
        }
    }
}

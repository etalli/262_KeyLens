import UserNotifications

/// macOS 通知を発行するシングルトン
final class NotificationManager {
    static let shared = NotificationManager()

    private init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            KeyStat.log("notification auth — granted: \(granted), error: \(error?.localizedDescription ?? "none")")
        }
    }

    /// 指定キーがマイルストーン（1000の倍数）に達した通知を送る
    func notify(key: String, count: Int) {
        KeyStat.log("notify() called — key: \(key), count: \(count)")
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            KeyStat.log("notification authorizationStatus: \(settings.authorizationStatus.rawValue)")
        }

        let content = UNMutableNotificationContent()
        content.title = "⌨️ KeyStat"
        content.body = L10n.shared.notificationBody(key: key, count: count)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil   // trigger=nil で即時配信
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                KeyStat.log("notification send error: \(error.localizedDescription)")
            } else {
                KeyStat.log("notification queued successfully")
            }
        }
    }
}

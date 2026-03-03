import UserNotifications
import Foundation

class NotificationManager {
    static let shared = NotificationManager()

    func requestPermission() async {
        try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    func scheduleNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let content = UNMutableNotificationContent()
        content.title = "NAR Check-in"
        content.body = "How are you feeling?"
        content.sound = .default

        for (hour, minute) in Constants.notificationTimes {
            var components = DateComponents()
            components.hour = hour
            components.minute = minute

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: true
            )
            let request = UNNotificationRequest(
                identifier: "checkin-\(hour)-\(minute)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }
}

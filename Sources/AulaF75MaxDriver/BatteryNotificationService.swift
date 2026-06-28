import Foundation
import UserNotifications

@MainActor
final class BatteryNotificationService {
    static let shared = BatteryNotificationService()

    private let lowBatteryThreshold = 20
    private var didRequestAuthorization = false

    private init() {}

    func requestAuthorization() {
        guard !didRequestAuthorization else { return }
        didRequestAuthorization = true

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error {
                NSLog("Battery notification authorization failed: \(error.localizedDescription)")
            }
        }
    }

    func handleBatteryUpdate(previousPercent: Int?, currentPercent: Int?) {
        guard let currentPercent, currentPercent <= lowBatteryThreshold else { return }

        if let previousPercent, previousPercent <= lowBatteryThreshold {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = L10n.text("Aula F75 Max battery low")
        content.body = L10n.format("Battery is at %d%%.", currentPercent)
        content.sound = .default
        content.userInfo = [
            "batteryPercent": currentPercent
        ]

        let request = UNNotificationRequest(
            identifier: "aula-f75-max-battery-low",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}

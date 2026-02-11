import SwiftUI
import UserNotifications
import UserNotifications
@main
struct YourApp: App {
    init() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
                print("notif:", ok)
            }
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }


    private func requestNotificationPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                print("Notification permission:", granted)
            }
    }
}

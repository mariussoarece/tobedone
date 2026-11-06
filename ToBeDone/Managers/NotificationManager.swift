//
//  NotificationManager.swift
//  ToBeDone
//

import SwiftUI
import UserNotifications

// MARK: - Notification Manager
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    func requestPermission() {
        // Lets notifications appear as a banner even while the app is open
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
            print("Granted: \(granted)")
        }
    }

    func scheduleNotification(for task: TaskModel) {
        // Nothing to remind about for finished tasks or times already in the past
        guard !task.isCompleted, task.dueDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Task Reminder"
        content.body = "Don't forget: \(task.title) is due now!"
        content.sound = .default
        content.interruptionLevel = .active

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: task.dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelNotification(for task: TaskModel) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [task.id.uuidString])
    }
    /// Show banners, sound and keep the notification in Notification Center
    /// when it arrives while the app is on screen (iOS hides them otherwise).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("Authorization:", settings.authorizationStatus.rawValue)
            print("Alert:", settings.alertSetting.rawValue)
            print("Sound:", settings.soundSetting.rawValue)
            print("Badge:", settings.badgeSetting.rawValue)
        }
    }

}

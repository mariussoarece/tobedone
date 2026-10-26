//
//  NotificationManager.swift
//  ToBeDone
//

import SwiftUI
import UserNotifications

// MARK: - Notification Manager
class NotificationManager {
    static let shared = NotificationManager()
    @AppStorage("reminderHour") private var reminderHour: Int = 22
    @AppStorage("reminderMinute") private var reminderMinute: Int = 0
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
            print("Granted: \(granted)")
        }
    }

    func scheduleNotification(for task: TaskModel) {
        let content = UNMutableNotificationContent()
        content.title = "Task Reminder"
        content.body = "Don't forget: \(task.title) is due today!"
        content.sound = .default

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: task.dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelNotification(for task: TaskModel) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [task.id.uuidString])
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

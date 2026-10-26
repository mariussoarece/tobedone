//
//  ActivityReminderScheduler.swift
//  ToBeDone
//

import Foundation
import SwiftData
import UserNotifications

/// Schedules the repeating "Daily Activity Reminder" notification.
/// The reminder is only active after the user has picked a time in Settings.
enum ActivityReminderScheduler {
    static let identifier = "activityReminder"
    static let enabledKey = "activityReminderEnabled"

    /// Re-creates the reminder with the current list of unfinished activities.
    @MainActor
    static func refresh(context: ModelContext) {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: enabledKey) else { return }

        let hour = defaults.object(forKey: "reminderHour") as? Int ?? 22
        let minute = defaults.object(forKey: "reminderMinute") as? Int ?? 0

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Daily Activity Reminder"
        content.body = incompleteActivitiesMessage(context: context)
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: hour, minute: minute),
            repeats: true
        )
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    @MainActor
    private static func incompleteActivitiesMessage(context: ModelContext) -> String {
        let items = (try? context.fetch(FetchDescriptor<ActivityItem>())) ?? []
        let incomplete = items.filter {
            !$0.isCompleted && Calendar.current.isDateInToday($0.date)
        }

        if incomplete.isEmpty {
            return "All activities completed today. Great job!"
        }

        let bullets = incomplete.map { "• \($0.name)" }.joined(separator: "\n")
        return "You still have activities to complete:\n\(bullets)"
    }
}

//
//  ReminderScheduler.swift
//  ToBeDone
//
//  Schedules two kinds of notifications:
//  • Daily summary (default 21:00, set in Settings): lists that day's unfinished
//    tasks and Daily Routine activities. Days where everything is done get no notification.
//  • Activity start: one notification when each Daily Routine activity begins.
//
//  iOS can't check your data at 21:00 by itself, so the next 7 days are prepared in
//  advance and rebuilt whenever something changes or the app is opened.
//

import Foundation
import SwiftData
import UserNotifications

enum ReminderScheduler {
    // Settings keys (shared with SettingsView via @AppStorage)
    static let summaryEnabledKey = "dailySummaryEnabled"
    static let activityStartEnabledKey = "activityStartEnabled"
    static let hourKey = "reminderHour"
    static let minuteKey = "reminderMinute"
    static let defaultHour = 21
    static let defaultMinute = 0

    private static let summaryPrefix = "dailySummary-"
    private static let activityPrefix = "activityStart-"
    private static let legacyIdentifier = "activityReminder"   // repeating reminder from older versions
    private static let daysAhead = 7
    private static let maxActivityAlerts = 40                  // iOS keeps at most 64 pending notifications

    /// Rebuilds all summary and activity-start notifications from the current data.
    @MainActor
    static func refresh(context: ModelContext) {
        let defaults = UserDefaults.standard
        let summaryOn = defaults.object(forKey: summaryEnabledKey) as? Bool ?? true
        let activityOn = defaults.object(forKey: activityStartEnabledKey) as? Bool ?? true
        let hour = defaults.object(forKey: hourKey) as? Int ?? defaultHour
        let minute = defaults.object(forKey: minuteKey) as? Int ?? defaultMinute

        let tasks = (try? context.fetch(FetchDescriptor<TaskModel>())) ?? []
        let activities = (try? context.fetch(FetchDescriptor<ActivityItem>())) ?? []

        var requests: [UNNotificationRequest] = []
        if summaryOn {
            requests += summaryRequests(tasks: tasks, activities: activities, hour: hour, minute: minute)
        }
        if activityOn {
            requests += activityStartRequests(activities: activities)
        }

        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let old = pending.map(\.identifier).filter {
                $0.hasPrefix(summaryPrefix) || $0.hasPrefix(activityPrefix) || $0 == legacyIdentifier
            }
            center.removePendingNotificationRequests(withIdentifiers: old)
            for request in requests {
                center.add(request)
            }
        }
    }

    // MARK: - Daily summary

    private static func summaryRequests(tasks: [TaskModel], activities: [ActivityItem],
                                        hour: Int, minute: Int) -> [UNNotificationRequest] {
        let cal = Calendar.current
        let now = Date()
        var result: [UNNotificationRequest] = []

        for offset in 0..<daysAhead {
            guard let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now)),
                  let fireDate = cal.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  fireDate > now,
                  let endOfDay = cal.date(byAdding: .day, value: 1, to: day) else { continue }

            // Unfinished tasks due that day (or earlier and still open) and that day's unfinished activities
            let openTasks = tasks.filter { !$0.isCompleted && $0.dueDate < endOfDay }
                .sorted { $0.dueDate < $1.dueDate }
            let openActivities = activities.filter { !$0.isCompleted && cal.isDate($0.date, inSameDayAs: day) }
                .sorted { $0.date < $1.date }

            guard !openTasks.isEmpty || !openActivities.isEmpty else { continue }   // all done: no notification

            let content = UNMutableNotificationContent()
            content.title = "Not finished yet"
            content.body = summaryText(tasks: openTasks, activities: openActivities)
            content.sound = .default
            content.threadIdentifier = "daily-summary"
            content.interruptionLevel = .active   // shows on Lock Screen, Notification Center and as a banner

            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let id = summaryPrefix + fireDate.formatted(.iso8601.year().month().day())
            result.append(UNNotificationRequest(
                identifier: id,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            ))
        }
        return result
    }

    private static func summaryText(tasks: [TaskModel], activities: [ActivityItem]) -> String {
        var parts: [String] = []
        if !tasks.isEmpty { parts.append("\(tasks.count) task\(tasks.count == 1 ? "" : "s")") }
        if !activities.isEmpty { parts.append("\(activities.count) activit\(activities.count == 1 ? "y" : "ies")") }

        let names = tasks.map(\.title) + activities.map(\.name)
        let shown = names.prefix(5).map { "• \($0)" }
        var lines = ["You still have \(parts.joined(separator: " and ")) to complete:"] + shown
        if names.count > shown.count {
            lines.append("+ \(names.count - shown.count) more")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Activity start

    private static func activityStartRequests(activities: [ActivityItem]) -> [UNNotificationRequest] {
        let cal = Calendar.current
        let now = Date()
        guard let limit = cal.date(byAdding: .day, value: daysAhead, to: now) else { return [] }

        let upcoming = activities
            .filter { !$0.isCompleted && $0.date > now && $0.date < limit }
            .sorted { $0.date < $1.date }
            .prefix(maxActivityAlerts)

        return upcoming.map { item in
            let content = UNMutableNotificationContent()
            content.title = "Starting now: \(item.name)"
            var body: [String] = []
            if item.durationMinutes > 0 { body.append("\(item.durationMinutes) min") }
            if !item.details.isEmpty { body.append(item.details) }
            content.body = body.isEmpty ? "Time for your activity." : body.joined(separator: " · ")
            content.sound = .default
            content.threadIdentifier = "activity-start"
            content.interruptionLevel = .active

            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: item.date)
            return UNNotificationRequest(
                identifier: activityPrefix + item.id.uuidString,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            )
        }
    }
}

//
//  ReminderScheduler.swift
//  ToBeDone
//
//  Schedules these notifications (To Do due-time reminders are set by NotificationManager):
//  • Daily summary (default 21:00, set in Settings): lists that day's unfinished
//    tasks and Daily Routine activities. Days where everything is done get no notification.
//  • Activity start: one notification when each Daily Routine activity begins.
//  • Monthly expense: every month on its day (1–28) and time (default 10:00).
//  • Early reminder ("Remind me before") for To Do tasks and Daily Routine activities:
//    "Gym is starting in 2 days and 30 min".
//
//  iOS can't check your data at 21:00 by itself, so the next 7 days are prepared in
//  advance and rebuilt whenever something changes or the app is opened.
//  It also refreshes the home-screen widget, since it runs after every change.
//

import Foundation
import SwiftData
import UserNotifications

enum ReminderScheduler {
    /// A notification to schedule and when it fires first (used to keep the soonest ones)
    private struct Pending {
        let fire: Date
        let request: UNNotificationRequest
    }

    // Settings keys (shared with SettingsView via @AppStorage)
    static let summaryEnabledKey = "dailySummaryEnabled"
    static let activityStartEnabledKey = "activityStartEnabled"
    static let hourKey = "reminderHour"
    static let minuteKey = "reminderMinute"
    static let defaultHour = 21
    static let defaultMinute = 0

    private static let summaryPrefix = "dailySummary-"
    private static let activityPrefix = "activityStart-"
    private static let monthlyPrefix = "monthly-"
    private static let taskEarlyPrefix = "taskEarly-"
    private static let activityEarlyPrefix = "activityEarly-"
    private static var managedPrefixes: [String] {
        [summaryPrefix, activityPrefix, monthlyPrefix, taskEarlyPrefix, activityEarlyPrefix]
    }
    private static let legacyIdentifier = "activityReminder"   // repeating reminder from older versions
    private static let daysAhead = 7
    private static let maxActivityAlerts = 40
    private static let earlyDaysAhead = 60
    /// iOS keeps at most 64 pending notifications. To Do due-time reminders use the
    /// rest; if there are more than this, the ones coming up soonest are kept.
    private static let maxManaged = 48

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
        let monthly = (try? context.fetch(FetchDescriptor<MonthlyTaskModel>())) ?? []

        // Keep the home-screen widget in step with the data (the latest Confidence
        // score sets the smiley in the widget's background)
        var latestConfidence = FetchDescriptor<ConfidenceEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        latestConfidence.fetchLimit = 1
        let confidence = (try? context.fetch(latestConfidence))?.first?.score
        WidgetData.write(tasks: tasks, monthly: monthly, activities: activities, confidence: confidence)

        // Not while taking App Store screenshots
        guard !DemoData.isEnabled else { return }

        var requests: [Pending] = []
        if summaryOn {
            requests += summaryRequests(tasks: tasks, activities: activities, hour: hour, minute: minute)
        }
        if activityOn {
            requests += activityStartRequests(activities: activities)
        }
        requests += monthlyRequests(monthly: monthly)
        requests += earlyRequests(tasks: tasks, activities: activities)

        // Soonest first, within what iOS allows
        let chosen = requests.sorted { $0.fire < $1.fire }.prefix(maxManaged).map(\.request)

        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let old = pending.map(\.identifier).filter { id in
                managedPrefixes.contains { id.hasPrefix($0) } || id == legacyIdentifier
            }
            center.removePendingNotificationRequests(withIdentifiers: old)
            for request in chosen {
                center.add(request)
            }
        }
    }

    // MARK: - Daily summary

    private static func summaryRequests(tasks: [TaskModel], activities: [ActivityItem],
                                        hour: Int, minute: Int) -> [Pending] {
        let cal = Calendar.current
        let now = Date()
        var result: [Pending] = []

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
            result.append(Pending(fire: fireDate, request: UNNotificationRequest(
                identifier: id,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            )))
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

    private static func activityStartRequests(activities: [ActivityItem]) -> [Pending] {
        let cal = Calendar.current
        let now = Date()
        guard let limit = cal.date(byAdding: .day, value: daysAhead, to: now) else { return [] }

        let upcoming = activities
            .filter { !$0.isCompleted && $0.date > now && $0.date < limit }
            .sorted { $0.date < $1.date }
            .prefix(maxActivityAlerts)

        return upcoming.map { item -> Pending in
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
            return Pending(fire: item.date, request: UNNotificationRequest(
                identifier: activityPrefix + item.id.uuidString,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            ))
        }
    }

    // MARK: - Monthly expenses

    /// One repeating notification per expense: every month on its day and time.
    private static func monthlyRequests(monthly: [MonthlyTaskModel]) -> [Pending] {
        let currency = UserDefaults.standard.string(forKey: "selectedCurrency") ?? "USD"
        return monthly.compactMap { m -> Pending? in
            guard let day = m.dayOfMonth, let next = m.nextOccurrence() else { return nil }
            let content = UNMutableNotificationContent()
            content.title = "Monthly expense"
            let amount = m.price > 0
                ? " (\(m.price.formatted(.number.precision(.fractionLength(2)))) \(currency))" : ""
            content.body = "\(m.title)\(amount) is due today."
            content.sound = .default
            content.threadIdentifier = "monthly-expense"
            content.interruptionLevel = .active

            let comps = DateComponents(day: day, hour: m.hour, minute: m.minute)
            return Pending(fire: next, request: UNNotificationRequest(
                identifier: monthlyPrefix + m.id.uuidString,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            ))
        }
    }

    // MARK: - Early reminders ("Remind me before")

    private static func earlyRequests(tasks: [TaskModel], activities: [ActivityItem]) -> [Pending] {
        let now = Date()
        let limit = now.addingTimeInterval(TimeInterval(earlyDaysAhead * 24 * 60 * 60))
        var result: [Pending] = []

        for t in tasks where !t.isCompleted {
            guard let minutes = t.reminderMinutes, minutes > 0 else { continue }
            let fire = t.dueDate.addingTimeInterval(TimeInterval(-minutes * 60))
            guard fire > now, fire < limit else { continue }
            result.append(Pending(fire: fire, request: earlyRequest(id: taskEarlyPrefix + t.id.uuidString,
                                              title: t.title, minutes: minutes, fire: fire,
                                              thread: "task-early")))
        }
        for a in activities where !a.isCompleted {
            guard let minutes = a.reminderMinutes, minutes > 0 else { continue }
            let fire = a.date.addingTimeInterval(TimeInterval(-minutes * 60))
            guard fire > now, fire < limit else { continue }
            result.append(Pending(fire: fire, request: earlyRequest(id: activityEarlyPrefix + a.id.uuidString,
                                              title: a.name, minutes: minutes, fire: fire,
                                              thread: "activity-early")))
        }
        return result
    }

    private static func earlyRequest(id: String, title: String, minutes: Int, fire: Date,
                                     thread: String) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Coming up"
        // "Gym is starting in 2 days and 30 min" / "Gym is starting in 45 min"
        content.body = "\(title) is starting in \(Agenda.describeMinutes(minutes))."
        content.sound = .default
        content.threadIdentifier = thread
        content.interruptionLevel = .active

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        return UNNotificationRequest(identifier: id, content: content,
                                     trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
    }
}

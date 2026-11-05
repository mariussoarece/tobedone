//
//  WidgetData.swift
//  ToBeDone
//
//  The home-screen widget runs separately from the app and can't open the
//  database, so after every change the app writes the next 7 days of To Do,
//  Monthly Expense and Daily Routine items to a small file in the shared
//  App Group folder. The widget reads that file.
//
//  Needs the App Group "group.ro.vishrama.tobedone" on both the app and the
//  widget target (Signing & Capabilities). Without it, nothing is written and
//  the app works as before.
//

import Foundation
import WidgetKit

/// Same layout as `WidgetSnapshot` in the widget's TodayWidget.swift.
struct WidgetSnapshot: Codable {
    struct Item: Codable {
        var kind: String          // "task", "monthly", "activity"
        var title: String
        var start: Date
        var durationMinutes: Int
        var done: Bool
        var detail: String
    }
    var generatedAt: Date
    var items: [Item]
}

enum WidgetData {
    static let appGroup = "group.ro.vishrama.tobedone"
    static let fileName = "widget-agenda.json"
    private static let daysAhead = 7

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appending(path: fileName)
    }

    @MainActor
    static func write(tasks: [TaskModel], monthly: [MonthlyTaskModel], activities: [ActivityItem]) {
        guard !DemoData.isEnabled, let url = fileURL else { return }
        let cal = Calendar.current
        let currency = UserDefaults.standard.string(forKey: "selectedCurrency") ?? "USD"
        let today = cal.startOfDay(for: .now)

        var items: [WidgetSnapshot.Item] = []
        for offset in 0..<daysAhead {
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            for a in Agenda.forDay(day, tasks: tasks, monthly: monthly, activities: activities, calendar: cal) {
                items.append(.init(kind: a.kind.rawValue, title: a.title, start: a.start,
                                   durationMinutes: a.durationMinutes, done: a.done,
                                   detail: a.detail(currency: currency)))
            }
        }

        let snapshot = WidgetSnapshot(generatedAt: .now, items: items)
        do {
            let data = try JSONEncoder().encode(snapshot)
            // Only rewrite (and redraw the widget) when something actually changed
            if let old = try? Data(contentsOf: url),
               let oldSnapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: old),
               oldSnapshot.items.count == items.count,
               (try? JSONEncoder().encode(oldSnapshot.items)) == (try? JSONEncoder().encode(items)) {
                return
            }
            try data.write(to: url, options: .atomic)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("Widget data error:", error)
        }
    }
}

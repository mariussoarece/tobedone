//
//  Agenda.swift
//  ToBeDone
//
//  Everything happening on a given day: To Do tasks, Monthly Expenses and
//  Daily Routine activities, ordered by time. Used by the Today card on Home,
//  the weekly view and the home-screen widget.
//

import SwiftUI

enum AgendaKind: String, Codable {
    case task, monthly, activity

    var color: Color {
        switch self {
        case .task: return .blue
        case .monthly: return .orange
        case .activity: return .indigo
        }
    }

    var label: String {
        switch self {
        case .task: return "To Do"
        case .monthly: return "Monthly expense"
        case .activity: return "Daily Routine"
        }
    }
}

struct AgendaItem: Identifiable, Hashable {
    let kind: AgendaKind
    let modelID: UUID
    let title: String
    let start: Date
    var durationMinutes: Int = 0     // only activities have a duration
    var done: Bool = false           // monthly expenses: paid this month
    var price: Double? = nil         // monthly expenses

    var id: String { "\(kind.rawValue)-\(modelID.uuidString)-\(start.timeIntervalSince1970)" }
    var end: Date { start.addingTimeInterval(TimeInterval(durationMinutes * 60)) }

    /// "Monthly expense · 650 EUR", "Daily Routine · 30 min", "To Do"
    func detail(currency: String) -> String {
        switch kind {
        case .task:
            return kind.label
        case .monthly:
            guard let price, price > 0 else { return kind.label }
            return "\(kind.label) · \(price.formatted(.number.precision(.fractionLength(0...2)))) \(currency)"
        case .activity:
            return durationMinutes > 0 ? "\(kind.label) · \(durationMinutes) min" : kind.label
        }
    }
}

enum Agenda {

    /// Everything scheduled on `day`, ordered by time.
    static func forDay(_ day: Date,
                       tasks: [TaskModel],
                       monthly: [MonthlyTaskModel],
                       activities: [ActivityItem],
                       calendar cal: Calendar = .current) -> [AgendaItem] {
        var items: [AgendaItem] = []

        for t in tasks where cal.isDate(t.dueDate, inSameDayAs: day) {
            items.append(AgendaItem(kind: .task, modelID: t.id, title: t.title,
                                    start: t.dueDate, done: t.isCompleted))
        }
        for m in monthly {
            if let at = m.occurrence(on: day, calendar: cal) {
                items.append(AgendaItem(kind: .monthly, modelID: m.id, title: m.title,
                                        start: at, done: m.isPaid(in: day, calendar: cal), price: m.price))
            }
        }
        for a in activities where cal.isDate(a.date, inSameDayAs: day) {
            items.append(AgendaItem(kind: .activity, modelID: a.id, title: a.name, start: a.date,
                                    durationMinutes: a.durationMinutes, done: a.isCompleted))
        }
        return items.sorted { $0.start < $1.start }
    }

    /// "10:00" in the user's own 12/24-hour style
    static func timeText(hour: Int, minute: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// Human-readable length of time: "45 min", "2 h and 15 min",
    /// "1 day and 30 min", "3 days, 2 h and 5 min".
    static func describeMinutes(_ totalMinutes: Int) -> String {
        let total = max(totalMinutes, 0)
        let days = total / (24 * 60)
        let hours = (total % (24 * 60)) / 60
        let minutes = total % 60
        var parts: [String] = []
        if days > 0 { parts.append("\(days) day" + (days == 1 ? "" : "s")) }
        if hours > 0 { parts.append("\(hours) h") }
        if minutes > 0 || parts.isEmpty { parts.append("\(minutes) min") }
        switch parts.count {
        case 1: return parts[0]
        case 2: return "\(parts[0]) and \(parts[1])"
        default: return "\(parts[0]), \(parts[1]) and \(parts[2])"
        }
    }
}

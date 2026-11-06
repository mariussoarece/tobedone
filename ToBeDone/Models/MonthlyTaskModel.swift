//
//  MonthlyTaskModel.swift
//  ToBeDone
//
//  A Monthly Expense repeats every month on `dayOfMonth` (1–28, so the day exists
//  in every month) at `hour`:`minute` (default 10:00). A reminder is sent then.
//  The new fields are optional, so existing data opens without any migration
//  problem; older items simply have no day yet.
//

import SwiftUI
import SwiftData

@Model
class MonthlyTaskModel: Identifiable {
    var id: UUID = UUID()         // Important for identifying items in the list
    var title: String
    var price: Double
    /// 1–28, or nil for items created before days existed
    var dayOfMonth: Int? = nil
    /// Minutes after midnight; nil means the default 10:00
    var timeOfDayMinutes: Int? = nil

    init(title: String, price: Double = 0.0, dayOfMonth: Int? = nil, hour: Int = 10, minute: Int = 0) {
        self.title = title
        self.price = price
        self.dayOfMonth = dayOfMonth.map { min(max($0, 1), 28) }
        self.timeOfDayMinutes = hour * 60 + minute
    }

    var hour: Int { (timeOfDayMinutes ?? 600) / 60 }      // 600 min = 10:00
    var minute: Int { (timeOfDayMinutes ?? 600) % 60 }

    /// "Every month on day 5 at 10:00", or nil when no day is set
    var scheduleText: String? {
        guard let day = dayOfMonth else { return nil }
        return "Every month on day \(day) at \(Agenda.timeText(hour: hour, minute: minute))"
    }

    /// When it happens on `day`, or nil if it isn't due that day.
    func occurrence(on day: Date, calendar cal: Calendar = .current) -> Date? {
        guard let d = dayOfMonth, cal.component(.day, from: day) == d else { return nil }
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }

    /// The next time its day and time come round after `now`.
    func nextOccurrence(after now: Date = .now, calendar cal: Calendar = .current) -> Date? {
        guard let d = dayOfMonth else { return nil }
        let comps = DateComponents(day: d, hour: hour, minute: minute, second: 0)
        return cal.nextDate(after: now, matching: comps, matchingPolicy: .nextTime)
    }
}

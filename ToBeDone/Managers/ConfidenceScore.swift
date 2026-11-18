//
//  ConfidenceScore.swift
//  ToBeDone
//
//  Same rules as the Android version (2.8–2.9):
//  • Each day gets a score (done ÷ total × 10) from that day's Daily Routine
//    activities, To Do tasks and Monthly Expenses (done = paid for that month).
//    It's saved as a Confidence entry tagged "activities". Days that haven't
//    come yet get no score. Ratings you save yourself are never touched.
//  • A day's Confidence level is the average of that score and the ratings you
//    saved yourself that day.
//

import Foundation
import SwiftData

enum ConfidenceScorer {
    static let tag = "activities"
    static let note = "Daily Routine, To Do and Monthly Expenses"

    /// Recomputes the score of each day in `days`.
    @MainActor
    static func sync(days: Set<Date>, context: ModelContext) {
        guard !DemoData.isEnabled else { return }   // screenshots keep their sample scores
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        let activities = (try? context.fetch(FetchDescriptor<ActivityItem>())) ?? []
        let tasks = (try? context.fetch(FetchDescriptor<TaskModel>())) ?? []
        let monthly = (try? context.fetch(FetchDescriptor<MonthlyTaskModel>())) ?? []
        let entries = (try? context.fetch(FetchDescriptor<ConfidenceEntry>())) ?? []
        var changed = false

        for rawDay in days {
            let day = cal.startOfDay(for: rawDay)
            let existing = entries.filter { cal.isDate($0.date, inSameDayAs: day) && $0.tags.contains(tag) }

            // Days that haven't come yet: no score (it would show as 0 in Confidence)
            if day > today {
                existing.forEach { context.delete($0) }
                changed = changed || !existing.isEmpty
                continue
            }

            var done: [Bool] = []
            done += activities.filter { cal.isDate($0.date, inSameDayAs: day) }.map(\.isCompleted)
            done += tasks.filter { cal.isDate($0.dueDate, inSameDayAs: day) }.map(\.isCompleted)
            done += monthly.filter { !$0.isCompleted && $0.occurrence(on: day, calendar: cal) != nil }
                .map { $0.isPaid(in: day, calendar: cal) }

            if done.isEmpty {
                existing.forEach { context.delete($0) }
                changed = changed || !existing.isEmpty
                continue
            }

            let score = Int((Double(done.filter { $0 }.count) / Double(done.count) * 10).rounded())
            if let first = existing.first {
                if first.score != score || first.note != note {
                    first.score = score
                    first.note = note
                    changed = true
                }
                existing.dropFirst().forEach { context.delete($0) }   // only one score per day
                changed = changed || existing.count > 1
            } else {
                context.insert(ConfidenceEntry(date: day, score: score, note: note, tags: [tag]))
                changed = true
            }
        }
        if changed { try? context.save() }
    }

    /// This month's scores up to today (they also count To Do and Monthly Expenses
    /// now), and no scores for days that haven't come yet. Runs whenever reminders
    /// are rebuilt, i.e. after every change and each time the app opens.
    @MainActor
    static func rescoreThisMonth(context: ModelContext) {
        guard !DemoData.isEnabled else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let monthStart = cal.startOfMonth(for: today)

        var days = Set<Date>()
        var day = monthStart
        while day <= today {
            days.insert(day)
            day = cal.date(byAdding: .day, value: 1, to: day) ?? today.addingTimeInterval(86_400)
        }
        let entries = (try? context.fetch(FetchDescriptor<ConfidenceEntry>())) ?? []
        for e in entries where e.tags.contains(tag) && cal.startOfDay(for: e.date) > today {
            days.insert(cal.startOfDay(for: e.date))
        }
        sync(days: days, context: context)
    }
}

/// The Confidence level of each day (see the top of this file).
enum ConfidenceLevels {
    static func isDerived(_ e: ConfidenceEntry) -> Bool { e.tags.contains(ConfidenceScorer.tag) }

    /// Level per day, oldest first, up to and including today.
    static func daily(_ entries: [ConfidenceEntry], today: Date = .now) -> [(day: Date, level: Double)] {
        let cal = Calendar.current
        let end = cal.startOfDay(for: today)
        let grouped = Dictionary(grouping: entries, by: { cal.startOfDay(for: $0.date) })
        return grouped
            .filter { $0.key <= end }
            .map { (day: $0.key, level: Double($0.value.reduce(0) { $0 + $1.score }) / Double($0.value.count)) }
            .sorted { $0.day < $1.day }
    }

    /// Average daily level over the last `days` days (today included), or nil.
    static func average(_ entries: [ConfidenceEntry], days: Int, today: Date = .now) -> Double? {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -(days - 1), to: cal.startOfDay(for: today)) else { return nil }
        let vals = daily(entries, today: today).filter { $0.day >= start }.map(\.level)
        return vals.isEmpty ? nil : vals.reduce(0, +) / Double(vals.count)
    }

    /// Today's level, or nil when today has nothing yet.
    static func today(_ entries: [ConfidenceEntry], now: Date = .now) -> Double? {
        guard let last = daily(entries, today: now).last,
              Calendar.current.isDate(last.day, inSameDayAs: now) else { return nil }
        return last.level
    }

    /// Days in a row with a level above 0, counting back from today. If today has
    /// no level yet (or is at 0), it counts from yesterday, so an unfinished day
    /// doesn't break the streak.
    static func streak(_ levels: [(day: Date, level: Double)], now: Date = .now) -> Int {
        let cal = Calendar.current
        let byDay = Dictionary(levels.map { ($0.day, $0.level) }, uniquingKeysWith: { a, _ in a })
        var day = cal.startOfDay(for: now)
        if (byDay[day] ?? 0) <= 0 { day = cal.date(byAdding: .day, value: -1, to: day) ?? day }
        var n = 0
        while (byDay[day] ?? 0) > 0 {
            n += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return n
    }
}

//
//  DemoData.swift
//  ToBeDone
//
//  Sample content for App Store screenshots. Only used when the app is started
//  with the "-demoData" launch argument (the screenshot test does this). The data
//  lives in memory only, so your real tasks are never read, changed or backed up.
//
//  "-demoScene <name>" picks the content for one screenshot, so each screen shows
//  exactly what it should: home, todo, routine, monthly, projects, grocery,
//  confidence, focus.
//

import Foundation
import SwiftData

enum DemoData {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-demoData")
    }

    /// Which screenshot is being taken ("-demoScene routine" etc.). Default: home.
    static var scene: String {
        UserDefaults.standard.string(forKey: "demoScene") ?? "home"
    }

    /// "Now" for screens that open on a date. The Daily Routine screenshot shows
    /// the first week of November 2026 (Tuesday 3 Nov selected); everything else
    /// uses the real date.
    static var now: Date {
        guard isEnabled, scene == "routine" else { return Date() }
        return november(3, 8)
    }

    private static func november(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: day,
                                                   hour: hour, minute: minute)) ?? Date()
    }

    static func seed(into context: ModelContext) {
        switch scene {
        case "todo": seedToDo(context)
        case "routine": seedRoutine(context)
        case "monthly": seedMonthly(context)
        case "projects": seedProject(context)
        case "grocery": seedGrocery(context)
        case "confidence": seedConfidence(context)
        case "focus": seedFocus(context)
        default: seedHome(context)
        }
        try? context.save()
    }

    // MARK: - Helpers

    /// A day relative to today at a given time
    private static func at(_ dayOffset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let day = cal.date(byAdding: .day, value: dayOffset, to: today) ?? today
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    private static func task(_ title: String, _ due: Date, _ priority: TaskPriority,
                             done: Bool = false, remindMinutes: Int? = nil) -> TaskModel {
        let t = TaskModel(title: title, dueDate: due, priority: priority)
        t.isCompleted = done
        t.reminderMinutes = remindMinutes
        return t
    }

    // MARK: - Home: today's plan

    private static func seedHome(_ context: ModelContext) {
        let today = min(Calendar.current.component(.day, from: .now), 28)

        // Today, in time order: four items
        context.insert(ActivityItem(date: at(0, 9), name: "Deep work for the new project", durationMinutes: 120))
        context.insert(task("Send the project report", at(0, 16), .high))
        context.insert(MonthlyTaskModel(title: "Pay the electricity bill", price: 75, dayOfMonth: today, hour: 18))
        context.insert(ActivityItem(date: at(0, 21), name: "Read a book", durationMinutes: 30))

        // A little in the other sections, so their rows show numbers
        context.insert(MonthlyTaskModel(title: "Rent", price: 650, dayOfMonth: 1))
        context.insert(task("Book train tickets", at(1, 9), .medium))
        context.insert(OtherTaskModel(title: "Plan summer holiday", subtasks: [
            SubtaskModel(title: "Choose destination", isCompleted: true),
            SubtaskModel(title: "Book flights"),
            SubtaskModel(title: "Find a hotel"),
        ]))
        for (name, price) in [("Running shoes", 89.99), ("Desk lamp", 34.50), ("Birthday gift for Anna", 45.00)] {
            context.insert(ShoppingItemModel(name: name, price: price, currency: "EUR"))
        }
        insertGrocery(context)
        seedConfidence(context)
        seedFocus(context)
    }

    // MARK: - To Do: two due, the rest done on earlier days

    private static func seedToDo(_ context: ModelContext) {
        context.insert(task("Book train tickets", at(1, 9), .medium, remindMinutes: 60))
        context.insert(task("Renew gym membership", at(3, 10), .low))

        context.insert(task("Send the project report", at(-1, 16), .high, done: true))
        context.insert(task("Call the dentist", at(-1, 11), .medium, done: true))
        context.insert(task("Water the plants", at(-2, 8), .low, done: true))
        context.insert(task("Pay the parking ticket", at(-3, 12), .high, done: true))
    }

    // MARK: - Daily Routine: first weeks of November 2026

    private static func seedRoutine(_ context: ModelContext) {
        let cal = Calendar.current
        func weekly(_ name: String, firstDay: Int, hour: Int, minutes: Int, doneFirst: Bool) {
            let series = UUID()
            for w in 0..<4 {
                let start = cal.date(byAdding: .weekOfYear, value: w, to: november(firstDay, hour)) ?? november(firstDay, hour)
                context.insert(ActivityItem(date: start, name: name, durationMinutes: minutes,
                                            isCompleted: doneFirst && w == 0,
                                            seriesId: series, repeatsWeekly: true, repeatWeeks: 4))
            }
        }
        // Every Monday at 12:00 from 2 November, every Tuesday at 9:00 and 13:00 from 3 November
        weekly("Team meeting", firstDay: 2, hour: 12, minutes: 60, doneFirst: true)
        weekly("Morning run", firstDay: 3, hour: 9, minutes: 30, doneFirst: true)
        weekly("Lunch walk", firstDay: 3, hour: 13, minutes: 30, doneFirst: false)

        // Two more activities on Tuesday 3 November, the day selected in the Monthly view
        context.insert(ActivityItem(date: november(3, 17), name: "Language class", durationMinutes: 60))
        context.insert(ActivityItem(date: november(3, 21), name: "Read a book", durationMinutes: 30))

        // Monthly Expenses on 2, 3 and 4 November (shown as orange lines)
        context.insert(MonthlyTaskModel(title: "Rent", price: 650, dayOfMonth: 2, hour: 10))
        context.insert(MonthlyTaskModel(title: "Internet", price: 25, dayOfMonth: 3, hour: 11))
        context.insert(MonthlyTaskModel(title: "Phone", price: 15, dayOfMonth: 4, hour: 10))

        // To Do tasks that week (shown as blue lines)
        context.insert(task("Call the dentist", november(2, 16), .medium, done: true))
        context.insert(task("Send the project report", november(4, 15), .high))
        context.insert(task("Book train tickets", november(5, 11), .medium))
        context.insert(task("Pick up the dry cleaning", november(6, 17), .low))
    }

    // MARK: - Monthly Expenses: two

    private static func seedMonthly(_ context: ModelContext) {
        context.insert(MonthlyTaskModel(title: "Rent", price: 650, dayOfMonth: 1, hour: 10))
        context.insert(MonthlyTaskModel(title: "Internet", price: 25, dayOfMonth: 15, hour: 10))
    }

    // MARK: - Projects: one open with three subtasks, one completed

    private static func seedProject(_ context: ModelContext) {
        context.insert(OtherTaskModel(title: "Plan summer holiday", subtasks: [
            SubtaskModel(title: "Choose destination", isCompleted: true),
            SubtaskModel(title: "Book flights"),
            SubtaskModel(title: "Find a hotel"),
        ]))
        context.insert(OtherTaskModel(title: "Paint the balcony", isCompleted: true, subtasks: [
            SubtaskModel(title: "Buy paint", isCompleted: true),
            SubtaskModel(title: "Paint the walls", isCompleted: true),
        ]))
    }

    // MARK: - Grocery: eight items, five to buy and three bought

    private static func seedGrocery(_ context: ModelContext) {
        insertGrocery(context)
    }

    private static func insertGrocery(_ context: ModelContext) {
        for name in ["Milk", "Bread", "Eggs", "Tomatoes", "Avocados"] {
            context.insert(GroceryItemModel(name: name))
        }
        for name in ["Coffee", "Bananas", "Rice"] {
            context.insert(GroceryItemModel(name: name, isBought: true))
        }
    }

    // MARK: - Confidence: the last 30 days, slowly improving

    private static func seedConfidence(_ context: ModelContext) {
        let scores = [5, 6, 5, 6, 7, 6, 7, 7, 6, 7, 8, 7, 7, 8, 7, 8, 8, 7, 8, 8, 7, 8, 9, 8, 8, 9, 8, 8, 9, 8]
        for (i, score) in scores.enumerated() {
            let day = scores.count - 1 - i
            context.insert(ConfidenceEntry(date: at(-day, 20), score: score,
                                           note: i == scores.count - 1 ? "Finished my report early" : nil))
        }
    }

    // MARK: - Focus Test: three tests, one week apart

    private static func seedFocus(_ context: ModelContext) {
        for (weeksAgo, seconds) in [(2, 52.7), (1, 61.3), (0, 74.8)] {
            context.insert(FocusResult(date: at(-7 * weeksAgo, 20, 30), duration: seconds))
        }
    }
}

//
//  DemoData.swift
//  ToBeDone
//
//  Sample content for App Store screenshots. Only used when the app is started
//  with the "-demoData" launch argument (the screenshot test does this). The data
//  lives in memory only, so your real tasks are never read, changed or backed up.
//

import Foundation
import SwiftData

enum DemoData {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-demoData")
    }

    static func seed(into context: ModelContext) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        func at(_ dayOffset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let day = cal.date(byAdding: .day, value: dayOffset, to: today) ?? today
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        // To Do
        let tasks: [(String, Int, Int, TaskPriority, Bool)] = [
            ("Pay the electricity bill", 0, 18, .high, false),
            ("Call the dentist", 0, 11, .medium, true),
            ("Send the project report", 0, 16, .high, false),
            ("Renew gym membership", 1, 10, .low, false),
            ("Book train tickets", 2, 9, .medium, false),
            ("Water the plants", 0, 8, .low, true),
        ]
        for (title, day, hour, priority, done) in tasks {
            let t = TaskModel(title: title, dueDate: at(day, hour), priority: priority)
            t.isCompleted = done
            context.insert(t)
        }

        // Shopping
        let shopping: [(String, Double, Bool)] = [
            ("Running shoes", 89.99, false), ("Desk lamp", 34.50, false),
            ("Birthday gift for Anna", 45.00, false), ("Phone case", 19.99, false),
            ("Notebook", 6.50, false), ("Headphones", 59.00, true),
        ]
        for (name, price, done) in shopping {
            let item = ShoppingItemModel(name: name, price: price, currency: "EUR",
                                         priority: .medium, isCompleted: done)
            if done { item.completedAt = at(-2, 12) }
            context.insert(item)
        }

        // Grocery
        for (name, bought) in [("Milk", false), ("Bread", false), ("Eggs", false), ("Tomatoes", false),
                               ("Avocados", false), ("Greek yogurt", false), ("Coffee", true), ("Bananas", true),
                               ("Olive oil", false), ("Spinach", false)] {
            context.insert(GroceryItemModel(name: name, isBought: bought))
        }

        // Monthly expenses
        for (title, price) in [("Rent", 650.0), ("Electricity", 75.0), ("Internet", 25.0),
                               ("Phone", 15.0), ("Gym", 40.0), ("Streaming", 12.0)] {
            context.insert(MonthlyTaskModel(title: title, price: price))
        }

        // Projects
        context.insert(OtherTaskModel(title: "Plan summer holiday", subtasks: [
            SubtaskModel(title: "Choose destination", isCompleted: true),
            SubtaskModel(title: "Book flights"),
            SubtaskModel(title: "Find a hotel"),
        ]))
        context.insert(OtherTaskModel(title: "Learn Spanish", subtasks: [
            SubtaskModel(title: "Finish lesson 5", isCompleted: true),
            SubtaskModel(title: "Practice 15 min a day"),
        ]))

        // Daily Routine: this week
        let routine: [(String, Int, Int, Int, Int, Bool)] = [   // name, day, hour, minute, minutes, done
            ("Morning run", 0, 7, 0, 30, true),
            ("Deep work", 0, 9, 0, 120, true),
            ("Lunch walk", 0, 13, 0, 30, false),
            ("Read a book", 0, 21, 0, 30, false),
            ("Yoga", 1, 7, 30, 45, false),
            ("Team meeting", 1, 10, 0, 60, false),
            ("Morning run", -1, 7, 0, 30, true),
            ("Language class", -1, 18, 0, 60, true),
            ("Deep work", 2, 9, 0, 120, false),
            ("Cook dinner", 2, 19, 0, 60, false),
        ]
        for (name, day, hour, minute, minutes, done) in routine {
            context.insert(ActivityItem(date: at(day, hour, minute), name: name,
                                        durationMinutes: minutes, isCompleted: done))
        }

        // Confidence: the last 30 days, slowly improving
        let scores = [5, 6, 5, 6, 7, 6, 7, 7, 6, 7, 8, 7, 7, 8, 7, 8, 8, 7, 8, 8, 7, 8, 9, 8, 8, 9, 8, 8, 9, 8]
        for (i, score) in scores.enumerated() {
            let day = scores.count - 1 - i
            context.insert(ConfidenceEntry(date: at(-day, 20), score: score,
                                           note: i == scores.count - 1 ? "Finished my report early" : nil))
        }

        // Focus Test: improving over the weeks
        for (weeksAgo, seconds) in [(6, 31.4), (5, 38.2), (4, 45.0), (3, 52.7), (2, 61.3), (1, 74.8), (0, 83.2)] {
            context.insert(FocusResult(date: at(-7 * weeksAgo, 20, 30), duration: seconds))
        }

        try? context.save()
    }
}

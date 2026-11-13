//
//  ExportDTOs.swift
//  ToBeDone
//

import SwiftUI

//Add export/import button

struct TaskDTO: Codable, Identifiable {
    var id: UUID
    var title: String
    var dueDate: Date
    var priority: String
    var isCompleted: Bool
    var reminderMinutes: Int? = nil   // optional: older export files don't have it
}

struct ShoppingItemDTO: Codable, Identifiable {
    var id: UUID
    var name: String
    var price: Double
    var currency: String
    var priority: String
    var isCompleted: Bool
}

struct MonthlyTaskDTO: Codable, Identifiable {
    var id: UUID
    var title: String
    var price: Double
    // Optional, so files exported by older versions still import
    var dayOfMonth: Int? = nil
    var hour: Int? = nil
    var minute: Int? = nil
}

struct SubtaskDTO: Codable, Identifiable {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var startDate: Date? = nil   // optional: older export files don't have dates
    var endDate: Date? = nil
}

struct OtherTaskDTO: Codable, Identifiable {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var subtasks: [SubtaskDTO]
    var startDate: Date? = nil   // optional: older export files don't have dates
    var endDate: Date? = nil
}

struct ActivityDTO: Codable, Identifiable {
    var id: UUID
    var date: Date
    var name: String
    var details: String
    var durationMinutes: Int
    var isCompleted: Bool
    var seriesId: UUID?
    var repeatsWeekly: Bool
    var repeatWeeks: Int
    var reminderMinutes: Int? = nil   // optional: older export files don't have it
}

struct ExportPackage: Codable {
    var tasks: [TaskDTO]
    var shoppingItems: [ShoppingItemDTO]
    var monthlyTasks: [MonthlyTaskDTO]
    var tasksWithSubtasks: [OtherTaskDTO]
    var activityTasks: [ActivityDTO]
}

// Add helpers in app A

extension TaskDTO {
    init(from model: TaskModel) {
        self.id = model.id
        self.title = model.title
        self.dueDate = model.dueDate
        self.priority = model.priority.rawValue
        self.isCompleted = model.isCompleted
        self.reminderMinutes = model.reminderMinutes
    }
}

extension ShoppingItemDTO {
    init(from model: ShoppingItemModel) {
        self.id = model.id
        self.name = model.name
        self.price = model.price
        self.currency = model.currency
        self.priority = model.priority.rawValue
        self.isCompleted = model.isCompleted
    }
}

extension MonthlyTaskDTO {
    init(from model: MonthlyTaskModel) {
        self.id = model.id
        self.title = model.title
        self.price = model.price
        self.dayOfMonth = model.dayOfMonth
        self.hour = model.hour
        self.minute = model.minute
    }
}

extension OtherTaskDTO {
    init(from model: OtherTaskModel) {
        self.id = model.id
        self.title = model.title
        self.isCompleted = model.isCompleted
        self.subtasks = model.subtasks.map {
            SubtaskDTO(id: $0.id, title: $0.title, isCompleted: $0.isCompleted,
                       startDate: $0.startDate, endDate: $0.endDate)
        }
        self.startDate = model.startDate
        self.endDate = model.endDate
    }
}

extension ActivityDTO {
    init(from model: ActivityItem) {
        self.id = model.id
        self.date = model.date
        self.name = model.name
        self.details = model.details
        self.durationMinutes = model.durationMinutes
        self.isCompleted = model.isCompleted
        self.seriesId = model.seriesId
        self.repeatsWeekly = model.repeatsWeekly
        self.repeatWeeks = model.repeatWeeks
        self.reminderMinutes = model.reminderMinutes
    }
}

struct TaskPackage: Codable {
    var tasks: [TaskDTO]
}

struct ShoppingTaskPackage: Codable {
    var shoppingtasks: [ShoppingItemDTO]
}

struct MonthlyTaskPackage: Codable {
    var monthlyTasks: [MonthlyTaskDTO]
}

struct OtherTaskPackage: Codable {
    var othertasks: [OtherTaskDTO]
}

struct ActivityPackage: Codable {
    var activities: [ActivityDTO]
}

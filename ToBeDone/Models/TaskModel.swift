//
//  TaskModel.swift
//  ToBeDone
//

import SwiftUI
import SwiftData

enum TaskPriority: String, CaseIterable, Identifiable, Codable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var id: String { self.rawValue }
}

// MARK: - Task Model
@Model
class TaskModel: Identifiable {
    var id: UUID = UUID()
    var title: String
    var dueDate: Date
    var priority: TaskPriority
    var isCompleted: Bool = false

    // Reminders are scheduled/cancelled by the views (add, complete, delete, import),
    // not here, so creating a task in code never fires an unexpected notification.
    init(title: String, dueDate: Date, priority: TaskPriority) {
        self.title = title
        self.dueDate = dueDate
        self.priority = priority
    }
}

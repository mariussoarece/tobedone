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
    var isCompleted: Bool = false {
        didSet {
            if isCompleted {
                NotificationManager.shared.cancelNotification(for: self)
            }
        }
    }

    init( title: String, dueDate: Date, priority: TaskPriority) {
        self.title = title
        self.dueDate = dueDate
        self.priority = priority
        NotificationManager.shared.scheduleNotification(for: self)
    }
}

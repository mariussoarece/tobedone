//
//  OtherTaskModel.swift
//  ToBeDone
//

import SwiftUI
import SwiftData

@Model
class SubtaskModel: Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var isCompleted: Bool = false
    /// Optional start and end (new in 6.x; older subtasks have none)
    var startDate: Date? = nil
    var endDate: Date? = nil

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
            self.id = id
            self.title = title
            self.isCompleted = isCompleted
        }

    static func == (lhs: SubtaskModel, rhs: SubtaskModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@Model
class OtherTaskModel: Identifiable {
    var id = UUID()
    var title: String
    var subtasks: [SubtaskModel] = []
    var isCompleted: Bool = false  // ✅ New
    /// Optional start and end; you get a notification at each (new in 6.x)
    var startDate: Date? = nil
    var endDate: Date? = nil

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        subtasks: [SubtaskModel] = []
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.subtasks = subtasks
    }
}

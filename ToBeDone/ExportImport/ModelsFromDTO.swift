//
//  ModelsFromDTO.swift
//  ToBeDone
//

import SwiftUI

//Import logic in App B

extension TaskModel {
    static func fromDTO(_ dto: TaskDTO) -> TaskModel {
        let task = TaskModel(
            title: dto.title,
            dueDate: dto.dueDate,
            priority: TaskPriority(rawValue: dto.priority) ?? .medium
        )
        task.reminderMinutes = dto.reminderMinutes
        return task
    }
}

extension ShoppingItemModel {
    static func fromDTO(_ dto: ShoppingItemDTO) -> ShoppingItemModel {
        let item = ShoppingItemModel(
            name: dto.name,
            price: dto.price,
            currency: dto.currency,
            priority: TaskPriority(rawValue: dto.priority) ?? .medium
        )
        item.isCompleted = dto.isCompleted
        return item
    }
}

extension MonthlyTaskModel {
    static func fromDTO(_ dto: MonthlyTaskDTO) -> MonthlyTaskModel {
        MonthlyTaskModel(title: dto.title, price: dto.price, dayOfMonth: dto.dayOfMonth,
                         hour: dto.hour ?? 10, minute: dto.minute ?? 0)
    }
}

//
//  ShoppingItemModel.swift
//  ToBeDone
//

import SwiftUI
import SwiftData

@Model
class ShoppingItemModel: Identifiable {
    var id: UUID = UUID()
    var name: String
    var price: Double
    var currency: String
    var priority: TaskPriority
    var isCompleted: Bool = false
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        price: Double,
        currency: String,
        priority: TaskPriority = .medium,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.price = price
        self.currency = currency
        self.priority = priority
        self.isCompleted = isCompleted
    }
}

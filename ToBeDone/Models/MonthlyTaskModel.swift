//
//  MonthlyTaskModel.swift
//  ToBeDone
//

import SwiftUI
import SwiftData

@Model
class MonthlyTaskModel: Identifiable {
    var id: UUID = UUID()         // Important for identifying items in the list
    var title: String
    var price: Double

    init(title: String, price: Double = 0.0) {
        self.title = title
        self.price = price
    }
}

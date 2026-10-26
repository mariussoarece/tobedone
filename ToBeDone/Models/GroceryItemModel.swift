//
//  GroceryItemModel.swift
//  ToBeDone
//

import SwiftUI
import SwiftData

@Model
class GroceryItemModel: Identifiable {
    var id: UUID = UUID()
    var name: String
    var isBought: Bool = false

    init(name: String, isBought: Bool = false) {
        self.name = name
        self.isBought = isBought
    }
}

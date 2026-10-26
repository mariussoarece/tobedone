//
//  ImportFromJSON.swift
//  ToBeDone
//

import SwiftUI
import SwiftData

//Iport function with merge not overwrite

func importFromJSON(data: Data, modelContext: ModelContext) {
    do {
        let package = try JSONDecoder().decode(ExportPackage.self, from: data)

        // Existing tasks for simple duplicate check (by title + date)
        let existingTasks = try modelContext.fetch(FetchDescriptor<TaskModel>())
        let existingShopping = try modelContext.fetch(FetchDescriptor<ShoppingItemModel>())
        let existingMonthly = try modelContext.fetch(FetchDescriptor<MonthlyTaskModel>())

        // Helper to avoid duplicates
        func taskExists(_ dto: TaskDTO) -> Bool {
            existingTasks.contains {
                $0.title == dto.title && $0.dueDate == dto.dueDate
            }
        }

        func shoppingExists(_ dto: ShoppingItemDTO) -> Bool {
            existingShopping.contains {
                $0.name == dto.name && $0.price == dto.price
            }
        }

        func monthlyExists(_ dto: MonthlyTaskDTO) -> Bool {
            existingMonthly.contains {
                $0.title == dto.title && $0.price == dto.price
            }
        }

        // Import tasks
        for dto in package.tasks where !taskExists(dto) {
            let newTask = TaskModel.fromDTO(dto)
            modelContext.insert(newTask)
        }

        // Import shopping items
        for dto in package.shoppingItems where !shoppingExists(dto) {
            let newItem = ShoppingItemModel.fromDTO(dto)
            modelContext.insert(newItem)
        }

        // Import monthly tasks
        for dto in package.monthlyTasks where !monthlyExists(dto) {
            let newMonthly = MonthlyTaskModel.fromDTO(dto)
            modelContext.insert(newMonthly)
        }

        try modelContext.save()
        print("Import completed successfully.")
    } catch {
        print("Import error:", error)
    }
}

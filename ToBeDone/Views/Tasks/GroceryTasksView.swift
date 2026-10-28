//
//  GroceryTasksView.swift
//  ToBeDone
//

import SwiftUI
import SwiftData

struct GroceryTasksView: View {
    @Query private var groceryItems: [GroceryItemModel]
    @Environment(\.modelContext) private var modelContext

    @State private var newItemName: String = ""

    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 16) {
                            // ✅ Custom large title — not next to the back button
                            Text("Grocery List")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.yellow)
                                .padding(.horizontal)
                                .padding(.top)
            KeyboardDismissWrapper {
                Form {
                    // 🔹 Add New Grocery Item
                    Section(header: Text("Add Grocery Item")) {
                        TextField("Item Name", text: $newItemName)
                            .submitLabel(.done)
                            .onSubmit {
                                dismissKeyboard()
                            }

                        Button("Add") {
                            let name = newItemName.trimmingCharacters(in: .whitespaces)
                            guard !name.isEmpty else { return }
                            let item = GroceryItemModel(name: name)
                            modelContext.insert(item)
                            try? modelContext.save()   // save now, don't wait for autosave
                            newItemName = ""
                        }
                        .buttonStyle(.borderedProminent)   // blue, like Export
                    }

                    // 🔸 Grocery Items Not Bought Yet
                    Section(header: Text("Grocery List")) {
                        ForEach(sortedItems().filter { !$0.isBought }, id: \.id) { item in
                            groceryRow(item)
                        }
                    }

                    // ✅ Bought Items Section
                    Section(header: Text("Bought Items")) {
                        ForEach(sortedItems().filter { $0.isBought }, id: \.id) { item in
                            groceryRow(item)
                        }.onDelete(perform: deleteCompletedTasks)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline) // optional
            .navigationTitle("")

            }
        }
    }

    @ViewBuilder
    private func groceryRow(_ item: GroceryItemModel) -> some View {
        HStack {
            Text(item.name)
                .strikethrough(item.isBought)
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleItem(item)
        }
    }

    private func toggleItem(_ item: GroceryItemModel) {
        item.isBought.toggle()
        try? modelContext.save()
    }

    private func sortedItems() -> [GroceryItemModel] {
        groceryItems.sorted {
            if $0.isBought == $1.isBought {
                return $0.name < $1.name
            }
            return !$0.isBought && $1.isBought
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
    private func deleteCompletedTasks(at offsets: IndexSet) {
        // Only the "Bought Items" list can be swiped, so map offsets to that list
        let completedTasks = sortedItems().filter { $0.isBought }
        for index in offsets {
            let taskToDelete = completedTasks[index]
            modelContext.delete(taskToDelete)
        }
        try? modelContext.save()
    }

}

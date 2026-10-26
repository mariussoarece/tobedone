//
//  ShoppingTasksView.swift
//  ToBeDone
//

import SwiftUI
import SwiftData

// MARK: - Shopping Tasks View
struct ShoppingTasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var shoppingItems: [ShoppingItemModel]

    @State private var newItemName: String = ""
    @State private var newItemPrice: String = ""
    @State private var selectedPriority: TaskPriority = .medium
    @AppStorage("selectedCurrency") private var selectedCurrency: String = "USD"
    @State private var exportURL: URL?
    @State private var showingImporter = false
    @State private var editingItem: ShoppingItemModel?
    @State private var editedPrice: String = ""
    @State private var showEditPriceSheet = false

    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 16) {
                // ✅ Custom large title — not next to the back button
                Text("Shopping Tasks")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .padding(.top)
            KeyboardDismissWrapper {
                Form {
                    Section(header: Text("Add New Item")) {
                        TextField("Item Name", text: $newItemName)
                        TextField("Price", text: $newItemPrice).keyboardType(.decimalPad)

                        Picker("Priority", selection: $selectedPriority) {
                            ForEach(TaskPriority.allCases) { priority in
                                Text(priority.rawValue).tag(priority)
                            }
                        }

                        Button("Add Item") {
                            let name = newItemName.trimmingCharacters(in: .whitespaces)
                            if !name.isEmpty, let price = newItemPrice.decimalValue {
                                let newItem = ShoppingItemModel(name: name, price: price, currency: selectedCurrency, priority: selectedPriority)
                                modelContext.insert(newItem)
                                newItemName = ""
                                newItemPrice = ""
                            }
                        }
                    }

                    Section(header: Text("Shopping List")) {
                        ForEach(shoppingItems.filter { !$0.isCompleted }) { item in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.name).bold()
                                    Text("\(item.price, specifier: "%.2f") \(selectedCurrency)")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Image(systemName: "cart.badge.plus").foregroundColor(.green)
                            }
                            .onTapGesture {
                                editingItem = item
                                editedPrice = String(item.price)
                            }
                            .contentShape(Rectangle())

                        }
                    }
                    Section {
                        HStack {
                            Text("Total to Buy:")
                                .fontWeight(.bold)
                            Spacer()
                            Text("\(totalActivePrice(), specifier: "%.2f") \(selectedCurrency)")
                                .bold().foregroundColor(.blue)
                        }
                    }
                    HStack{
                        Button("Export Tasks") {
                            exportShoppingTasks()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Import Tasks") {
                            showingImporter = true
                        }
                        .buttonStyle(.bordered)
                        .padding(.horizontal)
                    }
                    Section(header: Text("Completed Purchases")) {
                        ForEach(shoppingItems.filter { $0.isCompleted }) { item in
                            HStack {
                                Text(item.name)
                                    .strikethrough()
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)   // ⭐ allows wrapping
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Spacer()
                                if let date = item.completedAt {
                                    Text(formattedDate(date))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                                }
                                Spacer()
                                Text("✔️").foregroundColor(.green)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleCompletion(item)
                            }
                        }
                        .onDelete(perform: deleteCompletedItems)
                    }

                    Section {
                        HStack {
                            Text("Total:")
                                .fontWeight(.bold)
                            Spacer()
                            Text("\(totalPrice(), specifier: "%.2f") \(selectedCurrency)")
                                .fontWeight(.bold)
                        }
                    }

                }

                .fileImporter(
                        isPresented: $showingImporter,
                        allowedContentTypes: [.json],
                        allowsMultipleSelection: false
                    ) { result in
                        switch result {
                        case .success(let urls):
                            if let url = urls.first {
                                let granted = url.startAccessingSecurityScopedResource()
                                defer {
                                    if granted {
                                        url.stopAccessingSecurityScopedResource()
                                    }
                                }
                                do {

                                    let data = try Data(contentsOf: url)
                                    importShoppingTasks(from: data)

                                } catch {
                                    print("Import read error:", error)
                                }
                            }

                        case .failure(let error):
                            print("Importer error:", error)
                        }
                    }

                }
            .navigationBarTitleDisplayMode(.inline) // optional
            .navigationTitle("")
            }
        }
        .sheet(item: $editingItem) { item in
            ScrollView {
                VStack(spacing: 20) {
                    Text("Edit Price")
                        .font(.title2)
                        .bold()

                    Text(item.name)
                        .font(.headline)

                    TextField("Price", text: $editedPrice)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)

                    Button("Confirm") {
                        if let newPrice = editedPrice.decimalValue {
                            item.price = newPrice
                        }
                        item.completedAt = Date()
                        item.isCompleted = true
                        try? modelContext.save()
                        editingItem = nil
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Cancel") {
                        editingItem = nil
                    }
                    .foregroundColor(.red)
                }
                .padding()
            }
            .presentationDetents([.fraction(0.35)])
            .presentationDragIndicator(.visible)
        }
    }

    private func toggleCompletion(_ task: ShoppingItemModel) {
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? Date() : nil
        try? modelContext.save()
    }
    private func totalActivePrice() -> Double {
        shoppingItems
            .filter { !$0.isCompleted }
            .reduce(0) { $0 + $1.price }
    }
    private func totalPrice() -> Double {
        shoppingItems
            .reduce(0) { $0 + $1.price }
    }
    private func deleteCompletedItems(at offsets: IndexSet) {
        let completedItems = shoppingItems.filter { $0.isCompleted }
        for index in offsets {
            let item = completedItems[index]
            modelContext.delete(item)
        }
        try? modelContext.save()
    }
    private func exportShoppingTasks() {
        let dtos = shoppingItems
                .filter { !$0.isCompleted }   // ⭐ only active items
                .map(ShoppingItemDTO.init)

        let package = ExportPackage(
            tasks: [],
            shoppingItems: dtos,
            monthlyTasks: [],
            tasksWithSubtasks: [],
            activityTasks: []
        )

        do {
            let data = try JSONEncoder().encode(package)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("shopping_tasks_export.json")

            try data.write(to: url)
            exportURL = url
            presentShareSheet(url: url)   // ⬅️ opens share sheet immediately
                } catch {
                    print("Export error:", error)
                }
            }

            private func presentShareSheet(url: URL) {
                guard let scene = UIApplication.shared.connectedScenes
                        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                      let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
                else { return }

                // Find the topmost presented controller, in case something's already showing
                var topVC = rootVC
                while let presented = topVC.presentedViewController {
                    topVC = presented
                }

                let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

                // Required for iPad — without this it can crash on iPad
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = topVC.view
                    popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }

                topVC.present(activityVC, animated: true)
            }
    private func importShoppingTasks(from data: Data) {
        do {
            // Export writes an ExportPackage ("shoppingItems"); older files used "shoppingtasks"
            let dtos: [ShoppingItemDTO]
            if let package = try? JSONDecoder().decode(ExportPackage.self, from: data) {
                dtos = package.shoppingItems
            } else {
                dtos = try JSONDecoder().decode(ShoppingTaskPackage.self, from: data).shoppingtasks
            }

            let existing = shoppingItems

            func exists(_ dto: ShoppingItemDTO) -> Bool {
                existing.contains { $0.id == dto.id }
            }

            for dto in dtos where !exists(dto) {
                let priorityEnum = TaskPriority(rawValue: dto.priority) ?? .medium

                let item = ShoppingItemModel(
                    id: dto.id,
                    name: dto.name,
                    price: dto.price,
                    currency: dto.currency,
                    priority: priorityEnum,
                    isCompleted: dto.isCompleted
                )
                modelContext.insert(item)
            }

            try? modelContext.save()
        } catch {
            print("Import decode error:", error)
        }
    }
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.dd.yyyy"
        return formatter.string(from: date)
    }

}

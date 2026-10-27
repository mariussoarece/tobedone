//
//  MonthlyTasksView.swift
//  ToBeDone
//

import SwiftUI
import SwiftData

struct MonthlyTasksView: View {
    @Query private var monthlyTasks: [MonthlyTaskModel]
    @Environment(\.modelContext) private var modelContext

    @State private var newTaskTitle: String = ""
    @State private var newTaskPrice: String = ""
    @AppStorage("selectedCurrency") private var selectedCurrency: String = "USD"
    @State private var exportURL: URL?
    @State private var showingImporter = false

    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 16) {
                            Text("Monthly Task")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                                .padding(.horizontal)
                                .padding(.top)
            KeyboardDismissWrapper {
                Form {
                    Section(header: Text("Add Monthly Task")) {
                        TextField("Task Title", text: $newTaskTitle)
                            .submitLabel(.next)

                        TextField("Price", text: $newTaskPrice)
                            .keyboardType(.decimalPad)
                            .submitLabel(.done)
                            .onSubmit {
                                hideKeyboard()
                            }

                        Button("Add Task") {
                            addTask()
                        }
                    }

                    Section(header: Text("Monthly Tasks - Swipe to delete")) {
                        ForEach(monthlyTasks, id: \.id) { task in
                            HStack {
                                Text(task.title)
                                Spacer()
                                Text("\(task.price, specifier: "%.2f") \(selectedCurrency)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onDelete(perform: deleteTask)
                    }

                    Section {
                        HStack {
                            Text("Total:")
                                .fontWeight(.bold)
                            Spacer()
                            Text("\(totalPrice(), specifier: "%.2f") \(selectedCurrency)")
                                .bold().foregroundColor(.blue)
                        }
                    }
                    HStack{
                        Button("Export Tasks") {
                            exportMonthlyTasks()
                        }
                        .buttonStyle(.borderedProminent)
                        // ⭐ ADD SHARELINK

                        Button("Import Tasks") {
                            showingImporter = true
                        }
                        .buttonStyle(.bordered)
                        .padding(.horizontal)
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
                                importMonthlyTasks(from: data)

                            } catch {
                                print("Import read error:", error)
                            }
                        }

                    case .failure(let error):
                        print("Importer error:", error)
                    }
                }
            .navigationBarTitleDisplayMode(.inline) // optional
            .navigationTitle("")
            }
        }
    }

    private func addTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let price = newTaskPrice.decimalValue ?? 0.0
        let newTask = MonthlyTaskModel(title: title, price: price)
        modelContext.insert(newTask)
        try? modelContext.save()   // save now, don't wait for autosave
        newTaskTitle = ""
        newTaskPrice = ""
    }

    private func deleteTask(at offsets: IndexSet) {
        for index in offsets {
            let task = monthlyTasks[index]
            modelContext.delete(task)
        }
        try? modelContext.save()
    }

    private func totalPrice() -> Double {
        monthlyTasks.reduce(0) { $0 + $1.price }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
    private func exportMonthlyTasks() {
        let dtos = monthlyTasks.map(MonthlyTaskDTO.init)

        let package = ExportPackage(
            tasks: [],
            shoppingItems: [],
            monthlyTasks: dtos,
            tasksWithSubtasks: [],
            activityTasks: []
        )

        do {
            let data = try JSONEncoder().encode(package)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("monthly_tasks_export.json")

            try data.write(to: url)
            exportURL = url
            presentShareSheet(url: url)
        } catch {
            print("Export error:", error)
        }
    }
    private func importMonthlyTasks(from data: Data) {
        do {
            let package = try JSONDecoder().decode(MonthlyTaskPackage.self, from: data)

            let existing = monthlyTasks

            func exists(_ dto: MonthlyTaskDTO) -> Bool {
                // Imported items get a new id, so compare by content to avoid duplicates
                existing.contains {
                    $0.title == dto.title &&
                    $0.price == dto.price
                }
            }

            for dto in package.monthlyTasks where !exists(dto) {
                let item = MonthlyTaskModel(
                    title: dto.title,
                    price: dto.price,
                )
                modelContext.insert(item)
            }

            try? modelContext.save()
        } catch {
            print("Import decode error:", error)
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
}

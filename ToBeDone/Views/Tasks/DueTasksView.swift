//
//  DueTasksView.swift
//  ToBeDone
//

import SwiftUI
import SwiftData

struct DueTasksView: View {
    @Query private var dueTasks: [TaskModel]
    @Environment(\.modelContext) private var modelContext

    @State private var newTaskTitle: String = ""
    @State private var dueDate: Date = Date()
    @State private var selectedPriority: TaskPriority = .medium
    @State private var exportURL: URL?
    @State private var showingImporter = false
    @State private var showingShareSheet = false

    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 16) {

                // Custom large title
                Text("To Do Tasks")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                    .padding(.horizontal)
                    .padding(.top)

                KeyboardDismissWrapper {
                    Form {
                        // MARK: Add New Task
                        Section(header: Text("Add New Task")) {
                            TextField("Task Title", text: $newTaskTitle)

                            // Pick date + time (change to .date if you only want the day)
                            DatePicker(
                                "Due Date & Time",
                                selection: $dueDate,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)

                            Picker("Priority", selection: $selectedPriority) {
                                ForEach(TaskPriority.allCases, id: \.self) { priority in
                                    Text(priority.rawValue.capitalized)
                                }
                            }

                            Button("Add Task") {
                                addTask()
                            }
                        }

                        // MARK: Due Tasks
                        Section(header: Text("Due Tasks")) {
                            ForEach(sortedTasks().filter { !$0.isCompleted }, id: \.id) { task in
                                taskRow(task)
                            }
                        }
                        HStack{
                            Button("Export Tasks") {
                                exportDueTasks()
                            }
                            .buttonStyle(.borderedProminent)
                            // ⭐ ADD SHARELINK

                            Button("Import Tasks") {
                                showingImporter = true
                            }
                            .buttonStyle(.bordered)
                            .padding(.horizontal)
                        }

                        // MARK: Completed Tasks
                        Section(header: Text("Completed Tasks")) {
                            ForEach(sortedTasks().filter { $0.isCompleted }, id: \.id) { task in
                                taskRow(task)
                            }
                            .onDelete(perform: deleteCompletedTasks)
                        }

                    }
                    .scrollDismissesKeyboard(.interactively)

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
                                    importDueTasks(from: data)

                                } catch {
                                    print("Import read error:", error)
                                }
                            }

                        case .failure(let error):
                            print("Importer error:", error)
                        }
                    }
            }
            .navigationTitle("")                 // hides default nav title
            .navigationBarTitleDisplayMode(.inline)

        }
    }

    // MARK: - Row
    @ViewBuilder
    private func taskRow(_ task: TaskModel) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .gray : .primary)

                Text("Due: \(formattedDate(task.dueDate))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(task.priority.rawValue)
                .font(.caption)
                .padding(6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
        }
        .contentShape(Rectangle())
        .onTapGesture { toggleCompletion(task) }
    }

    // MARK: - Logic
    private func addTask() {
        guard !newTaskTitle.isEmpty else { return }

        // Snap to start of the minute (no optionals, no crashes)
        let t = dueDate.timeIntervalSinceReferenceDate
        let normalized = Date(timeIntervalSinceReferenceDate: floor(t / 60) * 60)

        let newTask = TaskModel(
            title: newTaskTitle,
            dueDate: normalized,
            priority: selectedPriority
        )

        modelContext.insert(newTask)
        try? modelContext.save()
        NotificationManager.shared.scheduleNotification(for: newTask)

        // Reset UI
        newTaskTitle = ""
        dueDate = Date()
        selectedPriority = .medium
    }

    private func toggleCompletion(_ task: TaskModel) {
        task.isCompleted.toggle()
        try? modelContext.save()
        if task.isCompleted {
            NotificationManager.shared.cancelNotification(for: task)
        } else {
            // Un-completing a task brings its reminder back
            NotificationManager.shared.scheduleNotification(for: task)
        }
    }

    private func sortedTasks() -> [TaskModel] {
        dueTasks.sorted {
            if $0.isCompleted == $1.isCompleted {
                return $0.dueDate < $1.dueDate
            }
            return !$0.isCompleted && $1.isCompleted
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func deleteCompletedTasks(at offsets: IndexSet) {
        let completed = sortedTasks().filter { $0.isCompleted }
        for index in offsets {
            let taskToDelete = completed[index]
            NotificationManager.shared.cancelNotification(for: taskToDelete)
            modelContext.delete(taskToDelete)
        }
        try? modelContext.save()
    }
    private func exportDueTasks() {
        let dtos = dueTasks.filter { !$0.isCompleted }.map(TaskDTO.init)

        let package = ExportPackage(
            tasks: dtos,
            shoppingItems: [],
            monthlyTasks: [],
            tasksWithSubtasks: [],
            activityTasks: []
        )

        do {
            let data = try JSONEncoder().encode(package)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("todo_tasks_export.json")

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
    private func importDueTasks(from data: Data) {
        do {
            let package = try JSONDecoder().decode(ExportPackage.self, from: data)

            let existing = dueTasks

            func exists(_ dto: TaskDTO) -> Bool {
                existing.contains {
                    $0.title == dto.title &&
                    $0.dueDate == dto.dueDate &&
                    $0.priority.rawValue == dto.priority   // compare enum rawValue to DTO String
                }
            }

            for dto in package.tasks where !exists(dto) {

                let priorityEnum = TaskPriority(rawValue: dto.priority) ?? .medium

                let item = TaskModel(
                    title: dto.title,
                    dueDate: dto.dueDate,
                    priority: priorityEnum
                )

                item.isCompleted = dto.isCompleted

                modelContext.insert(item)
                NotificationManager.shared.scheduleNotification(for: item)
            }

            try? modelContext.save()
        } catch {
            print("Import decode error:", error)
        }
    }

}

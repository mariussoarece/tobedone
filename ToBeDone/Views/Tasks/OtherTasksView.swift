//
//  OtherTasksView.swift
//  ToBeDone
//

import SwiftUI
import SwiftData

struct OtherTasksView: View {
    @Query private var tasksWithSubtasks: [OtherTaskModel]
    @Environment(\.modelContext) private var modelContext

    @State private var newTaskTitle: String = ""
    @State private var exportURL: URL?
    @State private var showingImporter = false

    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 16) {
                            // ✅ Custom large title — not next to the back button
                            Text("Project Tasks")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                                .padding(.horizontal)
                                .padding(.top)
            KeyboardDismissWrapper {
                Form {
                    // 🔹 Add Task Section
                    Section(header: Text("Add New Task")) {
                        TextField("Task Title", text: $newTaskTitle)
                            .submitLabel(.done)
                            .onSubmit {
                                hideKeyboard()
                            }

                        Button("Add Project") {
                            if !newTaskTitle.isEmpty {
                                let newTask = OtherTaskModel(title: newTaskTitle)
                                modelContext.insert(newTask)
                                try? modelContext.save()   // save now, don't wait for autosave
                                newTaskTitle = ""
                            }
                        }
                        .buttonStyle(.borderedProminent)   // blue, like Export
                    }

                    // 🔸 Active Tasks Section
                    Section(header: Text("Tasks with Subtasks")) {
                        ForEach(sortedTasks().filter { !$0.isCompleted }, id: \.id) { task in
                            SubtaskSectionView(
                                task: task,
                                onAdd: { newSubtaskText in
                                    addSubtask(to: task, subtaskTitle: newSubtaskText)
                                },
                                onToggleCompletion: {
                                    toggleTaskCompletion(task)
                                }
                            )
                        }
                    }
                    HStack{
                        Button("Export Projects") {
                            exportOtherTasks()
                        }
                        .buttonStyle(.borderedProminent)
                        // ⭐ ADD SHARELINK

                        Button("Import Projects") {
                            showingImporter = true
                        }
                        .buttonStyle(.bordered)
                        .padding(.horizontal)
                    }

                    // ✅ Completed Tasks Section
                    Section(header: Text("Completed Tasks")) {
                            ForEach(sortedTasks().filter { $0.isCompleted }, id: \.id) { task in
                                SubtaskSectionView(
                                    task: task,
                                    onAdd: { newSubtaskText in
                                        addSubtask(to: task, subtaskTitle: newSubtaskText)
                                    },
                                    onToggleCompletion: {
                                        toggleTaskCompletion(task)
                                    }
                                )
                            }
                            .onDelete(perform: deleteCompletedTasks)
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
                                    importOtherTasks(from: data)

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
    }

    private func addSubtask(to task: OtherTaskModel, subtaskTitle: String) {
        let newSubtask = SubtaskModel(title: subtaskTitle)
        task.subtasks.append(newSubtask)
        try? modelContext.save()
    }

    private func sortedTasks() -> [OtherTaskModel] {
        tasksWithSubtasks.sorted {
            if $0.isCompleted == $1.isCompleted {
                return $0.title < $1.title
            }
            return !$0.isCompleted && $1.isCompleted
        }
    }

    private func toggleTaskCompletion(_ task: OtherTaskModel) {
        task.isCompleted.toggle()
        try? modelContext.save()
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
    private func deleteCompletedTasks(at offsets: IndexSet) {
        let completedTasks = sortedTasks().filter { $0.isCompleted }
        for index in offsets {
            let taskToDelete = completedTasks[index]
            modelContext.delete(taskToDelete)
        }
        try? modelContext.save()
    }

    private func exportOtherTasks() {
        let activeTasks = tasksWithSubtasks.filter { !$0.isCompleted }
        let dtos: [OtherTaskDTO] = activeTasks.map { task in

            let subtaskDTOs: [SubtaskDTO] = task.subtasks.map { sub in
                SubtaskDTO(
                    id: sub.id,
                    title: sub.title,
                    isCompleted: sub.isCompleted
                )
            }

            return OtherTaskDTO(
                id: task.id,
                title: task.title,
                isCompleted: false,
                subtasks: subtaskDTOs
            )
        }

        let package = ExportPackage(
            tasks: [],
            shoppingItems: [],
            monthlyTasks: [],
            tasksWithSubtasks: dtos,
            activityTasks: []
        )

        do {
            let data = try JSONEncoder().encode(package)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("other_tasks_export.json")

            try data.write(to: url)
            exportURL = url
            presentShareSheet(url: url)
        } catch {
            print("Export error:", error)
        }
    }
    private func importOtherTasks(from data: Data) {
        do {
            // Export writes an ExportPackage ("tasksWithSubtasks"); older files used "othertasks"
            let dtos: [OtherTaskDTO]
            if let package = try? JSONDecoder().decode(ExportPackage.self, from: data) {
                dtos = package.tasksWithSubtasks
            } else {
                dtos = try JSONDecoder().decode(OtherTaskPackage.self, from: data).othertasks
            }

            let existing = tasksWithSubtasks

            func exists(_ dto: OtherTaskDTO) -> Bool {
                existing.contains { $0.id == dto.id }
            }

            for dto in dtos where !exists(dto) {
                let convertedSubtasks = dto.subtasks.map { subDTO in
                    SubtaskModel(
                        id: subDTO.id,
                        title: subDTO.title,
                        isCompleted: subDTO.isCompleted
                    )
                }
                let item = OtherTaskModel(
                    id: dto.id,
                    title: dto.title,
                    isCompleted: dto.isCompleted,
                    subtasks: convertedSubtasks

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

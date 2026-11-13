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
    @State private var editingProject: OtherTaskModel?
    @State private var editingSubtask: SubtaskModel?
    @State private var newSubtask: NewSubtaskRequest?
    @State private var newHasStart = false
    @State private var newStart = StartEndRows.defaultStart
    @State private var newHasEnd = false
    @State private var newEnd = StartEndRows.defaultEnd

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
            // Plain Form (no KeyboardDismissWrapper), so Edit windows and the list update normally
                Form {
                    // 🔹 Add Task Section
                    Section(header: Text("Add New Task")) {
                        TextField("Task Title", text: $newTaskTitle)
                            .submitLabel(.done)
                            .onSubmit {
                                hideKeyboard()
                            }

                        // Optional start and end, with a notification at each
                        StartEndRows(hasStart: $newHasStart, start: $newStart, hasEnd: $newHasEnd, end: $newEnd)

                        Button("Add Project") {
                            if !newTaskTitle.isEmpty {
                                let newTask = OtherTaskModel(title: newTaskTitle)
                                newTask.startDate = newHasStart ? newStart : nil
                                newTask.endDate = newHasEnd ? max(newEnd, newHasStart ? newStart : newEnd) : nil
                                modelContext.insert(newTask)
                                try? modelContext.save()   // save now, don't wait for autosave
                                ReminderScheduler.refresh(context: modelContext)
                                newTaskTitle = ""
                                newHasStart = false
                                newHasEnd = false
                                newStart = StartEndRows.defaultStart
                                newEnd = StartEndRows.defaultEnd
                                Toast.show("Project added")
                            }
                        }
                        .buttonStyle(.borderedProminent)   // blue, like Export
                        .frame(maxWidth: .infinity, alignment: .trailing)   // right side of the screen
                    }

                    // 🔸 Active Tasks Section
                    Section(header: Text("Projects – tap to complete, hold to edit")) {
                        ForEach(sortedTasks().filter { !$0.isCompleted }, id: \.id) { task in
                            SubtaskSectionView(
                                task: task,
                                onAdd: { newSubtaskText in
                                    newSubtask = NewSubtaskRequest(project: task, title: newSubtaskText)
                                },
                                onToggleCompletion: {
                                    toggleTaskCompletion(task)
                                },
                                onEditProject: { editingProject = task },
                                onEditSubtask: { editingSubtask = $0 }
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
                                        newSubtask = NewSubtaskRequest(project: task, title: newSubtaskText)
                                    },
                                    onToggleCompletion: {
                                        toggleTaskCompletion(task)
                                    },
                                    onEditProject: { editingProject = task },
                                    onEditSubtask: { editingSubtask = $0 }
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
                .scrollDismissesKeyboard(.interactively)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
                }
            .navigationBarTitleDisplayMode(.inline) // optional
            .navigationTitle("")
            .sheet(item: $editingProject) { EditProjectSheet(project: $0) }
            .sheet(item: $editingSubtask) { EditSubtaskSheet(subtask: $0) }
            .sheet(item: $newSubtask) { request in
                NewSubtaskSheet(title: request.title) { title, start, end in
                    addSubtask(to: request.project, subtaskTitle: title, start: start, end: end)
                }
            }
            }
        }
    }

    private func addSubtask(to task: OtherTaskModel, subtaskTitle: String, start: Date?, end: Date?) {
        let subtask = SubtaskModel(title: subtaskTitle)
        subtask.startDate = start
        subtask.endDate = end
        task.subtasks.append(subtask)
        try? modelContext.save()
        ReminderScheduler.refresh(context: modelContext)   // start and end notifications
        Toast.show("Subtask added")
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
        ReminderScheduler.refresh(context: modelContext)   // no reminders for finished projects
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
        ReminderScheduler.refresh(context: modelContext)
    }

    private func exportOtherTasks() {
        let activeTasks = tasksWithSubtasks.filter { !$0.isCompleted }
        let dtos: [OtherTaskDTO] = activeTasks.map { task in

            let subtaskDTOs: [SubtaskDTO] = task.subtasks.map { sub in
                SubtaskDTO(
                    id: sub.id,
                    title: sub.title,
                    isCompleted: sub.isCompleted,
                    startDate: sub.startDate,
                    endDate: sub.endDate
                )
            }

            return OtherTaskDTO(
                id: task.id,
                title: task.title,
                isCompleted: false,
                subtasks: subtaskDTOs,
                startDate: task.startDate,
                endDate: task.endDate
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
                    let sub = SubtaskModel(
                        id: subDTO.id,
                        title: subDTO.title,
                        isCompleted: subDTO.isCompleted
                    )
                    sub.startDate = subDTO.startDate
                    sub.endDate = subDTO.endDate
                    return sub
                }
                let item = OtherTaskModel(
                    id: dto.id,
                    title: dto.title,
                    isCompleted: dto.isCompleted,
                    subtasks: convertedSubtasks

                )
                item.startDate = dto.startDate
                item.endDate = dto.endDate
                modelContext.insert(item)
            }

            try? modelContext.save()
            ReminderScheduler.refresh(context: modelContext)
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

/// Which project a new subtask goes into, and the title typed so far
struct NewSubtaskRequest: Identifiable {
    let id = UUID()
    let project: OtherTaskModel
    let title: String
}

//
//  SubtaskSectionView.swift
//  ToBeDone
//

import SwiftUI
import SwiftData

struct SubtaskSectionView: View {
    @Bindable var task: OtherTaskModel
    var onAdd: (String) -> Void
    var onToggleCompletion: () -> Void
    var onEditProject: () -> Void = {}
    var onEditSubtask: (SubtaskModel) -> Void = { _ in }

    @Environment(\.modelContext) private var modelContext
    @State private var localSubtask: String = ""
    /// Closed by default; open in the App Store screenshot so the subtasks show
    @State private var isExpanded = DemoData.isEnabled

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach($task.subtasks) { $subtask in
                HStack {
                    Button(action: {
                        subtask.isCompleted.toggle()
                        try? modelContext.save() // ✅ Save toggle
                        ReminderScheduler.refresh(context: modelContext)   // no reminders for finished subtasks
                    }) {
                        Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(subtask.isCompleted ? .green : .gray)
                    }
                    .buttonStyle(BorderlessButtonStyle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text(subtask.title)
                        if let dates = dateRangeText(start: subtask.startDate, end: subtask.endDate) {
                            Text(dates).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
                .editAction { onEditSubtask(subtask) }   // swipe right or touch and hold
            }

            HStack {
                TextField("New Subtask", text: $localSubtask)
                // Opens "New Subtask" with this title, where start and end can be set
                Button("Add") {
                    if !localSubtask.trimmingCharacters(in: .whitespaces).isEmpty {
                        onAdd(localSubtask)
                        localSubtask = ""
                    }
                }
                .buttonStyle(.borderedProminent)   // blue, like Export
            }
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .gray : .primary)
                if let dates = dateRangeText(start: task.startDate, end: task.endDate) {
                    Label(dates, systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onTapGesture {
                onToggleCompletion()
            }
            .editAction { onEditProject() }   // swipe right or touch and hold
        }
    }
}

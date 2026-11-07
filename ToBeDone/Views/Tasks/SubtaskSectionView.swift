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
                    }) {
                        Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(subtask.isCompleted ? .green : .gray)
                    }
                    .buttonStyle(BorderlessButtonStyle())

                    Text(subtask.title)
                }
            }

            HStack {
                TextField("New Subtask", text: $localSubtask)
                Button("Add") {
                    if !localSubtask.isEmpty {
                        onAdd(localSubtask)
                        localSubtask = ""
                    }
                }
                .buttonStyle(.borderedProminent)   // blue, like Export
            }
        } label: {
            Text(task.title)
                .strikethrough(task.isCompleted)
                .foregroundColor(task.isCompleted ? .gray : .primary)
                .onTapGesture {
                    onToggleCompletion()
                }
        }
    }
}

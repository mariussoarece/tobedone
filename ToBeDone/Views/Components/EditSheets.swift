//
//  EditSheets.swift
//  ToBeDone
//
//  The "Edit" windows for To Do tasks, Shopping and Grocery items, Projects,
//  subtasks and Daily Routine activities. Open one by swiping a row to the
//  right, or by touching and holding it. Nothing changes until Save is tapped.
//

import SwiftUI
import SwiftData

// MARK: - Shared frame

/// Form + Cancel / Save, used by every edit window.
private struct EditForm<Content: View>: View {
    let title: String
    let canSave: Bool
    let onSave: () -> Void
    let content: () -> Content
    @Environment(\.dismiss) private var dismiss

    init(title: String, canSave: Bool, onSave: @escaping () -> Void,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.canSave = canSave
        self.onSave = onSave
        self.content = content
    }

    var body: some View {
        NavigationStack {
            Form { content() }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onSave()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave)
                    }
                }
        }
    }
}

private func trimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }

/// Swipe right (or touch and hold) on a row to edit it.
extension View {
    func editAction(_ action: @escaping () -> Void) -> some View {
        self
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button(action: action) { Label("Edit", systemImage: "pencil") }
                    .tint(.blue)
            }
            .contextMenu {
                Button(action: action) { Label("Edit", systemImage: "pencil") }
            }
    }
}

// MARK: - To Do

struct EditTaskSheet: View {
    @Environment(\.modelContext) private var modelContext
    let task: TaskModel

    @State private var title: String
    @State private var dueDate: Date
    @State private var priority: TaskPriority
    @State private var remindBefore: Bool
    @State private var remindMinutes: Int

    init(task: TaskModel) {
        self.task = task
        _title = State(initialValue: task.title)
        _dueDate = State(initialValue: task.dueDate)
        _priority = State(initialValue: task.priority)
        _remindBefore = State(initialValue: (task.reminderMinutes ?? 0) > 0)
        _remindMinutes = State(initialValue: task.reminderMinutes ?? 30)
    }

    var body: some View {
        EditForm(title: "Edit Task", canSave: !trimmed(title).isEmpty, onSave: save) {
            Section {
                TextField("Task Title", text: $title)
                DatePicker("Due Date & Time", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                Picker("Priority", selection: $priority) {
                    ForEach(TaskPriority.allCases) { Text($0.rawValue).tag($0) }
                }
                ReminderBeforeRows(isOn: $remindBefore, minutesBefore: $remindMinutes, start: dueDate)
            }
        }
    }

    private func save() {
        task.title = trimmed(title)
        task.dueDate = Date(timeIntervalSinceReferenceDate: floor(dueDate.timeIntervalSinceReferenceDate / 60) * 60)
        task.priority = priority
        task.reminderMinutes = remindBefore && remindMinutes > 0 ? remindMinutes : nil
        try? modelContext.save()
        // The due-time reminder follows the new date
        NotificationManager.shared.cancelNotification(for: task)
        NotificationManager.shared.scheduleNotification(for: task)
        ReminderScheduler.refresh(context: modelContext)
        Toast.show("Task saved")
    }
}

// MARK: - Shopping

struct EditShoppingItemSheet: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedCurrency") private var selectedCurrency: String = "USD"
    let item: ShoppingItemModel

    @State private var name: String
    @State private var price: String
    @State private var priority: TaskPriority

    init(item: ShoppingItemModel) {
        self.item = item
        _name = State(initialValue: item.name)
        _price = State(initialValue: item.price.formatted(.number.precision(.fractionLength(0...2)).grouping(.never)))
        _priority = State(initialValue: item.priority)
    }

    var body: some View {
        EditForm(title: "Edit Item", canSave: !trimmed(name).isEmpty && price.decimalValue != nil, onSave: save) {
            Section {
                TextField("Item Name", text: $name)
                HStack {
                    TextField("Price", text: $price).keyboardType(.decimalPad)
                    Text(selectedCurrency).foregroundStyle(.secondary)
                }
                if price.decimalValue == nil {
                    Text("Please enter a price").font(.footnote).foregroundStyle(.red)
                }
                Picker("Priority", selection: $priority) {
                    ForEach(TaskPriority.allCases) { Text($0.rawValue).tag($0) }
                }
            }
        }
    }

    private func save() {
        item.name = trimmed(name)
        item.price = price.decimalValue ?? item.price
        item.priority = priority
        try? modelContext.save()
        Toast.show("Item saved")
    }
}

// MARK: - Grocery

struct EditGroceryItemSheet: View {
    @Environment(\.modelContext) private var modelContext
    let item: GroceryItemModel
    @State private var name: String

    init(item: GroceryItemModel) {
        self.item = item
        _name = State(initialValue: item.name)
    }

    var body: some View {
        EditForm(title: "Edit Item", canSave: !trimmed(name).isEmpty, onSave: save) {
            Section { TextField("Item Name", text: $name) }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        item.name = trimmed(name)
        try? modelContext.save()
        Toast.show("Item saved")
    }
}

// MARK: - Start and end dates (Projects and subtasks)

/// "Start date" and "End date" switches, each with a date & time picker.
struct StartEndRows: View {
    @Binding var hasStart: Bool
    @Binding var start: Date
    @Binding var hasEnd: Bool
    @Binding var end: Date

    var body: some View {
        Toggle("Start date", isOn: $hasStart)
        if hasStart {
            DatePicker("Starts", selection: $start, displayedComponents: [.date, .hourAndMinute])
        }
        Toggle("End date", isOn: $hasEnd)
        if hasEnd {
            DatePicker("Ends", selection: $end, in: (hasStart ? start : .distantPast)...,
                       displayedComponents: [.date, .hourAndMinute])
        }
    }

    /// Default times: start today at 9:00, end in a week at 18:00
    static var defaultStart: Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    }
    static var defaultEnd: Date {
        let inAWeek = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        return Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: inAWeek) ?? inAWeek
    }
}

/// "15 Nov – 30 Nov", "From 15 Nov", "Until 30 Nov", or nil
func dateRangeText(start: Date?, end: Date?) -> String? {
    let f: (Date) -> String = { $0.formatted(.dateTime.day().month(.abbreviated).hour().minute()) }
    switch (start, end) {
    case let (s?, e?): return "\(f(s)) – \(f(e))"
    case let (s?, nil): return "From \(f(s))"
    case let (nil, e?): return "Until \(f(e))"
    default: return nil
    }
}

// MARK: - Projects

struct EditProjectSheet: View {
    @Environment(\.modelContext) private var modelContext
    let project: OtherTaskModel

    @State private var title: String
    @State private var hasStart: Bool
    @State private var start: Date
    @State private var hasEnd: Bool
    @State private var end: Date

    init(project: OtherTaskModel) {
        self.project = project
        _title = State(initialValue: project.title)
        _hasStart = State(initialValue: project.startDate != nil)
        _start = State(initialValue: project.startDate ?? StartEndRows.defaultStart)
        _hasEnd = State(initialValue: project.endDate != nil)
        _end = State(initialValue: project.endDate ?? StartEndRows.defaultEnd)
    }

    var body: some View {
        EditForm(title: "Edit Project", canSave: !trimmed(title).isEmpty, onSave: save) {
            Section {
                TextField("Project Title", text: $title)
            }
            Section {
                StartEndRows(hasStart: $hasStart, start: $start, hasEnd: $hasEnd, end: $end)
            } footer: {
                Text("You get a notification when the project starts and when it should be finished.")
            }
        }
    }

    private func save() {
        project.title = trimmed(title)
        project.startDate = hasStart ? start : nil
        project.endDate = hasEnd ? max(end, hasStart ? start : end) : nil
        try? modelContext.save()
        ReminderScheduler.refresh(context: modelContext)   // start and end notifications
        Toast.show("Project saved")
    }
}

struct EditSubtaskSheet: View {
    @Environment(\.modelContext) private var modelContext
    let subtask: SubtaskModel

    @State private var title: String
    @State private var hasStart: Bool
    @State private var start: Date
    @State private var hasEnd: Bool
    @State private var end: Date

    init(subtask: SubtaskModel) {
        self.subtask = subtask
        _title = State(initialValue: subtask.title)
        _hasStart = State(initialValue: subtask.startDate != nil)
        _start = State(initialValue: subtask.startDate ?? StartEndRows.defaultStart)
        _hasEnd = State(initialValue: subtask.endDate != nil)
        _end = State(initialValue: subtask.endDate ?? StartEndRows.defaultEnd)
    }

    var body: some View {
        EditForm(title: "Edit Subtask", canSave: !trimmed(title).isEmpty, onSave: save) {
            Section {
                TextField("Subtask", text: $title)
            }
            Section {
                StartEndRows(hasStart: $hasStart, start: $start, hasEnd: $hasEnd, end: $end)
            }
        }
    }

    private func save() {
        subtask.title = trimmed(title)
        subtask.startDate = hasStart ? start : nil
        subtask.endDate = hasEnd ? max(end, hasStart ? start : end) : nil
        try? modelContext.save()
        Toast.show("Subtask saved")
    }
}

// MARK: - Daily Routine

/// Edits one activity. For a repeating activity, only this day changes.
struct EditActivitySheet: View {
    @Environment(\.modelContext) private var modelContext
    let item: ActivityItem
    /// Called with the old and the new start, after saving
    var onSaved: (Date, Date) -> Void = { _, _ in }

    @State private var name: String
    @State private var details: String
    @State private var date: Date
    @State private var duration: Double
    @State private var remindBefore: Bool
    @State private var remindMinutes: Int

    init(item: ActivityItem, onSaved: @escaping (Date, Date) -> Void = { _, _ in }) {
        self.item = item
        self.onSaved = onSaved
        _name = State(initialValue: item.name)
        _details = State(initialValue: item.details)
        _date = State(initialValue: item.date)
        _duration = State(initialValue: Double(item.durationMinutes))
        _remindBefore = State(initialValue: (item.reminderMinutes ?? 0) > 0)
        _remindMinutes = State(initialValue: item.reminderMinutes ?? 30)
    }

    var body: some View {
        EditForm(title: "Edit Activity", canSave: !trimmed(name).isEmpty, onSave: save) {
            Section("Activity") {
                TextField("Name", text: $name)
                TextField("Description", text: $details, axis: .vertical).lineLimit(1...3)
                DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                Stepper(value: $duration, in: 0...480, step: 5) { Text("Duration: \(Int(duration)) min") }
            }
            Section {
                ReminderBeforeRows(isOn: $remindBefore, minutesBefore: $remindMinutes, start: date)
            } footer: {
                if item.seriesId != nil {
                    Text("This activity repeats: only this day is changed.")
                }
            }
        }
    }

    private func save() {
        let oldDate = item.date
        item.name = trimmed(name)
        item.details = details
        item.date = date
        item.durationMinutes = Int(duration)
        item.reminderMinutes = remindBefore && remindMinutes > 0 ? remindMinutes : nil
        try? modelContext.save()
        ReminderScheduler.refresh(context: modelContext)
        onSaved(oldDate, date)
        Toast.show("Activity saved")
    }
}

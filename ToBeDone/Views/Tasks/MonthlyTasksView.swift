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
    @State private var newDay: Int = min(Calendar.current.component(.day, from: .now), 28)
    @State private var newTime: Date = MonthlyTasksView.tenOClock
    @State private var editing: MonthlyTaskModel?
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
            // No KeyboardDismissWrapper here: its separate hosting controller kept the
            // list from refreshing after an edit (and the Edit window from closing).
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

                        // Only 1–28, so the day exists in every month
                        Picker("Day of month", selection: $newDay) {
                            ForEach(1...28, id: \.self) { Text("\($0)").tag($0) }
                        }

                        DatePicker("Time", selection: $newTime, displayedComponents: .hourAndMinute)

                        Button("Add Task") {
                            addTask()
                        }
                        .buttonStyle(.borderedProminent)   // blue, like Export
                        .frame(maxWidth: .infinity, alignment: .trailing)   // right side of the screen
                    }

                    Section(header: Text("Monthly Tasks - Tap to edit, swipe to delete")) {
                        ForEach(sortedTasks, id: \.id) { task in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.title)
                                    // "Every month on day 5 at 10:00"
                                    Text(task.scheduleText ?? "No day set – tap to choose one")
                                        .font(.caption)
                                        .foregroundStyle(task.dayOfMonth == nil ? Color.orange : Color.secondary)
                                }
                                Spacer()
                                Text("\(task.price, specifier: "%.2f") \(selectedCurrency)")
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { editing = task }
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
                .scrollDismissesKeyboard(.interactively)
                .toolbar {
                    // The number pad has no Return key, so add a Done button above the keyboard
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { hideKeyboard() }
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
            .sheet(item: $editing) { task in
                EditMonthlyTaskSheet(task: task) {
                    try? modelContext.save()
                    ReminderScheduler.refresh(context: modelContext)
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
        let time = Calendar.current.dateComponents([.hour, .minute], from: newTime)
        let newTask = MonthlyTaskModel(title: title, price: price, dayOfMonth: newDay,
                                       hour: time.hour ?? 10, minute: time.minute ?? 0)
        modelContext.insert(newTask)
        try? modelContext.save()   // save now, don't wait for autosave
        ReminderScheduler.refresh(context: modelContext)   // monthly reminder
        newTaskTitle = ""
        newTaskPrice = ""
        newTime = Self.tenOClock
    }

    /// Default time for a new monthly expense: 10:00
    static var tenOClock: Date {
        Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: .now) ?? .now
    }

    /// By day of the month, then time; items without a day at the end
    private var sortedTasks: [MonthlyTaskModel] {
        monthlyTasks.sorted {
            let a = ($0.dayOfMonth ?? 99, $0.hour * 60 + $0.minute)
            let b = ($1.dayOfMonth ?? 99, $1.hour * 60 + $1.minute)
            return a < b
        }
    }

    private func deleteTask(at offsets: IndexSet) {
        let sorted = sortedTasks
        for index in offsets {
            modelContext.delete(sorted[index])
        }
        try? modelContext.save()
        ReminderScheduler.refresh(context: modelContext)
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
                    dayOfMonth: dto.dayOfMonth,
                    hour: dto.hour ?? 10,
                    minute: dto.minute ?? 0
                )
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

// MARK: - Edit sheet

/// Change the title, price, day of the month and time of a monthly expense.
struct EditMonthlyTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedCurrency") private var selectedCurrency: String = "USD"
    let task: MonthlyTaskModel
    var onSave: () -> Void

    @State private var title: String
    @State private var price: String
    @State private var day: Int
    @State private var time: Date

    init(task: MonthlyTaskModel, onSave: @escaping () -> Void) {
        self.task = task
        self.onSave = onSave
        _title = State(initialValue: task.title)
        _price = State(initialValue: task.price == 0 ? "" : task.price.formatted(.number.precision(.fractionLength(0...2)).grouping(.never)))
        _day = State(initialValue: task.dayOfMonth ?? min(Calendar.current.component(.day, from: .now), 28))
        _time = State(initialValue: Calendar.current.date(bySettingHour: task.hour, minute: task.minute,
                                                          second: 0, of: .now) ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Monthly expense") {
                    TextField("Task Title", text: $title)
                    HStack {
                        TextField("Price", text: $price)
                            .keyboardType(.decimalPad)
                        Text(selectedCurrency).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Picker("Day of month", selection: $day) {
                        ForEach(1...28, id: \.self) { Text("\($0)").tag($0) }
                    }
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                } footer: {
                    Text("You get a reminder every month on this day and time. Days 29–31 aren't offered because not every month has them.")
                }
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = title.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        let t = Calendar.current.dateComponents([.hour, .minute], from: time)
                        task.title = trimmed
                        task.price = price.decimalValue ?? 0
                        task.dayOfMonth = day
                        task.timeOfDayMinutes = (t.hour ?? 10) * 60 + (t.minute ?? 0)
                        onSave()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

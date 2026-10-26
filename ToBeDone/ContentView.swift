import SwiftUI
import SwiftData
import UserNotifications
import Charts

 
@main
struct LifeOrderingApp: App {
    init() {
            NotificationManager.shared.requestPermission()
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TaskModel.self,
            ShoppingItemModel.self,
            MonthlyTaskModel.self,
            OtherTaskModel.self,
            SubtaskModel.self,
            GroceryItemModel.self,
            ConfidenceEntry.self,
            ActivityItem.self,
            FocusResult.self,
        ])
        let config = ModelConfiguration("default") // same as before
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    var body: some Scene {
        WindowGroup {
            if hasSeenIntroPage {
                HomeView()
                    .modelContainer(sharedModelContainer)
            } else {
                IntroPage(hasSeenIntroPage: $hasSeenIntroPage)
                    .modelContainer(sharedModelContainer)
            }
        }
    }
    
    @AppStorage("hasSeenIntroPage") private var hasSeenIntroPage: Bool = false
    
    struct IntroPage: View {
        @AppStorage("userName") private var userName = ""
        @Binding var hasSeenIntroPage: Bool
        @State private var startFocusTest = false
        @State private var showExplanation = false

        
        var body: some View {
            VStack(spacing: 24) {
                Text("Caveat")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("""
    This app will help you — it really will — but the real change starts with you.  
    If you decide **right now** to consciously guide your thoughts and actions, the app becomes a powerful tool instead of just doing half the work.

    Motivate your mind to act on the things you want to do.  
    Every positive thought builds an action, every positive action builds confidence.  
    This is the flow that you need to carry on all your life.
    """)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .padding()
                Text("Let's beggin! How should we call you?")
                    .font(.headline)

                TextField("Enter your name", text: $userName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                Button("Continue") {
                    
                    showExplanation = true
                    
                }
                .fullScreenCover(isPresented: $showExplanation) {
                    FocusTestExplanationView()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 20)
            }
            .padding()
        }
    }

}

@Model
class ShoppingItemModel: Identifiable {
    var id: UUID = UUID()
    var name: String
    var price: Double
    var currency: String
    var priority: TaskPriority
    var isCompleted: Bool = false
    var completedAt: Date?
    
    init(
        id: UUID = UUID(),
        name: String,
        price: Double,
        currency: String,
        priority: TaskPriority = .medium,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.price = price
        self.currency = currency
        self.priority = priority
        self.isCompleted = isCompleted
    }
}
 
@Model
class MonthlyTaskModel: Identifiable {
    var id: UUID = UUID()         // Important for identifying items in the list
    var title: String
    var price: Double

    init(title: String, price: Double = 0.0) {
        self.title = title
        self.price = price
    }
}






enum TaskPriority: String, CaseIterable, Identifiable, Codable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    
    var id: String { self.rawValue }
}
 
 
 
// MARK: - Settings View
struct SettingsView: View {
    @AppStorage("selectedTheme") private var selectedTheme: String = "Default"
    @AppStorage("selectedCurrency") private var selectedCurrency: String = "USD"
    @AppStorage("reminderHour") private var reminderHour: Int = 22
    @AppStorage("reminderMinute") private var reminderMinute: Int = 0

    let currencies = [
        "USD", "EUR", "GBP", "RON", "JPY", "CNY", "INR", "AUD", "CAD", "CHF",
        "SEK", "NOK", "DKK", "NZD", "ZAR", "RUB", "BRL", "MXN", "SGD", "HKD",
        "TRY", "PLN", "HUF", "CZK", "ARS", "KRW", "THB", "AED", "SAR", "EGP",
        "NGN", "MYR", "IDR", "VND", "ILS", "BGN", "UAH", "PKR"
    ]
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // ✅ Custom large title — not next to the back button
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .padding(.top)
                
                Form {
                    Section(header: Text("Appearance")) {
                        Picker("Theme", selection: $selectedTheme) {
                            Text("Default").tag("Default")
                            Text("Light").tag("Light")
                            Text("Dark").tag("Dark")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    Section(header: Text("Currency")) {
                        Picker("Currency", selection: $selectedCurrency) {
                            ForEach(currencies, id: \.self) { currency in
                                Text(currency)
                            }
                        }
                    }
                    Section(header: Text("Daily Activity Reminder")) {
                        DatePicker(
                            "Reminder Time",
                            selection: Binding(
                                get: {
                                    Calendar.current.date(from: DateComponents(
                                        hour: reminderHour,
                                        minute: reminderMinute
                                    )) ?? Date()
                                },
                                set: { newValue in
                                    let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                    reminderHour = comps.hour ?? 22
                                    reminderMinute = comps.minute ?? 0
                                    scheduleDailyActivityReminder()
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    }

                }
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline) // optional
            .navigationTitle("")
        }
    }
    func scheduleDailyActivityReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["activityReminder"])

        let content = UNMutableNotificationContent()
        content.title = "Daily Activity Reminder"
        content.body = buildIncompleteActivitiesMessage()
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: reminderHour, minute: reminderMinute),
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "activityReminder",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }
    func buildIncompleteActivitiesMessage() -> String {
        let context = ModelContext(try! ModelContainer(for: ActivityItem.self))
        let today = Calendar.current.startOfDay(for: Date())

        let items = try? context.fetch(FetchDescriptor<ActivityItem>())
        let incomplete = items?.filter { !$0.isCompleted && Calendar.current.isDate($0.date, inSameDayAs: today) } ?? []

        if incomplete.isEmpty {
            return "All activities completed today. Great job!"
        }

        let bullets = incomplete.map { "• \($0.name)" }.joined(separator: "\n")
        return "You still have activities to complete:\n\(bullets)"
    }
}
 
// MARK: - Apple Watch Sync (Placeholder)
#if os(watchOS)
import WatchConnectivity
class WatchSessionManager: NSObject, WCSessionDelegate {
    static let shared = WatchSessionManager()
    private override init() { super.init() }
    func setupSession() {
        if WCSession.default.isSupported {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Handle messages from Apple Watch
    }
}
#endif
 
 
// MARK: - Task Model
@Model
class TaskModel: Identifiable {
    var id: UUID = UUID()
    var title: String
    var dueDate: Date
    var priority: TaskPriority
    var isCompleted: Bool = false {
        didSet {
            if isCompleted {
                NotificationManager.shared.cancelNotification(for: self)
            }
        }
    }
    
    init( title: String, dueDate: Date, priority: TaskPriority) {
        self.title = title
        self.dueDate = dueDate
        self.priority = priority
        NotificationManager.shared.scheduleNotification(for: self)
    }
}
 

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
        NavigationStack {
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

        // If you use local notifications, schedule here:
        // NotificationManager.shared.scheduleNotification(for: newTask)

        // Reset UI
        newTaskTitle = ""
        dueDate = Date()
        selectedPriority = .medium
    }

    private func toggleCompletion(_ task: TaskModel) {
        task.isCompleted.toggle()
        try? modelContext.save()
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
            }

            try? modelContext.save()
        } catch {
            print("Import decode error:", error)
        }
    }

}


// MARK: - Shopping Tasks View
struct ShoppingTasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var shoppingItems: [ShoppingItemModel]

    @State private var newItemName: String = ""
    @State private var newItemPrice: String = ""
    @State private var selectedPriority: TaskPriority = .medium
    @AppStorage("selectedCurrency") private var selectedCurrency: String = ""
    @State private var exportURL: URL?
    @State private var showingImporter = false
    @State private var editingItem: ShoppingItemModel?
    @State private var editedPrice: String = ""
    @State private var showEditPriceSheet = false
    
    var body: some View {
        NavigationStack {
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
                            if let price = Double(newItemPrice) {
                                let newItem = ShoppingItemModel(name: newItemName, price: price, currency: selectedCurrency, priority: selectedPriority)
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
                        if let newPrice = Double(editedPrice) {
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
            let package = try JSONDecoder().decode(ShoppingTaskPackage.self, from: data)

            let existing = shoppingItems

            func exists(_ dto: ShoppingItemDTO) -> Bool {
                existing.contains {
                    $0.id == dto.id &&
                    $0.name == dto.name &&
                    $0.price == dto.price
                }
            }

            for dto in package.shoppingtasks where !exists(dto) {
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


 
// MARK: - Date Formatter
extension DateFormatter {
    static var shortDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }
}



// MARK: - Notification Manager
class NotificationManager {
    static let shared = NotificationManager()
    @AppStorage("reminderHour") private var reminderHour: Int = 22
    @AppStorage("reminderMinute") private var reminderMinute: Int = 0
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
            print("Granted: \(granted)")
        }
    }
    
    func scheduleNotification(for task: TaskModel) {
        let content = UNMutableNotificationContent()
        content.title = "Task Reminder"
        content.body = "Don't forget: \(task.title) is due today!"
        content.sound = .default
        
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: task.dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let request = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelNotification(for task: TaskModel) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [task.id.uuidString])
    }
    func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("Authorization:", settings.authorizationStatus.rawValue)
            print("Alert:", settings.alertSetting.rawValue)
            print("Sound:", settings.soundSetting.rawValue)
            print("Badge:", settings.badgeSetting.rawValue)
        }
    }
    
    


}



struct MonthlyTasksView: View {
    @Query private var monthlyTasks: [MonthlyTaskModel]
    @Environment(\.modelContext) private var modelContext

    @State private var newTaskTitle: String = ""
    @State private var newTaskPrice: String = ""
    @AppStorage("selectedCurrency") private var selectedCurrency: String = ""
    @State private var exportURL: URL?
    @State private var showingImporter = false
    
    var body: some View {
        NavigationStack {
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
        guard !newTaskTitle.isEmpty else { return }
        let price = Double(newTaskPrice) ?? 0.0
        let newTask = MonthlyTaskModel(title: newTaskTitle, price: price)
        modelContext.insert(newTask)
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
                existing.contains {
                    $0.id == dto.id &&
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






@Model
class SubtaskModel: Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var isCompleted: Bool = false
    
    init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
            self.id = id
            self.title = title
            self.isCompleted = isCompleted
        }

    static func == (lhs: SubtaskModel, rhs: SubtaskModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@Model
class OtherTaskModel: Identifiable {
    var id = UUID()
    var title: String
    var subtasks: [SubtaskModel] = []
    var isCompleted: Bool = false  // ✅ New
    
    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        subtasks: [SubtaskModel] = []
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.subtasks = subtasks
    }
}




struct SubtaskSectionView: View {
    @Bindable var task: OtherTaskModel
    var onAdd: (String) -> Void
    var onToggleCompletion: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var localSubtask: String = ""

    var body: some View {
        DisclosureGroup {
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


struct OtherTasksView: View {
    @Query private var tasksWithSubtasks: [OtherTaskModel]
    @Environment(\.modelContext) private var modelContext

    @State private var newTaskTitle: String = ""
    @State private var exportURL: URL?
    @State private var showingImporter = false
    
    var body: some View {
        NavigationStack {
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

                        Button("Add Task") {
                            if !newTaskTitle.isEmpty {
                                let newTask = OtherTaskModel(title: newTaskTitle)
                                modelContext.insert(newTask)
                                newTaskTitle = ""
                            }
                        }
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
            let package = try JSONDecoder().decode(OtherTaskPackage.self, from: data)

            let existing = tasksWithSubtasks

            func exists(_ dto: OtherTaskDTO) -> Bool {
                existing.contains {
                    $0.title == dto.title &&
                    $0.id == dto.id
                }
            }

            for dto in package.othertasks where !exists(dto) {
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

@Model
class GroceryItemModel: Identifiable {
    var id: UUID = UUID()
    var name: String
    var isBought: Bool = false

    init(name: String, isBought: Bool = false) {
        self.name = name
        self.isBought = isBought
    }
}

struct GroceryTasksView: View {
    @Query private var groceryItems: [GroceryItemModel]
    @Environment(\.modelContext) private var modelContext

    @State private var newItemName: String = ""

    var body: some View {
        NavigationStack {
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
                            guard !newItemName.isEmpty else { return }
                            let item = GroceryItemModel(name: newItemName)
                            modelContext.insert(item)
                            newItemName = ""
                        }
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
        let completedTasks = sortedItems()
        for index in offsets {
            let taskToDelete = completedTasks[index]
            modelContext.delete(taskToDelete)
        }
        try? modelContext.save()
    }

}



/// A wrapper that allows dismissing the keyboard when tapping anywhere outside.
struct KeyboardDismissWrapper<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        RepresentableWrapper(content: content)
    }

    private struct RepresentableWrapper: UIViewControllerRepresentable {
        let content: Content

        func makeUIViewController(context: Context) -> UIViewController {
            let controller = UIHostingController(rootView: content)
            let tapGesture = UITapGestureRecognizer(target: controller.view, action: #selector(UIView.endEditing))
            tapGesture.cancelsTouchesInView = false
            controller.view.addGestureRecognizer(tapGesture)
            return controller
        }

        func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
            (uiViewController as? UIHostingController<Content>)?.rootView = content
        }
    }
}


struct HomeView: View {
    @AppStorage("userName") private var userName: String = ""
    @State private var showFocusTest = false
    @State private var startTest = false
    @State private var showResults = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: - Greeting header
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Hi, \(userName.isEmpty ? "Friend" : userName)")
                                .font(.largeTitle.bold())
                            Image(systemName: "heart.fill")
                                .foregroundColor(.pink.opacity(0.6))
                                .font(.title2)
                        }
                        Text("The more organized you, the happier you.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // MARK: - Handwritten accent (top right)

                    HStack {
                        Spacer()

                        Image("small_steps_big_changes")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80)
                    }
                    .padding(.horizontal)
                    
                    // MARK: - Blue banner
                    VStack(spacing: 4) {
                        Text("Life Ordering App")
                            .font(.title.bold())
                            .foregroundColor(.white)
                        Text("PLAN  ·  DO  ·  GROW")
                            .font(.caption)
                            .tracking(2)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.blue.opacity(0.85))
                    )
                    .padding(.horizontal)

                    // MARK: - Card grid
                    Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                        GridRow {
                            taskCard("To Do List", subtitle: "Get things done",
                                     icon: "list.clipboard", color: .blue, destination: DueTasksView())
                            taskCard("Shopping List", subtitle: "Buy what you need",
                                     icon: "cart.fill", color: .red, destination: ShoppingTasksView())
                        }
                        GridRow {
                            taskCard("Monthly Expenses", subtitle: "Spend with purpose",
                                     icon: "calendar", color: .orange, destination: MonthlyTasksView())
                            taskCard("Project Tasks", subtitle: "Work toward goals",
                                     icon: "target", color: .green, destination: OtherTasksView())
                        }
                        GridRow {
                            taskCard("Grocery List", subtitle: "Healthy choices",
                                     icon: "basket.fill", color: .yellow, destination: GroceryTasksView())
                            taskCard("Daily Routine", subtitle: "Plan your time",
                                     icon: "clock.fill", color: .blue, destination: DailyActivitiesView())
                        }
                        GridRow {
                            taskCard("Confidence Level", subtitle: "Be proud of you",
                                     icon: "heart.fill", color: .red, destination: ConfidenceTrackerView())
                            taskCard("Settings", subtitle: "Customize your app",
                                     icon: "gearshape.fill", color: .gray, destination: SettingsView())
                        }
                    }
                    .padding(.horizontal)

                    // MARK: - Focus test buttons (kept from original)
                    VStack(spacing: 5) {
                        Button("Start Focus Test") { startTest = true }
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.5)))
                            .foregroundColor(.white)

                        Button("View Results") { showResults = true }
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.5)))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal)

                    // MARK: - Handwritten footer

                    
                    VStack {
                        Spacer()

                        Image("you_got_this")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .fullScreenCover(isPresented: $startTest) {
                RedDotFocusTestView(shouldReturnToHome: false, onFinish: { showResults = true })
            }
            .fullScreenCover(isPresented: $showResults) {
                ResultsListView()
            }
        }
    }

    // MARK: - Card builder
    @ViewBuilder
    func taskCard<T: View>(_ title: String, subtitle: String, icon: String, color: Color, destination: T) -> some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.7))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.22))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SwiftData Model
@Model
final class ConfidenceEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var score: Int // 1...10
    var note: String?
    var tags: [String] = []   // ← no @Attribute(.transformable)

    init(id: UUID = UUID(), date: Date = .now, score: Int, note: String? = nil, tags: [String] = []) {
        self.id = id
        self.date = date
        self.score = score
        self.note = note
        self.tags = tags
    }
}

// MARK: - Convenience Filters
extension ConfidenceEntry {
    static func lastNDaysPredicate(_ n: Int) -> Predicate<ConfidenceEntry> {
        let start = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -n+1, to: .now)!)
        return #Predicate<ConfidenceEntry> { $0.date >= start }
    }
}

// MARK: - View: Confidence Tracker
struct ConfidenceTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ConfidenceEntry.date, order: .reverse, animation: .snappy) private var entries: [ConfidenceEntry]
    
    @State private var score: Double = 7
    @State private var note: String = ""
    @State private var selectedTags: Set<String> = []
    @State private var showNoteField: Bool = false
    @State private var showSavedBanner: Bool = false
    
    // Customize the tags to your domain
    private let availableTags = [ "workout", "social", "focus", "rest", "morning", "evening"]
    
    
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // ✅ Custom large title — consistent with your other views
                Text("Confidence")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)       // pick any color you like
                    .padding(.horizontal, -20)

                ScrollView {
                    VStack(spacing: 16) {
                        header
                        inputCard
                        chartCard
                        statsCard
                        recentList
                    }
                }
                .padding(.horizontal, 10)
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { addQuickButtons } }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")                    // hide default title to avoid duplication
            .onAppear { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
            .overlay(alignment: .top) {
                if showSavedBanner {
                    SavedBanner()
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                    
                }
            }
        }
    }


    
    // MARK: - Header
    private var header: some View {
                VStack(alignment: .leading, spacing: 6) {
                    Text("How confident do you feel right now?")
                        .font(.title2.weight(.semibold))
                    Text("Tap a number or use the slider, then Save.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        

    
    
    // MARK: - Input
    private var inputCard: some View {
        VStack(spacing: 12) {
            // Quick picks 1–10
            HStack { ForEach(1...10, id: \.self) { n in
                Button(action: {
                    score = Double(n)
                    haptic()
                }) {
                    Text("\(n)")
                        .font(.callout.bold())
                        .padding(.vertical, 8)
                        .frame(width: 32)
                        .background(roundCapsule(selected: Int(score) == n))
                }
                .buttonStyle(.plain)
            }}
            
            // Slider
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("1")
                    Slider(value: $score, in: 1...10, step: 1)
                    Text("10")
                }
                .accessibilityLabel("Confidence slider")
                Text("Selected: \(Int(score)) / 10")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            
            // Optional note
            if showNoteField {
                ZStack(alignment: .leading) {
                    TextEditor(text: $note)
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemBackground)))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator), lineWidth: 0.5))
                    if note.isEmpty {
                        Text("Optional note (e.g. why you feel this way)")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                    }
                }
            }
            
            HStack {
                Button(noteButtonTitle) { withAnimation { showNoteField.toggle() } }
                    .buttonStyle(.borderless)
                
                Spacer()
                
                Button(action: saveEntry) {
                    Label("Save", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
    
    private var noteButtonTitle: String { showNoteField ? "Hide note" : "Add note" }
    
    // MARK: - Chart
    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Last 30 Days")
                    .font(.headline)
                Spacer()
            }
            
            let grouped = groupDailyAverages(for: entries, lastDays: 30)
            Chart(grouped, id: \.day) { item in
                LineMark(
                    x: .value("Day", item.day),
                    y: .value("Avg", item.avg)
                )
                PointMark(
                    x: .value("Day", item.day),
                    y: .value("Avg", item.avg)
                )
                RuleMark(y: .value("Target", 7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .annotation(position: .leading) { Text("Target 7+").font(.caption2).foregroundStyle(.secondary) }
            }
            .frame(height: 180)
            .chartYScale(domain: 1...10)
            .accessibilityLabel("Confidence over time chart")
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
    
    // MARK: - Stats
    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stats")
                .font(.headline)
            
            let (avg7, avg30) = rollingAverages()
            let (best, worst) = bestWorst()
            let streak = currentStreak(minScore: 7)
            
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 16) {
                GridRow { statCell(title: "7‑day avg", value: String(format: "%.1f", avg7)) ; statCell(title: "30‑day avg", value: String(format: "%.1f", avg30)) }
                GridRow { statCell(title: "Best day", value: String(format: "%.1f", best)) ; statCell(title: "Worst day", value: String(format: "%.1f", worst)) }
                GridRow { statCell(title: "Streak ≥7", value: "\(streak) day\(streak == 1 ? "" : "s")") }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
    
    private func statCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
        }
    }
    
    // MARK: - Recent entries
    private var recentList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent")
                .font(.headline)
            
            if entries.isEmpty {
                ContentUnavailableView("No entries yet", systemImage: "chart.line.uptrend.xyaxis", description: Text("Log your first confidence check above."))
            } else {
                ForEach(entries.prefix(12)) { entry in
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(entry.score)")
                            .font(.title3.bold())
                            .frame(width: 36, alignment: .leading)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.date, style: .date) + Text(" · ") + Text(entry.date, style: .time)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let note = entry.note, !note.isEmpty {
                                Text(note)
                                    .font(.callout)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
//                            if !entry.tags.isEmpty {
//                                FlowLayout(alignment: .leading, spacing: 6) {
//                                    ForEach(entry.tags, id: \.self) { tag in
//                                        Text(tag.replacingOccurrences(of: "-", with: " ").capitalized)
//                                            .font(.caption)
//                                            .padding(.horizontal, 8)
//                                            .padding(.vertical, 4)
//                                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemFill)))
//                                    }
//                                }
//                            }
                        }
                        Spacer()
                        Menu {
                            Button(role: .destructive) { delete(entry) } label: { Label("Delete", systemImage: "trash") }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    Divider()
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
    
    // MARK: - Actions
    private func saveEntry() {
        let entry = ConfidenceEntry(date: .now, score: Int(score), note: note.isEmpty ? nil : note, tags: [])
        modelContext.insert(entry)
        do {
            try modelContext.save()
            // UI feedback + reset
            note = ""
//            selectedTags.removeAll()
            withAnimation { showSavedBanner = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation { showSavedBanner = false }
            }
            haptic(.heavy)
        } catch {
            print("Save error: \(error)")
        }
        
    }
    
    private func delete(_ entry: ConfidenceEntry) {
        modelContext.delete(entry)
        do { try modelContext.save() } catch { print("Delete error: \(error)") }
    }
    
    // MARK: - Helpers
    private func roundCapsule(selected: Bool) -> some ShapeStyle {
        selected ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(Color(.tertiarySystemFill))
    }
    
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .rigid) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    
    private var addQuickButtons: some View {
        Menu {
            Button { addMockWeek() } label: { Label("Add mock week", systemImage: "calendar.badge.plus") }
            Button(role: .destructive) { deleteAll() } label: { Label("Delete all", systemImage: "trash") }
        } label: {
            Image(systemName: "gearshape")
        }
    }
    
    private func deleteAll() {
        for e in entries { modelContext.delete(e) }
        try? modelContext.save()
    }
    
    // Seed data for previews / testing
    private func addMockWeek() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        for i in 0..<7 {
            let d = cal.date(byAdding: .day, value: -i, to: today)!
            let samples = Int.random(in: 2...4)
            for _ in 0..<samples {
                let offsetHour = Int.random(in: 7...21)
                let date = cal.date(byAdding: .hour, value: offsetHour, to: d)!
                let score = Int.random(in: 4...9)
                let tags = ["after-task", "workout", "social", "focus", "rest"].shuffled().prefix(Int.random(in: 0...2))
                let entry = ConfidenceEntry(date: date, score: score, note: nil, tags: Array(tags))
                modelContext.insert(entry)
            }
        }
        try? modelContext.save()
    }
    
    // MARK: - Analytics
    private func groupDailyAverages(for entries: [ConfidenceEntry], lastDays: Int) -> [(day: Date, avg: Double)] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -lastDays+1, to: .now)!)
        let filtered = entries.filter { $0.date >= start }
        let grouped = Dictionary(grouping: filtered, by: { cal.startOfDay(for: $0.date) })
        return grouped.keys.sorted().map { day in
            let vals = grouped[day]!.map { Double($0.score) }
            let avg = vals.reduce(0, +) / Double(vals.count)
            return (day, avg)
        }
    }
    
    private func rollingAverages() -> (Double, Double) {
        func avg(_ n: Int) -> Double {
            let start = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -n+1, to: .now)!)
            let vals = entries.filter { $0.date >= start }.map { Double($0.score) }
            guard !vals.isEmpty else { return 0 }
            return vals.reduce(0, +) / Double(vals.count)
        }
        return (avg(7), avg(30))
    }
    
    private func bestWorst() -> (Double, Double) {
        let vals = entries.map { Double($0.score) }
        return (vals.max() ?? 0, vals.min() ?? 0)
    }
    
    private func currentStreak(minScore: Int) -> Int {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: entries, by: { cal.startOfDay(for: $0.date) })
        var streak = 0
        var day = cal.startOfDay(for: .now)
        while true {
            if let dayEntries = grouped[day], dayEntries.contains(where: { $0.score >= minScore }) {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
                day = prev
            } else { break }
        }
        return streak
    }
}

// MARK: - Small Components
struct SavedBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
            Text("Saved")
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .clipShape(Capsule())
        .shadow(radius: 2)
    }
}

struct TagToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack(spacing: 6) {
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                configuration.label
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 10).fill(configuration.isOn ? Color(.tertiarySystemFill) : Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
    }
}



// MARK: - Integration Example
struct RootTabWithConfidence_PreviewScaffold: View {
    var body: some View {
        NavigationStack {
            ConfidenceTrackerView()
        }
        .tabItem { Label("Confidence", systemImage: "bolt.heart") }
    }
}

// MARK: - Previews with in-memory store
struct ConfidenceTrackerView_Previews: PreviewProvider {
    static var previews: some View {
        let schema = Schema([ConfidenceEntry.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        return ConfidenceTrackerView()
            .modelContainer(container)
            .preferredColorScheme(.dark)
    }
}







@Model
final class ActivityItem {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date
    var seriesId: UUID?
    var repeatsWeekly: Bool = false
    var repeatWeeks: Int = 0        // ← persisted, simple

    var name: String
    var details: String
    var durationMinutes: Int
    var isCompleted: Bool = false

    init(
        date: Date = .now,
        name: String,
        details: String = "",
        durationMinutes: Int = 0,
        isCompleted: Bool = false,
        seriesId: UUID? = nil,
        repeatsWeekly: Bool = false,
        repeatWeeks: Int = 0
    ) {
        self.date = date
        self.seriesId = seriesId
        self.repeatsWeekly = repeatsWeekly
        self.repeatWeeks = repeatWeeks
        self.name = name
        self.details = details
        self.durationMinutes = durationMinutes
        self.isCompleted = isCompleted
    }
}

// MARK: - Daily Activities Home
struct DailyActivitiesView: View {
    @Environment(\.modelContext) private var modelContext

    // We fetch all activities for the visible month and filter in memory per selected day
    @Query(sort: \ActivityItem.date, order: .forward, animation: .snappy)
    private var allActivities: [ActivityItem]

    // Also allow writing a derived daily confidence into ConfidenceEntry (from your existing tracker)
    @Query(sort: \ConfidenceEntry.date, order: .reverse) private var confidenceEntries: [ConfidenceEntry]

    @State private var monthAnchor: Date = Calendar.current.startOfMonth(for: .now)
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)

    @State private var showingAddSheet = false
    @State private var exportURL: URL?
    @State private var showingImporter = false
    @AppStorage("reminderHour") private var reminderHour: Int = 22
    @AppStorage("reminderMinute") private var reminderMinute: Int = 0
    @State private var viewMode: ViewMode = .monthly
    enum ViewMode { case monthly, weekly }
    @State private var currentWeekStart: Date = Calendar.current.startOfWeek(for: .now)

    var body: some View {
        VStack(spacing: 8) {

            // Title always on its own line
            Text("Daily Activities")
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            // Buttons always below the title
            HStack {
                Button("Monthly") { viewMode = .monthly }
                    .buttonStyle(.borderedProminent)

                Button("Weekly") { viewMode = .weekly }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            if viewMode == .monthly {
                header

                MonthCalendarGrid(
                    month: monthAnchor,
                    selectedDate: $selectedDate,
                    scores: dailyScores(in: monthAnchor),
                    onSelect: { selectedDate = $0 }
                )
                .padding(.horizontal)
                Divider()
                dayListSection
                HStack {
                    Button("Export Activities") { exportActivities() }
                        .buttonStyle(.borderedProminent)
                    Button("Import Activities") { showingImporter = true }
                        .buttonStyle(.bordered)
                }
                .padding(.horizontal)

            } else {

                WeeklyTimelineView(weekStart: currentWeekStart, allActivities: allActivities)
            }


        }
        .onReceive(NotificationCenter.default.publisher(for: .changeWeek)) { note in
            if let newWeek = note.object as? Date {
                currentWeekStart = newWeek
            }
                }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { addButton } }
        .sheet(isPresented: $showingAddSheet) {
            AddActivitySheet(defaultDate: selectedDate) { items in
                let cal = Calendar.current
                var affected = Set<Date>()
                for item in items {
                    modelContext.insert(item)
                    affected.insert(cal.startOfDay(for: item.date))
                }
                try? modelContext.save()
                syncConfidenceForDays(affected)
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
                            importActivities(from: data)

                        } catch {
                            print("Import read error:", error)
                        }
                    }
                case .failure(let error):
                    print("Importer error:", error)
                }
            }
        .padding(.bottom, 8)
    }

    // MARK: - Header with month controls
    private var header: some View {
        HStack(spacing: 12) {
            Button { monthAnchor = Calendar.current.date(byAdding: .month, value: -1, to: monthAnchor)! } label: {
                Image(systemName: "chevron.left").font(.headline)
            }
            Spacer()
            VStack(spacing: 2) {
                Text(monthAnchor, format: .dateTime.year())
                    .font(.caption).foregroundStyle(.secondary)
                Text(monthAnchor, format: .dateTime.month(.wide))
                    .font(.title3.weight(.semibold))
            }
            Spacer()
            Button { monthAnchor = Calendar.current.date(byAdding: .month, value: 1, to: monthAnchor)! } label: {
                Image(systemName: "chevron.right").font(.headline)
            }
        }
        .padding(.horizontal)
    }

    private var addButton: some View {
        Button { showingAddSheet = true } label: {
            Label("Add", systemImage: "plus.circle.fill").font(.headline)
        }
    }

    // MARK: - List for selected day
    private var dayListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(selectedDate, format: Date.FormatStyle().weekday(.wide)) · \(selectedDate, style: .date)")
                    .font(.headline)
                Spacer()
                if let score = scoreForDay(selectedDate) {
                    Label("\(score)/10", systemImage: "bolt.heart").font(.subheadline)
                }
            }

            if dayActivities(selectedDate).isEmpty {
                ContentUnavailableView("No activities", systemImage: "list.bullet", description: Text("Add one using the + button."))
            } else {
                List {
                    ForEach(dayActivities(selectedDate)) { item in
                        ActivityRow(item: item, onToggle: { updated in
                            updated.isCompleted.toggle(); try? modelContext.save(); syncConfidenceForDay(selectedDate)
                        })
                        
                    }
                    .onDelete { indexSet in
                        let items = dayActivities(selectedDate)
                        for i in indexSet { modelContext.delete(items[i]) }
                        try? modelContext.save(); syncConfidenceForDay(selectedDate)
                    }
                }
                .listStyle(.insetGrouped)
                .frame(maxHeight: 320)
            }
            
        }
        .padding(.horizontal)
    }

    // MARK: - Helpers
    private func dayActivities(_ date: Date) -> [ActivityItem] {
        let cal = Calendar.current
        return allActivities.filter { cal.isDate($0.date, inSameDayAs: date) }
    }

    private func scoreForDay(_ date: Date) -> Int? {
        let items = dayActivities(date)
        guard !items.isEmpty else { return nil }
        let done = items.filter { $0.isCompleted }.count
        let score = Int(round((Double(done) / Double(items.count)) * 10.0))
        return score
    }

    private func dailyScores(in month: Date) -> [Date: Int] {
        let cal = Calendar.current
        let range = cal.monthDateRange(containing: month)
        let items = allActivities.filter { $0.date >= range.start && $0.date <= range.end }
        var dict: [Date: (done: Int, total: Int)] = [:]
        for item in items {
            let day = cal.startOfDay(for: item.date)
            var agg = dict[day] ?? (0, 0)
            agg.total += 1
            if item.isCompleted { agg.done += 1 }
            dict[day] = agg
        }
        var scores: [Date: Int] = [:]
        for (day, agg) in dict {
            let s = Int(round((Double(agg.done) / Double(agg.total)) * 10.0))
            scores[day] = s
        }
        return scores
    }

    // Write or update a ConfidenceEntry for the selected day
    private func syncConfidenceForDay(_ date: Date) {
        guard let score = scoreForDay(date) else { return }
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        let existing = confidenceEntries.first { cal.isDate($0.date, inSameDayAs: dayStart) }
        if let e = existing {
            e.score = score
        } else {
            let entry = ConfidenceEntry(date: dayStart, score: score, note: "Derived from activities", tags: ["activities"])
            modelContext.insert(entry)
        }
        try? modelContext.save()
    }
    
    // MARK: - Confidence sync helpers
    private func syncConfidenceForDays(_ days: Set<Date>) {
        for d in days { syncConfidenceForDay(d) }
    }
    private func exportActivities() {
        let dtos = allActivities.filter { !$0.isCompleted }.map(ActivityDTO.init)
        let package = ActivityPackage(activities: dtos)

        do {
            let data = try JSONEncoder().encode(package)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("daily_activities_export.json")
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
    private func importActivities(from data: Data) {
        do {
            let package = try JSONDecoder().decode(ActivityPackage.self, from: data)

            let existing = allActivities

            func exists(_ dto: ActivityDTO) -> Bool {
                existing.contains {
                    $0.name == dto.name &&
                    $0.date == dto.date &&
                    $0.durationMinutes == dto.durationMinutes
                }
            }

            for dto in package.activities where !exists(dto) {
                let item = ActivityItem(
                    date: dto.date,
                    name: dto.name,
                    details: dto.details,
                    durationMinutes: dto.durationMinutes,
                    isCompleted: dto.isCompleted,
                    seriesId: dto.seriesId,
                    repeatsWeekly: dto.repeatsWeekly,
                    repeatWeeks: dto.repeatWeeks
                )
                modelContext.insert(item)
            }

            try? modelContext.save()
        } catch {
            print("Import decode error:", error)
        }
    }
    // MARK: - Daily Reminder Scheduler
    private func scheduleDailyActivityReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["activityReminder"])

        let content = UNMutableNotificationContent()
        content.title = "Daily Activity Reminder"
        content.body = buildIncompleteActivitiesMessage()
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: reminderHour, minute: reminderMinute),
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "activityReminder",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }
    
    private func buildIncompleteActivitiesMessage() -> String {
        let today = Calendar.current.startOfDay(for: Date())
        let incomplete = allActivities.filter {
            !$0.isCompleted && Calendar.current.isDate($0.date, inSameDayAs: today)
        }

        if incomplete.isEmpty {
            return "All activities completed today. Great job!"
        }

        let bullets = incomplete.map { "• \($0.name)" }.joined(separator: "\n")
        return "You still have activities to complete:\n\(bullets)"
    }
    private func overlaps(_ newItem: ActivityItem) -> Bool {
        let cal = Calendar.current

        for item in allActivities {
            if cal.isDate(item.date, inSameDayAs: newItem.date) {
                let startA = item.date
                let endA = item.date.addingTimeInterval(TimeInterval(item.durationMinutes * 60))

                let startB = newItem.date
                let endB = newItem.date.addingTimeInterval(TimeInterval(newItem.durationMinutes * 60))

                if startA < endB && startB < endA {
                    return true
                }
            }
        }
        return false
    }

}

extension Notification.Name {
    static let changeWeek = Notification.Name("changeWeek")
}


// MARK: - Row
struct ActivityRow: View {
    @Bindable var item: ActivityItem
    var onToggle: (ActivityItem) -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Button(action: { onToggle(item) }) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                HStack{
                    Text(timeFormatter.string(from: item.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(item.name)
                        .font(.body.weight(.medium))
                    if !item.details.isEmpty { Text(item.details).font(.caption).foregroundStyle(.secondary) }
                }
            }
            Spacer()
            if item.durationMinutes > 0 {
                Text("\(item.durationMinutes)m").font(.callout).foregroundStyle(.secondary)
            }
        }
    }
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
}

// MARK: - Add Sheet
struct AddActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var details: String = ""
    @State private var duration: Double = 60
    @State private var date: Date
    @State private var repeatWeekly: Bool = false
    @State private var repeatDailyWholeWeek: Bool = true
    @State private var repeatWeeksCount: Int = 4   // 1…52
    @State private var showingOverlapAlert = false
    @State private var pendingItem: ActivityItem?

    var onSave: ([ActivityItem]) -> Void

    init(defaultDate: Date, onSave: @escaping ([ActivityItem]) -> Void) {
        // Set default time to 10:00 ONLY when creating a new activity
            let cal = Calendar.current
            let tenAM = cal.date(
                bySettingHour: 10,
                minute: 0,
                second: 0,
                of: defaultDate
            ) ?? defaultDate
        self._date = State(initialValue: tenAM)
        self.onSave = onSave
        }

    private func overlaps(_ newItem: ActivityItem, in existing: [ActivityItem]) -> Bool {
        let cal = Calendar.current

        for item in existing {
            if cal.isDate(item.date, inSameDayAs: newItem.date) {
                let startA = item.date
                let endA = item.date.addingTimeInterval(TimeInterval(item.durationMinutes * 60))

                let startB = newItem.date
                let endB = newItem.date.addingTimeInterval(TimeInterval(newItem.durationMinutes * 60))

                if startA < endB && startB < endA {
                    return true
                }
            }
        }
        return false
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    Toggle("Repeat weekly (same weekday)", isOn: $repeatWeekly)
                    if repeatWeekly {
                        Stepper(value: $repeatWeeksCount, in: 1...52) {
                            Text("For \(repeatWeeksCount) week\(repeatWeeksCount == 1 ? "" : "s")")
                        }
                    }
                }
                Section("Activity") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $details, axis: .vertical).lineLimit(1...3)
                    HStack {
                        Text("Duration")
                        Spacer()
                        Stepper(value: $duration, in: 0...480, step: 5) { Text("\(Int(duration)) min") }
                    }
                }
            }
            .navigationTitle("New Activity")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }

                        var newItems: [ActivityItem] = []

                        if repeatWeekly {
                            let sid = UUID()
                            for w in 0..<repeatWeeksCount {
                                let next = Calendar.current.date(byAdding: .weekOfYear, value: w, to: date)!
                                let item = ActivityItem(
                                    date: next,
                                    name: trimmed,
                                    details: details,
                                    durationMinutes: Int(duration)
                                )
                                item.seriesId = sid

                                // ⭐ OVERLAP CHECK
                                if overlaps(item, in: (try? modelContext.fetch(FetchDescriptor<ActivityItem>())) ?? []) {
                                    pendingItem = item
                                    showingOverlapAlert = true
                                    break
                                }


                                newItems.append(item)
                            }
                        } else {
                            let item = ActivityItem(
                                date: date,
                                name: trimmed,
                                details: details,
                                durationMinutes: Int(duration)
                            )

                            // ⭐ OVERLAP CHECK
                            if overlaps(item, in: (try? modelContext.fetch(FetchDescriptor<ActivityItem>())) ?? []) {
                                pendingItem = item
                                showingOverlapAlert = true
                            } else {
                                newItems.append(item)
                            }

                        }

                        // ⭐ Only save if no overlap alert is shown
                        if !showingOverlapAlert {
                            onSave(newItems)
                            dismiss()
                        }
                    }
            
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .alert("Activity Overlaps", isPresented: $showingOverlapAlert) {
                        Button("Create Anyway") {
                            if let item = pendingItem {
                                onSave([item])
                                dismiss()
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This activity overlaps an existing one.")
                    }
                }
                
            }
        }
    }

}

// MARK: - Month Calendar Grid
struct MonthCalendarGrid: View {
    var month: Date
    @Binding var selectedDate: Date
    var scores: [Date: Int]        // day -> 0...10
    var onSelect: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(minimum: 24), spacing: 6), count: 7)

    var body: some View {
        let cal = Calendar.current
        let days = cal.daysForMonthGrid(containing: month)

        VStack(spacing: 4) {
            // Weekday headers
            HStack {
                ForEach(cal.veryShortWeekdaySymbolsIndexed(), id: \.0) { (_, sym) in
                    Text(sym.uppercased()).font(.caption2).frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(days, id: \.self) { day in
                    let cal = Calendar.current
                    let isCurrentMonth = cal.isDate(day, equalTo: month, toGranularity: .month)
                    let dayStart = cal.startOfDay(for: day)
                    let score = scores[dayStart]

                    let isToday = cal.isDateInToday(day)
                    let isSelected = dayStart == selectedDate

                    // Tints
                    let todayTint = Color.blue                // keep your blue today ring
                    let todayFill = todayTint.opacity(0.18)   // blue-ish background for today
                    let selectedFill = Color(uiColor: .systemGray4)   // ⚫️ stronger gray for selection
                    let selectedStroke = Color(uiColor: .systemGray)

                    Button {
                        selectedDate = dayStart
                        onSelect(dayStart)
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Text("\(cal.component(.day, from: day))")
                                .font(.callout.weight((isSelected || isToday) ? .semibold : .regular))
                                .frame(maxWidth: .infinity, minHeight: 6)
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(
                                            isSelected
                                            ? selectedFill                             // ← more gray when selected
                                            : (isToday ? todayFill
                                                       : Color(.secondarySystemBackground))
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            isToday ? todayTint                         // blue ring for today
                                                    : (isSelected ? selectedStroke      // gray ring for selected
                                                                  : .clear),
                                            lineWidth: isToday ? 2 : (isSelected ? 1.5 : 0)
                                        )
                                )
                                .foregroundStyle(
                                    isCurrentMonth ? .primary : .secondary
                                )

                            if let s = score {
                                Text("\(s)")
                                    .font(.caption2.weight(.semibold))
                                    .padding(4)
                                    .background(Capsule().fill(Color(.tertiarySystemFill)))
                                    .padding(4)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .animation(.snappy, value: selectedDate)   // smoother tap feedback
                }

            }
        }
    }
}

// MARK: - Calendar helpers
extension Calendar {
    func monthDateRange(containing anchor: Date) -> (start: Date, end: Date) {
            let start = startOfMonth(for: anchor)
            let startOfNextMonth = self.date(byAdding: .month, value: 1, to: start)!   // <- self.
            let end = self.date(byAdding: .second, value: -1, to: startOfNextMonth)!   // last second of month
            return (start, end)
        }

        func startOfMonth(for anchor: Date) -> Date {
            let comps = dateComponents([.year, .month], from: anchor)
            return self.date(from: comps)!
        }
    func daysForMonthGrid(containing date: Date) -> [Date] {
        // Build a 6-row grid (42 cells), including leading/trailing days
        var days: [Date] = []
        let start = startOfMonth(for: date)
        let weekday = component(.weekday, from: start) // 1..7
        let firstGridDay = self.date(byAdding: .day, value: -(weekday - firstWeekday), to: start) ?? start
        for i in 0..<42 { days.append(self.date(byAdding: .day, value: i, to: firstGridDay)!) }
        return days
    }
    func veryShortWeekdaySymbolsIndexed() -> [(Int, String)] {
        let syms = veryShortStandaloneWeekdaySymbols // locale-aware
        // rotate so that it starts at firstWeekday
        let start = firstWeekday - 1
        return (0..<7).map { i in ((i + start) % 7, syms[(i + start) % 7]) }
    }
    func startOfWeek(for date: Date) -> Date {
            let comps = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return self.date(from: comps)!
        }
}

// MARK: - Integration examples
struct DailyActivitiesEntryPoint_Previews: PreviewProvider {
    static var previews: some View {
        let schema = Schema([ActivityItem.self, ConfidenceEntry.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)

        return NavigationStack {
            DailyActivitiesView()
        }
        .modelContainer(container)
        .preferredColorScheme(.light)
    }
}

// Example: Add a button on your main/root page
struct RootWithDailyActivitiesButton: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    ConfidenceTrackerView()
                } label: { Label("Confidence level", systemImage: "bolt.heart.fill") }

                NavigationLink {
                    DailyActivitiesView()
                } label: { Label("Daily Activities", systemImage: "calendar") }
            }
            .navigationTitle("LifeOrdering")
        }
    }
}


struct CompactTagToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            configuration.label
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)   // squeeze text if needed
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, minHeight: 8) // equal width per column
                .background(
                    Capsule()
                        .fill(configuration.isOn ? Color(.tertiarySystemFill)
                                                  :Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(.plain)
    }
}



struct WeeklyTimelineView: View {
    @State private var selectedItem: ActivityItem?
    @State private var showDetails = false
    
    let weekStart: Date
    let allActivities: [ActivityItem]

    private let hours = Array(0..<24)

    var body: some View {
        VStack(spacing: 12) {

            // WEEK NAVIGATION
            HStack {
                Button {
                    let cal = Calendar.current
                    let prev = cal.date(byAdding: .weekOfYear, value: -1, to: weekStart)!
                    NotificationCenter.default.post(name: .changeWeek, object: prev)
                } label: {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                Text(weekStart, format: .dateTime.year().month().day())
                    .font(.headline)

                Spacer()

                Button {
                    let cal = Calendar.current
                    let next = cal.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
                    NotificationCenter.default.post(name: .changeWeek, object: next)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal) {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        HStack(alignment: .top, spacing: 4) {

                            // HOURS COLUMN
                            VStack(alignment: .trailing, spacing: 20) {
                                ForEach(hours, id: \.self) { hour in
                                    Text(String(format: "%02d:00", hour))
                                        .id(hour)   // ⭐ important
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .frame(height: 40, alignment: .top)
                                }
                            }
                            .padding(.leading, 4)

                            // 7 DAY COLUMNS
                            ForEach(0..<7) { offset in
                                let day = Calendar.current.date(byAdding: .day, value: offset, to: weekStart)!
                                let dayItems = activitiesForDay(day)
                                dayColumn(day: day, items: dayItems)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .onAppear {
                        proxy.scrollTo(7, anchor: .top)   // ⭐ jump to 07:00
                    }
                }

            }
            .sheet(isPresented: $showDetails) {
                if let item = selectedItem {
                    VStack(spacing: 20) {
                        Text(item.name)
                            .font(.title2)
                            .bold()

                        Text("Starts at: \(item.date.formatted(date: .omitted, time: .shortened))")
                        Text("Duration: \(item.durationMinutes) minutes")

                        Spacer()
                    }
                    .padding()
                }
            }

        }
    }

    // MARK: - Helpers
    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                Rectangle()
                    .fill(hour >= 7 && hour < 18
                          ? Color.gray.opacity(0.15)
                          : Color.white)

                // Thin line across the entire hour
                        Rectangle()
                            .fill(Color.black.opacity(0.25))
                            .frame(height: 1)
                            .offset(y: 0)
            }
        }
    }


    private func activitiesForDay(_ day: Date) -> [ActivityItem] {
        let cal = Calendar.current
        return allActivities.filter { cal.isDate($0.date, inSameDayAs: day) }
    }

    private func offsetFor(_ item: ActivityItem) -> CGFloat {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: item.date)
        let minute = cal.component(.minute, from: item.date)
        let totalMinutes = hour * 60 + minute

        return CGFloat(totalMinutes) //* (40.0 / 60.0)  // 40px per hour
    }

    private func heightFor(_ item: ActivityItem) -> CGFloat {
        CGFloat(item.durationMinutes) * (45.0 / 60.0)
    }

    private func colorFor(_ item: ActivityItem) -> Color {
        if item.isCompleted { return .green.opacity(0.3) }
        if item.durationMinutes > 60 { return .red.opacity(0.3) }
        return .gray.opacity(0.2)
    }
    private func columnOffset(for item: ActivityItem, in dayItems: [ActivityItem]) -> CGFloat {
        var index = 0

        for other in dayItems {
            if other.id == item.id { break }

            let startA = other.date
            let endA = other.date.addingTimeInterval(TimeInterval(other.durationMinutes * 60))

            let startB = item.date
            let endB = item.date.addingTimeInterval(TimeInterval(item.durationMinutes * 60))

            if startA < endB && startB < endA {
                index += 1
            }
        }

        return CGFloat(index) * 10
    }
    
    private func activityBox(item: ActivityItem, items: [ActivityItem]) -> some View {
        let offsetY = offsetFor(item)
        let height = heightFor(item)
        let offsetX = columnOffset(for: item, in: items)

        return Text(item.name)
            .font(.caption)
            .padding(4)
            .frame(maxWidth: .infinity)
            .background(Color.green.opacity(0.25))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.purple, lineWidth: 1)
            )
            .cornerRadius(6)
            .offset(x: offsetX, y: offsetY)
            .frame(height: height, alignment: .top)
    }



    private func dayColumn(day: Date, items: [ActivityItem]) -> some View {
        VStack(spacing: 0) {
            Text(day, format: .dateTime.weekday(.abbreviated))
                .font(.caption)
                .padding(.bottom, 4)

            ZStack(alignment: .top) {
                hourGrid
                renderOverlapping(items)
            }
        }
        .frame(width: 120)
    }

    private func overlappingGroups(for items: [ActivityItem]) -> [[ActivityItem]] {
        var groups: [[ActivityItem]] = []
        let sorted = items.sorted { $0.date < $1.date }

        for item in sorted {
            var placed = false
            for i in groups.indices {
                if groups[i].contains(where: { overlap($0, item) }) {
                    groups[i].append(item)
                    placed = true
                    break
                }
            }
            if !placed {
                groups.append([item])
            }
        }
        return groups
    }

    private func overlap(_ a: ActivityItem, _ b: ActivityItem) -> Bool {
        let startA = a.date
        let endA = a.date.addingTimeInterval(TimeInterval(a.durationMinutes * 60))
        let startB = b.date
        let endB = b.date.addingTimeInterval(TimeInterval(b.durationMinutes * 60))
        return startA < endB && startB < endA
    }
    private func renderOverlapping(_ items: [ActivityItem]) -> some View {
        let groups = overlappingGroups(for: items)

        return ForEach(groups.indices, id: \.self) { gIndex in
            let group = groups[gIndex]
            let count = group.count
            let widthFraction = 1.0 / CGFloat(count)
            let columnWidth: CGFloat = 120 * widthFraction

            ForEach(group.indices, id: \.self) { i in
                let item = group[i]
                let offsetY = offsetFor(item)
                let height = heightFor(item)

                Text(item.name)
                    .font(.caption)
                    .padding(4)
                    .frame(width: columnWidth - 4)
                    .background(Color.green.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.purple, lineWidth: 1)
                    )
                    .cornerRadius(6)
                    .offset(
                        x: (CGFloat(i) - CGFloat(count - 1) / 2) * columnWidth,
                        y: offsetY
                    )
                    .frame(height: height, alignment: .top)
            }
        }
    }

}

//Add export/import button


struct TaskDTO: Codable, Identifiable {
    var id: UUID
    var title: String
    var dueDate: Date
    var priority: String
    var isCompleted: Bool
}

struct ShoppingItemDTO: Codable, Identifiable {
    var id: UUID
    var name: String
    var price: Double
    var currency: String
    var priority: String
    var isCompleted: Bool
}

struct MonthlyTaskDTO: Codable, Identifiable {
    var id: UUID
    var title: String
    var price: Double
}

struct SubtaskDTO: Codable, Identifiable {
    var id: UUID
    var title: String
    var isCompleted: Bool
}

struct OtherTaskDTO: Codable, Identifiable {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var subtasks: [SubtaskDTO]
}

struct ActivityDTO: Codable, Identifiable {
    var id: UUID
    var date: Date
    var name: String
    var details: String
    var durationMinutes: Int
    var isCompleted: Bool
    var seriesId: UUID?
    var repeatsWeekly: Bool
    var repeatWeeks: Int
}

struct ExportPackage: Codable {
    var tasks: [TaskDTO]
    var shoppingItems: [ShoppingItemDTO]
    var monthlyTasks: [MonthlyTaskDTO]
    var tasksWithSubtasks: [OtherTaskDTO]
    var activityTasks: [ActivityDTO]
}



// Add helpers in app A

extension TaskDTO {
    init(from model: TaskModel) {
        self.id = model.id
        self.title = model.title
        self.dueDate = model.dueDate
        self.priority = model.priority.rawValue
        self.isCompleted = model.isCompleted
    }
}

extension ShoppingItemDTO {
    init(from model: ShoppingItemModel) {
        self.id = model.id
        self.name = model.name
        self.price = model.price
        self.currency = model.currency
        self.priority = model.priority.rawValue
        self.isCompleted = model.isCompleted
    }
}

extension MonthlyTaskDTO {
    init(from model: MonthlyTaskModel) {
        self.id = model.id
        self.title = model.title
        self.price = model.price
    }
}

extension OtherTaskDTO {
    init(from model: OtherTaskModel) {
        self.id = model.id
        self.title = model.title
        self.isCompleted = model.isCompleted
        self.subtasks = model.subtasks.map {
            SubtaskDTO(id: $0.id, title: $0.title, isCompleted: $0.isCompleted)
        }
    }
}

extension ActivityDTO {
    init(from model: ActivityItem) {
        self.id = model.id
        self.date = model.date
        self.name = model.name
        self.details = model.details
        self.durationMinutes = model.durationMinutes
        self.isCompleted = model.isCompleted
        self.seriesId = model.seriesId
        self.repeatsWeekly = model.repeatsWeekly
        self.repeatWeeks = model.repeatWeeks
    }
}

struct TaskPackage: Codable {
    var tasks: [TaskDTO]
}

struct ShoppingTaskPackage: Codable {
    var shoppingtasks: [ShoppingItemDTO]
}

struct MonthlyTaskPackage: Codable {
    var monthlyTasks: [MonthlyTaskDTO]
}

struct OtherTaskPackage: Codable {
    var othertasks: [OtherTaskDTO]
}

struct ActivityPackage: Codable {
    var activities: [ActivityDTO]
}

//Import logic in App B

extension TaskModel {
    static func fromDTO(_ dto: TaskDTO) -> TaskModel {
        TaskModel(
            title: dto.title,
            dueDate: dto.dueDate,
            priority: TaskPriority(rawValue: dto.priority) ?? .medium
        )
    }
}

extension ShoppingItemModel {
    static func fromDTO(_ dto: ShoppingItemDTO) -> ShoppingItemModel {
        let item = ShoppingItemModel(
            name: dto.name,
            price: dto.price,
            currency: dto.currency,
            priority: TaskPriority(rawValue: dto.priority) ?? .medium
        )
        item.isCompleted = dto.isCompleted
        return item
    }
}

extension MonthlyTaskModel {
    static func fromDTO(_ dto: MonthlyTaskDTO) -> MonthlyTaskModel {
        MonthlyTaskModel(title: dto.title, price: dto.price)
    }
}



//Iport function with merge not overwrite

//import SwiftData

func importFromJSON(data: Data, modelContext: ModelContext) {
    do {
        let package = try JSONDecoder().decode(ExportPackage.self, from: data)

        // Existing tasks for simple duplicate check (by title + date)
        let existingTasks = try modelContext.fetch(FetchDescriptor<TaskModel>())
        let existingShopping = try modelContext.fetch(FetchDescriptor<ShoppingItemModel>())
        let existingMonthly = try modelContext.fetch(FetchDescriptor<MonthlyTaskModel>())

        // Helper to avoid duplicates
        func taskExists(_ dto: TaskDTO) -> Bool {
            existingTasks.contains {
                $0.title == dto.title && $0.dueDate == dto.dueDate
            }
        }

        func shoppingExists(_ dto: ShoppingItemDTO) -> Bool {
            existingShopping.contains {
                $0.name == dto.name && $0.price == dto.price
            }
        }

        func monthlyExists(_ dto: MonthlyTaskDTO) -> Bool {
            existingMonthly.contains {
                $0.title == dto.title && $0.price == dto.price
            }
        }

        // Import tasks
        for dto in package.tasks where !taskExists(dto) {
            let newTask = TaskModel.fromDTO(dto)
            modelContext.insert(newTask)
        }

        // Import shopping items
        for dto in package.shoppingItems where !shoppingExists(dto) {
            let newItem = ShoppingItemModel.fromDTO(dto)
            modelContext.insert(newItem)
        }

        // Import monthly tasks
        for dto in package.monthlyTasks where !monthlyExists(dto) {
            let newMonthly = MonthlyTaskModel.fromDTO(dto)
            modelContext.insert(newMonthly)
        }

        try modelContext.save()
        print("Import completed successfully.")
    } catch {
        print("Import error:", error)
    }
}


@Model
class FocusResult {
    var date: Date
    var duration: Double

    init(date: Date, duration: Double) {
        self.date = date
        self.duration = duration
    }
}


struct FocusTestStartView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var startTest = false
    @State private var showResults = false
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Focus Test")
                .font(.largeTitle.bold())
            .pickerStyle(.segmented)

            Button("Start Test") {
                startTest = true
            }
            .buttonStyle(.borderedProminent)

        }
        .padding()
        .fullScreenCover(isPresented: $startTest) {
            RedDotFocusTestView(shouldReturnToHome: false, onFinish: { showResults = true }  )
        }
        .fullScreenCover(isPresented: $showResults) {
                    ResultsListView()
                }
    }
}


import Charts

struct FocusPerformanceGraphView: View {
    @Query(sort: \FocusResult.date)
    private var results: [FocusResult]

    var body: some View {
        VStack {
            Text("Focus Performance")
                .font(.title.bold())

            Chart(results) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Duration", item.duration)
                )
                .foregroundStyle(.blue)
            }
            .frame(height: 300)

            Spacer()
        }
        .padding()
    }
}


struct FocusTestExplanationView: View {
    @State private var startTest = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Focus Test Instructions")
                .font(.largeTitle.bold())
                .padding(.top)

            Text("""
Look at the red dot without blinking and without moving your eyes as much as you can.

When you blink, tap the screen. The time will be recorded and you can compare it with your future tests.

Come again in a week and retest your attention span. After 1 week of using this app, you will see improvements in your focus.

Maintaining gaze on a fixed point improves:
• continuous micro‑attention (microsaccades)
• suppression of reflexive eye movements
• resistance to boredom
• mental stability

When your mind wanders, your eyes drift.
When you’re tired, your microsaccades increase.
When you’re stressed, fixation becomes unstable.
""")
            .font(.body)
            .multilineTextAlignment(.leading)
            .padding(.horizontal)

            Button("Start Test") {
                startTest = true
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .fullScreenCover(isPresented: $startTest) {
            RedDotFocusTestView(shouldReturnToHome: true, onFinish: nil  )
        }
    }
}

struct RedDotFocusTestView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss


    @State private var timerValue: Double = 0
    @State private var timer: Timer?
    
    let shouldReturnToHome: Bool
    let onFinish: (() -> Void)?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Circle()
                .fill(.red)
                .frame(width: 150, height: 150)
                .position(
                    x: UIScreen.main.bounds.width / 2,
                    y: UIScreen.main.bounds.height / 2
                )

            VStack {
                Text(String(format: "%.2f s", timerValue))
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding()
                Spacer()
            }
        }
        .onAppear { startTimer() }
        .onTapGesture { finishTest() }
    }

    private func startTimer() {
        timerValue = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            timerValue += 0.01
        }
    }
    @AppStorage("hasSeenIntroPage") private var hasSeenIntroPage: Bool = false

    private func finishTest() {
        timer?.invalidate()
        timer = nil

        let result = FocusResult(date: Date(), duration: timerValue)
        modelContext.insert(result)
        try? modelContext.save()
        
        hasSeenIntroPage = true
        
        if shouldReturnToHome {
            dismiss()   // return to HomeView
        } else {
            dismiss()               // Home → Test → Home
            onFinish?()
        }
    }
}

struct ResultsListView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FocusResult.date) private var results: [FocusResult]

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(results.enumerated()), id: \.offset) { index, item in
                    VStack(alignment: .leading) {
                        Text("Test #\(index + 1)")
                            .font(.headline)

                        Text("Date: \(item.date.formatted(date: .numeric, time: .shortened))")
                        Text("Duration: \(String(format: "%.2f s", item.duration))")
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Past Results")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Go Back") { dismiss() }
                }
            }
        }
    }
}



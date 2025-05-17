import SwiftUI
import SwiftUI
import SwiftData
import UserNotifications
 
@main
struct LifeOrderingApp: App {
        @AppStorage("selectedTheme") private var selectedTheme: String = "Default"
 
    init() {
        NotificationManager.shared.requestPermission()
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(selectedTheme == "Dark" ? .dark : .light)
                .modelContainer(for: [
                                      TaskModel.self,
                                      ShoppingItemModel.self,
                                      MonthlyTaskModel.self,  // ← must be included
                                      OtherTaskModel.self,     // ← must be included
                                      GroceryItemModel.self
                                     ])

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
    
    init(name: String, price: Double, currency: String, priority: TaskPriority) {
        self.name = name
        self.price = price
        self.currency = currency
        self.priority = priority
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

//@Model
//class OtherTaskModel: Identifiable {
//    var id: UUID = UUID()
//    var title: String
//    var subtasks: [String]  // Or model it with a separate SubtaskModel
//
//    init(title: String, subtasks: [String] = []) {
//        self.title = title
//        self.subtasks = subtasks
//    }
//}

//@Model
//class SubtaskModel: Identifiable {
//    var id: UUID = UUID()
//    var title: String
//    var isDone: Bool = false
//
//    init(title: String) {
//        self.title = title
//    }
//}
//
//
//@Model
//class OtherTaskModel {
//    var id: UUID = UUID()
//    var title: String
//    var subtasks: [SubtaskModel] = []
//
//    init(title: String, subtasks: [SubtaskModel] = []) {
//        self.title = title
//        self.subtasks = subtasks
//    }
//}

@Model
class SubtaskModel: Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String

    init(title: String) {
        self.title = title
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
    
    init(title: String) {
        self.title = title
    }
}


enum TaskPriority: String, CaseIterable, Identifiable, Codable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    
    var id: String { self.rawValue }
}
 
 
 
// MARK: - Main View
struct MainView: View {
    var body: some View {
        TabView {
            DueTasksView()
                .tabItem {
                    Image(systemName: "list.bullet.circle")
                    Text("Due Tasks")
                }
            
            ShoppingTasksView()
                .tabItem {
                    Image(systemName: "cart.fill")
                    Text("Shopping Tasks")
                }
            
            MonthlyTasksView()
                .tabItem {
                    Label("Monthly Tasks", systemImage: "calendar")
                }
            
            GroceryTasksView()
                .tabItem {
                    Image(systemName: "bag.fill")
                    Text("Grocery Tasks")
                }
 
            OtherTasksView()
                .tabItem {
                    Label("Other Tasks", systemImage: "list.bullet")
                }

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
 
        }
    }
}
 
// MARK: - Settings View
struct SettingsView: View {
    @AppStorage("selectedTheme") private var selectedTheme: String = "Default"
    
    var body: some View {
        Form {
            Section(header: Text("Appearance")) {
                Picker("Theme", selection: $selectedTheme) {
                    Text("Default").tag("Default")
                    Text("Light").tag("Light")
                    Text("Dark").tag("Dark")
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
        .navigationTitle("Settings")
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
    
    init(title: String, dueDate: Date, priority: TaskPriority) {
        self.title = title
        self.dueDate = dueDate
        self.priority = priority
        NotificationManager.shared.scheduleNotification(for: self)
    }
}
 
 
// MARK: - Due Tasks View
//struct DueTasksView: View {
//    @Environment(\.modelContext) private var modelContext
//    @Query private var tasks: [TaskModel]
//
//    @State private var newTaskTitle: String = ""
//    @State private var selectedPriority: TaskPriority = .medium
//    @State private var dueDate = Date()
//
////    var body: some View {
////        NavigationStack {
////            Form {
////                Section(header: Text("Add New Task")) {
////                    TextField("Task Title", text: $newTaskTitle)
////                    Picker("Priority", selection: $selectedPriority) {
////                        ForEach(TaskPriority.allCases) { priority in
////                            Text(priority.rawValue).tag(priority)
////                        }
////                    }
////                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
////                    Button("Add Task") {
////                        let newTask = TaskModel(title: newTaskTitle, dueDate: dueDate, priority: selectedPriority)
////                        modelContext.insert(newTask)
////                        newTaskTitle = ""
////                    }
////                }
////
////                Section(header: Text("Active Tasks")) {
////                    List {
////                        ForEach(tasks.filter { !$0.isCompleted }) { task in
////                            HStack {
////                                VStack(alignment: .leading) {
////                                    Text(task.title).bold()
////                                    Text("Due: \(task.dueDate, formatter: DateFormatter.shortDateFormatter)")
////                                        .font(.subheadline)
////                                        .foregroundColor(.gray)
////                                }
////                                Spacer()
////                                Button(action: { completeTask(task) }) {
////                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
////                                }
////                            }
////                        }
////                    }
////                }
////            }
////            .navigationTitle("Due Tasks")
////        }
////    }
////
////    private func completeTask(_ task: TaskModel) {
////        task.isCompleted = true
////    }
////}
////
//    var body: some View {
//        NavigationStack {
//            List {
//                ForEach(sortedTasks(), id: \.id) { task in
//                    HStack {
//                        Text(task.title)
//                            .strikethrough(task.isCompleted)
//                            .foregroundColor(task.isCompleted ? .gray : .primary)
//                        Spacer()
//                        Text(task.priority.rawValue)
//                            .font(.caption)
//                            .foregroundColor(.blue)
//                    }
//                    .contentShape(Rectangle()) // Make the full row tappable
//                    .onTapGesture {
//                        toggleCompletion(task)
//                    }
//                }
//            }
//            .navigationTitle("Due Tasks")
//        }
//    }
//
//    private func toggleCompletion(_ task: TaskModel) {
//        task.isCompleted.toggle()
//        try? modelContext.save()
//    }
//
//    private func sortedTasks() -> [TaskModel] {
//        dueTasks.sorted {
//            if $0.isCompleted == $1.isCompleted {
//                return $0.dueDate < $1.dueDate
//            }
//            return !$0.isCompleted && $1.isCompleted // Incomplete on top
//        }
//    }
//}
//

struct DueTasksView: View {
    @Query private var dueTasks: [TaskModel]
    @Environment(\.modelContext) private var modelContext

    @State private var newTaskTitle: String = ""
    @State private var newDueDate: Date = Date()
    @State private var selectedPriority: TaskPriority = .medium

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Add New Task")) {
                    TextField("Task Title", text: $newTaskTitle)
                    DatePicker("Due Date", selection: $newDueDate, displayedComponents: .date)
                    Picker("Priority", selection: $selectedPriority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Text(priority.rawValue.capitalized)
                        }
                    }
                    Button("Add Task") {
                        addTask()
                    }
                }

                Section(header: Text("Due Tasks")) {
                    List {
                        ForEach(sortedTasks(), id: \.id) { task in
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
                            .onTapGesture {
                                toggleCompletion(task)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Due Tasks")
        }
    }

    private func addTask() {
        guard !newTaskTitle.isEmpty else { return }

        let newTask = TaskModel(title: newTaskTitle, dueDate: newDueDate, priority: selectedPriority)
        modelContext.insert(newTask)
        print("✅ Added new task: \(newTask.title)")

        newTaskTitle = ""
        newDueDate = Date()
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
        return formatter.string(from: date)
    }
}



// MARK: - Shopping Tasks View
struct ShoppingTasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var shoppingItems: [ShoppingItemModel]
    
    @State private var newItemName: String = ""
    @State private var newItemPrice: String = ""
    @State private var selectedPriority: TaskPriority = .medium
    @State private var selectedCurrency = "RON"
    
    var totalCost: Double {
        shoppingItems.filter { !$0.isCompleted }.reduce(0) { $0 + $1.price }
    }
    
    var body: some View {
        NavigationStack {
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
                    List {
                        ForEach(shoppingItems.filter { !$0.isCompleted }) { item in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.name).bold()
                                    Text("\(item.price, specifier: "%.2f") \(item.currency)")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Button(action: { completeItem(item) }) {
                                    Image(systemName: "cart.badge.plus").foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Total Cost")) {
                    Text("\(totalCost, specifier: "%.2f") \(selectedCurrency)")
                        .font(.title2).bold().foregroundColor(.blue)
                }
                Section(header: Text("Completed Purchases")) {
                    List {
                        ForEach(shoppingItems.filter { $0.isCompleted }) { item in
                            HStack {
                                Text(item.name).strikethrough()
                                Spacer()
                                Text("✔️").foregroundColor(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Shopping Tasks")
        }
    }
    
    private func completeItem(_ item: ShoppingItemModel) {
        item.isCompleted = true
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
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
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
}
 
 
//struct MonthlyTasksView: View {
//    @Query private var monthlyTasks: [MonthlyTaskModel]
//    @Environment(\.modelContext) private var modelContext
//    @State private var newTask: String = ""
//
//    var body: some View {
//        NavigationStack {
//            VStack {
//                Form {
//                    Section(header: Text("Add Monthly Task")) {
//                        TextField("Task Description", text: $newTask)
//                        Button("Add Task") {
//                            if !newTask.isEmpty {
//                                let task = MonthlyTaskModel(title: newTask)
//                                modelContext.insert(task)
//                                newTask = ""
//                            }
//                        }
//                    }
//
//                    Section(header: Text("Tasks")) {
//                        List {
//                            ForEach(monthlyTasks) { task in
//                                HStack {
//                                    Text(task.title)
//                                    Spacer()
//                                    Button(action: {
//                                        removeTask(task)
//                                    }) {
//                                        Image(systemName: "trash")
//                                            .foregroundColor(.red)
//                                    }
//                                }
//                            }
//                        }
//                    }
//                }
//            }
//            .navigationTitle("Monthly Tasks")
//        }
//    }
//
//    private func removeTask(_ task: MonthlyTaskModel) {
//        modelContext.delete(task)
//    }
//}
 
 
struct TaskWithSubtasks: Identifiable {
    var id = UUID()
    var title: String
    var subtasks: [String]
}
 

struct MonthlyTasksView: View {
    @Query private var monthlyTasks: [MonthlyTaskModel]
    @Environment(\.modelContext) private var modelContext

    @State private var newTaskTitle: String = ""
    @State private var newTaskPrice: String = ""

    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    Section(header: Text("Add Monthly Task")) {
                        TextField("Task Title", text: $newTaskTitle)
                        TextField("Price", text: $newTaskPrice)
                            .keyboardType(.decimalPad)

                        Button("Add Task") {
                            addTask()
                        }
                    }

                    Section(header: Text("Monthly Tasks")) {
                        List {
                            ForEach(monthlyTasks, id: \.id) { task in
                                HStack {
                                    Text(task.title)
                                    Spacer()
                                    Text("\(task.price, specifier: "%.2f")")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .onDelete(perform: deleteTask)
                        }
                    }

                    Section {
                        HStack {
                            Text("Total:")
                                .fontWeight(.bold)
                            Spacer()
                            Text("\(totalPrice(), specifier: "%.2f")")
                                .fontWeight(.bold)
                        }
                    }
                }
            }
            .navigationTitle("Monthly Tasks")
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
    }

    private func totalPrice() -> Double {
        monthlyTasks.reduce(0) { $0 + $1.price }
    }
}
 
//struct SubtaskSectionView: View {
//    let task: OtherTaskModel
//    @Binding var newSubtask: String
//    var onAdd: () -> Void
//
//    var body: some View {
//        DisclosureGroup(task.title) {
//            ForEach(task.subtasks, id: \.self) { subtask in
//                Text("- \(subtask.title)")
//            }
//            HStack {
//                TextField("New Subtask", text: $newSubtask)
//                Button("Add", action: onAdd)
//            }
//        }
//    }
//}

struct SubtaskSectionView: View {
    let task: OtherTaskModel
    var onAdd: (String) -> Void
    var onToggleCompletion: () -> Void

    @State private var localSubtask: String = ""

    var body: some View {
        DisclosureGroup {
            ForEach(task.subtasks, id: \.id) { subtask in
                Text("- \(subtask.title)")
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
 
//struct OtherTasksView: View {
//    @Query private var tasksWithSubtasks: [OtherTaskModel]
//    @Environment(\.modelContext) private var modelContext
//
////    @State private var tasksWithSubtasks: [TaskWithSubtasks] = []
//    @State private var newTaskTitle: String = ""
//    @State private var newSubtask: String = ""
//    @State private var selectedTaskID: UUID?
// 
//    var body: some View {
//        NavigationStack {
//            VStack {
//                Form {
//                    Section(header: Text("Add New Task")) {
//                        TextField("Task Title", text: $newTaskTitle)
//                        Button("Add Task") {
//                            if !newTaskTitle.isEmpty {
//                                let newTask = OtherTaskModel(title: newTaskTitle)
//                                modelContext.insert(newTask)
//                                newTaskTitle = ""
//                            }
//                        }
//                    }
//
//                    Section(header: Text("Tasks with Subtasks")) {
//                        List {
//                            ForEach(tasksWithSubtasks, id: \.id) { task in
//                                SubtaskSectionView(task: task, newSubtask: $newSubtask) {
//                                    addSubtask(to: task)
//                                }
//                            }
//                        }
//                    }
//                }
//            }
//            .navigationTitle("Others Tasks")
//        }
//    }
//
//    private func addSubtask(to task: OtherTaskModel) {
//        guard !newSubtask.isEmpty else { return }
//        task.subtasks.append(SubtaskModel(title: newSubtask))
//        newSubtask = ""
//        try? modelContext.save()               // Persist the change
//    }
//}

struct OtherTasksView: View {
    @Query private var tasksWithSubtasks: [OtherTaskModel]
    @Environment(\.modelContext) private var modelContext
    
    @State private var newTaskTitle: String = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    Section(header: Text("Add New Task")) {
                        TextField("Task Title", text: $newTaskTitle)
                        Button("Add Task") {
                            if !newTaskTitle.isEmpty {
                                let newTask = OtherTaskModel(title: newTaskTitle)
                                modelContext.insert(newTask)
                                newTaskTitle = ""
                            }
                        }
                    }
                    
                    Section(header: Text("Tasks with Subtasks")) {
                        List {
                            ForEach(sortedTasks(), id: \.id) { task in
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
                    }
                }
            }
            .navigationTitle("Others Tasks")
        }
    }
    
    private func addSubtask(to task: OtherTaskModel, subtaskTitle: String) {
        let subtask = SubtaskModel(title: subtaskTitle)
        task.subtasks.append(subtask)
        try? modelContext.save()
    }
    
    private func sortedTasks() -> [OtherTaskModel] {
        tasksWithSubtasks.sorted {
            if $0.isCompleted == $1.isCompleted {
                return $0.title < $1.title
            }
            return !$0.isCompleted && $1.isCompleted // incomplete at top
        }
    }
    
    private func toggleTaskCompletion(_ task: OtherTaskModel) {
        task.isCompleted.toggle()
        try? modelContext.save()
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
            Form {
                Section(header: Text("Add Grocery Item")) {
                    TextField("Item Name", text: $newItemName)
                    Button("Add") {
                        guard !newItemName.isEmpty else { return }
                        let item = GroceryItemModel(name: newItemName)
                        modelContext.insert(item)
                        print("✅ Inserted: \(item.name)")
                        newItemName = ""
                    }
                }

                Section(header: Text("Grocery List")) {
                    List {
                        ForEach(sortedItems(), id: \.id) { item in
                            HStack {
                                Text(item.name)
                                    .strikethrough(item.isBought)
                                Spacer()
                            }
                            .contentShape(Rectangle()) // to make entire row tappable
                            .onTapGesture {
                                toggleItem(item)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Grocery List")
        }
    }

    private func toggleItem(_ item: GroceryItemModel) {
        item.isBought.toggle()
    }

    private func sortedItems() -> [GroceryItemModel] {
        groceryItems.sorted {
            if $0.isBought == $1.isBought {
                return $0.name < $1.name
            }
            return !$0.isBought && $1.isBought // not bought go first
        }
    }
}

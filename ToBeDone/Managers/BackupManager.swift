//
//  BackupManager.swift
//  ToBeDone
//
//  Keeps automatic JSON backups of everything in the app, so data can be
//  brought back if the database ever opens empty (for example after an update).
//
//  Backups live in the app's Documents/Backups folder. They are visible in the
//  Files app under "On My iPhone › ToBeDone", where you can also copy them to iCloud.
//

import Foundation
import SwiftData

// MARK: - Backup file format

/// Every field that is not essential is optional, so backups written by an
/// older version of the app can still be read after the models change.
struct AppBackup: Codable {
    var formatVersion: Int = 1
    var createdAt: Date = Date()

    var tasks: [TaskB] = []
    var shoppingItems: [ShoppingB] = []
    var monthlyTasks: [MonthlyB] = []
    var projects: [ProjectB] = []
    var groceryItems: [GroceryB] = []
    var confidenceEntries: [ConfidenceB] = []
    var activities: [ActivityB] = []
    var focusResults: [FocusB] = []

    var totalCount: Int {
        tasks.count + shoppingItems.count + monthlyTasks.count + projects.count +
        groceryItems.count + confidenceEntries.count + activities.count + focusResults.count
    }

    struct TaskB: Codable {
        var id: UUID; var title: String; var dueDate: Date
        var priority: String?; var isCompleted: Bool?
    }
    struct ShoppingB: Codable {
        var id: UUID; var name: String; var price: Double
        var currency: String?; var priority: String?; var isCompleted: Bool?; var completedAt: Date?
    }
    struct MonthlyB: Codable {
        var id: UUID; var title: String; var price: Double?
    }
    struct SubtaskB: Codable {
        var id: UUID; var title: String; var isCompleted: Bool?
    }
    struct ProjectB: Codable {
        var id: UUID; var title: String; var isCompleted: Bool?; var subtasks: [SubtaskB]?
    }
    struct GroceryB: Codable {
        var id: UUID; var name: String; var isBought: Bool?
    }
    struct ConfidenceB: Codable {
        var id: UUID; var date: Date; var score: Int; var note: String?; var tags: [String]?
    }
    struct ActivityB: Codable {
        var id: UUID; var date: Date; var name: String; var details: String?
        var durationMinutes: Int?; var isCompleted: Bool?
        var seriesId: UUID?; var repeatsWeekly: Bool?; var repeatWeeks: Int?
    }
    struct FocusB: Codable {
        var date: Date; var duration: Double
    }
}

// MARK: - Backup manager

enum BackupManager {

    static var backupFolder: URL {
        URL.documentsDirectory.appending(path: "Backups", directoryHint: .isDirectory)
    }
    static var latestBackupURL: URL {
        backupFolder.appending(path: "ToBeDone-backup-latest.json")
    }
    private static let daysToKeep = 7

    // MARK: Snapshot

    @MainActor
    static func makeSnapshot(context: ModelContext) -> AppBackup {
        func all<T: PersistentModel>(_ type: T.Type) -> [T] {
            (try? context.fetch(FetchDescriptor<T>())) ?? []
        }

        var b = AppBackup()
        b.tasks = all(TaskModel.self).map {
            AppBackup.TaskB(id: $0.id, title: $0.title, dueDate: $0.dueDate,
                  priority: $0.priority.rawValue, isCompleted: $0.isCompleted)
        }
        b.shoppingItems = all(ShoppingItemModel.self).map {
            AppBackup.ShoppingB(id: $0.id, name: $0.name, price: $0.price, currency: $0.currency,
                  priority: $0.priority.rawValue, isCompleted: $0.isCompleted, completedAt: $0.completedAt)
        }
        b.monthlyTasks = all(MonthlyTaskModel.self).map {
            AppBackup.MonthlyB(id: $0.id, title: $0.title, price: $0.price)
        }
        b.projects = all(OtherTaskModel.self).map { p in
            AppBackup.ProjectB(id: p.id, title: p.title, isCompleted: p.isCompleted,
                  subtasks: p.subtasks.map { AppBackup.SubtaskB(id: $0.id, title: $0.title, isCompleted: $0.isCompleted) })
        }
        b.groceryItems = all(GroceryItemModel.self).map {
            AppBackup.GroceryB(id: $0.id, name: $0.name, isBought: $0.isBought)
        }
        b.confidenceEntries = all(ConfidenceEntry.self).map {
            AppBackup.ConfidenceB(id: $0.id, date: $0.date, score: $0.score, note: $0.note, tags: $0.tags)
        }
        b.activities = all(ActivityItem.self).map {
            AppBackup.ActivityB(id: $0.id, date: $0.date, name: $0.name, details: $0.details,
                  durationMinutes: $0.durationMinutes, isCompleted: $0.isCompleted,
                  seriesId: $0.seriesId, repeatsWeekly: $0.repeatsWeekly, repeatWeeks: $0.repeatWeeks)
        }
        b.focusResults = all(FocusResult.self).map {
            AppBackup.FocusB(date: $0.date, duration: $0.duration)
        }
        return b
    }

    // MARK: Write

    /// Saves pending changes, then writes the latest backup plus one per day (last 7 kept).
    /// An empty database never overwrites a backup that has data in it.
    @MainActor
    @discardableResult
    static func writeBackup(context: ModelContext) -> Bool {
        try? context.save()
        let snapshot = makeSnapshot(context: context)
        guard snapshot.totalCount > 0 else { return false }

        do {
            try FileManager.default.createDirectory(at: backupFolder, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            // Default date format keeps full precision, so restored items match exactly
            let data = try encoder.encode(snapshot)

            try data.write(to: latestBackupURL, options: .atomic)

            let day = Date().formatted(.iso8601.year().month().day())
            try data.write(to: backupFolder.appending(path: "ToBeDone-backup-\(day).json"), options: .atomic)

            pruneOldBackups()
            return true
        } catch {
            print("Backup failed:", error)
            return false
        }
    }

    private static func pruneOldBackups() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: backupFolder, includingPropertiesForKeys: nil) else { return }
        let daily = files
            .filter { $0.lastPathComponent.hasPrefix("ToBeDone-backup-20") }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }   // newest first (dates sort as text)
        for old in daily.dropFirst(daysToKeep) {
            try? fm.removeItem(at: old)
        }
    }

    // MARK: Read

    static func readLatestBackup() -> AppBackup? {
        guard let data = try? Data(contentsOf: latestBackupURL) else { return nil }
        return try? JSONDecoder().decode(AppBackup.self, from: data)
    }

    // MARK: Restore

    /// Adds everything from the backup that is not already in the database (matched by id).
    /// Nothing existing is deleted or overwritten. Returns how many items were added.
    @MainActor
    @discardableResult
    static func restore(_ backup: AppBackup, into context: ModelContext) -> Int {
        func ids<T: PersistentModel>(_ type: T.Type, _ id: (T) -> UUID) -> Set<UUID> {
            Set(((try? context.fetch(FetchDescriptor<T>())) ?? []).map(id))
        }
        var added = 0

        let taskIds = ids(TaskModel.self) { $0.id }
        for t in backup.tasks where !taskIds.contains(t.id) {
            let m = TaskModel(title: t.title, dueDate: t.dueDate,
                              priority: TaskPriority(rawValue: t.priority ?? "") ?? .medium)
            m.id = t.id
            m.isCompleted = t.isCompleted ?? false
            context.insert(m)
            NotificationManager.shared.scheduleNotification(for: m)
            added += 1
        }

        let shopIds = ids(ShoppingItemModel.self) { $0.id }
        for s in backup.shoppingItems where !shopIds.contains(s.id) {
            let m = ShoppingItemModel(id: s.id, name: s.name, price: s.price,
                                      currency: s.currency ?? "",
                                      priority: TaskPriority(rawValue: s.priority ?? "") ?? .medium,
                                      isCompleted: s.isCompleted ?? false)
            m.completedAt = s.completedAt
            context.insert(m)
            added += 1
        }

        let monthlyIds = ids(MonthlyTaskModel.self) { $0.id }
        for mt in backup.monthlyTasks where !monthlyIds.contains(mt.id) {
            let m = MonthlyTaskModel(title: mt.title, price: mt.price ?? 0)
            m.id = mt.id
            context.insert(m)
            added += 1
        }

        let projectIds = ids(OtherTaskModel.self) { $0.id }
        for p in backup.projects where !projectIds.contains(p.id) {
            let subs = (p.subtasks ?? []).map {
                SubtaskModel(id: $0.id, title: $0.title, isCompleted: $0.isCompleted ?? false)
            }
            context.insert(OtherTaskModel(id: p.id, title: p.title,
                                          isCompleted: p.isCompleted ?? false, subtasks: subs))
            added += 1
        }

        let groceryIds = ids(GroceryItemModel.self) { $0.id }
        for g in backup.groceryItems where !groceryIds.contains(g.id) {
            let m = GroceryItemModel(name: g.name, isBought: g.isBought ?? false)
            m.id = g.id
            context.insert(m)
            added += 1
        }

        let confidenceIds = ids(ConfidenceEntry.self) { $0.id }
        for c in backup.confidenceEntries where !confidenceIds.contains(c.id) {
            context.insert(ConfidenceEntry(id: c.id, date: c.date, score: c.score,
                                           note: c.note, tags: c.tags ?? []))
            added += 1
        }

        let activityIds = ids(ActivityItem.self) { $0.id }
        for a in backup.activities where !activityIds.contains(a.id) {
            let m = ActivityItem(date: a.date, name: a.name, details: a.details ?? "",
                                 durationMinutes: a.durationMinutes ?? 0,
                                 isCompleted: a.isCompleted ?? false,
                                 seriesId: a.seriesId,
                                 repeatsWeekly: a.repeatsWeekly ?? false,
                                 repeatWeeks: a.repeatWeeks ?? 0)
            m.id = a.id
            context.insert(m)
            added += 1
        }

        let existingFocus = (try? context.fetch(FetchDescriptor<FocusResult>())) ?? []
        for f in backup.focusResults
        where !existingFocus.contains(where: { $0.date == f.date && $0.duration == f.duration }) {
            context.insert(FocusResult(date: f.date, duration: f.duration))
            added += 1
        }

        try? context.save()
        return added
    }

    /// True when nothing at all is stored in the database.
    @MainActor
    static func databaseIsEmpty(context: ModelContext) -> Bool {
        makeSnapshot(context: context).totalCount == 0
    }
}

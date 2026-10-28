//
//  DataStore.swift
//  ToBeDone
//
//  Opens the app's database. If it ever can't be opened, the files are copied
//  aside (never deleted) and the app offers to restore from the latest backup,
//  instead of crashing.
//

import Foundation
import SwiftData

enum DataStore {
    static let schema = Schema([
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

    /// The error message when the existing database could not be opened at launch.
    private(set) static var openError: String?

    /// Created once, the first time it is used.
    static let container: ModelContainer = makeContainer()

    private static func makeContainer() -> ModelContainer {
        // Screenshot mode: sample data in memory only, the real database is not opened
        if DemoData.isEnabled {
            let memory = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try! ModelContainer(for: schema, configurations: [memory])
            DemoData.seed(into: ModelContext(container))
            return container
        }

        // Keep the name "default": it is the same database file every earlier version used.
        // Changing the name or location would make the app open an empty database.
        let config = ModelConfiguration("default")

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("Could not open database:", error)
            openError = error.localizedDescription

            // Keep a copy of the files that failed to open, then start a fresh database.
            // The user is then offered a restore from the JSON backup.
            preserveAndRemoveStoreFiles(at: config.url)
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                print("Could not create a fresh database:", error)
                let memory = ModelConfiguration(isStoredInMemoryOnly: true)
                return try! ModelContainer(for: schema, configurations: [memory])
            }
        }
    }

    /// Copies default.store (and its -shm / -wal companions) into
    /// Application Support/UnopenedDatabase-<date>/, then removes the originals.
    private static func preserveAndRemoveStoreFiles(at storeURL: URL) {
        let fm = FileManager.default
        let stamp = Date().formatted(.iso8601).replacingOccurrences(of: ":", with: "-")
        let folder = storeURL.deletingLastPathComponent()
            .appending(path: "UnopenedDatabase-\(stamp)", directoryHint: .isDirectory)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)

        for suffix in ["", "-shm", "-wal"] {
            let file = URL(fileURLWithPath: storeURL.path + suffix)
            guard fm.fileExists(atPath: file.path) else { continue }
            do {
                try fm.copyItem(at: file, to: folder.appending(path: file.lastPathComponent))
                try fm.removeItem(at: file)
            } catch {
                print("Could not move \(file.lastPathComponent):", error)
            }
        }
    }
}

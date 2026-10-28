//
//  ToBeDoneApp.swift
//  ToBeDone
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct LifeOrderingApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("selectedTheme") private var selectedTheme: String = "Default"
    @State private var backupToRestore: AppBackup?
    @State private var showRestorePrompt = false
    @State private var restoredCount: Int?

    init() {
        NotificationManager.shared.requestPermission()
    }

    /// "Default" follows the system setting; "Light"/"Dark" force a mode.
    private var colorScheme: ColorScheme? {
        switch selectedTheme {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }

    // Opened in DataStore: same database file as before, but no crash if it can't be opened
    var sharedModelContainer: ModelContainer { DataStore.container }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasSeenIntroPage {
                    HomeView()
                } else {
                    IntroPage(hasSeenIntroPage: $hasSeenIntroPage)
                }
            }
            .modelContainer(sharedModelContainer)
            .preferredColorScheme(colorScheme)
            .task { checkForRestore() }
            .alert("Restore your data?", isPresented: $showRestorePrompt, presenting: backupToRestore) { backup in
                Button("Restore") {
                    restoredCount = BackupManager.restore(backup, into: sharedModelContainer.mainContext)
                }
                Button("Not now", role: .cancel) {}
            } message: { backup in
                Text("The app opened without any data, but a backup from \(backup.createdAt.formatted(date: .abbreviated, time: .shortened)) with \(backup.totalCount) items was found. Restoring only adds items; nothing is deleted.")
            }
            .alert("Data restored", isPresented: Binding(
                get: { restoredCount != nil },
                set: { if !$0 { restoredCount = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("\(restoredCount ?? 0) items were brought back from the backup.")
            }
        }
        .onChange(of: scenePhase) { _, phase in
            let context = sharedModelContainer.mainContext
            switch phase {
            case .active:
                // Keep the daily reminder text up to date each time the app opens
                ReminderScheduler.refresh(context: context)
                BackupManager.writeBackup(context: context)
            case .background:
                // Save and back up whenever the app leaves the screen
                BackupManager.writeBackup(context: context)
            default:
                break
            }
        }
    }

    @AppStorage("hasSeenIntroPage") private var hasSeenIntroPage: Bool = false

    /// If the database is empty but a backup with data exists, offer to restore it.
    @MainActor
    private func checkForRestore() {
        let context = sharedModelContainer.mainContext
        guard BackupManager.databaseIsEmpty(context: context),
              let backup = BackupManager.readLatestBackup(),
              backup.totalCount > 0 else { return }
        backupToRestore = backup
        showRestorePrompt = true
    }

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
                Text("Let's begin! What should we call you?")
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

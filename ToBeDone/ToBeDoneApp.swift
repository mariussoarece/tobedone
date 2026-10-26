//
//  ToBeDoneApp.swift
//  ToBeDone
//

import SwiftUI
import SwiftData
import UserNotifications

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

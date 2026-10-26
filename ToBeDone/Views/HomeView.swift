//
//  HomeView.swift
//  ToBeDone
//

import SwiftUI

struct HomeView: View {
    @AppStorage("userName") private var userName: String = ""
    @State private var showFocusTest = false
    @State private var startTest = false
    @State private var showResults = false
    @State private var openResultsAfterTest = false

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
            .fullScreenCover(isPresented: $startTest, onDismiss: {
                // Open results only after the test screen has fully closed;
                // presenting both at once made the results screen not appear.
                if openResultsAfterTest {
                    openResultsAfterTest = false
                    showResults = true
                }
            }) {
                RedDotFocusTestView(shouldReturnToHome: false, onFinish: { openResultsAfterTest = true })
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

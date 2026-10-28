//
//  HomeView.swift
//  ToBeDone
//
//  Home screen (design "A · Clean iOS"): greeting, Today progress, and the
//  Plan / Do / Grow sections. Colors are system colors, so dark mode works automatically.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("selectedCurrency") private var selectedCurrency: String = "USD"
    @State private var showSettings = false

    @Query private var tasks: [TaskModel]
    @Query private var activities: [ActivityItem]
    @Query private var shoppingItems: [ShoppingItemModel]
    @Query private var groceryItems: [GroceryItemModel]
    @Query private var monthlyItems: [MonthlyTaskModel]
    @Query private var projects: [OtherTaskModel]
    @Query private var confidenceEntries: [ConfidenceEntry]
    @Query private var focusResults: [FocusResult]

    var body: some View {
        NavigationStack {
            List {
                // Greeting + Settings
                Section {
                    header
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))

                // Today
                Section {
                    todayCard
                }

                Section {
                    HomeRow(title: Text("To Do"), icon: "checklist", color: .blue,
                            detail: countText(openTasks)) { DueTasksView() }
                    HomeRow(title: Text("Monthly Expenses"), icon: "calendar", color: .orange,
                            detail: monthlyText) { MonthlyTasksView() }
                    HomeRow(title: Text("Projects"), icon: "target", color: .indigo,
                            detail: countText(projects.filter { !$0.isCompleted }.count)) { OtherTasksView() }
                } header: {
                    Text("PLAN")
                }

                Section {
                    HomeRow(title: Text("Shopping"), icon: "cart.fill", color: .red,
                            detail: countText(shoppingItems.filter { !$0.isCompleted }.count)) { ShoppingTasksView() }
                    HomeRow(title: Text("Grocery"), icon: "basket.fill", color: .green,
                            detail: countText(groceryItems.filter { !$0.isBought }.count)) { GroceryTasksView() }
                } header: {
                    Text("DO")
                }

                Section {
                    HomeRow(title: Text("Daily Routine"), icon: "clock.fill", color: .teal,
                            detail: activitiesLeftToday > 0 ? "\(activitiesLeftToday) left" : nil) { DailyActivitiesView() }
                    HomeRow(title: Text("Confidence"), icon: "heart.fill", color: .pink,
                            detail: confidenceText) { ConfidenceTrackerView() }
                    HomeRow(title: Text("Focus Test"), icon: "eye.fill", color: .cyan,
                            detail: focusBestText) { FocusTestView() }
                } header: {
                    Text("GROW")
                }

                // Handwritten footer
                Section {
                    Image("you_got_this")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 170)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("You got this!")
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.insetGrouped)
            .environment(\.defaultMinListRowHeight, 34)   // allows the shorter rows below
            .toolbar(.hidden, for: .navigationBar)   // the greeting replaces the title bar on Home only
            .navigationDestination(isPresented: $showSettings) { SettingsView() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text("Hi, \(userName.isEmpty ? "Friend" : userName)")
                        .font(.largeTitle.bold())
                    Image(systemName: "heart.fill")
                        .font(.title2)
                        .foregroundStyle(.pink)
                        .accessibilityHidden(true)
                }
            }
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color(.secondarySystemGroupedBackground), in: Circle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Settings")
        }
        .padding(.top, 8)
    }

    // MARK: - Today card

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today").font(.headline)
                Spacer()
                if todayTotal > 0 {
                    Text("\(Int((todayProgress * 100).rounded()))%")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                }
            }
            if todayTotal > 0 {
                ProgressView(value: todayProgress)
                    .tint(.blue)
                    .accessibilityLabel("Today's progress")
            } else {
                Text("Nothing planned for today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                stat(openTasks, "tasks due")
                stat(activitiesLeftToday, "activities left")
                stat(toBuy, "to buy")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private func stat(_ value: Int, _ label: String) -> Text {
        Text("\(value)").bold().foregroundColor(.primary) + Text(" \(label)")
    }

    // MARK: - Numbers

    /// Unfinished tasks due today or earlier
    private var openTasks: Int {
        let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now
        return tasks.filter { !$0.isCompleted && $0.dueDate < endOfToday }.count
    }

    private var todayTasks: [TaskModel] { tasks.filter { Calendar.current.isDateInToday($0.dueDate) } }
    private var todayActivities: [ActivityItem] { activities.filter { Calendar.current.isDateInToday($0.date) } }

    private var activitiesLeftToday: Int { todayActivities.filter { !$0.isCompleted }.count }

    /// Today's tasks and activities: how many there are and how many are done
    private var todayTotal: Int { todayTasks.count + todayActivities.count }
    private var todayProgress: Double {
        guard todayTotal > 0 else { return 0 }
        let done = todayTasks.filter(\.isCompleted).count + todayActivities.filter(\.isCompleted).count
        return Double(done) / Double(todayTotal)
    }

    private var toBuy: Int {
        shoppingItems.filter { !$0.isCompleted }.count + groceryItems.filter { !$0.isBought }.count
    }

    private var monthlyText: String? {
        guard !monthlyItems.isEmpty else { return nil }
        let total = monthlyItems.reduce(0) { $0 + $1.price }
        return "\(total.formatted(.number.precision(.fractionLength(0...2)))) \(selectedCurrency)"
    }

    /// Average confidence over the last 7 days
    private var confidenceText: String? {
        guard let start = Calendar.current.date(byAdding: .day, value: -7, to: .now) else { return nil }
        let recent = confidenceEntries.filter { $0.date >= start }
        guard !recent.isEmpty else { return nil }
        let avg = Double(recent.reduce(0) { $0 + $1.score }) / Double(recent.count)
        return String(format: "%.1f", avg)
    }

    /// "Best 42 s", shown at the right edge of the Focus Test row
    private var focusBestText: String? {
        guard let best = focusResults.map(\.duration).max() else { return nil }
        return "Best \(FocusResult.formatBest(best))"
    }

    private func countText(_ n: Int) -> String? { n > 0 ? "\(n)" : nil }
}

// MARK: - Row

/// One row: colored icon tile, title, optional number on the right, chevron.
private struct HomeRow<Destination: View>: View {
    let title: Text
    let icon: String
    let color: Color
    let detail: String?
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(color, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .accessibilityHidden(true)
                title
                Spacer()
                if let detail {
                    Text(detail).foregroundStyle(.secondary)
                }
            }
        }
        // About 2 mm less height per row than the iOS default
        .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
    }
}

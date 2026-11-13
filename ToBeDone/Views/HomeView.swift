//
//  HomeView.swift
//  ToBeDone
//
//  Home screen (design "A · Clean iOS"): greeting, today's agenda, and the
//  Plan / Do / Grow sections. Colors are system colors, so dark mode works automatically.
//

import SwiftUI
import SwiftData
import StoreKit

struct HomeView: View {
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("selectedCurrency") private var selectedCurrency: String = "USD"
    @State private var showSettings = false
    @State private var destination: HomeDestination?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview

    @Query private var tasks: [TaskModel]
    @Query private var activities: [ActivityItem]
    @Query private var shoppingItems: [ShoppingItemModel]
    @Query private var groceryItems: [GroceryItemModel]
    @Query private var monthlyItems: [MonthlyTaskModel]
    @Query private var projects: [OtherTaskModel]
    @Query private var confidenceEntries: [ConfidenceEntry]
    @Query private var focusResults: [FocusResult]
    @Query(sort: \JournalEntry.date, order: .reverse) private var journalEntries: [JournalEntry]

    var body: some View {
        NavigationStack {
            List {
                // Greeting + Settings
                Section {
                    header
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))

                // Today: everything scheduled today, by time
                Section {
                    todaySection
                }

                Section {
                    HomeRow(title: Text("To Do"), icon: "checklist", color: .blue,
                            detail: countText(openTasks)) { DueTasksView() }
                    HomeRow(title: Text("Monthly Expenses"), icon: "calendar", color: .orange,
                            detail: monthlyText) { MonthlyTasksView() }
                    HomeRow(title: Text("Projects"), icon: "target", color: .green,
                            detail: countText(projects.filter { !$0.isCompleted }.count)) { OtherTasksView() }
                } header: {
                    Text("PLAN")
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16))   // title line about 2 mm shorter
                }

                Section {
                    HomeRow(title: Text("Shopping"), icon: "cart.fill", color: .red,
                            detail: countText(shoppingItems.filter { !$0.isCompleted }.count)) { ShoppingTasksView() }
                    HomeRow(title: Text("Grocery"), icon: "basket.fill", color: .yellow,
                            detail: countText(groceryItems.filter { !$0.isBought }.count)) { GroceryTasksView() }
                } header: {
                    Text("DO")
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16))   // title line about 2 mm shorter
                }

                Section {
                    HomeRow(title: Text("Daily Routine"), icon: "clock.fill", color: .indigo,
                            detail: activitiesLeftToday > 0 ? "\(activitiesLeftToday) left" : nil) { DailyActivitiesView() }
                    HomeRow(title: Text("Confidence"), icon: "heart.fill", color: .pink,
                            detail: confidenceText) { ConfidenceTrackerView() }
                    HomeRow(title: Text("Journalling"), icon: "book.closed.fill", color: .orange,
                            detail: journalEntries.first?.mood.emoji) { JournalView() }
                    HomeRow(title: Text("Focus Test"), icon: "eye.fill", color: .blue,
                            detail: focusBestText) { FocusTestView() }
                } header: {
                    Text("GROW")
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16))   // title line about 2 mm shorter
                }

                // Handwritten footer
                Section {
                    // The image's empty border was trimmed, so 152 pt wide
                    // shows the handwriting at the same size as before
                    Image("you_got_this")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 152)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("You got this!")
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))   // less empty space around it
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)   // smaller gaps between Today, PLAN, DO and GROW
            .environment(\.defaultMinListRowHeight, 34)   // allows the shorter rows below
            .toolbar(.hidden, for: .navigationBar)   // the greeting replaces the title bar on Home only
            .navigationDestination(isPresented: $showSettings) { SettingsView() }
            .task { await askForRatingIfDue() }
            .navigationDestination(item: $destination) { target in
                switch target {
                case .todo: DueTasksView()
                case .monthly: MonthlyTasksView()
                case .routine: DailyActivitiesView()
                case .weekly: DailyActivitiesView(startWeekly: true)
                }
            }
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

    /// Today's To Do tasks, Monthly Expenses and Daily Routine activities, by time.
    /// Each one is its own row: tap it to open its section, tap the circle to tick it off.
    @ViewBuilder
    private var todaySection: some View {
        HStack {
            Text("Today").font(.headline)
            Spacer()
            // Weekly view of the Daily Routine, with To Do and Monthly Expenses as lines
            Button {
                destination = .weekly
            } label: {
                Label("Weekly view", systemImage: "calendar.day.timeline.left")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .tint(.blue)
        }
        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 8, trailing: 12))

        if todayAgenda.isEmpty {
            Text("Nothing planned for today.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 10, trailing: 16))
        } else {
            ForEach(todayAgenda) { item in
                TodayRow(item: item, currency: selectedCurrency,
                         onToggle: { withAnimation { toggle(item) } })
                    .contentShape(Rectangle())
                    .onTapGesture { destination = HomeDestination(item.kind) }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 12))
            }
        }
    }

    private var todayAgenda: [AgendaItem] {
        // Ticked-off tasks and activities leave the Today panel
        Agenda.forDay(.now, tasks: tasks, monthly: monthlyItems, activities: activities)
            .filter { !$0.done }
    }

    /// Tick a To Do task or Daily Routine activity off (or back on) from the Today card.
    private func toggle(_ item: AgendaItem) {
        switch item.kind {
        case .task:
            guard let task = tasks.first(where: { $0.id == item.modelID }) else { return }
            task.isCompleted.toggle()
            try? modelContext.save()
            if task.isCompleted {
                NotificationManager.shared.cancelNotification(for: task)
            } else {
                NotificationManager.shared.scheduleNotification(for: task)
            }
        case .activity:
            guard let activity = activities.first(where: { $0.id == item.modelID }) else { return }
            activity.isCompleted.toggle()
            try? modelContext.save()
            syncActivityConfidence(for: activity.date)
        case .monthly:
            // Paid for this month: it leaves Today and this month's reminder is skipped
            guard let expense = monthlyItems.first(where: { $0.id == item.modelID }) else { return }
            expense.paidMonth = expense.isPaid(in: item.start) ? nil : MonthlyTaskModel.monthKey(for: item.start)
            try? modelContext.save()
        }
        ReminderScheduler.refresh(context: modelContext)
    }

    /// Same rule as the Daily Routine screen: the day's score is the share of
    /// activities done (0–10), kept in a ConfidenceEntry tagged "activities".
    private func syncActivityConfidence(for date: Date) {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        let dayItems = activities.filter { cal.isDate($0.date, inSameDayAs: dayStart) }
        let existing = confidenceEntries.first {
            cal.isDate($0.date, inSameDayAs: dayStart) && $0.tags.contains("activities")
        }
        guard !dayItems.isEmpty else { return }
        let done = dayItems.filter(\.isCompleted).count
        let score = Int((Double(done) / Double(dayItems.count) * 10).rounded())
        if let existing {
            existing.score = score
        } else {
            modelContext.insert(ConfidenceEntry(date: dayStart, score: score,
                                                note: "Derived from activities", tags: ["activities"]))
        }
        try? modelContext.save()
    }

    // MARK: - Rating

    /// Apple's own "Enjoying ToBeDone?" rating window, once after 1 month of use
    /// and once after 2 months. Apple decides whether it really appears (at most
    /// 3 times a year, and never in TestFlight builds).
    private func askForRatingIfDue() async {
        guard !DemoData.isEnabled else { return }
        let defaults = UserDefaults.standard
        let firstUseKey = "firstUseDate"
        let shownKey = "ratingPromptsShown"

        guard let firstUse = defaults.object(forKey: firstUseKey) as? Date else {
            defaults.set(Date.now, forKey: firstUseKey)   // start counting from today
            return
        }
        let days = Calendar.current.dateComponents([.day], from: firstUse, to: .now).day ?? 0
        let shown = defaults.integer(forKey: shownKey)
        let due = (shown == 0 && days >= 30) || (shown == 1 && days >= 60)
        guard due else { return }

        try? await Task.sleep(for: .seconds(2))   // let Home appear first
        guard !Task.isCancelled else { return }
        defaults.set(shown + 1, forKey: shownKey)
        requestReview()
    }

    // MARK: - Numbers

    /// Unfinished tasks due today or earlier
    private var openTasks: Int {
        let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now
        return tasks.filter { !$0.isCompleted && $0.dueDate < endOfToday }.count
    }

    private var activitiesLeftToday: Int {
        activities.filter { !$0.isCompleted && Calendar.current.isDateInToday($0.date) }.count
    }

    private var monthlyText: String? {
        // Still to pay this month (expenses marked as paid are deducted)
        let unpaid = monthlyItems.filter { !$0.isCompleted && !$0.isPaid(in: .now) }
        guard !unpaid.isEmpty else { return nil }
        let total = unpaid.reduce(0) { $0 + $1.price }
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

// MARK: - Today rows

/// Where a tap on the Today card leads
enum HomeDestination: Hashable {
    case todo, monthly, routine, weekly

    init(_ kind: AgendaKind) {
        switch kind {
        case .task: self = .todo
        case .monthly: self = .monthly
        case .activity: self = .routine
        }
    }
}

/// "09:00 | Deep work · Daily Routine · 120 min   ○"
private struct TodayRow: View {
    let item: AgendaItem
    let currency: String
    let onToggle: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Text(item.start.formatted(date: .omitted, time: .shortened))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(item.kind.color)
                .frame(width: 3, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .strikethrough(item.done)
                    .foregroundStyle(item.done ? .secondary : .primary)
                    .lineLimit(1)
                Text(item.detail(currency: currency))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if let onToggle {
                Button(action: onToggle) {
                    Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(item.done ? Color.green : Color.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(item.done ? "Mark as not done" : "Mark as done")
            }
        }
    }
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
        // Row height: 9 pt above and below the content
        .listRowInsets(EdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16))
    }
}

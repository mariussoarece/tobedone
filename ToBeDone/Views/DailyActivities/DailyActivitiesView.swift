//
//  DailyActivitiesView.swift
//  ToBeDone
//

import SwiftUI
import SwiftData
import UserNotifications

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
            // Segmented picker shows which view is active
            Picker("View", selection: $viewMode) {
                Text("Monthly").tag(ViewMode.monthly)
                Text("Weekly").tag(ViewMode.weekly)
            }
            .pickerStyle(.segmented)
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
                ActivityReminderScheduler.refresh(context: modelContext)
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
                            updated.isCompleted.toggle()
                            try? modelContext.save()
                            syncConfidenceForDay(selectedDate)
                            ActivityReminderScheduler.refresh(context: modelContext)
                        })

                    }
                    .onDelete { indexSet in
                        let items = dayActivities(selectedDate)
                        for i in indexSet { modelContext.delete(items[i]) }
                        try? modelContext.save()
                        syncConfidenceForDay(selectedDate)
                        ActivityReminderScheduler.refresh(context: modelContext)
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

    // Write or update the activity-based ConfidenceEntry for a day.
    // Only touches entries tagged "activities", so scores you logged yourself
    // in the Confidence screen are never overwritten.
    private func syncConfidenceForDay(_ date: Date) {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        let existing = confidenceEntries.first {
            cal.isDate($0.date, inSameDayAs: dayStart) && $0.tags.contains("activities")
        }
        guard let score = scoreForDay(date) else {
            // No activities left that day: remove the derived score
            if let e = existing {
                modelContext.delete(e)
                try? modelContext.save()
            }
            return
        }
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
            ActivityReminderScheduler.refresh(context: modelContext)
        } catch {
            print("Import decode error:", error)
        }
    }
}

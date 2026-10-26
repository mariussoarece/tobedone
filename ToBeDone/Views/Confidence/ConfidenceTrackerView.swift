//
//  ConfidenceTrackerView.swift
//  ToBeDone
//

import SwiftUI
import SwiftData
import Charts

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

//
//  TodayWidget.swift
//  ToBeDoneWidget
//
//  Home-screen widget: everything happening today (To Do, Monthly Expenses,
//  Daily Routine) ordered by time, from the current hour onwards, with a +
//  that opens the app's main screen.
//
//  The app writes the data to the shared App Group folder (WidgetData.swift);
//  this widget only reads it. Both targets need the App Group
//  "group.ro.vishrama.tobedone" in Signing & Capabilities.
//

import WidgetKit
import SwiftUI

// MARK: - Data (same layout as WidgetSnapshot in the app)

struct WidgetSnapshot: Codable {
    struct Item: Codable {
        var kind: String          // "task", "monthly", "activity"
        var title: String
        var start: Date
        var durationMinutes: Int
        var done: Bool
        var detail: String
    }
    var generatedAt: Date
    var items: [Item]
    /// Today's Confidence level (0–10, whole number), for the face in the background
    var confidence: Int? = nil
    /// The day that level belongs to
    var confidenceDay: Date? = nil

    /// The level for the day of `date`, or nil (a new day starts without a face)
    func level(on date: Date) -> Int? {
        guard let confidence, let day = confidenceDay,
              Calendar.current.isDate(day, inSameDayAs: date) else { return nil }
        return confidence
    }

    static let appGroup = "group.ro.vishrama.tobedone"
    static let fileName = "widget-agenda.json"

    static func load() -> WidgetSnapshot? {
        guard let url = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
                .appending(path: fileName),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}

extension WidgetSnapshot.Item {
    var end: Date { start.addingTimeInterval(TimeInterval(durationMinutes * 60)) }

    var color: Color {
        switch kind {
        case "task": return .blue
        case "monthly": return .orange
        default: return .indigo
        }
    }
}

// MARK: - Timeline

struct TodayEntry: TimelineEntry {
    let date: Date
    let items: [WidgetSnapshot.Item]
    let hasData: Bool
    var confidence: Int? = nil
}

struct TodayProvider: TimelineProvider {

    /// Today's items from the start of the current hour onwards.
    /// Activities that started earlier but are still going on are kept too.
    static func items(at date: Date, from snapshot: WidgetSnapshot?) -> [WidgetSnapshot.Item] {
        guard let snapshot else { return [] }
        let cal = Calendar.current
        let hourStart = cal.dateInterval(of: .hour, for: date)?.start ?? date
        return snapshot.items
            .filter { cal.isDate($0.start, inSameDayAs: date) && ($0.start >= hourStart || $0.end > date) }
            .filter { !$0.done }   // ticked off (or paid) items leave the widget
            .sorted { $0.start < $1.start }
    }

    func placeholder(in context: Context) -> TodayEntry {
        let now = Date()
        let sample = [
            WidgetSnapshot.Item(kind: "activity", title: "Morning run", start: now, durationMinutes: 30, done: false, detail: "Daily Routine · 30 min"),
            WidgetSnapshot.Item(kind: "task", title: "Send the report", start: now.addingTimeInterval(3600), durationMinutes: 0, done: false, detail: "To Do"),
            WidgetSnapshot.Item(kind: "monthly", title: "Internet", start: now.addingTimeInterval(7200), durationMinutes: 0, done: false, detail: "Monthly expense"),
        ]
        return TodayEntry(date: now, items: sample, hasData: true, confidence: 10)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        let snapshot = WidgetSnapshot.load()
        completion(TodayEntry(date: .now, items: Self.items(at: .now, from: snapshot), hasData: snapshot != nil,
                              confidence: snapshot?.level(on: .now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load()
        let cal = Calendar.current
        let now = Date()

        // One entry now, then one at the start of every hour for the next 24 hours,
        // so the list always begins at the current hour (and changes day at midnight).
        var dates = [now]
        if let hourStart = cal.dateInterval(of: .hour, for: now)?.start {
            for h in 1...24 {
                if let d = cal.date(byAdding: .hour, value: h, to: hourStart) { dates.append(d) }
            }
        }
        let entries = dates.map {
            TodayEntry(date: $0, items: Self.items(at: $0, from: snapshot), hasData: snapshot != nil,
                       confidence: snapshot?.level(on: $0))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - View

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    private var maxRows: Int {
        switch family {
        case .systemLarge, .systemExtraLarge: return 8
        default: return 3
        }
    }
    private var compact: Bool { family == .systemSmall }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if entry.items.isEmpty {
                Spacer(minLength: 0)
                Text(entry.hasData ? "Nothing more planned for today." : "Open ToBeDone once to show your day here.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.black)
                Spacer(minLength: 0)
            } else {
                ForEach(Array(entry.items.prefix(maxRows).enumerated()), id: \.offset) { _, item in
                    row(item)
                }
                if entry.items.count > maxRows {
                    Text("+ \(entry.items.count - maxRows) more")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.black)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Today")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.black)
                Text(entry.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.black)
            }
            Spacer(minLength: 4)
            // + opens the app's main screen (the whole widget does too)
            Link(destination: URL(string: "tobedone://home")!) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.blue, in: Circle())
            }
            .accessibilityLabel("Open ToBeDone")
        }
    }

    private func row(_ item: WidgetSnapshot.Item) -> some View {
        HStack(spacing: 6) {
            Text(item.start, format: .dateTime.hour().minute())
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.black)
                .frame(width: compact ? 34 : 44, alignment: .leading)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(item.color)
                .frame(width: 3, height: compact ? 18 : 24)
            VStack(alignment: .leading, spacing: 0) {
                Text((item.done ? "✓ " : "") + item.title)
                    .font((compact ? Font.caption : Font.subheadline).weight(.bold))
                    .strikethrough(item.done)
                    .foregroundStyle(.black)
                    .lineLimit(1)
                if !compact {
                    Text(item.detail)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Face in the background

/// A large face behind the list, only when today's Confidence level (as on Home,
/// rounded) is 10. Any other level, or nothing today yet: no face.
struct ConfidenceFace: View {
    let score: Int?

    private var imageName: String? {
        score == 10 ? "face_10" : nil
    }

    var body: some View {
        if let imageName {
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height) * 0.85
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Widget

struct TodayWidget: Widget {
    let kind = "TodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    ZStack {
                        Color.white   // always white, so the black text is easy to read
                        ConfidenceFace(score: entry.confidence)
                    }
                }
                .widgetURL(URL(string: "tobedone://home"))
        }
        .configurationDisplayName("Today")
        .description("Today's To Do tasks, monthly expenses and Daily Routine, by time.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct ToBeDoneWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
    }
}

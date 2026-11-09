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
    /// Latest Confidence score (0–10), for the smiley in the background
    var confidence: Int? = nil

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
            .sorted { $0.start < $1.start }
    }

    func placeholder(in context: Context) -> TodayEntry {
        let now = Date()
        let sample = [
            WidgetSnapshot.Item(kind: "activity", title: "Morning run", start: now, durationMinutes: 30, done: false, detail: "Daily Routine · 30 min"),
            WidgetSnapshot.Item(kind: "task", title: "Send the report", start: now.addingTimeInterval(3600), durationMinutes: 0, done: false, detail: "To Do"),
            WidgetSnapshot.Item(kind: "monthly", title: "Internet", start: now.addingTimeInterval(7200), durationMinutes: 0, done: false, detail: "Monthly expense"),
        ]
        return TodayEntry(date: now, items: sample, hasData: true, confidence: 9)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        let snapshot = WidgetSnapshot.load()
        completion(TodayEntry(date: .now, items: Self.items(at: .now, from: snapshot), hasData: snapshot != nil,
                              confidence: snapshot?.confidence))
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
                       confidence: snapshot?.confidence)
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ForEach(Array(entry.items.prefix(maxRows).enumerated()), id: \.offset) { _, item in
                    row(item)
                }
                if entry.items.count > maxRows {
                    Text("+ \(entry.items.count - maxRows) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Today")
                    .font(.headline)
                Text(entry.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: compact ? 34 : 44, alignment: .leading)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(item.color)
                .frame(width: 3, height: compact ? 18 : 24)
            VStack(alignment: .leading, spacing: 0) {
                Text((item.done ? "✓ " : "") + item.title)
                    .font(compact ? .caption : .subheadline)
                    .strikethrough(item.done)
                    .foregroundStyle(item.done ? .secondary : .primary)
                    .lineLimit(1)
                if !compact {
                    Text(item.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Smiley background

/// A large, faint face behind the list, following the latest Confidence score:
/// 8–10 a big laughing smile, 5–7 a gentle smile, 0–4 (or no score) nothing.
struct ConfidenceFace: View {
    let score: Int?

    private enum Mood { case big, gentle }

    private var mood: Mood? {
        guard let score else { return nil }
        switch score {
        case 8...: return .big
        case 5...7: return .gentle
        default: return nil
        }
    }

    var body: some View {
        if let mood {
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height) * 0.85
                ZStack {
                    Circle()
                        .stroke(lineWidth: size * 0.05)
                    // Eyes
                    HStack(spacing: size * 0.26) {
                        Circle().frame(width: size * 0.1, height: size * 0.1)
                        Circle().frame(width: size * 0.1, height: size * 0.1)
                    }
                    .offset(y: -size * 0.12)
                    // Mouth
                    if mood == .big {
                        BigSmile()
                            .frame(width: size * 0.5, height: size * 0.26)
                            .offset(y: size * 0.17)
                    } else {
                        GentleSmile()
                            .stroke(style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round))
                            .frame(width: size * 0.44, height: size * 0.14)
                            .offset(y: size * 0.17)
                    }
                }
                .frame(width: size, height: size)
                .foregroundStyle(Color.yellow.opacity(0.28))
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .accessibilityHidden(true)
        }
    }

    /// Open, laughing mouth (a filled half circle)
    private struct BigSmile: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY),
                           control: CGPoint(x: rect.midX, y: rect.maxY * 2 - rect.minY))
            p.closeSubpath()
            return p
        }
    }

    /// A simple curved line
    private struct GentleSmile: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                           control: CGPoint(x: rect.midX, y: rect.maxY + rect.height))
            return p
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
                        Color(.systemBackground)
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

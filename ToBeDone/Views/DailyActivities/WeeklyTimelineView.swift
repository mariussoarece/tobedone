//
//  WeeklyTimelineView.swift
//  ToBeDone
//

import SwiftUI

struct WeeklyTimelineView: View {
    @State private var selectedItem: ActivityItem?

    let weekStart: Date
    let allActivities: [ActivityItem]

    private let hours = Array(0..<24)

    // One shared scale so hour labels, grid lines and activity boxes line up:
    // 60 points per hour = 1 point per minute.
    private let hourHeight: CGFloat = 60
    private let dayHeaderHeight: CGFloat = 20

    var body: some View {
        VStack(spacing: 12) {

            // WEEK NAVIGATION
            HStack {
                Button {
                    let cal = Calendar.current
                    let prev = cal.date(byAdding: .weekOfYear, value: -1, to: weekStart)!
                    NotificationCenter.default.post(name: .changeWeek, object: prev)
                } label: {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                Text(weekStart, format: .dateTime.year().month().day())
                    .font(.headline)

                Spacer()

                Button {
                    let cal = Calendar.current
                    let next = cal.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
                    NotificationCenter.default.post(name: .changeWeek, object: next)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal) {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        HStack(alignment: .top, spacing: 4) {

                            // HOURS COLUMN
                            VStack(alignment: .trailing, spacing: 0) {
                                // Same height as the weekday header above each day column
                                Color.clear.frame(height: dayHeaderHeight)
                                ForEach(hours, id: \.self) { hour in
                                    Text(String(format: "%02d:00", hour))
                                        .id(hour)   // ⭐ important
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .frame(height: hourHeight, alignment: .top)
                                }
                            }
                            .padding(.leading, 4)

                            // 7 DAY COLUMNS
                            ForEach(0..<7) { offset in
                                let day = Calendar.current.date(byAdding: .day, value: offset, to: weekStart)!
                                let dayItems = activitiesForDay(day)
                                dayColumn(day: day, items: dayItems)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .onAppear {
                        proxy.scrollTo(7, anchor: .top)   // ⭐ jump to 07:00
                    }
                }

            }
            .sheet(item: $selectedItem) { item in
                    VStack(spacing: 20) {
                        Text(item.name)
                            .font(.title2)
                            .bold()

                        Text("Starts at: \(item.date.formatted(date: .omitted, time: .shortened))")
                        Text("Duration: \(item.durationMinutes) minutes")

                        if !item.details.isEmpty {
                            Text(item.details)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .presentationDetents([.medium])
            }

        }
    }

    // MARK: - Helpers
    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                VStack(spacing: 0) {
                    // Thin line at the start of each hour
                    Rectangle()
                        .fill(Color.primary.opacity(0.2))   // visible in light and dark mode
                        .frame(height: 1)
                    Rectangle()
                        .fill(hour >= 7 && hour < 18
                              ? Color.gray.opacity(0.15)
                              : Color(.systemBackground))
                }
                .frame(height: hourHeight)
            }
        }
    }

    private func activitiesForDay(_ day: Date) -> [ActivityItem] {
        let cal = Calendar.current
        return allActivities.filter { cal.isDate($0.date, inSameDayAs: day) }
    }

    private func offsetFor(_ item: ActivityItem) -> CGFloat {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: item.date)
        let minute = cal.component(.minute, from: item.date)
        let totalMinutes = hour * 60 + minute

        return CGFloat(totalMinutes) * (hourHeight / 60)
    }

    private func heightFor(_ item: ActivityItem) -> CGFloat {
        // Same scale as the grid; a minimum so very short activities stay tappable
        max(CGFloat(item.durationMinutes), 20) * (hourHeight / 60)
    }

    private func colorFor(_ item: ActivityItem) -> Color {
        if item.isCompleted { return .green.opacity(0.3) }
        if item.durationMinutes > 60 { return .red.opacity(0.3) }
        return .gray.opacity(0.2)
    }
    private func columnOffset(for item: ActivityItem, in dayItems: [ActivityItem]) -> CGFloat {
        var index = 0

        for other in dayItems {
            if other.id == item.id { break }

            let startA = other.date
            let endA = other.date.addingTimeInterval(TimeInterval(other.durationMinutes * 60))

            let startB = item.date
            let endB = item.date.addingTimeInterval(TimeInterval(item.durationMinutes * 60))

            if startA < endB && startB < endA {
                index += 1
            }
        }

        return CGFloat(index) * 10
    }

    private func activityBox(item: ActivityItem, items: [ActivityItem]) -> some View {
        let offsetY = offsetFor(item)
        let height = heightFor(item)
        let offsetX = columnOffset(for: item, in: items)

        return Text(item.name)
            .font(.caption)
            .padding(4)
            .frame(maxWidth: .infinity)
            .background(Color.green.opacity(0.25))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.purple, lineWidth: 1)
            )
            .cornerRadius(6)
            .offset(x: offsetX, y: offsetY)
            .frame(height: height, alignment: .top)
    }

    private func dayColumn(day: Date, items: [ActivityItem]) -> some View {
        VStack(spacing: 0) {
            Text(day, format: .dateTime.weekday(.abbreviated).day())
                .font(.caption)
                .frame(height: dayHeaderHeight)

            ZStack(alignment: .top) {
                hourGrid
                renderOverlapping(items)
            }
        }
        .frame(width: 120)
    }

    private func overlappingGroups(for items: [ActivityItem]) -> [[ActivityItem]] {
        var groups: [[ActivityItem]] = []
        let sorted = items.sorted { $0.date < $1.date }

        for item in sorted {
            var placed = false
            for i in groups.indices {
                if groups[i].contains(where: { overlap($0, item) }) {
                    groups[i].append(item)
                    placed = true
                    break
                }
            }
            if !placed {
                groups.append([item])
            }
        }
        return groups
    }

    private func overlap(_ a: ActivityItem, _ b: ActivityItem) -> Bool {
        let startA = a.date
        let endA = a.date.addingTimeInterval(TimeInterval(a.durationMinutes * 60))
        let startB = b.date
        let endB = b.date.addingTimeInterval(TimeInterval(b.durationMinutes * 60))
        return startA < endB && startB < endA
    }
    private func renderOverlapping(_ items: [ActivityItem]) -> some View {
        let groups = overlappingGroups(for: items)

        return ForEach(groups.indices, id: \.self) { gIndex in
            let group = groups[gIndex]
            let count = group.count
            let widthFraction = 1.0 / CGFloat(count)
            let columnWidth: CGFloat = 120 * widthFraction

            ForEach(group.indices, id: \.self) { i in
                let item = group[i]
                let offsetY = offsetFor(item)
                let height = heightFor(item)

                // Size the box before coloring it, so its height matches the duration
                Text(item.name)
                    .font(.caption)
                    .padding(4)
                    .frame(width: columnWidth - 4, height: height, alignment: .topLeading)
                    .background(colorFor(item))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.purple, lineWidth: 1)
                    )
                    .cornerRadius(6)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedItem = item }
                    .offset(
                        x: (CGFloat(i) - CGFloat(count - 1) / 2) * columnWidth,
                        y: offsetY
                    )
            }
        }
    }

}

//
//  WeeklyTimelineView.swift
//  ToBeDone
//

import SwiftUI

struct WeeklyTimelineView: View {
    @State private var selectedItem: ActivityItem?
    @State private var showDetails = false

    let weekStart: Date
    let allActivities: [ActivityItem]

    private let hours = Array(0..<24)

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
                            VStack(alignment: .trailing, spacing: 20) {
                                ForEach(hours, id: \.self) { hour in
                                    Text(String(format: "%02d:00", hour))
                                        .id(hour)   // ⭐ important
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .frame(height: 40, alignment: .top)
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
            .sheet(isPresented: $showDetails) {
                if let item = selectedItem {
                    VStack(spacing: 20) {
                        Text(item.name)
                            .font(.title2)
                            .bold()

                        Text("Starts at: \(item.date.formatted(date: .omitted, time: .shortened))")
                        Text("Duration: \(item.durationMinutes) minutes")

                        Spacer()
                    }
                    .padding()
                }
            }

        }
    }

    // MARK: - Helpers
    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                Rectangle()
                    .fill(hour >= 7 && hour < 18
                          ? Color.gray.opacity(0.15)
                          : Color.white)

                // Thin line across the entire hour
                        Rectangle()
                            .fill(Color.black.opacity(0.25))
                            .frame(height: 1)
                            .offset(y: 0)
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

        return CGFloat(totalMinutes) //* (40.0 / 60.0)  // 40px per hour
    }

    private func heightFor(_ item: ActivityItem) -> CGFloat {
        CGFloat(item.durationMinutes) * (45.0 / 60.0)
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
            Text(day, format: .dateTime.weekday(.abbreviated))
                .font(.caption)
                .padding(.bottom, 4)

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

                Text(item.name)
                    .font(.caption)
                    .padding(4)
                    .frame(width: columnWidth - 4)
                    .background(Color.green.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.purple, lineWidth: 1)
                    )
                    .cornerRadius(6)
                    .offset(
                        x: (CGFloat(i) - CGFloat(count - 1) / 2) * columnWidth,
                        y: offsetY
                    )
                    .frame(height: height, alignment: .top)
            }
        }
    }

}

//
//  MonthCalendarGrid.swift
//  ToBeDone
//

import SwiftUI

// MARK: - Month Calendar Grid
struct MonthCalendarGrid: View {
    var month: Date
    @Binding var selectedDate: Date
    var scores: [Date: Int]        // day -> 0...10
    var onSelect: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(minimum: 24), spacing: 6), count: 7)

    var body: some View {
        let cal = Calendar.current
        let days = cal.daysForMonthGrid(containing: month)

        VStack(spacing: 4) {
            // Weekday headers
            HStack {
                ForEach(cal.veryShortWeekdaySymbolsIndexed(), id: \.0) { (_, sym) in
                    Text(sym.uppercased()).font(.caption2).frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(days, id: \.self) { day in
                    let cal = Calendar.current
                    let isCurrentMonth = cal.isDate(day, equalTo: month, toGranularity: .month)
                    let dayStart = cal.startOfDay(for: day)
                    let score = scores[dayStart]

                    let isToday = cal.isDateInToday(day)
                    let isSelected = dayStart == selectedDate

                    // Tints
                    let todayTint = Color.blue                // keep your blue today ring
                    let todayFill = todayTint.opacity(0.18)   // blue-ish background for today
                    let selectedFill = Color(uiColor: .systemGray4)   // ⚫️ stronger gray for selection
                    let selectedStroke = Color(uiColor: .systemGray)

                    Button {
                        selectedDate = dayStart
                        onSelect(dayStart)
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Text("\(cal.component(.day, from: day))")
                                .font(.callout.weight((isSelected || isToday) ? .semibold : .regular))
                                .frame(maxWidth: .infinity, minHeight: 6)
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(
                                            isSelected
                                            ? selectedFill                             // ← more gray when selected
                                            : (isToday ? todayFill
                                                       : Color(.secondarySystemBackground))
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            isToday ? todayTint                         // blue ring for today
                                                    : (isSelected ? selectedStroke      // gray ring for selected
                                                                  : .clear),
                                            lineWidth: isToday ? 2 : (isSelected ? 1.5 : 0)
                                        )
                                )
                                .foregroundStyle(
                                    isCurrentMonth ? .primary : .secondary
                                )

                            if let s = score {
                                Text("\(s)")
                                    .font(.caption2.weight(.semibold))
                                    .padding(4)
                                    .background(Capsule().fill(Color(.tertiarySystemFill)))
                                    .padding(4)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .animation(.snappy, value: selectedDate)   // smoother tap feedback
                }

            }
        }
    }
}

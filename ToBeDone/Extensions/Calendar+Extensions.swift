//
//  Calendar+Extensions.swift
//  ToBeDone
//

import SwiftUI

// MARK: - Calendar helpers
extension Calendar {
    func monthDateRange(containing anchor: Date) -> (start: Date, end: Date) {
            let start = startOfMonth(for: anchor)
            let startOfNextMonth = self.date(byAdding: .month, value: 1, to: start)!   // <- self.
            let end = self.date(byAdding: .second, value: -1, to: startOfNextMonth)!   // last second of month
            return (start, end)
        }

        func startOfMonth(for anchor: Date) -> Date {
            let comps = dateComponents([.year, .month], from: anchor)
            return self.date(from: comps)!
        }
    func daysForMonthGrid(containing date: Date) -> [Date] {
        // Build a 6-row grid (42 cells), including leading/trailing days
        var days: [Date] = []
        let start = startOfMonth(for: date)
        let weekday = component(.weekday, from: start) // 1..7
        // Days to step back to the first column. The "+ 7) % 7" keeps it from going
        // forward (which skipped the 1st when the month starts on a Sunday and weeks start on Monday).
        let leadingDays = (weekday - firstWeekday + 7) % 7
        let firstGridDay = self.date(byAdding: .day, value: -leadingDays, to: start) ?? start
        for i in 0..<42 { days.append(self.date(byAdding: .day, value: i, to: firstGridDay)!) }
        return days
    }
    func veryShortWeekdaySymbolsIndexed() -> [(Int, String)] {
        let syms = veryShortStandaloneWeekdaySymbols // locale-aware
        // rotate so that it starts at firstWeekday
        let start = firstWeekday - 1
        return (0..<7).map { i in ((i + start) % 7, syms[(i + start) % 7]) }
    }
    func startOfWeek(for date: Date) -> Date {
            let comps = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return self.date(from: comps)!
        }
}

//
//  ActivityItem.swift
//  ToBeDone
//

import SwiftUI
import SwiftData

@Model
final class ActivityItem {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date
    var seriesId: UUID?
    var repeatsWeekly: Bool = false
    var repeatWeeks: Int = 0        // ← persisted, simple

    var name: String
    var details: String
    var durationMinutes: Int
    var isCompleted: Bool = false

    init(
        date: Date = .now,
        name: String,
        details: String = "",
        durationMinutes: Int = 0,
        isCompleted: Bool = false,
        seriesId: UUID? = nil,
        repeatsWeekly: Bool = false,
        repeatWeeks: Int = 0
    ) {
        self.date = date
        self.seriesId = seriesId
        self.repeatsWeekly = repeatsWeekly
        self.repeatWeeks = repeatWeeks
        self.name = name
        self.details = details
        self.durationMinutes = durationMinutes
        self.isCompleted = isCompleted
    }
}

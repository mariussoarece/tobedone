//
//  ConfidenceEntry.swift
//  ToBeDone
//

import SwiftUI
import SwiftData

// MARK: - SwiftData Model
@Model
final class ConfidenceEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var score: Int // 1...10
    var note: String?
    var tags: [String] = []   // ← no @Attribute(.transformable)

    init(id: UUID = UUID(), date: Date = .now, score: Int, note: String? = nil, tags: [String] = []) {
        self.id = id
        self.date = date
        self.score = score
        self.note = note
        self.tags = tags
    }
}

// MARK: - Convenience Filters
extension ConfidenceEntry {
    static func lastNDaysPredicate(_ n: Int) -> Predicate<ConfidenceEntry> {
        let start = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -n+1, to: .now)!)
        return #Predicate<ConfidenceEntry> { $0.date >= start }
    }
}

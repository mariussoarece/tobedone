//
//  FocusResult.swift
//  ToBeDone
//

import SwiftUI
import SwiftData

@Model
class FocusResult {
    var date: Date
    var duration: Double

    init(date: Date, duration: Double) {
        self.date = date
        self.duration = duration
    }
}

extension FocusResult {
    /// Seconds, e.g. "42.3 s" (history, last result)
    static func format(_ seconds: Double) -> String {
        String(format: "%.1f s", seconds)
    }

    /// Best result as minutes:seconds, e.g. "1:23s" or "0:42s"
    static func formatBest(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02ds", total / 60, total % 60)
    }
}

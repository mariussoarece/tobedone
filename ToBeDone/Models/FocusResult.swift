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
    /// "42 s", or "8.4 s" for short times
    static func format(_ seconds: Double) -> String {
        seconds < 10 ? String(format: "%.1f s", seconds) : String(format: "%.0f s", seconds)
    }
}

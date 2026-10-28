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
    /// Minutes and seconds: "1 min 05 s", or "42 s" under a minute
    static func format(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let minutes = total / 60
        let secs = total % 60
        return minutes > 0
            ? String(format: "%d min %02d s", minutes, secs)
            : "\(secs) s"
    }
}

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

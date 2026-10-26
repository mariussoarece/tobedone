//
//  DateFormatter+Extensions.swift
//  ToBeDone
//

import SwiftUI

// MARK: - Date Formatter
extension DateFormatter {
    static var shortDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }
}

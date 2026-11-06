//
//  String+Decimal.swift
//  ToBeDone
//

import Foundation

extension String {
    /// Parses a price typed by the user. Accepts both "2.50" and "2,50",
    /// because the decimal keyboard shows a comma in many regions (e.g. Romania).
    var decimalValue: Double? {
        let cleaned = trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
    }
}

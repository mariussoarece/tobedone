//
//  FocusPerformanceGraphView.swift
//  ToBeDone
//

import SwiftUI
import SwiftData
import Charts

struct FocusPerformanceGraphView: View {
    @Query(sort: \FocusResult.date)
    private var results: [FocusResult]

    var body: some View {
        VStack {
            Text("Focus Performance")
                .font(.title.bold())

            Chart(results) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Duration", item.duration)
                )
                .foregroundStyle(.blue)
            }
            .frame(height: 300)

            Spacer()
        }
        .padding()
    }
}

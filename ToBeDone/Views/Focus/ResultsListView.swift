//
//  ResultsListView.swift
//  ToBeDone
//

import SwiftUI
import SwiftData

struct ResultsListView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FocusResult.date) private var results: [FocusResult]

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(results.enumerated()), id: \.offset) { index, item in
                    VStack(alignment: .leading) {
                        Text("Test #\(index + 1)")
                            .font(.headline)

                        Text("Date: \(item.date.formatted(date: .numeric, time: .shortened))")
                        Text("Duration: \(String(format: "%.2f s", item.duration))")
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Past Results")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Go Back") { dismiss() }
                }
            }
        }
    }
}

//
//  FocusTestView.swift
//  ToBeDone
//
//  Opened from "Focus Test" on the home screen: best result, start button and history.
//

import SwiftUI
import SwiftData
import Charts

struct FocusTestView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FocusResult.date, order: .reverse) private var results: [FocusResult]
    @State private var startTest = false
    @State private var showInstructions = false

    private var best: Double? { results.map(\.duration).max() }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
        // Same title style as the other screens, in red like "Shopping Tasks"
        Text("Focus Test")
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundColor(.red)
            .padding(.horizontal)
            .padding(.top)

        List {
            // Summary + start
            Section {
                HStack(spacing: 0) {
                    stat("Best", best.map(FocusResult.formatBest) ?? "–")
                    Divider()
                    stat("Last", results.first.map { FocusResult.format($0.duration) } ?? "–")
                    Divider()
                    stat("Tests", "\(results.count)")
                }
                .padding(.vertical, 4)

                Button {
                    startTest = true
                } label: {
                    Text("Start Test")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Button("How the test works") { showInstructions = true }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }

            // Progress chart once there are at least two results
            if results.count >= 2 {
                Section("Progress") {
                    Chart(Array(results.reversed())) { item in
                        LineMark(x: .value("Date", item.date), y: .value("Seconds", item.duration))
                        PointMark(x: .value("Date", item.date), y: .value("Seconds", item.duration))
                    }
                    .frame(height: 160)
                }
            }

            // History
            Section {
                if results.isEmpty {
                    Text("No results yet. Start your first test above.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(results) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.date.formatted(date: .abbreviated, time: .omitted))
                                Text(item.date.formatted(date: .omitted, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if item.duration == best {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                    .accessibilityLabel("Best result")
                            }
                            Text(FocusResult.format(item.duration))
                                .font(.body.monospacedDigit().weight(.semibold))
                        }
                    }
                    .onDelete { offsets in
                        for i in offsets { modelContext.delete(results[i]) }
                        try? modelContext.save()
                    }
                }
            } header: {
                Text("History")
            } footer: {
                if !results.isEmpty { Text("Swipe left on a result to delete it.") }
            }
        }
        .listStyle(.insetGrouped)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $startTest) {
            RedDotFocusTestView(shouldReturnToHome: false, onFinish: nil)
        }
        .sheet(isPresented: $showInstructions) {
            ScrollView { FocusInstructionsText().padding() }
                .presentationDetents([.medium, .large])
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.weight(.bold).monospacedDigit())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// The explanation text, shared with the first-launch explanation screen.
struct FocusInstructionsText: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How the test works")
                .font(.title2.bold())
            Text("""
Look at the red dot without blinking and without moving your eyes as much as you can.

When you blink, tap the screen. The time is recorded so you can compare it with future tests.

Come back in a week and test again to see how your attention span improves.
""")
        }
    }
}

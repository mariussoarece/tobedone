//
//  FocusTestStartView.swift
//  ToBeDone
//

import SwiftUI
import SwiftData

struct FocusTestStartView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var startTest = false
    @State private var showResults = false
    @State private var openResultsAfterTest = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Focus Test")
                .font(.largeTitle.bold())

            Button("Start Test") {
                startTest = true
            }
            .buttonStyle(.borderedProminent)

        }
        .padding()
        .fullScreenCover(isPresented: $startTest, onDismiss: {
            if openResultsAfterTest {
                openResultsAfterTest = false
                showResults = true
            }
        }) {
            RedDotFocusTestView(shouldReturnToHome: false, onFinish: { openResultsAfterTest = true })
        }
        .fullScreenCover(isPresented: $showResults) {
                    ResultsListView()
                }
    }
}

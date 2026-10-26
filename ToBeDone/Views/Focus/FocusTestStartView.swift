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

    var body: some View {
        VStack(spacing: 24) {
            Text("Focus Test")
                .font(.largeTitle.bold())
            .pickerStyle(.segmented)

            Button("Start Test") {
                startTest = true
            }
            .buttonStyle(.borderedProminent)

        }
        .padding()
        .fullScreenCover(isPresented: $startTest) {
            RedDotFocusTestView(shouldReturnToHome: false, onFinish: { showResults = true }  )
        }
        .fullScreenCover(isPresented: $showResults) {
                    ResultsListView()
                }
    }
}

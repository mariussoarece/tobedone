//
//  RedDotFocusTestView.swift
//  ToBeDone
//

import SwiftUI
import SwiftData

struct RedDotFocusTestView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var timerValue: Double = 0
    @State private var startDate = Date()
    @State private var timer: Timer?
    @State private var finished = false

    let shouldReturnToHome: Bool
    let onFinish: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // ZStack centers the dot on every screen size
            Circle()
                .fill(.red)
                .frame(width: 150, height: 150)

            VStack {
                // Live timer in seconds only, e.g. 83.42 s
                Text(String(format: "%.2f s", timerValue))
                    .monospacedDigit()
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding()
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
        .onTapGesture { finishTest() }
    }

    private func startTimer() {
        timerValue = 0
        startDate = Date()
        timer?.invalidate()
        // Measure real elapsed time; adding 0.01 per tick drifts because ticks get skipped
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            timerValue = Date().timeIntervalSince(startDate)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    @AppStorage("hasSeenIntroPage") private var hasSeenIntroPage: Bool = false

    private func finishTest() {
        guard !finished else { return }   // ignore extra taps while closing
        finished = true
        stopTimer()
        timerValue = Date().timeIntervalSince(startDate)

        let result = FocusResult(date: Date(), duration: timerValue)
        modelContext.insert(result)
        try? modelContext.save()

        hasSeenIntroPage = true

        onFinish?()
        dismiss()
    }
}

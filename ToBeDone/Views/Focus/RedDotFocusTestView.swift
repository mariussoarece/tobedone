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
    @State private var timer: Timer?

    let shouldReturnToHome: Bool
    let onFinish: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Circle()
                .fill(.red)
                .frame(width: 150, height: 150)
                .position(
                    x: UIScreen.main.bounds.width / 2,
                    y: UIScreen.main.bounds.height / 2
                )

            VStack {
                Text(String(format: "%.2f s", timerValue))
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding()
                Spacer()
            }
        }
        .onAppear { startTimer() }
        .onTapGesture { finishTest() }
    }

    private func startTimer() {
        timerValue = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            timerValue += 0.01
        }
    }
    @AppStorage("hasSeenIntroPage") private var hasSeenIntroPage: Bool = false

    private func finishTest() {
        timer?.invalidate()
        timer = nil

        let result = FocusResult(date: Date(), duration: timerValue)
        modelContext.insert(result)
        try? modelContext.save()

        hasSeenIntroPage = true

        if shouldReturnToHome {
            dismiss()   // return to HomeView
        } else {
            dismiss()               // Home → Test → Home
            onFinish?()
        }
    }
}

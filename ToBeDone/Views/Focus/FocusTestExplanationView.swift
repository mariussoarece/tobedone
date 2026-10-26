//
//  FocusTestExplanationView.swift
//  ToBeDone
//

import SwiftUI

struct FocusTestExplanationView: View {
    @State private var startTest = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Focus Test Instructions")
                .font(.largeTitle.bold())
                .padding(.top)

            Text("""
Look at the red dot without blinking and without moving your eyes as much as you can.

When you blink, tap the screen. The time will be recorded and you can compare it with your future tests.

Come again in a week and retest your attention span. After 1 week of using this app, you will see improvements in your focus.

Maintaining gaze on a fixed point improves:
• continuous micro‑attention (microsaccades)
• suppression of reflexive eye movements
• resistance to boredom
• mental stability

When your mind wanders, your eyes drift.
When you’re tired, your microsaccades increase.
When you’re stressed, fixation becomes unstable.
""")
            .font(.body)
            .multilineTextAlignment(.leading)
            .padding(.horizontal)

            Button("Start Test") {
                startTest = true
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .fullScreenCover(isPresented: $startTest) {
            RedDotFocusTestView(shouldReturnToHome: true, onFinish: nil  )
        }
    }
}

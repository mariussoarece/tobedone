//
//  Toast.swift
//  ToBeDone
//
//  A short confirmation ("Task added") that appears in the middle of the screen
//  for 1 second. Call `Toast.show("Task added")` from anywhere; the message is
//  drawn once, at the top of the app (see ToBeDoneApp), so it also works from
//  screens that use KeyboardDismissWrapper.
//

import SwiftUI
import Observation

@Observable
final class Toast {
    static let shared = Toast()

    private(set) var message: String?
    /// nil = the usual light bubble; a colour = coloured bubble with white text
    private(set) var tint: Color?
    @ObservationIgnored private var showCount = 0

    /// Shows `message` for 1 second, optionally in a colour (e.g. blue on To Do).
    static func show(_ message: String, color: Color? = nil) {
        shared.show(message, color: color)
    }

    private func show(_ text: String, color: Color?) {
        showCount += 1
        let current = showCount
        withAnimation(.easeOut(duration: 0.15)) {
            message = text
            tint = color
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            // A newer message keeps its own full second
            guard let self, self.showCount == current else { return }
            withAnimation(.easeIn(duration: 0.2)) { self.message = nil }
        }
    }
}

/// The confirmation bubble. Added once over the whole app.
struct ToastOverlay: View {
    var body: some View {
        if let message = Toast.shared.message {
            let tint = Toast.shared.tint
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(tint == nil ? Color.primary : Color.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background {
                    if let tint {
                        Capsule().fill(tint)
                    } else {
                        Capsule().fill(.regularMaterial)
                    }
                }
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
                .allowsHitTesting(false)
                .accessibilityAddTraits(.isStaticText)
        }
    }
}

//
//  FirstTimeTip.swift
//  ToBeDone
//
//  A short tip shown the first time a screen is opened (only once).
//

import SwiftUI

private struct FirstTimeTip: ViewModifier {
    let key: String
    let title: String
    let message: String

    @State private var show = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !DemoData.isEnabled else { return }   // not in the App Store screenshots
                if !UserDefaults.standard.bool(forKey: key) {
                    UserDefaults.standard.set(true, forKey: key)
                    // A moment after the screen slides in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { show = true }
                }
            }
            .alert(title, isPresented: $show) {
                Button("Got it", role: .cancel) {}
            } message: {
                Text(message)
            }
    }
}

extension View {
    /// Shows `message` once, the first time this screen appears.
    func firstTimeTip(_ key: String, title: String, message: String) -> some View {
        modifier(FirstTimeTip(key: "tipShown." + key, title: title, message: message))
    }
}

//
//  KeyboardDismissWrapper.swift
//  ToBeDone
//

import SwiftUI

/// A wrapper that allows dismissing the keyboard when tapping anywhere outside.
struct KeyboardDismissWrapper<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        RepresentableWrapper(content: content)
    }

    private struct RepresentableWrapper: UIViewControllerRepresentable {
        let content: Content

        func makeUIViewController(context: Context) -> UIViewController {
            let controller = UIHostingController(rootView: content)
            let tapGesture = UITapGestureRecognizer(target: controller.view, action: #selector(UIView.endEditing))
            tapGesture.cancelsTouchesInView = false
            controller.view.addGestureRecognizer(tapGesture)
            return controller
        }

        func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
            (uiViewController as? UIHostingController<Content>)?.rootView = content
        }
    }
}

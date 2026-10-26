//
//  KeyboardDismissWrapper.swift
//  ToBeDone
//

import SwiftUI
import SwiftData

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

        // The content lives in its own hosting controller, which does not inherit
        // SwiftUI's environment. Pass the database context through explicitly so
        // views inside (e.g. subtask checkboxes) save to the app's real database.
        private func rootView(_ context: Context) -> AnyView {
            AnyView(content.environment(\.modelContext, context.environment.modelContext))
        }

        func makeUIViewController(context: Context) -> UIViewController {
            let controller = UIHostingController(rootView: rootView(context))
            let tapGesture = UITapGestureRecognizer(target: controller.view, action: #selector(UIView.endEditing))
            tapGesture.cancelsTouchesInView = false
            controller.view.addGestureRecognizer(tapGesture)
            return controller
        }

        func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
            (uiViewController as? UIHostingController<AnyView>)?.rootView = rootView(context)
        }
    }
}

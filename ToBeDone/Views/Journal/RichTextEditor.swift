//
//  RichTextEditor.swift
//  ToBeDone
//
//  A text box that keeps formatting: bold, italic, underline and colours.
//  SwiftUI's TextEditor only does this from iOS 26, so this wraps UIKit's
//  UITextView (works on iOS 18). The buttons above it talk to the text box
//  through RichTextController.
//

import SwiftUI
import UIKit
import Observation

// MARK: - Controller (used by the B / I / U / colour buttons)

@Observable
final class RichTextController {
    @ObservationIgnored weak var textView: UITextView?

    /// Shown as "on" on the buttons, for the text at the cursor
    private(set) var isBold = false
    private(set) var isItalic = false
    private(set) var isUnderlined = false

    static var baseFont: UIFont { UIFont.preferredFont(forTextStyle: .body) }

    func toggleBold() { toggle(.traitBold) }
    func toggleItalic() { toggle(.traitItalic) }

    func toggleUnderline() {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        if range.length > 0 {
            var allUnderlined = true
            tv.textStorage.enumerateAttribute(.underlineStyle, in: range) { value, _, _ in
                if (value as? Int ?? 0) == 0 { allUnderlined = false }
            }
            tv.textStorage.beginEditing()
            if allUnderlined {
                tv.textStorage.removeAttribute(.underlineStyle, range: range)
            } else {
                tv.textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
            tv.textStorage.endEditing()
            changed(tv, keeping: range)
        } else {
            var attrs = tv.typingAttributes
            let on = (attrs[.underlineStyle] as? Int ?? 0) == 0
            if on {
                attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            } else {
                attrs.removeValue(forKey: .underlineStyle)
            }
            tv.typingAttributes = attrs
        }
        refreshState()
    }

    /// `nil` = the normal text colour (black in light mode, white in dark mode)
    func setColor(_ color: UIColor?) {
        guard let tv = textView else { return }
        let value = color ?? UIColor.label
        let range = tv.selectedRange
        if range.length > 0 {
            tv.textStorage.addAttribute(.foregroundColor, value: value, range: range)
            changed(tv, keeping: range)
        } else {
            tv.typingAttributes[.foregroundColor] = value
        }
    }

    private func toggle(_ trait: UIFontDescriptor.SymbolicTraits) {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        if range.length > 0 {
            var allHave = true
            tv.textStorage.enumerateAttribute(.font, in: range) { value, _, _ in
                let font = value as? UIFont ?? Self.baseFont
                if !font.fontDescriptor.symbolicTraits.contains(trait) { allHave = false }
            }
            tv.textStorage.beginEditing()
            tv.textStorage.enumerateAttribute(.font, in: range) { value, subrange, _ in
                let font = value as? UIFont ?? Self.baseFont
                tv.textStorage.addAttribute(.font, value: font.with(trait, on: !allHave), range: subrange)
            }
            tv.textStorage.endEditing()
            changed(tv, keeping: range)
        } else {
            let font = tv.typingAttributes[.font] as? UIFont ?? Self.baseFont
            let on = !font.fontDescriptor.symbolicTraits.contains(trait)
            tv.typingAttributes[.font] = font.with(trait, on: on)
        }
        refreshState()
    }

    /// Tells SwiftUI about the change and keeps the same text selected.
    private func changed(_ tv: UITextView, keeping range: NSRange) {
        tv.selectedRange = range
        tv.delegate?.textViewDidChange?(tv)
    }

    /// Updates the button states from the text at the cursor.
    func refreshState() {
        guard let tv = textView else { return }
        var attrs = tv.typingAttributes
        let range = tv.selectedRange
        if range.length > 0, range.location < tv.textStorage.length {
            attrs = tv.textStorage.attributes(at: range.location, effectiveRange: nil)
        }
        let traits = (attrs[.font] as? UIFont ?? Self.baseFont).fontDescriptor.symbolicTraits
        isBold = traits.contains(.traitBold)
        isItalic = traits.contains(.traitItalic)
        isUnderlined = (attrs[.underlineStyle] as? Int ?? 0) != 0
    }
}

extension UIFont {
    /// The same font with a trait (bold, italic) turned on or off.
    func with(_ trait: UIFontDescriptor.SymbolicTraits, on: Bool) -> UIFont {
        var traits = fontDescriptor.symbolicTraits
        if on { traits.insert(trait) } else { traits.remove(trait) }
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

// MARK: - Text box

struct RichTextEditor: UIViewRepresentable {
    @Binding var text: NSAttributedString
    let controller: RichTextController

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.allowsEditingTextAttributes = true   // also adds B / I / U to the text menu
        tv.adjustsFontForContentSizeCategory = true
        tv.textContainerInset = UIEdgeInsets(top: 10, left: 6, bottom: 10, right: 6)
        tv.attributedText = text
        tv.typingAttributes = [.font: RichTextController.baseFont, .foregroundColor: UIColor.label]
        controller.textView = tv
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        context.coordinator.parent = self
        // Only when the text was replaced from outside (e.g. loading an entry),
        // so typing doesn't move the cursor
        if !tv.attributedText.isEqual(to: text) {
            tv.attributedText = text
        }
        controller.textView = tv
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        init(_ parent: RichTextEditor) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = NSAttributedString(attributedString: textView.attributedText)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.controller.refreshState()
        }
    }
}

// MARK: - Saving and loading

enum JournalText {
    /// Formatted text → RTF data. The normal text colour is left out, so the
    /// text is black in light mode and white in dark mode when it's opened again.
    static func rtf(from text: NSAttributedString) -> Data? {
        let copy = NSMutableAttributedString(attributedString: text)
        let whole = NSRange(location: 0, length: copy.length)
        copy.enumerateAttribute(.foregroundColor, in: whole) { value, range, _ in
            if let color = value as? UIColor, isNormalTextColor(color) {
                copy.removeAttribute(.foregroundColor, range: range)
            }
        }
        return try? copy.data(from: whole, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }

    /// RTF data → formatted text, using the system font in the user's text size.
    static func attributed(from data: Data?) -> NSAttributedString {
        guard let data,
              let loaded = try? NSMutableAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil)
        else { return NSAttributedString() }

        let whole = NSRange(location: 0, length: loaded.length)
        let base = RichTextController.baseFont
        // Keep bold / italic, but always with the system font (RTF can't store it)
        loaded.enumerateAttribute(.font, in: whole) { value, range, _ in
            let traits = (value as? UIFont)?.fontDescriptor.symbolicTraits ?? []
            var font = base
            if traits.contains(.traitBold) { font = font.with(.traitBold, on: true) }
            if traits.contains(.traitItalic) { font = font.with(.traitItalic, on: true) }
            loaded.addAttribute(.font, value: font, range: range)
        }
        // Text without a chosen colour follows light / dark mode
        loaded.enumerateAttribute(.foregroundColor, in: whole) { value, range, _ in
            if value == nil { loaded.addAttribute(.foregroundColor, value: UIColor.label, range: range) }
        }
        return loaded
    }

    private static func isNormalTextColor(_ color: UIColor) -> Bool {
        if color == UIColor.label { return true }
        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        return color.resolvedColor(with: light) == UIColor.label.resolvedColor(with: light)
            && color.resolvedColor(with: dark) == UIColor.label.resolvedColor(with: dark)
    }
}

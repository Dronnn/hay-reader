import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct TextEditorView: NSViewRepresentable {
    @Bindable var model: PlayerViewModel
    func makeCoordinator() -> Coordinator { Coordinator(model: model) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        guard let text = scroll.documentView as? NSTextView else { return scroll }
        text.isRichText = false
        text.allowsUndo = true
        text.font = .systemFont(ofSize: 24)
        text.textContainerInset = NSSize(width: 20, height: 20)
        text.delegate = context.coordinator
        text.setAccessibilityIdentifier("armenianEditor")
        text.isAutomaticQuoteSubstitutionEnabled = false
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let text = scroll.documentView as? NSTextView else { return }
        if text.string != model.text {
            let range = NSRange(location: 0, length: (text.string as NSString).length)
            if text.shouldChangeText(in: range, replacementString: model.text) {
                text.replaceCharacters(in: range, with: model.text)
                text.didChangeText()
            }
            text.setSelectedRange(NSRange(location: 0, length: 0))
        }
        if let window = scroll.window { window.setFrameAutosaveName("MainWindow") }
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        let model: PlayerViewModel
        init(model: PlayerViewModel) { self.model = model }
        func textDidChange(_ notification: Notification) {
            guard let text = notification.object as? NSTextView else { return }
            model.text = text.string
        }
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let text = notification.object as? NSTextView else { return }
            model.selection = text.selectedRange()
        }
    }
}

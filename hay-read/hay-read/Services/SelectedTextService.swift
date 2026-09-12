import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = PlayerViewModel()
    private var spaceMonitor: Any?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        spaceMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 49, event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty,
                  !(NSApp.keyWindow?.firstResponder is NSTextView),
                  let self, self.model.playing || self.model.paused else { return event }
            self.model.togglePause()
            return nil
        }
    }
    func applicationWillTerminate(_ notification: Notification) {
        if let spaceMonitor { NSEvent.removeMonitor(spaceMonitor) }
        model.stop()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { show(); return true }
    func show() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.identifier?.rawValue == "main" || $0.title == "Armenian Speaker" }?.makeKeyAndOrderFront(nil)
    }
    @objc func speakArmenian(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pasteboard.string(forType: .string), (try? SpeechInput.validate(text)) != nil else {
            error.pointee = "No selected text was received."; return
        }
        show()
        model.receive(text, autoPlay: model.settings.autoPlay)
    }
}

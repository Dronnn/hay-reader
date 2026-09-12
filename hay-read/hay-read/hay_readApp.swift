import SwiftUI

@main
struct hay_readApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        Window("Armenian Speaker", id: "main") { ContentView(model: delegate.model) }
            .defaultSize(width: 780, height: 520)
            .commands {
                CommandMenu("Speech") {
                    Button("Play") { delegate.model.play() }.keyboardShortcut(.return, modifiers: .command)
                    Button("Pause / Resume") { delegate.model.togglePause() }
                    Button("Stop") { delegate.model.stop() }.keyboardShortcut(".", modifiers: .command)
                    Button("Clear") { delegate.model.replaceText("") }.keyboardShortcut("k", modifiers: .command)
                    Button("Speak Clipboard") { delegate.show(); delegate.model.clipboard() }
                }
            }
        Settings { SettingsView(model: delegate.model) }
        MenuBarExtra("Armenian Speaker", systemImage: "speaker.wave.2") {
            Button("Show Armenian Speaker") { delegate.show() }
            Button("Speak Clipboard") { delegate.show(); delegate.model.clipboard() }
            Button(delegate.model.paused ? "Resume" : "Pause") { delegate.model.togglePause() }
                .disabled(!delegate.model.paused && !delegate.model.playing)
            Button("Stop") { delegate.model.stop() }
            Divider()
            SettingsLink()
            Button("Quit") { NSApp.terminate(nil) }
        }
    }
}

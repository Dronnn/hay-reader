import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var model: PlayerViewModel
    @State private var showHistory = false
    @AppStorage("showTranslation") private var showTranslation = true
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                TextEditorView(model: model)
                if showHistory {
                    Divider()
                    List(model.history.phrases, id: \.self) { phrase in
                        Button { model.replaceText(phrase) } label: {
                            Text(phrase).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain)
                    }.frame(width: 210)
                }
            }
            if showTranslation { Divider(); TranslationPanel(model: model, translation: model.translation) }
            Divider()
            HStack(spacing: 16) {
                Button { model.play() } label: { Image(systemName: "play.fill") }.help("Play (⌘Return)").accessibilityLabel("Play")
                Button { model.togglePause() } label: { Image(systemName: model.paused ? "playpause.fill" : "pause.fill") }
                    .disabled(!model.playing && !model.paused).accessibilityLabel(model.paused ? "Resume" : "Pause")
                Button { model.stop() } label: { Image(systemName: "stop.fill") }.accessibilityLabel("Stop")
                Text("Speed")
                Slider(value: $model.speed, in: 0.1...2, step: 0.1).frame(minWidth: 100).accessibilityLabel("Speed")
                Menu(String(format: "%.1f×", model.speed)) {
                    ForEach((1...20).map { Double($0) / 10 }, id: \.self) { speed in
                        Button(String(format: "%.1f×", speed)) { model.speed = speed }
                    }
                }.frame(width: 70)
                if model.generating { ProgressView().controlSize(.small) }
            }.padding(14)
            HStack { Text(model.status); Spacer(); Text("Gor · Armenian") }
                .font(.caption).foregroundStyle(.secondary).padding([.horizontal, .bottom], 14)
        }
        .frame(minWidth: 620, minHeight: 360)
        .toolbar {
            Button("Clear", systemImage: "trash") { model.replaceText("") }
            Button(showTranslation ? "Hide Translation" : "Show Translation", systemImage: "character.bubble") { showTranslation.toggle() }
            Button("History", systemImage: "clock") { showHistory.toggle() }
        }
        .alert("Unable to Speak", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first, url.pathExtension.lowercased() == "txt" else { return false }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do { model.replaceText(try String(contentsOf: url, encoding: .utf8)); return true }
            catch { model.error = "This file could not be opened as UTF-8 text."; return false }
        }
    }
}

struct SettingsView: View {
    @Bindable var model: PlayerViewModel
    var body: some View {
        @Bindable var settings = model.settings
        return Form {
            LabeledContent("Voice", value: "Gor — Armenian")
            HStack {
                Text("Default speed")
                Slider(value: $settings.defaultSpeed, in: 0.1...2, step: 0.1)
                Text(String(format: "%.1f×", model.settings.defaultSpeed)).monospacedDigit()
            }
            Toggle("Keep phrase history", isOn: $settings.keepHistory)
                .onChange(of: model.settings.keepHistory) { _, enabled in if !enabled { model.history.clear() } }
            Button("Clear History") { model.history.clear() }
            Picker("Audio cache", selection: $settings.cacheMegabytes) {
                ForEach([10, 50, 100, 250], id: \.self) { Text("\($0) MB").tag($0) }
            }
            Toggle("Automatically play text received from Services", isOn: $settings.autoPlay)
            Button("Open Licenses") {
                if let url = Bundle.main.resourceURL?.appendingPathComponent("Licenses") { NSWorkspace.shared.open(url) }
            }
            Text("Speech synthesis is performed entirely on this Mac.").font(.footnote).foregroundStyle(.secondary)
        }.padding(24).frame(width: 480)
    }
}

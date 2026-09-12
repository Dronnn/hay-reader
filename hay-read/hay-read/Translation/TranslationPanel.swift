import SwiftUI

struct TranslationPanel: View {
    @Bindable var model: PlayerViewModel
    @State private var translation = TranslationViewModel()
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("Translation", selection: $translation.direction) {
                    ForEach(TranslationDirection.allCases) { Text($0.label).tag($0) }
                }.labelsHidden().frame(width: 200)
                Button("Translate") { translation.translate(model.selectedText) }
                if translation.busy {
                    ProgressView().controlSize(.small)
                    Button("Cancel") { translation.reset() }
                }
                Spacer()
                if !translation.result.isEmpty {
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(translation.result, forType: .string)
                    }
                    Button("Use Text") { model.replaceText(translation.result) }
                }
            }
            if let error = translation.error { Text(error).foregroundStyle(.red).font(.callout) }
            if !translation.result.isEmpty {
                ScrollView { Text(translation.result).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                    .frame(maxHeight: 130)
            }
            Text("Local machine translation · May contain mistakes").font(.caption).foregroundStyle(.secondary)
        }.padding(14)
        .onChange(of: model.text) { _, text in translation.translate(text, delay: true) }
        .onChange(of: translation.direction) { _, _ in translation.translate(model.text) }
        .onAppear { translation.translate(model.text, delay: true) }
        .onDisappear { translation.reset() }
    }
}

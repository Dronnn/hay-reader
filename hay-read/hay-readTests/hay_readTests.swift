import Foundation
import Testing
import AVFoundation
@testable import hay_read

struct SpeechTests {
    @Test func speedConversion() {
        #expect(SpeechInput.lengthScale(speed: 0.1) == 10)
        #expect(SpeechInput.lengthScale(speed: 2) == 0.5)
        #expect(SpeechInput.lengthScale(speed: 0.5) == 2)
        #expect(abs(SpeechInput.lengthScale(speed: 0.7) - 1.4285714) < 0.0001)
        #expect(SpeechInput.lengthScale(speed: 1) == 1)
        #expect(SpeechInput.lengthScale(speed: .nan) == 1)
    }
    @Test func cacheKeys() {
        let key = AudioCache.key(text: "բարև", voice: "gor", speed: 1)
        #expect(key == AudioCache.key(text: "բարև", voice: "gor", speed: 1))
        #expect(key != AudioCache.key(text: "բարև", voice: "gor", speed: 0.5))
        #expect(key != AudioCache.key(text: "արի գնանք", voice: "gor", speed: 1))
        #expect(key != AudioCache.key(text: "բարև", voice: "other", speed: 1))
    }
    @Test func unicodeAndEmpty() throws {
        for phrase in ["բարև", "արի գնանք", "արի խոսենք", "ես սովորում եմ հայերեն", "այս գիրքը շատ լավ է"] {
            #expect(try SpeechInput.validate(phrase) == phrase)
        }
        #expect(throws: SpeechError.self) { try SpeechInput.validate(" \n\t") }
    }
    @Test func modelValidation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = ModelManager(directory: directory)
        #expect(throws: SpeechError.self) { try manager.model() }
        let model = directory.appendingPathComponent(ModelManager.voice + ".onnx")
        try Data([1]).write(to: model)
        #expect(throws: SpeechError.self) { try manager.model() }
        try Data("{}".utf8).write(to: model.appendingPathExtension("json"))
        #expect(try manager.model() == model)
    }
    @MainActor @Test func historyLimitAndDeduplication() throws {
        let name = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = HistoryStore(defaults: defaults)
        for i in 0..<25 { store.add("բարև \(i)") }
        store.add("բարև 20")
        #expect(store.phrases.count == 20)
        #expect(store.phrases.first == "բարև 20")
        #expect(HistoryStore(defaults: defaults).phrases == store.phrases)
        store.clear()
        #expect(HistoryStore(defaults: defaults).phrases.isEmpty)
    }
    @MainActor @Test func automaticTranslationUsesLatestInput() async throws {
        let model = TranslationViewModel()
        model.translate("Ես սիրում եմ քեզ։", delay: true)
        #expect(!model.busy)
        model.translate("", delay: true)
        try await Task.sleep(for: .milliseconds(700))
        #expect(model.result.isEmpty)
        model.translate("Ես սիրում եմ քեզ։", delay: true)
        model.translate("Այս գիրքը շատ լավ է։", delay: true)
        for _ in 0..<150 where model.result.isEmpty && model.error == nil {
            try await Task.sleep(for: .milliseconds(40))
        }
        #expect(model.result.lowercased().contains("книга"))
        #expect(model.error == nil)
    }
    @Test func translationBothDirections() async throws {
        let service = TranslationService()
        let russian = try await service.translate("Ես սիրում եմ քեզ։", direction: .armenianToRussian)
        #expect(russian.lowercased().contains("люблю"))
        let armenian = try await service.translate("Привет.", direction: .russianToArmenian)
        #expect(armenian.unicodeScalars.contains { (0x0530...0x058F).contains($0.value) })
        let repeated = try await service.translate("Ես սիրում եմ քեզ։", direction: .armenianToRussian)
        #expect(repeated == russian)
    }
    @Test func actualArmenianSynthesisAndCache() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = PiperTTSService(cacheDirectory: directory)
        var durations: [Double] = []
        for speed in [1.0, 0.7, 0.5] {
            let result = try await service.synthesize(text: "արի գնանք", speed: speed, cacheMegabytes: 100)
            let file = try AVAudioFile(forReading: result.url)
            let duration = Double(file.length) / file.processingFormat.sampleRate
            #expect(duration > 0.1)
            durations.append(duration)
            let cached = try await service.synthesize(text: "արի գնանք", speed: speed, cacheMegabytes: 100)
            #expect(cached.cached)
            #expect(cached.url == result.url)
        }
        #expect(durations[1] > durations[0])
        #expect(durations[2] > durations[1])
        for phrase in ["մի", "բարև", "Ես սովորում եմ հայերեն։ Այս գիրքը շատ լավ է, և ես ուզում եմ այն կարդալ ամեն օր։"] {
            let result = try await service.synthesize(text: phrase, speed: 1, cacheMegabytes: 100)
            #expect(try AVAudioFile(forReading: result.url).length > 0)
        }
    }
}

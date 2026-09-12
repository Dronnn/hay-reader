import Foundation
import Observation

enum TranslationDirection: String, CaseIterable, Identifiable, Sendable {
    case armenianToRussian = "hy-ru", russianToArmenian = "ru-hy"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .armenianToRussian: "Armenian to Russian"
        case .russianToArmenian: "Russian to Armenian"
        }
    }
}

enum TranslationError: LocalizedError {
    case unavailable, tooLong, failed
    var errorDescription: String? {
        switch self {
        case .unavailable: "The translation model is unavailable. Rebuild or reinstall the app."
        case .tooLong: "Translate a shorter passage (up to about 450 word pieces) or select part of the text."
        case .failed: "This text could not be translated. Try a shorter sentence."
        }
    }
}

actor TranslationService {
    private var engines: [TranslationDirection: UnsafeMutableRawPointer] = [:]
    deinit { for engine in engines.values { translation_destroy(engine) } }
    func translate(_ text: String, direction: TranslationDirection) async throws -> String {
        _ = try SpeechInput.validate(text)
        try Task.checkCancellation()
        if engines[direction] == nil {
            guard let resources = Bundle.main.resourceURL,
                  let engine = translation_create(resources.appendingPathComponent("TranslationModels/" + direction.rawValue).path) else {
                throw TranslationError.unavailable
            }
            engines[direction] = engine
        }
        var code: Int32 = 0
        guard let result = translation_run(engines[direction], text, &code) else {
            throw code == 1 ? TranslationError.tooLong : TranslationError.failed
        }
        defer { translation_free_text(result) }
        try Task.checkCancellation()
        return String(cString: result)
    }
}

@MainActor @Observable
final class TranslationViewModel {
    var direction = TranslationDirection.armenianToRussian
    private(set) var result = ""
    private(set) var busy = false
    private(set) var error: String?
    private let service = TranslationService()
    private var task: Task<Void, Never>?
    private var requestID = UUID()
    func reset() {
        requestID = UUID(); task?.cancel(); task = nil
        result = ""; error = nil; busy = false
    }
    func translate(_ text: String, delay: Bool = false) {
        reset()
        guard (try? SpeechInput.validate(text)) != nil else { return }
        if !delay { busy = true }
        let id = requestID
        let direction = direction
        task = Task {
            do {
                if delay { try await Task.sleep(for: .milliseconds(600)) }
                try Task.checkCancellation()
                guard requestID == id else { return }
                busy = true
                let output = try await service.translate(text, direction: direction)
                guard requestID == id else { return }
                result = output; busy = false
            } catch is CancellationError {
            } catch {
                guard requestID == id else { return }
                self.error = error.localizedDescription; busy = false
            }
        }
    }
}

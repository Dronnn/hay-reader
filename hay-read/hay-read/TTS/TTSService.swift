import Foundation

struct AudioResult: Sendable {
    let url: URL
    let cached: Bool
}

protocol TTSService: Sendable {
    func synthesize(text: String, speed: Double, cacheMegabytes: Int) async throws -> AudioResult
}

enum SpeechError: LocalizedError {
    case emptyText, noArmenian, missingModel, synthesis, playback
    var errorDescription: String? {
        switch self {
        case .emptyText: "Enter some text to speak."
        case .noArmenian: "There is no Armenian text to speak. Enter Armenian or translate Russian into Armenian first."
        case .missingModel: "The Armenian voice is missing or damaged. Rebuild the app to install it."
        case .synthesis: "Piper could not generate speech for this text."
        case .playback: "Audio playback failed. Check your audio output and try again."
        }
    }
}

enum SpeechInput {
    static func validate(_ text: String) throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SpeechError.emptyText }
        return text
    }
    static func armenianText(in text: String) -> String? {
        func isArmenian(_ scalar: Unicode.Scalar) -> Bool {
            (0x0531...0x0556).contains(scalar.value) || (0x0560...0x0588).contains(scalar.value) || (0xFB13...0xFB17).contains(scalar.value)
        }
        guard text.unicodeScalars.contains(where: isArmenian) else { return nil }
        let filtered = text.unicodeScalars.map { scalar -> String in
            if CharacterSet.letters.contains(scalar) && !isArmenian(scalar) { return " " }
            return String(scalar)
        }.joined()
        return filtered.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func speechText(editor: String, translation: String) throws -> String {
        guard let text = armenianText(in: editor) ?? armenianText(in: translation) else { throw SpeechError.noArmenian }
        return text
    }
    static func lengthScale(speed: Double) -> Float {
        Float(1 / (speed.isFinite ? min(2, max(0.1, speed)) : 1))
    }
}

struct ModelManager: Sendable {
    static let voice = "hy_AM-gor-medium"
    let directory: URL
    func model() throws -> URL {
        let model = directory.appendingPathComponent(Self.voice + ".onnx")
        let config = model.appendingPathExtension("json")
        guard FileManager.default.fileExists(atPath: model.path),
              let data = try? Data(contentsOf: config),
              (try? JSONSerialization.jsonObject(with: data)) is [String: Any] else { throw SpeechError.missingModel }
        return model
    }
    static func installed() throws -> ModelManager {
        let fm = FileManager.default
        let directory = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Armenian Speaker/Models", isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        for suffix in [".onnx", ".onnx.json"] {
            let target = directory.appendingPathComponent(voice + suffix)
            if !fm.fileExists(atPath: target.path),
               let source = Bundle.main.resourceURL?.appendingPathComponent("Models/" + voice + suffix),
               fm.fileExists(atPath: source.path) { try fm.copyItem(at: source, to: target) }
        }
        return ModelManager(directory: directory)
    }
}

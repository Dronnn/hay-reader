import Foundation
import CryptoKit

struct AudioCache {
    let directory: URL
    static func key(text: String, voice: String, speed: Double) -> String {
        let payload = "v2|\(voice.utf8.count):\(voice)|\(SpeechInput.lengthScale(speed: speed))|\(text)"
        return SHA256.hash(data: Data(payload.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    func file(key: String) -> URL { directory.appendingPathComponent(key).appendingPathExtension("wav") }
    func prepare() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stale = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for file in stale where file.lastPathComponent.hasSuffix(".partial.wav") {
            try? FileManager.default.removeItem(at: file)
        }
    }
    func touch(_ url: URL) { try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path) }
    func trim(megabytes: Int, keeping: URL? = nil) {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])) ?? []
        let entries = files.compactMap { url -> (URL, Int, Date)? in
            guard url.pathExtension == "wav", let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) else { return nil }
            return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
        }.sorted { $0.2 < $1.2 }
        var total = entries.reduce(0) { $0 + $1.1 }
        for entry in entries where total > max(1, megabytes) * 1_048_576 && entry.0 != keeping {
            if (try? fm.removeItem(at: entry.0)) != nil { total -= entry.1 }
        }
    }
}

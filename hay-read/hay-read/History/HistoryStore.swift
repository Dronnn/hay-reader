import Foundation
import Observation

@MainActor @Observable
final class HistoryStore {
    private(set) var phrases: [String]
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        phrases = Array((defaults.stringArray(forKey: "phrases") ?? []).prefix(20))
    }
    func add(_ text: String) {
        guard (try? SpeechInput.validate(text)) != nil else { return }
        phrases.removeAll { $0 == text }
        phrases.insert(text, at: 0)
        phrases = Array(phrases.prefix(20))
        defaults.set(phrases, forKey: "phrases")
    }
    func clear() { phrases = []; defaults.removeObject(forKey: "phrases") }
}

@MainActor @Observable
final class AppSettings {
    var defaultSpeed: Double { didSet { UserDefaults.standard.set(defaultSpeed, forKey: "defaultSpeed") } }
    var keepHistory: Bool { didSet { UserDefaults.standard.set(keepHistory, forKey: "keepHistory") } }
    var cacheMegabytes: Int { didSet { UserDefaults.standard.set(cacheMegabytes, forKey: "cacheMegabytes") } }
    var autoPlay: Bool { didSet { UserDefaults.standard.set(autoPlay, forKey: "autoPlay") } }
    init() {
        UserDefaults.standard.register(defaults: ["defaultSpeed": 1.0, "keepHistory": true, "cacheMegabytes": 100, "autoPlay": true])
        defaultSpeed = min(2, max(0.1, UserDefaults.standard.double(forKey: "defaultSpeed")))
        keepHistory = UserDefaults.standard.bool(forKey: "keepHistory")
        cacheMegabytes = max(10, UserDefaults.standard.integer(forKey: "cacheMegabytes"))
        autoPlay = UserDefaults.standard.bool(forKey: "autoPlay")
    }
}

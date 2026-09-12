import AppKit
import AVFoundation
import Observation

@MainActor @Observable
final class PlayerViewModel: NSObject, AVAudioPlayerDelegate {
    var text = ""
    var selection = NSRange(location: 0, length: 0)
    var speed: Double
    var generating = false
    var playing = false
    var paused = false
    var status = "Ready"
    var error: String?
    let settings = AppSettings()
    let history = HistoryStore()
    let translation = TranslationViewModel()
    private let tts: any TTSService = PiperTTSService()
    private var audio: AVAudioPlayer?
    private var task: Task<Void, Never>?
    private var generation = UUID()
    override init() { speed = settings.defaultSpeed; super.init() }
    var selectedText: String {
        let nsText = text as NSString
        return selection.length > 0 && NSMaxRange(selection) <= nsText.length ? nsText.substring(with: selection) : text
    }
    func play() {
        stop()
        let currentTranslation = translation.sourceText == text || translation.sourceText == selectedText ? translation.result : ""
        guard let input = try? SpeechInput.speechText(editor: SpeechInput.armenianText(in: selectedText) ?? text, translation: currentTranslation) else {
            error = SpeechError.noArmenian.localizedDescription; return
        }
        guard (try? SpeechInput.validate(input)) != nil else { error = SpeechError.emptyText.localizedDescription; return }
        let id = UUID(); generation = id
        generating = true; status = "Generating…"
        let currentSpeed = speed
        task = Task {
            do {
                let result = try await tts.synthesize(text: input, speed: currentSpeed, cacheMegabytes: settings.cacheMegabytes)
                try Task.checkCancellation()
                guard generation == id else { return }
                let player = try AVAudioPlayer(contentsOf: result.url)
                player.delegate = self
                guard player.prepareToPlay(), player.play() else { throw SpeechError.playback }
                audio = player; playing = true; generating = false
                status = result.cached ? "Playing · Cached" : "Playing"
                if settings.keepHistory { history.add(input) }
            } catch is CancellationError {
            } catch {
                guard generation == id else { return }
                generating = false; status = "Ready"
                self.error = (error as? SpeechError)?.localizedDescription ?? "Speech could not be played. Check the model and available disk space."
            }
        }
    }
    func togglePause() {
        guard let audio else { return }
        if paused {
            guard audio.play() else { error = SpeechError.playback.localizedDescription; return }
            paused = false; playing = true; status = "Playing"
        } else if playing { audio.pause(); paused = true; playing = false; status = "Paused" }
    }
    func stop() {
        generation = UUID(); task?.cancel(); task = nil
        audio?.stop(); audio = nil
        generating = false; playing = false; paused = false; status = "Ready"
    }
    func replaceText(_ value: String) { text = value; selection = NSRange(location: 0, length: 0) }
    func receive(_ value: String, autoPlay: Bool) {
        stop(); replaceText(value)
        if autoPlay { play() }
    }
    func clipboard() {
        guard let value = NSPasteboard.general.string(forType: .string) else { error = "The clipboard does not contain text."; return }
        receive(value, autoPlay: true)
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard self.audio === player else { return }
            self.stop()
            if !flag { self.error = SpeechError.playback.localizedDescription }
        }
    }
}

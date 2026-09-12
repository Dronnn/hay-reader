import Foundation
import AVFoundation
import os

actor PiperTTSService: TTSService {
    private var synth: OpaquePointer?
    private let logger = Logger(subsystem: "com.mrmaier.hay.hay-read", category: "Speech")
    private let cache: AudioCache
    init(cacheDirectory: URL? = nil) {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cache = AudioCache(directory: cacheDirectory ?? base.appendingPathComponent("Armenian Speaker/Audio"))
    }
    deinit { if let synth { piper_free(synth) } }

    func synthesize(text: String, speed: Double, cacheMegabytes: Int) async throws -> AudioResult {
        let text = try SpeechInput.validate(text)
        try Task.checkCancellation()
        try cache.prepare()
        let url = cache.file(key: AudioCache.key(text: text, voice: ModelManager.voice, speed: speed))
        if FileManager.default.fileExists(atPath: url.path) {
            cache.touch(url)
            cache.trim(megabytes: cacheMegabytes, keeping: url)
            logger.info("Audio cache hit")
            return AudioResult(url: url, cached: true)
        }
        if synth == nil {
            let model = try ModelManager.installed().model()
            guard let resources = Bundle.main.resourceURL else { throw SpeechError.missingModel }
            synth = speaker_create(model.path, model.appendingPathExtension("json").path,
                                 resources.appendingPathComponent("espeak-ng-data").path)
        }
        guard let synth else { logger.error("Piper initialization failed"); throw SpeechError.synthesis }
        var options = piper_default_synthesize_options(synth)
        options.length_scale = SpeechInput.lengthScale(speed: speed)
        guard speaker_start(synth, text, &options) == PIPER_OK else { logger.error("Piper start failed"); throw SpeechError.synthesis }
        let temporary = cache.directory.appendingPathComponent(UUID().uuidString + ".partial.wav")
        defer { try? FileManager.default.removeItem(at: temporary) }
        var output: AVAudioFile?
        var frames = 0
        while true {
            try Task.checkCancellation()
            var chunk = piper_audio_chunk()
            let status = speaker_next(synth, &chunk)
            guard status == PIPER_OK || status == PIPER_DONE else { logger.error("Piper chunk failed"); throw SpeechError.synthesis }
            guard chunk.num_samples > 0, let samples = chunk.samples else {
                if status == PIPER_DONE { break }
                continue
            }
            guard let format = AVAudioFormat(standardFormatWithSampleRate: Double(chunk.sample_rate), channels: 1),
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(chunk.num_samples)),
                  let destination = buffer.floatChannelData?[0] else { throw SpeechError.synthesis }
            buffer.frameLength = buffer.frameCapacity
            destination.update(from: samples, count: chunk.num_samples)
            if output == nil { output = try AVAudioFile(forWriting: temporary, settings: format.settings) }
            try output?.write(from: buffer)
            frames += chunk.num_samples
            if status == PIPER_DONE || chunk.is_last { break }
        }
        output = nil
        try Task.checkCancellation()
        guard frames > 0 else { logger.error("Piper returned no samples"); throw SpeechError.synthesis }
        try FileManager.default.moveItem(at: temporary, to: url)
        cache.trim(megabytes: cacheMegabytes, keeping: url)
        logger.info("Speech synthesized")
        return AudioResult(url: url, cached: false)
    }
}

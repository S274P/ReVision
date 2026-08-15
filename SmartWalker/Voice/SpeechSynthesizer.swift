import Foundation
@preconcurrency import AVFoundation
import Combine

/// Text-to-speech with two priority levels so safety warnings can interrupt
/// navigation chatter, plus de-duplication so the same line isn't repeated
/// nonstop while an obstacle stays in view.
///
/// If a caretaker has recorded their own voice for a phrase (see `VoiceLibrary`),
/// that recording is played instead of the synthesized voice. Anything without a
/// recording falls back to the tuned, calm system voice.
@MainActor
final class SpeechSynthesizer: NSObject, ObservableObject {

    enum Priority {
        case normal   // navigation instructions, confirmations
        case urgent   // safety warnings — interrupt everything
    }

    @Published private(set) var lastSpoken: String = ""
    @Published private(set) var isSpeaking: Bool = false

    /// Caretaker setting: speak extra slowly for users who need more time.
    var slowSpeech: Bool = false

    /// Language for the voice, e.g. "en-US".
    var languageCode: String = "en-US" {
        didSet { refreshVoice() }
    }

    /// Recorded-voice library. When set, recordings are preferred over TTS.
    weak var library: VoiceLibrary?

    private let synthesizer = AVSpeechSynthesizer()
    private var preferredVoice: AVSpeechSynthesisVoice?
    private var clipPlayer: AVAudioPlayer?

    /// The last urgent line + when it was said, used with a cooldown to avoid spam.
    private var lastUrgentPhrase: String = ""
    private var lastUrgentTime: Date = .distantPast

    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
        refreshVoice()
    }

    /// Duck other audio and allow speech to mix; safe to call repeatedly.
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            print("[SpeechSynthesizer] audio session error: \(error)")
        }
    }

    private func refreshVoice() {
        preferredVoice = Self.bestVoice(language: languageCode)
    }

    /// Prefer a premium voice, then enhanced, then any match, then a plain default.
    static func bestVoice(language: String) -> AVSpeechSynthesisVoice? {
        let all = AVSpeechSynthesisVoice.speechVoices()
        let langPrefix = String(language.prefix(2)).lowercased()
        let matches = all.filter { $0.language.lowercased().hasPrefix(langPrefix) }
        let ranked = matches.sorted { a, b in
            if (a.language == language) != (b.language == language) {
                return a.language == language
            }
            return a.quality.rawValue > b.quality.rawValue
        }
        return ranked.first ?? AVSpeechSynthesisVoice(language: language)
    }

    /// Speaks `text`. If a recording exists (matched by `clipKey`, or by the phrase
    /// text), that recording is played; otherwise the system voice speaks the text.
    /// Urgent lines interrupt current speech; normal lines queue.
    func speak(_ text: String,
               priority: Priority = .normal,
               cooldown: TimeInterval = 2.5,
               clipKey: String? = nil) {
        let phrase = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty else { return }

        if priority == .urgent {
            let now = Date()
            if phrase == lastUrgentPhrase, now.timeIntervalSince(lastUrgentTime) < cooldown {
                return // identical warning too soon — skip
            }
            lastUrgentPhrase = phrase
            lastUrgentTime = now
        }

        // Prefer a caretaker recording: explicit key first, then the phrase text.
        let clipURL = clipKey.flatMap { library?.url(for: $0) }
            ?? library?.url(for: VoiceLibrary.key(forPhrase: phrase))

        if let clipURL {
            playClip(clipURL)
            lastSpoken = phrase
            return
        }

        // Fall back to synthesized speech.
        if priority == .urgent { stopAll() }

        let utterance = AVSpeechUtterance(string: phrase)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * (slowSpeech ? 0.72 : 0.82)
        utterance.pitchMultiplier = 0.96
        utterance.preUtteranceDelay = 0.05
        utterance.postUtteranceDelay = priority == .urgent ? 0.1 : 0.2
        utterance.voice = preferredVoice
            ?? AVSpeechSynthesisVoice(language: languageCode)
            ?? AVSpeechSynthesisVoice(language: "en-US")

        lastSpoken = phrase
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    private func playClip(_ url: URL) {
        // A recording is the "speech" now — interrupt any current speech/clip.
        synthesizer.stopSpeaking(at: .immediate)
        clipPlayer?.stop()
        configureAudioSession()
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.play()
            clipPlayer = p
            isSpeaking = true
        } catch {
            print("[SpeechSynthesizer] clip play error: \(error)")
            isSpeaking = false
        }
    }

    /// Stops all speech immediately (both synthesized and recorded).
    func stopAll() {
        synthesizer.stopSpeaking(at: .immediate)
        clipPlayer?.stop()
        clipPlayer = nil
        isSpeaking = false
    }
}

extension SpeechSynthesizer: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = self.synthesizer.isSpeaking }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = self.synthesizer.isSpeaking }
    }
}

extension SpeechSynthesizer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.isSpeaking = false }
    }
}

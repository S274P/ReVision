import Foundation
import Speech
import AVFoundation
import Combine

/// Live microphone → text using on-device speech recognition where available.
///
/// The app listens continuously while the user is in Navigation mode. Because iOS
/// rarely marks a continuous buffer result as "final" on a natural pause, we detect
/// end-of-speech ourselves with a short silence timer: after the user stops talking
/// for `silenceDelay`, the current transcript is treated as a finished command and
/// emitted via `onFinalResult`; the caller parses it into a `VoiceCommand`.
@MainActor
final class SpeechRecognizer: ObservableObject {

    @Published private(set) var isListening = false
    @Published private(set) var transcript = ""
    @Published private(set) var authorized = false

    /// Called with each finalized phrase.
    var onFinalResult: (String) -> Void = { _ in }

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// Fire the current transcript as a command after this much silence.
    private let silenceDelay: TimeInterval = 1.2
    private var silenceWork: DispatchWorkItem?

    // MARK: - Authorization

    func requestAuthorization() async {
        let speechStatus: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        let micGranted: Bool = await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
        }
        authorized = (speechStatus == .authorized) && micGranted
    }

    // MARK: - Listening

    func startListening() {
        guard authorized, !isListening, let recognizer, recognizer.isAvailable else { return }

        // Reset any prior task.
        task?.cancel()
        task = nil

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("[SpeechRecognizer] audio session error: \(error)")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        self.request = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
        } catch {
            print("[SpeechRecognizer] engine start error: \(error)")
            return
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        // Natural end-of-speech (rare for continuous buffers).
                        self.finalizeUtterance()
                    } else if !self.transcript.isEmpty {
                        // Usual path: restart the silence countdown as words arrive.
                        self.scheduleSilenceFinalize()
                    }
                }
                if error != nil {
                    self.restart()
                }
            }
        }
    }

    func stopListening() {
        silenceWork?.cancel()
        silenceWork = nil
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning { audioEngine.stop() }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isListening = false
    }

    // MARK: - End-of-speech detection

    /// (Re)start the silence countdown each time new words arrive. When the user
    /// stops talking for `silenceDelay`, the transcript is treated as a finished command.
    private func scheduleSilenceFinalize() {
        silenceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.finalizeUtterance()
        }
        silenceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + silenceDelay, execute: work)
    }

    /// Emit the current transcript as a command (if any) and start a fresh listen.
    private func finalizeUtterance() {
        guard isListening else { return }   // avoid double-firing during teardown
        silenceWork?.cancel()
        silenceWork = nil
        let phrase = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        transcript = ""
        if !phrase.isEmpty {
            onFinalResult(phrase)
        }
        restart()
    }

    /// Cleanly stops and starts again — used after each finalized phrase or error.
    private func restart() {
        stopListening()
        // Small delay avoids fighting the audio session during teardown.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.startListening()
        }
    }
}

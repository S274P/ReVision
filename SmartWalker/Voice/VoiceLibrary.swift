import Foundation
@preconcurrency import AVFoundation
import Combine

/// Stores caretaker voice recordings and plays them back.
///
/// Recordings are keyed by a string — either a fixed phrase (via `key(forPhrase:)`)
/// or `"dw:<connectionID>"` for a doorway direction — and saved as .m4a files in the
/// app's Documents/VoiceClips folder. A small JSON index maps key → filename.
@MainActor
final class VoiceLibrary: NSObject, ObservableObject {

    /// Bumped whenever a recording is added/removed so views refresh.
    @Published private(set) var revision = 0
    /// The key currently being recorded, if any (drives the UI).
    @Published private(set) var recordingKey: String?

    private var index: [String: String] = [:]      // key -> filename
    private let indexName = "voice_index.json"

    private var recorder: AVAudioRecorder?
    private var previewPlayer: AVAudioPlayer?
    private var pendingFilename: String?

    override init() {
        super.init()
        loadIndex()
    }

    // MARK: - Keys

    /// Canonical key for a fixed phrase (case/space/punctuation-insensitive).
    static func key(forPhrase text: String) -> String {
        let lowered = text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?,;:"))
        return lowered.split(whereSeparator: { $0 == " " }).joined(separator: " ")
    }

    // MARK: - Storage

    private var folder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("VoiceClips", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var indexURL: URL { folder.appendingPathComponent(indexName) }

    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexURL),
              let map = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        index = map
    }

    private func saveIndex() {
        if let data = try? JSONEncoder().encode(index) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }

    // MARK: - Queries

    func hasRecording(for key: String) -> Bool { url(for: key) != nil }

    func url(for key: String) -> URL? {
        guard let name = index[key] else { return nil }
        let u = folder.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    var isRecording: Bool { recorder?.isRecording ?? false }

    // MARK: - Permission

    @discardableResult
    func requestMicPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
        }
    }

    // MARK: - Recording

    func startRecording(for key: String) {
        stopPreview()
        configureSession(record: true)
        let filename = "clip_\(UUID().uuidString).m4a"
        let url = folder.appendingPathComponent(filename)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.record()
            recorder = rec
            recordingKey = key
            pendingFilename = filename
        } catch {
            print("[VoiceLibrary] record error: \(error)")
            configureSession(record: false)
        }
    }

    func stopRecording() {
        recorder?.stop()
        if let key = recordingKey, let name = pendingFilename {
            if let old = index[key] {
                try? FileManager.default.removeItem(at: folder.appendingPathComponent(old))
            }
            index[key] = name
            saveIndex()
        }
        recorder = nil
        recordingKey = nil
        pendingFilename = nil
        configureSession(record: false)
        revision += 1
    }

    func delete(key: String) {
        if let name = index[key] {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
        }
        index[key] = nil
        saveIndex()
        revision += 1
    }

    // MARK: - Preview playback (for the recording screen)

    func preview(key: String) {
        guard let url = url(for: key) else { return }
        stopPreview()
        configureSession(record: false)
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.play()
            previewPlayer = p
        } catch {
            print("[VoiceLibrary] preview error: \(error)")
        }
    }

    func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
    }

    // MARK: - Audio session

    private func configureSession(record: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            if record {
                try session.setCategory(.playAndRecord, mode: .default,
                                        options: [.duckOthers, .defaultToSpeaker])
            } else {
                try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            }
            try session.setActive(true, options: [])
        } catch {
            print("[VoiceLibrary] session error: \(error)")
        }
    }
}

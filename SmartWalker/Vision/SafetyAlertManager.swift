import Foundation
import Combine

/// Turns a frame's detected objects into at most one spoken safety warning, applying:
///  - zone-aware steering (go around an obstacle when a side is clear; stop when
///    something is right in front or every direction is blocked),
///  - a grace period so brief detector dropouts don't flip state and restart speech,
///  - no cutting a warning off mid-word unless the danger actually increases,
///  - a cooldown so we don't speak every frame,
///  - priority: urgent warnings interrupt navigation speech.
@MainActor
final class SafetyAlertManager: ObservableObject {
    @Published private(set) var lastWarning: String = "Clear path."
    @Published private(set) var lastUrgency: ObstacleUrgency = .none

    private unowned let speaker: SpeechSynthesizer

    /// Minimum gap between two spoken warnings.
    private let cooldown: TimeInterval = 2.0
    /// A stop can come a little sooner than a caution.
    private let stopGate: TimeInterval = 1.2
    /// Safety net: if we somehow think we're still speaking this long, speak anyway.
    private let speakingSafetyNet: TimeInterval = 6.0
    private var lastSpokenAt = Date.distantPast

    /// How long the frame must be clear before we treat the path as actually clear.
    /// This absorbs brief detector dropouts (the main cause of stutter).
    private let clearGrace: TimeInterval = 1.5
    /// After this long clear, announce "Clear path." once.
    private let clearAnnounceDelay: TimeInterval = 3.0
    private var lastObstacleAt = Date.distantPast
    private var announcedClear = true

    init(speaker: SpeechSynthesizer) {
        self.speaker = speaker
    }

    /// Whether a warning is currently active (used to suppress navigation chatter).
    var hasActiveWarning: Bool { lastUrgency != .none }

    /// Process one frame's detections.
    func process(_ objects: [DetectedObject]) {
        guard let (phrase, urgency) = ZoneLogic.guidance(for: objects) else {
            handleClearPath()
            return
        }

        lastObstacleAt = Date()
        announcedClear = false

        let previousUrgency = lastUrgency
        lastUrgency = urgency

        let now = Date()
        let escalated = urgency.rawValue > previousUrgency.rawValue
        let sinceLast = now.timeIntervalSince(lastSpokenAt)
        let seemsStuck = sinceLast > speakingSafetyNet

        // Don't cut a warning off mid-word — only interrupt if the danger got worse
        // (e.g. caution -> stop), or if the speech state looks stuck.
        if speaker.isSpeaking && !escalated && !seemsStuck { return }

        // Minimum gap between warnings, unless the danger just increased.
        let gate = urgency == .stop ? stopGate : cooldown
        if sinceLast < gate && !escalated { return }

        lastSpokenAt = now
        lastWarning = phrase
        speaker.speak(phrase, priority: .urgent, cooldown: cooldown)
    }

    private func handleClearPath() {
        let now = Date()
        // Grace period: a brief detector dropout is NOT "clear". Keep the current
        // warning state until the frame has stayed clear for `clearGrace`.
        guard now.timeIntervalSince(lastObstacleAt) >= clearGrace else { return }

        lastUrgency = .none

        // Announce "Clear path." once, a bit after obstacles are truly gone.
        guard !announcedClear,
              now.timeIntervalSince(lastObstacleAt) >= clearAnnounceDelay else { return }
        announcedClear = true
        lastWarning = "Clear path."
        speaker.speak("Clear path.", priority: .normal)
    }

    /// Reset when leaving safety mode.
    func reset() {
        lastUrgency = .none
        lastWarning = "Clear path."
        announcedClear = true
        lastObstacleAt = .distantPast
        lastSpokenAt = .distantPast
    }
}

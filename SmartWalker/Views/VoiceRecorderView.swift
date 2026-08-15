import SwiftUI

/// Caretaker screen for recording their own voice for common phrases.
/// Recordings play instead of the synthesized voice wherever the app says that phrase.
struct VoiceRecorderView: View {
    @ObservedObject var voice: VoiceLibrary

    private let phrases = [
        "Stop.", "Careful.", "Clear path.",
        "Turn left.", "Turn right.", "Go straight ahead.",
        "You have arrived.", "Almost there.",
        "Please wait.", "Follow my voice."
    ]

    var body: some View {
        List {
            Section {
                ForEach(phrases, id: \.self) { phrase in
                    row(phrase)
                }
            } header: {
                Text("Tap Record, say the phrase, then tap Stop. Your voice will play instead of the robot voice.")
                    .textCase(nil)
            }
        }
        .navigationTitle("Record your voice")
        .navigationBarTitleDisplayMode(.inline)
        .task { await voice.requestMicPermission() }
        .onDisappear {
            if voice.isRecording { voice.stopRecording() }
            voice.stopPreview()
        }
    }

    @ViewBuilder
    private func row(_ phrase: String) -> some View {
        let key = VoiceLibrary.key(forPhrase: phrase)
        let recorded = voice.hasRecording(for: key)
        let isRec = voice.recordingKey == key

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(phrase).font(.body)
                if recorded && !isRec {
                    Label("Recorded", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.safe)
                }
            }
            Spacer()

            if isRec {
                Button {
                    voice.stopRecording()
                } label: {
                    Label("Stop", systemImage: "stop.circle.fill")
                        .foregroundStyle(Theme.danger)
                }
                .buttonStyle(.borderless)
            } else {
                if recorded {
                    Button { voice.preview(key: key) } label: {
                        Image(systemName: "play.circle").font(.title3)
                    }
                    .buttonStyle(.borderless)
                    Button(role: .destructive) { voice.delete(key: key) } label: {
                        Image(systemName: "trash").font(.body)
                    }
                    .buttonStyle(.borderless)
                }
                Button { voice.startRecording(for: key) } label: {
                    Label(recorded ? "Re-record" : "Record", systemImage: "mic.circle.fill")
                }
                .buttonStyle(.borderless)
                .tint(Theme.accent)
            }
        }
        .padding(.vertical, 2)
    }
}

import AVFoundation
import Observation

enum SpeechRole {
    case modelA
    case modelB
    case commentator
    case judge
}

@MainActor
@Observable
final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {
    var isEnabled: Bool = false
    var isSpeaking: Bool = false

    private let synthesizer = AVSpeechSynthesizer()
    private var lastSpokenLength: Int = 0
    private var currentRole: SpeechRole = .modelA
    private var utteranceQueue: [AVSpeechUtterance] = []

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Voice Assignment

    func voice(for role: SpeechRole) -> AVSpeechSynthesisVoice? {
        // Assign distinct voices per role. Uses macOS premium voices when available.
        switch role {
        case .modelA:
            return AVSpeechSynthesisVoice(identifier: "com.apple.voice.premium.en-US.Zoe")
                ?? AVSpeechSynthesisVoice(language: "en-US")
        case .modelB:
            return AVSpeechSynthesisVoice(identifier: "com.apple.voice.premium.en-GB.Malcolm")
                ?? AVSpeechSynthesisVoice(language: "en-GB")
        case .commentator:
            return AVSpeechSynthesisVoice(identifier: "com.apple.voice.premium.en-US.Ava")
                ?? AVSpeechSynthesisVoice(language: "en-AU")
        case .judge:
            return AVSpeechSynthesisVoice(identifier: "com.apple.voice.premium.en-US.Tom")
                ?? AVSpeechSynthesisVoice(language: "en-US")
        }
    }

    // MARK: - Streaming Feed

    /// Called repeatedly as streaming text grows. Extracts complete sentences
    /// not yet spoken and queues them for speech.
    func feedStreamingText(_ fullText: String, role: SpeechRole) {
        guard isEnabled else { return }
        currentRole = role

        let newText = String(fullText.dropFirst(lastSpokenLength))
        let sentences = extractCompleteSentences(from: newText)

        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            lastSpokenLength += sentence.count

            let utterance = AVSpeechUtterance(string: trimmed)
            utterance.voice = voice(for: role)
            utterance.rate = 0.52
            utterance.pitchMultiplier = pitchMultiplier(for: role)
            utterance.preUtteranceDelay = 0.1

            // Don't let queue back up too much
            if synthesizer.isSpeaking && utteranceQueue.count > 3 {
                continue
            }

            synthesizer.speak(utterance)
        }
    }

    /// Called when a turn completes to speak any remaining partial sentence.
    func flushRemaining(role: SpeechRole) {
        guard isEnabled else { return }
        // Reset for next turn
        lastSpokenLength = 0
    }

    /// Reset the sentence tracker for a new turn.
    func resetForNewTurn() {
        lastSpokenLength = 0
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        lastSpokenLength = 0
        isSpeaking = false
    }

    // MARK: - Private

    private func extractCompleteSentences(from text: String) -> [String] {
        var sentences: [String] = []
        var current = ""

        for char in text {
            current.append(char)
            if char == "." || char == "!" || char == "?" {
                // Check if next char is whitespace or end of string (sentence boundary)
                sentences.append(current)
                current = ""
            }
        }
        // Don't include the partial (non-sentence-ending) remainder
        // It will be picked up on the next feed call

        return sentences
    }

    private func pitchMultiplier(for role: SpeechRole) -> Float {
        switch role {
        case .modelA: return 1.0
        case .modelB: return 0.95
        case .commentator: return 1.1
        case .judge: return 0.9
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = true
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}

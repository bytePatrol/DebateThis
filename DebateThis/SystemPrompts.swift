import Foundation

// Hardcoded prompt strings for Layer 1.
// Migrate to structured PromptLibrary in Layer 2 (see TODOS.md).

enum SystemPrompts {

    static func debater(side: DebaterSide, topic: String) -> String {
        """
        You are a world-class debater arguing \(side.label) the following topic:

        "\(topic)"

        Rules:
        - Argue \(side.label) this position with conviction, even if you personally disagree.
        - DO NOT hedge, equivocate, or acknowledge the other side has valid points.
        - DO NOT concede any ground. Your job is to WIN, not to be balanced.
        - Be specific. Use concrete examples, data, and logical arguments.
        - When responding to your opponent, directly attack their weakest arguments.
        - Keep your response to 2-3 focused paragraphs.
        - Write in a confident, assertive tone. No "I think" or "perhaps."
        - Do not use phrases like "as an AI" or reference being a language model.
        """
    }

    static func debaterWithContext(side: DebaterSide, topic: String, transcript: [TranscriptEntry]) -> String {
        var prompt = debater(side: side, topic: topic)

        if !transcript.isEmpty {
            prompt += "\n\nDebate transcript so far:\n"
            for entry in transcript {
                prompt += "\n[\(entry.speaker)] \(entry.content)\n"
            }
            prompt += "\nNow respond to your opponent's latest argument. Attack their reasoning directly."
        }

        return prompt
    }

    static func judge(topic: String, transcript: [TranscriptEntry]) -> String {
        var prompt = """
        You are an impartial judge evaluating a debate on the topic:

        "\(topic)"

        Score each debater on four dimensions (1-10 scale):
        1. Argument Quality: logical structure, coherence, depth of reasoning
        2. Evidence: use of specific examples, data, concrete support
        3. Rhetoric: persuasiveness, clarity, impact of language
        4. Responsiveness: how well they engaged with and countered the opponent

        Debate transcript:
        """

        for entry in transcript {
            prompt += "\n\n[\(entry.speaker)] \(entry.content)"
        }

        prompt += """


        Provide your verdict in this exact format:

        WINNER: [Model A or Model B]

        SCORES:
        Model A: argument=X evidence=X rhetoric=X responsiveness=X
        Model B: argument=X evidence=X rhetoric=X responsiveness=X

        REASONING:
        [2-3 sentences explaining why the winner won. Be decisive. Do not cop out with "both made good points."]
        """

        return prompt
    }
}

// MARK: - Supporting Types

enum DebaterSide {
    case forTopic
    case againstTopic

    var label: String {
        switch self {
        case .forTopic: return "FOR"
        case .againstTopic: return "AGAINST"
        }
    }
}

struct TranscriptEntry {
    let speaker: String
    let content: String
}

import Foundation
import SwiftData

// MARK: - SwiftData Models for Debate Persistence

@Model
final class SavedDebate {
    var debateID: UUID
    var topic: String
    var modelAID: String
    var modelAName: String
    var modelBID: String
    var modelBName: String
    var judgeModelID: String
    var judgeModelName: String
    var commentatorModelID: String?
    var commentatorModelName: String?
    var winnerName: String?
    var winnerIsModelB: Bool
    var verdictReasoning: String?
    var createdAt: Date
    var totalRounds: Int

    @Relationship(deleteRule: .cascade)
    var rounds: [SavedRound]

    init(from debate: Debate) {
        self.debateID = debate.id
        self.topic = debate.topic
        self.modelAID = debate.modelA.id
        self.modelAName = debate.modelA.shortName
        self.modelBID = debate.modelB.id
        self.modelBName = debate.modelB.shortName
        self.judgeModelID = debate.judgeModel.id
        self.judgeModelName = debate.judgeModel.shortName
        self.commentatorModelID = debate.commentatorModel?.id
        self.commentatorModelName = debate.commentatorModel?.shortName
        self.winnerName = debate.verdict?.winner.shortName
        self.winnerIsModelB = debate.verdict?.winner.id == debate.modelB.id
        self.verdictReasoning = debate.verdict?.reasoning
        self.createdAt = debate.createdAt
        self.totalRounds = debate.rounds.count
        self.rounds = debate.rounds.map { SavedRound(from: $0) }
    }

    var summary: String {
        "\(modelAName) vs \(modelBName)"
    }

    var resultText: String {
        if let winner = winnerName {
            return "\(winner) wins"
        }
        return "No verdict"
    }
}

@Model
final class SavedRound {
    var number: Int
    var turnAContent: String?
    var turnBContent: String?
    var commentary: String?

    init(from round: DebateRound) {
        self.number = round.number
        self.turnAContent = round.turnA?.content
        self.turnBContent = round.turnB?.content
        self.commentary = round.commentary
    }
}

// MARK: - Transcript Export

extension SavedDebate {
    func exportTranscript() -> String {
        var text = """
        DEBATE: \(topic)
        \(modelAName) (FOR) vs \(modelBName) (AGAINST)
        Judge: \(judgeModelName)
        Date: \(createdAt.formatted(date: .abbreviated, time: .shortened))

        """

        let sortedRounds = rounds.sorted { $0.number < $1.number }
        for round in sortedRounds {
            text += "\n--- ROUND \(round.number) ---\n"
            if let a = round.turnAContent {
                text += "\n[\(modelAName) — FOR]\n\(a)\n"
            }
            if let b = round.turnBContent {
                text += "\n[\(modelBName) — AGAINST]\n\(b)\n"
            }
            if let c = round.commentary {
                text += "\n[Commentary]\n\(c)\n"
            }
        }

        if let winner = winnerName, let reasoning = verdictReasoning {
            text += "\n--- VERDICT ---\n"
            text += "Winner: \(winner)\n"
            text += "\(reasoning)\n"
        }

        return text
    }
}

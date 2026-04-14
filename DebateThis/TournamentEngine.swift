import Foundation
import Observation
import SwiftData

// MARK: - Tournament Data Types

enum TournamentSize: Int, CaseIterable, Identifiable {
    case four = 4
    case eight = 8

    var id: Int { rawValue }
    var label: String { "\(rawValue) Models" }
}

struct TournamentMatch: Identifiable {
    let id: UUID
    let roundIndex: Int       // 0 = quarterfinals/semis, 1 = semis/final, etc.
    let matchIndex: Int
    var modelA: ModelIdentifier?
    var modelB: ModelIdentifier?
    var winner: ModelIdentifier?
    var state: TournamentMatchState

    init(roundIndex: Int, matchIndex: Int, modelA: ModelIdentifier? = nil, modelB: ModelIdentifier? = nil) {
        self.id = UUID()
        self.roundIndex = roundIndex
        self.matchIndex = matchIndex
        self.modelA = modelA
        self.modelB = modelB
        self.state = (modelA != nil && modelB != nil) ? .ready : .pending
    }
}

enum TournamentMatchState: Equatable {
    case pending
    case ready
    case inProgress
    case complete
}

struct TournamentData: Identifiable {
    let id: UUID
    let topic: String
    let judgeModel: ModelIdentifier
    let commentatorModel: ModelIdentifier?
    var participants: [ModelIdentifier]
    var matches: [TournamentMatch]
    var currentRoundIndex: Int
    var champion: ModelIdentifier?
    let createdAt: Date

    var totalRounds: Int {
        Int(log2(Double(participants.count)).rounded(.up))
    }

    var isComplete: Bool { champion != nil }
}

// MARK: - Tournament Engine

@MainActor
@Observable
final class TournamentEngine {
    var tournament: TournamentData?
    var currentMatchIndex: Int?
    var debateEngine: DebateEngine
    var isRunning: Bool = false

    init(debateEngine: DebateEngine) {
        self.debateEngine = debateEngine
    }

    func createTournament(
        topic: String,
        participants: [ModelIdentifier],
        judgeModel: ModelIdentifier,
        commentatorModel: ModelIdentifier?,
        roundsPerMatch: Int = 2
    ) {
        let bracket = generateBracket(participants: participants)
        tournament = TournamentData(
            id: UUID(),
            topic: topic,
            judgeModel: judgeModel,
            commentatorModel: commentatorModel,
            participants: participants,
            matches: bracket,
            currentRoundIndex: 0,
            champion: nil,
            createdAt: Date()
        )
        debateEngine.totalRounds = roundsPerMatch
    }

    // MARK: - Bracket Generation

    private func generateBracket(participants: [ModelIdentifier]) -> [TournamentMatch] {
        var shuffled = participants.shuffled()
        let size = nextPowerOfTwo(shuffled.count)

        // Pad with byes if needed
        while shuffled.count < size {
            shuffled.append(ModelIdentifier(id: "bye", displayName: "BYE", provider: ""))
        }

        let totalRounds = Int(log2(Double(size)))
        var matches: [TournamentMatch] = []

        // First round
        for i in stride(from: 0, to: size, by: 2) {
            let match = TournamentMatch(
                roundIndex: 0,
                matchIndex: i / 2,
                modelA: shuffled[i],
                modelB: shuffled[i + 1]
            )
            matches.append(match)
        }

        // Subsequent rounds (empty, to be filled as winners advance)
        var matchesInRound = size / 2
        for round in 1..<totalRounds {
            matchesInRound /= 2
            for matchIdx in 0..<matchesInRound {
                matches.append(TournamentMatch(roundIndex: round, matchIndex: matchIdx))
            }
        }

        // Auto-advance byes
        for i in matches.indices where matches[i].roundIndex == 0 {
            if matches[i].modelB?.id == "bye" {
                matches[i].winner = matches[i].modelA
                matches[i].state = .complete
                advanceWinner(from: &matches, matchRound: 0, matchIndex: matches[i].matchIndex, winner: matches[i].modelA!)
            } else if matches[i].modelA?.id == "bye" {
                matches[i].winner = matches[i].modelB
                matches[i].state = .complete
                advanceWinner(from: &matches, matchRound: 0, matchIndex: matches[i].matchIndex, winner: matches[i].modelB!)
            }
        }

        return matches
    }

    private func advanceWinner(from matches: inout [TournamentMatch], matchRound: Int, matchIndex: Int, winner: ModelIdentifier) {
        let nextRound = matchRound + 1
        let nextMatchIndex = matchIndex / 2
        let isTopSlot = matchIndex % 2 == 0

        guard let idx = matches.firstIndex(where: { $0.roundIndex == nextRound && $0.matchIndex == nextMatchIndex }) else { return }

        if isTopSlot {
            matches[idx].modelA = winner
        } else {
            matches[idx].modelB = winner
        }

        if matches[idx].modelA != nil && matches[idx].modelB != nil {
            matches[idx].state = .ready
        }
    }

    private func nextPowerOfTwo(_ n: Int) -> Int {
        var p = 1
        while p < n { p *= 2 }
        return p
    }

    // MARK: - Run Tournament

    func runNextMatch() {
        guard var tournament else { return }
        guard let matchIdx = tournament.matches.firstIndex(where: { $0.state == .ready }) else {
            return
        }

        isRunning = true
        currentMatchIndex = matchIdx
        tournament.matches[matchIdx].state = .inProgress
        self.tournament = tournament

        let match = tournament.matches[matchIdx]
        guard let modelA = match.modelA, let modelB = match.modelB else { return }

        debateEngine.onDebateComplete = { [weak self] debate in
            guard let self else { return }
            self.handleMatchComplete(matchIdx: matchIdx, debate: debate)
        }

        debateEngine.startDebate(
            topic: tournament.topic,
            modelA: modelA,
            modelB: modelB,
            judgeModel: tournament.judgeModel,
            commentatorModel: tournament.commentatorModel
        )
    }

    private func handleMatchComplete(matchIdx: Int, debate: Debate) {
        guard var tournament else { return }
        guard let verdict = debate.verdict else { return }

        tournament.matches[matchIdx].winner = verdict.winner
        tournament.matches[matchIdx].state = .complete

        // Advance winner
        let match = tournament.matches[matchIdx]
        advanceWinner(from: &tournament.matches, matchRound: match.roundIndex, matchIndex: match.matchIndex, winner: verdict.winner)

        // Check if tournament is complete
        if let finalMatch = tournament.matches.last, finalMatch.state == .complete {
            tournament.champion = finalMatch.winner
        }

        self.tournament = tournament
        self.currentMatchIndex = nil
        self.isRunning = false

        debateEngine.onDebateComplete = nil
        debateEngine.reset()

        // Auto-advance to next match if tournament isn't over
        if !tournament.isComplete {
            Task {
                try? await Task.sleep(for: .seconds(2))
                self.runNextMatch()
            }
        }
    }
}

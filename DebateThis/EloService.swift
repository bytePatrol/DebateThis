import Foundation
import SwiftData

// MARK: - Model Rating (SwiftData)

@Model
final class ModelRating {
    @Attribute(.unique) var modelID: String
    var displayName: String
    var rating: Double
    var wins: Int
    var losses: Int
    var lastUpdated: Date

    var totalGames: Int { wins + losses }
    var winRate: Double { totalGames > 0 ? Double(wins) / Double(totalGames) : 0 }

    init(modelID: String, displayName: String) {
        self.modelID = modelID
        self.displayName = displayName
        self.rating = 1200.0
        self.wins = 0
        self.losses = 0
        self.lastUpdated = Date()
    }
}

// MARK: - Elo Computation

enum EloService {
    static let defaultRating: Double = 1200.0
    static let kFactor: Double = 32.0

    static func computeNewRatings(
        ratingA: Double,
        ratingB: Double,
        winnerIsA: Bool
    ) -> (newA: Double, newB: Double) {
        let expectedA = 1.0 / (1.0 + pow(10.0, (ratingB - ratingA) / 400.0))
        let expectedB = 1.0 - expectedA

        let scoreA: Double = winnerIsA ? 1.0 : 0.0
        let scoreB: Double = winnerIsA ? 0.0 : 1.0

        let newA = ratingA + kFactor * (scoreA - expectedA)
        let newB = ratingB + kFactor * (scoreB - expectedB)

        return (newA, newB)
    }

    @MainActor
    static func recordResult(
        winnerID: String,
        winnerName: String,
        loserID: String,
        loserName: String,
        context: ModelContext
    ) {
        let winnerRating = fetchOrCreate(modelID: winnerID, name: winnerName, context: context)
        let loserRating = fetchOrCreate(modelID: loserID, name: loserName, context: context)

        let (newWinner, newLoser) = computeNewRatings(
            ratingA: winnerRating.rating,
            ratingB: loserRating.rating,
            winnerIsA: true
        )

        winnerRating.rating = newWinner
        winnerRating.wins += 1
        winnerRating.lastUpdated = Date()

        loserRating.rating = newLoser
        loserRating.losses += 1
        loserRating.lastUpdated = Date()

        try? context.save()
    }

    @MainActor
    private static func fetchOrCreate(modelID: String, name: String, context: ModelContext) -> ModelRating {
        let predicate = #Predicate<ModelRating> { $0.modelID == modelID }
        let descriptor = FetchDescriptor(predicate: predicate)
        if let existing = try? context.fetch(descriptor).first {
            existing.displayName = name
            return existing
        }
        let new = ModelRating(modelID: modelID, displayName: name)
        context.insert(new)
        return new
    }
}

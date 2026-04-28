import Foundation
import SwiftData

// MARK: - PersonalizationEngine

/// Manages multi-signal interest tracking and story ranking.
///
/// Signals used (weighted):
///   Explicit:  like (+3.0), save (+2.5), dislike (-3.0), hide (-2.0)
///   Implicit:  click-through (+2.0), read time (+0.5/min), article read (+1.0)
///   Temporal:  consecutive days engaged (+1.5/day streak)
///   Recency:   stories decay in priority after 6 hours
///   Diversity: slight boost to underrepresented categories (prevents echo chamber)
@MainActor
class PersonalizationEngine: ObservableObject {
    static let shared = PersonalizationEngine()

    private let allCategories = ["ai", "startup", "finance", "politics", "world", "austin", "health", "layoffs"]

    // MARK: - Bootstrap default interests

    func bootstrapIfNeeded(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<UserInterest>())) ?? []
        if existing.isEmpty {
            // Seed with the user's stated starting interests
            let defaultInterests: [(String, Double)] = [
                ("ai", 0.8),
                ("startup", 0.75),
                ("finance", 0.7),
                ("politics", 0.65),
                ("austin", 0.7),
                ("health", 0.6),
                ("layoffs", 0.65),
                ("world", 0.5),
            ]
            for (cat, score) in defaultInterests {
                let interest = UserInterest(category: cat)
                interest.interestScore = score
                context.insert(interest)
            }
            try? context.save()
        }
    }

    // MARK: - Record signals

    func recordLike(category: String, context: ModelContext) {
        mutate(category: category, context: context) { $0.likeCount += 1 }
    }

    func recordDislike(category: String, context: ModelContext) {
        mutate(category: category, context: context) { $0.dislikeCount += 1 }
    }

    func recordSave(category: String, context: ModelContext) {
        mutate(category: category, context: context) { $0.saveCount += 1 }
    }

    func recordHide(category: String, context: ModelContext) {
        mutate(category: category, context: context) { $0.hideCount += 1 }
    }

    func recordRead(category: String, durationSeconds: Int, context: ModelContext) {
        mutate(category: category, context: context) {
            $0.totalArticlesRead += 1
            $0.totalReadDurationSeconds += durationSeconds
            updateStreak(&$0)
        }
    }

    func recordClickThrough(category: String, context: ModelContext) {
        mutate(category: category, context: context) {
            $0.clickThroughCount += 1
            $0.viewCount += 1
        }
    }

    func recordImpression(category: String, context: ModelContext) {
        mutate(category: category, context: context) { $0.viewCount += 1 }
    }

    // MARK: - Rank stories

    func rank(stories: [Story], context: ModelContext) -> [Story] {
        let interests = fetchInterests(context: context)
        let scoreMap = Dictionary(uniqueKeysWithValues: interests.map { ($0.category, $0.interestScore) })
        let categoryCounts = categoryCounts(stories: stories)
        let now = Date()

        return stories
            .filter { !$0.isHidden }
            .map { story -> (Story, Double) in
                var score = scoreMap[story.category] ?? 0.5

                // Recency decay: stories older than 6h get lower priority
                let ageHours = now.timeIntervalSince(story.publishedAt) / 3600.0
                let recencyMultiplier = max(0.4, 1.0 - (ageHours / 12.0))
                score *= recencyMultiplier

                // Diversity boost: if this category is underrepresented, slight boost
                let catCount = categoryCounts[story.category] ?? 1
                if catCount <= 1 { score *= 1.15 }

                // Saved stories always surface
                if story.isSaved { score += 2.0 }

                return (story, score)
            }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }

    // MARK: - Interest summary for UI

    func interestSummary(context: ModelContext) -> [(category: String, score: Double)] {
        let interests = fetchInterests(context: context)
        return interests
            .sorted { $0.interestScore > $1.interestScore }
            .map { (category: $0.category, score: $0.interestScore) }
    }

    // MARK: - Private helpers

    private func mutate(category: String, context: ModelContext, transform: (inout UserInterest) -> Void) {
        let interests = fetchInterests(context: context)
        if var interest = interests.first(where: { $0.category == category }) {
            transform(&interest)
            interest.recalculateScore()
        } else {
            var newInterest = UserInterest(category: category)
            transform(&newInterest)
            newInterest.recalculateScore()
            context.insert(newInterest)
        }
        try? context.save()
    }

    private func fetchInterests(context: ModelContext) -> [UserInterest] {
        (try? context.fetch(FetchDescriptor<UserInterest>())) ?? []
    }

    private func updateStreak(_ interest: inout UserInterest) {
        let today = Story.todayString()
        if interest.lastEngagedDate == today { return }

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())
            .flatMap { d -> String? in
                let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: d)
            } ?? ""

        if interest.lastEngagedDate == yesterday {
            interest.consecutiveDaysEngaged += 1
        } else {
            interest.consecutiveDaysEngaged = 1
        }
        interest.lastEngagedDate = today
    }

    private func categoryCounts(stories: [Story]) -> [String: Int] {
        stories.reduce(into: [:]) { $0[$1.category, default: 0] += 1 }
    }
}

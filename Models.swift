import Foundation
import SwiftData

// MARK: - Story

@Model
final class Story {
    @Attribute(.unique) var id: String
    var headline: String
    var summary: String
    var whyItMatters: String
    var sourceURL: String
    var sourceName: String
    var category: String          // "ai", "startup", "finance", "politics", "austin", "health", "world", "layoffs"
    var publishedAt: Date
    var fetchedAt: Date
    var isRead: Bool
    var isSaved: Bool
    var isHidden: Bool
    var likeSignal: Bool          // "more like this"
    var dislikeSignal: Bool       // "less like this"
    var readDurationSeconds: Int  // how long user spent reading
    var openedFullArticle: Bool   // clicked through to source
    var briefDate: String         // YYYY-MM-DD for grouping into daily records

    init(
        id: String = UUID().uuidString,
        headline: String,
        summary: String,
        whyItMatters: String,
        sourceURL: String,
        sourceName: String,
        category: String,
        publishedAt: Date = Date(),
        fetchedAt: Date = Date(),
        briefDate: String = Story.todayString()
    ) {
        self.id = id
        self.headline = headline
        self.summary = summary
        self.whyItMatters = whyItMatters
        self.sourceURL = sourceURL
        self.sourceName = sourceName
        self.category = category
        self.publishedAt = publishedAt
        self.fetchedAt = fetchedAt
        self.isRead = false
        self.isSaved = false
        self.isHidden = false
        self.likeSignal = false
        self.dislikeSignal = false
        self.readDurationSeconds = 0
        self.openedFullArticle = false
        self.briefDate = briefDate
    }

    static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

// MARK: - LearnBlurb

@Model
final class LearnBlurb {
    @Attribute(.unique) var id: String
    var question: String
    var answer: String
    var category: String
    var emoji: String
    var isSaved: Bool
    var wasShownOn: String        // YYYY-MM-DD

    init(id: String = UUID().uuidString, question: String, answer: String, category: String, emoji: String) {
        self.id = id
        self.question = question
        self.answer = answer
        self.category = category
        self.emoji = emoji
        self.isSaved = false
        self.wasShownOn = Story.todayString()
    }
}

// MARK: - UserInterest (personalization engine)

@Model
final class UserInterest {
    @Attribute(.unique) var category: String

    // Explicit signals
    var likeCount: Int
    var dislikeCount: Int
    var saveCount: Int
    var hideCount: Int

    // Implicit signals
    var totalReadDurationSeconds: Int   // total time spent reading this category
    var totalArticlesRead: Int          // articles where isRead = true
    var clickThroughCount: Int          // opened full article
    var viewCount: Int                  // how many times stories in this category were shown
    var consecutiveDaysEngaged: Int     // streak
    var lastEngagedDate: String

    // Computed score (cached, recalculated on change)
    var interestScore: Double

    init(category: String) {
        self.category = category
        self.likeCount = 0
        self.dislikeCount = 0
        self.saveCount = 0
        self.hideCount = 0
        self.totalReadDurationSeconds = 0
        self.totalArticlesRead = 0
        self.clickThroughCount = 0
        self.viewCount = 0
        self.consecutiveDaysEngaged = 0
        self.lastEngagedDate = ""
        self.interestScore = 0.5
    }

    /// Recalculate interest score from all signals.
    /// Score range: 0.0 (strongly disinterested) to 1.0 (highly interested)
    func recalculateScore() {
        let positiveSignals: Double =
            Double(likeCount) * 3.0 +
            Double(saveCount) * 2.5 +
            Double(clickThroughCount) * 2.0 +
            Double(totalArticlesRead) * 1.0 +
            Double(min(totalReadDurationSeconds, 3600)) / 60.0 * 0.5 +   // cap at 60 min equiv
            Double(consecutiveDaysEngaged) * 1.5

        let negativeSignals: Double =
            Double(dislikeCount) * 3.0 +
            Double(hideCount) * 2.0

        let viewAdjusted = viewCount > 0
            ? (positiveSignals - negativeSignals) / Double(viewCount)
            : 0.0

        // Normalize to 0–1 range with sigmoid-like clamping
        let raw = 0.5 + viewAdjusted * 0.2
        interestScore = max(0.05, min(1.0, raw))
    }
}

// MARK: - DailyBriefRecord (archive)

@Model
final class DailyBriefRecord {
    @Attribute(.unique) var dateString: String   // YYYY-MM-DD
    var storyIDs: [String]                        // references to Story IDs
    var learnBlurbIDs: [String]
    var otdText: String                           // "one thing today" blurb
    var createdAt: Date

    init(dateString: String, storyIDs: [String] = [], learnBlurbIDs: [String] = [], otdText: String = "") {
        self.dateString = dateString
        self.storyIDs = storyIDs
        self.learnBlurbIDs = learnBlurbIDs
        self.otdText = otdText
        self.createdAt = Date()
    }
}

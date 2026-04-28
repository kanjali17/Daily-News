import Foundation
import SwiftData

// MARK: - RefreshScheduler

class RefreshScheduler {
    static let shared = RefreshScheduler()

    private var scheduler: NSBackgroundActivityScheduler?
    private var refreshTask: Task<Void, Never>?

    func start() {
        let activity = NSBackgroundActivityScheduler(identifier: "com.kanjali17.DailyBriefSticky.refresh")
        activity.repeats = true
        activity.interval = 3 * 60 * 60   // 3 hours
        activity.tolerance = 30 * 60       // ±30 min
        activity.qualityOfService = .utility

        activity.schedule { completion in
            Task {
                await self.performRefresh()
                completion(.finished)
            }
        }
        self.scheduler = activity

        // Also listen for manual refresh
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleManualRefresh),
            name: .manualRefreshRequested,
            object: nil
        )

        // Initial fetch on launch
        Task { await performRefresh() }
    }

    @objc func handleManualRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { await performRefresh() }
    }

    @MainActor
    func performRefresh() async {
        NotificationCenter.default.post(name: .refreshStarted, object: nil)

        // 1. Fetch RSS items
        let rawItems = await NewsService.shared.fetchAllStories()

        // 2. Optionally AI-summarize
        var summaries: [String: StorySummary] = [:]
        if await SummarizerService.shared.isEnabled {
            // Only summarize first 10 to conserve API usage
            let toSummarize = Array(rawItems.prefix(10))
            summaries = await SummarizerService.shared.summarizeBatch(toSummarize)
        }

        // 3. Convert to Story objects and store
        let today = Story.todayString()
        var storyIDs: [String] = []

        // Use AppDelegate's container via shared context
        guard let container = (NSApp.delegate as? AppDelegate)?.modelContainer else {
            NotificationCenter.default.post(name: .storiesUpdated, object: nil)
            return
        }

        let context = ModelContext(container)

        // Fetch existing story IDs for deduplication
        let existingStories = (try? context.fetch(FetchDescriptor<Story>())) ?? []
        let existingLinks = Set(existingStories.map { $0.sourceURL })

        for item in rawItems {
            guard !existingLinks.contains(item.link) else { continue }

            let summary = summaries[item.link]
            let story = Story(
                headline: summary?.headline ?? item.title,
                summary: summary?.summary ?? item.description,
                whyItMatters: summary?.whyItMatters ?? "Stay informed on this developing story.",
                sourceURL: item.link,
                sourceName: item.sourceName,
                category: item.category,
                publishedAt: item.pubDate,
                briefDate: today
            )
            context.insert(story)
            storyIDs.append(story.id)
        }

        // 4. Update or create today's DailyBriefRecord
        let records = (try? context.fetch(FetchDescriptor<DailyBriefRecord>(
            predicate: #Predicate { $0.dateString == today }
        ))) ?? []

        if let record = records.first {
            record.storyIDs.append(contentsOf: storyIDs)
        } else {
            // Generate "one thing today" from top AI story or first story
            let otd = rawItems.first(where: { $0.category == "ai" || $0.category == "finance" })
            let otdText = otd.map { "\($0.sourceName): \($0.title)" } ?? "Check back soon for today's top story."
            let record = DailyBriefRecord(dateString: today, storyIDs: storyIDs, otdText: otdText)
            context.insert(record)
        }

        // 5. Generate learn blurbs
        let blurbs = await SummarizerService.shared.generateLearnBlurbs(forCategories: ["ai", "finance", "startup", "health"])
        let existingBlurbs = (try? context.fetch(FetchDescriptor<LearnBlurb>())) ?? []
        let existingQuestions = Set(existingBlurbs.map { $0.question })

        for blurb in blurbs where !existingQuestions.contains(blurb.question) {
            context.insert(LearnBlurb(
                question: blurb.question,
                answer: blurb.answer,
                category: blurb.category,
                emoji: blurb.emoji
            ))
        }

        try? context.save()

        NotificationCenter.default.post(name: .storiesUpdated, object: nil)
        UserDefaults.standard.set(Date(), forKey: "lastRefreshDate")
    }
}

extension Notification.Name {
    static let refreshStarted = Notification.Name("refreshStarted")
}

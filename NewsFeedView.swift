import SwiftUI
import SwiftData

struct NewsFeedView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Story.publishedAt, order: .reverse) private var allStories: [Story]
    @StateObject private var personalization = PersonalizationEngine.shared

    private let categoryOrder = ["ai", "startup", "layoffs", "finance", "politics", "world", "austin", "health"]

    private var todayStories: [Story] {
        let today = Story.todayString()
        let filtered = allStories.filter { $0.briefDate == today && !$0.isHidden }
        return personalization.rank(stories: filtered, context: context)
    }

    private var todayRecord: DailyBriefRecord? {
        let today = Story.todayString()
        return try? context.fetch(
            FetchDescriptor<DailyBriefRecord>(predicate: #Predicate { $0.dateString == today })
        ).first
    }

    private var storiesByCategory: [(category: String, stories: [Story])] {
        let ranked = todayStories
        var dict: [String: [Story]] = [:]
        for story in ranked {
            dict[story.category, default: []].append(story)
        }
        return categoryOrder.compactMap { cat in
            guard let stories = dict[cat], !stories.isEmpty else { return nil }
            return (category: cat, stories: stories)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                // One Thing Today
                if let record = todayRecord, !record.otdText.isEmpty {
                    OTDCard(text: record.otdText)
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                }

                if todayStories.isEmpty {
                    EmptyFeedView()
                } else {
                    ForEach(storiesByCategory, id: \.category) { group in
                        SectionHeader(category: group.category)

                        ForEach(group.stories.prefix(3)) { story in
                            StoryCardView(story: story)
                                .onAppear {
                                    personalization.recordImpression(category: story.category, context: context)
                                }
                        }
                    }
                }

                Color.clear.frame(height: 20)
            }
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - One Thing Today Card

struct OTDCard: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("⚡ ONE THING TODAY")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(Color(hex: "#60a5fa"))

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#f0f0f0"))
                .lineSpacing(3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#1d2d44"))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: "#3b5998"), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let category: String

    var label: String {
        switch category {
        case "ai": return "TECH & AI"
        case "startup": return "AI STARTUPS"
        case "layoffs": return "TECH LAYOFFS"
        case "finance": return "FINANCE & MARKETS"
        case "politics": return "POLITICS"
        case "world": return "WORLD NEWS"
        case "austin": return "AUSTIN & UT"
        case "health": return "HEALTHCARE & SCIENCE"
        default: return category.uppercased()
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.0)
                .foregroundColor(Color(hex: "#52525b"))
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.5)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background(Color(hex: "#18181b"))
    }
}

// MARK: - Empty State

struct EmptyFeedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("📰")
                .font(.system(size: 32))
            Text("Fetching your brief...")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#a1a1aa"))
            Text("Stories will appear after the first refresh.")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#52525b"))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

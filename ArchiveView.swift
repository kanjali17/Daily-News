import SwiftUI
import SwiftData

struct ArchiveView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DailyBriefRecord.dateString, order: .reverse) private var records: [DailyBriefRecord]
    @Query private var allStories: [Story]
    @StateObject private var personalization = PersonalizationEngine.shared
    @State private var selectedSection: ArchiveSection = .saved

    enum ArchiveSection: String, CaseIterable {
        case saved = "Saved"
        case history = "History"
        case profile = "My Profile"
    }

    private var savedStories: [Story] {
        allStories.filter { $0.isSaved }.sorted { $0.fetchedAt > $1.fetchedAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sub-tabs
            HStack(spacing: 0) {
                ForEach(ArchiveSection.allCases, id: \.self) { section in
                    Button(action: { selectedSection = section }) {
                        Text(section.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(selectedSection == section
                                ? Color(hex: "#f4f4f5")
                                : Color(hex: "#52525b"))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(selectedSection == section
                                ? Color.white.opacity(0.08)
                                : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(hex: "#18181b"))

            Divider().overlay(Color.white.opacity(0.05))

            ScrollView {
                switch selectedSection {
                case .saved: SavedStoriesSection(stories: savedStories)
                case .history: HistorySection(records: records, allStories: allStories)
                case .profile: ProfileSection()
                }
                Color.clear.frame(height: 20)
            }
            .scrollIndicators(.hidden)
        }
    }
}

// MARK: - Saved Stories

struct SavedStoriesSection: View {
    let stories: [Story]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if stories.isEmpty {
                VStack(spacing: 8) {
                    Text("🔖")
                        .font(.system(size: 28))
                    Text("No saved stories yet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "#a1a1aa"))
                    Text("Tap Save on any story to keep it here.")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#52525b"))
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                ForEach(stories) { story in
                    SavedStoryRow(story: story)
                }
            }
        }
    }
}

struct SavedStoryRow: View {
    @Bindable var story: Story
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CategoryTag(category: story.category)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(story.headline)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#e4e4e7"))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(story.sourceName) · \(story.briefDate)")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#52525b"))
            }

            Spacer()

            Button(action: {
                story.isSaved = false
                try? context.save()
            }) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#fbbf24"))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)

        Divider().overlay(Color.white.opacity(0.05))
    }
}

// MARK: - History

struct HistorySection: View {
    let records: [DailyBriefRecord]
    let allStories: [Story]

    private func stories(for record: DailyBriefRecord) -> [Story] {
        let ids = Set(record.storyIDs)
        return allStories.filter { ids.contains($0.id) }.prefix(3).map { $0 }
    }

    private func displayDate(_ dateString: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: dateString) else { return dateString }
        let today = Calendar.current.isDateInToday(date)
        let yesterday = Calendar.current.isDateInYesterday(date)
        if today { return "Today" }
        if yesterday { return "Yesterday" }
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if records.isEmpty {
                VStack(spacing: 8) {
                    Text("📅")
                        .font(.system(size: 28))
                    Text("Archive builds over time")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "#a1a1aa"))
                    Text("Past briefs will appear here after each day.")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#52525b"))
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                ForEach(records) { record in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(displayDate(record.dateString).uppercased())
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.8)
                            .foregroundColor(Color(hex: "#52525b"))
                            .padding(.horizontal, 14)
                            .padding(.top, 12)
                            .padding(.bottom, 2)

                        ForEach(stories(for: record)) { story in
                            Text(story.headline)
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#a1a1aa"))
                                .lineLimit(1)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 4)

                            Divider().overlay(Color.white.opacity(0.04))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Interest Profile

struct ProfileSection: View {
    @Environment(\.modelContext) private var context
    @StateObject private var personalization = PersonalizationEngine.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Stats row
            HStack(spacing: 8) {
                StatCard(label: "SAVED STORIES", value: savedCount, color: Color(hex: "#fbbf24"))
                StatCard(label: "DAYS ACTIVE", value: daysActive, color: Color(hex: "#34d399"))
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 12)

            HStack(spacing: 8) {
                Text("INTEREST PROFILE")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.0)
                    .foregroundColor(Color(hex: "#52525b"))
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 0.5)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            let interests = personalization.interestSummary(context: context)
            ForEach(interests, id: \.category) { item in
                InterestBar(category: item.category, score: item.score)
            }

            Text("Scores update based on what you read, save, and click.")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#3f3f46"))
                .padding(.horizontal, 14)
                .padding(.top, 8)
        }
    }

    private var savedCount: String {
        let count = (try? context.fetch(FetchDescriptor<Story>(predicate: #Predicate { $0.isSaved })))?.count ?? 0
        return "\(count)"
    }

    private var daysActive: String {
        let count = (try? context.fetch(FetchDescriptor<DailyBriefRecord>()))?.count ?? 0
        return "\(max(1, count))"
    }
}

struct StatCard: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(Color(hex: "#f4f4f5"))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.2), lineWidth: 0.5)
        )
    }
}

struct InterestBar: View {
    let category: String
    let score: Double

    var label: String {
        switch category {
        case "ai": return "Tech & AI"
        case "startup": return "AI Startups"
        case "finance": return "Finance"
        case "politics": return "Politics"
        case "world": return "World"
        case "austin": return "Austin & UT"
        case "health": return "Healthcare"
        case "layoffs": return "Tech Layoffs"
        default: return category.capitalized
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#a1a1aa"))
                .frame(width: 90, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: geo.size.width * score, height: 6)
                }
            }
            .frame(height: 6)

            Text("\(Int(score * 100))%")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(hex: "#52525b"))
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }

    var barColor: Color {
        switch category {
        case "ai": return Color(hex: "#a78bfa")
        case "startup": return Color(hex: "#34d399")
        case "finance": return Color(hex: "#fbbf24")
        case "politics": return Color(hex: "#f87171")
        case "austin": return Color(hex: "#60a5fa")
        case "health": return Color(hex: "#f472b6")
        case "layoffs": return Color(hex: "#fb923c")
        default: return Color(hex: "#9ca3af")
        }
    }
}

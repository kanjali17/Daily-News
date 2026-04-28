import SwiftUI
import SwiftData

struct LearnSectionView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \LearnBlurb.wasShownOn, order: .reverse) private var blurbs: [LearnBlurb]

    private var todayBlurbs: [LearnBlurb] {
        let today = Story.todayString()
        let todays = blurbs.filter { $0.wasShownOn == today }
        if !todays.isEmpty { return todays }
        // Fall back to most recent batch
        return Array(blurbs.prefix(6))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 8) {
                    Text("TODAY'S CONCEPTS")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.0)
                        .foregroundColor(Color(hex: "#52525b"))
                    Rectangle()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 0.5)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

                if todayBlurbs.isEmpty {
                    // Show defaults while AI generates
                    ForEach(LearnBlurbData.defaults, id: \.question) { blurb in
                        StaticLearnCard(blurb: blurb)
                    }
                } else {
                    ForEach(todayBlurbs) { blurb in
                        LearnCard(blurb: blurb)
                    }
                }

                Color.clear.frame(height: 20)
            }
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Dynamic LearnCard (from SwiftData)

struct LearnCard: View {
    @Bindable var blurb: LearnBlurb
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(blurb.emoji)
                .font(.system(size: 18))

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(blurb.question)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "#f4f4f5"))

                    Text(blurb.answer)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#71717a"))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button(action: {
                    blurb.isSaved.toggle()
                    try? context.save()
                }) {
                    Image(systemName: blurb.isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 13))
                        .foregroundColor(blurb.isSaved ? Color(hex: "#fbbf24") : Color(hex: "#3f3f46"))
                }
                .buttonStyle(.plain)
            }

            CategoryTag(category: blurb.category)
        }
        .padding(14)
        .background(Color(hex: "#1c1c1f"))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }
}

// MARK: - Static fallback card

struct StaticLearnCard: View {
    let blurb: LearnBlurbData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(blurb.emoji)
                .font(.system(size: 18))

            Text(blurb.question)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#f4f4f5"))

            Text(blurb.answer)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#71717a"))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            CategoryTag(category: blurb.category)
        }
        .padding(14)
        .background(Color(hex: "#1c1c1f"))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }
}

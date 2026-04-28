import SwiftUI
import SwiftData

struct StoryCardView: View {
    @Bindable var story: Story
    @Environment(\.modelContext) private var context
    @StateObject private var personalization = PersonalizationEngine.shared
    @State private var appearedAt: Date?
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                VStack(alignment: .leading, spacing: 5) {
                    // Meta row
                    HStack(spacing: 6) {
                        CategoryTag(category: story.category)
                        Text("·")
                            .foregroundColor(Color(hex: "#3f3f46"))
                        Text(timeAgo(story.publishedAt))
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#52525b"))
                        Spacer()
                        if story.isSaved {
                            Image(systemName: "bookmark.fill")
                                .font(.system(size: 9))
                                .foregroundColor(Color(hex: "#fbbf24"))
                        }
                    }

                    Text(story.headline)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "#e4e4e7"))
                        .lineSpacing(2)
                        .lineLimit(isExpanded ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)

                    if isExpanded {
                        Text(story.summary)
                            .font(.system(size: 11.5))
                            .foregroundColor(Color(hex: "#71717a"))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity.combined(with: .move(edge: .top)))

                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color(hex: "#3b82f6").opacity(0.3))
                                .frame(width: 2)
                                .padding(.trailing, 8)

                            Text(story.whyItMatters)
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#60a5fa"))
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if isExpanded {
                // Action row
                HStack(spacing: 6) {
                    // Like / More like this
                    ActionButton(
                        icon: story.likeSignal ? "hand.thumbsup.fill" : "hand.thumbsup",
                        label: story.likeSignal ? "Noted" : "More like this",
                        isActive: story.likeSignal,
                        activeColor: Color(hex: "#34d399")
                    ) {
                        story.likeSignal.toggle()
                        if story.likeSignal {
                            story.dislikeSignal = false
                            personalization.recordLike(category: story.category, context: context)
                        }
                        try? context.save()
                    }

                    // Save
                    ActionButton(
                        icon: story.isSaved ? "bookmark.fill" : "bookmark",
                        label: story.isSaved ? "Saved" : "Save",
                        isActive: story.isSaved,
                        activeColor: Color(hex: "#fbbf24")
                    ) {
                        story.isSaved.toggle()
                        if story.isSaved {
                            personalization.recordSave(category: story.category, context: context)
                        }
                        try? context.save()
                    }

                    // Hide
                    ActionButton(
                        icon: "eye.slash",
                        label: "Hide",
                        isActive: false,
                        activeColor: .red
                    ) {
                        story.isHidden = true
                        personalization.recordHide(category: story.category, context: context)
                        try? context.save()
                    }

                    Spacer()

                    // Read full article
                    Button(action: {
                        openLink(story.sourceURL)
                        story.openedFullArticle = true
                        personalization.recordClickThrough(category: story.category, context: context)
                        try? context.save()
                    }) {
                        Text("\(story.sourceName) →")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#3b82f6"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
                .transition(.opacity)
            }

            Divider()
                .overlay(Color.white.opacity(0.05))
        }
        .onAppear {
            appearedAt = Date()
            story.isRead = true
            try? context.save()
        }
        .onDisappear {
            // Record approximate read duration
            if let appeared = appearedAt {
                let duration = Int(Date().timeIntervalSince(appeared))
                if duration > 2 {  // ignore instant scrolls
                    personalization.recordRead(
                        category: story.category,
                        durationSeconds: duration,
                        context: context
                    )
                }
            }
        }
    }

    private func openLink(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 1 { return "Just now" }
        if mins < 60 { return "\(mins)m ago" }
        let hours = mins / 60
        if hours < 24 { return "\(hours)h ago" }
        return "\(hours / 24)d ago"
    }
}

// MARK: - Category Tag

struct CategoryTag: View {
    let category: String

    var config: (label: String, bg: Color, fg: Color) {
        switch category {
        case "ai":       return ("AI", Color(hex: "#8b5cf6").opacity(0.2), Color(hex: "#a78bfa"))
        case "startup":  return ("STARTUP", Color(hex: "#10b981").opacity(0.15), Color(hex: "#34d399"))
        case "finance":  return ("FINANCE", Color(hex: "#f59e0b").opacity(0.15), Color(hex: "#fbbf24"))
        case "politics": return ("POLITICS", Color(hex: "#ef4444").opacity(0.15), Color(hex: "#f87171"))
        case "world":    return ("WORLD", Color(hex: "#6b7280").opacity(0.2), Color(hex: "#9ca3af"))
        case "austin":   return ("AUSTIN", Color(hex: "#3b82f6").opacity(0.15), Color(hex: "#60a5fa"))
        case "health":   return ("HEALTH", Color(hex: "#ec4899").opacity(0.15), Color(hex: "#f472b6"))
        case "layoffs":  return ("LAYOFFS", Color(hex: "#f97316").opacity(0.15), Color(hex: "#fb923c"))
        default:         return (category.uppercased(), Color.gray.opacity(0.15), Color.gray)
        }
    }

    var body: some View {
        Text(config.label)
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.6)
            .foregroundColor(config.fg)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(config.bg)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let activeColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(isActive ? activeColor : Color(hex: "#52525b"))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(isActive ? activeColor.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isActive ? activeColor.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

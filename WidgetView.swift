import SwiftUI
import SwiftData

struct WidgetView: View {
    @State private var selectedTab: Tab = .brief
    @State private var isRefreshing = false
    @State private var lastRefresh: Date? = UserDefaults.standard.object(forKey: "lastRefreshDate") as? Date

    enum Tab { case brief, learn, archive }

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "#18181b"))

            VStack(spacing: 0) {
                // Title bar
                TitleBarView(
                    isRefreshing: $isRefreshing,
                    lastRefresh: lastRefresh,
                    onRefresh: triggerRefresh
                )

                // Tabs
                TabBarView(selectedTab: $selectedTab)

                Divider().overlay(Color.white.opacity(0.08))

                // Content
                Group {
                    switch selectedTab {
                    case .brief:
                        NewsFeedView()
                    case .learn:
                        LearnSectionView()
                    case .archive:
                        ArchiveView()
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: selectedTab)
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: .refreshStarted)) { _ in
            isRefreshing = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .storiesUpdated)) { _ in
            isRefreshing = false
            lastRefresh = Date()
        }
    }

    private func triggerRefresh() {
        NotificationCenter.default.post(name: .manualRefreshRequested, object: nil)
    }
}

// MARK: - Title Bar

struct TitleBarView: View {
    @Binding var isRefreshing: Bool
    let lastRefresh: Date?
    let onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // macOS traffic lights placeholder
            HStack(spacing: 5) {
                Circle().fill(Color(hex: "#ff5f57")).frame(width: 11, height: 11)
                Circle().fill(Color(hex: "#febc2e")).frame(width: 11, height: 11)
                Circle().fill(Color(hex: "#28c840")).frame(width: 11, height: 11)
            }

            Text("Daily Brief Sticky")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "#a1a1aa"))

            Spacer()

            if isRefreshing {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
                Text("Refreshing...")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#52525b"))
            } else {
                Text(refreshLabel)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#52525b"))

                Button(action: onRefresh) {
                    Text("↻ Refresh")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "#a1a1aa"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(hex: "#1c1c1f"))
    }

    private var refreshLabel: String {
        guard let date = lastRefresh else { return "Never updated" }
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 1 { return "Just updated" }
        if mins < 60 { return "Updated \(mins)m ago" }
        let hours = mins / 60
        return "Updated \(hours)h ago"
    }
}

// MARK: - Tab Bar

struct TabBarView: View {
    @Binding var selectedTab: WidgetView.Tab

    var body: some View {
        HStack(spacing: 0) {
            TabButton(title: "Daily Brief", tab: .brief, selectedTab: $selectedTab)
            TabButton(title: "Learn", tab: .learn, selectedTab: $selectedTab)
            TabButton(title: "Archive", tab: .archive, selectedTab: $selectedTab)
            Spacer()
        }
        .padding(.horizontal, 14)
        .background(Color(hex: "#1c1c1f"))
    }
}

struct TabButton: View {
    let title: String
    let tab: WidgetView.Tab
    @Binding var selectedTab: WidgetView.Tab

    var isActive: Bool { selectedTab == tab }

    var body: some View {
        Button(action: { selectedTab = tab }) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isActive ? Color(hex: "#f4f4f5") : Color(hex: "#71717a"))
                .padding(.vertical, 8)
                .padding(.trailing, 12)
        }
        .buttonStyle(.plain)
        .overlay(
            Rectangle()
                .fill(isActive ? Color(hex: "#3b82f6") : Color.clear)
                .frame(height: 2),
            alignment: .bottom
        )
    }
}

// MARK: - Color hex extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}

# Daily Brief Sticky

A macOS desktop widget that delivers personalized, AI-summarized news and educational blurbs as a floating sticky note on your desktop.



## Features

- 🗞 **Floating desktop widget** — persists across Spaces, survives screen lock, no Dock icon
- 🤖 **AI summarization** — powered by Claude API (optional, requires API key)
- 🎯 **Multi-signal personalization** — learns from what you read, save, like, click, and how long you spend reading
- 📚 **Learn section** — daily educational blurbs on finance, AI, startups, healthcare
- 🗂 **Archive** — full history of past daily briefs + saved stories
- ⚡ **Auto-refresh** — every 3 hours via `NSBackgroundActivityScheduler`

## Requirements

- macOS 14.0+ (Sonoma)
- Xcode 15.2+
- Swift 5.9+
- Optional: Anthropic API key for AI summarization

## Setup

### 1. Clone the repo

```bash
git clone https://github.com/kanjali17/daily-brief-sticky.git
cd daily-brief-sticky
```

### 2. Open in Xcode

```bash
open DailyBriefSticky.xcodeproj
```

### 3. Configure signing

- In Xcode → select the `DailyBriefSticky` target
- Under **Signing & Capabilities**, set your Apple Developer Team
- Change bundle ID if needed: `com.kanjali17.DailyBriefSticky`

### 4. Add entitlements

Add `DailyBriefSticky.entitlements` with:
```xml
<key>com.apple.security.network.client</key>
<true/>
```

### 5. Build & Run (⌘R)

The widget will appear in the top-right of your screen. A newspaper icon appears in the menu bar.

### 6. Enable AI Summarization (optional)

1. Click the menu bar icon → the widget appears
2. The first run uses built-in RSS summaries
3. To enable Claude AI summaries:
   - Get an API key from [console.anthropic.com](https://console.anthropic.com)
   - Open Settings via the menu bar icon
   - Paste your API key and toggle "Enable AI summaries"

## Architecture

```
DailyBriefSticky/
├── App/
│   ├── DailyBriefStickyApp.swift    # @main entry, no window scene
│   └── AppDelegate.swift            # NSPanel creation, status bar, lifecycle
├── Window/
│   ├── FloatingPanel.swift          # Custom NSPanel (borderless, floating)
│   └── FloatingPanelController.swift # Window lifecycle + frame persistence
├── Views/
│   ├── WidgetView.swift             # Root view with tab navigation
│   ├── NewsFeedView.swift           # Personalized news feed
│   ├── StoryCardView.swift          # Story card with interaction tracking
│   ├── LearnSectionView.swift       # Educational blurbs
│   ├── ArchiveView.swift            # History, saved, interest profile
│   └── SettingsView.swift           # API key, refresh config
├── Services/
│   ├── NewsService.swift            # RSS fetching + XML parsing (13 feeds)
│   ├── SummarizerService.swift      # Claude API integration
│   ├── PersonalizationEngine.swift  # Multi-signal interest scoring
│   └── RefreshScheduler.swift       # Background refresh + manual trigger
└── Models/
    └── Models.swift                 # SwiftData models (Story, LearnBlurb, UserInterest, DailyBriefRecord)
```

## Personalization Signals

The interest engine tracks **8 signals** per category:

| Signal | Weight | Type |
|--------|--------|------|
| Like ("More like this") | +3.0 | Explicit |
| Save story | +2.5 | Explicit |
| Dislike ("Less like this") | -3.0 | Explicit |
| Hide story | -2.0 | Explicit |
| Click through to article | +2.0 | Implicit |
| Time spent reading | +0.5/min | Implicit |
| Article marked as read | +1.0 | Implicit |
| Consecutive days engaged | +1.5/day | Temporal |

Scores are also adjusted for:
- **Recency decay** — older stories rank lower
- **Diversity boost** — underrepresented categories get a slight lift

## News Sources

| Category | Source |
|----------|--------|
| Tech & AI | TechCrunch, The Verge, MIT Tech Review |
| Startups | VentureBeat |
| Finance | Reuters Business, MarketWatch |
| Politics | AP News |
| World | BBC World |
| Healthcare | STAT News, Science Daily |
| Austin & UT | KUT News, UT Austin News |
| Layoffs | TechCrunch Layoffs feed |

## Roadmap

- [ ] Notification for breaking news in top categories
- [ ] iCloud sync for saved stories across devices
- [ ] Custom RSS feed addition
- [ ] Weekly digest email
- [ ] Haptic feedback on Apple Silicon

## License

MIT

#!/bin/bash
# =============================================================
# Daily Brief Sticky — GitHub repo creation + push script
# Run this from the directory containing the DailyBriefSticky folder
# Prerequisites: git, gh (GitHub CLI) installed
# Install gh: brew install gh
# Then authenticate: gh auth login
# =============================================================

set -e

REPO_NAME="daily-brief-sticky"
GITHUB_USER="kanjali17"
PROJECT_DIR="DailyBriefSticky"

echo "🗞  Daily Brief Sticky — GitHub Setup"
echo "======================================"

# Check for gh CLI
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) not found."
    echo "   Install it: brew install gh"
    echo "   Then run: gh auth login"
    exit 1
fi

# Check auth
if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated with GitHub CLI."
    echo "   Run: gh auth login"
    exit 1
fi

echo "✅ GitHub CLI authenticated"

# Initialize git in the project folder
cd "$PROJECT_DIR"

if [ ! -d ".git" ]; then
    git init
    echo "✅ Git initialized"
fi

# Create .gitignore
cat > .gitignore << 'EOF'
# Xcode
*.xcuserstate
xcuserdata/
*.xcworkspace/xcuserdata/
DerivedData/
*.pbxuser
*.mode1v3
*.mode2v3
*.perspectivev3
*.xccheckout
*.moved-aside
*.xcuserdata

# Build
build/
*.o
*.d

# macOS
.DS_Store
.AppleDouble
.LSOverride
*.icloud

# SwiftPM
.build/
.swiftpm/

# Secrets — never commit your API key
*.env
secrets.plist
EOF

echo "✅ .gitignore created"

# Create the GitHub repo
echo ""
echo "📦 Creating GitHub repo: $GITHUB_USER/$REPO_NAME"
gh repo create "$REPO_NAME" \
    --public \
    --description "macOS floating desktop widget for personalized news & daily learning briefs" \
    --homepage "https://github.com/$GITHUB_USER/$REPO_NAME" \
    || echo "   (Repo may already exist — continuing)"

# Set remote
git remote remove origin 2>/dev/null || true
git remote add origin "https://github.com/$GITHUB_USER/$REPO_NAME.git"
echo "✅ Remote set to github.com/$GITHUB_USER/$REPO_NAME"

# Stage and commit all files
git add -A
git commit -m "feat: initial commit — Daily Brief Sticky macOS widget

All 4 phases implemented:
- Phase 1: Floating NSPanel desktop widget (persists across Spaces/lock)
- Phase 2: RSS news fetching from 13 feeds (TechCrunch, BBC, Reuters, KUT, etc.)
- Phase 3: Claude AI summarization (optional, via Anthropic API)
- Phase 4: Multi-signal personalization engine (8 signals: like, save, read time,
           click-through, hide, dislike, streak, impressions) + archive view

Categories: AI, Startups, Finance, Politics, World, Austin/UT, Healthcare, Layoffs
Stack: SwiftUI + AppKit (NSPanel), SwiftData, NSBackgroundActivityScheduler"

# Push
git branch -M main
git push -u origin main

echo ""
echo "🎉 Done! Your repo is live at:"
echo "   https://github.com/$GITHUB_USER/$REPO_NAME"
echo ""
echo "Next steps:"
echo "  1. Open Xcode and create a new macOS App project named 'DailyBriefSticky'"
echo "  2. Set bundle ID to: com.kanjali17.DailyBriefSticky"
echo "  3. Delete the auto-generated ContentView.swift"
echo "  4. Drag all .swift files from this repo into your Xcode project"
echo "  5. In Info.plist add: LSUIElement = YES (Boolean)"
echo "  6. In Signing & Capabilities add: Outgoing Connections (Client)"
echo "  7. Build and run (⌘R)"
echo ""
echo "Optional: Add your Anthropic API key in the widget's settings for AI summaries."

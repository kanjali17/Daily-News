import AppKit
import SwiftUI
import SwiftData

class FloatingPanelController: NSObject, NSWindowDelegate {
    private var panel: FloatingPanel?
    private let modelContainer: ModelContainer?

    private let positionKey = "widgetFrame"
    private let visibilityKey = "widgetVisible"

    init(modelContainer: ModelContainer?) {
        self.modelContainer = modelContainer
        super.init()
    }

    func showPanel() {
        let frame = savedFrame()

        let panel = FloatingPanel(contentRect: frame)
        panel.delegate = self

        // Embed SwiftUI view
        let rootView = WidgetView()
            .modelContainer(modelContainer ?? makeInMemoryContainer())
            .environment(\.colorScheme, .dark)

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        // Apply corner radius via layer
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 14
        panel.contentView?.layer?.masksToBounds = true

        self.panel = panel

        let wasVisible = UserDefaults.standard.bool(forKey: visibilityKey)
        if wasVisible || !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            panel.orderFrontRegardless()
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            UserDefaults.standard.set(true, forKey: visibilityKey)
        }
    }

    func togglePanel() {
        guard let panel = panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
            UserDefaults.standard.set(false, forKey: visibilityKey)
        } else {
            panel.orderFrontRegardless()
            UserDefaults.standard.set(true, forKey: visibilityKey)
        }
    }

    // MARK: - Frame persistence

    private func savedFrame() -> NSRect {
        if let saved = UserDefaults.standard.string(forKey: positionKey),
           let frame = NSRectFromString(saved) as NSRect?,
           frame.size.width > 0 {
            return frame
        }
        // Default position: top-right of main screen
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSRect(
            x: screen.maxX - 450,
            y: screen.maxY - 700,
            width: 420,
            height: 660
        )
    }

    func windowDidMove(_ notification: Notification) {
        saveFrame()
    }

    func windowDidResize(_ notification: Notification) {
        saveFrame()
    }

    private func saveFrame() {
        if let frame = panel?.frame {
            UserDefaults.standard.set(NSStringFromRect(frame), forKey: positionKey)
        }
    }

    // Prevent closing when red button clicked — just hide
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        togglePanel()
        return false
    }

    private func makeInMemoryContainer() -> ModelContainer {
        let schema = Schema([Story.self, LearnBlurb.self, UserInterest.self, DailyBriefRecord.self])
        return try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
}

// Helper to parse NSRect from string safely
private func NSRectFromString(_ string: String) -> NSRect? {
    let rect = NSRectFromString(string)
    return rect.size.width > 0 ? rect : nil
}

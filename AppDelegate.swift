import AppKit
import SwiftUI
import SwiftData

class AppDelegate: NSObject, NSApplicationDelegate {
    var panelController: FloatingPanelController?
    var statusBarItem: NSStatusItem?
    var modelContainer: ModelContainer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock (also set LSUIElement in Info.plist)
        NSApp.setActivationPolicy(.accessory)

        // Set up SwiftData container
        do {
            let schema = Schema([Story.self, LearnBlurb.self, UserInterest.self, DailyBriefRecord.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("SwiftData setup failed: \(error)")
        }

        // Create the floating panel
        panelController = FloatingPanelController(modelContainer: modelContainer)
        panelController?.showPanel()

        // Status bar icon for quick access
        setupStatusBar()

        // Schedule background refresh
        RefreshScheduler.shared.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusBarItem?.button {
            button.image = NSImage(systemSymbolName: "newspaper.fill", accessibilityDescription: "Daily Brief")
            button.action = #selector(togglePanel)
            button.target = self
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show/Hide Widget", action: #selector(togglePanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Daily Brief", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusBarItem?.menu = menu
    }

    @objc func togglePanel() {
        panelController?.togglePanel()
    }

    @objc func refreshNow() {
        NotificationCenter.default.post(name: .manualRefreshRequested, object: nil)
    }
}

extension Notification.Name {
    static let manualRefreshRequested = Notification.Name("manualRefreshRequested")
    static let storiesUpdated = Notification.Name("storiesUpdated")
}

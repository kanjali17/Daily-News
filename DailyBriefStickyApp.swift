import SwiftUI
import AppKit

@main
struct DailyBriefStickyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No default window — AppDelegate manages the floating panel
        Settings {
            EmptyView()
        }
    }
}

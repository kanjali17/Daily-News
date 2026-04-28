import AppKit

/// A borderless, floating NSPanel that lives on the desktop above wallpaper
/// but below normal windows. It can move across all Spaces and persists
/// through screen lock/unlock.
class FloatingPanel: NSPanel {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [
                .borderless,
                .nonactivatingPanel,
                .resizable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )

        // Float above desktop but below normal app windows
        self.level = .floating
        self.isFloatingPanel = true

        // Appear on all Spaces, don't move with Exposé
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle
        ]

        // Visual style
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true

        // Stay visible but don't take focus
        self.becomesKeyOnlyIfNeeded = true
        self.acceptsMouseMovedEvents = true

        // Allow resize with minimum/maximum bounds
        self.minSize = NSSize(width: 340, height: 400)
        self.maxSize = NSSize(width: 600, height: 900)
    }

    // Accept key events for text fields without becoming key window
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // Prevent the panel from hiding when the app loses focus
    override func resignMain() {}
}

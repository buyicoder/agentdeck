import AppKit
import SwiftUI

@MainActor
enum AgentDeckTestWindow {
    private static var window: NSWindow?

    static func open() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let content = TestWindowView()
        let hostingController = NSHostingController(rootView: content)
        let window = NSWindow(
            contentRect: NSRect(x: 120, y: 120, width: 520, height: 360),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AgentDeck Test Conversation"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct TestWindowView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("AgentDeck Test Conversation")
                .font(.title2.bold())
            Text("Use this harmless window to verify scanning, queueing, promotion, and restore before moving real agent windows.")
                .foregroundStyle(.secondary)
            Divider()
            Label("Expected detector: title-fallback or AgentDeck app title", systemImage: "scope")
            Label("Expected action: Move windows toggle may move only this test window during validation", systemImage: "rectangle.on.rectangle")
            Spacer()
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 260, alignment: .topLeading)
    }
}


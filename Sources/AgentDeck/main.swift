import AppKit
import CoreGraphics
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var store: ConversationStore?
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = ConversationStore.preview
        let panel = AgentDeckPanelView(store: store)
        let hostingController = NSHostingController(rootView: panel)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AgentDeck"
        window.collectionBehavior = [.moveToActiveSpace]
        if let screen = primaryScreen() {
            let frame = screen.visibleFrame
            let size = NSSize(width: min(1180, frame.width - 80), height: min(760, frame.height - 80))
            window.setFrame(
                NSRect(
                    x: frame.midX - size.width / 2,
                    y: frame.midY - size.height / 2,
                    width: size.width,
                    height: size.height
                ),
                display: true
            )
        } else {
            window.center()
        }
        window.contentViewController = hostingController
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        self.window = window
        self.store = store
        store.refreshSnapshot()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak store] _ in
            Task { @MainActor in
                store?.refreshSnapshot()
            }
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    private func primaryScreen() -> NSScreen? {
        let mainDisplayID = CGMainDisplayID()
        let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")
        return NSScreen.screens.first { screen in
            guard let screenNumber = screen.deviceDescription[screenNumberKey] as? NSNumber else {
                return false
            }
            return screenNumber.uint32Value == mainDisplayID
        } ?? NSScreen.main ?? NSScreen.screens.first
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()

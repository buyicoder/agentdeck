import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

struct WindowFact: Identifiable, Hashable {
    let id: String
    let appName: String
    let ownerPID: pid_t
    let windowNumber: Int
    let title: String
    let frame: CGRect
    let displayLabel: String
    let isOnScreen: Bool
}

struct WindowSnapshot {
    let windows: [WindowFact]
    let focusedWindow: WindowFact?
    let focusedSide: DisplaySide?
}

enum AccessibilityTrust {
    @MainActor
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @MainActor
    static func requestIfNeeded() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

enum MacOSWindowFactProvider {
    static func snapshot() -> WindowSnapshot {
        let windows = listVisibleWindows()
        let focused = focusedWindow(in: windows)
        return WindowSnapshot(
            windows: windows,
            focusedWindow: focused,
            focusedSide: focused.flatMap(focusedSide)
        )
    }

    static func listVisibleWindows() -> [WindowFact] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let rawWindows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return rawWindows.compactMap { info -> WindowFact? in
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let ownerName = info[kCGWindowOwnerName as String] as? String,
                  let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  let windowNumber = info[kCGWindowNumber as String] as? Int,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any]
            else {
                return nil
            }

            let title = (info[kCGWindowName as String] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Untitled window"
            let frame = CGRect(
                x: bounds["X"] as? CGFloat ?? 0,
                y: bounds["Y"] as? CGFloat ?? 0,
                width: bounds["Width"] as? CGFloat ?? 0,
                height: bounds["Height"] as? CGFloat ?? 0
            )

            guard frame.width > 80, frame.height > 40 else {
                return nil
            }

            return WindowFact(
                id: "\(ownerPID)-\(windowNumber)",
                appName: ownerName,
                ownerPID: ownerPID,
                windowNumber: windowNumber,
                title: title,
                frame: frame,
                displayLabel: displayLabel(for: frame),
                isOnScreen: (info[kCGWindowIsOnscreen as String] as? Bool) ?? true
            )
        }
    }

    private static func focusedWindow(in windows: [WindowFact]) -> WindowFact? {
        guard let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            return nil
        }

        // CGWindowListCopyWindowInfo returns windows in front-to-back order for
        // on-screen windows, so the first window owned by the frontmost app is
        // the best public-API approximation of the focused window.
        return windows.first { $0.ownerPID == frontmostPID }
    }

    private static func focusedSide(for fact: WindowFact) -> DisplaySide? {
        guard let primary = NSScreen.screens.first else { return nil }
        let midpointX = fact.frame.midX
        let minX = primary.frame.minX
        let maxX = primary.frame.maxX

        guard midpointX >= minX, midpointX <= maxX else {
            return nil
        }

        return midpointX < primary.frame.midX ? .left : .right
    }

    private static func displayLabel(for frame: CGRect) -> String {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return "Unknown display" }

        let midpoint = CGPoint(x: frame.midX, y: frame.midY)
        if let index = screens.firstIndex(where: { $0.frame.contains(midpoint) }) {
            return index == 0 ? "Primary display" : "Display \(index + 1)"
        }

        return "Offscreen"
    }
}

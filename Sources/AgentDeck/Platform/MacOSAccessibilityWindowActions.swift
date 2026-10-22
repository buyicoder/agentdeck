import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// First real macOS Accessibility spike for moving AgentDeck-managed windows.
///
/// This is intentionally not wired into app state yet. It can replace
/// `MockWindowActionPerformer` later once permissions, identity stability, and
/// restore UX are validated.
struct MacOSAccessibilityWindowActionPerformer: WindowActionPerforming {
    var resolver: AXWindowResolving = MacOSAXWindowResolver()
    var framePlanner: WindowFramePlanning = MainDisplaySplitFramePlanner()

    func promote(_ action: WindowPromotionAction) throws {
        let resolved = try resolver.resolve(windowIdentity: action.windowIdentity)
        let targetFrame = try framePlanner.targetFrame(for: action.targetSide)
        try MacOSAXWindowMutator.setFrame(targetFrame, on: resolved.element)
    }

    func restore(_ snapshot: WindowFrameSnapshot) throws {
        let resolved = try resolver.resolve(windowIdentity: snapshot.windowIdentity)
        try MacOSAXWindowMutator.setFrame(snapshot.frame, on: resolved.element)
    }
}

protocol AXWindowResolving {
    func resolve(windowIdentity: String) throws -> ResolvedAXWindow
}

protocol WindowFramePlanning {
    func targetFrame(for side: DisplaySide) throws -> CGRect
}

struct ResolvedAXWindow {
    let identity: WindowIdentityParts
    let element: AXUIElement
    let cgFrame: CGRect
    let axFrame: CGRect
    let title: String
}

struct WindowIdentityParts: Hashable {
    let ownerPID: pid_t
    let windowNumber: Int

    static func parse(_ value: String) throws -> WindowIdentityParts {
        let separators = CharacterSet(charactersIn: "-:")
        let parts = value
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }

        guard parts.count >= 2,
              let pidValue = Int32(parts[0]),
              let windowNumber = Int(parts[1])
        else {
            throw MacOSAccessibilityWindowActionError.invalidWindowIdentity(value)
        }

        return WindowIdentityParts(ownerPID: pidValue, windowNumber: windowNumber)
    }
}

enum MacOSAccessibilityWindowActionError: Error, LocalizedError {
    case accessibilityPermissionRequired
    case invalidWindowIdentity(String)
    case cgWindowNotFound(String)
    case axWindowsUnavailable(pid_t, AXError)
    case axWindowNotFound(String)
    case axAttributeReadFailed(String, AXError)
    case invalidAXValue(String)
    case axAttributeWriteFailed(String, AXError)
    case screenUnavailable

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            "Accessibility permission is required before windows can be moved."
        case .invalidWindowIdentity(let identity):
            "Invalid window identity: \(identity)"
        case .cgWindowNotFound(let identity):
            "CG window not found for identity: \(identity)"
        case .axWindowsUnavailable(let pid, let error):
            "Could not read AX windows for pid \(pid): \(error)"
        case .axWindowNotFound(let identity):
            "Could not match an AX window for identity: \(identity)"
        case .axAttributeReadFailed(let attribute, let error):
            "Could not read AX attribute \(attribute): \(error)"
        case .invalidAXValue(let attribute):
            "AX attribute \(attribute) did not contain the expected value type."
        case .axAttributeWriteFailed(let attribute, let error):
            "Could not write AX attribute \(attribute): \(error)"
        case .screenUnavailable:
            "No screen is available for frame planning."
        }
    }
}

struct MacOSAXWindowResolver: AXWindowResolving {
    var frameTolerance: CGFloat = 8

    func resolve(windowIdentity: String) throws -> ResolvedAXWindow {
        guard AXIsProcessTrusted() else {
            throw MacOSAccessibilityWindowActionError.accessibilityPermissionRequired
        }

        let identity = try WindowIdentityParts.parse(windowIdentity)
        let cgSnapshot = try CGWindowSnapshot.find(identity: identity, originalIdentity: windowIdentity)
        let appElement = AXUIElementCreateApplication(identity.ownerPID)
        let windows = try AXWindowReader.windows(for: appElement, ownerPID: identity.ownerPID)

        let candidates = windows.compactMap { element -> AXWindowCandidate? in
            guard let frame = try? AXWindowReader.frame(of: element) else { return nil }
            let title = (try? AXWindowReader.stringAttribute(kAXTitleAttribute, from: element)) ?? ""
            return AXWindowCandidate(element: element, title: title, frame: frame)
        }

        if let best = bestCandidate(in: candidates, matching: cgSnapshot) {
            return ResolvedAXWindow(
                identity: identity,
                element: best.element,
                cgFrame: cgSnapshot.frame,
                axFrame: best.frame,
                title: best.title
            )
        }

        throw MacOSAccessibilityWindowActionError.axWindowNotFound(windowIdentity)
    }

    private func bestCandidate(
        in candidates: [AXWindowCandidate],
        matching snapshot: CGWindowSnapshot
    ) -> AXWindowCandidate? {
        candidates
            .map { candidate in
                (
                    candidate: candidate,
                    score: matchScore(candidate: candidate, snapshot: snapshot)
                )
            }
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .first?
            .candidate
    }

    private func matchScore(candidate: AXWindowCandidate, snapshot: CGWindowSnapshot) -> Int {
        var score = 0

        if !snapshot.title.isEmpty && candidate.title == snapshot.title {
            score += 8
        } else if !snapshot.title.isEmpty && candidate.title.localizedCaseInsensitiveContains(snapshot.title) {
            score += 4
        }

        if candidate.frame.isClose(to: snapshot.frame, tolerance: frameTolerance) {
            score += 12
        } else if candidate.frame.size.isClose(to: snapshot.frame.size, tolerance: frameTolerance) {
            score += 4
        }

        return score
    }
}

private struct AXWindowCandidate {
    let element: AXUIElement
    let title: String
    let frame: CGRect
}

private struct CGWindowSnapshot {
    let title: String
    let frame: CGRect

    static func find(identity: WindowIdentityParts, originalIdentity: String) throws -> CGWindowSnapshot {
        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard let rawWindows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            throw MacOSAccessibilityWindowActionError.cgWindowNotFound(originalIdentity)
        }

        guard let info = rawWindows.first(where: { window in
            (window[kCGWindowOwnerPID as String] as? pid_t) == identity.ownerPID
                && (window[kCGWindowNumber as String] as? Int) == identity.windowNumber
        }) else {
            throw MacOSAccessibilityWindowActionError.cgWindowNotFound(originalIdentity)
        }

        let title = (info[kCGWindowName as String] as? String) ?? ""
        let bounds = (info[kCGWindowBounds as String] as? [String: Any]) ?? [:]
        let frame = CGRect(
            x: bounds["X"] as? CGFloat ?? 0,
            y: bounds["Y"] as? CGFloat ?? 0,
            width: bounds["Width"] as? CGFloat ?? 0,
            height: bounds["Height"] as? CGFloat ?? 0
        )

        return CGWindowSnapshot(title: title, frame: frame)
    }
}

private enum AXWindowReader {
    static func windows(for appElement: AXUIElement, ownerPID: pid_t) throws -> [AXUIElement] {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
        guard error == .success else {
            throw MacOSAccessibilityWindowActionError.axWindowsUnavailable(ownerPID, error)
        }

        return (value as? [AXUIElement]) ?? []
    }

    static func frame(of element: AXUIElement) throws -> CGRect {
        let position = try pointAttribute(kAXPositionAttribute, from: element)
        let size = try sizeAttribute(kAXSizeAttribute, from: element)
        return CGRect(origin: position, size: size)
    }

    static func stringAttribute(_ attribute: String, from element: AXUIElement) throws -> String {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success else {
            throw MacOSAccessibilityWindowActionError.axAttributeReadFailed(attribute, error)
        }
        return (value as? String) ?? ""
    }

    private static func pointAttribute(_ attribute: String, from element: AXUIElement) throws -> CGPoint {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success, let axValue = value else {
            throw MacOSAccessibilityWindowActionError.axAttributeReadFailed(attribute, error)
        }

        guard CFGetTypeID(axValue) == AXValueGetTypeID() else {
            throw MacOSAccessibilityWindowActionError.invalidAXValue(attribute)
        }

        var point = CGPoint.zero
        let didRead = AXValueGetValue(axValue as! AXValue, .cgPoint, &point)
        guard didRead else {
            throw MacOSAccessibilityWindowActionError.invalidAXValue(attribute)
        }
        return point
    }

    private static func sizeAttribute(_ attribute: String, from element: AXUIElement) throws -> CGSize {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success, let axValue = value else {
            throw MacOSAccessibilityWindowActionError.axAttributeReadFailed(attribute, error)
        }

        guard CFGetTypeID(axValue) == AXValueGetTypeID() else {
            throw MacOSAccessibilityWindowActionError.invalidAXValue(attribute)
        }

        var size = CGSize.zero
        let didRead = AXValueGetValue(axValue as! AXValue, .cgSize, &size)
        guard didRead else {
            throw MacOSAccessibilityWindowActionError.invalidAXValue(attribute)
        }
        return size
    }
}

enum MacOSAXWindowMutator {
    static func setFrame(_ frame: CGRect, on element: AXUIElement) throws {
        try setPosition(frame.origin, on: element)
        try setSize(frame.size, on: element)
    }

    private static func setPosition(_ position: CGPoint, on element: AXUIElement) throws {
        var mutablePosition = position
        guard let value = AXValueCreate(.cgPoint, &mutablePosition) else {
            throw MacOSAccessibilityWindowActionError.axAttributeWriteFailed(kAXPositionAttribute, .failure)
        }

        let error = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
        guard error == .success else {
            throw MacOSAccessibilityWindowActionError.axAttributeWriteFailed(kAXPositionAttribute, error)
        }
    }

    private static func setSize(_ size: CGSize, on element: AXUIElement) throws {
        var mutableSize = size
        guard let value = AXValueCreate(.cgSize, &mutableSize) else {
            throw MacOSAccessibilityWindowActionError.axAttributeWriteFailed(kAXSizeAttribute, .failure)
        }

        let error = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
        guard error == .success else {
            throw MacOSAccessibilityWindowActionError.axAttributeWriteFailed(kAXSizeAttribute, error)
        }
    }
}

struct MainDisplaySplitFramePlanner: WindowFramePlanning {
    var inset: CGFloat = 8

    func targetFrame(for side: DisplaySide) throws -> CGRect {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            throw MacOSAccessibilityWindowActionError.screenUnavailable
        }

        let visibleFrame = AXCoordinateSpace.rectFromAppKit(screen.visibleFrame).insetBy(dx: inset, dy: inset)
        let halfWidth = floor(visibleFrame.width / 2)

        switch side {
        case .left:
            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: halfWidth,
                height: visibleFrame.height
            )
        case .right:
            return CGRect(
                x: visibleFrame.minX + halfWidth,
                y: visibleFrame.minY,
                width: visibleFrame.width - halfWidth,
                height: visibleFrame.height
            )
        }
    }
}

private enum AXCoordinateSpace {
    static func rectFromAppKit(_ rect: CGRect) -> CGRect {
        let maxY = NSScreen.screens.map(\.frame.maxY).max() ?? rect.maxY
        return CGRect(
            x: rect.minX,
            y: maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }
}

private extension CGRect {
    func isClose(to other: CGRect, tolerance: CGFloat) -> Bool {
        abs(origin.x - other.origin.x) <= tolerance
            && abs(origin.y - other.origin.y) <= tolerance
            && size.isClose(to: other.size, tolerance: tolerance)
    }
}

private extension CGSize {
    func isClose(to other: CGSize, tolerance: CGFloat) -> Bool {
        abs(width - other.width) <= tolerance
            && abs(height - other.height) <= tolerance
    }
}

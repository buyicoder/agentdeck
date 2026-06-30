import CoreGraphics
import Foundation

struct WindowFrameSnapshot: Hashable {
    let windowIdentity: String
    let displayLabel: String
    let frame: CGRect
}

extension WindowFrameSnapshot {
    static func capture(windowIdentity: String) -> WindowFrameSnapshot? {
        guard let fact = MacOSWindowFactProvider.listVisibleWindows().first(where: { $0.id == windowIdentity }) else {
            return nil
        }

        return WindowFrameSnapshot(
            windowIdentity: windowIdentity,
            displayLabel: fact.displayLabel,
            frame: fact.frame
        )
    }
}

struct WindowPromotionAction: Hashable {
    let conversationID: UUID
    let windowIdentity: String
    let targetSide: DisplaySide
    let undoFrame: WindowFrameSnapshot?
}

protocol WindowActionPerforming {
    func promote(_ action: WindowPromotionAction) throws
    func restore(_ snapshot: WindowFrameSnapshot) throws
}

enum WindowActionError: Error, LocalizedError {
    case unsupported
    case windowNotFound(String)

    var errorDescription: String? {
        switch self {
        case .unsupported:
            "Window movement is not implemented yet."
        case .windowNotFound(let identity):
            "Window not found: \(identity)"
        }
    }
}

struct MockWindowActionPerformer: WindowActionPerforming {
    func promote(_ action: WindowPromotionAction) throws {
        // Intentionally empty. The Scheduler MVP applies state changes only.
    }

    func restore(_ snapshot: WindowFrameSnapshot) throws {
        // Intentionally empty. Real restore belongs to the platform layer.
    }
}

struct PromotionCoordinator {
    let performer: WindowActionPerforming

    init(performer: WindowActionPerforming = MockWindowActionPerformer()) {
        self.performer = performer
    }

    func perform(_ plan: PromotionPlan) throws -> WindowPromotionAction {
        let undoFrame = WindowFrameSnapshot.capture(windowIdentity: plan.windowIdentity)
        let action = WindowPromotionAction(
            conversationID: plan.conversationID,
            windowIdentity: plan.windowIdentity,
            targetSide: plan.targetSide,
            undoFrame: undoFrame
        )
        try performer.promote(action)
        return action
    }
}

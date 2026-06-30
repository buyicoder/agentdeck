import Foundation

struct SchedulerInput {
    let conversations: [ConversationSurface]
    let activeSide: DisplaySide
}

struct PromotionPlan {
    let conversationID: UUID
    let windowIdentity: String
    let targetSide: DisplaySide
    let event: String
}

enum ConversationScheduler {
    static func nextPromotion(_ input: SchedulerInput) -> PromotionPlan? {
        guard let targetSide = availableSide(input),
              let queued = input.conversations.first(where: { $0.status == .queued })
        else {
            return nil
        }

        return PromotionPlan(
            conversationID: queued.id,
            windowIdentity: queued.windowIdentity,
            targetSide: targetSide,
            event: "Promoted \"\(queued.conversationTitle)\" to \(targetSide.rawValue)."
        )
    }

    private static func availableSide(_ input: SchedulerInput) -> DisplaySide? {
        let preferred: DisplaySide = input.activeSide == .left ? .right : .left
        if visibleConversation(on: preferred, in: input.conversations) == nil {
            return preferred
        }
        if visibleConversation(on: input.activeSide, in: input.conversations) == nil {
            return input.activeSide
        }
        return nil
    }

    private static func visibleConversation(
        on side: DisplaySide,
        in conversations: [ConversationSurface]
    ) -> ConversationSurface? {
        conversations.first { item in
            item.side == side && (item.status == .editing || item.status == .displayed)
        }
    }
}

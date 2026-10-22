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
        guard let queued = input.conversations.first(where: { $0.status == .queued })
        else {
            return nil
        }
        let targetSide = targetSide(for: input)

        return PromotionPlan(
            conversationID: queued.id,
            windowIdentity: queued.windowIdentity,
            targetSide: targetSide,
            event: "已将「\(queued.conversationTitle)」弹出到\(targetSide.label)。"
        )
    }

    static func promotionBlockReason(_ input: SchedulerInput) -> String? {
        guard input.conversations.contains(where: { $0.status == .queued }) else {
            return "当前没有等待弹出的对话。"
        }
        return nil
    }

    private static func targetSide(for input: SchedulerInput) -> DisplaySide {
        input.activeSide == .left ? .right : .left
    }
}

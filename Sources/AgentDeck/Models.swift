import AppKit
import Foundation

enum ConversationStatus: String, CaseIterable, Identifiable {
    case editing
    case displayed
    case running
    case queued
    case hidden
    case inactive
    case unknown
    case done

    var id: String { rawValue }
}

struct ConversationSurface: Identifiable, Hashable {
    let id: UUID
    var appName: String
    var windowLabel: String
    var windowIdentity: String
    var conversationTitle: String
    var conversationKey: String
    var subtitle: String
    var status: ConversationStatus
    var location: String
    var age: String
    var side: DisplaySide?
    var detectorLevel: Int
    var detectorID: String
    var detectorConfidence: Double
}

enum ValidationStepStatus: String {
    case pending
    case passed
    case failed
    case skipped
}

struct ValidationStep: Identifiable, Hashable {
    let id: String
    var title: String
    var status: ValidationStepStatus
    var detail: String
}

enum DisplaySide: String, Identifiable {
    case left
    case right

    var id: String { rawValue }

    var label: String {
        switch self {
        case .left: "Left"
        case .right: "Right"
        }
    }
}

@Observable
@MainActor
final class ConversationStore {
    var activeSide: DisplaySide = .left
    var conversations: [ConversationSurface]
    var events: [String]
    var accessibilityTrusted: Bool
    var lastScanSummary: String
    var focusedWindowSummary: String
    var realWindowActionsEnabled: Bool
    var undoFrames: [WindowFrameSnapshot]
    var validationSteps: [ValidationStep]
    var lastValidationRunAt: Date?
    private var promotionCoordinator: PromotionCoordinator

    init(
        conversations: [ConversationSurface],
        events: [String] = [],
        promotionCoordinator: PromotionCoordinator = PromotionCoordinator()
    ) {
        self.conversations = conversations
        self.events = events
        self.accessibilityTrusted = AccessibilityTrust.isTrusted
        self.lastScanSummary = "Mock data"
        self.focusedWindowSummary = "Mock focus"
        self.realWindowActionsEnabled = false
        self.undoFrames = []
        self.validationSteps = Self.defaultValidationSteps()
        self.lastValidationRunAt = nil
        self.promotionCoordinator = promotionCoordinator
        normalizeQueue()
    }

    var queued: [ConversationSurface] {
        conversations.filter { $0.status == .queued }
    }

    var trackedCount: Int {
        conversations.filter { $0.status != .done }.count
    }

    var validationReport: String {
        let runAt = lastValidationRunAt.map(Self.validationDateFormatter.string(from:)) ?? "not run"
        let mode = realWindowActionsEnabled ? "real window actions" : "panel-only"
        let rows = validationSteps.map { step in
            "- \(step.title): \(step.status.rawValue) - \(step.detail)"
        }
        .joined(separator: "\n")

        return """
        AgentDeck Validation Report
        Run at: \(runAt)
        Mode: \(mode)
        Scan: \(lastScanSummary)
        Focus: \(focusedWindowSummary)
        Queued: \(queued.count)
        Undo frames: \(undoFrames.count)

        Steps:
        \(rows)
        """
    }

    func visibleConversation(on side: DisplaySide) -> ConversationSurface? {
        conversations.first { item in
            item.side == side && (item.status == .editing || item.status == .displayed)
        }
    }

    func setActiveSide(_ side: DisplaySide) {
        activeSide = side

        for index in conversations.indices where conversations[index].status == .editing {
            conversations[index].status = .displayed
        }

        if let index = conversations.firstIndex(where: { $0.side == side && ($0.status == .displayed || $0.status == .editing) }) {
            conversations[index].status = .editing
            conversations[index].location = "Main display / \(side.label)"
        }

        addEvent("Active editing side set to \(side.rawValue).")
        promoteIfPossible()
    }

    func markRunning(_ id: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        let oldSide = conversations[index].side
        let title = conversations[index].conversationTitle
        conversations[index].status = .running
        conversations[index].side = nil
        conversations[index].location = oldSide.map { "Freed \($0.rawValue) slot" } ?? "Background"
        addEvent("Conversation \"\(title)\" marked running.")
        promoteIfPossible()
    }

    func markDone(_ id: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        let title = conversations[index].conversationTitle
        conversations[index].status = .done
        conversations[index].side = nil
        conversations[index].location = "Done"
        addEvent("Conversation \"\(title)\" marked done.")
        promoteIfPossible()
    }

    func queue(_ id: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        let title = conversations[index].conversationTitle
        conversations[index].status = .queued
        conversations[index].side = nil
        conversations[index].location = "Hidden"
        addEvent("Conversation \"\(title)\" queued for review.")
        promoteIfPossible()
    }

    func promoteIfPossible() {
        let input = SchedulerInput(conversations: conversations, activeSide: activeSide)
        guard let plan = ConversationScheduler.nextPromotion(input),
              let queuedIndex = conversations.firstIndex(where: { $0.id == plan.conversationID })
        else {
            return
        }

        do {
            let action = try promotionCoordinator.perform(plan)
            if let undoFrame = action.undoFrame {
                undoFrames.insert(undoFrame, at: 0)
                if undoFrames.count > 20 {
                    undoFrames.removeLast()
                }
            }
        } catch {
            addEvent("Promotion failed: \(error.localizedDescription)")
            return
        }

        conversations[queuedIndex].status = .displayed
        conversations[queuedIndex].side = plan.targetSide
        conversations[queuedIndex].location = "Main display / \(plan.targetSide.label)"
        addEvent(plan.event)
    }

    func switchActiveConversation() {
        if let editingIndex = conversations.firstIndex(where: { $0.status == .editing }) {
            conversations[editingIndex].status = .inactive
            conversations[editingIndex].side = nil
            conversations[editingIndex].location = "\(conversations[editingIndex].windowLabel) / background conversation"
        }

        guard let targetIndex = conversations.firstIndex(where: { $0.conversationKey == "codex:w1:agentdeck-design" }) else { return }
        conversations[targetIndex].status = .editing
        conversations[targetIndex].side = activeSide
        conversations[targetIndex].location = "Main display / \(activeSide.label)"
        addEvent("Active conversation switched inside \(conversations[targetIndex].windowLabel).")
    }

    func refreshSnapshot() {
        accessibilityTrusted = AccessibilityTrust.isTrusted
        let snapshot = MacOSWindowFactProvider.snapshot()
        let mapped = snapshot.windows.map { fact in
            Self.conversationSurface(
                from: fact,
                focusedWindowID: snapshot.focusedWindow?.id,
                focusedSide: snapshot.focusedSide,
                detectorPipeline: DetectorPipeline()
            )
        }

        if mapped.isEmpty {
            addEvent("Window scan returned no visible app windows.")
            lastScanSummary = "0 windows detected"
            focusedWindowSummary = "No focused window detected"
            return
        }

        conversations = mergeDetectedConversations(mapped)
        if let side = snapshot.focusedSide {
            activeSide = side
        }
        lastScanSummary = "\(mapped.count) windows detected"
        focusedWindowSummary = snapshot.focusedWindow.map { "\($0.appName): \($0.title)" } ?? "No focused window detected"
        addEvent("Detected \(mapped.count) conversations from visible windows; focused side: \(snapshot.focusedSide?.rawValue ?? "unknown").")
    }

    func requestAccessibilityPermission() {
        accessibilityTrusted = AccessibilityTrust.requestIfNeeded()
        addEvent(accessibilityTrusted ? "Accessibility permission is trusted." : "Requested Accessibility permission.")
    }

    func setRealWindowActionsEnabled(_ enabled: Bool) {
        realWindowActionsEnabled = enabled
        if enabled {
            promotionCoordinator = PromotionCoordinator(performer: MacOSAccessibilityWindowActionPerformer())
            addEvent("Real window actions enabled. Promote will move windows.")
        } else {
            promotionCoordinator = PromotionCoordinator(performer: MockWindowActionPerformer())
            addEvent("Real window actions disabled. Promote updates panel state only.")
        }
    }

    func restoreLastWindowFrame() {
        guard let snapshot = undoFrames.first else {
            addEvent("No undo frame available.")
            return
        }

        do {
            try promotionCoordinator.performer.restore(snapshot)
            undoFrames.removeFirst()
            addEvent("Restored window \(snapshot.windowIdentity) to previous frame.")
        } catch {
            addEvent("Restore failed: \(error.localizedDescription)")
        }
    }

    func openTestWindow() {
        AgentDeckTestWindow.open()
        addEvent("Opened AgentDeck test conversation window. Click Scan to detect it.")
    }

    func runValidationMode() {
        validationSteps = Self.defaultValidationSteps()
        lastValidationRunAt = Date()
        setValidation("open", .passed, "Opened safe test window.")
        AgentDeckTestWindow.open()

        refreshSnapshot()
        setValidation("scan", conversations.isEmpty ? .failed : .passed, lastScanSummary)

        guard let testConversation = conversations.first(where: { item in
            item.conversationTitle.localizedCaseInsensitiveContains("AgentDeck Test Conversation")
                || item.windowLabel.localizedCaseInsensitiveContains("AgentDeck Test Conversation")
        }) else {
            setValidation("detect", .failed, "Test conversation row was not found after scan.")
            setValidation("queue", .skipped, "Detection failed.")
            setValidation("promote", .skipped, "Detection failed.")
            setValidation("restore", .skipped, "Detection failed.")
            addEvent("Validation failed: test conversation was not detected.")
            return
        }

        setValidation("detect", .passed, "Detected row: \(testConversation.appName) / \(testConversation.conversationTitle).")
        setQueuedWithoutPromotion(testConversation.id)
        setValidation("queue", .passed, "Queued test conversation.")

        if !realWindowActionsEnabled {
            promoteIfPossible()
            setValidation("promote", .skipped, "Move windows is off; panel state promotion only.")
            setValidation("restore", .skipped, "No real move was attempted.")
            addEvent("Validation completed in mock mode.")
            return
        }

        let undoCountBefore = undoFrames.count
        promoteIfPossible()
        if undoFrames.count > undoCountBefore {
            setValidation("promote", .passed, "Promoted test window and captured undo frame.")
        } else {
            setValidation("promote", .failed, "Promotion did not capture an undo frame.")
            setValidation("restore", .skipped, "Promotion failed.")
            return
        }

        restoreLastWindowFrame()
        setValidation("restore", undoFrames.count < undoCountBefore + 1 ? .passed : .failed, "Restore attempted using latest undo frame.")
    }

    func copyValidationReportToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(validationReport, forType: .string)
        addEvent("Copied validation report to clipboard.")
    }

    private func setQueuedWithoutPromotion(_ id: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        let title = conversations[index].conversationTitle
        conversations[index].status = .queued
        conversations[index].side = nil
        conversations[index].location = "Hidden"
        addEvent("Validation queued \"\(title)\" without auto-promote.")
    }

    private func normalizeQueue() {
        conversations.sort { lhs, rhs in
            if lhs.status == .done && rhs.status != .done { return false }
            if lhs.status != .done && rhs.status == .done { return true }
            return lhs.age < rhs.age
        }
    }

    private func addEvent(_ message: String) {
        events.insert(message, at: 0)
        if events.count > 8 {
            events.removeLast()
        }
    }

    private func mergeDetectedConversations(_ detected: [ConversationSurface]) -> [ConversationSurface] {
        var merged: [ConversationSurface] = []
        var previousByKey: [String: ConversationSurface] = [:]
        for item in conversations {
            previousByKey[item.conversationKey] = item
        }
        let detectedWindowIdentities = Set(detected.map(\.windowIdentity))
        let detectedKeys = Set(detected.map(\.conversationKey))

        for item in detected {
            if var existing = previousByKey[item.conversationKey] {
                existing.appName = item.appName
                existing.windowLabel = item.windowLabel
                existing.windowIdentity = item.windowIdentity
                existing.conversationTitle = item.conversationTitle
                existing.subtitle = item.subtitle
                existing.status = item.status
                existing.location = item.location
                existing.age = item.age
                existing.side = item.side
                existing.detectorLevel = item.detectorLevel
                existing.detectorID = item.detectorID
                existing.detectorConfidence = item.detectorConfidence
                merged.append(existing)
                previousByKey[item.conversationKey] = nil
            } else {
                if conversations.contains(where: { $0.windowIdentity == item.windowIdentity && $0.conversationKey != item.conversationKey }) {
                    addEvent("Conversation changed inside \(item.windowLabel): \"\(item.conversationTitle)\".")
                }
                merged.append(item)
            }
        }

        for var previous in previousByKey.values {
            guard previous.status != .done else { continue }

            if detectedWindowIdentities.contains(previous.windowIdentity)
                && !detectedKeys.contains(previous.conversationKey)
            {
                previous.status = .inactive
                previous.side = nil
                previous.location = "\(previous.windowLabel) / inactive conversation"
                merged.append(previous)
            } else if previous.status == .queued {
                merged.append(previous)
            }
        }

        return merged.sorted { lhs, rhs in
            statusRank(lhs.status) < statusRank(rhs.status)
        }
    }

    private func statusRank(_ status: ConversationStatus) -> Int {
        switch status {
        case .editing: 0
        case .displayed: 1
        case .queued: 2
        case .running: 3
        case .unknown: 4
        case .hidden: 5
        case .inactive: 6
        case .done: 7
        }
    }

    private func setValidation(_ id: String, _ status: ValidationStepStatus, _ detail: String) {
        guard let index = validationSteps.firstIndex(where: { $0.id == id }) else { return }
        validationSteps[index].status = status
        validationSteps[index].detail = detail
    }

    private static func defaultValidationSteps() -> [ValidationStep] {
        [
            ValidationStep(id: "open", title: "Open test window", status: .pending, detail: "Waiting"),
            ValidationStep(id: "scan", title: "Scan windows", status: .pending, detail: "Waiting"),
            ValidationStep(id: "detect", title: "Detect test conversation", status: .pending, detail: "Waiting"),
            ValidationStep(id: "queue", title: "Queue test conversation", status: .pending, detail: "Waiting"),
            ValidationStep(id: "promote", title: "Promote test conversation", status: .pending, detail: "Waiting"),
            ValidationStep(id: "restore", title: "Restore test window", status: .pending, detail: "Waiting")
        ]
    }

    private static let validationDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func conversationSurface(
        from fact: WindowFact,
        focusedWindowID: String?,
        focusedSide: DisplaySide?,
        detectorPipeline: DetectorPipeline
    ) -> ConversationSurface {
        let isFocused = fact.id == focusedWindowID
        let detection = detectorPipeline.detect(
            DetectionContext(
                fact: fact,
                focusedWindowID: focusedWindowID,
                focusedSide: focusedSide
            )
        )
        return ConversationSurface(
            id: UUID(),
            appName: fact.appName,
            windowLabel: "Window \(fact.windowNumber)",
            windowIdentity: "\(fact.ownerPID)-\(fact.windowNumber)",
            conversationTitle: detection.title,
            conversationKey: detection.conversationKey,
            subtitle: detection.subtitle,
            status: isFocused ? .editing : .unknown,
            location: fact.displayLabel,
            age: "now",
            side: isFocused ? focusedSide : nil,
            detectorLevel: detection.detectorLevel,
            detectorID: detection.detectorID,
            detectorConfidence: detection.confidence
        )
    }
}

extension ConversationStore {
    static let preview = ConversationStore(
        conversations: [
            ConversationSurface(
                id: UUID(),
                appName: "Cursor",
                windowLabel: "Cursor window 1",
                windowIdentity: "mock-cursor-window-1",
                conversationTitle: "AgentDeck prototype",
                conversationKey: "cursor:w1:agentdeck-prototype",
                subtitle: "Editing product UI",
                status: .editing,
                location: "Main display / Left",
                age: "now",
                side: .left,
                detectorLevel: 2,
                detectorID: "mock-cursor",
                detectorConfidence: 0.8
            ),
            ConversationSurface(
                id: UUID(),
                appName: "WorkBuddy",
                windowLabel: "WorkBuddy window 1",
                windowIdentity: "mock-workbuddy-window-1",
                conversationTitle: "Jarvis delivery thread",
                conversationKey: "workbuddy:w1:thread-4537",
                subtitle: "Waiting for review",
                status: .displayed,
                location: "Main display / Right",
                age: "3m",
                side: .right,
                detectorLevel: 2,
                detectorID: "mock-workbuddy",
                detectorConfidence: 0.78
            ),
            ConversationSurface(
                id: UUID(),
                appName: "Codex",
                windowLabel: "Codex window 1",
                windowIdentity: "mock-codex-window-1",
                conversationTitle: "AIZZ markdown audit",
                conversationKey: "codex:w1:aizz-markdown",
                subtitle: "Running background task",
                status: .running,
                location: "External display 1",
                age: "11m",
                side: nil,
                detectorLevel: 1,
                detectorID: "mock-title",
                detectorConfidence: 0.55
            ),
            ConversationSurface(
                id: UUID(),
                appName: "Codex",
                windowLabel: "Codex window 1",
                windowIdentity: "mock-codex-window-1",
                conversationTitle: "AgentDeck product design",
                conversationKey: "codex:w1:agentdeck-design",
                subtitle: "Same Codex window, different conversation",
                status: .inactive,
                location: "Codex window 1 / background thread",
                age: "13m",
                side: nil,
                detectorLevel: 2,
                detectorID: "mock-codex",
                detectorConfidence: 0.82
            ),
            ConversationSurface(
                id: UUID(),
                appName: "Claude Code",
                windowLabel: "Terminal tab 2",
                windowIdentity: "mock-terminal-tab-2",
                conversationTitle: "Hammerspoon detector",
                conversationKey: "terminal:tab2:hammerspoon-detector",
                subtitle: "Needs human instruction",
                status: .queued,
                location: "Hidden",
                age: "18m",
                side: nil,
                detectorLevel: 1,
                detectorID: "mock-terminal",
                detectorConfidence: 0.5
            ),
            ConversationSurface(
                id: UUID(),
                appName: "Chrome",
                windowLabel: "Chrome window 3 / tab 8",
                windowIdentity: "mock-chrome-window-3-tab-8",
                conversationTitle: "Agent browser preview",
                conversationKey: "chrome:w3:t8:agent-browser-preview",
                subtitle: "Browser tab conversation",
                status: .hidden,
                location: "External display 2",
                age: "24m",
                side: nil,
                detectorLevel: 2,
                detectorID: "mock-browser",
                detectorConfidence: 0.75
            )
        ],
        events: ["Native panel loaded with mock conversation state."]
    )
}

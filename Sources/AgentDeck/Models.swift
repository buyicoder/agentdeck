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

struct TrackedAppRule: Identifiable, Hashable, Codable {
    let name: String
    var isEnabled: Bool

    var id: String { name }
}

struct WorkbenchState: Hashable {
    var editingSide: DisplaySide?
    var focusedConversationID: UUID?
    var focusedWindowIdentity: String?
    var summary: String

    static let sample = WorkbenchState(
        editingSide: nil,
        focusedConversationID: nil,
        focusedWindowIdentity: nil,
        summary: "尚无实时编辑侧"
    )
}

enum DisplaySide: String, Identifiable {
    case left
    case right

    var id: String { rawValue }

    var label: String {
        switch self {
        case .left: "左侧"
        case .right: "右侧"
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
    var trackAllApps: Bool
    var trackedAppRules: [TrackedAppRule]
    var ignoredConversationKeys: Set<String>
    var selectedConversationID: UUID?
    var workbenchState: WorkbenchState
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
        let settings = Self.loadSettings()
        self.trackAllApps = settings.trackAllApps
        self.trackedAppRules = settings.trackedAppRules
        self.ignoredConversationKeys = settings.ignoredConversationKeys
        self.selectedConversationID = nil
        self.workbenchState = .sample
        self.promotionCoordinator = promotionCoordinator
        normalizeQueue()
    }

    var queued: [ConversationSurface] {
        conversations.filter { $0.status == .queued }
    }

    var promotionBlockReason: String? {
        ConversationScheduler.promotionBlockReason(
            SchedulerInput(conversations: conversations, activeSide: schedulerActiveSide)
        )
    }

    var promotionActionLabel: String {
        guard promotionBlockReason != nil else { return "弹出下一项" }
        return "暂无队列"
    }

    var trackedCount: Int {
        conversations.filter { $0.status != .done }.count
    }

    var enabledTrackedApps: [String] {
        trackedAppRules.filter(\.isEnabled).map(\.name)
    }

    var trackedAppSummary: String {
        if trackAllApps {
            return "所有可见 App"
        }
        let count = enabledTrackedApps.count
        return "\(count) 个已选 App"
    }

    var validationReport: String {
        let runAt = lastValidationRunAt.map(Self.validationDateFormatter.string(from:)) ?? "尚未运行"
        let mode = realWindowActionsEnabled ? "真实窗口移动" : "仅更新面板"
        let rows = validationSteps.map { step in
            "- \(step.title): \(Self.validationStatusLabel(step.status)) - \(step.detail)"
        }
        .joined(separator: "\n")

        return """
        AgentDeck 验证报告
        运行时间：\(runAt)
        模式：\(mode)
        扫描：\(localizedScanSummary)
        焦点：\(localizedFocusedWindowSummary)
        队列：\(queued.count)
        可撤销帧：\(undoFrames.count)

        步骤：
        \(rows)
        """
    }

    func visibleConversation(on side: DisplaySide) -> ConversationSurface? {
        guard workbenchState.editingSide == side,
              let focusedID = workbenchState.focusedConversationID
        else { return nil }
        return conversations.first { $0.id == focusedID }
    }

    private var localizedScanSummary: String {
        if lastScanSummary == "Mock data" { return "样例数据" }
        return lastScanSummary
            .replacingOccurrences(of: "windows detected", with: "个窗口")
            .replacingOccurrences(of: "tracked", with: "个已追踪")
            .replacingOccurrences(of: " of ", with: " / ")
    }

    private var localizedFocusedWindowSummary: String {
        focusedWindowSummary == "Mock focus" ? "尚无真实焦点" : focusedWindowSummary
    }

    func queueCommandTarget() {
        guard let id = commandTargetID() else {
            addEvent("没有可入队的选中或活跃对话。")
            return
        }
        queue(id)
    }

    func markRunningCommandTarget() {
        guard let id = commandTargetID() else {
            addEvent("没有可标记运行中的选中或活跃对话。")
            return
        }
        markRunning(id)
    }

    func markDoneCommandTarget() {
        guard let id = commandTargetID() else {
            addEvent("没有可标记完成的选中或活跃对话。")
            return
        }
        markDone(id)
    }

    func setActiveSide(_ side: DisplaySide) {
        activeSide = side
        workbenchState.editingSide = side

        for index in conversations.indices where conversations[index].status == .editing {
            conversations[index].status = .displayed
        }

        if let index = conversations.firstIndex(where: { $0.side == side && ($0.status == .displayed || $0.status == .editing) }) {
            conversations[index].status = .editing
            conversations[index].location = "主屏 / \(side.label)"
        }

        addEvent("已将编辑侧设为\(side.label)。")
        promoteIfPossible()
    }

    func markRunning(_ id: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        let oldSide = conversations[index].side
        let title = conversations[index].conversationTitle
        conversations[index].status = .running
        conversations[index].side = nil
        conversations[index].location = oldSide.map { "已释放\($0.label)槽位" } ?? "后台"
        addEvent("已将「\(title)」标记为运行中。")
        promoteIfPossible()
    }

    func markDone(_ id: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        let title = conversations[index].conversationTitle
        conversations[index].status = .done
        conversations[index].side = nil
        conversations[index].location = "完成"
        addEvent("已将「\(title)」标记为完成。")
        promoteIfPossible()
    }

    func queue(_ id: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        let title = conversations[index].conversationTitle
        conversations[index].status = .queued
        conversations[index].side = nil
        conversations[index].location = "已隐藏"
        addEvent("已将「\(title)」加入审阅队列。")
        promoteIfPossible()
    }

    func setTrackAllApps(_ enabled: Bool) {
        trackAllApps = enabled
        addEvent(enabled ? "正在追踪所有可见 App。" : "仅追踪选中的 App。")
        applySettingsToCurrentConversations()
        saveSettings()
    }

    func toggleTrackedApp(_ appName: String) {
        if let index = trackedAppRules.firstIndex(where: { Self.normalizedAppName($0.name) == Self.normalizedAppName(appName) }) {
            trackedAppRules[index].isEnabled.toggle()
            addEvent("\(trackedAppRules[index].name) 追踪已\(trackedAppRules[index].isEnabled ? "开启" : "关闭")。")
        } else {
            trackedAppRules.append(TrackedAppRule(name: appName, isEnabled: true))
            trackedAppRules.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            addEvent("已将 \(appName) 加入追踪 App。")
        }
        applySettingsToCurrentConversations()
        saveSettings()
    }

    func addTrackedApp(_ appName: String) {
        let cleaned = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        if trackedAppRules.contains(where: { Self.normalizedAppName($0.name) == Self.normalizedAppName(cleaned) }) {
            addEvent("\(cleaned) 已在追踪 App 列表中。")
            return
        }
        trackedAppRules.append(TrackedAppRule(name: cleaned, isEnabled: true))
        trackedAppRules.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        addEvent("已将 \(cleaned) 加入追踪 App。")
        saveSettings()
    }

    func ignoreConversation(_ id: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        let item = conversations[index]
        ignoredConversationKeys.insert(item.conversationKey)
        conversations.remove(at: index)
        if selectedConversationID == id {
            selectedConversationID = nil
        }
        addEvent("已忽略对话「\(item.conversationTitle)」。")
        saveSettings()
    }

    func unignoreConversationKey(_ key: String) {
        ignoredConversationKeys.remove(key)
        addEvent("已移除忽略规则。")
        saveSettings()
    }

    func clearIgnoredConversations() {
        ignoredConversationKeys.removeAll()
        addEvent("已清空忽略规则。")
        saveSettings()
    }

    func promoteIfPossible() {
        let input = SchedulerInput(conversations: conversations, activeSide: schedulerActiveSide)
        guard let plan = ConversationScheduler.nextPromotion(input),
              let queuedIndex = conversations.firstIndex(where: { $0.id == plan.conversationID })
        else {
            addEvent(promotionBlockReason ?? "当前无法弹出下一项。")
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
            addEvent("弹出失败：\(error.localizedDescription)")
            return
        }

        clearDisplaySlot(on: plan.targetSide)
        conversations[queuedIndex].status = .displayed
        conversations[queuedIndex].side = plan.targetSide
        conversations[queuedIndex].location = "主屏 / \(plan.targetSide.label)"
        addEvent(plan.event)
    }

    func switchActiveConversation() {
        if let editingIndex = conversations.firstIndex(where: { $0.status == .editing }) {
            conversations[editingIndex].status = .inactive
            conversations[editingIndex].side = nil
            conversations[editingIndex].location = "\(conversations[editingIndex].windowLabel) / 后台对话"
        }

        guard let targetIndex = conversations.firstIndex(where: { $0.conversationKey == "codex:w1:agentdeck-design" }) else { return }
        conversations[targetIndex].status = .editing
        conversations[targetIndex].side = activeSide
        conversations[targetIndex].location = "主屏 / \(activeSide.label)"
        addEvent("已切换 \(conversations[targetIndex].windowLabel) 内的活跃对话。")
    }

    func refreshSnapshot() {
        accessibilityTrusted = AccessibilityTrust.isTrusted
        let snapshot = MacOSWindowFactProvider.snapshot()
        let trackedFacts = snapshot.windows.filter { isTrackedApp($0.appName) }
        let mapped = trackedFacts.map { fact in
            Self.conversationSurface(
                from: fact,
                focusedWindowID: snapshot.focusedWindow?.id,
                focusedSide: snapshot.focusedSide,
                detectorPipeline: DetectorPipeline()
            )
        }
        let filtered = mapped.filter { !ignoredConversationKeys.contains($0.conversationKey) }
        updateWorkbenchState(from: snapshot, detected: filtered)

        if filtered.isEmpty {
            addEvent(snapshot.windows.isEmpty ? "扫描未发现可见 App 窗口。" : "扫描后没有符合追踪规则的对话。")
            lastScanSummary = snapshot.windows.isEmpty ? "0 个窗口" : "0 / \(snapshot.windows.count) 个已追踪"
            focusedWindowSummary = "未检测到焦点窗口"
            conversations = conversations.filter { ignoredConversationKeys.contains($0.conversationKey) == false && isTrackedApp($0.appName) }
            return
        }

        conversations = mergeDetectedConversations(filtered)
        lastScanSummary = filtered.count == snapshot.windows.count ? "\(snapshot.windows.count) 个窗口" : "\(filtered.count) / \(snapshot.windows.count) 个已追踪"
        focusedWindowSummary = snapshot.focusedWindow.map { "\($0.appName): \($0.title)" } ?? "未检测到焦点窗口"
        updateWorkbenchState(from: snapshot, detected: conversations)
        addEvent("从 \(snapshot.windows.count) 个可见窗口中识别到 \(filtered.count) 个已追踪对话；编辑侧：\(workbenchState.editingSide?.label ?? "未占用")。")
    }

    func requestAccessibilityPermission() {
        accessibilityTrusted = AccessibilityTrust.requestIfNeeded()
        addEvent(accessibilityTrusted ? "辅助功能权限已就绪。" : "已请求辅助功能权限。")
    }

    func setRealWindowActionsEnabled(_ enabled: Bool) {
        realWindowActionsEnabled = enabled
        if enabled {
            promotionCoordinator = PromotionCoordinator(performer: MacOSAccessibilityWindowActionPerformer())
            addEvent("已允许移动真实窗口。弹出操作将移动窗口。")
        } else {
            promotionCoordinator = PromotionCoordinator(performer: MockWindowActionPerformer())
            addEvent("已关闭真实窗口移动。弹出操作仅更新面板状态。")
        }
    }

    func restoreLastWindowFrame() {
        guard let snapshot = undoFrames.first else {
            addEvent("没有可撤销的窗口移动。")
            return
        }

        do {
            try promotionCoordinator.performer.restore(snapshot)
            undoFrames.removeFirst()
            addEvent("已将窗口 \(snapshot.windowIdentity) 恢复到之前位置。")
        } catch {
            addEvent("恢复失败：\(error.localizedDescription)")
        }
    }

    func openTestWindow() {
        AgentDeckTestWindow.open()
        addEvent("已打开 AgentDeck 测试对话窗口。点击扫描即可识别。")
    }

    func runValidationMode() {
        validationSteps = Self.defaultValidationSteps()
        lastValidationRunAt = Date()
        setValidation("open", .passed, "已打开安全测试窗口。")
        AgentDeckTestWindow.open()

        refreshSnapshot()
        setValidation("scan", conversations.isEmpty ? .failed : .passed, localizedScanSummary)

        guard let testConversation = conversations.first(where: { item in
            item.conversationTitle.localizedCaseInsensitiveContains("AgentDeck Test Conversation")
                || item.windowLabel.localizedCaseInsensitiveContains("AgentDeck Test Conversation")
        }) else {
            setValidation("detect", .failed, "扫描后没有找到测试对话行。")
            setValidation("queue", .skipped, "识别失败，已跳过。")
            setValidation("promote", .skipped, "识别失败，已跳过。")
            setValidation("restore", .skipped, "识别失败，已跳过。")
            addEvent("验证失败：没有识别到测试对话。")
            return
        }

        setValidation("detect", .passed, "已识别：\(testConversation.appName) / \(testConversation.conversationTitle)。")
        setQueuedWithoutPromotion(testConversation.id)
        setValidation("queue", .passed, "已将测试对话加入队列。")

        if !realWindowActionsEnabled {
            promoteIfPossible()
            setValidation("promote", .skipped, "真实窗口移动未开启，仅验证面板状态。")
            setValidation("restore", .skipped, "没有执行真实移动。")
            addEvent("验证已在面板模式完成。")
            return
        }

        let undoCountBefore = undoFrames.count
        promoteIfPossible()
        if undoFrames.count > undoCountBefore {
            setValidation("promote", .passed, "已弹出测试窗口，并记录撤销帧。")
        } else {
            setValidation("promote", .failed, "弹出后没有记录撤销帧。")
            setValidation("restore", .skipped, "弹出失败，已跳过。")
            return
        }

        restoreLastWindowFrame()
        setValidation("restore", undoFrames.count < undoCountBefore + 1 ? .passed : .failed, "已尝试使用最新撤销帧恢复窗口。")
    }

    func copyValidationReportToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(validationReport, forType: .string)
        addEvent("已复制验证报告。")
    }

    private func setQueuedWithoutPromotion(_ id: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        let title = conversations[index].conversationTitle
        conversations[index].status = .queued
        conversations[index].side = nil
        conversations[index].location = "已隐藏"
        addEvent("验证已将「\(title)」加入队列，未自动弹出。")
    }

    private func commandTargetID() -> UUID? {
        if let selectedConversationID,
           conversations.contains(where: { $0.id == selectedConversationID }) {
            return selectedConversationID
        }
        if let editing = conversations.first(where: { $0.status == .editing }) {
            return editing.id
        }
        if let activeSlot = conversations.first(where: { item in
            item.side == activeSide && (item.status == .displayed || item.status == .editing)
        }) {
            return activeSlot.id
        }
        return nil
    }

    private func applySettingsToCurrentConversations() {
        conversations = conversations.filter { item in
            isTrackedApp(item.appName) && !ignoredConversationKeys.contains(item.conversationKey)
        }
        if let selectedConversationID,
           !conversations.contains(where: { $0.id == selectedConversationID }) {
            self.selectedConversationID = nil
        }
    }

    private func isTrackedApp(_ appName: String) -> Bool {
        if Self.isSelfApp(appName) { return false }
        if trackAllApps { return true }
        let normalized = Self.normalizedAppName(appName)
        return trackedAppRules.contains { rule in
            rule.isEnabled && Self.normalizedAppName(rule.name) == normalized
        }
    }

    private var schedulerActiveSide: DisplaySide {
        workbenchState.editingSide ?? activeSide
    }

    private func updateWorkbenchState(from snapshot: WindowSnapshot, detected: [ConversationSurface]) {
        guard let focused = snapshot.focusedWindow else {
            workbenchState = WorkbenchState(
                editingSide: nil,
                focusedConversationID: nil,
                focusedWindowIdentity: nil,
                summary: "当前焦点不是可调度 agent，主屏未占用"
            )
            return
        }

        if Self.isSelfApp(focused.appName) {
            workbenchState.summary = workbenchState.editingSide == nil
                ? "AgentDeck 面板前台；主屏未占用"
                : "AgentDeck 面板前台；保留上次 agent 编辑侧"
            return
        }

        guard isTrackedApp(focused.appName),
              let focusedSide = snapshot.focusedSide
        else {
            workbenchState = WorkbenchState(
                editingSide: nil,
                focusedConversationID: nil,
                focusedWindowIdentity: nil,
                summary: "当前焦点不是可调度 agent，主屏未占用"
            )
            return
        }

        let focusedIdentity = "\(focused.ownerPID)-\(focused.windowNumber)"
        let focusedConversation = detected.first { $0.windowIdentity == focusedIdentity }
        activeSide = focusedSide
        workbenchState = WorkbenchState(
            editingSide: focusedSide,
            focusedConversationID: focusedConversation?.id,
            focusedWindowIdentity: focusedIdentity,
            summary: "\(focused.appName) / \(focused.title)"
        )
    }

    private func clearDisplaySlot(on side: DisplaySide) {
        for index in conversations.indices where conversations[index].side == side && conversations[index].status == .displayed {
            conversations[index].side = nil
            conversations[index].status = .running
            conversations[index].location = "后台"
        }
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
                    addEvent("\(item.windowLabel) 内的对话已切换为「\(item.conversationTitle)」。")
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
                previous.location = "\(previous.windowLabel) / 非活跃对话"
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
            ValidationStep(id: "open", title: "打开测试窗口", status: .pending, detail: "等待中"),
            ValidationStep(id: "scan", title: "扫描窗口", status: .pending, detail: "等待中"),
            ValidationStep(id: "detect", title: "识别测试对话", status: .pending, detail: "等待中"),
            ValidationStep(id: "queue", title: "测试对话入队", status: .pending, detail: "等待中"),
            ValidationStep(id: "promote", title: "弹出测试对话", status: .pending, detail: "等待中"),
            ValidationStep(id: "restore", title: "恢复测试窗口", status: .pending, detail: "等待中")
        ]
    }

    private static func validationStatusLabel(_ status: ValidationStepStatus) -> String {
        switch status {
        case .pending: "等待中"
        case .passed: "通过"
        case .failed: "失败"
        case .skipped: "跳过"
        }
    }

    private static func defaultTrackedAppRules() -> [TrackedAppRule] {
        [
            ("Codex", true),
            ("Cursor", true),
            ("WorkBuddy", true),
            ("Claude Code", true),
            ("Terminal", true),
            ("iTerm2", true),
            ("Google Chrome", false),
            ("Chrome", false),
            ("Safari", false),
            ("Microsoft Edge", false)
        ].map { TrackedAppRule(name: $0.0, isEnabled: $0.1) }
    }

    private static func normalizedAppName(_ appName: String) -> String {
        appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func isSelfApp(_ appName: String) -> Bool {
        normalizedAppName(appName) == "agentdeck"
    }

    private struct StoredSettings: Codable {
        var trackAllApps: Bool
        var trackedAppRules: [TrackedAppRule]
        var ignoredConversationKeys: Set<String>
    }

    private func saveSettings() {
        let settings = StoredSettings(
            trackAllApps: trackAllApps,
            trackedAppRules: trackedAppRules,
            ignoredConversationKeys: ignoredConversationKeys
        )
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: settingsDefaultsKey)
    }

    private static func loadSettings() -> StoredSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsDefaultsKey),
              let settings = try? JSONDecoder().decode(StoredSettings.self, from: data)
        else {
            return StoredSettings(
                trackAllApps: false,
                trackedAppRules: defaultTrackedAppRules(),
                ignoredConversationKeys: []
            )
        }

        return StoredSettings(
            trackAllApps: settings.trackAllApps,
            trackedAppRules: settings.trackedAppRules.isEmpty ? defaultTrackedAppRules() : settings.trackedAppRules,
            ignoredConversationKeys: settings.ignoredConversationKeys
        )
    }

    private var settingsDefaultsKey: String {
        Self.settingsDefaultsKey
    }

    private static let settingsDefaultsKey = "agentdeck.settings.v2"

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
            windowLabel: "窗口 \(fact.windowNumber)",
            windowIdentity: "\(fact.ownerPID)-\(fact.windowNumber)",
            conversationTitle: detection.title,
            conversationKey: detection.conversationKey,
            subtitle: detection.subtitle,
            status: isFocused ? .editing : .unknown,
            location: fact.displayLabel,
            age: "刚刚",
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
                windowLabel: "Cursor 窗口 1",
                windowIdentity: "mock-cursor-window-1",
                conversationTitle: "AgentDeck 原型",
                conversationKey: "cursor:w1:agentdeck-prototype",
                subtitle: "正在编辑产品界面",
                status: .editing,
                location: "主屏 / 左侧",
                age: "刚刚",
                side: .left,
                detectorLevel: 2,
                detectorID: "mock-cursor",
                detectorConfidence: 0.8
            ),
            ConversationSurface(
                id: UUID(),
                appName: "WorkBuddy",
                windowLabel: "WorkBuddy 窗口 1",
                windowIdentity: "mock-workbuddy-window-1",
                conversationTitle: "Jarvis 交付线程",
                conversationKey: "workbuddy:w1:thread-4537",
                subtitle: "等待审阅",
                status: .displayed,
                location: "主屏 / 右侧",
                age: "3m",
                side: .right,
                detectorLevel: 2,
                detectorID: "mock-workbuddy",
                detectorConfidence: 0.78
            ),
            ConversationSurface(
                id: UUID(),
                appName: "Codex",
                windowLabel: "Codex 窗口 1",
                windowIdentity: "mock-codex-window-1",
                conversationTitle: "AIZZ Markdown 审计",
                conversationKey: "codex:w1:aizz-markdown",
                subtitle: "后台任务运行中",
                status: .running,
                location: "外接屏 1",
                age: "11m",
                side: nil,
                detectorLevel: 1,
                detectorID: "mock-title",
                detectorConfidence: 0.55
            ),
            ConversationSurface(
                id: UUID(),
                appName: "Codex",
                windowLabel: "Codex 窗口 1",
                windowIdentity: "mock-codex-window-1",
                conversationTitle: "AgentDeck 产品设计",
                conversationKey: "codex:w1:agentdeck-design",
                subtitle: "同一个 Codex 窗口内的另一个对话",
                status: .inactive,
                location: "Codex 窗口 1 / 后台线程",
                age: "13m",
                side: nil,
                detectorLevel: 2,
                detectorID: "mock-codex",
                detectorConfidence: 0.82
            ),
            ConversationSurface(
                id: UUID(),
                appName: "Claude Code",
                windowLabel: "Terminal 标签页 2",
                windowIdentity: "mock-terminal-tab-2",
                conversationTitle: "Hammerspoon 识别器",
                conversationKey: "terminal:tab2:hammerspoon-detector",
                subtitle: "需要人工确认",
                status: .queued,
                location: "已隐藏",
                age: "18m",
                side: nil,
                detectorLevel: 1,
                detectorID: "mock-terminal",
                detectorConfidence: 0.5
            ),
            ConversationSurface(
                id: UUID(),
                appName: "Chrome",
                windowLabel: "Chrome 窗口 3 / 标签页 8",
                windowIdentity: "mock-chrome-window-3-tab-8",
                conversationTitle: "Agent 浏览器预览",
                conversationKey: "chrome:w3:t8:agent-browser-preview",
                subtitle: "浏览器标签页对话",
                status: .hidden,
                location: "外接屏 2",
                age: "24m",
                side: nil,
                detectorLevel: 2,
                detectorID: "mock-browser",
                detectorConfidence: 0.75
            )
        ],
        events: ["已加载原生面板样例对话状态。"]
    )
}

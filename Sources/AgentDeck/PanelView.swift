import AppKit
import SwiftUI

private enum PanelMode: String, CaseIterable, Identifiable {
    case daily = "日常"
    case setup = "设置向导"
    case diagnostics = "诊断"
    case settings = "偏好"

    var id: String { rawValue }
}

struct AgentDeckPanelView: View {
    @Bindable var store: ConversationStore
    @State private var mode: PanelMode = .daily
    @State private var newTrackedAppName = ""

    var body: some View {
        VStack(spacing: 14) {
            topBar
            modeTabs

            ScrollView {
                modeContent
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .id(mode)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(18)
        .frame(minWidth: 1120, minHeight: 720, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var modeContent: some View {
        switch mode {
        case .daily:
            dailyDashboard
        case .setup:
            setupView
        case .diagnostics:
            diagnosticsView
        case .settings:
            settingsView
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.teal.opacity(0.92))
                .frame(width: 42, height: 42)
                .overlay(Text("AD").font(.headline).foregroundStyle(.white))

            VStack(alignment: .leading, spacing: 2) {
                Text("AgentDeck")
                    .font(.title2.bold())
                Text(topStatusLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if sampleMode {
                Label("样例模式", systemImage: "shippingbox")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
            }

            Button {
                store.refreshSnapshot()
            } label: {
                Label("扫描", systemImage: "arrow.clockwise")
            }
            .frame(height: 30)

            Button {
                store.promoteIfPossible()
            } label: {
                Label(store.promotionActionLabel, systemImage: "arrow.up.forward")
            }
            .frame(height: 30)
            .keyboardShortcut("p", modifiers: [.control, .option])
            .help(store.promotionBlockReason ?? "将队首对话弹出到空闲槽位")

            Button {
                mode = .setup
            } label: {
                Image(systemName: store.accessibilityTrusted ? "checkmark.shield" : "exclamationmark.shield")
            }
            .frame(width: 30, height: 30)
            .help("设置向导")

            Button {
                mode = .settings
            } label: {
                Image(systemName: "gearshape")
            }
            .frame(width: 30, height: 30)
            .help("偏好设置")
        }
        .padding(14)
        .frame(minHeight: 70, maxHeight: 70)
        .background(panelBackground)
    }

    private var modeTabs: some View {
        Picker("模式", selection: $mode) {
            ForEach(PanelMode.allCases) { item in
                Text(item.rawValue).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 520)
        .frame(height: 32)
    }

    private var dailyDashboard: some View {
        VStack(spacing: 14) {
            dailyHealthStrip

            HStack(alignment: .top, spacing: 14) {
                conversationWorklist
                    .frame(minWidth: 640, maxWidth: .infinity)

                VStack(spacing: 14) {
                    primaryDisplayPanel
                    displayOverviewPanel
                    nextQueuePanel
                }
                .frame(width: 360)
            }

            recentDecisionsPanel
        }
    }

    private var dailyHealthStrip: some View {
        HStack(spacing: 10) {
            HealthTile(
                title: "权限",
                value: store.accessibilityTrusted ? "已就绪" : "需要授权",
                detail: store.accessibilityTrusted ? "可以扫描窗口" : "先完成设置向导",
                systemImage: store.accessibilityTrusted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                tone: store.accessibilityTrusted ? .ok : .warning
            )

            HealthTile(
                title: "扫描",
                value: scanSummaryValue,
                detail: scanHealthDetail,
                systemImage: scanHealthTone == .ok ? "waveform.path.ecg" : "magnifyingglass",
                tone: scanHealthTone
            )

            HealthTile(
                title: "队列",
                value: "\(store.queued.count) 个待审阅",
                detail: reviewHealthDetail,
                systemImage: store.queued.isEmpty ? "tray" : "tray.full.fill",
                tone: store.queued.isEmpty ? .neutral : .ok
            )

            HealthTile(
                title: "识别",
                value: detectorHealthValue,
                detail: detectorHealthDetail,
                systemImage: detectorHealthTone == .warning ? "exclamationmark.bubble" : "checkmark.bubble",
                tone: detectorHealthTone
            )
        }
    }

    private var conversationWorklist: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("对话")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text("待审阅与正在处理")
                        .font(.title3.bold())
                }

                Spacer()

                Text("\(realTrackedCount) 个真实追踪")
                    .font(.caption.bold())
                    .foregroundStyle(sampleMode ? .orange : .secondary)
            }

            if store.conversations.isEmpty {
                emptyConversationState
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    conversationSection("待我审阅", items: reviewItems)
                    conversationSection("正在编辑", items: activeItems)
                    conversationSection("后台运行", items: backgroundItems)
                    conversationSection("需要确认", items: confirmationItems)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .background(panelBackground)
    }

    private func conversationSection(_ title: String, items: [ConversationSurface]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text("\(items.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            if items.isEmpty {
                Text(emptySectionMessage(for: title))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 5)
            } else {
                ForEach(items) { item in
                    ConversationRow(item: item, store: store)
                }
            }
        }
    }

    private var primaryDisplayPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("主屏", primaryDisplaySummary)
                Spacer()
                Text("下一项：\(nextPromotionSideLabel)")
                    .font(.caption.bold())
                    .foregroundStyle(.teal)
            }

            Text(store.workbenchState.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Picker("正在编辑侧", selection: $store.activeSide) {
                Text("左侧编辑").tag(DisplaySide.left)
                Text("右侧编辑").tag(DisplaySide.right)
            }
            .pickerStyle(.segmented)
            .onChange(of: store.activeSide) { _, side in
                store.setActiveSide(side)
            }

            HStack(spacing: 10) {
                SlotView(side: .left, store: store)
                SlotView(side: .right, store: store)
            }
        }
        .padding(16)
        .background(panelBackground)
    }

    private var nextQueuePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("队首任务", store.queued.first?.conversationTitle ?? "暂无待审阅")

            if let next = store.queued.first {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(next.appName) / \(next.windowLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(userFacingDetector(for: next))
                        .font(.caption)
                        .foregroundStyle(detectorTone(for: next))

                    if let reason = store.promotionBlockReason {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        store.promoteIfPossible()
                    } label: {
                        Label(store.promotionActionLabel, systemImage: "arrow.up.forward")
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text(queueEmptyMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(panelBackground)
    }

    private var displayOverviewPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("屏幕概览", "\(NSScreen.screens.count) 块屏幕")

            ForEach(displayOverviewRows) { row in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(row.tone.color)
                        .frame(width: 8, height: 8)
                        .padding(.top, 5)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(row.name)
                                .font(.caption.bold())
                            Spacer()
                            Text(row.status)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(row.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(panelBackground)
    }

    private var recentDecisionsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionTitle("最近决策", "最近 \(min(store.events.count, 3)) 条")
                Spacer()
                Button {
                    mode = .diagnostics
                } label: {
                    Label("诊断", systemImage: "stethoscope")
                }
            }

            if store.events.isEmpty {
                Text("还没有决策记录。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(store.events.prefix(3)), id: \.self) { event in
                    Text(event)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.teal.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(16)
        .background(panelBackground)
    }

    private var setupView: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                setupCard(
                    title: "辅助功能权限",
                    value: store.accessibilityTrusted ? "已就绪" : "需要授权",
                    symbol: store.accessibilityTrusted ? "checkmark.seal.fill" : "lock.fill",
                    tone: store.accessibilityTrusted ? .ok : .warning
                ) {
                    Button {
                        store.requestAccessibilityPermission()
                    } label: {
                        Label("申请权限", systemImage: "lock.open")
                    }
                    Button {
                        store.refreshSnapshot()
                    } label: {
                        Label("扫描", systemImage: "arrow.clockwise")
                    }
                }

                setupCard(
                    title: "窗口控制",
                    value: store.realWindowActionsEnabled ? "允许移动" : "仅更新面板",
                    symbol: store.realWindowActionsEnabled ? "rectangle.2.swap" : "rectangle.dashed",
                    tone: store.realWindowActionsEnabled ? .warning : .neutral
                ) {
                    Toggle("移动真实窗口", isOn: Binding(
                        get: { store.realWindowActionsEnabled },
                        set: { store.setRealWindowActionsEnabled($0) }
                    ))
                    .toggleStyle(.switch)

                    if !store.undoFrames.isEmpty {
                        Button {
                            store.restoreLastWindowFrame()
                        } label: {
                            Label("撤销移动", systemImage: "arrow.uturn.backward")
                        }
                    }
                }
            }
            .frame(minWidth: 420, maxWidth: 520)

            VStack(alignment: .leading, spacing: 14) {
                setupCard(title: "安全测试", value: "本地测试窗口", symbol: "macwindow", tone: .neutral) {
                    Button {
                        store.openTestWindow()
                    } label: {
                        Label("打开测试窗口", systemImage: "macwindow")
                    }
                    Button {
                        store.runValidationMode()
                    } label: {
                        Label("运行验证", systemImage: "checklist")
                    }
                }

                recentDecisionsPanel
            }
        }
    }

    private func setupCard<Content: View>(
        title: String,
        value: String,
        symbol: String,
        tone: HealthTone,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(tone.color)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.title3.bold())
                }
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(panelBackground)
    }

    private var diagnosticsView: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 14) {
                validationPanel
                simulationPanel
            }
            .frame(width: 380)

            VStack(spacing: 14) {
                diagnosticsSummary
                eventPanel
            }
        }
    }

    private var diagnosticsSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("诊断", "原始信号")

            diagnosticRow("焦点窗口", focusedWindowValue)
            diagnosticRow("识别风险", detectorHealthDetail)
            diagnosticRow("撤销帧", "\(store.undoFrames.count)")
            diagnosticRow("追踪范围", store.trackedAppSummary)
        }
        .padding(16)
        .background(panelBackground)
    }

    private func diagnosticRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var settingsView: some View {
        HStack(alignment: .top, spacing: 14) {
            settingsPanel
                .frame(width: 420)

            VStack(alignment: .leading, spacing: 14) {
                commandPanel
                ignoredPanel
            }
        }
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("追踪范围", store.trackedAppSummary)

            Toggle("追踪所有可见 App", isOn: Binding(
                get: { store.trackAllApps },
                set: { store.setTrackAllApps($0) }
            ))
            .toggleStyle(.switch)

            HStack(spacing: 6) {
                TextField("添加 App 名称", text: $newTrackedAppName)
                    .textFieldStyle(.roundedBorder)
                Button {
                    store.addTrackedApp(newTrackedAppName)
                    newTrackedAppName = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
            }
            .disabled(store.trackAllApps)
            .opacity(store.trackAllApps ? 0.45 : 1)

            Divider()

            ForEach(store.trackedAppRules) { rule in
                Button {
                    store.toggleTrackedApp(rule.name)
                } label: {
                    HStack {
                        Image(systemName: rule.isEnabled ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(rule.isEnabled ? .green : .secondary)
                        Text(rule.name)
                            .lineLimit(1)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .disabled(store.trackAllApps)
                .opacity(store.trackAllApps ? 0.45 : 1)
            }
        }
        .padding(16)
        .background(panelBackground)
    }

    private var commandPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("命令", "面板快捷键")

            CommandShortcutRow(title: "选中项入队", shortcut: "Ctrl Opt Q")
            CommandShortcutRow(title: "标记运行中", shortcut: "Ctrl Opt R")
            CommandShortcutRow(title: "标记完成", shortcut: "Ctrl Opt D")
            CommandShortcutRow(title: "弹出下一项", shortcut: "Ctrl Opt P")

            HStack(spacing: 6) {
                Button("入队") { store.queueCommandTarget() }
                    .keyboardShortcut("q", modifiers: [.control, .option])
                Button("运行中") { store.markRunningCommandTarget() }
                    .keyboardShortcut("r", modifiers: [.control, .option])
                Button("完成") { store.markDoneCommandTarget() }
                    .keyboardShortcut("d", modifiers: [.control, .option])
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(panelBackground)
    }

    private var ignoredPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("已忽略", "\(store.ignoredConversationKeys.count)")
                Spacer()
                if !store.ignoredConversationKeys.isEmpty {
                    Button("清空") {
                        store.clearIgnoredConversations()
                    }
                }
            }

            if store.ignoredConversationKeys.isEmpty {
                Text("没有已忽略的对话。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(store.ignoredConversationKeys).sorted(), id: \.self) { key in
                    HStack(spacing: 6) {
                        Text(key)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            store.unignoreConversationKey(key)
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(7)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(16)
        .background(panelBackground)
    }

    private var simulationPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("模拟", "对话事件")

            Button("切换活跃对话") {
                store.switchActiveConversation()
            }
            .frame(maxWidth: .infinity)

            Button("刷新快照") {
                store.refreshSnapshot()
            }
            .frame(maxWidth: .infinity)

            Button("打开安全测试窗口") {
                store.openTestWindow()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(panelBackground)
    }

    private var validationPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("验证", "安全旅程")
                Spacer()
                Button {
                    store.copyValidationReportToClipboard()
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                }
            }

            Button {
                store.runValidationMode()
            } label: {
                Label("运行验证", systemImage: "checklist")
            }

            ForEach(store.validationSteps) { step in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: validationIcon(for: step.status))
                        .foregroundStyle(validationColor(for: step.status))
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title).fontWeight(.semibold)
                        Text(step.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                }
                .padding(7)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(16)
        .background(panelBackground)
    }

    private var eventPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("事件日志", "调度决策")
                Spacer()
                Text("编辑侧：\(store.activeSide.label)")
                    .foregroundStyle(.secondary)
            }

            ForEach(store.events, id: \.self) { event in
                Text(event)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Color.teal.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(panelBackground)
    }

    private var emptyConversationState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(emptyStateTitle, systemImage: emptyStateIcon)
                .font(.headline)

            Text(emptyStateDetail)
                .foregroundStyle(.secondary)

            Button {
                store.accessibilityTrusted ? store.refreshSnapshot() : store.requestAccessibilityPermission()
            } label: {
                Label(store.accessibilityTrusted ? "扫描" : "申请权限", systemImage: store.accessibilityTrusted ? "arrow.clockwise" : "lock.open")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 280, alignment: .center)
        .padding(24)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
    }

    private func sectionTitle(_ eyebrow: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(eyebrow)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .lineLimit(2)
        }
    }

    private var activeConversations: [ConversationSurface] {
        store.conversations.filter { $0.status != .done }
    }

    private var realTrackedCount: Int {
        sampleMode ? 0 : store.trackedCount
    }

    private var reviewItems: [ConversationSurface] {
        activeConversations.filter { $0.status == .queued || $0.status == .displayed }
    }

    private var activeItems: [ConversationSurface] {
        activeConversations.filter { $0.status == .editing }
    }

    private var backgroundItems: [ConversationSurface] {
        activeConversations.filter { $0.status == .running || $0.status == .hidden || $0.status == .inactive }
    }

    private var confirmationItems: [ConversationSurface] {
        activeConversations.filter { item in
            item.status == .unknown || item.detectorLevel == 0 || item.detectorConfidence < 0.6
        }
    }

    private var lowConfidenceConversations: [ConversationSurface] {
        activeConversations.filter { item in
            item.detectorLevel == 0 || item.detectorID == "none" || item.detectorConfidence < 0.6
        }
    }

    private var sampleMode: Bool {
        store.lastScanSummary == "Mock data"
    }

    private var scanSummaryValue: String {
        if sampleMode { return "样例数据" }
        return store.lastScanSummary
            .replacingOccurrences(of: "windows detected", with: "个窗口")
            .replacingOccurrences(of: "tracked", with: "个已追踪")
            .replacingOccurrences(of: " of ", with: " / ")
    }

    private var topStatusLine: String {
        if !store.accessibilityTrusted { return "需要授权后才能扫描真实窗口" }
        if sampleMode { return "样例模式 - 点击扫描读取真实窗口" }
        return "\(scanSummaryValue) - \(focusedWindowValue)"
    }

    private var focusedWindowValue: String {
        if store.focusedWindowSummary == "Mock focus" { return "尚无真实焦点" }
        return store.focusedWindowSummary
    }

    private var scanHealthTone: HealthTone {
        if sampleMode { return .neutral }
        if store.lastScanSummary.hasPrefix("0 ") { return .warning }
        return .ok
    }

    private var scanHealthDetail: String {
        if sampleMode { return "样例状态" }
        return focusedWindowValue
    }

    private var detectorHealthTone: HealthTone {
        guard !activeConversations.isEmpty else { return .neutral }
        return lowConfidenceConversations.isEmpty ? .ok : .warning
    }

    private var detectorHealthValue: String {
        guard !activeConversations.isEmpty else { return "无行" }
        return lowConfidenceConversations.isEmpty ? "可靠" : "\(lowConfidenceConversations.count) 项需确认"
    }

    private var detectorHealthDetail: String {
        guard !activeConversations.isEmpty else { return "扫描后显示对话" }
        guard !lowConfidenceConversations.isEmpty else { return "所有活跃行可用" }
        return "低置信度或未知对话"
    }

    private var reviewHealthDetail: String {
        if let next = store.queued.first {
            return "下一项：\(next.conversationTitle)"
        }
        return sampleMode ? "当前为样例队列" : "暂无待审阅"
    }

    private var queueEmptyMessage: String {
        if !store.accessibilityTrusted { return "授权后才会出现真实待审阅项。" }
        if sampleMode { return "点击扫描，用真实窗口替换样例状态。" }
        if store.conversations.isEmpty { return "没有找到已追踪窗口。" }
        return "当前没有等待审阅的对话。"
    }

    private var primaryDisplaySummary: String {
        guard let screen = primaryScreen else { return "主屏槽位" }
        let width = Int(screen.frame.width)
        let height = Int(screen.frame.height)
        return "\(screen.localizedName) \(width)x\(height)"
    }

    private var primaryScreen: NSScreen? {
        let mainDisplayID = CGMainDisplayID()
        let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")
        return NSScreen.screens.first { screen in
            guard let screenNumber = screen.deviceDescription[screenNumberKey] as? NSNumber else {
                return false
            }
            return screenNumber.uint32Value == mainDisplayID
        } ?? NSScreen.main ?? NSScreen.screens.first
    }

    private var displayOverviewRows: [DisplayOverviewRow] {
        NSScreen.screens.enumerated().map { index, screen in
            let name = index == 0 ? "主屏" : "屏幕 \(index + 1)"
            let items = conversations(onDisplayIndex: index)
            let width = Int(screen.frame.width)
            let height = Int(screen.frame.height)
            return DisplayOverviewRow(
                name: name,
                detail: "\(screen.localizedName) \(width)x\(height)",
                status: displayStatusSummary(for: items),
                tone: displayTone(for: items)
            )
        }
    }

    private func conversations(onDisplayIndex index: Int) -> [ConversationSurface] {
        let screenLabel = index == 0 ? "主屏" : "屏幕 \(index + 1)"
        let legacyExternalLabel = index > 0 ? "外接屏 \(index)" : ""
        return activeConversations.filter { item in
            item.location.contains(screenLabel)
                || (!legacyExternalLabel.isEmpty && item.location.contains(legacyExternalLabel))
        }
    }

    private func displayStatusSummary(for items: [ConversationSurface]) -> String {
        guard !items.isEmpty else { return "空闲" }
        let editing = items.filter { $0.status == .editing }.count
        let reviewing = items.filter { $0.status == .displayed || $0.status == .queued }.count
        let running = items.filter { $0.status == .running || $0.status == .hidden || $0.status == .inactive }.count
        let parts = [
            editing > 0 ? "编辑 \(editing)" : nil,
            reviewing > 0 ? "审阅 \(reviewing)" : nil,
            running > 0 ? "后台 \(running)" : nil
        ].compactMap { $0 }
        return parts.isEmpty ? "\(items.count) 个对话" : parts.joined(separator: " / ")
    }

    private func displayTone(for items: [ConversationSurface]) -> HealthTone {
        guard !items.isEmpty else { return .neutral }
        return items.contains(where: { $0.status == .editing || $0.status == .displayed }) ? .ok : .warning
    }

    private var emptyStateTitle: String {
        if !store.accessibilityTrusted { return "需要授权" }
        if sampleMode { return "样例模式" }
        return "没有已追踪对话"
    }

    private var emptyStateDetail: String {
        if !store.accessibilityTrusted { return "授予辅助功能权限后，再次扫描。" }
        if sampleMode { return "点击扫描读取本地可见窗口。" }
        return "打开一个已追踪 AI App 窗口，或调整追踪设置。"
    }

    private var emptyStateIcon: String {
        store.accessibilityTrusted ? "rectangle.dashed" : "lock.fill"
    }

    private func emptySectionMessage(for title: String) -> String {
        switch title {
        case "待我审阅": return "暂无待审阅。"
        case "正在编辑": return "暂无正在编辑项。"
        case "后台运行": return "暂无后台对话。"
        default: return "暂无需要确认的行。"
        }
    }

    private func opposite(of side: DisplaySide) -> DisplaySide {
        side == .left ? .right : .left
    }

    private var nextPromotionSideLabel: String {
        guard let editingSide = store.workbenchState.editingSide else {
            return "默认 \(opposite(of: store.activeSide).label)"
        }
        return opposite(of: editingSide).label
    }

    private func userFacingDetector(for item: ConversationSurface) -> String {
        if item.detectorLevel == 0 { return "未知对话" }
        if item.detectorConfidence < 0.6 { return "需要确认" }
        return "识别可靠"
    }

    private func detectorTone(for item: ConversationSurface) -> Color {
        item.detectorLevel == 0 || item.detectorConfidence < 0.6 ? .orange : .secondary
    }

    private func validationIcon(for status: ValidationStepStatus) -> String {
        switch status {
        case .pending: "circle"
        case .passed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .skipped: "minus.circle.fill"
        }
    }

    private func validationColor(for status: ValidationStepStatus) -> Color {
        switch status {
        case .pending: .secondary
        case .passed: .green
        case .failed: .red
        case .skipped: .orange
        }
    }
}

private struct DisplayOverviewRow: Identifiable {
    let name: String
    let detail: String
    let status: String
    let tone: HealthTone

    var id: String { name }
}

private struct ConversationRow: View {
    let item: ConversationSurface
    @Bindable var store: ConversationStore

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.conversationTitle)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    StatusBadge(status: item.status)
                }

                Text("\(item.appName) / \(item.windowLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(userFacingDetector, systemImage: detectorIcon)
                        .font(.caption)
                        .foregroundStyle(detectorTone)
                    Text(item.location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            rowPrimaryAction

            Menu {
                Button("入队") { store.queue(item.id) }
                Button("运行中") { store.markRunning(item.id) }
                Button("完成") { store.markDone(item.id) }
                Divider()
                Button("忽略") { store.ignoreConversation(item.id) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
        }
        .padding(10)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(store.selectedConversationID == item.id ? Color.teal : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            store.selectedConversationID = item.id
        }
    }

    @ViewBuilder
    private var rowPrimaryAction: some View {
        switch item.status {
        case .queued:
            Button(store.promotionActionLabel) { store.promoteIfPossible() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .frame(width: 78)
        case .displayed, .editing:
            Button("运行中") { store.markRunning(item.id) }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(width: 78)
        case .running, .hidden, .inactive, .unknown:
            Button("入队") { store.queue(item.id) }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(width: 78)
        case .done:
            EmptyView()
        }
    }

    private var userFacingDetector: String {
        if item.detectorLevel == 0 { return "未知" }
        if item.detectorConfidence < 0.6 { return "需确认" }
        return "可靠"
    }

    private var detectorIcon: String {
        item.detectorLevel == 0 || item.detectorConfidence < 0.6 ? "exclamationmark.circle" : "checkmark.circle"
    }

    private var detectorTone: Color {
        item.detectorLevel == 0 || item.detectorConfidence < 0.6 ? .orange : .secondary
    }
}

private enum HealthTone {
    case ok
    case warning
    case neutral

    var color: Color {
        switch self {
        case .ok: .green
        case .warning: .orange
        case .neutral: .secondary
        }
    }
}

private struct HealthTile: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tone: HealthTone

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tone.color)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
        .background(panelTileBackground)
    }

    private var panelTileBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
    }
}

private struct CommandShortcutRow: View {
    let title: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
            Spacer()
            Text(shortcut)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}

private struct SlotView: View {
    let side: DisplaySide
    @Bindable var store: ConversationStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(side.label)
                    .fontWeight(.semibold)
                Spacer()
                Text(label)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            if let item = store.visibleConversation(on: side) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(item.appName) / \(item.windowLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.conversationTitle)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    Text(StatusBadge.label(for: item.status))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("空位")
                        .fontWeight(.semibold)
                    Text("没有实时编辑中的 agent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 155, alignment: .topLeading)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(store.activeSide == side ? Color.teal : Color(nsColor: .separatorColor), lineWidth: 2)
        )
    }

    private var label: String {
        if store.activeSide == side { return "编辑中" }
        if store.visibleConversation(on: side) != nil { return "实时占用" }
        return "空位"
    }
}

private struct StatusBadge: View {
    let status: ConversationStatus

    var body: some View {
        Text(Self.label(for: status))
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .clipShape(Capsule())
    }

    static func label(for status: ConversationStatus) -> String {
        switch status {
        case .editing: "编辑中"
        case .displayed: "审阅中"
        case .running: "运行中"
        case .queued: "已入队"
        case .hidden: "已隐藏"
        case .inactive: "非活跃"
        case .unknown: "未知"
        case .done: "完成"
        }
    }

    private var color: Color {
        switch status {
        case .editing: .teal
        case .displayed: .blue
        case .running: .gray
        case .queued: .orange
        case .hidden: .brown
        case .inactive: .purple
        case .unknown: .red
        case .done: .green
        }
    }
}

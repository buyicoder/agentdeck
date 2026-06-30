import SwiftUI

struct AgentDeckPanelView: View {
    @Bindable var store: ConversationStore

    var body: some View {
        VStack(spacing: 16) {
            topBar
            healthStrip

            HStack(alignment: .top, spacing: 16) {
                conversationTable
                    .frame(minWidth: 720)

                VStack(spacing: 16) {
                    slotsPanel
                    queuePanel
                }
                .frame(width: 330)
            }

            HStack(alignment: .top, spacing: 16) {
                simulationPanel
                    .frame(width: 360)
                validationPanel
                    .frame(width: 360)
                eventPanel
            }
        }
        .padding(18)
        .frame(minWidth: 1080, minHeight: 700)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.teal.opacity(0.9))
                .frame(width: 44, height: 44)
                .overlay(Text("AD").font(.headline).foregroundStyle(.white))

            VStack(alignment: .leading, spacing: 2) {
                Text("AgentDeck")
                    .font(.title2.bold())
                Text("Local Mac panel for AI conversations")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(store.trackedCount) tracked conversations")
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.thinMaterial)
                .clipShape(Capsule())

            Button {
                store.refreshSnapshot()
            } label: {
                Label("Scan", systemImage: "arrow.clockwise")
            }

            Button {
                store.requestAccessibilityPermission()
            } label: {
                Label("Request Access", systemImage: "lock.open")
            }

            Button {
                store.promoteIfPossible()
            } label: {
                Label("Promote next", systemImage: "arrow.up.forward")
            }

            Toggle("Move windows", isOn: Binding(
                get: { store.realWindowActionsEnabled },
                set: { store.setRealWindowActionsEnabled($0) }
            ))
            .toggleStyle(.switch)
            .help("When enabled, Promote uses macOS Accessibility to move windows.")

            Button {
                store.restoreLastWindowFrame()
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }

            Button {
                store.openTestWindow()
            } label: {
                Label("Test window", systemImage: "macwindow")
            }
        }
        .padding(14)
        .background(panelBackground)
    }

    private var healthStrip: some View {
        HStack(spacing: 10) {
            HealthTile(
                title: "Permission",
                value: store.accessibilityTrusted ? "Ready" : "Needs access",
                detail: store.accessibilityTrusted ? "Accessibility trust granted" : "Grant Accessibility, then scan again",
                systemImage: store.accessibilityTrusted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                tone: store.accessibilityTrusted ? .ok : .warning
            )

            HealthTile(
                title: "Scan",
                value: store.lastScanSummary,
                detail: scanHealthDetail,
                systemImage: scanHealthTone == .ok ? "waveform.path.ecg" : "magnifyingglass",
                tone: scanHealthTone
            )

            HealthTile(
                title: "Detectors",
                value: detectorHealthValue,
                detail: detectorHealthDetail,
                systemImage: detectorHealthTone == .warning ? "dial.low" : "scope",
                tone: detectorHealthTone
            )

            HealthTile(
                title: "Review",
                value: "\(store.queued.count) queued",
                detail: "\(reviewHealthDetail) Undo frames: \(store.undoFrames.count)",
                systemImage: store.queued.isEmpty ? "tray" : "tray.full.fill",
                tone: store.queued.isEmpty ? .neutral : .ok
            )
        }
    }

    private var conversationTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CONVERSATION OVERVIEW")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text("Current AI Conversations")
                        .font(.title3.bold())
                }

                Spacer()

                Picker("Active side", selection: $store.activeSide) {
                    Text("Left editing").tag(DisplaySide.left)
                    Text("Right editing").tag(DisplaySide.right)
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
                .onChange(of: store.activeSide) { _, side in
                    store.setActiveSide(side)
                }
            }

            if store.conversations.isEmpty {
                emptyConversationState
            } else {
                Table(store.conversations) {
                    TableColumn("App") { item in
                        Text(item.appName).fontWeight(.semibold)
                    }
                    TableColumn("Window") { item in
                        VStack(alignment: .leading) {
                            Text(item.windowLabel).fontWeight(.semibold)
                            Text(item.conversationKey.components(separatedBy: ":").prefix(2).joined(separator: ":"))
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    TableColumn("Conversation") { item in
                        VStack(alignment: .leading) {
                            Text(item.conversationTitle).fontWeight(.semibold)
                            Text(item.subtitle).foregroundStyle(.secondary)
                        }
                    }
                    TableColumn("Status") { item in
                        StatusBadge(status: item.status)
                    }
                    TableColumn("Detector") { item in
                        DetectorBadge(item: item)
                    }
                    TableColumn("Location") { item in
                        Text(item.location).foregroundStyle(.secondary)
                    }
                    TableColumn("Age") { item in
                        Text(item.age).foregroundStyle(.secondary)
                    }
                    TableColumn("Actions") { item in
                        HStack {
                            Button("Queue") { store.queue(item.id) }
                            Button("Run") { store.markRunning(item.id) }
                            Button("Done") { store.markDone(item.id) }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(16)
        .background(panelBackground)
    }

    private var emptyConversationState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                store.accessibilityTrusted ? "No visible app windows were found" : "Accessibility permission is needed before real scans",
                systemImage: store.accessibilityTrusted ? "rectangle.dashed" : "lock.fill"
            )
            .font(.headline)

            Text(store.accessibilityTrusted ? "Open a supported AI app window, then scan again." : "Request access in macOS, return here, then scan. AgentDeck remains in sample or limited mode until permission is trusted.")
                .foregroundStyle(.secondary)

            Text("Last scan: \(store.lastScanSummary)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 280, alignment: .center)
        .padding(24)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var slotsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("MAIN DISPLAY", "Slots")

            HStack(spacing: 10) {
                SlotView(side: .left, store: store)
                SlotView(side: .right, store: store)
            }
        }
        .padding(16)
        .background(panelBackground)
    }

    private var queuePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("REVIEW QUEUE", "\(store.queued.count) queued")

            if store.queued.isEmpty {
                Text("Queue is empty.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.queued) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.conversationTitle).fontWeight(.semibold)
                        Text("\(item.appName) / \(item.windowLabel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(panelBackground)
    }

    private var simulationPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("SIMULATION", "Conversation Events")

            Button("Switch active conversation") {
                store.switchActiveConversation()
            }
            .frame(maxWidth: .infinity)

            Button("Refresh snapshot") {
                store.refreshSnapshot()
            }
            .frame(maxWidth: .infinity)

            Button("Open safe test window") {
                store.openTestWindow()
            }
            .frame(maxWidth: .infinity)

            Button("Run validation mode") {
                store.runValidationMode()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(panelBackground)
    }

    private var validationPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("VALIDATION", "Safe Journey")
                Spacer()
                Button {
                    store.copyValidationReportToClipboard()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .help("Copy the latest validation report")
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
                sectionTitle("EVENT LOG", "Scheduling Decisions")
                Spacer()
                Text("Active side: \(store.activeSide.rawValue)")
                    .foregroundStyle(.secondary)
            }

            ForEach(store.events, id: \.self) { event in
                Text(event)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Color.teal.opacity(0.08))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(panelBackground)
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
        }
    }

    private var activeConversations: [ConversationSurface] {
        store.conversations.filter { $0.status != .done }
    }

    private var lowConfidenceConversations: [ConversationSurface] {
        activeConversations.filter { item in
            item.detectorLevel == 0 || item.detectorID == "none" || item.detectorConfidence < 0.6
        }
    }

    private var scanHealthTone: HealthTone {
        if store.lastScanSummary == "Mock data" { return .neutral }
        if store.lastScanSummary.hasPrefix("0 ") { return .warning }
        return .ok
    }

    private var scanHealthDetail: String {
        if store.lastScanSummary == "Mock data" {
            return "Sample state; run scan for real windows"
        }
        return store.focusedWindowSummary
    }

    private var detectorHealthTone: HealthTone {
        guard !activeConversations.isEmpty else { return .neutral }
        return lowConfidenceConversations.isEmpty ? .ok : .warning
    }

    private var detectorHealthValue: String {
        guard !activeConversations.isEmpty else { return "No rows" }
        return "\(activeConversations.count - lowConfidenceConversations.count)/\(activeConversations.count) clear"
    }

    private var detectorHealthDetail: String {
        guard !activeConversations.isEmpty else { return "Scan to populate detector status" }
        guard !lowConfidenceConversations.isEmpty else { return "All active rows have usable confidence" }
        return "\(lowConfidenceConversations.count) low-confidence or unknown rows"
    }

    private var reviewHealthDetail: String {
        if let next = store.queued.first {
            return "Next: \(next.conversationTitle)"
        }
        return "No review backlog"
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
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
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
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            } else {
                Text("No tracked conversation")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 90)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(store.activeSide == side ? Color.teal : Color(nsColor: .separatorColor), lineWidth: 2)
        )
    }

    private var label: String {
        if store.activeSide == side { return "Editing" }
        if store.visibleConversation(on: side) != nil { return "Displayed" }
        return "Open"
    }
}

private struct StatusBadge: View {
    let status: ConversationStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .clipShape(Capsule())
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

private struct DetectorBadge: View {
    let item: ConversationSurface

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("L\(item.detectorLevel) \(item.detectorID)")
                .font(.caption.bold())
            Label("\(Int(item.detectorConfidence * 100))% confidence", systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(tone)
        }
    }

    private var systemImage: String {
        item.detectorConfidence < 0.6 || item.detectorLevel == 0 ? "exclamationmark.circle" : "checkmark.circle"
    }

    private var tone: Color {
        item.detectorConfidence < 0.6 || item.detectorLevel == 0 ? .orange : .secondary
    }
}

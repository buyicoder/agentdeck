import Foundation

struct DetectionContext {
    let fact: WindowFact
    let focusedWindowID: String?
    let focusedSide: DisplaySide?
}

struct DetectionResult {
    let conversationKey: String
    let title: String
    let subtitle: String
    let detectorID: String
    let detectorLevel: Int
    let confidence: Double
}

protocol ConversationDetector {
    var id: String { get }
    var level: Int { get }

    func match(_ context: DetectionContext) -> Bool
    func detect(_ context: DetectionContext) -> DetectionResult?
}

enum DetectionText {
    private static let titleSeparators = [" - ", " | ", " — ", " – ", " · ", " :: "]

    static func normalize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func slug(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let scalars = value.lowercased().unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let collapsed = String(scalars).split(separator: "-").joined(separator: "-")
        return String(collapsed.prefix(56))
    }

    static func titleWithoutAppSuffix(_ title: String, suffixes: [String]) -> String {
        var result = normalize(title)
        for suffix in suffixes {
            for separator in titleSeparators {
                let appSuffix = separator + suffix
                if result.range(of: appSuffix, options: [.caseInsensitive, .backwards])?.upperBound == result.endIndex,
                   let range = result.range(of: appSuffix, options: [.caseInsensitive, .backwards]) {
                    result = String(result[..<range.lowerBound]).trimmingTitleEdgeSeparators()
                }
            }
        }
        return result.isEmpty ? normalize(title) : result
    }

    static func titleWithoutAppPrefix(_ title: String, prefixes: [String]) -> String {
        var result = normalize(title)
        for prefix in prefixes {
            for separator in titleSeparators {
                let appPrefix = prefix + separator
                if let range = result.range(of: appPrefix, options: [.caseInsensitive, .anchored]) {
                    result = String(result[range.upperBound...]).trimmingTitleEdgeSeparators()
                }
            }
        }
        return result.isEmpty ? normalize(title) : result
    }

    static func parsedAppTitle(_ title: String, appNames: [String]) -> String {
        titleWithoutAppPrefix(
            titleWithoutAppSuffix(title, suffixes: appNames),
            prefixes: appNames
        )
    }
}

private extension String {
    func trimmingTitleEdgeSeparators() -> String {
        trimmingCharacters(in: CharacterSet(charactersIn: " -|—–·:").union(.whitespacesAndNewlines))
    }
}

enum AgentAppTitleParser {
    static func codex(_ title: String) -> String {
        DetectionText.parsedAppTitle(title, appNames: ["Codex"])
    }

    static func cursor(_ title: String) -> String {
        DetectionText.parsedAppTitle(title, appNames: ["Cursor"])
    }

    static func workBuddy(_ title: String) -> String {
        DetectionText.parsedAppTitle(title, appNames: ["WorkBuddy", "Work Buddy"])
    }

    static func terminalAgent(_ title: String) -> String {
        DetectionText.parsedAppTitle(title, appNames: ["Terminal", "iTerm2", "WezTerm"])
    }
}

enum BrowserTitleParser {
    static let browserAppNames = ["Google Chrome", "Microsoft Edge", "Safari"]

    static func isBrowser(appName: String) -> Bool {
        let normalizedAppName = appName.lowercased()
        return normalizedAppName.contains("chrome")
            || normalizedAppName.contains("edge")
            || normalizedAppName.contains("safari")
    }

    static func tabTitle(_ title: String) -> String {
        DetectionText.titleWithoutAppSuffix(title, suffixes: browserAppNames)
    }
}

struct AppTitleDetector: ConversationDetector {
    let id: String
    let level: Int
    let appNeedles: [String]
    let keyPrefix: String
    let confidence: Double
    let parseTitle: (String) -> String

    func match(_ context: DetectionContext) -> Bool {
        let appName = context.fact.appName.lowercased()
        return appNeedles.contains { appName.contains($0.lowercased()) }
            && !DetectionText.normalize(context.fact.title).isEmpty
    }

    func detect(_ context: DetectionContext) -> DetectionResult? {
        let title = parseTitle(context.fact.title)
        guard !title.isEmpty else { return nil }

        return DetectionResult(
            conversationKey: [
                keyPrefix,
                String(context.fact.ownerPID),
                String(context.fact.windowNumber),
                DetectionText.slug(title)
            ].joined(separator: ":"),
            title: title,
            subtitle: "L\(level) \(id): \(context.fact.appName) window title",
            detectorID: id,
            detectorLevel: level,
            confidence: confidence
        )
    }
}

struct BrowserTitleDetector: ConversationDetector {
    let id = "browser-title"
    let level = 1

    func match(_ context: DetectionContext) -> Bool {
        BrowserTitleParser.isBrowser(appName: context.fact.appName)
            && !DetectionText.normalize(context.fact.title).isEmpty
    }

    func detect(_ context: DetectionContext) -> DetectionResult? {
        let title = BrowserTitleParser.tabTitle(context.fact.title)
        guard !title.isEmpty else { return nil }

        return DetectionResult(
            conversationKey: [
                "browser-title",
                String(context.fact.ownerPID),
                String(context.fact.windowNumber),
                DetectionText.slug(title)
            ].joined(separator: ":"),
            title: title,
            subtitle: "L1 browser title detector; URL/tab identity not available yet",
            detectorID: id,
            detectorLevel: level,
            confidence: 0.5
        )
    }
}

struct TitleFallbackDetector: ConversationDetector {
    let id = "title-fallback"
    let level = 1

    func match(_ context: DetectionContext) -> Bool {
        !context.fact.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func detect(_ context: DetectionContext) -> DetectionResult? {
        let normalizedTitle = DetectionText.normalize(context.fact.title)
        guard !normalizedTitle.isEmpty else { return nil }

        return DetectionResult(
            conversationKey: [
                "title",
                String(context.fact.ownerPID),
                String(context.fact.windowNumber),
                DetectionText.slug(normalizedTitle)
            ].joined(separator: ":"),
            title: normalizedTitle,
            subtitle: "L1 title detector: \(Int(context.fact.frame.width))x\(Int(context.fact.frame.height))",
            detectorID: id,
            detectorLevel: level,
            confidence: confidence(for: normalizedTitle)
        )
    }

    private func confidence(for title: String) -> Double {
        if title == "Untitled window" { return 0.25 }
        if title.count < 4 { return 0.35 }
        return 0.55
    }
}

struct WindowOnlyDetector: ConversationDetector {
    let id = "window-only"
    let level = 0

    func match(_ context: DetectionContext) -> Bool {
        true
    }

    func detect(_ context: DetectionContext) -> DetectionResult? {
        DetectionResult(
            conversationKey: "window:\(context.fact.ownerPID):\(context.fact.windowNumber)",
            title: context.fact.title,
            subtitle: "L0 window fact: \(Int(context.fact.frame.width))x\(Int(context.fact.frame.height))",
            detectorID: id,
            detectorLevel: level,
            confidence: 0.15
        )
    }
}

struct DetectorPipeline {
    private let detectors: [ConversationDetector]

    init(detectors: [ConversationDetector] = [
        AppTitleDetector(
            id: "codex-title",
            level: 1,
            appNeedles: ["codex"],
            keyPrefix: "codex-title",
            confidence: 0.62,
            parseTitle: AgentAppTitleParser.codex
        ),
        AppTitleDetector(
            id: "cursor-title",
            level: 1,
            appNeedles: ["cursor"],
            keyPrefix: "cursor-title",
            confidence: 0.6,
            parseTitle: AgentAppTitleParser.cursor
        ),
        AppTitleDetector(
            id: "workbuddy-title",
            level: 1,
            appNeedles: ["workbuddy"],
            keyPrefix: "workbuddy-title",
            confidence: 0.62,
            parseTitle: AgentAppTitleParser.workBuddy
        ),
        AppTitleDetector(
            id: "terminal-agent-title",
            level: 1,
            appNeedles: ["terminal", "iterm", "wezterm"],
            keyPrefix: "terminal-title",
            confidence: 0.48,
            parseTitle: AgentAppTitleParser.terminalAgent
        ),
        BrowserTitleDetector(),
        TitleFallbackDetector(),
        WindowOnlyDetector()
    ]) {
        self.detectors = detectors
    }

    func detect(_ context: DetectionContext) -> DetectionResult {
        for detector in detectors where detector.match(context) {
            if let result = detector.detect(context) {
                return result
            }
        }

        return DetectionResult(
            conversationKey: "unknown:\(context.fact.ownerPID):\(context.fact.windowNumber)",
            title: context.fact.title,
            subtitle: "No detector result",
            detectorID: "none",
            detectorLevel: 0,
            confidence: 0
        )
    }
}

import Foundation

enum SupportedBrowser: CaseIterable {
    case chrome
    case edge
    case safari

    var bundleIdentifier: String {
        switch self {
        case .chrome: "com.google.Chrome"
        case .edge: "com.microsoft.edgemac"
        case .safari: "com.apple.Safari"
        }
    }

    var appName: String {
        switch self {
        case .chrome: "Google Chrome"
        case .edge: "Microsoft Edge"
        case .safari: "Safari"
        }
    }

    static func match(bundleIdentifier: String?, appName: String) -> SupportedBrowser? {
        if let bundleIdentifier,
           let browser = Self.allCases.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            return browser
        }

        let normalized = appName.lowercased()
        if normalized.contains("chrome") { return .chrome }
        if normalized.contains("edge") { return .edge }
        if normalized.contains("safari") { return .safari }
        return nil
    }
}

enum BrowserTabSource {
    case appleScript
    case windowTitleFallback
}

struct BrowserTabFact {
    let browser: SupportedBrowser
    let urlString: String
    let title: String
    let source: BrowserTabSource
}

protocol BrowserTabFactProviding {
    func activeTab(for browser: SupportedBrowser) -> BrowserTabFact?
}

struct AppleScriptBrowserTabFactProvider: BrowserTabFactProviding {
    func activeTab(for browser: SupportedBrowser) -> BrowserTabFact? {
        let scriptSource: String
        switch browser {
        case .chrome, .edge:
            scriptSource = """
            tell application "\(browser.appName)"
                if not (exists front window) then return {"", ""}
                set activeTab to active tab of front window
                return {URL of activeTab, title of activeTab}
            end tell
            """
        case .safari:
            scriptSource = """
            tell application "Safari"
                if not (exists front window) then return {"", ""}
                set activeTab to current tab of front window
                return {URL of activeTab, name of activeTab}
            end tell
            """
        }

        guard let script = NSAppleScript(source: scriptSource) else {
            return nil
        }

        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil,
              let url = result.atIndex(1)?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              let title = result.atIndex(2)?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !url.isEmpty || !title.isEmpty
        else {
            return nil
        }

        return BrowserTabFact(
            browser: browser,
            urlString: url,
            title: title,
            source: .appleScript
        )
    }
}

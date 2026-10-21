import Foundation

/// Which posts the harness shows: widget-sandbox v0.1.0's conformance set (`channel.json`), its corpus, or the harness's
/// own fixtures (`Fixtures/`).
public enum WidgetHarnessSet: String {
    case conformance
    case corpus
    case fixture
}

/// The arrange channel: launch arguments with ONE leading dash, as the composer harness's.
public struct WidgetHarnessLaunchOptions: Equatable {
    public var set: WidgetHarnessSet = .conformance
    /// Only the posts whose widget path contains this.
    public var postFilter: String?
    /// The client's flag (`ExperimentalUISettings.widgetMessages`).
    public var widgetMessages: Bool = true
    /// Overrides every post's size anchors.
    public var anchors: (width: Int32, height: Int32)?
    public var useDarkTheme: Bool = false

    public init() {}

    public static func ==(lhs: WidgetHarnessLaunchOptions, rhs: WidgetHarnessLaunchOptions) -> Bool {
        return lhs.set == rhs.set && lhs.postFilter == rhs.postFilter && lhs.widgetMessages == rhs.widgetMessages
            && lhs.anchors?.width == rhs.anchors?.width && lhs.anchors?.height == rhs.anchors?.height && lhs.useDarkTheme == rhs.useDarkTheme
    }

    /// `-widget-set conformance|corpus|fixture`, `-widget-post <part of a path>`, `-widget-flag on|off`,
    /// `-widget-anchors <W>x<H>`, `-harness-theme dark`.
    public static func parse(_ arguments: [String]) -> WidgetHarnessLaunchOptions {
        func value(_ key: String) -> String? {
            guard let index = arguments.firstIndex(of: key), index + 1 < arguments.count else {
                return nil
            }
            return arguments[index + 1]
        }
        var options = WidgetHarnessLaunchOptions()
        if let set = value("-widget-set").flatMap(WidgetHarnessSet.init(rawValue:)) {
            options.set = set
        }
        options.postFilter = value("-widget-post")
        if value("-widget-flag") == "off" {
            options.widgetMessages = false
        }
        if let anchors = value("-widget-anchors") {
            let parts = anchors.split(separator: "x").compactMap { Int32($0) }
            if parts.count == 2 {
                options.anchors = (parts[0], parts[1])
            }
        }
        options.useDarkTheme = value("-harness-theme") == "dark"
        return options
    }
}

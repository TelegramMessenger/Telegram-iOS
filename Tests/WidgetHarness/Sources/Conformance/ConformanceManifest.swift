import Foundation

/// A check the manifest expects a widget to publish: its catalogue ID and name.
public struct ConformanceCheck: Hashable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// One entry of widget-sandbox v0.1.0's `conformance/manifest.json` (CLIENTS.md, "The runner, step by step"): the widget,
/// the themes it runs in, its scripted actions, its pixel stages and the host checks.
public struct ConformanceTest {
    public let id: String
    public let fileURL: URL
    public let themes: [String]
    /// In order; each one key naming the action (`tap`, `drag`, `wait`, …) plus its arguments, as the manifest has them.
    public let actions: [[String: Any]]
    public let stages: [ConformanceStage]
    public let host: [ConformanceHostCheck]
    /// The checks the widget is expected to publish (the widget-sandbox author: "the expected checks of each are in
    /// manifest.json"), so a run that never publishes still accounts for every one.
    public let expectedChecks: [ConformanceCheck]

    public init(id: String, fileURL: URL, themes: [String], actions: [[String: Any]], stages: [ConformanceStage], host: [ConformanceHostCheck], expectedChecks: [ConformanceCheck] = []) {
        self.id = id
        self.fileURL = fileURL
        self.themes = themes
        self.actions = actions
        self.stages = stages
        self.host = host
        self.expectedChecks = expectedChecks
    }

    /// The widget's file name without its folder and extension (`auto/03-layout-a` → `03-layout-a`).
    public var baseName: String {
        return self.fileURL.deletingPathExtension().lastPathComponent
    }
}

/// A region the run crops at 2× for the pixel rule: `rect` in CSS px from the widget's top-left.
public struct ConformanceStage {
    public let name: String
    public let rect: CGRect
    public let themes: [String]
}

/// A check the host makes (report.mjs `hostChecks`): a bridge call the widget must reach the host with exactly `count`
/// times, the bubble's height in a range, the chat input keeping the focus; any combination of them.
public struct ConformanceHostCheck {
    public struct Bridge: Equatable {
        public let method: String
        /// Matched against the call's first argument; nil matches any.
        public let argument: String?
        public let count: Int

        public init(method: String, argument: String?, count: Int) {
            self.method = method
            self.argument = argument
            self.count = count
        }
    }

    public let id: String
    public let name: String
    public let bridge: Bridge?
    public let minHeight: Double?
    public let maxHeight: Double?
    /// `focus: "chat"`: the chat input must keep the focus.
    public let focusChat: Bool
    /// The check needs a user gesture, which synthetic input cannot grant.
    public let gesture: Bool
    /// Expected to fail.
    public let xfail: Bool

    public init(id: String, name: String, bridge: Bridge? = nil, minHeight: Double? = nil, maxHeight: Double? = nil, focusChat: Bool = false, gesture: Bool = false, xfail: Bool = false) {
        self.id = id
        self.name = name
        self.bridge = bridge
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.focusChat = focusChat
        self.gesture = gesture
        self.xfail = xfail
    }
}

public enum ConformanceManifest {
    public enum LoadError: Error {
        case missingBundle
        case unreadable(String)
    }

    /// The conformance set inside the app (`//third-party/widget-sandbox:WidgetConformanceBundle`).
    public static func bundleRoot() throws -> URL {
        guard let root = Bundle.main.url(forResource: "WidgetConformance", withExtension: "bundle").flatMap(Bundle.init(url:))?.resourceURL else {
            throw LoadError.missingBundle
        }
        return root
    }

    /// Every test with `set: "auto"`, in the manifest's order.
    public static func loadAutomaticSet() throws -> [ConformanceTest] {
        let root = try self.bundleRoot()
        let data = try Data(contentsOf: root.appendingPathComponent("manifest.json"))
        guard let manifest = try JSONSerialization.jsonObject(with: data) as? [String: Any], let tests = manifest["tests"] as? [[String: Any]] else {
            throw LoadError.unreadable("manifest.json")
        }
        return try tests.filter { ($0["set"] as? String) == "auto" }.map { entry in
            guard let id = entry["id"] as? String, let file = entry["file"] as? String else {
                throw LoadError.unreadable("a test without id or file")
            }
            let themes = (entry["themes"] as? [String]).flatMap { $0.isEmpty ? nil : $0 } ?? ["light"]
            let stages: [ConformanceStage] = ((entry["stages"] as? [[String: Any]]) ?? []).compactMap { stage in
                guard let name = stage["name"] as? String, let rect = stage["rect"] as? [Double], rect.count == 4 else {
                    return nil
                }
                return ConformanceStage(name: name, rect: CGRect(x: rect[0], y: rect[1], width: rect[2], height: rect[3]), themes: (stage["themes"] as? [String]) ?? themes)
            }
            let host: [ConformanceHostCheck] = ((entry["host"] as? [[String: Any]]) ?? []).compactMap { check in
                guard let id = check["id"] as? String else {
                    return nil
                }
                var bridge: ConformanceHostCheck.Bridge?
                if let call = check["bridge"] as? [String: Any], let method = call["method"] as? String {
                    bridge = .init(method: method, argument: call["arg"] as? String, count: (call["count"] as? Int) ?? 1)
                }
                let height = check["height"] as? [String: Any]
                return ConformanceHostCheck(
                    id: id,
                    name: (check["name"] as? String) ?? "",
                    bridge: bridge,
                    minHeight: (height?["min"] as? NSNumber)?.doubleValue,
                    maxHeight: (height?["max"] as? NSNumber)?.doubleValue,
                    focusChat: (check["focus"] as? String) == "chat",
                    gesture: (check["gesture"] as? Bool) ?? false,
                    xfail: (check["xfail"] as? Bool) ?? false
                )
            }
            let expected: [ConformanceCheck] = ((entry["checks"] as? [[String: Any]]) ?? []).compactMap { check in
                guard let id = check["id"] as? String, let name = check["name"] as? String else {
                    return nil
                }
                return ConformanceCheck(id: id, name: name)
            }
            return ConformanceTest(id: id, fileURL: root.appendingPathComponent(file), themes: themes, actions: (entry["actions"] as? [[String: Any]]) ?? [], stages: stages, host: host, expectedChecks: expected)
        }
    }
}

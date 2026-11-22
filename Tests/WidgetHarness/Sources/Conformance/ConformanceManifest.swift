import Foundation
import MessageWidget

/// widget-sandbox v0.2.1 (CLIENTS.md, "The message context"; scripts/conformance/lib.ts `MessageSpec`): how a test's
/// widget is sent, of which the runner takes the first spec: its kind (the server's flags) and its state.
public struct ConformanceMessageSpec: Equatable {
    /// The kind as the manifest names it; `kind` is nil when this client does not know it.
    public let kindName: String
    public let kind: MessageWidgetMessageKind?
    public let chatData: String?
    public let publicData: String?

    public init(kindName: String, chatData: String?, publicData: String?) {
        self.kindName = kindName
        self.kind = MessageWidgetMessageKind(rawValue: kindName)
        self.chatData = chatData
        self.publicData = publicData
    }
}

/// What the test bot does on a request with exactly this data (lib.ts `BotAction`): edit the message's state, edit the
/// shared widget's state, then answer with `result`; `repeat` runs the edits again every `every` s, `times` times in all.
/// Templates in the strings: `{n}` counts the requests with this data, `{from}` is who pressed (first name), `{time}`
/// the bot's HH:MM:SS.
public struct ConformanceBotAction: Equatable {
    public struct Edit: Equatable {
        public var chatData: String?
        public var publicData: String?

        public init(chatData: String?, publicData: String?) {
            self.chatData = chatData
            self.publicData = publicData
        }
    }

    public struct Repeat: Equatable {
        public var every: Double
        public var times: Int

        public init(every: Double, times: Int) {
            self.every = every
            self.times = times
        }
    }

    public var result: String?
    public var edit: Edit?
    /// `editShared.public_data`: the shared widget's state, for every carrier.
    public var editShared: String?
    public var `repeat`: Repeat?

    public init(result: String? = nil, edit: Edit? = nil, editShared: String? = nil, repeat: Repeat? = nil) {
        self.result = result
        self.edit = edit
        self.editShared = editShared
        self.repeat = `repeat`
    }
}

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
    /// A visual widget (`set: "visual"`): run only to see that it loads (CLIENTS.md: "without actions or crops").
    public let loadOnly: Bool
    /// The first of the test's `message` specs (v0.2.1), nil without one: such a test runs as the private chat's
    /// original with no state.
    public let message: ConformanceMessageSpec?
    /// The bot's answers by exact request data (v0.2.1).
    public let bot: [String: ConformanceBotAction]
    /// widget-sandbox v0.3.0: the start of the reason the host must stop the widget with (a counted cap passed on
    /// purpose, `auto/31`–`35`); such a run waits for the stop, not `done`, and passes its `covers` only on that stop.
    public let stops: String?
    /// The catalogue IDs the test covers.
    public let covers: [String]
    /// widget-sandbox v0.4.0: the content safe area its runner passes (the header's `safeArea`: the reference band of a
    /// time drawn over the widget), `none` for every other test.
    public var safeArea: MessageWidgetContentSafeArea = .none

    public init(id: String, fileURL: URL, themes: [String], actions: [[String: Any]], stages: [ConformanceStage], host: [ConformanceHostCheck], expectedChecks: [ConformanceCheck] = [], loadOnly: Bool = false, message: ConformanceMessageSpec? = nil, bot: [String: ConformanceBotAction] = [:], stops: String? = nil, covers: [String] = []) {
        self.id = id
        self.fileURL = fileURL
        self.themes = themes
        self.actions = actions
        self.stages = stages
        self.host = host
        self.expectedChecks = expectedChecks
        self.loadOnly = loadOnly
        self.message = message
        self.bot = bot
        self.stops = stops
        self.covers = covers
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
        return try self.entries(set: "auto").map(self.test)
    }

    /// Every test with `set: "visual"`, in the manifest's order, load-only: its widget, its themes, nothing else.
    public static func loadVisualSet() throws -> [ConformanceTest] {
        let root = try self.bundleRoot()
        return try self.entries(set: "visual").map { entry in
            guard let id = entry["id"] as? String, let file = entry["file"] as? String else {
                throw LoadError.unreadable("a test without id or file")
            }
            let themes = (entry["themes"] as? [String]).flatMap { $0.isEmpty ? nil : $0 } ?? ["light"]
            var test = ConformanceTest(id: id, fileURL: root.appendingPathComponent(file), themes: themes, actions: [], stages: [], host: [], loadOnly: true, message: self.message(entry), bot: self.bot(entry))
            test.safeArea = self.safeArea(entry)
            return test
        }
    }

    /// The first `message` spec, nil when there is none or it is malformed (no kind), as unknown keys are read as absent.
    private static func message(_ entry: [String: Any]) -> ConformanceMessageSpec? {
        guard let spec = (entry["message"] as? [[String: Any]])?.first, let kind = spec["kind"] as? String else {
            return nil
        }
        return ConformanceMessageSpec(kindName: kind, chatData: spec["chat_data"] as? String, publicData: spec["public_data"] as? String)
    }

    /// The `bot` table; an entry that is not an object is left out.
    private static func bot(_ entry: [String: Any]) -> [String: ConformanceBotAction] {
        guard let table = entry["bot"] as? [String: Any] else {
            return [:]
        }
        var actions: [String: ConformanceBotAction] = [:]
        for (data, value) in table {
            guard let action = value as? [String: Any] else {
                continue
            }
            let edit = (action["edit"] as? [String: Any]).map { ConformanceBotAction.Edit(chatData: $0["chat_data"] as? String, publicData: $0["public_data"] as? String) }
            let editShared = (action["editShared"] as? [String: Any])?["public_data"] as? String
            var repeatAction: ConformanceBotAction.Repeat?
            if let repeatSpec = action["repeat"] as? [String: Any], let every = (repeatSpec["every"] as? NSNumber)?.doubleValue, let times = (repeatSpec["times"] as? NSNumber)?.intValue {
                repeatAction = ConformanceBotAction.Repeat(every: every, times: times)
            }
            actions[data] = ConformanceBotAction(result: action["result"] as? String, edit: edit, editShared: editShared, repeat: repeatAction)
        }
        return actions
    }

    private static func entries(set: String) throws -> [[String: Any]] {
        let root = try self.bundleRoot()
        let data = try Data(contentsOf: root.appendingPathComponent("manifest.json"))
        guard let manifest = try JSONSerialization.jsonObject(with: data) as? [String: Any], let tests = manifest["tests"] as? [[String: Any]] else {
            throw LoadError.unreadable("manifest.json")
        }
        return tests.filter { ($0["set"] as? String) == set }
    }

    private static func test(_ entry: [String: Any]) throws -> ConformanceTest {
        let root = try self.bundleRoot()
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
        var test = ConformanceTest(id: id, fileURL: root.appendingPathComponent(file), themes: themes, actions: (entry["actions"] as? [[String: Any]]) ?? [], stages: stages, host: host, expectedChecks: expected, message: self.message(entry), bot: self.bot(entry), stops: entry["stops"] as? String, covers: (entry["covers"] as? [String]) ?? [])
        test.safeArea = self.safeArea(entry)
        return test
    }

    /// widget-sandbox v0.4.0: the header's `safeArea` (the reference band of a time drawn over the widget), `none` without.
    private static func safeArea(_ entry: [String: Any]) -> MessageWidgetContentSafeArea {
        guard let area = entry["safeArea"] as? [String: Any] else {
            return .none
        }
        let value = { (key: String) in CGFloat((area[key] as? NSNumber)?.doubleValue ?? 0.0) }
        return MessageWidgetContentSafeArea(top: value("top"), right: value("right"), bottom: value("bottom"), left: value("left"), cornerLeft: value("cornerLeft"), cornerRight: value("cornerRight"))
    }
}

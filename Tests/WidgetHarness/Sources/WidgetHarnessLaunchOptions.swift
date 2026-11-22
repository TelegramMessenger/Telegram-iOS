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
    /// Only these posts, by their whole paths, in this order (oldest first): a chat laid out for one measurement.
    public var posts: [String]?
    /// The server's kill switch (`MessageWidgetKillSwitch`, the app configuration's
    /// `ios_killswitch_disable_message_widgets`): engaged, every widget message shows the pill.
    public var killSwitch: Bool = false
    /// Overrides every post's size anchors.
    public var anchors: (width: Int32, height: Int32)?
    public var useDarkTheme: Bool = false
    /// The posts arrive from the other side of the chat (incoming bubbles) instead of being the account's own.
    public var incoming: Bool = false
    /// Each widget message carries its caption (the post's text); off, the widget is alone in its bubble.
    public var captions: Bool = true
    /// `-harness-menu hold`: the stand-in context menu stays open until `harness.endMenu` is tapped.
    public var holdsMenu: Bool = false
    /// `-harness-copy-protected on`: the chat forbids copying.
    public var copyProtected: Bool = false
    /// `-harness-can-query on`: every widget message has the server's can_query.
    public var canQuery: Bool = false
    /// `-harness-background-query on`: every widget message also has the server's background_query (requests without
    /// a tap, as in the private chat with the bot).
    public var backgroundQuery: Bool = false
    /// `-harness-chat bot`: the chat is with a bot.
    public var botChat: Bool = false
    /// `-harness-text-size <n>`: Settings ▸ Appearance ▸ Text Size, `PresentationFontSize`'s raw value (0 extra small …
    /// 5 extra large ×2, 6 medium).
    public var textSize: Int32?

    public init() {}

    public static func ==(lhs: WidgetHarnessLaunchOptions, rhs: WidgetHarnessLaunchOptions) -> Bool {
        return lhs.set == rhs.set && lhs.postFilter == rhs.postFilter && lhs.posts == rhs.posts && lhs.killSwitch == rhs.killSwitch
            && lhs.anchors?.width == rhs.anchors?.width && lhs.anchors?.height == rhs.anchors?.height && lhs.useDarkTheme == rhs.useDarkTheme
            && lhs.incoming == rhs.incoming && lhs.captions == rhs.captions && lhs.holdsMenu == rhs.holdsMenu
            && lhs.copyProtected == rhs.copyProtected && lhs.canQuery == rhs.canQuery && lhs.backgroundQuery == rhs.backgroundQuery && lhs.botChat == rhs.botChat && lhs.textSize == rhs.textSize
    }

    /// `-widget-set conformance|corpus|fixture`, `-widget-post <part of a path>`, `-widget-posts <path>,<path>,…`,
    /// `-widget-kill-switch on|off`,
    /// `-widget-anchors <W>x<H>`, `-widget-caption off`, `-harness-theme dark`, `-harness-side incoming`.
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
        options.posts = value("-widget-posts").map { $0.split(separator: ",").map(String.init) }
        options.killSwitch = value("-widget-kill-switch") == "on"
        if let anchors = value("-widget-anchors") {
            let parts = anchors.split(separator: "x").compactMap { Int32($0) }
            if parts.count == 2 {
                options.anchors = (parts[0], parts[1])
            }
        }
        options.useDarkTheme = value("-harness-theme") == "dark"
        options.incoming = value("-harness-side") == "incoming"
        options.captions = value("-widget-caption") != "off"
        options.holdsMenu = value("-harness-menu") == "hold"
        options.copyProtected = value("-harness-copy-protected") == "on"
        options.canQuery = value("-harness-can-query") == "on"
        options.backgroundQuery = value("-harness-background-query") == "on"
        options.botChat = value("-harness-chat") == "bot"
        options.textSize = value("-harness-text-size").flatMap { Int32($0) }
        return options
    }
}

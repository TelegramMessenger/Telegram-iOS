import Foundation

/// The kind of chat a widget's message is in (sdk-v1 §2.13, the Bot API's `Chat.type`).
public enum MessageWidgetChatType: String {
    case `private`
    case group
    case supergroup
    case channel
}

/// The account looking at the widget (sdk-v1 §2.13, Mini Apps' WebAppUser). The runtime leaves out a field that breaks
/// its rule.
public struct MessageWidgetViewer: Hashable {
    public var id: Int64
    public var firstName: String?
    public var lastName: String?
    public var username: String?
    public var isPremium: Bool

    public init(id: Int64, firstName: String? = nil, lastName: String? = nil, username: String? = nil, isPremium: Bool = false) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        self.isPremium = isPremium
    }
}

/// Where a widget is and what it may do (sdk-v1 §2.13, §2.14; widget-sandbox v0.2): the server's flags from its media as
/// they are, the chat's type and the viewer. Fixed for a widget's life: a widget is keyed by it
/// (`MessageWidgetRegistry.Key`), so another context is another widget. The runtime strips what the widget may not see
/// (a copy's chat type, the viewer without `canQuery`, everything about the user in a preview).
public struct MessageWidgetContext: Hashable {
    /// `is_copy`: a forwarded copy.
    public var isCopy: Bool
    /// `can_query`: requests on a tap.
    public var canQuery: Bool
    /// `background_query`: requests without a tap too.
    public var backgroundQuery: Bool
    public var chatType: MessageWidgetChatType?
    public var viewer: MessageWidgetViewer?
    /// An inline result shown before it is sent (sdk-v1 §2.16).
    public var isPreview: Bool

    public init(isCopy: Bool = false, canQuery: Bool = false, backgroundQuery: Bool = false, chatType: MessageWidgetChatType? = nil, viewer: MessageWidgetViewer? = nil, isPreview: Bool = false) {
        self.isCopy = isCopy
        self.canQuery = canQuery
        self.backgroundQuery = backgroundQuery
        self.chatType = chatType
        self.viewer = viewer
        self.isPreview = isPreview
    }
}

/// The bot's state (sdk-v1 §2.13): the chat state and the shared state as the server's bytes, which the runtime checks
/// (only it decides what is text). Never part of a widget's key: a change reaches the running widget as events.
public struct MessageWidgetState: Equatable {
    public var chatData: Data?
    public var publicData: Data?

    public static let empty = MessageWidgetState(chatData: nil, publicData: nil)

    public init(chatData: Data?, publicData: Data?) {
        self.chatData = chatData
        self.publicData = publicData
    }
}

/// The client's outcome for a widget's request (sdk-v1 §2.14): the bot's answer (its `result` bytes, nil for none), or a
/// failure the widget sees as TIMEOUT, RATE_LIMITED or FAILED.
public enum MessageWidgetRequestOutcome: Equatable {
    case answered(Data?)
    case timeout
    case rateLimited
    case failed
}

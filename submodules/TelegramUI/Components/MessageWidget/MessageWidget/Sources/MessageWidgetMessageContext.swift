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
    /// The client has Gram Wallet for this user (sdk-v1 §2.18, §5.13; widget-sandbox v0.5.0): the widget gets
    /// `TelegramWidget.wallet` where it may ask the bot.
    public var wallet: Bool

    public init(isCopy: Bool = false, canQuery: Bool = false, backgroundQuery: Bool = false, chatType: MessageWidgetChatType? = nil, viewer: MessageWidgetViewer? = nil, isPreview: Bool = false, wallet: Bool = false) {
        self.isCopy = isCopy
        self.canQuery = canQuery
        self.backgroundQuery = backgroundQuery
        self.chatType = chatType
        self.viewer = viewer
        self.isPreview = isPreview
        self.wallet = wallet
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

/// What the client draws over the widget (sdk-v1 §2.17, §5.12), in points (CSS px): with no caption below the widget, the
/// band of the message time at its bottom (`bottom`) and the corner the time takes in it, on its physical side
/// (`cornerRight` in a left-to-right interface, `cornerLeft` in a right-to-left one); the rest 0. `none` with a caption
/// below. The runtime keeps an inset of 0–64 and a corner of 0–200, anything else 0, as upstream checks it.
public struct MessageWidgetContentSafeArea: Equatable {
    public var top: CGFloat
    public var right: CGFloat
    public var bottom: CGFloat
    public var left: CGFloat
    public var cornerLeft: CGFloat
    public var cornerRight: CGFloat

    public static let none = MessageWidgetContentSafeArea()

    public init(top: CGFloat = 0.0, right: CGFloat = 0.0, bottom: CGFloat = 0.0, left: CGFloat = 0.0, cornerLeft: CGFloat = 0.0, cornerRight: CGFloat = 0.0) {
        self.top = top
        self.right = right
        self.bottom = bottom
        self.left = left
        self.cornerLeft = cornerLeft
        self.cornerRight = cornerRight
    }
}

/// The client's outcome for a widget's request or wallet call (sdk-v1 §2.14, §2.18): the bot's answer (its `result`
/// bytes, nil for none), or a failure the widget sees as TIMEOUT, RATE_LIMITED or FAILED; for a wallet call also REJECTED
/// (the user declined in the wallet window) and BAD_REQUEST (the wallet refused it), which a request sees as FAILED.
public enum MessageWidgetRequestOutcome: Equatable {
    case answered(Data?)
    case timeout
    case rateLimited
    case failed
    case rejected
    case badRequest
}

/// A wallet call the runtime admitted (sdk-v1 §2.18, widget-sandbox v0.5.0): TON Connect's `sendTransaction` request or
/// its `signData` payload as the runtime checked it, as JSON in TON Connect's field names (keys sorted), and `data`, the
/// label the bot gets with the outcome (1–64 bytes). The client shows its wallet window with the message's bot, sends or
/// signs on the user's confirmation, asks the bot with the outcome and answers with `completeRequest(id:outcome:)`.
public enum MessageWidgetWalletCall: Equatable {
    case sendTransaction(json: String, data: Data)
    case signData(json: String, data: Data)

    public var json: String {
        switch self {
        case let .sendTransaction(json, _), let .signData(json, _):
            return json
        }
    }

    public var data: Data {
        switch self {
        case let .sendTransaction(_, data), let .signData(_, data):
            return data
        }
    }
}

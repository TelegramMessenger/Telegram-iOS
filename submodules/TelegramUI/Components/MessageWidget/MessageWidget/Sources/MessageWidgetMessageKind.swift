import Foundation

/// widget-sandbox v0.2.2's WIDGET_MESSAGE_KINDS (packages/core/src/shared/sdk-policy.ts): the kinds of widget message
/// and the server's flags each has, as the conformance set names them (a `message` spec's `kind`). The conformance
/// runner and the DEBUG insertion of the conformance channel make a message's context from it; a real message's context
/// comes from its media's flags instead.
public enum MessageWidgetMessageKind: String {
    /// The original in the private chat with the bot that sent it.
    case `private`
    /// An original the bot sent to a group (or a supergroup) it is a member of.
    case group
    /// An original sent via the bot (inline mode), here in a private chat between two users.
    case viaBot = "via-bot"
    /// An original the bot sent without `allow_queries`: no requests anywhere, no network marker.
    case noQueries = "no-queries"
    /// A forwarded copy of a widget the bot sent with `fwd_allow_queries`.
    case liveCopy = "live-copy"
    /// A forwarded copy of a widget sent without `fwd_allow_queries`.
    case copy
    /// An inline result in the list, before it is sent.
    case preview

    /// The context of such a message seen by `viewer` (every kind passes it but a preview, which knows nothing about the
    /// user; the runtime strips it further where the widget may not see it).
    public func context(viewer: MessageWidgetViewer?) -> MessageWidgetContext {
        switch self {
        case .private:
            return MessageWidgetContext(isCopy: false, canQuery: true, backgroundQuery: true, chatType: .private, viewer: viewer)
        case .group:
            return MessageWidgetContext(isCopy: false, canQuery: true, backgroundQuery: false, chatType: .group, viewer: viewer)
        case .viaBot:
            return MessageWidgetContext(isCopy: false, canQuery: true, backgroundQuery: false, chatType: .private, viewer: viewer)
        case .noQueries:
            return MessageWidgetContext(isCopy: false, canQuery: false, backgroundQuery: false, chatType: .private, viewer: viewer)
        case .liveCopy:
            return MessageWidgetContext(isCopy: true, canQuery: true, backgroundQuery: false, chatType: .private, viewer: viewer)
        case .copy:
            return MessageWidgetContext(isCopy: true, canQuery: false, backgroundQuery: false, chatType: .private, viewer: viewer)
        case .preview:
            return MessageWidgetContext(isCopy: false, canQuery: false, backgroundQuery: false, chatType: .private, viewer: nil, isPreview: true)
        }
    }
}

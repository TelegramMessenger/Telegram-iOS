/// Opt-in capability for a local @all demonstration hosted by the genuine chat controller.
/// Ordinary cloud chats do not expose collective mentions until a server capability exists.
public protocol ChatAllMentionDemoContents: ChatCustomContentsProtocol {
    var canMentionAll: Bool { get }
    var memberCount: Int { get }
}

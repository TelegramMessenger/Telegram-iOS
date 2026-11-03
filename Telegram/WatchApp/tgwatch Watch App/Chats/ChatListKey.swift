import TDShim

/// Hashable identity for a TDLib `ChatList`. We avoid using `ChatList` directly as a
/// dictionary key because its `Hashable`/`Equatable` conformance may not synthesize
/// cleanly across TDLibKit versions (see CLAUDE.md gotchas).
enum ChatListKey: Hashable {
    case main
    case archive
    case folder(Int)
    /// A `ChatList` variant TDShim's forward-compatible decoder didn't recognize.
    /// Never expected in practice; kept distinct so it can't collide with `.main`.
    case unsupported

    init(_ list: ChatList) {
        switch list {
        case .chatListMain:
            self = .main
        case .chatListArchive:
            self = .archive
        case .chatListFolder(let f):
            self = .folder(f.chatFolderId)
        case .unsupported:
            self = .unsupported
        }
    }
}

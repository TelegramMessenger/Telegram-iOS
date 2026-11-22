import Foundation
import Postbox

/// Whether a history fill should ask the server for thread infos of `peer`'s messages.
///
/// Every channel post is stored with `threadId = 1` (`StoreMessage_Telegram.swift`), and a thread
/// info exists only for a forum topic or a monoforum sublist. Asking a plain channel for topic 1
/// returns nothing, stores nothing, and so repeats on every fill, one sequential round trip before
/// the messages are stored (measured 2026-10-13, three times in one chat open).
func peerCanHaveForumThreads(_ peer: Peer?) -> Bool {
    guard let peer else {
        return false
    }
    return peer.isForumOrMonoForum
}

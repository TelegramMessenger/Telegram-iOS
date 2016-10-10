import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public extension Message {
    var effectivelyIncoming: Bool {
        if self.flags.contains(.Incoming) {
            return true
        } else if let channel = self.peers[self.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
            return true
        } else {
            return false
        }
    }
}

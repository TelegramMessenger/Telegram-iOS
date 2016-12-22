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

public extension Message {
    var visibleButtonKeyboardMarkup: ReplyMarkupMessageAttribute? {
        for attribute in self.attributes {
            if let attribute = attribute as? ReplyMarkupMessageAttribute {
                if !attribute.flags.contains(.inline) && !attribute.rows.isEmpty {
                    if attribute.flags.contains(.personal) {
                        if !self.flags.contains(.Personal) {
                            return nil
                        }
                    }
                    return attribute
                }
            }
        }
        return nil
    }
    
    var requestsSetupReply: Bool {
        for attribute in self.attributes {
            if let attribute = attribute as? ReplyMarkupMessageAttribute {
                if !attribute.flags.contains(.inline) {
                    if attribute.flags.contains(.personal) {
                        if !self.flags.contains(.Personal) {
                            return false
                        }
                    }
                    return attribute.flags.contains(.setupReply)
                }
            }
        }
        return false
    }
}

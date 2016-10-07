import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public struct ExportedInvitation: Coding, Equatable {
    public let link: String
    
    init(link: String) {
        self.link = link
    }
    
    public init(decoder: Decoder) {
        self.link = decoder.decodeStringForKey("l")
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeString(self.link, forKey: "l")
    }
    
    public static func ==(lhs: ExportedInvitation, rhs: ExportedInvitation) -> Bool {
        return lhs.link == rhs.link
    }
}

extension ExportedInvitation {
    init?(apiExportedInvite: Api.ExportedChatInvite) {
        switch apiExportedInvite {
            case .chatInviteEmpty:
                return nil
            case let .chatInviteExported(link):
                self = ExportedInvitation(link: link)
        }
    }
}

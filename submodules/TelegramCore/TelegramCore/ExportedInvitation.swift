import Foundation
#if os(macOS)
    import PostboxMac
    import TelegramApiMac
#else
    import Postbox
    import TelegramApi
#endif

public struct ExportedInvitation: PostboxCoding, Equatable {
    public let link: String
    
    init(link: String) {
        self.link = link
    }
    
    public init(decoder: PostboxDecoder) {
        self.link = decoder.decodeStringForKey("l", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
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

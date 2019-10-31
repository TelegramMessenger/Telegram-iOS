import Foundation
import Postbox

public final class GalleryControllerActionInteraction {
    public let openUrl: (String, Bool) -> Void
    public let openUrlIn: (String) -> Void
    public let openPeerMention: (String) -> Void
    public let openPeer: (PeerId) -> Void
    public let openHashtag: (String?, String) -> Void
    public let openBotCommand: (String) -> Void
    public let addContact: (String) -> Void
    public let storeMediaPlaybackState: (MessageId, Double?) -> Void

       public init(openUrl: @escaping (String, Bool) -> Void, openUrlIn: @escaping (String) -> Void, openPeerMention: @escaping (String) -> Void, openPeer: @escaping (PeerId) -> Void, openHashtag: @escaping (String?, String) -> Void, openBotCommand: @escaping (String) -> Void, addContact: @escaping (String) -> Void, storeMediaPlaybackState: @escaping (MessageId, Double?) -> Void) {
        self.openUrl = openUrl
        self.openUrlIn = openUrlIn
        self.openPeerMention = openPeerMention
        self.openPeer = openPeer
        self.openHashtag = openHashtag
        self.openBotCommand = openBotCommand
        self.addContact = addContact
        self.storeMediaPlaybackState = storeMediaPlaybackState
    }
}

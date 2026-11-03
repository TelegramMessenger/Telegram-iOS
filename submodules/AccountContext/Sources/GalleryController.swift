import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore

public enum GalleryMediaSubject: Hashable {
    case paidMediaIndex(Int)
    case pollDescription
    case pollOption(Data)
    case pollSolution
    case instantPageMedia(EngineMedia.Id)
    /// A specific medium inside a rich message's `RichTextMessageAttribute` InstantPage. Rich media lives
    /// in the attribute, not `message.media`, so `effectiveMedia` can hold several and the default
    /// first-match resolution would open the wrong one. Distinct from `instantPageMedia`, whose only
    /// consumer sits inside `GalleryData`'s `TelegramMediaWebpage` (link-preview) branch.
    case richTextMedia(EngineMedia.Id)
}

public enum GalleryControllerItemSource {
    case peerMessagesAtId(messageId: EngineMessage.Id, chatLocation: ChatLocation, customTag: EngineMemoryBuffer?, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>)
    case standaloneMessage(EngineRawMessage, GalleryMediaSubject?)
    case custom(messages: Signal<([EngineRawMessage], Int32, Bool), NoError>, messageId: EngineMessage.Id, loadMore: (() -> Void)?)
}

public final class GalleryControllerActionInteraction {
    public let openUrl: (String, Bool, Bool) -> Void
    public let openUrlIn: (String) -> Void
    public let openPeerMention: (String) -> Void
    public let openPeer: (EnginePeer) -> Void
    public let openHashtag: (String?, String) -> Void
    public let openBotCommand: (String) -> Void
    public let openAd: (EngineMessage.Id) -> Void
    public let addContact: (String) -> Void
    public let storeMediaPlaybackState: (EngineMessage.Id, Double?, Double) -> Void
    public let editMedia: (EngineMessage.Id, [UIView], @escaping () -> Void) -> Void
    public let updateCanReadHistory: (Bool) -> Void
    public let sendSticker: ((FileMediaReference) -> Void)?

    public init(
        openUrl: @escaping (String, Bool, Bool) -> Void,
        openUrlIn: @escaping (String) -> Void,
        openPeerMention: @escaping (String) -> Void,
        openPeer: @escaping (EnginePeer) -> Void,
        openHashtag: @escaping (String?, String) -> Void,
        openBotCommand: @escaping (String) -> Void,
        openAd: @escaping (EngineMessage.Id) -> Void,
        addContact: @escaping (String) -> Void,
        storeMediaPlaybackState: @escaping (EngineMessage.Id, Double?, Double) -> Void, 
        editMedia: @escaping (EngineMessage.Id, [UIView], @escaping () -> Void) -> Void,
        updateCanReadHistory: @escaping (Bool) -> Void,
        sendSticker: ((FileMediaReference) -> Void)?
    ) {
        self.openUrl = openUrl
        self.openUrlIn = openUrlIn
        self.openPeerMention = openPeerMention
        self.openPeer = openPeer
        self.openHashtag = openHashtag
        self.openBotCommand = openBotCommand
        self.openAd = openAd
        self.addContact = addContact
        self.storeMediaPlaybackState = storeMediaPlaybackState
        self.editMedia = editMedia
        self.updateCanReadHistory = updateCanReadHistory
        self.sendSticker = sendSticker
    }
}

public protocol GalleryControllerProtocol: ViewController {
    
}

public protocol StickerPackScreen {
    
}

public protocol StickerPickerInput {
    
}

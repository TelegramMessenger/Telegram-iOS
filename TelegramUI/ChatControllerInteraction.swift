import Foundation
import Postbox
import AsyncDisplayKit
import TelegramCore
import Display

public enum ChatControllerInitialBotStartBehavior {
    case interactive
    case automatic(returnToPeerId: PeerId)
}

public struct ChatControllerInitialBotStart {
    let payload: String
    let behavior: ChatControllerInitialBotStartBehavior
}

public enum ChatControllerInteractionNavigateToPeer {
    case chat(textInputState: ChatTextInputState?, messageId: MessageId?)
    case info
    case withBotStartPayload(ChatControllerInitialBotStart)
}

struct ChatInterfaceHighlightedState: Equatable {
    let messageStableId: UInt32
    
    static func ==(lhs: ChatInterfaceHighlightedState, rhs: ChatInterfaceHighlightedState) -> Bool {
        return lhs.messageStableId == rhs.messageStableId
    }
}

public enum ChatControllerInteractionLongTapAction {
    case url(String)
    case mention(String)
    case peerMention(PeerId, String)
    case command(String)
    case hashtag(String)
}

public final class ChatControllerInteraction {
    let openMessage: (Message) -> Bool
    let openSecretMessagePreview: (MessageId) -> Void
    let closeSecretMessagePreview: () -> Void
    let openPeer: (PeerId?, ChatControllerInteractionNavigateToPeer, Message?) -> Void
    let openPeerMention: (String) -> Void
    let openMessageContextMenu: (Message, ASDisplayNode, CGRect) -> Void
    let navigateToMessage: (MessageId, MessageId) -> Void
    let clickThroughMessage: () -> Void
    let toggleMessagesSelection: ([MessageId], Bool) -> Void
    let sendMessage: (String) -> Void
    let sendSticker: (TelegramMediaFile) -> Void
    let sendGif: (TelegramMediaFile) -> Void
    let requestMessageActionCallback: (MessageId, MemoryBuffer?, Bool) -> Void
    let openUrl: (String) -> Void
    let shareCurrentLocation: () -> Void
    let shareAccountContact: () -> Void
    let sendBotCommand: (MessageId?, String) -> Void
    let openInstantPage: (Message) -> Void
    let openHashtag: (String?, String) -> Void
    let updateInputState: ((ChatTextInputState) -> ChatTextInputState) -> Void
    let openMessageShareMenu: (MessageId) -> Void
    let presentController: (ViewController, Any?) -> Void
    let presentGlobalOverlayController: (ViewController, Any?) -> Void
    let callPeer: (PeerId) -> Void
    let longTap: (ChatControllerInteractionLongTapAction) -> Void
    let openCheckoutOrReceipt: (MessageId) -> Void
    let openSearch: () -> Void
    let setupReply: (MessageId) -> Void
    let canSetupReply: (Message) -> Bool
    
    let requestMessageUpdate: (MessageId) -> Void
    
    var hiddenMedia: [MessageId: [Media]] = [:]
    var selectionState: ChatInterfaceSelectionState?
    var highlightedState: ChatInterfaceHighlightedState?
    var contextHighlightedState: ChatInterfaceHighlightedState?
    var automaticMediaDownloadSettings: AutomaticMediaDownloadSettings
    
    public init(openMessage: @escaping (Message) -> Bool, openSecretMessagePreview: @escaping (MessageId) -> Void, closeSecretMessagePreview: @escaping () -> Void, openPeer: @escaping (PeerId?, ChatControllerInteractionNavigateToPeer, Message?) -> Void, openPeerMention: @escaping (String) -> Void, openMessageContextMenu: @escaping (Message, ASDisplayNode, CGRect) -> Void, navigateToMessage: @escaping (MessageId, MessageId) -> Void, clickThroughMessage: @escaping () -> Void, toggleMessagesSelection: @escaping ([MessageId], Bool) -> Void, sendMessage: @escaping (String) -> Void, sendSticker: @escaping (TelegramMediaFile) -> Void, sendGif: @escaping (TelegramMediaFile) -> Void, requestMessageActionCallback: @escaping (MessageId, MemoryBuffer?, Bool) -> Void, openUrl: @escaping (String) -> Void, shareCurrentLocation: @escaping () -> Void, shareAccountContact: @escaping () -> Void, sendBotCommand: @escaping (MessageId?, String) -> Void, openInstantPage: @escaping (Message) -> Void, openHashtag: @escaping (String?, String) -> Void, updateInputState: @escaping ((ChatTextInputState) -> ChatTextInputState) -> Void, openMessageShareMenu: @escaping (MessageId) -> Void, presentController: @escaping  (ViewController, Any?) -> Void, presentGlobalOverlayController: @escaping (ViewController, Any?) -> Void, callPeer: @escaping (PeerId) -> Void, longTap: @escaping (ChatControllerInteractionLongTapAction) -> Void, openCheckoutOrReceipt: @escaping (MessageId) -> Void, openSearch: @escaping () -> Void, setupReply: @escaping (MessageId) -> Void, canSetupReply: @escaping (Message) -> Bool, requestMessageUpdate: @escaping (MessageId) -> Void, automaticMediaDownloadSettings: AutomaticMediaDownloadSettings) {
        self.openMessage = openMessage
        self.openSecretMessagePreview = openSecretMessagePreview
        self.closeSecretMessagePreview = closeSecretMessagePreview
        self.openPeer = openPeer
        self.openPeerMention = openPeerMention
        self.openMessageContextMenu = openMessageContextMenu
        self.navigateToMessage = navigateToMessage
        self.clickThroughMessage = clickThroughMessage
        self.toggleMessagesSelection = toggleMessagesSelection
        self.sendMessage = sendMessage
        self.sendSticker = sendSticker
        self.sendGif = sendGif
        self.requestMessageActionCallback = requestMessageActionCallback
        self.openUrl = openUrl
        self.shareCurrentLocation = shareCurrentLocation
        self.shareAccountContact = shareAccountContact
        self.sendBotCommand = sendBotCommand
        self.openInstantPage = openInstantPage
        self.openHashtag = openHashtag
        self.updateInputState = updateInputState
        self.openMessageShareMenu = openMessageShareMenu
        self.presentController = presentController
        self.presentGlobalOverlayController = presentGlobalOverlayController
        self.callPeer = callPeer
        self.longTap = longTap
        self.openCheckoutOrReceipt = openCheckoutOrReceipt
        self.openSearch = openSearch
        self.setupReply = setupReply
        self.canSetupReply = canSetupReply
        
        self.requestMessageUpdate = requestMessageUpdate
        
        self.automaticMediaDownloadSettings = automaticMediaDownloadSettings
    }
}

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
    case `default`
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

public enum ChatControllerInteractionOpenMessageMode {
    case `default`
    case stream
    case shared
}

public final class ChatControllerInteraction {
    let openMessage: (Message, ChatControllerInteractionOpenMessageMode) -> Bool
    let openPeer: (PeerId?, ChatControllerInteractionNavigateToPeer, Message?) -> Void
    let openPeerMention: (String) -> Void
    let openMessageContextMenu: (Message, ASDisplayNode, CGRect) -> Void
    let navigateToMessage: (MessageId, MessageId) -> Void
    let clickThroughMessage: () -> Void
    let toggleMessagesSelection: ([MessageId], Bool) -> Void
    let sendMessage: (String) -> Void
    let sendSticker: (FileMediaReference, Bool) -> Void
    let sendGif: (FileMediaReference) -> Void
    let requestMessageActionCallback: (MessageId, MemoryBuffer?, Bool) -> Void
    let activateSwitchInline: (PeerId?, String) -> Void
    let openUrl: (String, Bool, Bool?) -> Void
    let shareCurrentLocation: () -> Void
    let shareAccountContact: () -> Void
    let sendBotCommand: (MessageId?, String) -> Void
    let openInstantPage: (Message) -> Void
    let openHashtag: (String?, String) -> Void
    let updateInputState: ((ChatTextInputState) -> ChatTextInputState) -> Void
    let updateInputMode: ((ChatInputMode) -> ChatInputMode) -> Void
    let openMessageShareMenu: (MessageId) -> Void
    let presentController: (ViewController, Any?) -> Void
    let navigationController: () -> NavigationController?
    let presentGlobalOverlayController: (ViewController, Any?) -> Void
    let callPeer: (PeerId) -> Void
    let longTap: (ChatControllerInteractionLongTapAction) -> Void
    let openCheckoutOrReceipt: (MessageId) -> Void
    let openSearch: () -> Void
    let setupReply: (MessageId) -> Void
    let canSetupReply: (Message) -> Bool
    let navigateToFirstDateMessage: (Int32) -> Void
    let requestRedeliveryOfFailedMessages: (MessageId) -> Void
    let addContact: (String) -> Void
    
    let requestMessageUpdate: (MessageId) -> Void
    let cancelInteractiveKeyboardGestures: () -> Void
    
    var hiddenMedia: [MessageId: [Media]] = [:]
    var selectionState: ChatInterfaceSelectionState?
    var highlightedState: ChatInterfaceHighlightedState?
    var contextHighlightedState: ChatInterfaceHighlightedState?
    var automaticMediaDownloadSettings: AutomaticMediaDownloadSettings
    
    init(openMessage: @escaping (Message, ChatControllerInteractionOpenMessageMode) -> Bool, openPeer: @escaping (PeerId?, ChatControllerInteractionNavigateToPeer, Message?) -> Void, openPeerMention: @escaping (String) -> Void, openMessageContextMenu: @escaping (Message, ASDisplayNode, CGRect) -> Void, navigateToMessage: @escaping (MessageId, MessageId) -> Void, clickThroughMessage: @escaping () -> Void, toggleMessagesSelection: @escaping ([MessageId], Bool) -> Void, sendMessage: @escaping (String) -> Void, sendSticker: @escaping (FileMediaReference, Bool) -> Void, sendGif: @escaping (FileMediaReference) -> Void, requestMessageActionCallback: @escaping (MessageId, MemoryBuffer?, Bool) -> Void, activateSwitchInline: @escaping (PeerId?, String) -> Void, openUrl: @escaping (String, Bool, Bool?) -> Void, shareCurrentLocation: @escaping () -> Void, shareAccountContact: @escaping () -> Void, sendBotCommand: @escaping (MessageId?, String) -> Void, openInstantPage: @escaping (Message) -> Void, openHashtag: @escaping (String?, String) -> Void, updateInputState: @escaping ((ChatTextInputState) -> ChatTextInputState) -> Void, updateInputMode: @escaping ((ChatInputMode) -> ChatInputMode) -> Void, openMessageShareMenu: @escaping (MessageId) -> Void, presentController: @escaping  (ViewController, Any?) -> Void, navigationController: @escaping () -> NavigationController?, presentGlobalOverlayController: @escaping (ViewController, Any?) -> Void, callPeer: @escaping (PeerId) -> Void, longTap: @escaping (ChatControllerInteractionLongTapAction) -> Void, openCheckoutOrReceipt: @escaping (MessageId) -> Void, openSearch: @escaping () -> Void, setupReply: @escaping (MessageId) -> Void, canSetupReply: @escaping (Message) -> Bool, navigateToFirstDateMessage: @escaping(Int32) ->Void, requestRedeliveryOfFailedMessages: @escaping (MessageId) -> Void, addContact: @escaping (String) -> Void, requestMessageUpdate: @escaping (MessageId) -> Void, cancelInteractiveKeyboardGestures: @escaping () -> Void, automaticMediaDownloadSettings: AutomaticMediaDownloadSettings) {
        self.openMessage = openMessage
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
        self.activateSwitchInline = activateSwitchInline
        self.openUrl = openUrl
        self.shareCurrentLocation = shareCurrentLocation
        self.shareAccountContact = shareAccountContact
        self.sendBotCommand = sendBotCommand
        self.openInstantPage = openInstantPage
        self.openHashtag = openHashtag
        self.updateInputState = updateInputState
        self.updateInputMode = updateInputMode
        self.openMessageShareMenu = openMessageShareMenu
        self.presentController = presentController
        self.navigationController = navigationController
        self.presentGlobalOverlayController = presentGlobalOverlayController
        self.callPeer = callPeer
        self.longTap = longTap
        self.openCheckoutOrReceipt = openCheckoutOrReceipt
        self.openSearch = openSearch
        self.setupReply = setupReply
        self.canSetupReply = canSetupReply
        self.navigateToFirstDateMessage = navigateToFirstDateMessage
        self.requestRedeliveryOfFailedMessages = requestRedeliveryOfFailedMessages
        self.addContact = addContact
        
        self.requestMessageUpdate = requestMessageUpdate
        self.cancelInteractiveKeyboardGestures = cancelInteractiveKeyboardGestures
        
        self.automaticMediaDownloadSettings = automaticMediaDownloadSettings
    }
}

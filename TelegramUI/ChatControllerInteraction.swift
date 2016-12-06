import Foundation
import Postbox
import AsyncDisplayKit
import TelegramCore

public enum ChatControllerInteractionNavigateToPeer {
    case chat(textInputState: ChatTextInputState?)
    case info
}

public final class ChatControllerInteraction {
    let openMessage: (MessageId) -> Void
    let openPeer: (PeerId?, ChatControllerInteractionNavigateToPeer) -> Void
    let openPeerMention: (String) -> Void
    let openMessageContextMenu: (MessageId, ASDisplayNode, CGRect) -> Void
    let navigateToMessage: (MessageId, MessageId) -> Void
    let clickThroughMessage: () -> Void
    var hiddenMedia: [MessageId: [Media]] = [:]
    var selectionState: ChatInterfaceSelectionState?
    let toggleMessageSelection: (MessageId) -> Void
    let sendMessage: (String) -> Void
    let sendSticker: (TelegramMediaFile) -> Void
    let requestMessageActionCallback: (MessageId, MemoryBuffer?) -> Void
    let openUrl: (String) -> Void
    let shareCurrentLocation: () -> Void
    let shareAccountContact: () -> Void
    let sendBotCommand: (MessageId, String) -> Void
    let updateInputState: ((ChatTextInputState) -> ChatTextInputState) -> Void
    
    public init(openMessage: @escaping (MessageId) -> Void, openPeer: @escaping (PeerId?, ChatControllerInteractionNavigateToPeer) -> Void, openPeerMention: @escaping (String) -> Void, openMessageContextMenu: @escaping (MessageId, ASDisplayNode, CGRect) -> Void, navigateToMessage: @escaping (MessageId, MessageId) -> Void, clickThroughMessage: @escaping () -> Void, toggleMessageSelection: @escaping (MessageId) -> Void, sendMessage: @escaping (String) -> Void, sendSticker: @escaping (TelegramMediaFile) -> Void, requestMessageActionCallback: @escaping (MessageId, MemoryBuffer?) -> Void, openUrl: @escaping (String) -> Void, shareCurrentLocation: @escaping () -> Void, shareAccountContact: @escaping () -> Void, sendBotCommand: @escaping (MessageId, String) -> Void, updateInputState: @escaping ((ChatTextInputState) -> ChatTextInputState) -> Void) {
        self.openMessage = openMessage
        self.openPeer = openPeer
        self.openPeerMention = openPeerMention
        self.openMessageContextMenu = openMessageContextMenu
        self.navigateToMessage = navigateToMessage
        self.clickThroughMessage = clickThroughMessage
        self.toggleMessageSelection = toggleMessageSelection
        self.sendMessage = sendMessage
        self.sendSticker = sendSticker
        self.requestMessageActionCallback = requestMessageActionCallback
        self.openUrl = openUrl
        self.shareCurrentLocation = shareCurrentLocation
        self.shareAccountContact = shareAccountContact
        self.sendBotCommand = sendBotCommand
        self.updateInputState = updateInputState
    }
}

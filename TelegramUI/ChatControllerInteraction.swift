import Foundation
import Postbox
import AsyncDisplayKit

public enum ChatControllerInteractionNavigateToPeer {
    case chat
    case info
}

public final class ChatControllerInteraction {
    let openMessage: (MessageId) -> Void
    let openPeer: (PeerId, ChatControllerInteractionNavigateToPeer) -> Void
    let openMessageContextMenu: @escaping (MessageId, ASDisplayNode, CGRect) -> Void
    let navigateToMessage: (MessageId, MessageId) -> Void
    let clickThroughMessage: () -> Void
    var hiddenMedia: [MessageId: [Media]] = [:]
    var selectionState: ChatInterfaceSelectionState?
    let toggleMessageSelection: (MessageId) -> Void
    
    public init(openMessage: @escaping (MessageId) -> Void, openPeer: @escaping (PeerId, ChatControllerInteractionNavigateToPeer) -> Void, openMessageContextMenu: @escaping (MessageId, ASDisplayNode, CGRect) -> Void, navigateToMessage: @escaping (MessageId, MessageId) -> Void, clickThroughMessage: @escaping () -> Void, toggleMessageSelection: @escaping (MessageId) -> Void) {
        self.openMessage = openMessage
        self.openPeer = openPeer
        self.openMessageContextMenu = openMessageContextMenu
        self.navigateToMessage = navigateToMessage
        self.clickThroughMessage = clickThroughMessage
        self.toggleMessageSelection = toggleMessageSelection
    }
}

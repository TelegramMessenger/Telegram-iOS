import Foundation
import UIKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import Display
import AsyncDisplayKit

public enum ChatControllerInteractionOpenMessageMode {
    case `default`
    case stream
    case automaticPlayback
    case landscape
    case timecode(Double)
    case link
}

public final class OpenChatMessageParams {
    public let context: AccountContext
    public let message: Message
    public let standalone: Bool
    public let reverseMessageGalleryOrder: Bool
    public let mode: ChatControllerInteractionOpenMessageMode
    public let navigationController: NavigationController?
    public let modal: Bool
    public let dismissInput: () -> Void
    public let present: (ViewController, Any?) -> Void
    public let transitionNode: (MessageId, Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
    public let addToTransitionSurface: (UIView) -> Void
    public let openUrl: (String) -> Void
    public let openPeer: (Peer, ChatControllerInteractionNavigateToPeer) -> Void
    public let callPeer: (PeerId) -> Void
    public let enqueueMessage: (EnqueueMessage) -> Void
    public let sendSticker: ((FileMediaReference, ASDisplayNode, CGRect) -> Bool)?
    public let setupTemporaryHiddenMedia: (Signal<Any?, NoError>, Int, Media) -> Void
    public let chatAvatarHiddenMedia: (Signal<MessageId?, NoError>, Media) -> Void
    public let actionInteraction: GalleryControllerActionInteraction?
    
    public init(
        context: AccountContext,
        message: Message,
        standalone: Bool,
        reverseMessageGalleryOrder: Bool,
        mode: ChatControllerInteractionOpenMessageMode = .default,
        navigationController: NavigationController?,
        modal: Bool = false,
        dismissInput: @escaping () -> Void,
        present: @escaping (ViewController, Any?) -> Void,
        transitionNode: @escaping (MessageId, Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?,
        addToTransitionSurface: @escaping (UIView) -> Void,
        openUrl: @escaping (String) -> Void,
        openPeer: @escaping (Peer, ChatControllerInteractionNavigateToPeer) -> Void,
        callPeer: @escaping (PeerId) -> Void,
        enqueueMessage: @escaping (EnqueueMessage) -> Void,
        sendSticker: ((FileMediaReference, ASDisplayNode, CGRect) -> Bool)?,
        setupTemporaryHiddenMedia: @escaping (Signal<Any?, NoError>, Int, Media) -> Void,
        chatAvatarHiddenMedia: @escaping (Signal<MessageId?, NoError>, Media) -> Void,
        actionInteraction: GalleryControllerActionInteraction? = nil
    ) {
        self.context = context
        self.message = message
        self.standalone = standalone
        self.reverseMessageGalleryOrder = reverseMessageGalleryOrder
        self.mode = mode
        self.navigationController = navigationController
        self.modal = modal
        self.dismissInput = dismissInput
        self.present = present
        self.transitionNode = transitionNode
        self.addToTransitionSurface = addToTransitionSurface
        self.openUrl = openUrl
        self.openPeer = openPeer
        self.callPeer = callPeer
        self.enqueueMessage = enqueueMessage
        self.sendSticker = sendSticker
        self.setupTemporaryHiddenMedia = setupTemporaryHiddenMedia
        self.chatAvatarHiddenMedia = chatAvatarHiddenMedia
        self.actionInteraction = actionInteraction
    }
}

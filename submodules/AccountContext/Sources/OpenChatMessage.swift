import Foundation
import UIKit
import TelegramCore
import SwiftSignalKit
import Display
import AsyncDisplayKit
import UniversalMediaPlayer
import TelegramPresentationData
import TextFormat

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
    public let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    public let chatLocation: ChatLocation?
    public let chatFilterTag: EngineMemoryBuffer?
    public let chatLocationContextHolder: Atomic<ChatLocationContextHolder?>?
    public let message: EngineRawMessage
    public let mediaSubject: GalleryMediaSubject?
    public let standalone: Bool
    public let copyProtected: Bool
    public let reverseMessageGalleryOrder: Bool
    public let mode: ChatControllerInteractionOpenMessageMode
    public let navigationController: NavigationController?
    public let modal: Bool
    public let dismissInput: () -> Void
    public let present: (ViewController, Any?, PresentationContextType) -> Void
    public let transitionNode: (EngineMessage.Id, EngineRawMedia, Bool) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
    public let addToTransitionSurface: (UIView) -> Void
    public let openUrl: (String) -> Void
    public let openPeer: (EngineRawPeer, ChatControllerInteractionNavigateToPeer) -> Void
    public let callPeer: (EnginePeer.Id, Bool) -> Void
    public let openConferenceCall: (EngineRawMessage) -> Void
    public let enqueueMessage: (EnqueueMessage) -> Void
    public let sendSticker: ((FileMediaReference, UIView?, CGRect?) -> Bool)?
    public let sendEmoji: ((String, ChatTextInputTextCustomEmojiAttribute) -> Void)?
    public let setupTemporaryHiddenMedia: (Signal<Any?, NoError>, Int, EngineRawMedia) -> Void
    public let chatAvatarHiddenMedia: (Signal<EngineMessage.Id?, NoError>, EngineRawMedia) -> Void
    public let actionInteraction: GalleryControllerActionInteraction?
    public let playlistLocation: PeerMessagesPlaylistLocation?
    public let gallerySource: GalleryControllerItemSource?
    public let centralItemUpdated: ((EngineMessage.Id) -> Void)?
    public let navigateToMessageContext: ((EngineMessage) -> Void)?
    public let getSourceRect: (() -> CGRect?)?
    public let blockInteraction: Promise<Bool>
    
    public init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
        chatLocation: ChatLocation?,
        chatFilterTag: EngineMemoryBuffer?,
        chatLocationContextHolder: Atomic<ChatLocationContextHolder?>?,
        message: EngineRawMessage,
        mediaSubject: GalleryMediaSubject? = nil,
        standalone: Bool,
        copyProtected: Bool = false,
        reverseMessageGalleryOrder: Bool,
        mode: ChatControllerInteractionOpenMessageMode = .default,
        navigationController: NavigationController?,
        modal: Bool = false,
        dismissInput: @escaping () -> Void,
        present: @escaping (ViewController, Any?, PresentationContextType) -> Void,
        transitionNode: @escaping (EngineMessage.Id, EngineRawMedia, Bool) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?,
        addToTransitionSurface: @escaping (UIView) -> Void,
        openUrl: @escaping (String) -> Void,
        openPeer: @escaping (EngineRawPeer, ChatControllerInteractionNavigateToPeer) -> Void,
        callPeer: @escaping (EnginePeer.Id, Bool) -> Void,
        openConferenceCall: @escaping (EngineRawMessage) -> Void,
        enqueueMessage: @escaping (EnqueueMessage) -> Void,
        sendSticker: ((FileMediaReference, UIView?, CGRect?) -> Bool)?,
        sendEmoji: ((String, ChatTextInputTextCustomEmojiAttribute) -> Void)?,
        setupTemporaryHiddenMedia: @escaping (Signal<Any?, NoError>, Int, EngineRawMedia) -> Void,
        chatAvatarHiddenMedia: @escaping (Signal<EngineMessage.Id?, NoError>, EngineRawMedia) -> Void,
        actionInteraction: GalleryControllerActionInteraction? = nil,
        playlistLocation: PeerMessagesPlaylistLocation? = nil,
        gallerySource: GalleryControllerItemSource? = nil,
        centralItemUpdated: ((EngineMessage.Id) -> Void)? = nil,
        navigateToMessageContext: ((EngineMessage) -> Void)? = nil,
        getSourceRect: (() -> CGRect?)? = nil
    ) {
        self.context = context
        self.updatedPresentationData = updatedPresentationData
        self.chatLocation = chatLocation
        self.chatFilterTag = chatFilterTag
        self.chatLocationContextHolder = chatLocationContextHolder
        self.message = message
        self.mediaSubject = mediaSubject
        self.standalone = standalone
        self.copyProtected = copyProtected
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
        self.openConferenceCall = openConferenceCall
        self.enqueueMessage = enqueueMessage
        self.sendSticker = sendSticker
        self.sendEmoji = sendEmoji
        self.setupTemporaryHiddenMedia = setupTemporaryHiddenMedia
        self.chatAvatarHiddenMedia = chatAvatarHiddenMedia
        self.actionInteraction = actionInteraction
        self.playlistLocation = playlistLocation
        self.gallerySource = gallerySource
        self.centralItemUpdated = centralItemUpdated
        self.navigateToMessageContext = navigateToMessageContext
        self.getSourceRect = getSourceRect
        self.blockInteraction = Promise()
    }
}

import Foundation
import UIKit
import Photos
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences

public let chatMediaEditorV2KillswitchKey = "ios_killswitch_disable_chat_media_editor_v2"

public func chatMediaEditorV2Enabled(legacyOverride: Bool, killswitchPresent: Bool) -> Bool {
    return !legacyOverride && !killswitchPresent
}

public extension AccountContext {
    var usesChatMediaEditorV2: Bool {
        return chatMediaEditorV2Enabled(
            legacyOverride: self.sharedContext.immediateExperimentalUISettings.chatMediaEditorLegacy,
            killswitchPresent: self.getAppConfigValue(chatMediaEditorV2KillswitchKey) != nil
        )
    }
}

public func chatMediaGalleryHasTimer(peerId: EnginePeer.Id?, accountPeerId: EnginePeer.Id) -> Bool {
    guard let peerId else {
        return false
    }
    return peerId.namespace == Namespaces.Peer.CloudUser && peerId != accountPeerId
}

public func chatMediaGalleryHasCoverButton(isBroadcastChannel: Bool, peerId: EnginePeer.Id?, accountPeerId: EnginePeer.Id) -> Bool {
    return isBroadcastChannel || peerId == accountPeerId
}

public func chatMediaGalleryHasCoverButton(peer: EnginePeer?, accountPeerId: EnginePeer.Id) -> Bool {
    var isBroadcastChannel = false
    if case let .channel(channel) = peer, case .broadcast = channel.info {
        isBroadcastChannel = true
    }
    return chatMediaGalleryHasCoverButton(isBroadcastChannel: isBroadcastChannel, peerId: peer?.id, accountPeerId: accountPeerId)
}

public func chatMediaGalleryHasLivePhotoButton(peerId: EnginePeer.Id?) -> Bool {
    guard let peerId else {
        return false
    }
    return peerId.namespace != Namespaces.Peer.SecretChat
}

public enum ChatMediaGallerySource {
    case fetchResult(PHFetchResult<PHAsset>, index: Int, reversed: Bool)
    case selection(focusUniqueId: String)
}

public protocol ChatMediaGalleryController: AnyObject {
    func sendTransitionSnapshotView() -> UIView?
    func dismissGallery()
}

public final class ChatMediaGalleryParameters {
    public let source: ChatMediaGallerySource
    public let itemStore: Any
    public let selectionContext: Any?
    public let editingContext: Any
    public let recipientName: String?
    public let isActionButtonDone: Bool
    public let isScheduledMessages: Bool
    public let hasSendMenu: Bool
    public let hasSilentPosting: Bool
    public let hasSchedule: Bool
    public let hasTimer: Bool
    public let hasCoverButton: Bool
    public let hasLivePhotoButton: Bool
    public let reminder: Bool
    public let sendWhenOnlineAvailable: Signal<Bool, NoError>
    public let sendInProgress: Signal<Bool, NoError>
    public let immediateThumbnail: UIImage?
    public let getCaptionPanelView: () -> Any?
    public let presentSchedulePicker: (@escaping (Int32, Bool) -> Void) -> Void
    public let presentTimerPicker: (@escaping (Int32) -> Void) -> Void
    public let editCover: ((CGSize, @escaping (UIImage) -> Void, @escaping () -> Void) -> Void)?
    public let transitionHostView: () -> UIView?
    public let transitionView: (String) -> UIView?
    public let updateHiddenMedia: (String?) -> Void
    public let finishedTransitionIn: () -> Void
    public let willTransitionOut: () -> Void
    public let sendSelected: (_ currentItem: Any, _ silently: Bool, _ scheduleTime: Int32?, _ completion: @escaping () -> Void) -> Bool
    public let dismissAll: () -> Void
    public let isFilePreview: Bool
    public let isCropOnly: Bool

    public init(
        source: ChatMediaGallerySource,
        itemStore: Any,
        selectionContext: Any?,
        editingContext: Any,
        recipientName: String?,
        isActionButtonDone: Bool,
        isScheduledMessages: Bool,
        hasSendMenu: Bool,
        hasSilentPosting: Bool,
        hasSchedule: Bool,
        hasTimer: Bool,
        hasCoverButton: Bool,
        hasLivePhotoButton: Bool,
        reminder: Bool,
        sendWhenOnlineAvailable: Signal<Bool, NoError>,
        sendInProgress: Signal<Bool, NoError>,
        immediateThumbnail: UIImage?,
        getCaptionPanelView: @escaping () -> Any?,
        presentSchedulePicker: @escaping (@escaping (Int32, Bool) -> Void) -> Void,
        presentTimerPicker: @escaping (@escaping (Int32) -> Void) -> Void,
        editCover: ((CGSize, @escaping (UIImage) -> Void, @escaping () -> Void) -> Void)?,
        transitionHostView: @escaping () -> UIView?,
        transitionView: @escaping (String) -> UIView?,
        updateHiddenMedia: @escaping (String?) -> Void,
        finishedTransitionIn: @escaping () -> Void,
        willTransitionOut: @escaping () -> Void,
        sendSelected: @escaping (_ currentItem: Any, _ silently: Bool, _ scheduleTime: Int32?, _ completion: @escaping () -> Void) -> Bool,
        dismissAll: @escaping () -> Void,
        isFilePreview: Bool = false,
        isCropOnly: Bool = false
    ) {
        self.source = source
        self.itemStore = itemStore
        self.selectionContext = selectionContext
        self.editingContext = editingContext
        self.recipientName = recipientName
        self.isActionButtonDone = isActionButtonDone
        self.isScheduledMessages = isScheduledMessages
        self.hasSendMenu = hasSendMenu
        self.hasSilentPosting = hasSilentPosting
        self.hasSchedule = hasSchedule
        self.hasTimer = hasTimer
        self.hasCoverButton = hasCoverButton
        self.hasLivePhotoButton = hasLivePhotoButton
        self.reminder = reminder
        self.sendWhenOnlineAvailable = sendWhenOnlineAvailable
        self.sendInProgress = sendInProgress
        self.immediateThumbnail = immediateThumbnail
        self.getCaptionPanelView = getCaptionPanelView
        self.presentSchedulePicker = presentSchedulePicker
        self.presentTimerPicker = presentTimerPicker
        self.editCover = editCover
        self.transitionHostView = transitionHostView
        self.transitionView = transitionView
        self.updateHiddenMedia = updateHiddenMedia
        self.finishedTransitionIn = finishedTransitionIn
        self.willTransitionOut = willTransitionOut
        self.sendSelected = sendSelected
        self.dismissAll = dismissAll
        self.isFilePreview = isFilePreview
        self.isCropOnly = isCropOnly
    }
}

public final class ChatCameraScreenParameters {
    public let camera: ChatCameraParams
    public let peer: EnginePeer?
    public let isEditingMessage: Bool
    public let mediaGrouping: Bool
    public let initialCaption: NSAttributedString
    public let hasSchedule: Bool
    public let sendPaidMessageStars: Int64
    public let getCaptionPanelView: () -> Any?
    public let presentSchedulePicker: (@escaping (Int32, Bool) -> Void) -> Void
    public let presentTimerPicker: (@escaping (Int32) -> Void) -> Void
    public let completion: (_ messages: Any, _ count: Int32, _ silently: Bool, _ scheduleTime: Int32?, _ parameters: ChatSendMessageActionSheetController.SendParameters?, _ getAnimatedTransitionSource: @escaping (String) -> UIView?, _ completion: @escaping () -> Void) -> Void

    public init(
        camera: ChatCameraParams,
        peer: EnginePeer?,
        isEditingMessage: Bool,
        mediaGrouping: Bool,
        initialCaption: NSAttributedString,
        hasSchedule: Bool,
        sendPaidMessageStars: Int64,
        getCaptionPanelView: @escaping () -> Any?,
        presentSchedulePicker: @escaping (@escaping (Int32, Bool) -> Void) -> Void,
        presentTimerPicker: @escaping (@escaping (Int32) -> Void) -> Void,
        completion: @escaping (_ messages: Any, _ count: Int32, _ silently: Bool, _ scheduleTime: Int32?, _ parameters: ChatSendMessageActionSheetController.SendParameters?, _ getAnimatedTransitionSource: @escaping (String) -> UIView?, _ completion: @escaping () -> Void) -> Void
    ) {
        self.camera = camera
        self.peer = peer
        self.isEditingMessage = isEditingMessage
        self.mediaGrouping = mediaGrouping
        self.initialCaption = initialCaption
        self.hasSchedule = hasSchedule
        self.sendPaidMessageStars = sendPaidMessageStars
        self.getCaptionPanelView = getCaptionPanelView
        self.presentSchedulePicker = presentSchedulePicker
        self.presentTimerPicker = presentTimerPicker
        self.completion = completion
    }
}

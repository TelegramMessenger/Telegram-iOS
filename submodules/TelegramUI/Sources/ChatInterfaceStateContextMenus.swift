import Foundation
import UIKit
import Postbox
import TelegramCore
import SyncCore
import AsyncDisplayKit
import Display
import UIKit
import SwiftSignalKit
import MobileCoreServices
import TelegramVoip
import OverlayStatusController
import AccountContext
import ContextUI
import LegacyUI
import AppBundle
import SaveToCameraRoll
import PresentationDataUtils
import TelegramPresentationData
import TelegramStringFormatting
import UndoUI

private struct MessageContextMenuData {
    let starStatus: Bool?
    let canReply: Bool
    let canPin: Bool
    let canEdit: Bool
    let canSelect: Bool
    let resourceStatus: MediaResourceStatus?
    let messageActions: ChatAvailableMessageActions
}

func canEditMessage(context: AccountContext, limitsConfiguration: LimitsConfiguration, message: Message) -> Bool {
    return canEditMessage(accountPeerId: context.account.peerId, limitsConfiguration: limitsConfiguration, message: message)
}

private func canEditMessage(accountPeerId: PeerId, limitsConfiguration: LimitsConfiguration, message: Message, reschedule: Bool = false) -> Bool {
    var hasEditRights = false
    var unlimitedInterval = reschedule
    
    if message.id.namespace == Namespaces.Message.ScheduledCloud {
        if let peer = message.peers[message.id.peerId], let channel = peer as? TelegramChannel {
            switch channel.info {
                case .broadcast:
                    if channel.hasPermission(.editAllMessages) || !message.flags.contains(.Incoming) {
                        hasEditRights = true
                    }
                default:
                    hasEditRights = true
            }
        } else {
            hasEditRights = true
        }
    } else if message.id.peerId.namespace == Namespaces.Peer.SecretChat || message.id.namespace != Namespaces.Message.Cloud {
        hasEditRights = false
    } else if let author = message.author, author.id == accountPeerId, let peer = message.peers[message.id.peerId] {
        hasEditRights = true
        if let peer = peer as? TelegramChannel {
            if peer.flags.contains(.isGigagroup) {
                if peer.flags.contains(.isCreator) || peer.adminRights != nil {
                    hasEditRights = true
                } else {
                    hasEditRights = false
                }
            }
            switch peer.info {
            case .broadcast:
                if peer.hasPermission(.editAllMessages) || !message.flags.contains(.Incoming) {
                    unlimitedInterval = true
                }
            case .group:
                if peer.hasPermission(.pinMessages) {
                    unlimitedInterval = true
                }
            }
        }
    } else if message.author?.id == message.id.peerId, let peer = message.peers[message.id.peerId] {
        if let peer = peer as? TelegramChannel {
            switch peer.info {
            case .broadcast:
                if peer.hasPermission(.editAllMessages) || !message.flags.contains(.Incoming) {
                    unlimitedInterval = true
                    hasEditRights = true
                }
            case .group:
                if peer.hasPermission(.pinMessages) {
                    unlimitedInterval = true
                    hasEditRights = true
                }
            }
        }
    }
    
    var hasUneditableAttributes = false
    
    if hasEditRights {
        for attribute in message.attributes {
            if let _ = attribute as? InlineBotMessageAttribute {
                hasUneditableAttributes = true
                break
            }
        }
        if message.forwardInfo != nil {
            hasUneditableAttributes = true
        }
        
        for media in message.media {
            if let file = media as? TelegramMediaFile {
                if file.isSticker || file.isAnimatedSticker || file.isInstantVideo {
                    hasUneditableAttributes = true
                    break
                }
            } else if let _ = media as? TelegramMediaContact {
                hasUneditableAttributes = true
                break
            } else if let _ = media as? TelegramMediaExpiredContent {
                hasUneditableAttributes = true
                break
            } else if let _ = media as? TelegramMediaMap {
                hasUneditableAttributes = true
                break
            } else if let _ = media as? TelegramMediaPoll {
                hasUneditableAttributes = true
                break
            }  else if let _ = media as? TelegramMediaDice {
                hasUneditableAttributes = true
                break
            }
        }
        
        if !hasUneditableAttributes || reschedule {
            if canPerformEditingActions(limits: limitsConfiguration, accountPeerId: accountPeerId, message: message, unlimitedInterval: unlimitedInterval) {
                return true
            }
        }
    }
    return false
}


private let starIconEmpty = UIImage(bundleImageName: "Chat/Context Menu/StarIconEmpty")?.precomposed()
private let starIconFilled = UIImage(bundleImageName: "Chat/Context Menu/StarIconFilled")?.precomposed()

func canReplyInChat(_ chatPresentationInterfaceState: ChatPresentationInterfaceState) -> Bool {
    guard let peer = chatPresentationInterfaceState.renderedPeer?.peer else {
        return false
    }
    
    if case .scheduledMessages = chatPresentationInterfaceState.subject {
        return false
    }
    if case .pinnedMessages = chatPresentationInterfaceState.subject {
        return false
    }

    guard !peer.id.isReplies else {
        return false
    }
    switch chatPresentationInterfaceState.mode {
    case .inline:
        return false
    default:
        break
    }
    
    var canReply = false
    switch chatPresentationInterfaceState.chatLocation {
        case .peer:
            if let channel = peer as? TelegramChannel {
                if case .member = channel.participationStatus {
                    canReply = channel.hasPermission(.sendMessages)
                }
            } else if let group = peer as? TelegramGroup {
                if case .Member = group.membership {
                    canReply = true
                }
            } else {
                canReply = true
            }
        case .replyThread:
            canReply = true
    }
    return canReply
}

enum ChatMessageContextMenuActionColor {
    case accent
    case destructive
}

struct ChatMessageContextMenuSheetAction {
    let color: ChatMessageContextMenuActionColor
    let title: String
    let action: () -> Void
}

enum ChatMessageContextMenuAction {
    case context(ContextMenuAction)
    case sheet(ChatMessageContextMenuSheetAction)
}

struct MessageMediaEditingOptions: OptionSet {
    var rawValue: Int32
    
    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    static let imageOrVideo = MessageMediaEditingOptions(rawValue: 1 << 0)
    static let file = MessageMediaEditingOptions(rawValue: 1 << 1)
}

func messageMediaEditingOptions(message: Message) -> MessageMediaEditingOptions {
    if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
        return []
    }
    for attribute in message.attributes {
        if attribute is AutoremoveTimeoutMessageAttribute {
            return []
        } else if attribute is AutoclearTimeoutMessageAttribute {
            return []
        }
    }
    
    var options: MessageMediaEditingOptions = []
    
    for media in message.media {
        if let _ = media as? TelegramMediaImage {
            options.formUnion([.imageOrVideo, .file])
        } else if let file = media as? TelegramMediaFile {
            for attribute in file.attributes {
                switch attribute {
                    case .Sticker:
                        return []
                    case .Animated:
                        return []
                    case let .Video(video):
                        if video.flags.contains(.instantRoundVideo) {
                            return []
                        } else {
                            options.formUnion([.imageOrVideo, .file])
                        }
                    case let .Audio(audio):
                        if audio.isVoice {
                            return []
                        } else {
                            if let _ = message.groupingKey {
                                return []
                            } else {
                                options.formUnion([.imageOrVideo, .file])
                            }
                        }
                    default:
                        break
                }
            }
            options.formUnion([.imageOrVideo, .file])
        }
    }
    
    if message.groupingKey != nil {
        options.remove(.file)
    }
    
    return options
}

func updatedChatEditInterfaceMessageState(state: ChatPresentationInterfaceState, message: Message) -> ChatPresentationInterfaceState {
    var updated = state
    for media in message.media {
        if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
            updated = updated.updatedEditingUrlPreview((content.url, webpage))
        }
    }
    var isPlaintext = true
    for media in message.media {
        if !(media is TelegramMediaWebpage) {
            isPlaintext = false
            break
        }
    }
    let content: ChatEditInterfaceMessageStateContent
    if isPlaintext {
        content = .plaintext
    } else {
        content = .media(mediaOptions: messageMediaEditingOptions(message: message))
    }
    updated = updated.updatedEditMessageState(ChatEditInterfaceMessageState(content: content, mediaReference: nil))
    return updated
}

func contextMenuForChatPresentationInterfaceState(chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, messages: [Message], controllerInteraction: ChatControllerInteraction?, selectAll: Bool, interfaceInteraction: ChatPanelInterfaceInteraction?) -> Signal<[ContextMenuItem], NoError> {
    guard let interfaceInteraction = interfaceInteraction, let controllerInteraction = controllerInteraction else {
        return .single([])
    }
    
    var loadStickerSaveStatus: MediaId?
    var loadCopyMediaResource: MediaResource?
    var isAction = false
    var diceEmoji: String?
    if messages.count == 1 {
        for media in messages[0].media {
            if let file = media as? TelegramMediaFile {
                for attribute in file.attributes {
                    if case let .Sticker(_, packInfo, _) = attribute, packInfo != nil {
                        loadStickerSaveStatus = file.fileId
                    }
                }
            } else if media is TelegramMediaAction || media is TelegramMediaExpiredContent {
                isAction = true
            } else if let image = media as? TelegramMediaImage {
                if !messages[0].containsSecretMedia {
                    loadCopyMediaResource = largestImageRepresentation(image.representations)?.resource
                }
            } else if let dice = media as? TelegramMediaDice {
                diceEmoji = dice.emoji
            }
        }
    }
    
    var canReply = canReplyInChat(chatPresentationInterfaceState)
    var canPin = false
    let canSelect = !isAction
    
    let message = messages[0]
    
    if Namespaces.Message.allScheduled.contains(message.id.namespace) || message.id.peerId.isReplies {
        canReply = false
        canPin = false
    } else if messages[0].flags.intersection([.Failed, .Unsent]).isEmpty {
        switch chatPresentationInterfaceState.chatLocation {
            case .peer, .replyThread:
                if let channel = messages[0].peers[messages[0].id.peerId] as? TelegramChannel {
                    if !isAction {
                        canPin = channel.hasPermission(.pinMessages)
                    }
                } else if let group = messages[0].peers[messages[0].id.peerId] as? TelegramGroup {
                    if !isAction {
                        switch group.role {
                            case .creator, .admin:
                                canPin = true
                            default:
                                if let defaultBannedRights = group.defaultBannedRights {
                                    canPin = !defaultBannedRights.flags.contains(.banPinMessages)
                                } else {
                                    canPin = true
                                }
                        }
                    }
                } else if let _ = messages[0].peers[messages[0].id.peerId] as? TelegramUser, chatPresentationInterfaceState.explicitelyCanPinMessages {
                    if !isAction {
                        canPin = true
                    }
                }
            /*case .group:
                break*/
        }
    } else {
        canReply = false
        canPin = false
    }
    
    if let peer = messages[0].peers[messages[0].id.peerId] {
        if peer.isDeleted {
            canPin = false
        }
        if !(peer is TelegramSecretChat) && messages[0].id.namespace != Namespaces.Message.Cloud {
            canPin = false
            canReply = false
        }
    }
    
    var loadStickerSaveStatusSignal: Signal<Bool?, NoError> = .single(nil)
    if loadStickerSaveStatus != nil {
        loadStickerSaveStatusSignal = context.account.postbox.transaction { transaction -> Bool? in
            var starStatus: Bool?
            if let loadStickerSaveStatus = loadStickerSaveStatus {
                if getIsStickerSaved(transaction: transaction, fileId: loadStickerSaveStatus) {
                    starStatus = true
                } else {
                    starStatus = false
                }
            }
            
            return starStatus
        }
    }
    
    var loadResourceStatusSignal: Signal<MediaResourceStatus?, NoError> = .single(nil)
    if let loadCopyMediaResource = loadCopyMediaResource {
        loadResourceStatusSignal = context.account.postbox.mediaBox.resourceStatus(loadCopyMediaResource)
        |> take(1)
        |> map(Optional.init)
    }
    
    let loadLimits = context.account.postbox.transaction { transaction -> LimitsConfiguration in
        return transaction.getPreferencesEntry(key: PreferencesKeys.limitsConfiguration) as? LimitsConfiguration ?? LimitsConfiguration.defaultValue
    }
    
    let cachedData = context.account.postbox.transaction { transaction -> CachedPeerData? in
        return transaction.getPeerCachedData(peerId: messages[0].id.peerId)
    }
    
    let dataSignal: Signal<(MessageContextMenuData, [MessageId: ChatUpdatingMessageMedia], CachedPeerData?), NoError> = combineLatest(
        loadLimits,
        loadStickerSaveStatusSignal,
        loadResourceStatusSignal,
        context.sharedContext.chatAvailableMessageActions(postbox: context.account.postbox, accountPeerId: context.account.peerId, messageIds: Set(messages.map { $0.id })),
        context.account.pendingUpdateMessageManager.updatingMessageMedia
        |> take(1),
        cachedData
    )
    |> map { limitsConfiguration, stickerSaveStatus, resourceStatus, messageActions, updatingMessageMedia, cachedData -> (MessageContextMenuData, [MessageId: ChatUpdatingMessageMedia], CachedPeerData?) in
        var canEdit = false
        if !isAction {
            let message = messages[0]
            canEdit = canEditMessage(context: context, limitsConfiguration: limitsConfiguration, message: message)
        }
        
        return (MessageContextMenuData(starStatus: stickerSaveStatus, canReply: canReply, canPin: canPin, canEdit: canEdit, canSelect: canSelect, resourceStatus: resourceStatus, messageActions: messageActions), updatingMessageMedia, cachedData)
    }
    
    return dataSignal
    |> deliverOnMainQueue
    |> map { data, updatingMessageMedia, cachedData -> [ContextMenuItem] in
        var actions: [ContextMenuItem] = []
        
        var isPinnedMessages = false
        if case .pinnedMessages = chatPresentationInterfaceState.subject {
            isPinnedMessages = true
        }
        
        if let starStatus = data.starStatus {
            actions.append(.action(ContextMenuActionItem(text: starStatus ? chatPresentationInterfaceState.strings.Stickers_RemoveFromFavorites : chatPresentationInterfaceState.strings.Stickers_AddToFavorites, icon: { theme in
                return generateTintedImage(image: starStatus ? UIImage(bundleImageName: "Chat/Context Menu/Unstar") : UIImage(bundleImageName: "Chat/Context Menu/Rate"), color: theme.actionSheet.primaryTextColor)
            }, action: { _, f in
                interfaceInteraction.toggleMessageStickerStarred(messages[0].id)
                f(.default)
            })))
        }
        
        if data.messageActions.options.contains(.rateCall) {
            var callId: CallId?
            var isVideo: Bool = false
            for media in message.media {
                if let action = media as? TelegramMediaAction, case let .phoneCall(id, discardReason, _, isVideoValue) = action.action {
                    isVideo = isVideoValue
                    if discardReason != .busy && discardReason != .missed {
                        if let logName = callLogNameForId(id: id, account: context.account) {
                            let logsPath = callLogsPath(account: context.account)
                            let logPath = logsPath + "/" + logName
                            let start = logName.index(logName.startIndex, offsetBy: "\(id)".count + 1)
                            let end: String.Index
                            if logName.hasSuffix(".log.json") {
                                end = logName.index(logName.endIndex, offsetBy: -4 - 5)
                            } else {
                                end = logName.index(logName.endIndex, offsetBy: -4)
                            }
                            let accessHash = logName[start..<end]
                            if let accessHash = Int64(accessHash) {
                                callId = CallId(id: id, accessHash: accessHash)
                            }
                            
                            actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Call_ShareStats, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.actionSheet.primaryTextColor)
                            }, action: { _, f in
                                f(.dismissWithoutContent)
                                
                                let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                                controller.peerSelected = { [weak controller] peer in
                                    let peerId = peer.id
                                    
                                    if let strongController = controller {
                                        strongController.dismiss()
                                        
                                        let id = arc4random64()
                                        let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: LocalFileReferenceMediaResource(localFilePath: logPath, randomId: id), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: nil, attributes: [.FileName(fileName: "CallStats.log")])
                                        let message: EnqueueMessage = .message(text: "", attributes: [], mediaReference: .standalone(media: file), replyToMessageId: nil, localGroupingKey: nil)
                                        
                                        let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
                                    }
                                }
                                controllerInteraction.navigationController()?.pushViewController(controller)
                            })))
                        }
                    }
                    break
                }
            }
            if let callId = callId {
                actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Call_RateCall, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Rate"), color: theme.actionSheet.primaryTextColor)
                }, action: { _, f in
                    let _ = controllerInteraction.rateCall(message, callId, isVideo)
                    f(.dismissWithoutContent)
                })))
            }
        }
        
        var isReplyThreadHead = false
        if case let .replyThread(replyThreadMessage) = chatPresentationInterfaceState.chatLocation {
            isReplyThreadHead = messages[0].id == replyThreadMessage.effectiveTopId
        }
        
        if !isPinnedMessages, !isReplyThreadHead, data.canReply {
            actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_ContextMenuReply, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Reply"), color: theme.actionSheet.primaryTextColor)
            }, action: { _, f in
                interfaceInteraction.setupReplyMessage(messages[0].id, { transition in
                    f(.custom(transition))
                })
            })))
        }
        
        if data.messageActions.options.contains(.sendScheduledNow) {
            actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.ScheduledMessages_SendNow, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Resend"), color: theme.actionSheet.primaryTextColor)
            }, action: { _, f in
                controllerInteraction.sendScheduledMessagesNow(selectAll ? messages.map { $0.id } : [message.id])
                f(.dismissWithoutContent)
            })))
        }
        
        if data.messageActions.options.contains(.editScheduledTime) {
            actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.ScheduledMessages_EditTime, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Schedule"), color: theme.actionSheet.primaryTextColor)
            }, action: { _, f in
                controllerInteraction.editScheduledMessagesTime(selectAll ? messages.map { $0.id } : [message.id])
                f(.dismissWithoutContent)
            })))
        }
        
        let resourceAvailable: Bool
        if let resourceStatus = data.resourceStatus, case .Local = resourceStatus {
            resourceAvailable = true
        } else {
            resourceAvailable = false
        }
        
        if !messages[0].text.isEmpty || resourceAvailable || diceEmoji != nil {
            let message = messages[0]
            var isExpired = false
            for media in message.media {
                if let _ = media as? TelegramMediaExpiredContent {
                    isExpired = true
                }
            }
            if !isExpired {
                actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_ContextMenuCopy, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.actionSheet.primaryTextColor)
                }, action: { _, f in
                    if let diceEmoji = diceEmoji {
                        UIPasteboard.general.string = diceEmoji
                    } else {
                        let copyTextWithEntities = {
                            var messageEntities: [MessageTextEntity]?
                            for attribute in message.attributes {
                                if let attribute = attribute as? TextEntitiesMessageAttribute {
                                    messageEntities = attribute.entities
                                    break
                                }
                            }
                            storeMessageTextInPasteboard(message.text, entities: messageEntities)
                            
                            let content: UndoOverlayContent = .copy(text: chatPresentationInterfaceState.strings.Conversation_MessageCopied)
                            controllerInteraction.displayUndo(content)
                        }
                        if resourceAvailable {
                            for media in message.media {
                                if let image = media as? TelegramMediaImage, let largest = largestImageRepresentation(image.representations) {
                                    let _ = (context.account.postbox.mediaBox.resourceData(largest.resource, option: .incremental(waitUntilFetchStatus: false))
                                        |> take(1)
                                        |> deliverOnMainQueue).start(next: { data in
                                            if data.complete, let imageData = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                                                if let image = UIImage(data: imageData) {
                                                    if !message.text.isEmpty {
                                                        copyTextWithEntities()
                                                    } else {
                                                        UIPasteboard.general.image = image
                                                        let content: UndoOverlayContent = .copy(text: chatPresentationInterfaceState.strings.Conversation_ImageCopied)
                                                        controllerInteraction.displayUndo(content)
                                                    }
                                                } else {
                                                    copyTextWithEntities()
                                                }
                                            } else {
                                                copyTextWithEntities()
                                            }
                                        })
                                }
                            }
                        } else {
                            copyTextWithEntities()
                        }
                    }
                    f(.default)
                })))
                
                if isSpeakSelectionEnabled() && !message.text.isEmpty {
                    actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_ContextMenuSpeak, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Message"), color: theme.actionSheet.primaryTextColor)
                    }, action: { _, f in
                        controllerInteraction.performTextSelectionAction(0, NSAttributedString(string: message.text), .speak)
                        f(.default)
                    })))
                }
            }
            if resourceAvailable, !message.containsSecretMedia {
                var mediaReference: AnyMediaReference?
                for media in message.media {
                    if let image = media as? TelegramMediaImage, let _ = largestImageRepresentation(image.representations) {
                        mediaReference = ImageMediaReference.standalone(media: image).abstract
                        break
                    } else if let file = media as? TelegramMediaFile, file.isVideo {
                        mediaReference = FileMediaReference.standalone(media: file).abstract
                        break
                    }
                }
                if let mediaReference = mediaReference {
                    actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Preview_SaveToCameraRoll, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Save"), color: theme.actionSheet.primaryTextColor)
                    }, action: { _, f in
                        let _ = (saveToCameraRoll(context: context, postbox: context.account.postbox, mediaReference: mediaReference)
                        |> deliverOnMainQueue).start(completed: {
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            controllerInteraction.presentGlobalOverlayController(OverlayStatusController(theme: presentationData.theme, type: .success), nil)
                        })
                        f(.default)
                    })))
                }
            }
        }
        
        var threadId: Int64?
        var threadMessageCount: Int = 0
        if case .peer = chatPresentationInterfaceState.chatLocation, let channel = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramChannel, case .group = channel.info {
            if let cachedData = cachedData as? CachedChannelData, case let .known(maybeValue) = cachedData.linkedDiscussionPeerId, let _ = maybeValue {
                if let value = messages[0].threadId {
                    threadId = value
                } else {
                    for attribute in messages[0].attributes {
                        if let attribute = attribute as? ReplyThreadMessageAttribute, attribute.count > 0 {
                            threadId = makeMessageThreadId(messages[0].id)
                            threadMessageCount = Int(attribute.count)
                        }
                    }
                }
            } else {
                for attribute in messages[0].attributes {
                    if let attribute = attribute as? ReplyThreadMessageAttribute, attribute.count > 0 {
                        threadId = makeMessageThreadId(messages[0].id)
                        threadMessageCount = Int(attribute.count)
                    }
                }
            }
        }
        
        if let _ = threadId, !isPinnedMessages {
            let text: String
            if threadMessageCount != 0 {
                text = chatPresentationInterfaceState.strings.Conversation_ContextViewReplies(Int32(threadMessageCount))
            } else {
                text = chatPresentationInterfaceState.strings.Conversation_ContextViewThread
            }
            actions.append(.action(ContextMenuActionItem(text: text, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Replies"), color: theme.actionSheet.primaryTextColor)
            }, action: { c, _ in
                c.dismiss(completion: {
                    controllerInteraction.openMessageReplies(messages[0].id, true, true)
                })
            })))
        }
        
        let isMigrated: Bool
        if chatPresentationInterfaceState.renderedPeer?.peer is TelegramChannel && message.id.peerId.namespace == Namespaces.Peer.CloudGroup {
            isMigrated = true
        } else {
            isMigrated = false
        }
                
        if data.canEdit && !isPinnedMessages && !isMigrated {
            actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_MessageDialogEdit, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.actionSheet.primaryTextColor)
            }, action: { c, f in
                interfaceInteraction.setupEditMessage(messages[0].id, { transition in
                    f(.custom(transition))
                })
            })))
        }
        
        var activePoll: TelegramMediaPoll?
        for media in message.media {
            if let poll = media as? TelegramMediaPoll, !poll.isClosed, message.id.namespace == Namespaces.Message.Cloud, poll.pollId.namespace == Namespaces.Media.CloudPoll {
                if !isPollEffectivelyClosed(message: message, poll: poll) {
                    activePoll = poll
                }
            }
        }
        
        if let activePoll = activePoll, let voters = activePoll.results.voters {
            var hasSelected = false
            for result in voters {
                if result.selected {
                    hasSelected = true
                }
            }
            if hasSelected, case .poll = activePoll.kind {
                actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_UnvotePoll, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Unvote"), color: theme.actionSheet.primaryTextColor)
                }, action: { _, f in
                    interfaceInteraction.requestUnvoteInMessage(messages[0].id)
                    f(.dismissWithoutContent)
                })))
            }
        }
        
        if data.canPin && !isMigrated, case .peer = chatPresentationInterfaceState.chatLocation {
            var pinnedSelectedMessageId: MessageId?
            for message in messages {
                if message.tags.contains(.pinned) {
                    pinnedSelectedMessageId = message.id
                    break
                }
            }
            
            if let pinnedSelectedMessageId = pinnedSelectedMessageId {
                actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_Unpin, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Unpin"), color: theme.actionSheet.primaryTextColor)
                }, action: { c, _ in
                    interfaceInteraction.unpinMessage(pinnedSelectedMessageId, false, c)
                })))
            } else {
                actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_Pin, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Pin"), color: theme.actionSheet.primaryTextColor)
                }, action: { c, _ in
                    interfaceInteraction.pinMessage(messages[0].id, c)
                })))
            }
        }
        
        if let activePoll = activePoll, messages[0].forwardInfo == nil {
            var canStopPoll = false
            if !messages[0].flags.contains(.Incoming) {
                canStopPoll = true
            } else {
                var hasEditRights = false
                if messages[0].id.namespace == Namespaces.Message.Cloud {
                    if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
                        hasEditRights = false
                    } else if let author = message.author, author.id == context.account.peerId {
                        hasEditRights = true
                    } else if message.author?.id == message.id.peerId, let peer = message.peers[message.id.peerId] {
                        if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                            if peer.hasPermission(.editAllMessages) {
                                hasEditRights = true
                            }
                        }
                    }
                }
                
                if hasEditRights {
                    canStopPoll = true
                }
            }
            
            if canStopPoll {
                let stopPollAction: String
                switch activePoll.kind {
                case .poll:
                    stopPollAction = chatPresentationInterfaceState.strings.Conversation_StopPoll
                case .quiz:
                    stopPollAction = chatPresentationInterfaceState.strings.Conversation_StopQuiz
                }
                actions.append(.action(ContextMenuActionItem(text: stopPollAction, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/StopPoll"), color: theme.actionSheet.primaryTextColor)
                }, action: { _, f in
                    interfaceInteraction.requestStopPollInMessage(messages[0].id)
                    f(.dismissWithoutContent)
                })))
            }
        }
        
        if let message = messages.first, message.id.namespace == Namespaces.Message.Cloud, let channel = message.peers[message.id.peerId] as? TelegramChannel, !(message.media.first is TelegramMediaAction), !isReplyThreadHead, !isMigrated {
            actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_ContextMenuCopyLink, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.actionSheet.primaryTextColor)
            }, action: { _, f in
                var threadMessageId: MessageId?
                if case let .replyThread(replyThreadMessage) = chatPresentationInterfaceState.chatLocation {
                    threadMessageId = replyThreadMessage.messageId
                }
                let _ = (exportMessageLink(account: context.account, peerId: message.id.peerId, messageId: message.id, isThread: threadMessageId != nil)
                |> map { result -> String? in
                    return result
                }
                |> deliverOnMainQueue).start(next: { link in
                    if let link = link {
                        UIPasteboard.general.string = link
                        
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        
                        var warnAboutPrivate = false
                        if case .peer = chatPresentationInterfaceState.chatLocation {
                            if channel.addressName == nil {
                                warnAboutPrivate = true
                            }
                        }
                        
                        if warnAboutPrivate {
                            controllerInteraction.presentGlobalOverlayController(OverlayStatusController(theme: presentationData.theme, type: .genericSuccess(presentationData.strings.Conversation_PrivateMessageLinkCopied, true)), nil)
                        } else {
                            controllerInteraction.presentGlobalOverlayController(OverlayStatusController(theme: presentationData.theme, type: .genericSuccess(presentationData.strings.GroupInfo_InviteLink_CopyAlert_Success, false)), nil)
                        }
                    }
                })
                f(.default)
            })))
        }
        
        var isUnremovableAction = false
        if messages.count == 1 {
            let message = messages[0]
            
            var hasAutoremove = false
            for attribute in message.attributes {
                if let _ = attribute as? AutoremoveTimeoutMessageAttribute {
                    hasAutoremove = true
                    break
                } else if let _ = attribute as? AutoclearTimeoutMessageAttribute {
                    hasAutoremove = true
                    break
                }
            }
            
            if !hasAutoremove {
                for media in message.media {
                    if media is TelegramMediaAction {
                        if let channel = message.peers[message.id.peerId] as? TelegramChannel {
                            if channel.flags.contains(.isCreator) || (channel.adminRights?.rights.contains(.canDeleteMessages) == true) {
                            } else {
                                isUnremovableAction = true
                            }
                        }
                    }
                    if let file = media as? TelegramMediaFile {
                        if file.isVideo {
                            if file.isAnimated {
                                actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_LinkDialogSave, icon: { theme in
                                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Save"), color: theme.actionSheet.primaryTextColor)
                                }, action: { _, f in
                                    let _ = addSavedGif(postbox: context.account.postbox, fileReference: .message(message: MessageReference(message), media: file)).start()
                                    f(.default)
                                })))
                            }
                            break
                        }
                    }
                }
            }
        }
        /*if !isReplyThreadHead, !data.messageActions.options.intersection([.deleteLocally, .deleteGlobally]).isEmpty && isAction {
            actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_ContextMenuDelete, textColor: .destructive, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.actionSheet.destructiveActionTextColor)
            }, action: { controller, f in
                interfaceInteraction.deleteMessages(messages, controller, f)
            })))
        }*/
        
        if data.messageActions.options.contains(.viewStickerPack) {
            actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.StickerPack_ViewPack, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Sticker"), color: theme.actionSheet.primaryTextColor)
            }, action: { _, f in
                let _ = controllerInteraction.openMessage(message, .default)
                f(.dismissWithoutContent)
            })))
        }
                
        if data.messageActions.options.contains(.forward) {
            actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_ContextMenuForward, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.actionSheet.primaryTextColor)
            }, action: { _, f in
                interfaceInteraction.forwardMessages(selectAll ? messages : [message])
                f(.dismissWithoutContent)
            })))
        }
        
        if data.messageActions.options.contains(.report) {
            actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_ContextMenuReport, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Report"), color: theme.actionSheet.primaryTextColor)
            }, action: { controller, f in
                interfaceInteraction.reportMessages(messages, controller)
            })))
        } else if message.id.peerId.isReplies {
            actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_ContextMenuBlock, textColor: .destructive, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Restrict"), color: theme.actionSheet.destructiveActionTextColor)
            }, action: { controller, f in
                interfaceInteraction.blockMessageAuthor(message, controller)
            })))
        }
        
        var clearCacheAsDelete = false
        if let channel = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = channel.info, !isMigrated {
            var views: Int = 0
            for attribute in message.attributes {
                if let attribute = attribute as? ViewCountMessageAttribute {
                    views = attribute.count
                }
            }
            
            if let cachedData = cachedData as? CachedChannelData, cachedData.flags.contains(.canViewStats), views >= 100 {
                actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_ContextViewStats, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Statistics"), color: theme.actionSheet.primaryTextColor)
                }, action: { c, _ in
                    c.dismiss(completion: {
                        controllerInteraction.openMessageStats(messages[0].id)
                    })
                })))
            }
            
            clearCacheAsDelete = true
        }
        
        if !isReplyThreadHead, (!data.messageActions.options.intersection([.deleteLocally, .deleteGlobally]).isEmpty || clearCacheAsDelete) {
            var autoremoveDeadline: Int32?
            for attribute in message.attributes {
                if let attribute = attribute as? AutoremoveTimeoutMessageAttribute {
                    if let countdownBeginTime = attribute.countdownBeginTime {
                        autoremoveDeadline = countdownBeginTime + attribute.timeout
                    }
                    break
                }
            }

            let title: String
            var isSending = false
            var isEditing = false
            if updatingMessageMedia[message.id] != nil {
                isSending = true
                isEditing = true
                title = chatPresentationInterfaceState.strings.Conversation_ContextMenuCancelEditing
            } else if message.flags.isSending {
                isSending = true
                title = chatPresentationInterfaceState.strings.Conversation_ContextMenuCancelSending
            } else {
                title = chatPresentationInterfaceState.strings.Conversation_ContextMenuDelete
            }
            if let autoremoveDeadline = autoremoveDeadline, !isEditing, !isSending {
                actions.append(.custom(ChatDeleteMessageContextItem(timestamp: Double(autoremoveDeadline), action: { controller, f in
                    if isEditing {
                        context.account.pendingUpdateMessageManager.cancel(messageId: message.id)
                        f(.default)
                    } else {
                        interfaceInteraction.deleteMessages(selectAll ? messages : [message], controller, f)
                    }
                }), false))
            } else if !isUnremovableAction {
                actions.append(.action(ContextMenuActionItem(text: title, textColor: .destructive, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: isSending ? "Chat/Context Menu/Clear" : "Chat/Context Menu/Delete"), color: theme.actionSheet.destructiveActionTextColor)
                }, action: { controller, f in
                    if isEditing {
                        context.account.pendingUpdateMessageManager.cancel(messageId: message.id)
                        f(.default)
                    } else {
                        interfaceInteraction.deleteMessages(selectAll ? messages : [message], controller, f)
                    }
                })))
            }
        }
        
        if !isPinnedMessages, !isReplyThreadHead, data.canSelect {
            if !actions.isEmpty {
                actions.append(.separator)
            }
            if !selectAll || messages.count == 1 {
                actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_ContextMenuSelect, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.actionSheet.primaryTextColor)
                }, action: { _, f in
                    interfaceInteraction.beginMessageSelection(selectAll ? messages.map { $0.id } : [message.id], { transition in
                        f(.custom(transition))
                    })
                })))
            }
            
            if messages.count > 1 {
                actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_ContextMenuSelectAll(Int32(messages.count)), icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/SelectAll"), color: theme.actionSheet.primaryTextColor)
                }, action: { _, f in
                    interfaceInteraction.beginMessageSelection(messages.map { $0.id }, { transition in
                        f(.custom(transition))
                    })
                })))
            }
        }
        
        return actions
    }
}

func canPerformEditingActions(limits: LimitsConfiguration, accountPeerId: PeerId, message: Message, unlimitedInterval: Bool) -> Bool {
    if message.id.peerId == accountPeerId {
        return true
    }
    
    if unlimitedInterval {
        return true
    }
    
    let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
    if Int64(message.timestamp) + Int64(limits.maxMessageEditingInterval) > Int64(timestamp) {
        return true
    }
    
    return false
}

private func canPerformDeleteActions(limits: LimitsConfiguration, accountPeerId: PeerId, message: Message) -> Bool {
    if message.id.peerId == accountPeerId {
        return true
    }
    if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
        return true
    }
    
    if !message.flags.contains(.Incoming) {
        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        if message.id.peerId.namespace == Namespaces.Peer.CloudUser {
            if Int64(message.timestamp) + Int64(limits.maxMessageRevokeIntervalInPrivateChats) > Int64(timestamp) {
                return true
            }
        } else {
            if message.timestamp + limits.maxMessageRevokeInterval > timestamp {
                return true
            }
        }
    }
    
    return false
}

func chatAvailableMessageActionsImpl(postbox: Postbox, accountPeerId: PeerId, messageIds: Set<MessageId>, messages: [MessageId: Message] = [:], peers: [PeerId: Peer] = [:]) -> Signal<ChatAvailableMessageActions, NoError> {
    return postbox.transaction { transaction -> ChatAvailableMessageActions in
        let limitsConfiguration: LimitsConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.limitsConfiguration) as? LimitsConfiguration ?? LimitsConfiguration.defaultValue
        var optionsMap: [MessageId: ChatAvailableMessageActionOptions] = [:]
        var banPeer: Peer?
        var hadPersonalIncoming = false
        var hadBanPeerId = false
        
        func getPeer(_ peerId: PeerId) -> Peer? {
            if let peer = transaction.getPeer(peerId) {
                return peer
            } else if let peer = peers[peerId] {
                return peer
            } else {
                return nil
            }
        }
        
        func getMessage(_ messageId: MessageId) -> Message? {
            if let message = transaction.getMessage(messageId) {
                return message
            } else if let message = messages[messageId] {
                return message
            } else {
                return nil
            }
        }
        
        for id in messageIds {
            let isScheduled = id.namespace == Namespaces.Message.ScheduledCloud
            if optionsMap[id] == nil {
                optionsMap[id] = []
            }
            if let message = getMessage(id) {
                for media in message.media {
                    if let file = media as? TelegramMediaFile, file.isSticker {
                        for case let .Sticker(sticker) in file.attributes {
                            if let _ = sticker.packReference {
                                optionsMap[id]!.insert(.viewStickerPack)
                            }
                            break
                        }
                    } else if let action = media as? TelegramMediaAction, case .phoneCall = action.action {
                        optionsMap[id]!.insert(.rateCall)
                    }
                }
                if id.namespace == Namespaces.Message.ScheduledCloud {
                    optionsMap[id]!.insert(.sendScheduledNow)
                    if canEditMessage(accountPeerId: accountPeerId, limitsConfiguration: limitsConfiguration, message: message, reschedule: true) {
                        optionsMap[id]!.insert(.editScheduledTime)
                    }
                    if let peer = getPeer(id.peerId), let channel = peer as? TelegramChannel {
                        if !message.flags.contains(.Incoming) {
                            optionsMap[id]!.insert(.deleteLocally)
                        } else {
                            if channel.hasPermission(.deleteAllMessages) {
                                optionsMap[id]!.insert(.deleteLocally)
                            }
                        }
                    } else {
                        optionsMap[id]!.insert(.deleteLocally)
                    }
                } else if id.peerId == accountPeerId {
                    if !(message.flags.isSending || message.flags.contains(.Failed)) {
                        optionsMap[id]!.insert(.forward)
                    }
                    optionsMap[id]!.insert(.deleteLocally)
                } else if let peer = getPeer(id.peerId) {
                    var isAction = false
                    var isDice = false
                    for media in message.media {
                        if media is TelegramMediaAction || media is TelegramMediaExpiredContent {
                            isAction = true
                        }
                        if media is TelegramMediaDice {
                            isDice = true
                        }
                    }
                    if let channel = peer as? TelegramChannel {
                        if message.flags.contains(.Incoming) {
                            optionsMap[id]!.insert(.report)
                        }
                        if channel.hasPermission(.banMembers), case .group = channel.info {
                            if message.flags.contains(.Incoming) {
                                if message.author is TelegramUser {
                                    if !hadBanPeerId {
                                        hadBanPeerId = true
                                        banPeer = message.author
                                    } else if banPeer?.id != message.author?.id {
                                        banPeer = nil
                                    }
                                } else {
                                    hadBanPeerId = true
                                    banPeer = nil
                                }
                            } else {
                                hadBanPeerId = true
                                banPeer = nil
                            }
                        }
                        if !message.containsSecretMedia && !isAction {
                            if message.id.peerId.namespace != Namespaces.Peer.SecretChat {
                                if !(message.flags.isSending || message.flags.contains(.Failed)) {
                                    optionsMap[id]!.insert(.forward)
                                }
                            }
                        }

                        if !message.flags.contains(.Incoming) {
                            optionsMap[id]!.insert(.deleteGlobally)
                        } else {
                            if channel.hasPermission(.deleteAllMessages) {
                                optionsMap[id]!.insert(.deleteGlobally)
                            }
                        }
                    } else if let group = peer as? TelegramGroup {
                        if message.id.peerId.namespace != Namespaces.Peer.SecretChat && !message.containsSecretMedia {
                            if !isAction {
                                if !(message.flags.isSending || message.flags.contains(.Failed)) {
                                    optionsMap[id]!.insert(.forward)
                                }
                            }
                        }
                        optionsMap[id]!.insert(.deleteLocally)
                        if !message.flags.contains(.Incoming) {
                            optionsMap[id]!.insert(.deleteGlobally)
                        } else {
                            switch group.role {
                                case .creator, .admin:
                                    optionsMap[id]!.insert(.deleteGlobally)
                                case .member:
                                    var hasMediaToReport = false
                                    for media in message.media {
                                        if let _ = media as? TelegramMediaImage {
                                            hasMediaToReport = true
                                        } else if let _ = media as? TelegramMediaFile {
                                            hasMediaToReport = true
                                        } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                                            if let _ = content.image {
                                                hasMediaToReport = true
                                            } else if let _ = content.file {
                                                hasMediaToReport = true
                                            }
                                        }
                                    }
                                    if hasMediaToReport {
                                        optionsMap[id]!.insert(.report)
                                    }
                            }
                        }
                    } else if let user = peer as? TelegramUser {
                        if !isScheduled && message.id.peerId.namespace != Namespaces.Peer.SecretChat && !message.containsSecretMedia && !isAction && !message.id.peerId.isReplies {
                            if !(message.flags.isSending || message.flags.contains(.Failed)) {
                                optionsMap[id]!.insert(.forward)
                            }
                        }
                        optionsMap[id]!.insert(.deleteLocally)
                        var canDeleteGlobally = false
                        if canPerformDeleteActions(limits: limitsConfiguration, accountPeerId: accountPeerId, message: message) {
                            canDeleteGlobally = true
                        } else if limitsConfiguration.canRemoveIncomingMessagesInPrivateChats {
                            canDeleteGlobally = true
                        }
                        if user.botInfo != nil {
                            canDeleteGlobally = false
                        }
                        
                        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                        if isDice && Int64(message.timestamp) + 60 * 60 * 24 > Int64(timestamp) {
                            canDeleteGlobally = false
                        }
                        if message.flags.contains(.Incoming) {
                            hadPersonalIncoming = true
                        }
                        if canDeleteGlobally {
                            optionsMap[id]!.insert(.deleteGlobally)
                        }
                        if user.botInfo != nil && !user.id.isReplies && !isAction {
                            optionsMap[id]!.insert(.report)
                        }
                    } else if let _ = peer as? TelegramSecretChat {
                        var isNonRemovableServiceAction = false
                        for media in message.media {
                            if let action = media as? TelegramMediaAction {
                                switch action.action {
                                    case .historyScreenshot:
                                        isNonRemovableServiceAction = true
                                    default:
                                        break
                                }
                            }
                        }
                       
                        if !isNonRemovableServiceAction {
                            optionsMap[id]!.insert(.deleteGlobally)
                        }
                    } else {
                        assertionFailure()
                    }
                } else {
                    optionsMap[id]!.insert(.deleteLocally)
                }
            }
        }
        
        if !optionsMap.isEmpty {
            var reducedOptions = optionsMap.values.first!
            for value in optionsMap.values {
                reducedOptions.formIntersection(value)
            }
            if hadPersonalIncoming && optionsMap.values.contains(where: { $0.contains(.deleteGlobally) }) && !reducedOptions.contains(.deleteGlobally) {
                reducedOptions.insert(.unsendPersonal)
            }
            return ChatAvailableMessageActions(options: reducedOptions, banAuthor: banPeer)
        } else {
            return ChatAvailableMessageActions(options: [], banAuthor: nil)
        }
    }
}

final class ChatDeleteMessageContextItem: ContextMenuCustomItem {
    fileprivate let timestamp: Double
    fileprivate let action: (ContextController, @escaping (ContextMenuActionResult) -> Void) -> Void
    
    init(timestamp: Double, action: @escaping (ContextController, @escaping (ContextMenuActionResult) -> Void) -> Void) {
        self.timestamp = timestamp
        self.action = action
    }
    
    func node(presentationData: PresentationData, getController: @escaping () -> ContextController?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return ChatDeleteMessageContextItemNode(presentationData: presentationData, item: self, getController: getController, actionSelected: actionSelected)
    }
}

private let textFont = Font.regular(17.0)

private final class ChatDeleteMessageContextItemNode: ASDisplayNode, ContextMenuCustomNode, ContextActionNodeProtocol {
    private let item: ChatDeleteMessageContextItem
    private let presentationData: PresentationData
    private let getController: () -> ContextController?
    private let actionSelected: (ContextMenuActionResult) -> Void
    
    private let backgroundNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let textNode: ImmediateTextNode
    private let statusNode: ImmediateTextNode
    private let iconNode: ASImageNode
    private let textIconNode: ASImageNode
    private let buttonNode: HighlightTrackingButtonNode
    
    private var timer: SwiftSignalKit.Timer?
    
    private var pointerInteraction: PointerInteraction?

    init(presentationData: PresentationData, item: ChatDeleteMessageContextItem, getController: @escaping () -> ContextController?, actionSelected: @escaping (ContextMenuActionResult) -> Void) {
        self.item = item
        self.presentationData = presentationData
        self.getController = getController
        self.actionSelected = actionSelected
        
        let textFont = Font.regular(presentationData.listsFontSize.baseDisplaySize)
        let subtextFont = Font.regular(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0)
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isAccessibilityElement = false
        self.backgroundNode.backgroundColor = presentationData.theme.contextMenu.itemBackgroundColor
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isAccessibilityElement = false
        self.highlightedBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.textNode = ImmediateTextNode()
        self.textNode.isAccessibilityElement = false
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        self.textNode.attributedText = NSAttributedString(string: presentationData.strings.Conversation_ContextMenuDelete, font: textFont, textColor: presentationData.theme.contextMenu.destructiveColor)
        
        self.textNode.maximumNumberOfLines = 1
        let statusNode = ImmediateTextNode()
        statusNode.isAccessibilityElement = false
        statusNode.isUserInteractionEnabled = false
        statusNode.displaysAsynchronously = false
        statusNode.attributedText = NSAttributedString(string: stringForRemainingTime(Int32(max(0.0, self.item.timestamp - Date().timeIntervalSince1970)), strings: presentationData.strings), font: subtextFont, textColor: presentationData.theme.contextMenu.destructiveColor)
        statusNode.maximumNumberOfLines = 1
        self.statusNode = statusNode
        
        self.buttonNode = HighlightTrackingButtonNode()
        self.buttonNode.isAccessibilityElement = true
        self.buttonNode.accessibilityLabel = presentationData.strings.VoiceChat_StopRecording
        
        self.iconNode = ASImageNode()
        self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: presentationData.theme.actionSheet.destructiveActionTextColor)
        
        self.textIconNode = ASImageNode()
        self.textIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/SelfExpiring"), color: presentationData.theme.actionSheet.destructiveActionTextColor)
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.statusNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.textIconNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.highligthedChanged = { [weak self] highligted in
            guard let strongSelf = self else {
                return
            }
            if highligted {
                strongSelf.highlightedBackgroundNode.alpha = 1.0
            } else {
                strongSelf.highlightedBackgroundNode.alpha = 0.0
                strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
            }
        }
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.timer?.invalidate()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.pointerInteraction = PointerInteraction(node: self.buttonNode, style: .hover, willEnter: { [weak self] in
            if let strongSelf = self {
                strongSelf.highlightedBackgroundNode.alpha = 0.75
            }
        }, willExit: { [weak self] in
            if let strongSelf = self {
                strongSelf.highlightedBackgroundNode.alpha = 0.0
            }
        })
        
        let timer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
            self?.updateTime(transition: .immediate)
        }, queue: Queue.mainQueue())
        self.timer = timer
        timer.start()
    }
    
    private var validLayout: CGSize?
    func updateTime(transition: ContainedViewLayoutTransition) {
        guard let size = self.validLayout else {
            return
        }
        
        let subtextFont = Font.regular(self.presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0)
        self.statusNode.attributedText = NSAttributedString(string: stringForRemainingTime(Int32(max(0.0, self.item.timestamp - Date().timeIntervalSince1970)), strings: presentationData.strings), font: subtextFont, textColor: presentationData.theme.contextMenu.destructiveColor)
        
        let sideInset: CGFloat = 16.0
        let statusSize = self.statusNode.updateLayout(CGSize(width: size.width - sideInset - 32.0, height: .greatestFiniteMagnitude))
        transition.updateFrameAdditive(node: self.statusNode, frame: CGRect(origin: CGPoint(x: self.statusNode.frame.minX, y: self.statusNode.frame.minY), size: statusSize))
    }
    
    func updateLayout(constrainedWidth: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let sideInset: CGFloat = 16.0
        let iconSideInset: CGFloat = 12.0
        let verticalInset: CGFloat = 12.0
        
        let iconSize: CGSize = self.iconNode.image?.size ?? CGSize(width: 10.0, height: 10.0)
        let textIconSize: CGSize = self.textIconNode.image?.size ?? CGSize(width: 2.0, height: 2.0)
        
        let standardIconWidth: CGFloat = 32.0
        var rightTextInset: CGFloat = sideInset
        if !iconSize.width.isZero {
            rightTextInset = max(iconSize.width, standardIconWidth) + iconSideInset + sideInset
        }
        
        let textSize = self.textNode.updateLayout(CGSize(width: constrainedWidth - sideInset - rightTextInset, height: .greatestFiniteMagnitude))
        let statusSize = self.statusNode.updateLayout(CGSize(width: constrainedWidth - sideInset - rightTextInset - textIconSize.width - 2.0, height: .greatestFiniteMagnitude))
        
        let verticalSpacing: CGFloat = 2.0
        let combinedTextHeight = textSize.height + verticalSpacing + statusSize.height
        return (CGSize(width: max(textSize.width, statusSize.width) + sideInset + rightTextInset, height: verticalInset * 2.0 + combinedTextHeight), { size, transition in
            self.validLayout = size
            let verticalOrigin = floor((size.height - combinedTextHeight) / 2.0)
            let textFrame = CGRect(origin: CGPoint(x: sideInset, y: verticalOrigin), size: textSize)
            transition.updateFrameAdditive(node: self.textNode, frame: textFrame)
            
            transition.updateFrame(node: self.textIconNode, frame: CGRect(origin: CGPoint(x: sideInset, y: verticalOrigin + verticalSpacing + textSize.height + floorToScreenPixels((statusSize.height - textIconSize.height) / 2.0) + 1.0), size: textIconSize))
            transition.updateFrameAdditive(node: self.statusNode, frame: CGRect(origin: CGPoint(x: sideInset + textIconSize.width + 2.0, y: verticalOrigin + verticalSpacing + textSize.height), size: statusSize))
            
            if !iconSize.width.isZero {
                transition.updateFrameAdditive(node: self.iconNode, frame: CGRect(origin: CGPoint(x: size.width - standardIconWidth - iconSideInset + floor((standardIconWidth - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize))
            }
            
            transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
            transition.updateFrame(node: self.highlightedBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
            transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
        })
    }
    
    func updateTheme(presentationData: PresentationData) {
        self.backgroundNode.backgroundColor = presentationData.theme.contextMenu.itemBackgroundColor
        self.highlightedBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor
        
        let textFont = Font.regular(presentationData.listsFontSize.baseDisplaySize)
        let subtextFont = Font.regular(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0)
        
        self.textNode.attributedText = NSAttributedString(string: self.textNode.attributedText?.string ?? "", font: textFont, textColor: presentationData.theme.contextMenu.primaryColor)
        self.statusNode.attributedText = NSAttributedString(string: self.statusNode.attributedText?.string ?? "", font: subtextFont, textColor: presentationData.theme.contextMenu.secondaryColor)
    }
    
    @objc private func buttonPressed() {
        self.performAction()
    }
    
    func performAction() {
        guard let controller = self.getController() else {
            return
        }
        self.item.action(controller, { [weak self] result in
            self?.actionSelected(result)
        })
    }
    
    func setIsHighlighted(_ value: Bool) {
        if value {
            self.highlightedBackgroundNode.alpha = 1.0
        } else {
            self.highlightedBackgroundNode.alpha = 0.0
        }
    }
}

private func stringForRemainingTime(_ duration: Int32, strings: PresentationStrings) -> String {
    let days = duration / (3600 * 24)
    let hours = duration / 3600
    let minutes = duration / 60 % 60
    let seconds = duration % 60
    let durationString: String
    if days > 0 {
        let roundDays = round(Double(duration) / (3600.0 * 24.0))
        return strings.Conversation_AutoremoveRemainingDays(Int32(roundDays))
    } else if hours > 0 {
        durationString = String(format: "%d:%02d:%02d", hours, minutes, seconds)
    } else {
        durationString = String(format: "%d:%02d", minutes, seconds)
    }
    return strings.Conversation_AutoremoveRemainingTime(durationString).0
}

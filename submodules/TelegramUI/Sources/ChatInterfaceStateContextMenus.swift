import Foundation
import UIKit
import Postbox
import TelegramCore
import SyncCore
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
    guard !chatPresentationInterfaceState.isScheduledMessages else {
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
        /*case .group:
            break*/
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
                            options.formUnion([.imageOrVideo, .file])
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

func updatedChatEditInterfaceMessagetState(state: ChatPresentationInterfaceState, message: Message) -> ChatPresentationInterfaceState {
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

func contextMenuForChatPresentationIntefaceState(chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, messages: [Message], controllerInteraction: ChatControllerInteraction?, selectAll: Bool, interfaceInteraction: ChatPanelInterfaceInteraction?) -> Signal<[ContextMenuItem], NoError> {
    guard let interfaceInteraction = interfaceInteraction, let controllerInteraction = controllerInteraction else {
        return .single([])
    }
    
    var loadStickerSaveStatus: MediaId?
    var loadCopyMediaResource: MediaResource?
    var isAction = false
    var diceEmoji: String?
    var canDiscuss = false
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
    
    if Namespaces.Message.allScheduled.contains(message.id.namespace) {
        canReply = false
        canPin = false
    } else if messages[0].flags.intersection([.Failed, .Unsent]).isEmpty {
        switch chatPresentationInterfaceState.chatLocation {
            case .peer:
                if let channel = messages[0].peers[messages[0].id.peerId] as? TelegramChannel {
                    if !isAction {
                        canPin = channel.hasPermission(.pinMessages)
                        
                        if messages[0].id.namespace == Namespaces.Message.Cloud {
                            switch channel.info {
                            case let .broadcast(info):
                                if info.flags.contains(.hasDiscussionGroup) {
                                    canDiscuss = true
                                }
                            case .group:
                                break
                            }
                        }
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
    
    let dataSignal: Signal<(MessageContextMenuData, [MessageId: ChatUpdatingMessageMedia]), NoError> = combineLatest(
        loadLimits,
        loadStickerSaveStatusSignal,
        loadResourceStatusSignal,
        context.sharedContext.chatAvailableMessageActions(postbox: context.account.postbox, accountPeerId: context.account.peerId, messageIds: Set(messages.map { $0.id })),
        context.account.pendingUpdateMessageManager.updatingMessageMedia
        |> take(1)
    )
    |> map { limitsConfiguration, stickerSaveStatus, resourceStatus, messageActions, updatingMessageMedia -> (MessageContextMenuData, [MessageId: ChatUpdatingMessageMedia]) in
        var canEdit = false
        if !isAction {
            let message = messages[0]
            canEdit = canEditMessage(context: context, limitsConfiguration: limitsConfiguration, message: message)
        }
        
        return (MessageContextMenuData(starStatus: stickerSaveStatus, canReply: canReply, canPin: canPin, canEdit: canEdit, canSelect: canSelect, resourceStatus: resourceStatus, messageActions: messageActions), updatingMessageMedia)
    }
    
    return dataSignal
    |> deliverOnMainQueue
    |> map { data, updatingMessageMedia -> [ContextMenuItem] in
        var actions: [ContextMenuItem] = []
        
        if let starStatus = data.starStatus {
            actions.append(.action(ContextMenuActionItem(text: starStatus ? chatPresentationInterfaceState.strings.Stickers_RemoveFromFavorites : chatPresentationInterfaceState.strings.Stickers_AddToFavorites, icon: { theme in
                return generateTintedImage(image: starStatus ? UIImage(bundleImageName: "Chat/Context Menu/Unstar") : UIImage(bundleImageName: "Chat/Context Menu/Rate"), color: theme.actionSheet.primaryTextColor)
            }, action: { _, f in
                interfaceInteraction.toggleMessageStickerStarred(messages[0].id)
                f(.default)
            })))
        }
        
        if data.canReply {
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
            }
            if resourceAvailable, !message.containsSecretMedia {
                var mediaReference: AnyMediaReference?
                for media in message.media {
                    if let image = media as? TelegramMediaImage, let largest = largestImageRepresentation(image.representations) {
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
        
        if data.canEdit {
            actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_MessageDialogEdit, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.actionSheet.primaryTextColor)
            }, action: { _, f in
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
        
        if data.canPin {
            if chatPresentationInterfaceState.pinnedMessage?.id != messages[0].id {
                actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_Pin, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Pin"), color: theme.actionSheet.primaryTextColor)
                }, action: { _, f in
                    interfaceInteraction.pinMessage(messages[0].id)
                    f(.dismissWithoutContent)
                })))
            } else {
                actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_Unpin, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Unpin"), color: theme.actionSheet.primaryTextColor)
                }, action: { _, f in
                    interfaceInteraction.unpinMessage()
                    f(.default)
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
        
        if let message = messages.first, message.id.namespace == Namespaces.Message.Cloud, let channel = message.peers[message.id.peerId] as? TelegramChannel, !(message.media.first is TelegramMediaAction) {
            actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_ContextMenuCopyLink, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.actionSheet.primaryTextColor)
            }, action: { _, f in
                let _ = (exportMessageLink(account: context.account, peerId: message.id.peerId, messageId: message.id)
                |> map { result -> String? in
                    return result
                }
                |> deliverOnMainQueue).start(next: { link in
                    if let link = link {
                        UIPasteboard.general.string = link
                        
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        if channel.addressName == nil {
                            controllerInteraction.presentGlobalOverlayController(OverlayStatusController(theme: presentationData.theme, type: .genericSuccess(presentationData.strings.Conversation_PrivateMessageLinkCopied, true)), nil)
                        } else {
                            controllerInteraction.presentGlobalOverlayController(OverlayStatusController(theme: presentationData.theme, type: .genericSuccess(presentationData.strings.GroupInfo_InviteLink_CopyAlert_Success, false)), nil)
                        }
                    }
                })
                f(.default)
            })))
        }
        
        if messages.count == 1 {
            let message = messages[0]
            
            var hasAutoremove = false
            for attribute in message.attributes {
                if let _ = attribute as? AutoremoveTimeoutMessageAttribute {
                    hasAutoremove = true
                    break
                }
            }
            
            if !hasAutoremove {
                for media in message.media {
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
        if !data.messageActions.options.intersection([.deleteLocally, .deleteGlobally]).isEmpty && isAction {
            actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_ContextMenuDelete, textColor: .destructive, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.actionSheet.destructiveActionTextColor)
            }, action: { controller, f in
                interfaceInteraction.deleteMessages(messages, controller, f)
            })))
        }
        
        if data.messageActions.options.contains(.viewStickerPack) {
            actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.StickerPack_ViewPack, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Sticker"), color: theme.actionSheet.primaryTextColor)
            }, action: { _, f in
                let _ = controllerInteraction.openMessage(message, .default)
                f(.dismissWithoutContent)
            })))
        }
        
        if data.messageActions.options.contains(.rateCall) {
            var callId: CallId?
            for media in message.media {
                if let action = media as? TelegramMediaAction, case let .phoneCall(id, discardReason, _) = action.action {
                    if discardReason != .busy && discardReason != .missed {
                        if let logName = callLogNameForId(id: id, account: context.account) {
                            let start = logName.index(logName.startIndex, offsetBy: "\(id)".count + 1)
                            let end = logName.index(logName.endIndex, offsetBy: -4)
                            let accessHash = logName[start..<end]
                            if let accessHash = Int64(accessHash) {
                                callId = CallId(id: id, accessHash: accessHash)
                            }
                        }
                    }
                    break
                }
            }
            if let callId = callId {
                actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Call_RateCall, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Rate"), color: theme.actionSheet.primaryTextColor)
                }, action: { _, f in
                    let _ = controllerInteraction.rateCall(message, callId)
                    f(.dismissWithoutContent)
                })))
            }
        }
        
        if data.messageActions.options.contains(.forward) {
            actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_ContextMenuForward, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.actionSheet.primaryTextColor)
            }, action: { _, f in
                interfaceInteraction.forwardMessages(selectAll ? messages : [message])
                f(.dismissWithoutContent)
            })))
        }
        
        if canDiscuss {
            actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_ContextMenuDiscuss, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Message"), color: theme.actionSheet.primaryTextColor)
            }, action: { c, _ in
                let timestamp = messages[0].timestamp
                let channelMessageId = messages[0].id
                
                enum DiscussMessageResult {
                    case message(MessageId)
                    case peer(PeerId)
                }
                
                let signal = context.account.postbox.transaction { transaction -> PeerId? in
                    if let cachedData = transaction.getPeerCachedData(peerId: messages[0].id.peerId) as? CachedChannelData {
                        return cachedData.linkedDiscussionPeerId
                    } else {
                        return nil
                    }
                }
                |> mapToSignal { peerId -> Signal<DiscussMessageResult?, NoError> in
                    guard let peerId = peerId else {
                        return .single(nil)
                    }
                    let historyView = preloadedChatHistoryViewForLocation(ChatHistoryLocationInput(content: .InitialSearch(location: .index(MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: 0), timestamp: timestamp)), count: 30), id: 0), account: context.account, chatLocation: .peer(peerId), fixedCombinedReadStates: nil, tagMask: nil, additionalData: [])
                    return historyView
                    |> mapToSignal { historyView -> Signal<(MessageIndex?, Bool), NoError> in
                        switch historyView {
                        case .Loading:
                            return .single((nil, true))
                        case let .HistoryView(view, _, _, _, _, _, _):
                            for entry in view.entries {
                                for attribute in entry.message.attributes {
                                    if let attribute = attribute as? SourceReferenceMessageAttribute {
                                        if attribute.messageId == channelMessageId {
                                            return .single((entry.message.index, false))
                                        }
                                    }
                                }
                            }
                            return .single((nil, false))
                        }
                    }
                    |> take(until: { index in
                        return SignalTakeAction(passthrough: true, complete: !index.1)
                    })
                    |> last
                    |> map { result -> DiscussMessageResult? in
                        if let index = result?.0 {
                            return .message(index.id)
                        } else {
                            return .peer(peerId)
                        }
                    }
                }
                
                let foundIndex = Promise<DiscussMessageResult?>()
                foundIndex.set(signal)
                
                c.dismiss(completion: { [weak interfaceInteraction] in
                    var cancelImpl: (() -> Void)?
                    let statusController = OverlayStatusController(theme: chatPresentationInterfaceState.theme, type: .loading(cancelled: {
                        cancelImpl?()
                    }))
                    controllerInteraction.presentController(statusController, nil)
                    
                    let disposable = (foundIndex.get()
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak statusController] result in
                        statusController?.dismiss()
                        
                        if let result = result {
                            switch result {
                            case let .message(id):
                                interfaceInteraction?.navigateToMessage(id)
                            case let .peer(peerId):
                                interfaceInteraction?.navigateToChat(peerId)
                            }
                        }
                    })
                    
                    cancelImpl = { [weak statusController] in
                        disposable.dispose()
                        statusController?.dismiss()
                    }
                })
            })))
        }
        
        if data.messageActions.options.contains(.report) {
            actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_ContextMenuReport, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Report"), color: theme.actionSheet.primaryTextColor)
            }, action: { controller, f in
                interfaceInteraction.reportMessages(selectAll ? messages : [message], controller)
            })))
        }
        
        var clearCacheAsDelete = false
        if let peer = message.peers[message.id.peerId] as? TelegramChannel {
            clearCacheAsDelete = true
        }
        if (!data.messageActions.options.intersection([.deleteLocally, .deleteGlobally]).isEmpty || clearCacheAsDelete) && !isAction {
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
        
        if data.canSelect {
            if !actions.isEmpty {
                actions.append(.separator)
            }
            actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_ContextMenuMore, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/More"), color: theme.actionSheet.primaryTextColor)
            }, action: { _, f in
                interfaceInteraction.beginMessageSelection(selectAll ? messages.map { $0.id } : [message.id], { transition in
                    f(.custom(transition))
                })
            })))
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

func chatAvailableMessageActionsImpl(postbox: Postbox, accountPeerId: PeerId, messageIds: Set<MessageId>) -> Signal<ChatAvailableMessageActions, NoError> {
    return postbox.transaction { transaction -> ChatAvailableMessageActions in
        let limitsConfiguration: LimitsConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.limitsConfiguration) as? LimitsConfiguration ?? LimitsConfiguration.defaultValue
        var optionsMap: [MessageId: ChatAvailableMessageActionOptions] = [:]
        var banPeer: Peer?
        var hadPersonalIncoming = false
        var hadBanPeerId = false
        for id in messageIds {
            let isScheduled = id.namespace == Namespaces.Message.ScheduledCloud
            if optionsMap[id] == nil {
                optionsMap[id] = []
            }
            if let message = transaction.getMessage(id) {
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
                    if let peer = transaction.getPeer(id.peerId), let channel = peer as? TelegramChannel {
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
                } else if let peer = transaction.getPeer(id.peerId) {
                    var isAction = false
                    for media in message.media {
                        if media is TelegramMediaAction || media is TelegramMediaExpiredContent {
                            isAction = true
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
                        if !isScheduled && message.id.peerId.namespace != Namespaces.Peer.SecretChat && !message.containsSecretMedia && !isAction {
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
                        if message.flags.contains(.Incoming) {
                            hadPersonalIncoming = true
                        }
                        if canDeleteGlobally {
                            optionsMap[id]!.insert(.deleteGlobally)
                        }
                        if user.botInfo != nil {
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

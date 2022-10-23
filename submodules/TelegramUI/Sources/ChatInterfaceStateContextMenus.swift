import Foundation
import UIKit
import Postbox
import TelegramCore
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
import ShimmerEffect
import AnimatedAvatarSetNode
import AvatarNode
import AdUI
import TelegramNotices
import ReactionListContextMenuContent
import TelegramUIPreferences
import TranslateUI
import DebugSettingsUI
import ChatPresentationInterfaceState
import Pasteboard
import SettingsUI
import PremiumUI
import TextNodeWithEntities

private struct MessageContextMenuData {
    let starStatus: Bool?
    let canReply: Bool
    let canPin: Bool
    let canEdit: Bool
    let canSelect: Bool
    let resourceStatus: MediaResourceStatus?
    let messageActions: ChatAvailableMessageActions
}

func canEditMessage(context: AccountContext, limitsConfiguration: EngineConfiguration.Limits, message: Message) -> Bool {
    return canEditMessage(accountPeerId: context.account.peerId, limitsConfiguration: limitsConfiguration, message: message)
}

private func canEditMessage(accountPeerId: PeerId, limitsConfiguration: EngineConfiguration.Limits, message: Message, reschedule: Bool = false) -> Bool {
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
    } else if let author = message.author, message.author?.id != message.id.peerId, author.id.namespace == Namespaces.Peer.CloudChannel && message.id.peerId.namespace == Namespaces.Peer.CloudChannel, !message.flags.contains(.Incoming) {
        if message.media.contains(where: { $0 is TelegramMediaInvoice }) {
            hasEditRights = false
        } else {
            hasEditRights = true
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
            }  else if let _ = media as? TelegramMediaGame {
                hasUneditableAttributes = true
                break
            }  else if let _ = media as? TelegramMediaInvoice {
                hasUneditableAttributes = true
                break
            }
        }
        
        if !hasUneditableAttributes || reschedule {
            if canPerformEditingActions(limits: limitsConfiguration._asLimits(), accountPeerId: accountPeerId, message: message, unlimitedInterval: unlimitedInterval) {
                return true
            }
        }
    }
    return false
}

private func canViewReadStats(message: Message, participantCount: Int?, isMessageRead: Bool, appConfig: AppConfiguration) -> Bool {
    guard let peer = message.peers[message.id.peerId] else {
        return false
    }

    if message.flags.contains(.Incoming) {
        return false
    } else {
        if !isMessageRead {
            return false
        }
    }

    for media in message.media {
        if let _ = media as? TelegramMediaAction {
            return false
        } else if let file = media as? TelegramMediaFile {
            if file.isVoice || file.isInstantVideo {
                var hasRead = false
                for attribute in message.attributes {
                    if let attribute = attribute as? ConsumableContentMessageAttribute {
                        if attribute.consumed {
                            hasRead = true
                            break
                        }
                    }
                }
                if !hasRead {
                    return false
                }
            }
        }
    }

    var maxParticipantCount = 50
    var maxTimeout = 7 * 86400
    if let data = appConfig.data {
        if let value = data["chat_read_mark_size_threshold"] as? Double {
            maxParticipantCount = Int(value)
        }
        if let value = data["chat_read_mark_expire_period"] as? Double {
            maxTimeout = Int(value)
        }
    }

    switch peer {
    case let channel as TelegramChannel:
        if case .broadcast = channel.info {
            return false
        } else {
            if let participantCount = participantCount {
                if participantCount > maxParticipantCount {
                    return false
                }
            } else {
                return false
            }
        }
    case let group as TelegramGroup:
        if group.participantCount > maxParticipantCount {
            return false
        }
    default:
        return false
    }

    let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
    if Int64(message.timestamp) + Int64(maxTimeout) < Int64(timestamp) {
        return false
    }

    return true
}

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
    
    if let channel = peer as? TelegramChannel, channel.flags.contains(.isForum) {
        if let threadData = chatPresentationInterfaceState.threadData {
            if threadData.isClosed {
                var canManage = false
                if channel.flags.contains(.isCreator) {
                    canManage = true
                } else if channel.hasPermission(.manageTopics) {
                    canManage = true
                } else if threadData.isOwnedByMe {
                    canManage = true
                }
                
                if !canManage {
                    return false
                }
            }
        }
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
    case .feed:
        canReply = false
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

func messageMediaEditingOptions(message: Message) -> MessageMediaEditingOptions {
    if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
        return []
    }
    for attribute in message.attributes {
        if attribute is AutoclearTimeoutMessageAttribute {
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
                    case let .Video(_, _, flags):
                        if flags.contains(.instantRoundVideo) {
                            return []
                        } else {
                            options.formUnion([.imageOrVideo, .file])
                        }
                    case let .Audio(isVoice, _, _, _, _):
                        if isVoice {
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

func contextMenuForChatPresentationInterfaceState(chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, messages: [Message], controllerInteraction: ChatControllerInteraction?, selectAll: Bool, interfaceInteraction: ChatPanelInterfaceInteraction?, readStats: MessageReadStats? = nil, messageNode: ChatMessageItemView? = nil) -> Signal<ContextController.Items, NoError> {
    guard let interfaceInteraction = interfaceInteraction, let controllerInteraction = controllerInteraction else {
        return .single(ContextController.Items(content: .list([])))
    }
    
    var hasExpandedAudioTranscription = false
    if let messageNode = messageNode as? ChatMessageBubbleItemNode {
        hasExpandedAudioTranscription = messageNode.hasExpandedAudioTranscription()
    }

    if messages.count == 1, let _ = messages[0].adAttribute {
        let message = messages[0]

        let presentationData = context.sharedContext.currentPresentationData.with { $0 }

        var actions: [ContextMenuItem] = []
        actions.append(.action(ContextMenuActionItem(text: presentationData.strings.SponsoredMessageMenu_Info, textColor: .primary, textLayout: .twoLinesMax, textFont: .custom(Font.regular(presentationData.listsFontSize.baseDisplaySize - 1.0)), badge: nil, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Info"), color: theme.actionSheet.primaryTextColor)
        }, iconSource: nil, action: { c, _ in
            c.dismiss(completion: {
                controllerInteraction.navigationController()?.pushViewController(AdInfoScreen(context: context))
            })
        })))
        
        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
        if !chatPresentationInterfaceState.isPremium && !premiumConfiguration.isPremiumDisabled {
            actions.append(.action(ContextMenuActionItem(text: presentationData.strings.SponsoredMessageMenu_Hide, textColor: .primary, textLayout: .twoLinesMax, textFont: .custom(Font.regular(presentationData.listsFontSize.baseDisplaySize - 1.0)), badge: nil, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Restrict"), color: theme.actionSheet.primaryTextColor)
            }, iconSource: nil, action: { c, _ in
                c.dismiss(completion: {
                    var replaceImpl: ((ViewController) -> Void)?
                    let controller = PremiumDemoScreen(context: context, subject: .noAds, action: {
                        let controller = PremiumIntroScreen(context: context, source: .ads)
                        replaceImpl?(controller)
                    })
                    replaceImpl = { [weak controller] c in
                        controller?.replace(with: c)
                    }
                    controllerInteraction.navigationController()?.pushViewController(controller)
                })
            })))
        }

        actions.append(.separator)

        if chatPresentationInterfaceState.copyProtectionEnabled {
            
        } else {
            actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_ContextMenuCopy, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.actionSheet.primaryTextColor)
            }, action: { _, f in
                let copyTextWithEntities = {
                    var messageEntities: [MessageTextEntity]?
                    var restrictedText: String?
                    for attribute in message.attributes {
                        if let attribute = attribute as? TextEntitiesMessageAttribute {
                            messageEntities = attribute.entities
                        }
                        if let attribute = attribute as? RestrictedContentMessageAttribute {
                            restrictedText = attribute.platformText(platform: "ios", contentSettings: context.currentContentSettings.with { $0 }) ?? ""
                        }
                    }

                    if let restrictedText = restrictedText {
                        storeMessageTextInPasteboard(restrictedText, entities: nil)
                    } else {
                        storeMessageTextInPasteboard(message.text, entities: messageEntities)
                    }

                    Queue.mainQueue().after(0.2, {
                        let content: UndoOverlayContent = .copy(text: chatPresentationInterfaceState.strings.Conversation_MessageCopied)
                        controllerInteraction.displayUndo(content)
                    })
                }

                copyTextWithEntities()
                f(.default)
            })))
        }

        if let author = message.author, let addressName = author.addressName {
            let link = "https://t.me/\(addressName)"
            actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_ContextMenuCopyLink, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.actionSheet.primaryTextColor)
            }, action: { _, f in
                UIPasteboard.general.string = link

                let presentationData = context.sharedContext.currentPresentationData.with { $0 }

                Queue.mainQueue().after(0.2, {
                    controllerInteraction.displayUndo(.linkCopied(text: presentationData.strings.Conversation_LinkCopied))
                })

                f(.default)
            })))
        }

        return .single(ContextController.Items(content: .list(actions)))
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
                if loadStickerSaveStatus == nil {
                    loadCopyMediaResource = file.resource
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
    
    if case .peer = chatPresentationInterfaceState.chatLocation, let channel = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.flags.contains(.isForum) {
        if message.threadId == nil {
            canReply = false
        }
    }
    
    if Namespaces.Message.allScheduled.contains(message.id.namespace) || message.id.peerId.isReplies {
        canReply = false
        canPin = false
    } else if messages[0].flags.intersection([.Failed, .Unsent]).isEmpty {
        switch chatPresentationInterfaceState.chatLocation {
        case .peer, .replyThread, .feed:
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
    if let loadStickerSaveStatus = loadStickerSaveStatus {
        loadStickerSaveStatusSignal = context.engine.stickers.isStickerSaved(id: loadStickerSaveStatus)
        |> map(Optional.init)
    }
    
    var loadResourceStatusSignal: Signal<MediaResourceStatus?, NoError> = .single(nil)
    if let loadCopyMediaResource = loadCopyMediaResource {
        loadResourceStatusSignal = context.account.postbox.mediaBox.resourceStatus(loadCopyMediaResource)
        |> take(1)
        |> map(Optional.init)
    }
    
    let loadLimits = context.engine.data.get(
        TelegramEngine.EngineData.Item.Configuration.Limits(),
        TelegramEngine.EngineData.Item.Configuration.App()
    )
    
    struct InfoSummaryData {
        var linkedDiscusionPeerId: EnginePeerCachedInfoItem<EnginePeer.Id?>
        var canViewStats: Bool
        var participantCount: Int?
    }
    
    let infoSummaryData = context.engine.data.get(
        TelegramEngine.EngineData.Item.Peer.LinkedDiscussionPeerId(id: messages[0].id.peerId),
        TelegramEngine.EngineData.Item.Peer.CanViewStats(id: messages[0].id.peerId),
        TelegramEngine.EngineData.Item.Peer.ParticipantCount(id: messages[0].id.peerId)
    )
    |> map { linkedDiscusionPeerId, canViewStats, participantCount -> InfoSummaryData in
        return InfoSummaryData(
            linkedDiscusionPeerId: linkedDiscusionPeerId,
            canViewStats: canViewStats,
            participantCount: participantCount
        )
    }

    let readCounters = context.engine.data.get(TelegramEngine.EngineData.Item.Messages.PeerReadCounters(id: messages[0].id.peerId))
    
    let dataSignal: Signal<(MessageContextMenuData, [MessageId: ChatUpdatingMessageMedia], InfoSummaryData, AppConfiguration, Bool, Int32, AvailableReactions?, TranslationSettings, LoggingSettings, NotificationSoundList?), NoError> = combineLatest(
        loadLimits,
        loadStickerSaveStatusSignal,
        loadResourceStatusSignal,
        context.sharedContext.chatAvailableMessageActions(engine: context.engine, accountPeerId: context.account.peerId, messageIds: Set(messages.map { $0.id })),
        context.account.pendingUpdateMessageManager.updatingMessageMedia
        |> take(1),
        infoSummaryData,
        readCounters,
        ApplicationSpecificNotice.getMessageViewsPrivacyTips(accountManager: context.sharedContext.accountManager),
        context.engine.stickers.availableReactions(),
        context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.translationSettings, SharedDataKeys.loggingSettings]),
        context.engine.peers.notificationSoundList() |> take(1)
    )
    |> map { limitsAndAppConfig, stickerSaveStatus, resourceStatus, messageActions, updatingMessageMedia, infoSummaryData, readCounters, messageViewsPrivacyTips, availableReactions, sharedData, notificationSoundList -> (MessageContextMenuData, [MessageId: ChatUpdatingMessageMedia], InfoSummaryData, AppConfiguration, Bool, Int32, AvailableReactions?, TranslationSettings, LoggingSettings, NotificationSoundList?) in
        let (limitsConfiguration, appConfig) = limitsAndAppConfig
        var canEdit = false
        if !isAction {
            let message = messages[0]
            canEdit = canEditMessage(context: context, limitsConfiguration: limitsConfiguration, message: message)
        }

        let isMessageRead = readCounters.isOutgoingMessageIndexRead(message.index)
        
        let translationSettings: TranslationSettings
        if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.translationSettings]?.get(TranslationSettings.self) {
            translationSettings = current
        } else {
            translationSettings = TranslationSettings.defaultSettings
        }
        
        let loggingSettings: LoggingSettings
        if let current = sharedData.entries[SharedDataKeys.loggingSettings]?.get(LoggingSettings.self) {
            loggingSettings = current
        } else {
            loggingSettings = LoggingSettings.defaultSettings
        }
        
        return (MessageContextMenuData(starStatus: stickerSaveStatus, canReply: canReply, canPin: canPin, canEdit: canEdit, canSelect: canSelect, resourceStatus: resourceStatus, messageActions: messageActions), updatingMessageMedia, infoSummaryData, appConfig, isMessageRead, messageViewsPrivacyTips, availableReactions, translationSettings, loggingSettings, notificationSoundList)
    }
    
    return dataSignal
    |> deliverOnMainQueue
    |> map { data, updatingMessageMedia, infoSummaryData, appConfig, isMessageRead, messageViewsPrivacyTips, availableReactions, translationSettings, loggingSettings, notificationSoundList -> ContextController.Items in
        var actions: [ContextMenuItem] = []
        
        var isPinnedMessages = false
        if case .pinnedMessages = chatPresentationInterfaceState.subject {
            isPinnedMessages = true
        }
        
        if let starStatus = data.starStatus {
            var isPremiumSticker = false
            for media in messages[0].media {
                if let file = media as? TelegramMediaFile, file.isPremiumSticker {
                    isPremiumSticker = true
                    break
                }
            }
            if !isPremiumSticker || chatPresentationInterfaceState.isPremium {
                actions.append(.action(ContextMenuActionItem(text: starStatus ? chatPresentationInterfaceState.strings.Stickers_RemoveFromFavorites : chatPresentationInterfaceState.strings.Stickers_AddToFavorites, icon: { theme in
                    return generateTintedImage(image: starStatus ? UIImage(bundleImageName: "Chat/Context Menu/Unfave") : UIImage(bundleImageName: "Chat/Context Menu/Fave"), color: theme.actionSheet.primaryTextColor)
                }, action: { _, f in
                    interfaceInteraction.toggleMessageStickerStarred(messages[0].id)
                    f(.default)
                })))
            }
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
                                controller.peerSelected = { [weak controller] peer, _ in
                                    let peerId = peer.id
                                    
                                    if let strongController = controller {
                                        strongController.dismiss()
                                        
                                        let id = Int64.random(in: Int64.min ... Int64.max)
                                        let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: LocalFileReferenceMediaResource(localFilePath: logPath, randomId: id), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: nil, attributes: [.FileName(fileName: "CallStats.log")])
                                        let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), replyToMessageId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                                        
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
        
        var audioTranscription: AudioTranscriptionMessageAttribute?
        var didRateAudioTranscription = false
        for attribute in message.attributes {
            if let attribute = attribute as? AudioTranscriptionMessageAttribute {
                audioTranscription = attribute
                didRateAudioTranscription = attribute.didRate
                break
            }
        }
        
        var hasRateTranscription = false
        if hasExpandedAudioTranscription, let audioTranscription = audioTranscription, !didRateAudioTranscription {
            hasRateTranscription = true
            actions.insert(.custom(ChatRateTranscriptionContextItem(context: context, message: message, action: { [weak context] value in
                guard let context = context else {
                    return
                }
                
                let _ = context.engine.messages.rateAudioTranscription(messageId: message.id, id: audioTranscription.id, isGood: value).start()
                
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let content: UndoOverlayContent = .info(title: nil, text: presentationData.strings.Chat_AudioTranscriptionFeedbackTip)
                controllerInteraction.displayUndo(content)
            }), false), at: 0)
            actions.insert(.separator, at: 1)
        }
        
        if !hasRateTranscription {
            for media in message.media {
                if let file = media as? TelegramMediaFile, let size = file.size, size < 1 * 1024 * 1024, let duration = file.duration, duration < 60, (["audio/mpeg", "audio/mp3", "audio/mpeg3", "audio/ogg"] as [String]).contains(file.mimeType.lowercased()) {
                    let fileName = file.fileName ?? "Tone"
                    
                    var isAlreadyAdded = false
                    if let notificationSoundList = notificationSoundList, notificationSoundList.sounds.contains(where: { $0.file.fileId == file.fileId }) {
                        isAlreadyAdded = true
                    }
                    
                    if !isAlreadyAdded {
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        actions.append(.action(ContextMenuActionItem(text: presentationData.strings.Chat_SaveForNotifications, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/DownloadTone"), color: theme.actionSheet.primaryTextColor)
                        }, action: { _, f in
                            f(.default)
                            
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            
                            let settings = NotificationSoundSettings.extract(from: context.currentAppConfiguration.with({ $0 }))
                            if size > settings.maxSize {
                                controllerInteraction.displayUndo(.info(title: presentationData.strings.Notifications_UploadError_TooLarge_Title, text: presentationData.strings.Notifications_UploadError_TooLarge_Text(dataSizeString(Int64(settings.maxSize), formatting: DataSizeStringFormatting(presentationData: presentationData))).string))
                            } else if Double(duration) > Double(settings.maxDuration) {
                                controllerInteraction.displayUndo(.info(title: presentationData.strings.Notifications_UploadError_TooLong_Title(fileName).string, text: presentationData.strings.Notifications_UploadError_TooLong_Text(stringForDuration(Int32(settings.maxDuration))).string))
                            } else {
                                let _ = (context.engine.peers.saveNotificationSound(file: .message(message: MessageReference(message), media: file))
                                |> deliverOnMainQueue).start(completed: {
                                    controllerInteraction.displayUndo(.notificationSoundAdded(title: presentationData.strings.Notifications_UploadSuccess_Title, text: presentationData.strings.Notifications_SaveSuccess_Text, action: {
                                        controllerInteraction.navigationController()?.pushViewController(notificationsAndSoundsController(context: context, exceptionsList: nil))
                                    }))
                                })
                            }
                        })))
                        actions.append(.separator)
                    }
                }
            }
            
            if context.sharedContext.immediateExperimentalUISettings.enableReactionOverrides {
                for media in message.media {
                    if let file = media as? TelegramMediaFile, file.isAnimatedSticker {
                        actions.append(.action(ContextMenuActionItem(text: "Set as Reaction Effect", icon: { _ in
                            return nil
                        }, action: { c, _ in
                            let subItems: Signal<ContextController.Items, NoError> = context.engine.stickers.availableReactions()
                            |> map { reactions -> ContextController.Items in
                                var subActions: [ContextMenuItem] = []
                                
                                if let reactions = reactions {
                                    for reaction in reactions.reactions {
                                        if !reaction.isEnabled || !reaction.isPremium {
                                            continue
                                        }
                                        
                                        guard case let .builtin(emojiValue) = reaction.value else {
                                            continue
                                        }
                                        
                                        subActions.append(.action(ContextMenuActionItem(text: emojiValue, icon: { _ in
                                            return nil
                                        }, action: { _, f in
                                            let _ = updateExperimentalUISettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
                                                var settings = settings
                                                
                                                var currentItems: [ExperimentalUISettings.AccountReactionOverrides.Item]
                                                if let value = settings.accountReactionEffectOverrides.first(where: { $0.accountId == context.account.id.int64 }) {
                                                    currentItems = value.items
                                                } else {
                                                    currentItems = []
                                                }
                                                
                                                currentItems.removeAll(where: { $0.key == reaction.value })
                                                currentItems.append(ExperimentalUISettings.AccountReactionOverrides.Item(
                                                    key: reaction.value,
                                                    messageId: message.id,
                                                    mediaId: file.fileId
                                                ))
                                                
                                                settings.accountReactionEffectOverrides.removeAll(where: { $0.accountId == context.account.id.int64 })
                                                settings.accountReactionEffectOverrides.append(ExperimentalUISettings.AccountReactionOverrides(accountId: context.account.id.int64, items: currentItems))
                                                
                                                return settings
                                            }).start()
                                            
                                            f(.default)
                                        })))
                                    }
                                }
                                
                                return ContextController.Items(content: .list(subActions), disablePositionLock: true, tip: nil)
                            }
                            
                            c.pushItems(items: subItems)
                        })))
                        
                        actions.append(.action(ContextMenuActionItem(text: "Set as Sticker Effect", icon: { _ in
                            return nil
                        }, action: { c, _ in
                            let stickersKey: PostboxViewKey = .orderedItemList(id: Namespaces.OrderedItemList.CloudPremiumStickers)
                            let subItems: Signal<ContextController.Items, NoError> = context.account.postbox.combinedView(keys: [stickersKey])
                            |> map { views -> [String] in
                                if let view = views.views[stickersKey] as? OrderedItemListView, !view.items.isEmpty {
                                    return view.items.compactMap { item -> String? in
                                        guard let mediaItem = item.contents.get(RecentMediaItem.self) else {
                                            return nil
                                        }
                                        let file = mediaItem.media
                                        for attribute in file.attributes {
                                            switch attribute {
                                            case let .Sticker(text, _, _):
                                                return text
                                            default:
                                                break
                                            }
                                        }
                                        return nil
                                    }
                                } else {
                                    return []
                                }
                            }
                            |> map { stickerNames -> ContextController.Items in
                                var subActions: [ContextMenuItem] = []
                                
                                for stickerName in stickerNames {
                                    subActions.append(.action(ContextMenuActionItem(text: stickerName, icon: { _ in
                                        return nil
                                    }, action: { _, f in
                                        let _ = updateExperimentalUISettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
                                            var settings = settings
                                            
                                            var currentItems: [ExperimentalUISettings.AccountReactionOverrides.Item]
                                            if let value = settings.accountStickerEffectOverrides.first(where: { $0.accountId == context.account.id.int64 }) {
                                                currentItems = value.items
                                            } else {
                                                currentItems = []
                                            }
                                            
                                            currentItems.removeAll(where: { $0.key == MessageReaction.Reaction.builtin(stickerName) })
                                            currentItems.append(ExperimentalUISettings.AccountReactionOverrides.Item(
                                                key: .builtin(stickerName),
                                                messageId: message.id,
                                                mediaId: file.fileId
                                            ))
                                            
                                            settings.accountStickerEffectOverrides.removeAll(where: { $0.accountId == context.account.id.int64 })
                                            settings.accountStickerEffectOverrides.append(ExperimentalUISettings.AccountReactionOverrides(accountId: context.account.id.int64, items: currentItems))
                                            
                                            return settings
                                        }).start()
                                        
                                        f(.default)
                                    })))
                                }
                                
                                return ContextController.Items(content: .list(subActions), disablePositionLock: true, tip: nil)
                            }
                            
                            c.pushItems(items: subItems)
                        })))
                        
                        actions.append(.separator)
                        
                        break
                    }
                }
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
        
        var messageText: String = ""
        for message in messages {
            if !message.text.isEmpty {
                if messageText.isEmpty {
                    messageText = message.text
                } else {
                    messageText = ""
                    break
                }
            }
        }
        
        for attribute in message.attributes {
            if hasExpandedAudioTranscription, let attribute = attribute as? AudioTranscriptionMessageAttribute {
                if !messageText.isEmpty {
                    messageText.append("\n")
                }
                messageText.append(attribute.text)
                break
            }
        }
        
        var isPoll = false
        if messageText.isEmpty {
            for media in message.media {
                if let poll = media as? TelegramMediaPoll {
                    isPoll = true
                    var text = poll.text
                    for option in poll.options {
                        text.append("\n— \(option.text)")
                    }
                    messageText = poll.text
                    break
                }
            }
        }
        
        if (!messageText.isEmpty || resourceAvailable || diceEmoji != nil) && !chatPresentationInterfaceState.copyProtectionEnabled && !message.isCopyProtected() {
            let message = messages[0]
            var isExpired = false
            for media in message.media {
                if let _ = media as? TelegramMediaExpiredContent {
                    isExpired = true
                }
            }
            if !isExpired {
                if !isPoll {
                    actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_ContextMenuCopy, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.actionSheet.primaryTextColor)
                    }, action: { _, f in
                        if let diceEmoji = diceEmoji {
                            UIPasteboard.general.string = diceEmoji
                        } else {
                            let copyTextWithEntities = {
                                var messageEntities: [MessageTextEntity]?
                                var restrictedText: String?
                                for attribute in message.attributes {
                                    if let attribute = attribute as? TextEntitiesMessageAttribute {
                                        messageEntities = attribute.entities
                                    }
                                    if let attribute = attribute as? RestrictedContentMessageAttribute {
                                        restrictedText = attribute.platformText(platform: "ios", contentSettings: context.currentContentSettings.with { $0 }) ?? ""
                                    }
                                }
                                
                                if let restrictedText = restrictedText {
                                    storeMessageTextInPasteboard(restrictedText, entities: nil)
                                } else {
                                    storeMessageTextInPasteboard(messageText, entities: messageEntities)
                                }
                                
                                Queue.mainQueue().after(0.2, {
                                    let content: UndoOverlayContent = .copy(text: chatPresentationInterfaceState.strings.Conversation_MessageCopied)
                                    controllerInteraction.displayUndo(content)
                                })
                            }
                            if resourceAvailable {
                                for media in message.media {
                                    if let image = media as? TelegramMediaImage, let largest = largestImageRepresentation(image.representations) {
                                        let _ = (context.account.postbox.mediaBox.resourceData(largest.resource, option: .incremental(waitUntilFetchStatus: false))
                                            |> take(1)
                                            |> deliverOnMainQueue).start(next: { data in
                                                if data.complete, let imageData = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                                                    if let image = UIImage(data: imageData) {
                                                        if !messageText.isEmpty {
                                                            copyTextWithEntities()
                                                        } else {
                                                            UIPasteboard.general.image = image
                                                            
                                                            Queue.mainQueue().after(0.2, {
                                                                let content: UndoOverlayContent = .copy(text: chatPresentationInterfaceState.strings.Conversation_ImageCopied)
                                                                controllerInteraction.displayUndo(content)
                                                            })
                                                        }
                                                    } else {
                                                        copyTextWithEntities()
                                                    }
                                                } else {
                                                    copyTextWithEntities()
                                                }
                                            })
                                        break
                                    } else {
                                        copyTextWithEntities()
                                        break
                                    }
                                }
                            } else {
                                copyTextWithEntities()
                            }
                        }
                        f(.default)
                    })))
                }
                
                var showTranslateIfTopical = false
                if let peer = chatPresentationInterfaceState.renderedPeer?.chatMainPeer as? TelegramChannel, !(peer.addressName ?? "").isEmpty {
                    showTranslateIfTopical = true
                }
                
                let (canTranslate, _) = canTranslateText(context: context, text: messageText, showTranslate: translationSettings.showTranslate, showTranslateIfTopical: showTranslateIfTopical, ignoredLanguages: translationSettings.ignoredLanguages)
                if canTranslate {
                    actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_ContextMenuTranslate, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Translate"), color: theme.actionSheet.primaryTextColor)
                    }, action: { _, f in
                        controllerInteraction.performTextSelectionAction(0, NSAttributedString(string: messageText), .translate)
                        f(.default)
                    })))
                }
                
                if isSpeakSelectionEnabled() && !messageText.isEmpty {
                    actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_ContextMenuSpeak, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Message"), color: theme.actionSheet.primaryTextColor)
                    }, action: { _, f in
                        controllerInteraction.performTextSelectionAction(0, NSAttributedString(string: messageText), .speak)
                        f(.default)
                    })))
                }
            }
            
            if resourceAvailable, !message.containsSecretMedia {
                var mediaReference: AnyMediaReference?
                var isVideo = false
                for media in message.media {
                    if let image = media as? TelegramMediaImage, let _ = largestImageRepresentation(image.representations) {
                        mediaReference = ImageMediaReference.standalone(media: image).abstract
                        break
                    } else if let file = media as? TelegramMediaFile, file.isVideo {
                        mediaReference = FileMediaReference.standalone(media: file).abstract
                        isVideo = true
                        break
                    }
                }
                if let mediaReference = mediaReference {
                    actions.append(.action(ContextMenuActionItem(text: isVideo ? chatPresentationInterfaceState.strings.Gallery_SaveVideo : chatPresentationInterfaceState.strings.Gallery_SaveImage, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Save"), color: theme.actionSheet.primaryTextColor)
                    }, action: { _, f in
                        let _ = (saveToCameraRoll(context: context, postbox: context.account.postbox, mediaReference: mediaReference)
                        |> deliverOnMainQueue).start(completed: {
                            Queue.mainQueue().after(0.2) {
                                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                controllerInteraction.presentControllerInCurrent(UndoOverlayController(presentationData: presentationData, content: .mediaSaved(text: isVideo ? presentationData.strings.Gallery_VideoSaved : presentationData.strings.Gallery_ImageSaved), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return true }), nil)
                            }
                        })
                        f(.default)
                    })))
                }
            }
        }
        
        var downloadableMediaResourceInfos: [String] = []
        for media in message.media {
            if let file = media as? TelegramMediaFile {
                if let info = extractMediaResourceDebugInfo(resource: file.resource) {
                    downloadableMediaResourceInfos.append(info)
                }
            } else if let image = media as? TelegramMediaImage {
                for representation in image.representations {
                    if let info = extractMediaResourceDebugInfo(resource: representation.resource) {
                        downloadableMediaResourceInfos.append(info)
                    }
                }
            }
        }
        
        if (loggingSettings.logToFile || loggingSettings.logToConsole) && !downloadableMediaResourceInfos.isEmpty {
            actions.append(.action(ContextMenuActionItem(text: "Send Logs", icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Message"), color: theme.actionSheet.primaryTextColor)
            }, action: { _, f in
                triggerDebugSendLogsUI(context: context, additionalInfo: "User has requested download logs for \(downloadableMediaResourceInfos)", pushController: { c in
                    controllerInteraction.navigationController()?.pushViewController(c)
                })
                f(.default)
            })))
        }
        
        var threadId: Int64?
        var threadMessageCount: Int = 0
        if case .peer = chatPresentationInterfaceState.chatLocation, let channel = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramChannel, case .group = channel.info {
            if case let .known(maybeValue) = infoSummaryData.linkedDiscusionPeerId, let _ = maybeValue {
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
                    f(.default)
                })))
            }
        }
        
        var canPin = data.canPin
        if case let .replyThread(message) = chatPresentationInterfaceState.chatLocation {
            if !message.isForumPost {
                canPin = false
            }
        }
        if isMigrated {
            canPin = false
        }
        
        if canPin {
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
                let _ = (context.engine.messages.exportMessageLink(peerId: message.id.peerId, messageId: message.id, isThread: threadMessageId != nil)
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
                        Queue.mainQueue().after(0.2, {
                            if warnAboutPrivate {
                                controllerInteraction.displayUndo(.linkCopied(text: presentationData.strings.Conversation_PrivateMessageLinkCopiedLong))
                            } else {
                                controllerInteraction.displayUndo(.linkCopied(text: presentationData.strings.Conversation_LinkCopied))
                            }
                        })
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
                    if let action = media as? TelegramMediaAction {
                        if let channel = message.peers[message.id.peerId] as? TelegramChannel {
                            if channel.flags.contains(.isCreator) || (channel.adminRights?.rights.contains(.canDeleteMessages) == true) {
                            } else {
                                isUnremovableAction = true
                            }
                        }

                        switch action.action {
                        case .historyScreenshot:
                            isUnremovableAction = true
                        default:
                            break
                        }
                    }
                    if let file = media as? TelegramMediaFile, !chatPresentationInterfaceState.copyProtectionEnabled && !message.isCopyProtected() {
                        if file.isVideo {
                            if file.isAnimated && !file.isVideoSticker {
                                actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_SaveGif, icon: { theme in
                                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Save"), color: theme.actionSheet.primaryTextColor)
                                }, action: { _, f in
                                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                    let _ = (toggleGifSaved(account: context.account, fileReference: .message(message: MessageReference(message), media: file), saved: true)
                                    |> deliverOnMainQueue).start(next: { result in
                                        Queue.mainQueue().after(0.2) {
                                            switch result {
                                                case .generic:
                                                    controllerInteraction.presentControllerInCurrent(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_gif", scale: 0.075, colors: [:], title: nil, text: presentationData.strings.Gallery_GifSaved, customUndoText: nil), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                                                case let .limitExceeded(limit, premiumLimit):
                                                    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
                                                    let text: String
                                                    if limit == premiumLimit || premiumConfiguration.isPremiumDisabled {
                                                        text = presentationData.strings.Premium_MaxSavedGifsFinalText
                                                    } else {
                                                        text = presentationData.strings.Premium_MaxSavedGifsText("\(premiumLimit)").string
                                                    }
                                                    controllerInteraction.presentControllerInCurrent(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_gif", scale: 0.075, colors: [:], title: presentationData.strings.Premium_MaxSavedGifsTitle("\(limit)").string, text: text, customUndoText: nil), elevatedLayout: false, animateInAsReplacement: false, action: { action in
                                                        if case .info = action {
                                                            let controller = PremiumIntroScreen(context: context, source: .savedGifs)
                                                            controllerInteraction.navigationController()?.pushViewController(controller)
                                                            return true
                                                        }
                                                        return false
                                                    }), nil)
                                            }
                                        }
                                    })

                                    f(.default)
                                })))
                            }
                            break
                        }
                    }
                }
            }
        }
        
        if data.messageActions.options.contains(.viewStickerPack) {
            actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.StickerPack_ViewPack, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Sticker"), color: theme.actionSheet.primaryTextColor)
            }, action: { _, f in
                let _ = controllerInteraction.openMessage(message, .default)
                f(.dismissWithoutContent)
            })))
        }
                
        if data.messageActions.options.contains(.forward) {
            if chatPresentationInterfaceState.copyProtectionEnabled || message.isCopyProtected() {
                
            } else {
                actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_ContextMenuForward, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.actionSheet.primaryTextColor)
                }, action: { _, f in
                    interfaceInteraction.forwardMessages(selectAll ? messages : [message])
                    f(.dismissWithoutContent)
                })))
            }
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
            
            if infoSummaryData.canViewStats, views >= 100 {
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
        
        if isReplyThreadHead {
            actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.SharedMedia_ViewInChat, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/GoToMessage"), color: theme.actionSheet.primaryTextColor)
            }, action: { c, _ in
                c.dismiss(completion: {
                    guard let navigationController = controllerInteraction.navigationController() else {
                        return
                    }
                    guard let peer = messages[0].peers[messages[0].id.peerId] else {
                        return
                    }
                    context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(EnginePeer(peer)), subject: .message(id: .id(messages[0].id), highlight: true, timecode: nil), useExisting: true))
                })
            })))
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
            var didAddSeparator = false
            if !selectAll || messages.count == 1 {
                if !actions.isEmpty && !didAddSeparator {
                    didAddSeparator = true
                    actions.append(.separator)
                }

                actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_ContextMenuSelect, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.actionSheet.primaryTextColor)
                }, action: { _, f in
                    interfaceInteraction.beginMessageSelection(selectAll ? messages.map { $0.id } : [message.id], { transition in
                        f(.custom(transition))
                    })
                })))
            }

            if messages.count > 1 {
                if !actions.isEmpty && !didAddSeparator {
                    didAddSeparator = true
                    actions.append(.separator)
                }

                actions.append(.action(ContextMenuActionItem(text: chatPresentationInterfaceState.strings.Conversation_ContextMenuSelectAll(Int32(messages.count)), icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/SelectAll"), color: theme.actionSheet.primaryTextColor)
                }, action: { _, f in
                    interfaceInteraction.beginMessageSelection(messages.map { $0.id }, { transition in
                        f(.custom(transition))
                    })
                })))
            }
        }
        
        let canViewStats = canViewReadStats(message: message, participantCount: infoSummaryData.participantCount, isMessageRead: isMessageRead, appConfig: appConfig)
        var reactionCount = 0
        for reaction in mergedMessageReactionsAndPeers(accountPeer: nil, message: message).reactions {
            reactionCount += Int(reaction.count)
        }
        if let reactionsAttribute = message.reactionsAttribute {
            if !reactionsAttribute.canViewList {
                reactionCount = 0
            }
        }

        if let peer = message.peers[message.id.peerId], (canViewStats || reactionCount != 0) {
            var hasReadReports = false
            if let channel = peer as? TelegramChannel {
                if case .group = channel.info {
                    if canViewStats {
                        hasReadReports = true
                    }
                } else {
                    reactionCount = 0
                }
            } else if let _ = peer as? TelegramGroup {
                if canViewStats {
                    hasReadReports = true
                }
            } else {
                reactionCount = 0
            }
            
            /*var readStats = readStats
            if !canViewStats {
                readStats = MessageReadStats(reactionCount: 0, peers: [])
            }*/

            if hasReadReports || reactionCount != 0 {
                if !actions.isEmpty {
                    actions.insert(.separator, at: 0)
                }

                actions.insert(.custom(ChatReadReportContextItem(context: context, message: message, hasReadReports: hasReadReports, stats: readStats, action: { c, f, stats, customReactionEmojiPacks, firstCustomEmojiReaction in
                    if reactionCount == 0, let stats = stats, stats.peers.count == 1 {
                        c.dismiss(completion: {
                            controllerInteraction.openPeer(stats.peers[0], .default, nil, false)
                        })
                    } else if (stats != nil && !stats!.peers.isEmpty) || reactionCount != 0 {
                        var tip: ContextController.Tip?
                        
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
                        
                        if !premiumConfiguration.isPremiumDisabled {
                            if customReactionEmojiPacks.count == 1, let firstCustomEmojiReaction = firstCustomEmojiReaction {
                                tip = .animatedEmoji(
                                    text: presentationData.strings.ChatContextMenu_ReactionEmojiSetSingle(customReactionEmojiPacks[0].title).string,
                                    arguments: TextNodeWithEntities.Arguments(
                                        context: context,
                                        cache: controllerInteraction.presentationContext.animationCache,
                                        renderer: controllerInteraction.presentationContext.animationRenderer,
                                        placeholderColor: .clear,
                                        attemptSynchronous: true
                                    ),
                                    file: firstCustomEmojiReaction,
                                    action: {
                                        (interfaceInteraction.chatController() as? ChatControllerImpl)?.presentEmojiList(references: customReactionEmojiPacks.map { pack -> StickerPackReference in .id(id: pack.id.id, accessHash: pack.accessHash) })
                                    }
                                )
                            } else if customReactionEmojiPacks.count > 1 {
                                tip = .animatedEmoji(text: presentationData.strings.ChatContextMenu_ReactionEmojiSet(Int32(customReactionEmojiPacks.count)), arguments: nil, file: nil, action: {
                                    (interfaceInteraction.chatController() as? ChatControllerImpl)?.presentEmojiList(references: customReactionEmojiPacks.map { pack -> StickerPackReference in .id(id: pack.id.id, accessHash: pack.accessHash) })
                                })
                            }
                        }
                        
                        c.pushItems(items: .single(ContextController.Items(content: .custom(ReactionListContextMenuContent(
                            context: context,
                            availableReactions: availableReactions,
                            animationCache: controllerInteraction.presentationContext.animationCache,
                            animationRenderer: controllerInteraction.presentationContext.animationRenderer,
                            message: EngineMessage(message),
                            reaction: nil,
                            readStats: stats,
                            back: { [weak c] in
                                c?.popItems()
                            },
                            openPeer: { [weak c] peer in
                                c?.dismiss(completion: {
                                    controllerInteraction.openPeer(peer, .default, MessageReference(message), true)
                                })
                            }
                        )), tip: tip)))
                    } else {
                        f(.default)
                    }
                }), false), at: 0)
            }
        }
        
        if !actions.isEmpty, case .separator = actions[0] {
            actions.removeFirst()
        }
        
        return ContextController.Items(content: .list(actions), tip: nil)
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

func chatAvailableMessageActionsImpl(engine: TelegramEngine, accountPeerId: PeerId, messageIds: Set<MessageId>, messages: [MessageId: Message] = [:], peers: [PeerId: Peer] = [:]) -> Signal<ChatAvailableMessageActions, NoError> {
    return engine.data.get(
        TelegramEngine.EngineData.Item.Configuration.Limits(),
        EngineDataMap(Set(messageIds.map(\.peerId)).map(TelegramEngine.EngineData.Item.Peer.Peer.init)),
        EngineDataMap(Set(messageIds).map(TelegramEngine.EngineData.Item.Messages.Message.init))
    )
    |> map { limitsConfiguration, peerMap, messageMap -> ChatAvailableMessageActions in
        var optionsMap: [MessageId: ChatAvailableMessageActionOptions] = [:]
        var banPeer: Peer?
        var hadPersonalIncoming = false
        var hadBanPeerId = false
        var disableDelete = false
        var isCopyProtected = false
        var isShareProtected = false
        
        func getPeer(_ peerId: PeerId) -> Peer? {
            if let maybePeer = peerMap[peerId], let peer = maybePeer {
                return peer._asPeer()
            } else if let peer = peers[peerId] {
                return peer
            } else {
                return nil
            }
        }
        
        func getMessage(_ messageId: MessageId) -> Message? {
            if let maybeMessage = messageMap[messageId], let message = maybeMessage {
                return message._asMessage()
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
                if message.isCopyProtected() || message.containsSecretMedia {
                    isCopyProtected = true
                }
                for media in message.media {
                    if let invoice = media as? TelegramMediaInvoice, let _ = invoice.extendedMedia {
                        isShareProtected = true
                    } else if let file = media as? TelegramMediaFile, file.isSticker {
                        for case let .Sticker(_, packReference, _) in file.attributes {
                            if let _ = packReference {
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
                                } else if message.author is TelegramChannel {
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
                            if message.id.peerId.namespace != Namespaces.Peer.SecretChat && !message.isCopyProtected() {
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
                            if !isAction && !message.isCopyProtected() {
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
                        if !isScheduled && message.id.peerId.namespace != Namespaces.Peer.SecretChat && !message.containsSecretMedia && !isAction && !message.id.peerId.isReplies && !message.isCopyProtected() {
                            if !(message.flags.isSending || message.flags.contains(.Failed)) {
                                optionsMap[id]!.insert(.forward)
                            }
                        }
                        optionsMap[id]!.insert(.deleteLocally)
                        var canDeleteGlobally = false
                        if canPerformDeleteActions(limits: limitsConfiguration._asLimits(), accountPeerId: accountPeerId, message: message) {
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
                        for media in message.media {
                            if let action = media as? TelegramMediaAction {
                                if case .historyScreenshot = action.action {
                                    optionsMap[id]!.remove(.deleteLocally)
                                    optionsMap[id]!.remove(.deleteGlobally)
                                    disableDelete = true
                                }
                            }
                        }
                        if user.botInfo != nil && message.flags.contains(.Incoming) && !user.id.isReplies && !isAction {
                            optionsMap[id]!.insert(.report)
                        }
                    } else if let _ = peer as? TelegramSecretChat {
                        var isNonRemovableServiceAction = false
                        for media in message.media {
                            if let action = media as? TelegramMediaAction {
                                switch action.action {
                                    case .historyScreenshot:
                                        isNonRemovableServiceAction = true
                                        disableDelete = true
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
            
            if !isShareProtected {
                optionsMap[id]!.insert(.externalShare)
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
            return ChatAvailableMessageActions(options: reducedOptions, banAuthor: banPeer, disableDelete: disableDelete, isCopyProtected: isCopyProtected)
        } else {
            return ChatAvailableMessageActions(options: [], banAuthor: nil, disableDelete: false, isCopyProtected: isCopyProtected)
        }
    }
}

final class ChatDeleteMessageContextItem: ContextMenuCustomItem {
    fileprivate let timestamp: Double
    fileprivate let action: (ContextControllerProtocol, @escaping (ContextMenuActionResult) -> Void) -> Void
    
    init(timestamp: Double, action: @escaping (ContextControllerProtocol, @escaping (ContextMenuActionResult) -> Void) -> Void) {
        self.timestamp = timestamp
        self.action = action
    }
    
    func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return ChatDeleteMessageContextItemNode(presentationData: presentationData, item: self, getController: getController, actionSelected: actionSelected)
    }
}

private let textFont = Font.regular(17.0)

private final class ChatDeleteMessageContextItemNode: ASDisplayNode, ContextMenuCustomNode, ContextActionNodeProtocol {
    private let item: ChatDeleteMessageContextItem
    private let presentationData: PresentationData
    private let getController: () -> ContextControllerProtocol?
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

    var isActionEnabled: Bool {
        return true
    }

    init(presentationData: PresentationData, item: ChatDeleteMessageContextItem, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) {
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
        let statusSize = self.statusNode.updateLayout(CGSize(width: size.width - sideInset - 32.0 + 4.0, height: .greatestFiniteMagnitude))
        transition.updateFrameAdditive(node: self.statusNode, frame: CGRect(origin: CGPoint(x: self.statusNode.frame.minX, y: self.statusNode.frame.minY), size: statusSize))
    }
    
    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
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
        let statusSize = self.statusNode.updateLayout(CGSize(width: constrainedWidth - sideInset - rightTextInset - textIconSize.width + 2.0, height: .greatestFiniteMagnitude))
        
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
    
    func canBeHighlighted() -> Bool {
        return self.isActionEnabled
    }
    
    func updateIsHighlighted(isHighlighted: Bool) {
        self.setIsHighlighted(isHighlighted)
    }
    
    func actionNode(at point: CGPoint) -> ContextActionNodeProtocol {
        return self
    }
}

final class ChatReadReportContextItem: ContextMenuCustomItem {
    fileprivate let context: AccountContext
    fileprivate let message: Message
    fileprivate let hasReadReports: Bool
    fileprivate let stats: MessageReadStats?
    fileprivate let action: (ContextControllerProtocol, @escaping (ContextMenuActionResult) -> Void, MessageReadStats?, [StickerPackCollectionInfo], TelegramMediaFile?) -> Void

    init(context: AccountContext, message: Message, hasReadReports: Bool, stats: MessageReadStats?, action: @escaping (ContextControllerProtocol, @escaping (ContextMenuActionResult) -> Void, MessageReadStats?, [StickerPackCollectionInfo], TelegramMediaFile?) -> Void) {
        self.context = context
        self.message = message
        self.hasReadReports = hasReadReports
        self.stats = stats
        self.action = action
    }

    func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return ChatReadReportContextItemNode(presentationData: presentationData, item: self, getController: getController, actionSelected: actionSelected)
    }
}

private final class ChatReadReportContextItemNode: ASDisplayNode, ContextMenuCustomNode, ContextActionNodeProtocol {
    private let item: ChatReadReportContextItem
    private var presentationData: PresentationData
    private let getController: () -> ContextControllerProtocol?
    private let actionSelected: (ContextMenuActionResult) -> Void

    private let backgroundNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let placeholderCalculationTextNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let shimmerNode: ShimmerEffectNode
    private let iconNode: ASImageNode

    private let avatarsNode: AnimatedAvatarSetNode
    private let avatarsContext: AnimatedAvatarSetContext

    private let placeholderAvatarsNode: AnimatedAvatarSetNode
    private let placeholderAvatarsContext: AnimatedAvatarSetContext

    private let buttonNode: HighlightTrackingButtonNode

    private var pointerInteraction: PointerInteraction?

    private var disposable: Disposable?
    private var currentStats: MessageReadStats?
    
    private var customEmojiPacksDisposable: Disposable?
    private var customEmojiPacks: [StickerPackCollectionInfo] = []
    private var firstCustomEmojiReaction: TelegramMediaFile?

    init(presentationData: PresentationData, item: ChatReadReportContextItem, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) {
        self.item = item
        self.presentationData = presentationData
        self.getController = getController
        self.actionSelected = actionSelected
        self.currentStats = item.stats

        let textFont = Font.regular(presentationData.listsFontSize.baseDisplaySize)

        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isAccessibilityElement = false
        self.backgroundNode.backgroundColor = presentationData.theme.contextMenu.itemBackgroundColor
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isAccessibilityElement = false
        self.highlightedBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor
        self.highlightedBackgroundNode.alpha = 0.0

        self.placeholderCalculationTextNode = ImmediateTextNode()
        self.placeholderCalculationTextNode.attributedText = NSAttributedString(string: presentationData.strings.Conversation_ContextMenuSeen(11), font: textFont, textColor: presentationData.theme.contextMenu.primaryColor)
        self.placeholderCalculationTextNode.maximumNumberOfLines = 1

        self.textNode = ImmediateTextNode()
        self.textNode.isAccessibilityElement = false
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        self.textNode.attributedText = NSAttributedString(string: " ", font: textFont, textColor: presentationData.theme.contextMenu.primaryColor)
        self.textNode.maximumNumberOfLines = 1
        self.textNode.alpha = 0.0

        self.shimmerNode = ShimmerEffectNode()
        self.shimmerNode.clipsToBounds = true

        self.buttonNode = HighlightTrackingButtonNode()
        self.buttonNode.isAccessibilityElement = true
        self.buttonNode.accessibilityLabel = presentationData.strings.VoiceChat_StopRecording

        self.iconNode = ASImageNode()
        if let reactionsAttribute = item.message.reactionsAttribute, !reactionsAttribute.reactions.isEmpty {
            self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Reactions"), color: presentationData.theme.actionSheet.primaryTextColor)
        } else {
            self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Read"), color: presentationData.theme.actionSheet.primaryTextColor)
        }

        self.avatarsNode = AnimatedAvatarSetNode()
        self.avatarsContext = AnimatedAvatarSetContext()

        self.placeholderAvatarsNode = AnimatedAvatarSetNode()
        self.placeholderAvatarsContext = AnimatedAvatarSetContext()

        super.init()

        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.shimmerNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.avatarsNode)
        self.addSubnode(self.placeholderAvatarsNode)
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
        
        var reactionCount = 0
        var customEmojiFiles = Set<Int64>()
        for reaction in mergedMessageReactionsAndPeers(accountPeer: nil, message: self.item.message).reactions {
            reactionCount += Int(reaction.count)
            
            if case let .custom(fileId) = reaction.value {
                customEmojiFiles.insert(fileId)
            }
        }
        
        if !customEmojiFiles.isEmpty {
            self.customEmojiPacksDisposable = (item.context.engine.stickers.resolveInlineStickers(fileIds: Array(customEmojiFiles))
            |> mapToSignal { customEmoji -> Signal<([StickerPackCollectionInfo], TelegramMediaFile?), NoError> in
                var stickerPackSignals: [Signal<StickerPackCollectionInfo?, NoError>] = []
                var existingIds = Set<Int64>()
                var firstCustomEmojiReaction: TelegramMediaFile?
                for (_, file) in customEmoji {
                    loop: for attribute in file.attributes {
                        if case let .CustomEmoji(_, _, packReference) = attribute, let packReference = packReference {
                            if case let .id(id, _) = packReference, !existingIds.contains(id) {
                                if firstCustomEmojiReaction == nil {
                                    firstCustomEmojiReaction = file
                                }
                                
                                existingIds.insert(id)
                                stickerPackSignals.append(item.context.engine.stickers.loadedStickerPack(reference: packReference, forceActualized: false)
                                |> filter { result in
                                    if case .result = result {
                                        return true
                                    } else {
                                        return false
                                    }
                                }
                                |> map { result -> StickerPackCollectionInfo? in
                                    if case let .result(info, _, _) = result {
                                        return info
                                    } else {
                                        return nil
                                    }
                                })
                            }
                            break loop
                        }
                    }
                }
                return combineLatest(stickerPackSignals)
                |> map { stickerPacks -> ([StickerPackCollectionInfo], TelegramMediaFile?) in
                    return (stickerPacks.compactMap { $0 }, firstCustomEmojiReaction)
                }
            }
            |> deliverOnMainQueue).start(next: { [weak self] customEmojiPacks, firstCustomEmojiReaction in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.customEmojiPacks = customEmojiPacks
                strongSelf.firstCustomEmojiReaction = firstCustomEmojiReaction
            })
        }

        if let currentStats = self.currentStats {
            self.buttonNode.isUserInteractionEnabled = !currentStats.peers.isEmpty || reactionCount != 0
        } else {
            self.buttonNode.isUserInteractionEnabled = reactionCount != 0

            self.disposable = (item.context.engine.messages.messageReadStats(id: item.message.id)
            |> deliverOnMainQueue).start(next: { [weak self] value in
                guard let strongSelf = self else {
                    return
                }
                if let value = value {
                    strongSelf.updateStats(stats: value, transition: .animated(duration: 0.2, curve: .easeInOut))
                }
            })
        }
        
        item.context.account.viewTracker.updateReactionsForMessageIds(messageIds: [item.message.id], force: true)
    }

    deinit {
        self.disposable?.dispose()
        self.customEmojiPacksDisposable?.dispose()
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
    }

    private var validLayout: (calculatedWidth: CGFloat, size: CGSize)?

    func updateStats(stats: MessageReadStats, transition: ContainedViewLayoutTransition) {
        self.buttonNode.isUserInteractionEnabled = !stats.peers.isEmpty || stats.reactionCount != 0

        guard let (calculatedWidth, size) = self.validLayout else {
            return
        }

        self.currentStats = stats

        let (_, apply) = self.updateLayout(constrainedWidth: calculatedWidth, constrainedHeight: size.height)
        apply(size, transition)
    }

    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let sideInset: CGFloat = 14.0
        let verticalInset: CGFloat = 12.0

        let iconSize: CGSize = self.iconNode.image?.size ?? CGSize(width: 10.0, height: 10.0)

        let rightTextInset: CGFloat = sideInset + 36.0

        let calculatedWidth = min(constrainedWidth, 250.0)

        let textFont = Font.regular(self.presentationData.listsFontSize.baseDisplaySize)
        
        var reactionCount = 0
        for reaction in mergedMessageReactionsAndPeers(accountPeer: nil, message: self.item.message).reactions {
            reactionCount += Int(reaction.count)
        }

        if let currentStats = self.currentStats {
            reactionCount = currentStats.reactionCount
            
            if currentStats.peers.isEmpty {
                if reactionCount != 0 {
                    let text: String = self.presentationData.strings.Chat_ContextReactionCount(Int32(reactionCount))
                    self.textNode.attributedText = NSAttributedString(string: text, font: textFont, textColor: self.presentationData.theme.contextMenu.primaryColor)
                } else {
                    var text = self.presentationData.strings.Conversation_ContextMenuNoViews
                    for media in self.item.message.media {
                        if let file = media as? TelegramMediaFile {
                            if file.isVoice {
                                text = self.presentationData.strings.Conversation_ContextMenuNobodyListened
                            } else if file.isInstantVideo {
                                text = self.presentationData.strings.Conversation_ContextMenuNobodyWatched
                            }
                        }
                    }

                    self.textNode.attributedText = NSAttributedString(string: text, font: textFont, textColor: self.presentationData.theme.contextMenu.secondaryColor)
                }
            } else if currentStats.peers.count == 1 {
                if reactionCount != 0 {
                    let text: String = self.presentationData.strings.Chat_OutgoingContextReactionCount(Int32(reactionCount))
                    self.textNode.attributedText = NSAttributedString(string: text, font: textFont, textColor: self.presentationData.theme.contextMenu.primaryColor)
                } else {
                    self.textNode.attributedText = NSAttributedString(string: currentStats.peers[0].displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder), font: textFont, textColor: self.presentationData.theme.contextMenu.primaryColor)
                }
            } else {
                if reactionCount != 0 {
                    let text: String
                    if reactionCount >= currentStats.peers.count {
                        text = self.presentationData.strings.Chat_OutgoingContextReactionCount(Int32(reactionCount))
                    } else {
                        text = self.presentationData.strings.Chat_OutgoingContextMixedReactionCount("\(reactionCount)", "\(currentStats.peers.count)").string
                    }
                    self.textNode.attributedText = NSAttributedString(string: text, font: textFont, textColor: self.presentationData.theme.contextMenu.primaryColor)
                } else {
                    var text = self.presentationData.strings.Conversation_ContextMenuSeen(Int32(currentStats.peers.count))
                    for media in self.item.message.media {
                        if let file = media as? TelegramMediaFile {
                            if file.isVoice {
                                text = self.presentationData.strings.Conversation_ContextMenuListened(Int32(currentStats.peers.count))
                            } else if file.isInstantVideo {
                                text = self.presentationData.strings.Conversation_ContextMenuWatched(Int32(currentStats.peers.count))
                            }
                        }
                    }

                    self.textNode.attributedText = NSAttributedString(string: text, font: textFont, textColor: self.presentationData.theme.contextMenu.primaryColor)
                }
            }
        } else {
            self.textNode.attributedText = NSAttributedString(string: " ", font: textFont, textColor: self.presentationData.theme.contextMenu.primaryColor)
        }

        let textSize = self.textNode.updateLayout(CGSize(width: calculatedWidth - sideInset - rightTextInset - iconSize.width - 4.0, height: .greatestFiniteMagnitude))

        let placeholderTextSize = self.placeholderCalculationTextNode.updateLayout(CGSize(width: calculatedWidth - sideInset - rightTextInset - iconSize.width - 4.0, height: .greatestFiniteMagnitude))

        let combinedTextHeight = textSize.height
        return (CGSize(width: calculatedWidth, height: verticalInset * 2.0 + combinedTextHeight), { size, transition in
            self.validLayout = (calculatedWidth: calculatedWidth, size: size)
            let verticalOrigin = floor((size.height - combinedTextHeight) / 2.0)
            let textFrame = CGRect(origin: CGPoint(x: sideInset + iconSize.width + 4.0, y: verticalOrigin), size: textSize)
            transition.updateFrameAdditive(node: self.textNode, frame: textFrame)
            transition.updateAlpha(node: self.textNode, alpha: self.currentStats == nil ? 0.0 : 1.0)

            let shimmerHeight: CGFloat = 8.0

            self.shimmerNode.frame = CGRect(origin: CGPoint(x: textFrame.minX, y: floor((size.height - shimmerHeight) / 2.0)), size: CGSize(width: placeholderTextSize.width, height: shimmerHeight))
            self.shimmerNode.cornerRadius = shimmerHeight / 2.0
            let shimmeringForegroundColor: UIColor
            let shimmeringColor: UIColor
            if self.presentationData.theme.overallDarkAppearance {
                let backgroundColor = self.presentationData.theme.contextMenu.backgroundColor.blitOver(self.presentationData.theme.list.plainBackgroundColor, alpha: 1.0)

                shimmeringForegroundColor = self.presentationData.theme.contextMenu.primaryColor.blitOver(backgroundColor, alpha: 0.1)
                shimmeringColor = self.presentationData.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.3)
            } else {
                let backgroundColor = self.presentationData.theme.contextMenu.backgroundColor.blitOver(self.presentationData.theme.list.plainBackgroundColor, alpha: 1.0)

                shimmeringForegroundColor = self.presentationData.theme.contextMenu.primaryColor.blitOver(backgroundColor, alpha: 0.15)
                shimmeringColor = self.presentationData.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.3)
            }
            self.shimmerNode.update(backgroundColor: self.presentationData.theme.list.plainBackgroundColor, foregroundColor: shimmeringForegroundColor, shimmeringColor: shimmeringColor, shapes: [.rect(rect: self.shimmerNode.bounds)], horizontal: true, size: self.shimmerNode.bounds.size)
            self.shimmerNode.updateAbsoluteRect(self.shimmerNode.frame, within: size)
            transition.updateAlpha(node: self.shimmerNode, alpha: self.currentStats == nil ? 1.0 : 0.0)

            if !iconSize.width.isZero {
                transition.updateFrameAdditive(node: self.iconNode, frame: CGRect(origin: CGPoint(x: sideInset + 1.0, y: floor((size.height - iconSize.height) / 2.0)), size: iconSize))
            }

            let avatarsContent: AnimatedAvatarSetContext.Content
            let placeholderAvatarsContent: AnimatedAvatarSetContext.Content

            var avatarsPeers: [EnginePeer] = []
            if let recentPeers = self.item.message.reactionsAttribute?.recentPeers, !recentPeers.isEmpty {
                for recentPeer in recentPeers {
                    if let peer = self.item.message.peers[recentPeer.peerId] {
                        if !avatarsPeers.contains(where: { $0.id == peer.id }) {
                            avatarsPeers.append(EnginePeer(peer))
                            if avatarsPeers.count == 3 {
                                break
                            }
                        }
                    }
                }
            } else if let peers = self.currentStats?.peers {
                for i in 0 ..< min(3, peers.count) {
                    if !avatarsPeers.contains(where: { $0.id == peers[i].id }) {
                        avatarsPeers.append(peers[i])
                    }
                }
            }
            avatarsContent = self.avatarsContext.update(peers: avatarsPeers, animated: false)
            placeholderAvatarsContent = self.avatarsContext.updatePlaceholder(color: shimmeringForegroundColor, count: 3, animated: false)

            let avatarsSize = self.avatarsNode.update(context: self.item.context, content: avatarsContent, itemSize: CGSize(width: 24.0, height: 24.0), customSpacing: 10.0, animated: false, synchronousLoad: true)
            self.avatarsNode.frame = CGRect(origin: CGPoint(x: size.width - sideInset - 12.0 - avatarsSize.width, y: floor((size.height - avatarsSize.height) / 2.0)), size: avatarsSize)
            transition.updateAlpha(node: self.avatarsNode, alpha: self.currentStats == nil ? 0.0 : 1.0)

            let placeholderAvatarsSize = self.placeholderAvatarsNode.update(context: self.item.context, content: placeholderAvatarsContent, itemSize: CGSize(width: 24.0, height: 24.0), customSpacing: 10.0, animated: false, synchronousLoad: true)
            self.placeholderAvatarsNode.frame = CGRect(origin: CGPoint(x: size.width - sideInset - 8.0 - placeholderAvatarsSize.width, y: floor((size.height - placeholderAvatarsSize.height) / 2.0)), size: placeholderAvatarsSize)
            transition.updateAlpha(node: self.placeholderAvatarsNode, alpha: self.currentStats == nil ? 1.0 : 0.0)

            transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
            transition.updateFrame(node: self.highlightedBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
            transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
        })
    }

    func updateTheme(presentationData: PresentationData) {
        self.presentationData = presentationData

        self.backgroundNode.backgroundColor = presentationData.theme.contextMenu.itemBackgroundColor
        self.highlightedBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor

        let textFont = Font.regular(presentationData.listsFontSize.baseDisplaySize)

        self.textNode.attributedText = NSAttributedString(string: self.textNode.attributedText?.string ?? "", font: textFont, textColor: presentationData.theme.contextMenu.primaryColor)
    }

    @objc private func buttonPressed() {
        self.performAction()
    }

    private var actionTemporarilyDisabled: Bool = false
    
    func canBeHighlighted() -> Bool {
        return self.isActionEnabled
    }
    
    func updateIsHighlighted(isHighlighted: Bool) {
        self.setIsHighlighted(isHighlighted)
    }

    func performAction() {
        if self.actionTemporarilyDisabled {
            return
        }
        self.actionTemporarilyDisabled = true
        Queue.mainQueue().async { [weak self] in
            self?.actionTemporarilyDisabled = false
        }

        guard let controller = self.getController() else {
            return
        }
        self.item.action(controller, { [weak self] result in
            self?.actionSelected(result)
        }, self.currentStats, self.customEmojiPacks, self.firstCustomEmojiReaction)
    }

    var isActionEnabled: Bool {
        var reactionCount = 0
        for reaction in mergedMessageReactionsAndPeers(accountPeer: nil, message: self.item.message).reactions {
            reactionCount += Int(reaction.count)
        }
        if reactionCount >= 0 {
            return true
        }
        guard let currentStats = self.currentStats else {
            return false
        }
        return !currentStats.peers.isEmpty
    }

    func setIsHighlighted(_ value: Bool) {
        if value {
            self.highlightedBackgroundNode.alpha = 1.0
        } else {
            self.highlightedBackgroundNode.alpha = 0.0
        }
    }
    
    func actionNode(at point: CGPoint) -> ContextActionNodeProtocol {
        return self
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
    return strings.Conversation_AutoremoveRemainingTime(durationString).string
}

final class ChatRateTranscriptionContextItem: ContextMenuCustomItem {
    fileprivate let context: AccountContext
    fileprivate let message: Message
    fileprivate let action: (Bool) -> Void

    init(context: AccountContext, message: Message, action: @escaping (Bool) -> Void) {
        self.context = context
        self.message = message
        self.action = action
    }

    func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return ChatRateTranscriptionContextItemNode(presentationData: presentationData, item: self, getController: getController, actionSelected: actionSelected, action: self.action)
    }
}

private final class ChatRateTranscriptionContextItemNode: ASDisplayNode, ContextMenuCustomNode, ContextActionNodeProtocol {
    private let item: ChatRateTranscriptionContextItem
    private var presentationData: PresentationData
    private let getController: () -> ContextControllerProtocol?
    private let actionSelected: (ContextMenuActionResult) -> Void
    private let action: (Bool) -> Void

    private let backgroundNode: ASDisplayNode
    private let textNode: ImmediateTextNode
    
    private let upButtonImageNode: ASImageNode
    private let downButtonImageNode: ASImageNode
    private let upButtonNode: HighlightableButtonNode
    private let downButtonNode: HighlightableButtonNode

    init(presentationData: PresentationData, item: ChatRateTranscriptionContextItem, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void, action: @escaping (Bool) -> Void) {
        self.item = item
        self.presentationData = presentationData
        self.getController = getController
        self.actionSelected = actionSelected
        self.action = action

        let textFont = Font.regular(presentationData.listsFontSize.baseDisplaySize * 15.0 / 17.0)

        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isAccessibilityElement = false
        self.backgroundNode.backgroundColor = presentationData.theme.contextMenu.itemBackgroundColor

        self.textNode = ImmediateTextNode()
        self.textNode.isAccessibilityElement = false
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        self.textNode.attributedText = NSAttributedString(string: self.presentationData.strings.Chat_AudioTranscriptionRateAction, font: textFont, textColor: presentationData.theme.contextMenu.secondaryColor)
        self.textNode.maximumNumberOfLines = 1
        
        self.upButtonImageNode = ASImageNode()
        self.upButtonImageNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ThumbsUp"), color: presentationData.theme.contextMenu.primaryColor, backgroundColor: nil)
        self.upButtonImageNode.isUserInteractionEnabled = false
        
        self.downButtonImageNode = ASImageNode()
        self.downButtonImageNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ThumbsDown"), color: presentationData.theme.contextMenu.primaryColor, backgroundColor: nil)
        self.downButtonImageNode.isUserInteractionEnabled = false
        
        self.upButtonNode = HighlightableButtonNode()
        self.upButtonNode.addSubnode(self.upButtonImageNode)
        
        self.downButtonNode = HighlightableButtonNode()
        self.downButtonNode.addSubnode(self.downButtonImageNode)

        super.init()

        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.textNode)
        
        self.addSubnode(self.upButtonNode)
        self.addSubnode(self.downButtonNode)
        
        self.upButtonNode.addTarget(self, action: #selector(self.upPressed), forControlEvents: .touchUpInside)
        self.downButtonNode.addTarget(self, action: #selector(self.downPressed), forControlEvents: .touchUpInside)
    }

    deinit {
    }

    override func didLoad() {
        super.didLoad()
    }
    
    @objc private func upPressed() {
        self.action(true)
        self.getController()?.dismiss(completion: nil)
    }
    
    @objc private func downPressed() {
        self.action(false)
        self.getController()?.dismiss(completion: nil)
    }

    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let sideInset: CGFloat = 14.0
        let verticalInset: CGFloat = 9.0

        let calculatedWidth = min(constrainedWidth, 250.0)

        let textSize = self.textNode.updateLayout(CGSize(width: calculatedWidth - sideInset, height: .greatestFiniteMagnitude))

        let combinedTextHeight = textSize.height
        return (CGSize(width: calculatedWidth, height: verticalInset * 2.0 + combinedTextHeight + 35.0), { size, transition in
            let verticalOrigin = verticalInset
            let textFrame = CGRect(origin: CGPoint(x: floor((size.width - textSize.width) / 2.0), y: verticalOrigin), size: textSize)
            transition.updateFrameAdditive(node: self.textNode, frame: textFrame)
            
            let buttonArea = CGRect(origin: CGPoint(x: 0.0, y: size.height - 35.0 - 6.0), size: CGSize(width: size.width, height: 35.0))
            
            self.upButtonNode.frame = CGRect(origin: CGPoint(x: buttonArea.minX, y: buttonArea.minY), size: CGSize(width: floor(buttonArea.size.width / 2.0), height: buttonArea.height))
            self.downButtonNode.frame = CGRect(origin: CGPoint(x: buttonArea.minX + floor(buttonArea.size.width / 2.0), y: buttonArea.minY), size: CGSize(width: floor(buttonArea.size.width / 2.0), height: buttonArea.height))
            
            let spacing: CGFloat = 56.0
            
            if let image = self.upButtonImageNode.image {
                self.upButtonImageNode.frame = CGRect(origin: CGPoint(x: floor(buttonArea.width / 2.0) - floor(spacing / 2.0) - image.size.width, y: floor((buttonArea.height - image.size.height) / 2.0)), size: image.size)
            }
            if let image = self.downButtonImageNode.image {
                self.downButtonImageNode.frame = CGRect(origin: CGPoint(x: floor(spacing / 2.0), y: floor((buttonArea.height - image.size.height) / 2.0)), size: image.size)
            }

            transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
        })
    }

    func updateTheme(presentationData: PresentationData) {
        self.presentationData = presentationData

        self.backgroundNode.backgroundColor = presentationData.theme.contextMenu.itemBackgroundColor

        let textFont = Font.regular(presentationData.listsFontSize.baseDisplaySize)

        self.textNode.attributedText = NSAttributedString(string: self.textNode.attributedText?.string ?? "", font: textFont, textColor: presentationData.theme.contextMenu.primaryColor)
    }
    
    func canBeHighlighted() -> Bool {
        return self.isActionEnabled
    }
    
    func updateIsHighlighted(isHighlighted: Bool) {
        self.setIsHighlighted(isHighlighted)
    }

    func performAction() {
    }

    var isActionEnabled: Bool {
        return false
    }

    func setIsHighlighted(_ value: Bool) {
    }
    
    func actionNode(at point: CGPoint) -> ContextActionNodeProtocol {
        return self
    }
}

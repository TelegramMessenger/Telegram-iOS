import Foundation
import UIKit
import Postbox
import TelegramCore
import Display
import UIKit
import SwiftSignalKit
import MobileCoreServices
import TelegramVoip

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
    var hasEditRights = false
    var unlimitedInterval = false
    
    
    if message.id.peerId.namespace == Namespaces.Peer.SecretChat || message.id.namespace != Namespaces.Message.Cloud {
        hasEditRights = false
    } else if let author = message.author, author.id == context.account.peerId {
        hasEditRights = true
    } else if message.author?.id == message.id.peerId, let peer = message.peers[message.id.peerId] {
        if let peer = peer as? TelegramChannel {
            switch peer.info {
            case .broadcast:
                if peer.hasPermission(.editAllMessages) {
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
    
    if let peer = message.peers[message.id.peerId] as? TelegramChannel {
        if !peer.hasPermission(.sendMessages) {
            //hasUneditableAttributes = true
        }
    }
    
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
        
        if !hasUneditableAttributes {
            if canPerformEditingActions(limits: limitsConfiguration, accountPeerId: context.account.peerId, message: message, unlimitedInterval: unlimitedInterval) {
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

func contextMenuForChatPresentationIntefaceState(chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, messages: [Message], controllerInteraction: ChatControllerInteraction?, selectAll: Bool, interfaceInteraction: ChatPanelInterfaceInteraction?) -> Signal<[ChatMessageContextMenuAction], NoError> {
    guard let interfaceInteraction = interfaceInteraction, let controllerInteraction = controllerInteraction else {
        return .single([])
    }
    
    let dataSignal: Signal<MessageContextMenuData, NoError>
    
    var loadStickerSaveStatus: MediaId?
    var loadCopyMediaResource: MediaResource?
    var isAction = false
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
            }
        }
    }
    
    var canReply = canReplyInChat(chatPresentationInterfaceState)
    var canPin = false
    let canSelect = !isAction
    
    var canDeleteMessage: Bool = false
    
    let message = messages[0]
    if let channel = message.peers[message.id.peerId] as? TelegramChannel {
        if case .broadcast = channel.info {
            if !message.flags.contains(.Incoming) {
                canDeleteMessage = channel.hasPermission(.sendMessages)
            }
            if channel.hasPermission(.deleteAllMessages) {
                canDeleteMessage = true
            }
        } else {
            if channel.hasPermission(.deleteAllMessages) || !message.flags.contains(.Incoming) {
                canDeleteMessage = true
            }
        }
    } else if message.peers[message.id.peerId] is TelegramSecretChat {
        canDeleteMessage = true
    } else {
        canDeleteMessage = context.account.peerId == message.author?.id
    }
    
    if messages[0].flags.intersection([.Failed, .Unsent]).isEmpty {
        switch chatPresentationInterfaceState.chatLocation {
            case .peer:
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
    
    dataSignal = combineLatest(loadLimits, loadStickerSaveStatusSignal, loadResourceStatusSignal, chatAvailableMessageActions(postbox: context.account.postbox, accountPeerId: context.account.peerId, messageIds: Set(messages.map { $0.id })))
    |> map { limitsConfiguration, stickerSaveStatus, resourceStatus, messageActions -> MessageContextMenuData in
        var canEdit = false
        if !isAction {
            let message = messages[0]
            canEdit = canEditMessage(context: context, limitsConfiguration: limitsConfiguration, message: message)
        }
        
        return MessageContextMenuData(starStatus: stickerSaveStatus, canReply: canReply, canPin: canPin, canEdit: canEdit, canSelect: canSelect, resourceStatus: resourceStatus, messageActions: messageActions)
    }
    
    return dataSignal |> deliverOnMainQueue |> map { data -> [ChatMessageContextMenuAction] in
        var actions: [ChatMessageContextMenuAction] = []
        
        if let starStatus = data.starStatus, let image = starStatus ? starIconFilled : starIconEmpty {
            actions.append(.context(ContextMenuAction(content: .icon(image), action: {
                interfaceInteraction.toggleMessageStickerStarred(messages[0].id)
            })))
        }
        
        if data.canReply {
            actions.append(.context(ContextMenuAction(content: .text(title: chatPresentationInterfaceState.strings.Conversation_ContextMenuReply, accessibilityLabel: chatPresentationInterfaceState.strings.Conversation_ContextMenuReply), action: {
                interfaceInteraction.setupReplyMessage(messages[0].id)
            })))
        }
        
        if data.canEdit {
            actions.append(.sheet(ChatMessageContextMenuSheetAction(color: .accent, title: chatPresentationInterfaceState.strings.Conversation_Edit, action: {
                interfaceInteraction.setupEditMessage(messages[0].id)
            })))
        }
        
        let resourceAvailable: Bool
        if let resourceStatus = data.resourceStatus, case .Local = resourceStatus {
            resourceAvailable = true
        } else {
            resourceAvailable = false
        }
        
        if !messages[0].text.isEmpty || resourceAvailable {
            let message = messages[0]
            actions.append(.context(ContextMenuAction(content: .text(title: chatPresentationInterfaceState.strings.Conversation_ContextMenuCopy, accessibilityLabel: chatPresentationInterfaceState.strings.Conversation_ContextMenuCopy), action: {
                if resourceAvailable {
                    for media in message.media {
                        if let image = media as? TelegramMediaImage, let largest = largestImageRepresentation(image.representations) {
                            let _ = (context.account.postbox.mediaBox.resourceData(largest.resource, option: .incremental(waitUntilFetchStatus: false))
                            |> take(1)
                            |> deliverOnMainQueue).start(next: { data in
                                if data.complete, let imageData = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                                    if let image = UIImage(data: imageData) {
                                        if !message.text.isEmpty {
                                            UIPasteboard.general.string = message.text
                                            /*UIPasteboard.general.items = [
                                                [kUTTypeUTF8PlainText as String: message.text],
                                                [kUTTypePNG as String: image]
                                            ]*/
                                        } else {
                                            UIPasteboard.general.image = image
                                        }
                                    } else {
                                        UIPasteboard.general.string = message.text
                                    }
                                } else {
                                    UIPasteboard.general.string = message.text
                                }
                            })
                        }
                    }
                } else {
                    var messageEntities: [MessageTextEntity]?
                    for attribute in message.attributes {
                        if let attribute = attribute as? TextEntitiesMessageAttribute {
                            messageEntities = attribute.entities
                            break
                        }
                    }
                    storeMessageTextInPasteboard(message.text, entities: messageEntities)
                }
            })))
        }
        
        var activePoll: TelegramMediaPoll?
        for media in message.media {
            if let poll = media as? TelegramMediaPoll, !poll.isClosed, message.id.namespace == Namespaces.Message.Cloud, poll.pollId.namespace == Namespaces.Media.CloudPoll {
                activePoll = poll
            }
        }
        
        if let activePoll = activePoll, let voters = activePoll.results.voters {
            var hasSelected = false
            for result in voters {
                if result.selected {
                    hasSelected = true
                }
            }
            if hasSelected {
                actions.append(.sheet(ChatMessageContextMenuSheetAction(color: .accent, title: chatPresentationInterfaceState.strings.Conversation_UnvotePoll, action: {
                    interfaceInteraction.requestUnvoteInMessage(messages[0].id)
                })))
            }
        }
        
        if data.canPin {
            if chatPresentationInterfaceState.pinnedMessage?.id != messages[0].id {
                actions.append(.sheet(ChatMessageContextMenuSheetAction(color: .accent, title: chatPresentationInterfaceState.strings.Conversation_Pin, action: {
                    interfaceInteraction.pinMessage(messages[0].id)
                })))
            } else {
                actions.append(.sheet(ChatMessageContextMenuSheetAction(color: .accent, title: chatPresentationInterfaceState.strings.Conversation_Unpin, action: {
                    interfaceInteraction.unpinMessage()
                })))
            }
        }
        
        if let _ = activePoll, messages[0].forwardInfo == nil {
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
                actions.append(.sheet(ChatMessageContextMenuSheetAction(color: .accent, title: chatPresentationInterfaceState.strings.Conversation_StopPoll, action: {
                    interfaceInteraction.requestStopPollInMessage(messages[0].id)
                })))
            }
        }
        
        if let message = messages.first, message.id.namespace == Namespaces.Message.Cloud, let channel = message.peers[message.id.peerId] as? TelegramChannel, !(message.media.first is TelegramMediaAction) {
            actions.append(.sheet(ChatMessageContextMenuSheetAction(color: .accent, title: chatPresentationInterfaceState.strings.Conversation_ContextMenuCopyLink, action: {
                let _ = (exportMessageLink(account: context.account, peerId: message.id.peerId, messageId: message.id)
                |> map { result -> String? in
                    return result
                }
                |> deliverOnMainQueue).start(next: { link in
                    if let link = link {
                        UIPasteboard.general.string = link
                        
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        if channel.addressName == nil {
                            controllerInteraction.presentController(OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .genericSuccess(presentationData.strings.Conversation_PrivateMessageLinkCopied, true)), nil)
                        } else {
                            controllerInteraction.presentController(OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .genericSuccess(presentationData.strings.GroupInfo_InviteLink_CopyAlert_Success, false)), nil)
                        }
                    }
                })
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
                                actions.append(.sheet(ChatMessageContextMenuSheetAction(color: .accent, title: chatPresentationInterfaceState.strings.Conversation_LinkDialogSave, action: {
                                    let _ = addSavedGif(postbox: context.account.postbox, fileReference: .message(message: MessageReference(message), media: file)).start()
                                })))
                            }
                            break
                        }
                    }
                }
            }
        }
        if data.canSelect {
            actions.append(.context(ContextMenuAction(content: .text(title: chatPresentationInterfaceState.strings.Conversation_ContextMenuMore, accessibilityLabel: chatPresentationInterfaceState.strings.Conversation_ContextMenuMore.replacingOccurrences(of: "...", with: "")), action: {
                interfaceInteraction.beginMessageSelection(selectAll ? messages.map { $0.id } : [message.id])
            })))
        }
        if !data.messageActions.options.intersection([.deleteLocally, .deleteGlobally]).isEmpty && isAction {
            actions.append(.context(ContextMenuAction(content: .text(title: chatPresentationInterfaceState.strings.Conversation_ContextMenuDelete, accessibilityLabel: chatPresentationInterfaceState.strings.Conversation_ContextMenuDelete), action: {
                interfaceInteraction.deleteMessages(messages)
            })))
        }
        
        if data.messageActions.options.contains(.viewStickerPack) {
            actions.append(.sheet(ChatMessageContextMenuSheetAction(color: .accent, title: chatPresentationInterfaceState.strings.StickerPack_ViewPack, action: {
                let _ = controllerInteraction.openMessage(message, .default)
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
                actions.append(.sheet(ChatMessageContextMenuSheetAction(color: .accent, title: chatPresentationInterfaceState.strings.Call_RateCall, action: {
                    let _ = controllerInteraction.rateCall(message, callId)
                })))
            }
        }
        
        if data.messageActions.options.contains(.forward) {
            actions.append(.sheet(ChatMessageContextMenuSheetAction(color: .accent, title: chatPresentationInterfaceState.strings.Conversation_ContextMenuForward, action: {
                    interfaceInteraction.forwardMessages(selectAll ? messages : [message])
            })))
        }
        
        if data.messageActions.options.contains(.report) {
            actions.append(.sheet(ChatMessageContextMenuSheetAction(color: .accent, title: chatPresentationInterfaceState.strings.Conversation_ContextMenuReport, action: {
                interfaceInteraction.reportMessages(selectAll ? messages : [message])
            })))
        }
        
        if !data.messageActions.options.intersection([.deleteLocally, .deleteGlobally]).isEmpty && !isAction {
            let title = message.flags.isSending ? chatPresentationInterfaceState.strings.Conversation_ContextMenuCancelSending : chatPresentationInterfaceState.strings.Conversation_ContextMenuDelete
            actions.append(.sheet(ChatMessageContextMenuSheetAction(color: .destructive, title: title, action: {
                interfaceInteraction.deleteMessages(selectAll ? messages : [message])
            })))
        }
        
        return actions
    }
}

struct ChatAvailableMessageActionOptions: OptionSet {
    var rawValue: Int32
    
    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    init() {
        self.rawValue = 0
    }
    
    static let deleteLocally = ChatAvailableMessageActionOptions(rawValue: 1 << 0)
    static let deleteGlobally = ChatAvailableMessageActionOptions(rawValue: 1 << 1)
    static let forward = ChatAvailableMessageActionOptions(rawValue: 1 << 2)
    static let report = ChatAvailableMessageActionOptions(rawValue: 1 << 3)
    static let viewStickerPack = ChatAvailableMessageActionOptions(rawValue: 1 << 4)
    static let rateCall = ChatAvailableMessageActionOptions(rawValue: 1 << 5)
    static let cancelSending = ChatAvailableMessageActionOptions(rawValue: 1 << 6)
    static let unsendPersonal = ChatAvailableMessageActionOptions(rawValue: 1 << 7)
}

struct ChatAvailableMessageActions {
    let options: ChatAvailableMessageActionOptions
    let banAuthor: Peer?
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

func chatAvailableMessageActions(postbox: Postbox, accountPeerId: PeerId, messageIds: Set<MessageId>) -> Signal<ChatAvailableMessageActions, NoError> {
    return postbox.transaction { transaction -> ChatAvailableMessageActions in
        let limitsConfiguration: LimitsConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.limitsConfiguration) as? LimitsConfiguration ?? LimitsConfiguration.defaultValue
        var optionsMap: [MessageId: ChatAvailableMessageActionOptions] = [:]
        var banPeer: Peer?
        var hadPersonalIncoming = false
        var hadBanPeerId = false
        for id in messageIds {
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
                if id.peerId == accountPeerId {
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
                        if message.id.peerId.namespace != Namespaces.Peer.SecretChat && !message.containsSecretMedia && !isAction {
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

import Foundation
import Postbox
import TelegramCore
import Display
import UIKit
import SwiftSignalKit
import MobileCoreServices

private struct MessageContextMenuData {
    let starStatus: Bool?
    let canReply: Bool
    let canPin: Bool
    let canEdit: Bool
    let canSelect: Bool
    let resourceStatus: MediaResourceStatus?
    let messageActions: ChatAvailableMessageActions
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
                    switch channel.info {
                        case .broadcast:
                            canReply = channel.hasAdminRights([.canPostMessages])
                        case .group:
                            canReply = !channel.hasBannedRights(.banSendMessages)
                    }
                }
            } else if let group = peer as? TelegramGroup {
                if case .Member = group.membership {
                    canReply = true
                }
            } else {
                canReply = true
            }
        case .group:
            break
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

func contextMenuForChatPresentationIntefaceState(chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account, messages: [Message], interfaceInteraction: ChatPanelInterfaceInteraction?, debugStreamSingleVideo: @escaping (MessageId) -> Void) -> Signal<[ChatMessageContextMenuAction], NoError> {
    guard let interfaceInteraction = interfaceInteraction else {
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
            } else if let _ = media as? TelegramMediaAction {
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
                canDeleteMessage = channel.hasAdminRights(.canPostMessages)
            }
            canDeleteMessage = channel.hasAdminRights(.canDeleteMessages)
        }
        canDeleteMessage = channel.hasAdminRights(.canDeleteMessages) || !message.flags.contains(.Incoming)
    } else if message.peers[message.id.peerId] is TelegramSecretChat {
        canDeleteMessage = true
    } else {
        canDeleteMessage = account.peerId == message.author?.id
    }
    
    if messages[0].flags.intersection([.Failed, .Unsent]).isEmpty {
        switch chatPresentationInterfaceState.chatLocation {
            case .peer:
                if let channel = messages[0].peers[messages[0].id.peerId] as? TelegramChannel {
                    switch channel.info {
                        case .broadcast:
                            if !isAction {
                                canPin = channel.hasAdminRights([.canEditMessages])
                            }
                        case .group:
                            if !isAction {
                                canPin = channel.hasAdminRights([.canPinMessages])
                            }
                    }
                }
            case .group:
                break
        }
    } else {
        canReply = false
        canPin = false
    }
    
    var loadStickerSaveStatusSignal: Signal<Bool?, NoError> = .single(nil)
    if loadStickerSaveStatus != nil {
        loadStickerSaveStatusSignal = account.postbox.transaction { transaction -> Bool? in
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
        loadResourceStatusSignal = account.postbox.mediaBox.resourceStatus(loadCopyMediaResource)
            |> take(1)
            |> map(Optional.init)
    }
    
    let loadLimits = account.postbox.transaction { transaction -> LimitsConfiguration in
        return transaction.getPreferencesEntry(key: PreferencesKeys.limitsConfiguration) as? LimitsConfiguration ?? LimitsConfiguration.defaultValue
    }
    
    dataSignal = combineLatest(loadLimits, loadStickerSaveStatusSignal, loadResourceStatusSignal, chatAvailableMessageActions(postbox: account.postbox, accountPeerId: account.peerId, messageIds: Set(messages.map { $0.id })))
    |> map { limitsConfiguration, stickerSaveStatus, resourceStatus, messageActions -> MessageContextMenuData in
        var canEdit = false
        var restrictEdit: Bool = false
        if messages[0].id.namespace == Namespaces.Message.Cloud && !isAction {
            let message = messages[0]
            
            var hasEditRights = false
            if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
                hasEditRights = false
            } else if let author = message.author, author.id == account.peerId {
                hasEditRights = true
            } else if message.author?.id == message.id.peerId, let peer = message.peers[message.id.peerId] {
                if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                    if peer.hasAdminRights(.canEditMessages) {
                        hasEditRights = true
                    }
                }
            }
            
            var hasUneditableAttributes = false

            
            if let peer = message.peers[message.id.peerId] as? TelegramChannel {
                if peer.hasBannedRights(.banSendMessages) {
                    hasUneditableAttributes = true
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
                        if file.isSticker || file.isInstantVideo {
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
                    }
                }
                
                if !hasUneditableAttributes {
                    let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                    if canPerformEditingActions(limits: limitsConfiguration, accountPeerId: account.peerId, message: message) {
                        canEdit = true
                    }
                }
            }
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
            actions.append(.context(ContextMenuAction(content: .text(chatPresentationInterfaceState.strings.Conversation_ContextMenuReply), action: {
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
            actions.append(.context(ContextMenuAction(content: .text(chatPresentationInterfaceState.strings.Conversation_ContextMenuCopy), action: {
                if resourceAvailable {
                    for media in message.media {
                        if let image = media as? TelegramMediaImage, let largest = largestImageRepresentation(image.representations) {
                            let _ = (account.postbox.mediaBox.resourceData(largest.resource, option: .incremental(waitUntilFetchStatus: false))
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
                    UIPasteboard.general.string = message.text
                }
            })))
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
        
        if let message = messages.first, message.id.namespace == Namespaces.Message.Cloud, let channel = message.peers[message.id.peerId] as? TelegramChannel, let addressName = channel.addressName, !(message.media.first is TelegramMediaAction) {
            actions.append(.sheet(ChatMessageContextMenuSheetAction(color: .accent, title: chatPresentationInterfaceState.strings.Conversation_ContextMenuCopyLink, action: {
                UIPasteboard.general.string = "https://t.me/\(addressName)/\(message.id.id)"
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
                                    let _ = addSavedGif(postbox: account.postbox, fileReference: .message(message: MessageReference(message), media: file)).start()
                                })))
                            } else if !GlobalExperimentalSettings.isAppStoreBuild {
                                actions.append(.sheet(ChatMessageContextMenuSheetAction(color: .accent, title: "Stream", action: {
                                    debugStreamSingleVideo(message.id)
                                })))
                            }
                            break
                        }
                    }
                }
            }
        }
        if data.canSelect {
            actions.append(.context(ContextMenuAction(content: .text(chatPresentationInterfaceState.strings.Conversation_ContextMenuMore), action: {
                interfaceInteraction.beginMessageSelection(messages.map { $0.id })
            })))
        }
        if !data.messageActions.options.intersection([.deleteLocally, .deleteGlobally]).isEmpty && isAction {
            actions.append(.context(ContextMenuAction(content: .text(chatPresentationInterfaceState.strings.Conversation_ContextMenuDelete), action: {
                interfaceInteraction.deleteMessages(messages)
            })))
        }
        
        if data.messageActions.options.contains(.forward) {
            actions.append(.sheet(ChatMessageContextMenuSheetAction(color: .accent, title: chatPresentationInterfaceState.strings.Conversation_ContextMenuForward, action: {
                    interfaceInteraction.forwardMessages(messages)
            })))
        }
        
        if data.messageActions.options.contains(.report) {
            actions.append(.sheet(ChatMessageContextMenuSheetAction(color: .accent, title: chatPresentationInterfaceState.strings.Conversation_ContextMenuReport, action: {
                interfaceInteraction.reportMessages(messages)
            })))
        }
        
        if !data.messageActions.options.intersection([.deleteLocally, .deleteGlobally]).isEmpty {
            actions.append(.sheet(ChatMessageContextMenuSheetAction(color: .destructive, title: chatPresentationInterfaceState.strings.Conversation_ContextMenuDelete, action: {
                interfaceInteraction.deleteMessages(messages)
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
}

struct ChatAvailableMessageActions {
    let options: ChatAvailableMessageActionOptions
    let banAuthor: Peer?
}

private func canPerformEditingActions(limits: LimitsConfiguration, accountPeerId: PeerId, message: Message) -> Bool {
    if message.id.peerId == accountPeerId {
        return true
    }
    
    let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
    
    if message.timestamp + limits.maxMessageEditingInterval > timestamp {
        return true
    } else {
        return false
    }
}

func chatAvailableMessageActions(postbox: Postbox, accountPeerId: PeerId, messageIds: Set<MessageId>) -> Signal<ChatAvailableMessageActions, NoError> {
    return postbox.transaction { transaction -> ChatAvailableMessageActions in
        let limitsConfiguration: LimitsConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.limitsConfiguration) as? LimitsConfiguration ?? LimitsConfiguration.defaultValue
        var optionsMap: [MessageId: ChatAvailableMessageActionOptions] = [:]
        var banPeer: Peer?
        var hadBanPeerId = false
        for id in messageIds {
            if optionsMap[id] == nil {
                optionsMap[id] = []
            }
            if id.peerId == accountPeerId {
                optionsMap[id]!.insert(.forward)
                optionsMap[id]!.insert(.deleteLocally)
            } else if let peer = transaction.getPeer(id.peerId), let message = transaction.getMessage(id) {
                var isAction = false
                for media in message.media {
                    if media is TelegramMediaAction {
                        isAction = true
                    }
                }
                if let channel = peer as? TelegramChannel {
                    if message.flags.contains(.Incoming), channel.adminRights == nil, !channel.flags.contains(.isCreator) {
                        optionsMap[id]!.insert(.report)
                    }
                    if channel.hasAdminRights(.canBanUsers), case .group = channel.info {
                        if message.flags.contains(.Incoming) {
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
                    }
                    if message.id.peerId.namespace != Namespaces.Peer.SecretChat && !message.containsSecretMedia && !isAction {
                        optionsMap[id]!.insert(.forward)
                    }
                    if !message.flags.contains(.Incoming) {
                        optionsMap[id]!.insert(.deleteGlobally)
                    } else {
                        if channel.hasAdminRights([.canDeleteMessages]) {
                            optionsMap[id]!.insert(.deleteGlobally)
                        }
                    }
                } else if let group = peer as? TelegramGroup {
                    if message.id.peerId.namespace != Namespaces.Peer.SecretChat && !message.containsSecretMedia {
                        if !isAction {
                            optionsMap[id]!.insert(.forward)
                        }
                        if message.flags.contains(.Incoming) {
                            optionsMap[id]!.insert(.report)
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
                                break
                        }
                    }
                } else if let _ = peer as? TelegramUser {
                    if message.id.peerId.namespace != Namespaces.Peer.SecretChat && !message.containsSecretMedia && !isAction {
                        optionsMap[id]!.insert(.forward)
                    }
                    optionsMap[id]!.insert(.deleteLocally)
                    if !message.flags.contains(.Incoming) {
                        if canPerformEditingActions(limits: limitsConfiguration, accountPeerId: accountPeerId, message: message) {
                            optionsMap[id]!.insert(.deleteGlobally)
                        }
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
        
        if !optionsMap.isEmpty {
            var reducedOptions = optionsMap.values.first!
            for value in optionsMap.values {
                reducedOptions.formIntersection(value)
            }
            return ChatAvailableMessageActions(options: reducedOptions, banAuthor: banPeer)
        } else {
            return ChatAvailableMessageActions(options: [], banAuthor: nil)
        }
    }
}

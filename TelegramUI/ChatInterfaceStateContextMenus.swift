import Foundation
import Postbox
import TelegramCore
import Display
import UIKit
import SwiftSignalKit

private struct MessageContextMenuData {
    let starStatus: Bool?
    let canReply: Bool
    let canPin: Bool
    let canEdit: Bool
}

private let starIconEmpty = UIImage(bundleImageName: "Chat/Context Menu/StarIconEmpty")?.precomposed()
private let starIconFilled = UIImage(bundleImageName: "Chat/Context Menu/StarIconFilled")?.precomposed()

func contextMenuForChatPresentationIntefaceState(chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account, message: Message, interfaceInteraction: ChatPanelInterfaceInteraction?) -> Signal<ContextMenuController?, NoError> {
    guard let peer = chatPresentationInterfaceState.peer, let interfaceInteraction = interfaceInteraction else {
        return .single(nil)
    }
    
    let dataSignal: Signal<MessageContextMenuData, NoError>
    
    var loadStickerSaveStatus: MediaId?
    for media in message.media {
        if let file = media as? TelegramMediaFile {
            for attribute in file.attributes {
                if case let .Sticker(_, packInfo, _) = attribute, packInfo != nil {
                    loadStickerSaveStatus = file.fileId
                }
            }
        }
    }
    
    var canReply = false
    var canPin = false
    if let channel = peer as? TelegramChannel {
        switch channel.info {
            case .broadcast:
                canReply = channel.hasAdminRights([.canPostMessages])
            case .group:
                canReply = true
                canPin = channel.hasAdminRights([.canPinMessages])
        }
    } else {
        canReply = true
    }
    
    var canEdit = false
    if let author = message.author, author.id == account.peerId {
        var hasUneditableAttributes = false
        for attribute in message.attributes {
            if let _ = attribute as? InlineBotMessageAttribute {
                hasUneditableAttributes = true
                break
            }
        }
        
        if !hasUneditableAttributes {
            let timestamp = Int32(CFAbsoluteTimeGetCurrent())
            if message.timestamp >= timestamp - 60 * 60 * 24 * 2 {
                canEdit = true
            }
        }
    }
    
    if loadStickerSaveStatus != nil {
        dataSignal = account.postbox.modify { modifier -> MessageContextMenuData in
            var starStatus: Bool?
            if let loadStickerSaveStatus = loadStickerSaveStatus {
                if getIsStickerSaved(modifier: modifier, fileId: loadStickerSaveStatus) {
                    starStatus = true
                } else {
                    starStatus = false
                }
            }
            
            return MessageContextMenuData(starStatus: starStatus, canReply: canReply, canPin: canPin, canEdit: canEdit)
        }
    } else {
        dataSignal = .single(MessageContextMenuData(starStatus: nil, canReply: canReply, canPin: canPin, canEdit: canEdit))
    }
    
    return dataSignal |> deliverOnMainQueue |> map { data -> ContextMenuController? in
        var actions: [ContextMenuAction] = []
        
        if let starStatus = data.starStatus, let image = starStatus ? starIconFilled : starIconEmpty {
            actions.append(ContextMenuAction(content: .icon(image), action: {
                interfaceInteraction.toggleMessageStickerStarred(message.id)
            }))
        }
        
        if data.canReply {
            actions.append(ContextMenuAction(content: .text(chatPresentationInterfaceState.strings.Conversation_ContextMenuReply), action: {
                interfaceInteraction.setupReplyMessage(message.id)
            }))
        }
        
        if data.canEdit {
            actions.append(ContextMenuAction(content: .text(chatPresentationInterfaceState.strings.Conversation_Edit), action: {
                interfaceInteraction.setupEditMessage(message.id)
            }))
        }
        
        actions.append(ContextMenuAction(content: .text(chatPresentationInterfaceState.strings.Conversation_ContextMenuCopy), action: {
            if !message.text.isEmpty {
                UIPasteboard.general.string = message.text
            }
        }))
        
        if data.canPin {
            if chatPresentationInterfaceState.pinnedMessage?.id != message.id {
                actions.append(ContextMenuAction(content: .text(chatPresentationInterfaceState.strings.Conversation_Pin), action: {
                    interfaceInteraction.pinMessage(message.id)
                }))
            } else {
                actions.append(ContextMenuAction(content: .text(chatPresentationInterfaceState.strings.Conversation_Unpin), action: {
                    interfaceInteraction.unpinMessage()
                }))
            }
        }
        
        for media in message.media {
            if let file = media as? TelegramMediaFile {
                if file.isVideo && file.isAnimated {
                    actions.append(ContextMenuAction(content: .text(chatPresentationInterfaceState.strings.Conversation_LinkDialogSave), action: {
                        let _ = addSavedGif(postbox: account.postbox, file: file).start()
                    }))
                    break
                }
            }
        }
        
    actions.append(ContextMenuAction(content: .text(chatPresentationInterfaceState.strings.Conversation_ContextMenuMore), action: {
            interfaceInteraction.beginMessageSelection(message.id)
        }))
        
        if !actions.isEmpty {
            let contextMenuController = ContextMenuController(actions: actions)
            return contextMenuController
        } else {
            return nil
        }
    }
}

struct ChatDeleteMessagesOptions: OptionSet {
    var rawValue: Int32
    
    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    init() {
        self.rawValue = 0
    }
    
    static let locally = ChatDeleteMessagesOptions(rawValue: 1 << 0)
    static let globally = ChatDeleteMessagesOptions(rawValue: 1 << 1)
}

func chatDeleteMessagesOptions(account: Account, messageIds: Set<MessageId>) -> Signal<ChatDeleteMessagesOptions, NoError> {
    return account.postbox.modify { modifier -> ChatDeleteMessagesOptions in
        var optionsMap: [MessageId: ChatDeleteMessagesOptions] = [:]
        for id in messageIds {
            if let peer = modifier.getPeer(id.peerId), let message = modifier.getMessage(id) {
                if let channel = peer as? TelegramChannel {
                    var options: ChatDeleteMessagesOptions = []
                    if !message.flags.contains(.Incoming) {
                        options.insert(.globally)
                    } else {
                        if channel.hasAdminRights([.canDeleteMessages]) {
                            options.insert(.globally)
                        }
                    }
                    optionsMap[message.id] = options
                } else if let group = peer as? TelegramGroup {
                    var options: ChatDeleteMessagesOptions = []
                    options.insert(.locally)
                    if !message.flags.contains(.Incoming) {
                        options.insert(.globally)
                    } else {
                        switch group.role {
                            case .creator, .admin:
                                options.insert(.globally)
                            case .member:
                                break
                        }
                    }
                    optionsMap[message.id] = options
                } else if let _ = peer as? TelegramUser {
                    var options: ChatDeleteMessagesOptions = []
                    options.insert(.locally)
                    if !message.flags.contains(.Incoming) {
                        options.insert(.globally)
                    }
                    optionsMap[message.id] = options
                } else if let _ = peer as? TelegramSecretChat {
                    var options: ChatDeleteMessagesOptions = []
                    options.insert(.globally)
                    optionsMap[message.id] = options
                } else {
                    assertionFailure()
                }
            } else {
                optionsMap[id] = [.locally]
            }
        }
        
        if !optionsMap.isEmpty {
            var reducedOptions = optionsMap.values.first!
            for value in optionsMap.values {
                reducedOptions.formIntersection(value)
            }
            return reducedOptions
        } else {
            return []
        }
    }
}

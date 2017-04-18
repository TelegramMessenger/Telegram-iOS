import Foundation
import Postbox
import TelegramCore
import Display
import UIKit
import SwiftSignalKit

func contextMenuForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account, message: Message, interfaceInteraction: ChatPanelInterfaceInteraction?) -> ContextMenuController? {
    guard let peer = chatPresentationInterfaceState.peer, let interfaceInteraction = interfaceInteraction else {
        return nil
    }
    
    var actions: [ContextMenuAction] = []
    
    var canReply = false
    var canPin = false
    if let channel = peer as? TelegramChannel {
        switch channel.info {
            case .broadcast:
                switch channel.role {
                    case .creator, .editor, .moderator:
                        canReply = true
                    case .member:
                        canReply = false
                }
            case .group:
                canReply = true
                switch channel.role {
                    case .creator, .editor, .moderator:
                        canPin = true
                    case .member:
                        canPin = false
                }
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
    
    if canReply {
        actions.append(ContextMenuAction(content: .text("Reply"), action: {
            interfaceInteraction.setupReplyMessage(message.id)
        }))
    }
    
    if canEdit {
        actions.append(ContextMenuAction(content: .text("Edit"), action: {
            interfaceInteraction.setupEditMessage(message.id)
        }))
    }
    
    actions.append(ContextMenuAction(content: .text("Copy"), action: {
        if !message.text.isEmpty {
            UIPasteboard.general.string = message.text
        }
    }))
    
    if canPin {
        if chatPresentationInterfaceState.pinnedMessageId != message.id {
            actions.append(ContextMenuAction(content: .text("Pin"), action: {
                interfaceInteraction.pinMessage(message.id)
            }))
        } else {
            actions.append(ContextMenuAction(content: .text("Unpin"), action: {
                interfaceInteraction.unpinMessage()
            }))
        }
    }
    
    for media in message.media {
        if let file = media as? TelegramMediaFile {
            if file.isVideo && file.isAnimated {
                actions.append(ContextMenuAction(content: .text("Save"), action: {
                    let _ = addSavedGif(postbox: account.postbox, file: file).start()
                }))
                break
            }
        }
    }
    
    actions.append(ContextMenuAction(content: .text("More..."), action: {
        interfaceInteraction.beginMessageSelection(message.id)
    }))

    
    if !actions.isEmpty {
        let contextMenuController = ContextMenuController(actions: actions)
        return contextMenuController
    } else {
        return nil
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
                        switch channel.role {
                            case .creator:
                                options.insert(.globally)
                            case .moderator, .editor:
                                options.insert(.globally)
                            case .member:
                                break
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

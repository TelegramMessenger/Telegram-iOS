import Foundation
import UIKit
import TelegramCore
import Postbox
import Display
import AccountContext
import Emoji
import ChatInterfaceState
import ChatPresentationInterfaceState
import SwiftSignalKit
import TextFormat
import ChatContextQuery

func serviceTasksForChatPresentationIntefaceState(context: AccountContext, chatPresentationInterfaceState: ChatPresentationInterfaceState, updateState: @escaping ((ChatPresentationInterfaceState) -> ChatPresentationInterfaceState) -> Void) -> [AnyHashable: () -> Disposable] {
    var missingEmoji = Set<Int64>()
    let inputText = chatPresentationInterfaceState.interfaceState.composeInputState.inputText
    inputText.enumerateAttribute(ChatTextInputAttributes.customEmoji, in: NSRange(location: 0, length: inputText.length), using: { value, _, _ in
        if let value = value as? ChatTextInputTextCustomEmojiAttribute {
            if value.file == nil {
                missingEmoji.insert(value.fileId)
            }
        }
    })
    
    var result: [AnyHashable: () -> Disposable] = [:]
    for id in missingEmoji {
        result["emoji-\(id)"] = {
            return (context.engine.stickers.resolveInlineStickers(fileIds: [id])
            |> deliverOnMainQueue).start(next: { result in
                if let file = result[id] {
                    updateState({ state -> ChatPresentationInterfaceState in
                        return state.updatedInterfaceState { interfaceState -> ChatInterfaceState in
                            var inputState = interfaceState.composeInputState
                            let text = NSMutableAttributedString(attributedString: inputState.inputText)
                            
                            inputState.inputText.enumerateAttribute(ChatTextInputAttributes.customEmoji, in: NSRange(location: 0, length: inputText.length), using: { value, range, _ in
                                if let value = value as? ChatTextInputTextCustomEmojiAttribute {
                                    if value.fileId == id {
                                        text.removeAttribute(ChatTextInputAttributes.customEmoji, range: range)
                                        text.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: file.fileId.id, file: file), range: range)
                                    }
                                }
                            })
                            
                            inputState.inputText = text
                            
                            return interfaceState.withUpdatedComposeInputState(inputState)
                        }
                    })
                }
            })
        }
    }
    return result
}

func inputContextQueriesForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState) -> [ChatPresentationInputQuery] {
    let inputState = chatPresentationInterfaceState.interfaceState.effectiveInputState
    let inputString: NSString = inputState.inputText.string as NSString
    var result: [ChatPresentationInputQuery] = []
    for (possibleQueryRange, possibleTypes, additionalStringRange) in textInputStateContextQueryRangeAndType(inputState) {
        let query = inputString.substring(with: possibleQueryRange)
        if possibleTypes == [.emoji] {
            result.append(.emoji(query.basicEmoji.0))
        } else if possibleTypes == [.hashtag] {
            result.append(.hashtag(query))
        } else if possibleTypes == [.mention] {
            var types: ChatInputQueryMentionTypes = [.members]
            if possibleQueryRange.lowerBound == 1 {
                types.insert(.contextBots)
            }
            result.append(.mention(query: query, types: types))
        } else if possibleTypes == [.command] {
            result.append(.command(query))
        } else if possibleTypes == [.contextRequest], let additionalStringRange = additionalStringRange {
            let additionalString = inputString.substring(with: additionalStringRange)
            result.append(.contextRequest(addressName: query, query: additionalString))
        } else if possibleTypes == [.emojiSearch], !query.isEmpty, let inputLanguage = chatPresentationInterfaceState.interfaceState.inputLanguage {
            result.append(.emojiSearch(query: query, languageCode: inputLanguage, range: possibleQueryRange))
        }
    }
    return result
}

func inputTextPanelStateForChatPresentationInterfaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext) -> ChatTextInputPanelState {
    var contextPlaceholder: NSAttributedString?
    loop: for (_, result) in chatPresentationInterfaceState.inputQueryResults {
        if case let .contextRequestResult(peer, _) = result, case let .user(botUser) = peer, let botInfo = botUser.botInfo, let inlinePlaceholder = botInfo.inlinePlaceholder {
            let inputQueries = inputContextQueriesForChatPresentationIntefaceState(chatPresentationInterfaceState)
            for inputQuery in inputQueries {
                if case let .contextRequest(addressName, query) = inputQuery, query.isEmpty {
                    let baseFontSize: CGFloat = max(chatTextInputMinFontSize, chatPresentationInterfaceState.fontSize.baseDisplaySize)
                    
                    let string = NSMutableAttributedString()
                    string.append(NSAttributedString(string: "@" + addressName, font: Font.regular(baseFontSize), textColor: UIColor.clear))
                    string.append(NSAttributedString(string: " " + inlinePlaceholder, font: Font.regular(baseFontSize), textColor: chatPresentationInterfaceState.theme.chat.inputPanel.inputPlaceholderColor))
                    contextPlaceholder = string
                }
            }
            
            break loop
        }
    }
    
    var currentAutoremoveTimeout: Int32? = chatPresentationInterfaceState.autoremoveTimeout
    var canSetupAutoremoveTimeout = false
    
    var canSendTextMessages = true
    
    var accessoryItems: [ChatTextInputAccessoryItem] = []
    
    if let peer = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramSecretChat {
        var extendedSearchLayout = false
        loop: for (_, result) in chatPresentationInterfaceState.inputQueryResults {
            if case let .contextRequestResult(peer, _) = result, peer != nil {
                extendedSearchLayout = true
                break loop
            }
        }
        
        if !extendedSearchLayout {
            currentAutoremoveTimeout = peer.messageAutoremoveTimeout
            canSetupAutoremoveTimeout = true
        }
    } else if let group = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramGroup {
        if !group.hasBannedPermission(.banChangeInfo) {
            canSetupAutoremoveTimeout = true
        }
        canSendTextMessages = !group.hasBannedPermission(.banSendText)
    } else if let user = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramUser {
        if user.botInfo == nil {
            canSetupAutoremoveTimeout = true
        }
    } else if let channel = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramChannel {
        if channel.hasPermission(.changeInfo) {
            canSetupAutoremoveTimeout = true
        }
        canSendTextMessages = channel.hasBannedPermission(.banSendText) == nil
    }
    
    if canSetupAutoremoveTimeout {
        if case .scheduledMessages = chatPresentationInterfaceState.subject {
        } else if chatPresentationInterfaceState.renderedPeer?.peerId != context.account.peerId {
            if currentAutoremoveTimeout != nil || chatPresentationInterfaceState.renderedPeer?.peer is TelegramSecretChat {
                accessoryItems.append(.messageAutoremoveTimeout(currentAutoremoveTimeout))
            }
        }
    }
    
    switch chatPresentationInterfaceState.inputMode {
        case .media:
            accessoryItems.append(.input(isEnabled: true, inputMode: .keyboard))
            return ChatTextInputPanelState(accessoryItems: accessoryItems, contextPlaceholder: contextPlaceholder, mediaRecordingState: chatPresentationInterfaceState.inputTextPanelState.mediaRecordingState)
        case .inputButtons:
            return ChatTextInputPanelState(accessoryItems: [.botInput(isEnabled: true, inputMode: .keyboard)], contextPlaceholder: contextPlaceholder, mediaRecordingState: chatPresentationInterfaceState.inputTextPanelState.mediaRecordingState)
        case .none, .text:
            if let _ = chatPresentationInterfaceState.interfaceState.editMessage {
                accessoryItems.append(.input(isEnabled: true, inputMode: .emoji))
                
                return ChatTextInputPanelState(accessoryItems: accessoryItems, contextPlaceholder: contextPlaceholder, mediaRecordingState: chatPresentationInterfaceState.inputTextPanelState.mediaRecordingState)
            } else {
                var accessoryItems: [ChatTextInputAccessoryItem] = []
                let isTextEmpty = chatPresentationInterfaceState.interfaceState.composeInputState.inputText.length == 0
                let hasForward = chatPresentationInterfaceState.interfaceState.forwardMessageIds != nil
                
                
                if case .scheduledMessages = chatPresentationInterfaceState.subject {
                } else {
                    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
                    let giftIsEnabled = !premiumConfiguration.isPremiumDisabled && premiumConfiguration.showPremiumGiftInAttachMenu && premiumConfiguration.showPremiumGiftInTextField
                    if isTextEmpty, giftIsEnabled, let peer = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramUser, !peer.isDeleted && peer.botInfo == nil && !peer.flags.contains(.isSupport) && !peer.isPremium && !chatPresentationInterfaceState.premiumGiftOptions.isEmpty && chatPresentationInterfaceState.suggestPremiumGift {
                        accessoryItems.append(.gift)
                    }
                }
                
                var extendedSearchLayout = false
                loop: for (_, result) in chatPresentationInterfaceState.inputQueryResults {
                    if case let .contextRequestResult(peer, _) = result, peer != nil {
                        extendedSearchLayout = true
                        break loop
                    }
                }
                if !extendedSearchLayout {
                    if case .scheduledMessages = chatPresentationInterfaceState.subject {
                    } else if chatPresentationInterfaceState.renderedPeer?.peerId != context.account.peerId {
                        if let peer = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramSecretChat, chatPresentationInterfaceState.interfaceState.composeInputState.inputText.length == 0 {
                            accessoryItems.append(.messageAutoremoveTimeout(peer.messageAutoremoveTimeout))
                        } else if currentAutoremoveTimeout != nil && chatPresentationInterfaceState.interfaceState.composeInputState.inputText.length == 0 {
                            accessoryItems.append(.messageAutoremoveTimeout(currentAutoremoveTimeout))
                        }
                    }
                }
                   
                if isTextEmpty && chatPresentationInterfaceState.hasScheduledMessages && !hasForward {
                    accessoryItems.append(.scheduledMessages)
                }
                    
                var stickersEnabled = true
                var stickersAreEmoji = !isTextEmpty
                if let peer = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramChannel {
                    if isTextEmpty, case .broadcast = peer.info, canSendMessagesToPeer(peer) {
                        accessoryItems.append(.silentPost(chatPresentationInterfaceState.interfaceState.silentPosting))
                    }
                    if peer.hasBannedPermission(.banSendStickers) != nil {
                        stickersEnabled = false
                    }
                } else if let peer = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramGroup {
                    if peer.hasBannedPermission(.banSendStickers) {
                        stickersEnabled = false
                    }
                }
                
                if isTextEmpty && chatPresentationInterfaceState.hasBots && chatPresentationInterfaceState.hasBotCommands && !hasForward {
                    accessoryItems.append(.commands)
                }
                
                if !canSendTextMessages {
                    if stickersEnabled && !stickersAreEmoji && !hasForward {
                        accessoryItems.append(.input(isEnabled: true, inputMode: .stickers))
                    }
                } else {
                    stickersAreEmoji = stickersAreEmoji || hasForward
                    if stickersEnabled {
                        accessoryItems.append(.input(isEnabled: true, inputMode: stickersAreEmoji ? .emoji : .stickers))
                    } else {
                        accessoryItems.append(.input(isEnabled: true, inputMode: .emoji))
                    }
                }
                
                if isTextEmpty, let message = chatPresentationInterfaceState.keyboardButtonsMessage, let _ = message.visibleButtonKeyboardMarkup, chatPresentationInterfaceState.interfaceState.messageActionsState.dismissedButtonKeyboardMessageId != message.id {
                    accessoryItems.append(.botInput(isEnabled: true, inputMode: .bot))
                }
                
                return ChatTextInputPanelState(accessoryItems: accessoryItems, contextPlaceholder: contextPlaceholder, mediaRecordingState: chatPresentationInterfaceState.inputTextPanelState.mediaRecordingState)
            }
    }
}

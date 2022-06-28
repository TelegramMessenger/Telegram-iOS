import Foundation
import UIKit
import TelegramCore
import Postbox
import Display
import AccountContext
import Emoji
import ChatInterfaceState
import ChatPresentationInterfaceState

struct PossibleContextQueryTypes: OptionSet {
    var rawValue: Int32
    
    init() {
        self.rawValue = 0
    }
    
    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    static let emoji = PossibleContextQueryTypes(rawValue: (1 << 0))
    static let hashtag = PossibleContextQueryTypes(rawValue: (1 << 1))
    static let mention = PossibleContextQueryTypes(rawValue: (1 << 2))
    static let command = PossibleContextQueryTypes(rawValue: (1 << 3))
    static let contextRequest = PossibleContextQueryTypes(rawValue: (1 << 4))
    static let emojiSearch = PossibleContextQueryTypes(rawValue: (1 << 5))
}

private func makeScalar(_ c: Character) -> Character {
    return c
}

private let spaceScalar = " " as UnicodeScalar
private let newlineScalar = "\n" as UnicodeScalar
private let hashScalar = "#" as UnicodeScalar
private let atScalar = "@" as UnicodeScalar
private let slashScalar = "/" as UnicodeScalar
private let colonScalar = ":" as UnicodeScalar
private let alphanumerics = CharacterSet.alphanumerics

private func scalarCanPrependQueryControl(_ c: UnicodeScalar?) -> Bool {
    if let c = c {
        if c == " " || c == "\n" || c == "." || c == "," {
            return true
        }
        return false
    } else {
        return true
    }
}

func textInputStateContextQueryRangeAndType(_ inputState: ChatTextInputState) -> [(NSRange, PossibleContextQueryTypes, NSRange?)] {
    if inputState.selectionRange.count != 0 {
        return []
    }
    
    let inputText = inputState.inputText
    let inputString: NSString = inputText.string as NSString
    var results: [(NSRange, PossibleContextQueryTypes, NSRange?)] = []
    let inputLength = inputString.length
    
    if inputLength != 0 {
        if inputString.hasPrefix("@") && inputLength != 1 {
            let startIndex = 1
            var index = startIndex
            var contextAddressRange: NSRange?
            
            while true {
                if index == inputLength {
                    break
                }
                if let c = UnicodeScalar(inputString.character(at: index)) {
                    if c == " " {
                        if index != startIndex {
                            contextAddressRange = NSRange(location: startIndex, length: index - startIndex)
                            index += 1
                        }
                        break
                    } else {
                        if !((c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || (c >= "0" && c <= "9") || c == "_") {
                            break
                        }
                    }
                    
                    if index == inputLength {
                        break
                    } else {
                        index += 1
                    }
                } else {
                    index += 1
                }
            }
            
            if let contextAddressRange = contextAddressRange {
                results.append((contextAddressRange, [.contextRequest], NSRange(location: index, length: inputLength - index)))
            }
        }
        
        let maxIndex = min(inputState.selectionRange.lowerBound, inputLength)
        if maxIndex == 0 {
            return results
        }
        var index = maxIndex - 1
        
        var possibleQueryRange: NSRange?
        
        let string = (inputString as String)
        let trimmedString = string.trimmingTrailingSpaces()
        if string.count < 3, trimmedString.isSingleEmoji {
            return [(NSRange(location: 0, length: inputString.length - (string.count - trimmedString.count)), [.emoji], nil)]
        }
        
        var possibleTypes = PossibleContextQueryTypes([.command, .mention, .hashtag, .emojiSearch])
        var definedType = false
        
        while true {
            var previousC: UnicodeScalar?
            if index != 0 {
                previousC = UnicodeScalar(inputString.character(at: index - 1))
            }
            if let c = UnicodeScalar(inputString.character(at: index)) {
                if c == spaceScalar || c == newlineScalar {
                    possibleTypes = []
                } else if c == hashScalar {
                    if scalarCanPrependQueryControl(previousC) {
                        possibleTypes = possibleTypes.intersection([.hashtag])
                        definedType = true
                        index += 1
                        possibleQueryRange = NSRange(location: index, length: maxIndex - index)
                    }
                    break
                } else if c == atScalar {
                    if scalarCanPrependQueryControl(previousC) {
                        possibleTypes = possibleTypes.intersection([.mention])
                        definedType = true
                        index += 1
                        possibleQueryRange = NSRange(location: index, length: maxIndex - index)
                    }
                    break
                    } else if c == slashScalar {
                        if scalarCanPrependQueryControl(previousC) {
                        possibleTypes = possibleTypes.intersection([.command])
                        definedType = true
                        index += 1
                        possibleQueryRange = NSRange(location: index, length: maxIndex - index)
                    }
                    break
                } else if c == colonScalar {
                    if scalarCanPrependQueryControl(previousC) {
                        possibleTypes = possibleTypes.intersection([.emojiSearch])
                        definedType = true
                        index += 1
                        possibleQueryRange = NSRange(location: index, length: maxIndex - index)
                    }
                    break
                }
            }
            
            if index == 0 {
                break
            } else {
                index -= 1
                possibleQueryRange = NSRange(location: index, length: maxIndex - index)
            }
        }
        
        if let possibleQueryRange = possibleQueryRange, definedType && !possibleTypes.isEmpty {
            results.append((possibleQueryRange, possibleTypes, nil))
        }
    }
    return results
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
        if case .creator = group.role {
            canSetupAutoremoveTimeout = true
        } else if case let .admin(rights, _) = group.role {
            if rights.rights.contains(.canDeleteMessages) {
                canSetupAutoremoveTimeout = true
            }
        }
    } else if let user = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramUser {
        if user.botInfo == nil {
            canSetupAutoremoveTimeout = true
        }
    } else if let channel = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramChannel {
        if channel.hasPermission(.deleteAllMessages) {
            canSetupAutoremoveTimeout = true
        }
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
            accessoryItems.append(.keyboard)
            return ChatTextInputPanelState(accessoryItems: accessoryItems, contextPlaceholder: contextPlaceholder, mediaRecordingState: chatPresentationInterfaceState.inputTextPanelState.mediaRecordingState)
        case .inputButtons:
            return ChatTextInputPanelState(accessoryItems: [.keyboard], contextPlaceholder: contextPlaceholder, mediaRecordingState: chatPresentationInterfaceState.inputTextPanelState.mediaRecordingState)
        case .none, .text:
            if let _ = chatPresentationInterfaceState.interfaceState.editMessage {
                return ChatTextInputPanelState(accessoryItems: [], contextPlaceholder: contextPlaceholder, mediaRecordingState: chatPresentationInterfaceState.inputTextPanelState.mediaRecordingState)
            } else {
                var accessoryItems: [ChatTextInputAccessoryItem] = []
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
                
                let isTextEmpty = chatPresentationInterfaceState.interfaceState.composeInputState.inputText.length == 0
                
                if chatPresentationInterfaceState.interfaceState.forwardMessageIds == nil {
                    if isTextEmpty && chatPresentationInterfaceState.hasScheduledMessages {
                        accessoryItems.append(.scheduledMessages)
                    }
                    
                    var stickersEnabled = true
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
                    if isTextEmpty && chatPresentationInterfaceState.hasBots && chatPresentationInterfaceState.hasBotCommands {
                        accessoryItems.append(.commands)
                    }
                    #if DEBUG
                    accessoryItems.append(.stickers(stickersEnabled))
                    #else
                    if isTextEmpty {
                        accessoryItems.append(.stickers(stickersEnabled))
                    }
                    #endif
                    if isTextEmpty, let message = chatPresentationInterfaceState.keyboardButtonsMessage, let _ = message.visibleButtonKeyboardMarkup, chatPresentationInterfaceState.interfaceState.messageActionsState.dismissedButtonKeyboardMessageId != message.id {
                        accessoryItems.append(.inputButtons)
                    }
                }
                return ChatTextInputPanelState(accessoryItems: accessoryItems, contextPlaceholder: contextPlaceholder, mediaRecordingState: chatPresentationInterfaceState.inputTextPanelState.mediaRecordingState)
            }
    }
}

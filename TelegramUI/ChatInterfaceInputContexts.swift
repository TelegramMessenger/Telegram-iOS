import Foundation
import TelegramCore
import Postbox
import Display

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
}

private func makeScalar(_ c: Character) -> Character {
    return c
    //return c.utf16[c.utf16.startIndex]
}

private let spaceScalar = makeScalar(" ")
private let newlineScalar = makeScalar("\n")
private let hashScalar = makeScalar("#")
private let atScalar = makeScalar("@")
private let slashScalar = makeScalar("/")
private let alphanumerics = CharacterSet.alphanumerics

func textInputStateContextQueryRangeAndType(_ inputState: ChatTextInputState) -> (Range<String.Index>, PossibleContextQueryTypes, Range<String.Index>?)? {
    let inputText = inputState.inputText
    if !inputText.isEmpty {
        if inputText.hasPrefix("@") && inputText != "@" {
            let startIndex = inputText.index(after: inputText.startIndex)
            var index = startIndex
            var contextAddressRange: Range<String.Index>?
            
            while true {
                if index == inputText.endIndex {
                    break
                }
                let c = inputText[index]
                
                if c == " " {
                    if index != startIndex {
                        contextAddressRange = startIndex ..< index
                    index = inputText.index(after: index)
                    }
                    break
                } else {
                    if !((c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || (c >= "0" && c <= "9") || c == "_") {
                        break
                    }
                }
                
                if index == inputText.endIndex {
                    break
                } else {
                    index = inputText.index(after: index)
                }
            }
            
            if let contextAddressRange = contextAddressRange {
                return (contextAddressRange, [.contextRequest], index ..< inputText.endIndex)
            }
        }
        
        let maxUtfIndex = inputText.utf16.index(inputText.utf16.startIndex, offsetBy: inputState.selectionRange.lowerBound)
        guard let maxIndex = maxUtfIndex.samePosition(in: inputText) else {
            return nil
        }
        if maxIndex == inputText.startIndex {
            return nil
        }
        var index = inputText.index(before: maxIndex)
        
        var possibleQueryRange: Range<String.Index>?
        
        if inputText.isSingleEmoji {
            return (inputText.startIndex ..< inputText.endIndex, [.emoji], nil)
        }
        
        var possibleTypes = PossibleContextQueryTypes([.command, .mention, .hashtag])
        var definedType = false
        
        while true {
            let c = inputText[index]
            
            if c == spaceScalar || c == newlineScalar {
                possibleTypes = []
            } else if c == hashScalar {
                possibleTypes = possibleTypes.intersection([.hashtag])
                definedType = true
                index = inputText.index(after: index)
                possibleQueryRange = index ..< maxIndex
                break
            } else if c == atScalar {
                possibleTypes = possibleTypes.intersection([.mention])
                definedType = true
                index = inputText.index(after: index)
                possibleQueryRange = index ..< maxIndex
                break
            } else if c == slashScalar {
                possibleTypes = possibleTypes.intersection([.command])
                definedType = true
                index = inputText.index(after: index)
                possibleQueryRange = index ..< maxIndex
                break
            }
            
            if index == inputText.startIndex {
                break
            } else {
                index = inputText.index(before: index)
                possibleQueryRange = index ..< maxIndex
            }
        }
        
        if let possibleQueryRange = possibleQueryRange, definedType && !possibleTypes.isEmpty {
            return (possibleQueryRange, possibleTypes, nil)
        }
    }
    return nil
}

func inputContextQueryForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState) -> ChatPresentationInputQuery? {
    let inputState = chatPresentationInterfaceState.interfaceState.effectiveInputState
    if let (possibleQueryRange, possibleTypes, additionalStringRange) = textInputStateContextQueryRangeAndType(inputState) {
        let query = String(inputState.inputText[possibleQueryRange])
        if possibleTypes == [.emoji] {
            return .emoji(query)
        } else if possibleTypes == [.hashtag] {
            return .hashtag(query)
        } else if possibleTypes == [.mention] {
            return .mention(query)
        } else if possibleTypes == [.command] {
            return .command(query)
        } else if possibleTypes == [.contextRequest], let additionalStringRange = additionalStringRange {
            let additionalString = String(inputState.inputText[additionalStringRange])
            return .contextRequest(addressName: query, query: additionalString)
        }
        return nil
    } else {
        return nil
    }
}

func inputTextPanelStateForChatPresentationInterfaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account) -> ChatTextInputPanelState {
    var contextPlaceholder: NSAttributedString?
    if let inputQueryResult = chatPresentationInterfaceState.inputQueryResult {
        if case let .contextRequestResult(peer, _) = inputQueryResult, let botUser = peer as? TelegramUser, let botInfo = botUser.botInfo, let inlinePlaceholder = botInfo.inlinePlaceholder {
            if let inputQuery = inputContextQueryForChatPresentationIntefaceState(chatPresentationInterfaceState) {
                if case let .contextRequest(addressName, query) = inputQuery, query.isEmpty {
                    let string = NSMutableAttributedString()
                    string.append(NSAttributedString(string: "@" + addressName, font: Font.regular(17.0), textColor: UIColor.clear))
                    string.append(NSAttributedString(string: " " + inlinePlaceholder, font: Font.regular(17.0), textColor: UIColor(rgb: 0xC8C8CE)))
                    contextPlaceholder = string
                }
            }
        }
    }
    switch chatPresentationInterfaceState.inputMode {
        case .media, .inputButtons:
            return ChatTextInputPanelState(accessoryItems: [.keyboard], contextPlaceholder: contextPlaceholder, mediaRecordingState: chatPresentationInterfaceState.inputTextPanelState.mediaRecordingState)
        case .none, .text:
            if let _ = chatPresentationInterfaceState.interfaceState.editMessage {
                return ChatTextInputPanelState(accessoryItems: [], contextPlaceholder: contextPlaceholder, mediaRecordingState: chatPresentationInterfaceState.inputTextPanelState.mediaRecordingState)
            } else {
                if chatPresentationInterfaceState.interfaceState.composeInputState.inputText.isEmpty {
                    var accessoryItems: [ChatTextInputAccessoryItem] = []
                    if let peer = chatPresentationInterfaceState.peer as? TelegramSecretChat {
                        accessoryItems.append(.messageAutoremoveTimeout(peer.messageAutoremoveTimeout))
                    }
                    accessoryItems.append(.stickers)
                    if let message = chatPresentationInterfaceState.keyboardButtonsMessage, let _ = message.visibleButtonKeyboardMarkup {
                        accessoryItems.append(.inputButtons)
                    }
                    return ChatTextInputPanelState(accessoryItems: accessoryItems, contextPlaceholder: contextPlaceholder, mediaRecordingState: chatPresentationInterfaceState.inputTextPanelState.mediaRecordingState)
                } else {
                    return ChatTextInputPanelState(accessoryItems: [], contextPlaceholder: contextPlaceholder, mediaRecordingState: chatPresentationInterfaceState.inputTextPanelState.mediaRecordingState)
                }
            }
    }
}

func urlPreviewForPresentationInterfaceState() {
    
}

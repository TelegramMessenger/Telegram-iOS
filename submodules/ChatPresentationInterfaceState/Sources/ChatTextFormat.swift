import Foundation
import TextFormat
import TelegramCore
import AccountContext

public func chatTextInputAddFormattingAttribute(_ state: ChatTextInputState, attribute: NSAttributedString.Key, value: Any?) -> ChatTextInputState {
    if !state.selectionRange.isEmpty {
        let nsRange = NSRange(location: state.selectionRange.lowerBound, length: state.selectionRange.count)
        var addAttribute = true
        var attributesToRemove: [NSAttributedString.Key] = []
        state.inputText.enumerateAttributes(in: nsRange, options: .longestEffectiveRangeNotRequired) { attributes, range, _ in
            for (key, _) in attributes {
                if key == attribute {
                    if nsRange == range {
                        addAttribute = false
                        attributesToRemove.append(key)
                    }
                }
            }
        }
        
        var selectionRange = state.selectionRange
        
        let result = NSMutableAttributedString(attributedString: state.inputText)
        for attribute in attributesToRemove {
            if attribute == ChatTextInputAttributes.block {
                var removeRange = nsRange
                
                var selectionIndex = nsRange.upperBound
                if nsRange.upperBound != result.length && (result.string as NSString).character(at: nsRange.upperBound) != 0x0a {
                    result.insert(NSAttributedString(string: "\n"), at: nsRange.upperBound)
                    selectionIndex += 1
                    removeRange.length += 1
                }
                if nsRange.lowerBound != 0 && (result.string as NSString).character(at: nsRange.lowerBound - 1) != 0x0a {
                    result.insert(NSAttributedString(string: "\n"), at: nsRange.lowerBound)
                    selectionIndex += 1
                    removeRange.location += 1
                } else if nsRange.lowerBound != 0 {
                    removeRange.location -= 1
                    removeRange.length += 1
                }
                
                if removeRange.lowerBound > result.length {
                    removeRange = NSRange(location: result.length, length: 0)
                } else if removeRange.upperBound > result.length {
                    removeRange = NSRange(location: removeRange.lowerBound, length: result.length - removeRange.lowerBound)
                }
                result.removeAttribute(attribute, range: removeRange)
                
                if selectionRange.lowerBound > result.length {
                    selectionRange = result.length ..< result.length
                } else if selectionRange.upperBound > result.length {
                    selectionRange = selectionRange.lowerBound ..< result.length
                }
                
                // Prevent merge back
                result.enumerateAttributes(in: NSRange(location: selectionIndex, length: result.length - selectionIndex), options: .longestEffectiveRangeNotRequired) { attributes, range, _ in
                    for (key, value) in attributes {
                        if let value = value as? ChatTextInputTextQuoteAttribute {
                            result.removeAttribute(key, range: range)
                            result.addAttribute(key, value: ChatTextInputTextQuoteAttribute(kind: value.kind, isCollapsed: value.isCollapsed), range: range)
                        }
                    }
                }
                
                selectionRange = selectionIndex ..< selectionIndex
            } else {
                result.removeAttribute(attribute, range: nsRange)
            }
        }
        
        if addAttribute {
            if attribute == ChatTextInputAttributes.block {
                result.addAttribute(attribute, value: value ?? ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: false), range: nsRange)
                var selectionIndex = nsRange.upperBound
                if nsRange.upperBound != result.length && (result.string as NSString).character(at: nsRange.upperBound) != 0x0a {
                    result.insert(NSAttributedString(string: "\n"), at: nsRange.upperBound)
                    selectionIndex += 1
                }
                if nsRange.lowerBound != 0 && (result.string as NSString).character(at: nsRange.lowerBound - 1) != 0x0a {
                    result.insert(NSAttributedString(string: "\n"), at: nsRange.lowerBound)
                    selectionIndex += 1
                }
                selectionRange = selectionIndex ..< selectionIndex
            } else {
                result.addAttribute(attribute, value: true as Bool, range: nsRange)
            }
        }
        if selectionRange.lowerBound > result.length {
            selectionRange = result.length ..< result.length
        } else if selectionRange.upperBound > result.length {
            selectionRange = selectionRange.lowerBound ..< result.length
        }
        return ChatTextInputState(inputText: result, selectionRange: selectionRange)
    } else {
        return state
    }
}

public func chatTextInputClearFormattingAttributes(_ state: ChatTextInputState) -> ChatTextInputState {
    if !state.selectionRange.isEmpty {
        let nsRange = NSRange(location: state.selectionRange.lowerBound, length: state.selectionRange.count)
        var attributesToRemove: [NSAttributedString.Key] = []
        state.inputText.enumerateAttributes(in: nsRange, options: .longestEffectiveRangeNotRequired) { attributes, range, stop in
            for (key, _) in attributes {
                attributesToRemove.append(key)
            }
        }
        
        let result = NSMutableAttributedString(attributedString: state.inputText)
        for attribute in attributesToRemove {
            result.removeAttribute(attribute, range: nsRange)
        }
        return ChatTextInputState(inputText: result, selectionRange: state.selectionRange)
    } else {
        return state
    }
}

public func chatTextInputAddLinkAttribute(_ state: ChatTextInputState, selectionRange: Range<Int>, url: String) -> ChatTextInputState {
    if !selectionRange.isEmpty {
        let nsRange = NSRange(location: selectionRange.lowerBound, length: selectionRange.count)
        var linkRange = nsRange
        var attributesToRemove: [(NSAttributedString.Key, NSRange)] = []
        state.inputText.enumerateAttributes(in: nsRange, options: .longestEffectiveRangeNotRequired) { attributes, range, stop in
            for (key, _) in attributes {
                if key == ChatTextInputAttributes.textUrl {
                    attributesToRemove.append((key, range))
                    linkRange = linkRange.union(range)
                } else {
                    attributesToRemove.append((key, nsRange))
                }
            }
        }
        
        let result = NSMutableAttributedString(attributedString: state.inputText)
        for (attribute, range) in attributesToRemove {
            result.removeAttribute(attribute, range: range)
        }
        result.addAttribute(ChatTextInputAttributes.textUrl, value: ChatTextInputTextUrlAttribute(url: url), range: nsRange)
        return ChatTextInputState(inputText: result, selectionRange: selectionRange)
    } else {
        return state
    }
}

public func chatTextInputRemoveLinkAttribute(_ state: ChatTextInputState, selectionRange: Range<Int>) -> ChatTextInputState {
    if !selectionRange.isEmpty {
        let nsRange = NSRange(location: selectionRange.lowerBound, length: selectionRange.count)
        var attributesToRemove: [(NSAttributedString.Key, NSRange)] = []
        state.inputText.enumerateAttributes(in: nsRange, options: .longestEffectiveRangeNotRequired) { attributes, range, stop in
            for (key, _) in attributes {
                if key == ChatTextInputAttributes.textUrl {
                    attributesToRemove.append((key, range))
                } else {
                    attributesToRemove.append((key, nsRange))
                }
            }
        }
        
        let result = NSMutableAttributedString(attributedString: state.inputText)
        for (attribute, range) in attributesToRemove {
            result.removeAttribute(attribute, range: range)
        }
        return ChatTextInputState(inputText: result, selectionRange: selectionRange)
    } else {
        return state
    }
}

public func chatTextInputAddMentionAttribute(_ state: ChatTextInputState, peer: EnginePeer) -> ChatTextInputState {
    let inputText = NSMutableAttributedString(attributedString: state.inputText)
    
    let range = NSMakeRange(state.selectionRange.startIndex, state.selectionRange.endIndex - state.selectionRange.startIndex)
    
    if let addressName = peer.addressName, !addressName.isEmpty {
        let replacementText = "@\(addressName) "
        
        inputText.replaceCharacters(in: range, with: replacementText)
        
        let selectionPosition = range.lowerBound + (replacementText as NSString).length
        
        return ChatTextInputState(inputText: inputText, selectionRange: selectionPosition ..< selectionPosition)
    } else if !peer.compactDisplayTitle.isEmpty {
        let replacementText = NSMutableAttributedString()
        replacementText.append(NSAttributedString(string: peer.compactDisplayTitle, attributes: [ChatTextInputAttributes.textMention: ChatTextInputTextMentionAttribute(peerId: peer.id)]))
        replacementText.append(NSAttributedString(string: " "))
        
        let updatedRange = NSRange(location: range.location , length: range.length)
        
        inputText.replaceCharacters(in: updatedRange, with: replacementText)
        
        let selectionPosition = updatedRange.lowerBound + replacementText.length
        
        return ChatTextInputState(inputText: inputText, selectionRange: selectionPosition ..< selectionPosition)
    } else {
        return state
    }
}

public func chatTextInputAddQuoteAttribute(_ state: ChatTextInputState, selectionRange: Range<Int>, kind: ChatTextInputTextQuoteAttribute.Kind) -> ChatTextInputState {
    if selectionRange.isEmpty {
        return state
    }
    let nsRange = NSRange(location: selectionRange.lowerBound, length: selectionRange.count)
    var quoteRange = nsRange
    var attributesToRemove: [(NSAttributedString.Key, NSRange)] = []
    state.inputText.enumerateAttributes(in: nsRange, options: .longestEffectiveRangeNotRequired) { attributes, range, stop in
        for (key, _) in attributes {
            if key == ChatTextInputAttributes.block {
                attributesToRemove.append((key, range))
                quoteRange = quoteRange.union(range)
            } else {
                attributesToRemove.append((key, nsRange))
            }
        }
    }
    
    let result = NSMutableAttributedString(attributedString: state.inputText)
    for (attribute, range) in attributesToRemove {
        result.removeAttribute(attribute, range: range)
    }
    result.addAttribute(ChatTextInputAttributes.block, value: ChatTextInputTextQuoteAttribute(kind: kind, isCollapsed: false), range: nsRange)
    return ChatTextInputState(inputText: result, selectionRange: selectionRange)
}

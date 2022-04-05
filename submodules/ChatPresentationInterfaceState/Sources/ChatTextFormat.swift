import Foundation
import TextFormat
import Postbox
import TelegramCore
import AccountContext

public func chatTextInputAddFormattingAttribute(_ state: ChatTextInputState, attribute: NSAttributedString.Key) -> ChatTextInputState {
    if !state.selectionRange.isEmpty {
        let nsRange = NSRange(location: state.selectionRange.lowerBound, length: state.selectionRange.count)
        var addAttribute = true
        var attributesToRemove: [NSAttributedString.Key] = []
        state.inputText.enumerateAttributes(in: nsRange, options: .longestEffectiveRangeNotRequired) { attributes, range, stop in
            for (key, _) in attributes {
                if key == attribute && range == nsRange {
                    addAttribute = false
                    attributesToRemove.append(key)
                }
            }
        }
        
        let result = NSMutableAttributedString(attributedString: state.inputText)
        for attribute in attributesToRemove {
            result.removeAttribute(attribute, range: nsRange)
        }
        if addAttribute {
            result.addAttribute(attribute, value: true as Bool, range: nsRange)
        }
        return ChatTextInputState(inputText: result, selectionRange: state.selectionRange)
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

public func chatTextInputAddMentionAttribute(_ state: ChatTextInputState, peer: Peer) -> ChatTextInputState {
    let inputText = NSMutableAttributedString(attributedString: state.inputText)
    
    let range = NSMakeRange(state.selectionRange.startIndex, state.selectionRange.endIndex - state.selectionRange.startIndex)
    
    if let addressName = peer.addressName, !addressName.isEmpty {
        let replacementText = "@\(addressName) "
        
        inputText.replaceCharacters(in: range, with: replacementText)
        
        let selectionPosition = range.lowerBound + (replacementText as NSString).length
        
        return ChatTextInputState(inputText: inputText, selectionRange: selectionPosition ..< selectionPosition)
    } else if !EnginePeer(peer).compactDisplayTitle.isEmpty {
        let replacementText = NSMutableAttributedString()
        replacementText.append(NSAttributedString(string: EnginePeer(peer).compactDisplayTitle, attributes: [ChatTextInputAttributes.textMention: ChatTextInputTextMentionAttribute(peerId: peer.id)]))
        replacementText.append(NSAttributedString(string: " "))
        
        let updatedRange = NSRange(location: range.location , length: range.length)
        
        inputText.replaceCharacters(in: updatedRange, with: replacementText)
        
        let selectionPosition = updatedRange.lowerBound + replacementText.length
        
        return ChatTextInputState(inputText: inputText, selectionRange: selectionPosition ..< selectionPosition)
    } else {
        return state
    }
}

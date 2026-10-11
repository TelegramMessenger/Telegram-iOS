import Foundation
import TextFormat
import TelegramCore
import AccountContext

public func chatTextInputAddFormattingAttribute(_ state: ChatTextInputState, attribute: NSAttributedString.Key, value: Any?) -> ChatTextInputState {
    if !state.selectionRange.isEmpty {
        let nsRange = NSRange(location: state.selectionRange.lowerBound, length: state.selectionRange.count)
        // Toggle: remove the attribute when it already covers the WHOLE selection, add it otherwise.
        // Ask about this one attribute's own runs: `enumerateAttributes` splits runs wherever any
        // attribute changes, so a selection that is bold throughout but partly italic enumerates as
        // several runs and never "equals" the selection.
        var coversSelection = true
        state.inputText.enumerateAttribute(attribute, in: nsRange, options: .longestEffectiveRangeNotRequired) { value, _, stop in
            if value == nil {
                coversSelection = false
                stop.pointee = true
            }
        }
        let addAttribute = !coversSelection
        let attributesToRemove: [NSAttributedString.Key] = coversSelection ? [attribute] : []
        
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
        // Only what a link REPLACES is removed: a previous link, and the other entities that give
        // the same text its own tap target (mention, date). Formatting (bold, italic, spoiler, …)
        // and the block-quote/code attribute stay, so linking text neither unformats it nor cuts a
        // quote in three.
        let result = NSMutableAttributedString(attributedString: state.inputText)
        for key in [ChatTextInputAttributes.textUrl, ChatTextInputAttributes.textMention, ChatTextInputAttributes.date] {
            result.removeAttribute(key, range: nsRange)
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
        // Removes the link from the selection and nothing else: formatting and the quote stay.
        let result = NSMutableAttributedString(attributedString: state.inputText)
        result.removeAttribute(ChatTextInputAttributes.textUrl, range: nsRange)
        return ChatTextInputState(inputText: result, selectionRange: selectionRange)
    } else {
        return state
    }
}

public func chatTextInputAddDateAttribute(_ state: ChatTextInputState, selectionRange: Range<Int>, date: Int32) -> ChatTextInputState {
    if !selectionRange.isEmpty {
        let nsRange = NSRange(location: selectionRange.lowerBound, length: selectionRange.count)
        // As for a link: only what a date REPLACES is removed — a previous date and the other
        // entities that give the same text its own tap target. Formatting and the quote stay.
        let result = NSMutableAttributedString(attributedString: state.inputText)
        for key in [ChatTextInputAttributes.date, ChatTextInputAttributes.textUrl, ChatTextInputAttributes.textMention] {
            result.removeAttribute(key, range: nsRange)
        }
        result.addAttribute(ChatTextInputAttributes.date, value: ChatTextInputTextDateAttribute(date: date), range: nsRange)
        return ChatTextInputState(inputText: result, selectionRange: selectionRange)
    } else {
        return state
    }
}

public func chatTextInputRemoveDateAttribute(_ state: ChatTextInputState, selectionRange: Range<Int>) -> ChatTextInputState {
    if !selectionRange.isEmpty {
        let nsRange = NSRange(location: selectionRange.lowerBound, length: selectionRange.count)
        // Removes the date from the selection and nothing else: formatting and the quote stay.
        let result = NSMutableAttributedString(attributedString: state.inputText)
        result.removeAttribute(ChatTextInputAttributes.date, range: nsRange)
        return ChatTextInputState(inputText: result, selectionRange: selectionRange)
    } else {
        return state
    }
}

/// The text the avatar context menu's Mention inserts for `peer`: `@username ` for a peer with a
/// username, otherwise its name as a mention entity followed by a space; nil when it has neither.
/// One definition for both paths — `chatTextInputAddMentionAttribute` (the legacy state transform) and
/// the rich editor's insert through the node (`chatComposerInsertMention`).
public func chatTextInputMentionText(peer: EnginePeer) -> NSAttributedString? {
    if let addressName = peer.addressName, !addressName.isEmpty {
        return NSAttributedString(string: "@\(addressName) ")
    } else if !peer.compactDisplayTitle.isEmpty {
        let replacementText = NSMutableAttributedString()
        replacementText.append(NSAttributedString(string: peer.compactDisplayTitle, attributes: [ChatTextInputAttributes.textMention: ChatTextInputTextMentionAttribute(peerId: peer.id)]))
        replacementText.append(NSAttributedString(string: " "))
        return replacementText
    } else {
        return nil
    }
}

/// The LEGACY composer's Mention: rewrites the flat text. On the rich editor this retypes every block
/// as body, so the chat reaches this only when the input node declines the insert
/// (`chatComposerInsertMention`); the legacy node's flat state is its whole content.
public func chatTextInputAddMentionAttribute(_ state: ChatTextInputState, peer: EnginePeer) -> ChatTextInputState {
    guard let replacementText = chatTextInputMentionText(peer: peer) else {
        return state
    }
    let inputText = NSMutableAttributedString(attributedString: state.inputText)
    
    let range = NSMakeRange(state.selectionRange.startIndex, state.selectionRange.endIndex - state.selectionRange.startIndex)
    
    if let addressName = peer.addressName, !addressName.isEmpty {
        // A username goes in as a plain STRING, which takes the attributes of the text it replaces.
        inputText.replaceCharacters(in: range, with: replacementText.string)
    } else {
        inputText.replaceCharacters(in: range, with: replacementText)
    }
    
    let selectionPosition = range.lowerBound + replacementText.length
    
    return ChatTextInputState(inputText: inputText, selectionRange: selectionPosition ..< selectionPosition)
}

/// The LEGACY composer's insert of `text` at the selection (the chat's emoji keyboard): the text
/// inherits a quote at the caret and the character formatting before it, then the flat text is
/// rebuilt. Moved from `ChatControllerLoadDisplayNode`'s `insertText` closure (the formatting
/// inheritance below is new) so the chat and the composer harness share it; the chat reaches it only when the input node declines the insert
/// (`chatComposerInsertTextOnUsersBehalf`), since on the rich editor the rebuild retypes every block.
public func chatTextInputStateInsertingText(_ textInputState: ChatTextInputState, text: NSAttributedString) -> ChatTextInputState {
    let inputText = NSMutableAttributedString(attributedString: textInputState.inputText)
    
    let range = textInputState.selectionRange
    
    let updatedText = NSMutableAttributedString(attributedString: text)
    if range.lowerBound < inputText.length {
        if let quote = inputText.attribute(ChatTextInputAttributes.block, at: range.lowerBound, effectiveRange: nil) {
            updatedText.addAttribute(ChatTextInputAttributes.block, value: quote, range: NSRange(location: 0, length: updatedText.length))
        }
    }
    // Inherit the CHARACTER formatting at the caret too, not just the quote.
    //
    // Inserted fragments carry only what their producer set — the emoji keyboard builds
    // `NSAttributedString(string: text, attributes: [.customEmoji: …])` and nothing else — so
    // inserting a custom emoji inside a SPOILER split the spoiler in two, leaving the emoji
    // unhidden in the gap. Device trace at the editor's own boundary:
    // `"Qwfe"/sp=1 EMOJI/sp=0 "qwffqw"/sp=1`.
    //
    // FORMATTING ONLY, NEVER AN ENTITY. Custom emoji, link, mention and date share one
    // mutually-exclusive slot, so inheriting an entity would make an emoji inserted after a
    // URL join that link. And the caller always wins, so the emoji keeps its own attribute.
    //
    // The source is the character BEFORE the caret — what the user was last typing in —
    // falling back to the one at it, so inserting at the very end of a spoiler still
    // continues it.
    //
    // Inline CODE is never inherited by a custom emoji: a `Code` entity holds no other entity on
    // the wire, so a code-formatted custom emoji goes out as overlapping `Code` and `CustomEmoji`
    // (`HarnessEmojiInsertAfterInlineCodeTests`). Plain text still continues the code.
    let formattingSource = range.lowerBound > 0
        ? range.lowerBound - 1
        : (inputText.length > 0 ? 0 : nil)
    if let formattingSource, formattingSource < inputText.length {
        let source = inputText.attributes(at: formattingSource, effectiveRange: nil)
        for key in [ChatTextInputAttributes.bold, ChatTextInputAttributes.italic,
                    ChatTextInputAttributes.monospace, ChatTextInputAttributes.strikethrough,
                    ChatTextInputAttributes.underline, ChatTextInputAttributes.spoiler] {
            guard let value = source[key] else { continue }
            let whole = NSRange(location: 0, length: updatedText.length)
            updatedText.enumerateAttribute(key, in: whole, options: []) { existing, range, _ in
                guard existing == nil else { return }
                if key == ChatTextInputAttributes.monospace {
                    updatedText.enumerateAttribute(ChatTextInputAttributes.customEmoji, in: range, options: []) { emoji, subrange, _ in
                        if emoji == nil {
                            updatedText.addAttribute(key, value: value, range: subrange)
                        }
                    }
                } else {
                    updatedText.addAttribute(key, value: value, range: range)
                }
            }
        }
    }
    inputText.replaceCharacters(in: NSMakeRange(range.lowerBound, range.count), with: updatedText)
    
    let selectionPosition = range.lowerBound + (updatedText.string as NSString).length
    
    return ChatTextInputState(inputText: inputText, selectionRange: selectionPosition ..< selectionPosition)
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

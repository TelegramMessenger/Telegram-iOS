import Foundation
import SwiftSignalKit
import TextFormat
import TelegramCore
import AccountContext

public struct PossibleContextQueryTypes: OptionSet {
    public var rawValue: Int32
    
    public init() {
        self.rawValue = 0
    }
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let emoji = PossibleContextQueryTypes(rawValue: (1 << 0))
    public static let hashtag = PossibleContextQueryTypes(rawValue: (1 << 1))
    public static let mention = PossibleContextQueryTypes(rawValue: (1 << 2))
    public static let command = PossibleContextQueryTypes(rawValue: (1 << 3))
    public static let contextRequest = PossibleContextQueryTypes(rawValue: (1 << 4))
    public static let emojiSearch = PossibleContextQueryTypes(rawValue: (1 << 5))
}

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

public func textInputStateContextQueryRangeAndType(_ inputState: ChatTextInputState) -> [(NSRange, PossibleContextQueryTypes, NSRange?)] {
    return textInputStateContextQueryRangeAndType(inputText: inputState.inputText, selectionRange: inputState.selectionRange)
}

public func textInputStateContextQueryRangeAndType(inputText: NSAttributedString, selectionRange: Range<Int>) -> [(NSRange, PossibleContextQueryTypes, NSRange?)] {
    if selectionRange.count != 0 {
        return []
    }
    
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
        
        let maxIndex = min(selectionRange.lowerBound, inputLength)
        if maxIndex == 0 {
            return results
        }
        var index = maxIndex - 1
        
        var possibleQueryRange: NSRange?
        
        let string = (inputString as String)
        let trimmedString = string.trimmingTrailingSpaces()
        if string.count < 3, trimmedString.isSingleEmoji {
            if inputText.attribute(ChatTextInputAttributes.customEmoji, at: 0, effectiveRange: nil) == nil {
                return [(NSRange(location: 0, length: inputString.length - (string.count - trimmedString.count)), [.emoji], nil)]
            }
        } else {
            /*let activeString = inputText.attributedSubstring(from: NSRange(location: 0, length: inputState.selectionRange.upperBound))
            if let lastCharacter = activeString.string.last, String(lastCharacter).isSingleEmoji {
                let matchLength = (String(lastCharacter) as NSString).length
                
                if activeString.attribute(ChatTextInputAttributes.customEmoji, at: activeString.length - matchLength, effectiveRange: nil) == nil {
                    return [(NSRange(location: inputState.selectionRange.upperBound - matchLength, length: matchLength), [.emojiSearch], nil)]
                }
            }*/
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

public enum ChatPresentationInputQueryKind: Int32 {
    case emoji
    case hashtag
    case mention
    case command
    case contextRequest
    case emojiSearch
}

public struct ChatInputQueryMentionTypes: OptionSet, Hashable {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let contextBots = ChatInputQueryMentionTypes(rawValue: 1 << 0)
    public static let members = ChatInputQueryMentionTypes(rawValue: 1 << 1)
    public static let accountPeer = ChatInputQueryMentionTypes(rawValue: 1 << 2)
}

public enum ChatPresentationInputQuery: Hashable, Equatable {
    case emoji(String)
    case hashtag(String)
    case mention(query: String, types: ChatInputQueryMentionTypes)
    case command(String)
    case emojiSearch(query: String, languageCode: String, range: NSRange)
    case contextRequest(addressName: String, query: String)
    
    public var kind: ChatPresentationInputQueryKind {
        switch self {
            case .emoji:
                return .emoji
            case .hashtag:
                return .hashtag
            case .mention:
                return .mention
            case .command:
                return .command
            case .contextRequest:
                return .contextRequest
            case .emojiSearch:
                return .emojiSearch
        }
    }
}

public enum ChatContextQueryError {
    case generic
    case inlineBotLocationRequest(EnginePeer.Id)
}

public enum ChatContextQueryUpdate {
    case remove
    case update(ChatPresentationInputQuery, Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError>)
}

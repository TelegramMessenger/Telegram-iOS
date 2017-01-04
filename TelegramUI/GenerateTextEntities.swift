import Foundation
import TelegramCore

private let dataDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType([.link]).rawValue)
private let alphanumericSet = CharacterSet.alphanumerics
private let validIdentifierSet: CharacterSet = {
    var set = CharacterSet(charactersIn: "a".unicodeScalars.first! ... "z".unicodeScalars.first!)
    set.insert(charactersIn: "A".unicodeScalars.first! ... "Z".unicodeScalars.first!)
    set.insert(charactersIn: "0".unicodeScalars.first! ... "9".unicodeScalars.first!)
    set.insert("_")
    return set
}()
private let identifierDelimiterSet: CharacterSet = {
    var set = CharacterSet.punctuationCharacters
    set.formUnion(CharacterSet.whitespacesAndNewlines)
    return set
}()

private enum CurrentEntityType {
    case command
    case mention
    case hashtag
}

func generateTextEntities(_ text: String) -> [MessageTextEntity] {
    var entities: [MessageTextEntity] = []
    
    let utf16 = text.utf16
    
    if let dataDetector = dataDetector {
        dataDetector.enumerateMatches(in: text, options: [], range: NSMakeRange(0, utf16.count), using: { result, _, _ in
            if let result = result {
                if result.resultType == NSTextCheckingResult.CheckingType.link {
                    let lowerBound = utf16.index(utf16.startIndex, offsetBy: result.range.location).samePosition(in: text)
                    let upperBound = utf16.index(utf16.startIndex, offsetBy: result.range.location + result.range.length).samePosition(in: text)
                    if let lowerBound = lowerBound, let upperBound = upperBound {
                        entities.append(MessageTextEntity(range: text.distance(from: text.startIndex, to: lowerBound) ..< text.distance(from: text.startIndex, to: upperBound), type: .Url))
                    }
                }
            }
        })
    }
    
    let unicodeScalars = text.unicodeScalars
    var index = unicodeScalars.startIndex
    var currentEntity: (CurrentEntityType, Range<String.UnicodeScalarView.Index>)?
    
    func commitEntity(_ unicodeScalars: String.UnicodeScalarView, _ type: CurrentEntityType, _ range: Range<String.UnicodeScalarView.Index>, _ entities: inout [MessageTextEntity]) {
        let indexRange: Range<Int> = unicodeScalars.distance(from: unicodeScalars.startIndex, to: range.lowerBound) ..< unicodeScalars.distance(from: unicodeScalars.startIndex, to: range.upperBound)
        var overlaps = false
        for entity in entities {
            if entity.range.overlaps(indexRange) {
                overlaps = true
                break
            }
        }
        if !overlaps {
            let entityType: MessageTextEntityType
            switch type {
                case .command:
                    entityType = .BotCommand
                case .mention:
                    entityType = .Mention
                case .hashtag:
                    entityType = .Hashtag
            }
            entities.append(MessageTextEntity(range: indexRange, type: entityType))
        }
    }
    while index != unicodeScalars.endIndex {
        let c = unicodeScalars[index]
        if c == "/" {
            if let (type, range) = currentEntity {
                commitEntity(unicodeScalars, type, range, &entities)
            }
            currentEntity = (.command, index ..< index)
        } else if c == "@" {
            if let (type, range) = currentEntity {
                if case .command = type {
                    currentEntity = (type, range.lowerBound ..< unicodeScalars.index(after: index))
                } else {
                    commitEntity(unicodeScalars, type, range, &entities)
                    currentEntity = (.mention, index ..< index)
                }
            } else {
                currentEntity = (.mention, index ..< index)
            }
        } else if c == "#" {
            if let (type, range) = currentEntity {
                commitEntity(unicodeScalars, type, range, &entities)
            }
            currentEntity = (.hashtag, index ..< index)
        } else {
            if let (type, range) = currentEntity {
                switch type {
                    case .command, .mention:
                        if validIdentifierSet.contains(c) {
                            currentEntity = (type, range.lowerBound ..< unicodeScalars.index(after: index))
                        } else if identifierDelimiterSet.contains(c) {
                            if let (type, range) = currentEntity {
                                commitEntity(unicodeScalars, type, range, &entities)
                            }
                            currentEntity = nil
                        }
                    case .hashtag:
                        if alphanumericSet.contains(c) {
                            currentEntity = (type, range.lowerBound ..< unicodeScalars.index(after: index))
                        } else if identifierDelimiterSet.contains(c) {
                            if let (type, range) = currentEntity {
                                commitEntity(unicodeScalars, type, range, &entities)
                            }
                            currentEntity = nil
                        }
                }
            }
        }
        index = unicodeScalars.index(after: index)
    }
    if let (type, range) = currentEntity {
        commitEntity(unicodeScalars, type, range, &entities)
    }
    
    return entities
}

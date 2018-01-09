import Foundation
import TelegramCore

private let dataDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType([.link]).rawValue)
private let dataAndPhoneNumberDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType([.link, .phoneNumber]).rawValue)
private let phoneNumberDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType([.phoneNumber]).rawValue)
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
    
    var type: EnabledEntityTypes {
        switch self {
            case .command:
                return .command
            case .mention:
                return .mention
            case .hashtag:
                return .hashtag
        }
    }
}

struct EnabledEntityTypes: OptionSet {
    var rawValue: Int32
    
    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    static let command = EnabledEntityTypes(rawValue: 1 << 0)
    static let mention = EnabledEntityTypes(rawValue: 1 << 1)
    static let hashtag = EnabledEntityTypes(rawValue: 1 << 2)
    static let url = EnabledEntityTypes(rawValue: 1 << 3)
    static let phoneNumber = EnabledEntityTypes(rawValue: 1 << 4)
    
    static let all: EnabledEntityTypes = [.command, .mention, .hashtag, .url, .phoneNumber]
}

private func commitEntity(_ utf16: String.UTF16View, _ type: CurrentEntityType, _ range: Range<String.UTF16View.Index>, _ enabledTypes: EnabledEntityTypes, _ entities: inout [MessageTextEntity]) {
    if !enabledTypes.contains(type.type) {
        return
    }
    let indexRange: Range<Int> = utf16.distance(from: utf16.startIndex, to: range.lowerBound) ..< utf16.distance(from: utf16.startIndex, to: range.upperBound)
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

func generateTextEntities(_ text: String, enabledTypes: EnabledEntityTypes) -> [MessageTextEntity] {
    var entities: [MessageTextEntity] = []
    
    let utf16 = text.utf16
    
    var detector: NSDataDetector?
    if enabledTypes.contains(.phoneNumber) && enabledTypes.contains(.url) {
        detector = dataAndPhoneNumberDetector
    } else if enabledTypes.contains(.phoneNumber) {
        detector = phoneNumberDetector
    } else if enabledTypes.contains(.url) {
        detector = dataDetector
    }
    
    if let detector = detector {
        detector.enumerateMatches(in: text, options: [], range: NSMakeRange(0, utf16.count), using: { result, _, _ in
            if let result = result {
                if result.resultType == NSTextCheckingResult.CheckingType.link || result.resultType == NSTextCheckingResult.CheckingType.phoneNumber {
                    let lowerBound = utf16.index(utf16.startIndex, offsetBy: result.range.location).samePosition(in: text)
                    let upperBound = utf16.index(utf16.startIndex, offsetBy: result.range.location + result.range.length).samePosition(in: text)
                    if let lowerBound = lowerBound, let upperBound = upperBound {
                        let type: MessageTextEntityType
                        if result.resultType == NSTextCheckingResult.CheckingType.link {
                            type = .Url
                        } else {
                            type = .PhoneNumber
                        }
                        entities.append(MessageTextEntity(range: utf16.distance(from: text.startIndex, to: lowerBound) ..< utf16.distance(from: text.startIndex, to: upperBound), type: type))
                    }
                }
            }
        })
    }
    
    var index = utf16.startIndex
    var currentEntity: (CurrentEntityType, Range<String.UTF16View.Index>)?
    
    var previousScalar: UnicodeScalar?
    while index != utf16.endIndex {
        let c = utf16[index]
        let scalar = UnicodeScalar(c)
        var notFound = true
        if let scalar = scalar {
            if scalar == "/" {
                notFound = false
                if previousScalar != nil && !identifierDelimiterSet.contains(previousScalar!) {
                    currentEntity = nil
                } else {
                    if let (type, range) = currentEntity {
                        commitEntity(utf16, type, range, enabledTypes, &entities)
                    }
                    currentEntity = (.command, index ..< index)
                }
            } else if scalar == "@" {
                notFound = false
                if let (type, range) = currentEntity {
                    if case .command = type {
                        currentEntity = (type, range.lowerBound ..< utf16.index(after: index))
                    } else {
                        commitEntity(utf16, type, range, enabledTypes, &entities)
                        currentEntity = (.mention, index ..< index)
                    }
                } else {
                    currentEntity = (.mention, index ..< index)
                }
            } else if scalar == "#" {
                notFound = false
                if let (type, range) = currentEntity {
                    commitEntity(utf16, type, range, enabledTypes, &entities)
                }
                currentEntity = (.hashtag, index ..< index)
            }
        
            if notFound {
                if let (type, range) = currentEntity {
                    switch type {
                        case .command, .mention:
                            if validIdentifierSet.contains(scalar) {
                                currentEntity = (type, range.lowerBound ..< utf16.index(after: index))
                            } else if identifierDelimiterSet.contains(scalar) {
                                if let (type, range) = currentEntity {
                                    commitEntity(utf16, type, range, enabledTypes, &entities)
                                }
                                currentEntity = nil
                            }
                        case .hashtag:
                            if alphanumericSet.contains(scalar) {
                                currentEntity = (type, range.lowerBound ..< utf16.index(after: index))
                            } else if identifierDelimiterSet.contains(scalar) {
                                if let (type, range) = currentEntity {
                                    commitEntity(utf16, type, range, enabledTypes, &entities)
                                }
                                currentEntity = nil
                            }
                    }
                }
            }
        }
        index = utf16.index(after: index)
        previousScalar = scalar
    }
    if let (type, range) = currentEntity {
        commitEntity(utf16, type, range, enabledTypes, &entities)
    }
    
    return entities
}

func addLocallyGeneratedEntities(_ text: String, enabledTypes: EnabledEntityTypes, entities: [MessageTextEntity]) -> [MessageTextEntity]? {
    var resultEntities = entities
    
    var hasDigits = false
    if enabledTypes.contains(.phoneNumber) {
        loop: for c in text.utf16 {
            if let scalar = UnicodeScalar(c) {
                if scalar >= "0" && scalar <= "9" {
                    hasDigits = true
                    break loop
                }
            }
        }
    }
    
    if hasDigits {
        if let phoneNumberDetector = phoneNumberDetector, enabledTypes.contains(.phoneNumber) {
            let utf16 = text.utf16
            phoneNumberDetector.enumerateMatches(in: text, options: [], range: NSMakeRange(0, utf16.count), using: { result, _, _ in
                if let result = result {
                    if result.resultType == NSTextCheckingResult.CheckingType.phoneNumber {
                        let lowerBound = utf16.index(utf16.startIndex, offsetBy: result.range.location).samePosition(in: text)
                        let upperBound = utf16.index(utf16.startIndex, offsetBy: result.range.location + result.range.length).samePosition(in: text)
                        if let lowerBound = lowerBound, let upperBound = upperBound {
                            let indexRange: Range<Int> = utf16.distance(from: text.startIndex, to: lowerBound) ..< utf16.distance(from: text.startIndex, to: upperBound)
                            var overlaps = false
                            for entity in resultEntities {
                                if entity.range.overlaps(indexRange) {
                                    overlaps = true
                                    break
                                }
                            }
                            if !overlaps {
                                resultEntities.append(MessageTextEntity(range: indexRange, type: .PhoneNumber))
                            }
                        }
                    }
                }
            })
        }
    }
    
    if resultEntities.count != entities.count {
        return resultEntities
    } else {
        return nil
    }
}

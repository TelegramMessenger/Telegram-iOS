import Foundation
import TelegramCore
import TextFormat

public struct SupportUserInfoContent: Equatable {
    public let text: String
    public let entities: [MessageTextEntity]

    public init(text: String, entities: [MessageTextEntity]) {
        self.text = text
        self.entities = entities
    }
}

public enum SupportUserInfoSaveDecision: Equatable {
    case close
    case confirmDelete
    case tooLong
    case save
}

public func supportUserInfoEditorText(_ info: SupportUserInfo?) -> NSAttributedString {
    guard let info else {
        return NSAttributedString()
    }
    return chatInputStateStringWithAppliedEntities(info.text, entities: info.entities)
}

public func supportUserInfoContent(fieldText: NSAttributedString, originalEntities: [MessageTextEntity]) -> SupportUserInfoContent {
    let text = trimChatInputText(convertMarkdownToAttributes(expandedInputStateAttributedString(fieldText)))
    let entities = generateChatInputTextEntities(text, generateLinks: false).map { entity -> MessageTextEntity in
        guard case let .FormattedDate(format, date) = entity.type, format == nil else {
            return entity
        }
        for original in originalEntities {
            if case let .FormattedDate(originalFormat, originalDate) = original.type, originalDate == date, originalFormat != nil {
                return MessageTextEntity(range: entity.range, type: original.type)
            }
        }
        return entity
    }
    return SupportUserInfoContent(text: text.string, entities: entities.sorted(by: { lhs, rhs in
        if lhs.range.lowerBound != rhs.range.lowerBound {
            return lhs.range.lowerBound < rhs.range.lowerBound
        }
        if lhs.range.upperBound != rhs.range.upperBound {
            return lhs.range.upperBound < rhs.range.upperBound
        }
        return String(describing: lhs.type) < String(describing: rhs.type)
    }))
}

public func supportUserInfoSaveDecision(original: SupportUserInfoContent, current: SupportUserInfoContent) -> SupportUserInfoSaveDecision {
    if current == original {
        return .close
    }
    if current.text.isEmpty {
        return .confirmDelete
    }
    if current.text.utf16.count > supportUserInfoMaxLength {
        return .tooLong
    }
    return .save
}

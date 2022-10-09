import Foundation
import Postbox
import TelegramCore

private let foreignAgentNoticePattern = #"\s*(?:ДАННОЕ\s+)?СООБЩЕНИЕ\s*\(МАТЕРИАЛ\)\s*СОЗДАНО\s+И\s*\(ИЛИ\)\s*РАСПРОСТРАНЕНО\s+(?:ИНОСТРАННЫМ\s+)?СРЕДСТВОМ\s+МАССОВОЙ\s+ИНФОРМАЦИИ,\s*ВЫПОЛНЯЮЩИМ\s+ФУНКЦИИ\s+ИНОСТРАННОГО\s+АГЕНТА,\s*И\s*\(ИЛИ\)\s*РОССИЙСКИМ\s+ЮРИДИЧЕСКИМ\s+ЛИЦОМ,\s*ВЫПОЛНЯЮЩИМ\s+ФУНКЦИИ\s+ИНОСТРАННОГО\s+АГЕНТА\.?\s*"#

public let foreignAgentNoticeRegEx = try! NSRegularExpression(pattern: foreignAgentNoticePattern, options: .caseInsensitive)

public func removeForeignAgentNotice(text: String, entities: [MessageTextEntity], mayRemoveWholeText: Bool) -> (text: String, entities: [MessageTextEntity]) {
    var newText = text
    var newEntities = entities
    let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
    let matches = foreignAgentNoticeRegEx.matches(in: text, range: nsrange)
    for match in matches.reversed() {
        if let range = Range(match.range, in: text), range.lowerBound != text.startIndex || range.upperBound != text.endIndex || mayRemoveWholeText {
            let replaceWith = (range.lowerBound == text.startIndex || range.upperBound == text.endIndex) ? "" : "\n\n"
            newText.replaceSubrange(range, with: replaceWith)
            for index in newEntities.indices.reversed() {
                let entity = newEntities[index]
                if entity.range.upperBound > match.range.lowerBound {
                    let l = entity.range.lowerBound > match.range.lowerBound ? max(entity.range.lowerBound - match.range.length + replaceWith.count, match.range.lowerBound) : entity.range.lowerBound
                    let u = max(entity.range.upperBound - match.range.length + replaceWith.count, match.range.lowerBound)
                    if (l..<u).isEmpty {
                        newEntities.remove(at: index)
                    } else {
                        newEntities[index] = MessageTextEntity(range: l..<u, type: entity.type)
                    }
                }
            }
        }
    }
    return (newText, newEntities)
}

public func removeForeignAgentNotice(text: String, entities: [MessageTextEntity], media: [Media]) -> (text: String, entities: [MessageTextEntity]) {
    return removeForeignAgentNotice(text: text, entities: entities, mayRemoveWholeText: mayRemoveWholeText(with: media))
}

public func removeForeignAgentNotice(text: String, mayRemoveWholeText: Bool) -> String {
    return removeForeignAgentNotice(text: text, entities: [], mayRemoveWholeText: mayRemoveWholeText).text
}

public func removeForeignAgentNotice(text: String, media: [Media]) -> String {
    return removeForeignAgentNotice(text: text, entities: [], mayRemoveWholeText: mayRemoveWholeText(with: media)).text
}

public func removeForeignAgentNotice(message: Message, inAssociatedPinnedMessageToo: Bool = false) -> Message {
    let entitiesIndex = message.attributes.firstIndex { $0 is TextEntitiesMessageAttribute }
    let entities = entitiesIndex != nil ? (message.attributes[entitiesIndex!] as! TextEntitiesMessageAttribute).entities : []
    let (newText, newEntities) = removeForeignAgentNotice(text: message.text, entities: entities, mayRemoveWholeText: mayRemoveWholeText(with: message.media))
    var newMessage = message
    if newText != message.text {
        if let entitiesIndex = entitiesIndex, (message.attributes[entitiesIndex] as! TextEntitiesMessageAttribute).entities != newEntities {
            var newAttributes = message.attributes
            newAttributes[entitiesIndex] = TextEntitiesMessageAttribute(entities: newEntities)
            newMessage = message.withUpdatedText(newText).withUpdatedAttributes(newAttributes)
        } else {
            newMessage = message.withUpdatedText(newText)
        }
    }
    if let pollIndex = newMessage.media.firstIndex(where: { $0 is TelegramMediaPoll }) {
        let poll = newMessage.media[pollIndex] as! TelegramMediaPoll
        let newPollText = removeForeignAgentNotice(text: poll.text, mayRemoveWholeText: false)
        if newPollText != poll.text {
            var newMedia = newMessage.media
            newMedia[pollIndex] = poll.withUpdatedText(newPollText)
            newMessage = newMessage.withUpdatedMedia(newMedia)
        }
    }
    if inAssociatedPinnedMessageToo,
       let action = newMessage.media.first(where: { $0 is TelegramMediaAction }) as? TelegramMediaAction,
       action.action == .pinnedMessageUpdated,
       let attribute = newMessage.attributes.first(where: { $0 is ReplyMessageAttribute }) as? ReplyMessageAttribute,
       let associatedMessage = newMessage.associatedMessages[attribute.messageId] {
        let newAssociatedMessage = removeForeignAgentNotice(message: associatedMessage)
        if newAssociatedMessage !== associatedMessage {
            var newAssociatedMessages = newMessage.associatedMessages
            newAssociatedMessages[attribute.messageId] = newAssociatedMessage
            newMessage = newMessage.withUpdatedAssociatedMessages(newAssociatedMessages)
        }
    }
    return newMessage
}

public func removeForeignAgentNotice(attrString string: NSAttributedString) -> NSAttributedString {
    var updated: NSMutableAttributedString?
    let text = string.string
    let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
    let matches = foreignAgentNoticeRegEx.matches(in: text, range: nsrange)
    for match in matches.reversed() {
        if let range = Range(match.range, in: text) {
            let replaceWith = (range.lowerBound == text.startIndex || range.upperBound == text.endIndex) ? "" : "\n\n"
            if updated == nil {
                updated = string.mutableCopy() as? NSMutableAttributedString
            }
            updated!.replaceCharacters(in: match.range, with: replaceWith)
        }
    }
    return updated ?? string
}

private func mayRemoveWholeText(with media: [Media]) -> Bool {
    return media.contains { $0 is TelegramMediaImage || $0 is TelegramMediaFile }
}

// Should be called after regular removeForeignAgentNotice() have not found a match.
// If constant foreignAgentNoticePattern changed, this function may need to be updated too.
public func removeForeignAgentNoticePartialMatchAtEnd(text: String, mayRemoveWholeText: Bool) -> String {
    let reStart = try! NSRegularExpression(pattern: #"\b(?:ДА|СО|(?i)данное\s+со|сообщение\s*\(ма)"#)
    let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
    let matches = reStart.matches(in: text, range: nsrange)
    if !matches.isEmpty {
        let flatPattern = foreignAgentNoticePattern
            .replacingOccurrences(of: #"\s+"#, with: " ")
            .replacingOccurrences(of: #"\s*"#, with: "")
            .replacingOccurrences(of: #"\(\?:[^)]+\)\?"#, with: "", options: .regularExpression, range: nil)
            .replacingOccurrences(of: #"\\\.\?$"#, with: "", options: .regularExpression, range: nil)
            .replacingOccurrences(of: "\\", with: "")
            .uppercased()

        for match in matches {
            if let range = Range(match.range, in: text) {
                let flatPartialMatch = text[range.lowerBound...]
                    .uppercased()
                    .replacingOccurrences(of: #"\.{3}|…$"#, with: "", options: .regularExpression, range: nil)
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression, range: nil)
                    .replacingOccurrences(of: " (", with: "(")
                    .replacingOccurrences(of: ") ", with: ")")
                    .replacingOccurrences(of: ", ", with: ",")
                    .replacingOccurrences(of: #"\bД(А|$)(Н|$)(Н|$)(О|$)(Е|$)( |$)"#, with: "", options: .regularExpression, range: nil)
                    .replacingOccurrences(of: #"\bИ(Н|$)(О|$)(С|$)(Т|$)(Р|$)(А|$)(Н|$)(Н|$)(Ы|$)(М|$)( |$)"#, with: "", options: .regularExpression, range: nil)
                
                if flatPattern.starts(with: flatPartialMatch) {
                    let result = text[..<range.lowerBound]
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !result.isEmpty {
                        let endingEllipses = text.hasSuffix("…") ? "…" : (text.hasSuffix("...") ? "..." : "")
                        return result + endingEllipses
                    } else if mayRemoveWholeText {
                        return result
                    } else {
                        return text
                    }
                }
            }
        }
    }
    return text
}

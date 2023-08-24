import Foundation
import Postbox
import TelegramCore

public func removeChannelSignature(text: String, entities: [MessageTextEntity], mayRemoveWholeText: Bool, username: String) -> (text: String, entities: [MessageTextEntity]) {
    var newText = text
    var newEntities = entities
    
    for entity in entities {
        var cmp: ((Range<String.Index>) -> Bool)?
        
        switch entity.type {
        case .Mention:
            cmp = { range in
                return text[range].caseInsensitiveCompare("@\(username)") == .orderedSame
            }
        case let .TextUrl(url):
            cmp = { _ in
                return url.caseInsensitiveCompare("https://t.me/\(username)") == .orderedSame
            }
        default:
            break
        }
        
        if let cmp, let range = Range(NSRange(entity.range), in: text) {
            if !range.isEmpty, range.upperBound == text.endIndex {
                if cmp(range) {
                    var removeStartIndex = range.lowerBound
                    while removeStartIndex > text.startIndex {
                        let prev = text.index(before: removeStartIndex)
                        if !text[prev].isWhitespace {
                            break
                        }
                        removeStartIndex = prev
                    }
                    if (removeStartIndex == text.startIndex && mayRemoveWholeText) || text.range(of: "\n", range: removeStartIndex..<range.lowerBound) != nil {
                        newText.removeSubrange(removeStartIndex...)
                        let nsRemovedRange = NSRange(removeStartIndex..., in: text)
                        for index in newEntities.indices.reversed() {
                            let entity = newEntities[index]
                            if entity.range.upperBound > nsRemovedRange.lowerBound {
                                if entity.range.lowerBound >= nsRemovedRange.lowerBound {
                                    newEntities.remove(at: index)
                                } else {
                                    newEntities[index] = MessageTextEntity(range: entity.range.lowerBound..<nsRemovedRange.lowerBound, type: entity.type)
                                }
                            }
                        }
                    }
                    break
                }
            }
        }
    }
    
    return (newText, newEntities)
}

public func removeChannelSignature(text: String, entities: [MessageTextEntity], media: [Media], username: String) -> (text: String, entities: [MessageTextEntity]) {
    return removeChannelSignature(text: text, entities: entities, mayRemoveWholeText: mayRemoveWholeText(with: media), username: username)
}

public func removeChannelSignature(message: Message, inAssociatedPinnedMessageToo: Bool = false) -> Message {
    guard let username = message.channelUsername else {
        return message
    }
    let entitiesIndex = message.attributes.firstIndex { $0 is TextEntitiesMessageAttribute }
    let entities = entitiesIndex != nil ? (message.attributes[entitiesIndex!] as! TextEntitiesMessageAttribute).entities : []
    let (newText, newEntities) = removeChannelSignature(text: message.text, entities: entities, mayRemoveWholeText: mayRemoveWholeText(with: message.media), username: username)
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
    if inAssociatedPinnedMessageToo,
       let action = newMessage.media.first(where: { $0 is TelegramMediaAction }) as? TelegramMediaAction,
       action.action == .pinnedMessageUpdated,
       let attribute = newMessage.attributes.first(where: { $0 is ReplyMessageAttribute }) as? ReplyMessageAttribute,
       let associatedMessage = newMessage.associatedMessages[attribute.messageId] {
        let newAssociatedMessage = removeChannelSignature(message: associatedMessage)
        if newAssociatedMessage !== associatedMessage {
            var newAssociatedMessages = newMessage.associatedMessages
            newAssociatedMessages[attribute.messageId] = newAssociatedMessage
            newMessage = newMessage.withUpdatedAssociatedMessages(newAssociatedMessages)
        }
    }
    return newMessage
}

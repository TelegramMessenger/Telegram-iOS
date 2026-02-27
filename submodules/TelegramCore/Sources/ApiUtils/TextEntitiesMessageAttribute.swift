import Foundation
import Postbox
import TelegramApi


func apiEntitiesFromMessageTextEntities(_ entities: [MessageTextEntity], associatedPeers: SimpleDictionary<PeerId, Peer>) -> [Api.MessageEntity] {
    var apiEntities: [Api.MessageEntity] = []
    
    for entity in entities {
        let offset: Int32 = Int32(entity.range.lowerBound)
        let length: Int32 = Int32(entity.range.upperBound - entity.range.lowerBound)
        switch entity.type {
            case .Unknown:
                break
            case .Mention:
                apiEntities.append(.messageEntityMention(.init(offset: offset, length: length)))
            case .Hashtag:
                apiEntities.append(.messageEntityHashtag(.init(offset: offset, length: length)))
            case .BotCommand:
                apiEntities.append(.messageEntityBotCommand(.init(offset: offset, length: length)))
            case .Url:
                apiEntities.append(.messageEntityUrl(.init(offset: offset, length: length)))
            case .Email:
                apiEntities.append(.messageEntityEmail(.init(offset: offset, length: length)))
            case .Bold:
                apiEntities.append(.messageEntityBold(.init(offset: offset, length: length)))
            case .Italic:
                apiEntities.append(.messageEntityItalic(.init(offset: offset, length: length)))
            case .Code:
                apiEntities.append(.messageEntityCode(.init(offset: offset, length: length)))
            case let .Pre(language):
                apiEntities.append(.messageEntityPre(.init(offset: offset, length: length, language: language ?? "")))
            case let .TextUrl(url):
                apiEntities.append(.messageEntityTextUrl(.init(offset: offset, length: length, url: url)))
            case let .TextMention(peerId):
                if let peer = associatedPeers[peerId], let inputUser = apiInputUser(peer) {
                    apiEntities.append(.inputMessageEntityMentionName(.init(offset: offset, length: length, userId: inputUser)))
                }
            case .PhoneNumber:
                break
            case .Strikethrough:
                apiEntities.append(.messageEntityStrike(.init(offset: offset, length: length)))
            case let .BlockQuote(isCollapsed):
                var flags: Int32 = 0
                if isCollapsed {
                    flags |= 1 << 0
                }
                apiEntities.append(.messageEntityBlockquote(.init(flags: flags, offset: offset, length: length)))
            case .Underline:
                apiEntities.append(.messageEntityUnderline(.init(offset: offset, length: length)))
            case .BankCard:
                apiEntities.append(.messageEntityBankCard(.init(offset: offset, length: length)))
            case .Spoiler:
                apiEntities.append(.messageEntitySpoiler(.init(offset: offset, length: length)))
            case let .CustomEmoji(_, fileId):
                apiEntities.append(.messageEntityCustomEmoji(.init(offset: offset, length: length, documentId: fileId)))
            case .Custom:
                break
        }
    }
    
    return apiEntities
}

func apiTextAttributeEntities(_ attribute: TextEntitiesMessageAttribute, associatedPeers: SimpleDictionary<PeerId, Peer>) -> [Api.MessageEntity] {
    return apiEntitiesFromMessageTextEntities(attribute.entities, associatedPeers: associatedPeers)
}

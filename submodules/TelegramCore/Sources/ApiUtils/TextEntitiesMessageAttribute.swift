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
                apiEntities.append(.messageEntityMention(offset: offset, length: length))
            case .Hashtag:
                apiEntities.append(.messageEntityHashtag(offset: offset, length: length))
            case .BotCommand:
                apiEntities.append(.messageEntityBotCommand(offset: offset, length: length))
            case .Url:
                apiEntities.append(.messageEntityUrl(offset: offset, length: length))
            case .Email:
                apiEntities.append(.messageEntityEmail(offset: offset, length: length))
            case .Bold:
                apiEntities.append(.messageEntityBold(offset: offset, length: length))
            case .Italic:
                apiEntities.append(.messageEntityItalic(offset: offset, length: length))
            case .Code:
                apiEntities.append(.messageEntityCode(offset: offset, length: length))
            case .Pre:
                apiEntities.append(.messageEntityPre(offset: offset, length: length, language: ""))
            case let .TextUrl(url):
                apiEntities.append(.messageEntityTextUrl(offset: offset, length: length, url: url))
            case let .TextMention(peerId):
                if let peer = associatedPeers[peerId], let inputUser = apiInputUser(peer) {
                    apiEntities.append(.inputMessageEntityMentionName(offset: offset, length: length, userId: inputUser))
                }
            case .PhoneNumber:
                break
            case .Strikethrough:
                apiEntities.append(.messageEntityStrike(offset: offset, length: length))
            case .BlockQuote:
                apiEntities.append(.messageEntityBlockquote(offset: offset, length: length))
            case .Underline:
                apiEntities.append(.messageEntityUnderline(offset: offset, length: length))
            case .BankCard:
                apiEntities.append(.messageEntityBankCard(offset: offset, length: length))
            case .Spoiler:
                apiEntities.append(.messageEntitySpoiler(offset: offset, length: length))
            case let .CustomEmoji(_, fileId):
                apiEntities.append(.messageEntityCustomEmoji(offset: offset, length: length, documentId: fileId))
            case .Custom:
                break
        }
    }
    
    return apiEntities
}

func apiTextAttributeEntities(_ attribute: TextEntitiesMessageAttribute, associatedPeers: SimpleDictionary<PeerId, Peer>) -> [Api.MessageEntity] {
    return apiEntitiesFromMessageTextEntities(attribute.entities, associatedPeers: associatedPeers)
}

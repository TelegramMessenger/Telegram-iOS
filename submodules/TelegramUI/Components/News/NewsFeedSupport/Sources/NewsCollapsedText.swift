import Foundation
import TelegramCore

/// The entities of a collapsed post's text (its first `length` UTF-16 units, then …): the whole text's, clipped to the
/// cut, so the cut is drawn exactly as the start of the whole text and Show more only reveals what follows. An entity
/// running across the cut takes the … (a quote or code block would otherwise close before it and put it on a line of
/// its own), as does a quote ending at the cut. An entity acting on its own text is never left cut in two: a bare URL
/// keeps its whole target as a text URL; a mention, hashtag, command, address, number, date or custom emoji (drawn
/// whole or not at all) is dropped, leaving its start plain on the last line.
///
/// A code block keeps its language only while its text is whole. Its highlighting is cached on the message under the
/// block's text, and the bubble replaces that cache with the highlight of the text it draws, so a cut block's would
/// push out the whole block's. One running across the cut loses its language; one ending at it takes the … only when it
/// has none, and is otherwise left as it is, the … after it.
public func newsCollapsedTextEntities(_ entities: [MessageTextEntity], text: NSString, length: Int) -> [MessageTextEntity] {
    var result: [MessageTextEntity] = []
    for entity in entities {
        let range = entity.range
        guard range.lowerBound >= 0, range.lowerBound < length, range.upperBound > range.lowerBound else {
            continue
        }
        var type = entity.type
        var upperBound = range.upperBound
        if range.upperBound > length {
            switch entity.type {
            case .Url:
                guard range.upperBound <= text.length else {
                    continue
                }
                type = .TextUrl(url: text.substring(with: NSRange(location: range.lowerBound, length: range.count)))
            case .Pre:
                type = .Pre(language: nil)
            case .Mention, .Hashtag, .BotCommand, .Email, .PhoneNumber, .BankCard, .TonAddress, .FormattedDate, .CustomEmoji, .Custom, .Unknown:
                continue
            default:
                break
            }
            upperBound = length + 1
        } else if range.upperBound == length {
            switch entity.type {
            case .BlockQuote:
                upperBound = length + 1
            case let .Pre(language) where language?.isEmpty ?? true:
                upperBound = length + 1
            default:
                break
            }
        }
        result.append(MessageTextEntity(range: range.lowerBound ..< upperBound, type: type))
    }
    return result
}

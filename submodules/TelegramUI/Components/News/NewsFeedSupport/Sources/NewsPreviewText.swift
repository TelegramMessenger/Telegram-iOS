import Foundation
import TelegramCore

/// A post's text cut to `maxLength` UTF-16 units (the unit entity ranges count in), with its entities cut to
/// match. A feed row shows three lines and is built on the main thread as it scrolls in, where building and
/// typesetting the whole of a long post cost as much as the rest of the row.
///
/// The cut never splits a composed character. An entity that runs past it is shortened, except a custom emoji
/// or a formatted date, which stand for their whole range and are dropped.
public func newsPreviewTextPrefix(_ text: String, entities: [MessageTextEntity], maxLength: Int) -> (text: String, entities: [MessageTextEntity]) {
    let string = text as NSString
    guard string.length > maxLength else {
        return (text, entities)
    }
    let cut = string.rangeOfComposedCharacterSequence(at: max(0, maxLength)).location
    var result: [MessageTextEntity] = []
    for entity in entities {
        if entity.range.lowerBound >= cut {
            continue
        }
        if entity.range.upperBound <= cut {
            result.append(entity)
            continue
        }
        switch entity.type {
        case .CustomEmoji, .FormattedDate:
            continue
        default:
            result.append(MessageTextEntity(range: entity.range.lowerBound ..< cut, type: entity.type))
        }
    }
    return (string.substring(to: cut), result)
}

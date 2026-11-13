import Foundation
import TelegramCore

public struct TrailingHashtagFooter: Equatable {
    public let textEnd: Int
    public let hashtags: [String]
}

public func trailingHashtagFooter(text: String, entities: [MessageTextEntity], isCaption: Bool = false) -> TrailingHashtagFooter? {
    guard let range = trailingHashtagBlockRange(text: text, entities: entities) else {
        return nil
    }
    let string = text as NSString
    var textEnd = range.lowerBound
    while textEnd > 0, CharacterSet.whitespacesAndNewlines.contains(UnicodeScalar(string.character(at: textEnd - 1)) ?? "a") {
        textEnd -= 1
    }
    if textEnd == 0 && !isCaption {
        return nil
    }
    let hashtags = entities.compactMap { entity -> String? in
        guard case .Hashtag = entity.type, entity.range.lowerBound >= range.lowerBound, entity.range.upperBound <= string.length else {
            return nil
        }
        return string.substring(with: NSRange(location: entity.range.lowerBound, length: entity.range.count))
    }
    return TrailingHashtagFooter(textEnd: textEnd, hashtags: hashtags)
}

public func trailingTagsExpandedPositions(taggedPositions: [Int], unreadDividerPosition: Int?, collapsesMiddle: Bool, reachesStart: Bool, reachesEnd: Bool) -> Set<Int> {
    if !collapsesMiddle {
        return Set(taggedPositions)
    }
    var result = Set<Int>()
    if reachesStart, let first = taggedPositions.first {
        result.insert(first)
    }
    if let unreadDividerPosition, let firstUnread = taggedPositions.first(where: { $0 > unreadDividerPosition }) {
        result.insert(firstUnread)
    }
    if reachesEnd, let last = taggedPositions.last {
        result.insert(last)
    }
    return result
}

public func trailingHashtagBlockRange(text: String, entities: [MessageTextEntity]) -> Range<Int>? {
    let string = text as NSString
    let hashtags = entities.compactMap { entity -> Range<Int>? in
        if case .Hashtag = entity.type {
            return entity.range
        }
        return nil
    }
    var blockStart = string.length
    var blockEnd = string.length
    var hashtagCount = 0
    var lineEnd = string.length
    while lineEnd > 0 {
        let lineRange = string.lineRange(for: NSRange(location: lineEnd - 1, length: 0))
        let line = string.substring(with: lineRange)
        let filledLength = line.unicodeScalars.reduce(0) { result, scalar in
            return CharacterSet.whitespacesAndNewlines.contains(scalar) ? result : result + String(scalar).utf16.count
        }
        lineEnd = lineRange.location
        if filledLength == 0 {
            if hashtagCount != 0 {
                break
            }
            blockEnd = lineRange.location
            continue
        }
        let lineHashtags = hashtags.filter { $0.lowerBound >= lineRange.location && $0.upperBound <= lineRange.location + lineRange.length }
        let hashtagLength = lineHashtags.reduce(0) { $0 + $1.count }
        if lineHashtags.isEmpty || hashtagLength * 2 < filledLength {
            break
        }
        hashtagCount += lineHashtags.count
        blockStart = lineRange.location
    }
    while blockEnd > blockStart, CharacterSet.whitespacesAndNewlines.contains(UnicodeScalar(string.character(at: blockEnd - 1)) ?? "a") {
        blockEnd -= 1
    }
    if hashtagCount < 3 || blockStart >= blockEnd {
        return nil
    }
    let range = blockStart ..< blockEnd
    for entity in entities {
        switch entity.type {
        case .BlockQuote, .Pre, .Code:
            if entity.range.overlaps(range) {
                return nil
            }
        default:
            break
        }
    }
    return range
}

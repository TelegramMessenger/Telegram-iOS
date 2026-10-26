import Foundation

/// Locates a rich message's custom emoji in its notification body.
///
/// An ordinary message's custom emoji are entities with ranges in its text. A rich message carries them inside its
/// page, and its push body is the server's plain text of the page, with each emoji's alt text in its place. `emoji` is
/// the page's emoji in reading order (`InstantPage.customEmojiOccurrences`). Per alt text, the page's emoji take the
/// body's whole-character occurrences of it (so "❤" never matches inside "❤️") at or after `location` (UTF-16), in
/// order. When the body has more occurrences of an alt text than the page has emoji with it, an ordinary emoji is
/// among them and nothing tells which is custom: those emoji stay plain rather than put a glyph on the wrong one. A
/// body with fewer (truncated) maps the ones it keeps. An emoji with an empty alt text is skipped.
func notificationRichTextCustomEmoji(body: String, from location: Int, emoji: [(fileId: Int64, alt: String)]) -> [(range: Range<Int>, fileId: Int64)] {
    let string = body as NSString
    let location = max(0, min(location, string.length))

    func occurrences(of alt: String) -> [Range<Int>] {
        var result: [Range<Int>] = []
        var searchLocation = location
        while searchLocation < string.length {
            let found = string.range(of: alt, options: .literal, range: NSRange(location: searchLocation, length: string.length - searchLocation))
            if found.location == NSNotFound {
                break
            }
            if string.rangeOfComposedCharacterSequences(for: found) == found {
                result.append(found.location ..< NSMaxRange(found))
                searchLocation = NSMaxRange(found)
            } else {
                searchLocation = found.location + 1
            }
        }
        return result
    }

    var pageCounts: [String: Int] = [:]
    for item in emoji where !item.alt.isEmpty {
        pageCounts[item.alt, default: 0] += 1
    }
    var bodyRanges: [String: [Range<Int>]] = [:]
    for (alt, pageCount) in pageCounts {
        let ranges = occurrences(of: alt)
        if ranges.count <= pageCount {
            bodyRanges[alt] = ranges
        }
    }

    var result: [(range: Range<Int>, fileId: Int64)] = []
    var used: [String: Int] = [:]
    for item in emoji {
        guard let ranges = bodyRanges[item.alt] else {
            continue
        }
        let index = used[item.alt, default: 0]
        if index < ranges.count {
            result.append((ranges[index], item.fileId))
            used[item.alt] = index + 1
        }
    }
    return result
}

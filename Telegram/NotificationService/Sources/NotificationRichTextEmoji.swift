import Foundation

/// Locates a rich message's custom emoji in its notification body.
///
/// An ordinary message's custom emoji are entities with ranges in its text. A rich message carries them inside its
/// page, and its push body is the server's plain text of the page, with each emoji's alt text in its place. `emoji` is
/// the page's emoji in reading order (`InstantPage.customEmojiOccurrences`); each is matched to the next occurrence of
/// its alt text at or after `location` (UTF-16) that is a whole character, so "❤" never matches inside "❤️". An emoji
/// whose alt text is empty or not found is skipped and does not move the search on.
func notificationRichTextCustomEmoji(body: String, from location: Int, emoji: [(fileId: Int64, alt: String)]) -> [(range: Range<Int>, fileId: Int64)] {
    let string = body as NSString
    var result: [(range: Range<Int>, fileId: Int64)] = []
    var location = max(0, min(location, string.length))
    for item in emoji {
        if item.alt.isEmpty {
            continue
        }
        var searchLocation = location
        while searchLocation < string.length {
            let found = string.range(of: item.alt, options: .literal, range: NSRange(location: searchLocation, length: string.length - searchLocation))
            if found.location == NSNotFound {
                break
            }
            if string.rangeOfComposedCharacterSequences(for: found) == found {
                result.append((found.location ..< NSMaxRange(found), item.fileId))
                location = NSMaxRange(found)
                break
            }
            searchLocation = found.location + 1
        }
    }
    return result
}

import Foundation

/// Locates a rich message's custom emoji in its notification body.
///
/// An ordinary message's custom emoji are entities with ranges in its text. A rich message carries them inside its
/// page, and its push body is the server's plain text of the page, with each emoji's alt text in its place. `runs` is
/// the page's text in reading order (`InstantPage.customEmojiTextRuns`): plain text, and each custom emoji as its alt
/// text with its file id. Occurrences are whole characters ("❤" never matches inside "❤️"), searched in the body at or
/// after `location` (UTF-16).
///
/// The body may leave blocks out (a table, a caption) or be truncated, and the page may have the same emoji as plain
/// text too, so an occurrence in the body is mapped only where that cannot pick the wrong one. Per alt text, counting
/// every occurrence in the page, plain ones included:
/// - all of them are the same custom emoji: each occurrence in the body is that emoji, provided the body has no more
///   of them than the page;
/// - otherwise the body must have exactly the page's occurrences, taken in order, and the custom ones get their emoji.
/// Anything else stays plain rather than put a glyph on a plain emoji or on another custom one. An emoji with an empty
/// alt text is skipped.
func notificationRichTextCustomEmoji(body: String, from location: Int, runs: [(text: String, customEmojiFileId: Int64?)]) -> [(range: Range<Int>, fileId: Int64)] {
    func occurrences(of alt: String, in string: NSString, from location: Int) -> [Range<Int>] {
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

    let bodyString = body as NSString
    let location = max(0, min(location, bodyString.length))

    var alts: [String] = []
    for run in runs where run.customEmojiFileId != nil && !run.text.isEmpty && !alts.contains(run.text) {
        alts.append(run.text)
    }

    var result: [(range: Range<Int>, fileId: Int64)] = []
    for alt in alts {
        // The page's occurrences of `alt` in reading order: a custom emoji's file id, or nil for plain text (which
        // includes another custom emoji whose alt text contains this one).
        var page: [Int64?] = []
        for run in runs {
            if let fileId = run.customEmojiFileId, run.text == alt {
                page.append(fileId)
            } else {
                for _ in occurrences(of: alt, in: run.text as NSString, from: 0) {
                    page.append(nil)
                }
            }
        }
        let bodyRanges = occurrences(of: alt, in: bodyString, from: location)

        if let first = page.first, let fileId = first, page.allSatisfy({ $0 == fileId }) {
            if bodyRanges.count <= page.count {
                for range in bodyRanges {
                    result.append((range, fileId))
                }
            }
        } else if bodyRanges.count == page.count {
            for (range, fileId) in zip(bodyRanges, page) {
                if let fileId {
                    result.append((range, fileId))
                }
            }
        }
    }
    return result.sorted(by: { $0.range.lowerBound < $1.range.lowerBound })
}

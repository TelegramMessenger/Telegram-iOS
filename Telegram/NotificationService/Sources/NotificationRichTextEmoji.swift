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
/// every occurrence in the page's text (the runs joined, searched like the body), plain ones included, and taking an
/// occurrence as a custom emoji only where it is exactly that emoji's run:
/// - all of them are the same custom emoji: each occurrence in the body is that emoji, provided the body has no more
///   of them than the page;
/// - otherwise the body must have exactly the page's occurrences, taken in order, and the custom ones get their emoji.
/// The runs put each block-level text unit on its own line, so text never fuses across units in the page. This assumes
/// the body also separates units by at least one character that does not attach to the one before it (a newline or a
/// space); a body that ran two units together could join an alt text across them and misplace a glyph.
/// Anything else stays plain rather than put a glyph on a plain emoji or on another custom one, and so do two mapped
/// emoji that overlap in the body. An emoji with an empty alt text is skipped.
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

    // The page's text, and where each custom emoji sits in it. Occurrences are searched in the page exactly as in the
    // body, across run boundaries, so an alt text spanning two runs or containing another is counted alike in both.
    let pageString = runs.map(\.text).joined() as NSString
    var customSpans: [Range<Int>: (fileId: Int64, alt: String)] = [:]
    var alts: [String] = []
    var offset = 0
    for run in runs {
        let length = (run.text as NSString).length
        // An alt text is an emoji; a long one, or too many distinct ones, would only cost the extension's time.
        if let fileId = run.customEmojiFileId, !run.text.isEmpty, length <= 64 {
            customSpans[offset ..< offset + length] = (fileId, run.text)
            if !alts.contains(run.text) && alts.count < 64 {
                alts.append(run.text)
            }
        }
        offset += length
    }

    var result: [(range: Range<Int>, fileId: Int64)] = []
    for alt in alts {
        // The page's occurrences of `alt` in reading order: a custom emoji's file id where an occurrence is exactly
        // that emoji, nil for any other (plain text, or one straddling or inside another custom emoji).
        let page: [Int64?] = occurrences(of: alt, in: pageString, from: 0).map { range in
            if let span = customSpans[range], span.alt == alt {
                return span.fileId
            } else {
                return nil
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
    // Two alt texts can still claim overlapping text in a body that differs from the page; neither is then certain.
    // Sorted by start, every member of a run of chained overlaps overlaps another member, so only lone ones stay.
    var mapped: [(range: Range<Int>, fileId: Int64)] = []
    var cluster: [(range: Range<Int>, fileId: Int64)] = []
    var clusterEnd = 0
    for item in result.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) {
        if !cluster.isEmpty && item.range.lowerBound < clusterEnd {
            cluster.append(item)
            clusterEnd = max(clusterEnd, item.range.upperBound)
        } else {
            if cluster.count == 1 {
                mapped.append(cluster[0])
            }
            cluster = [item]
            clusterEnd = item.range.upperBound
        }
    }
    if cluster.count == 1 {
        mapped.append(cluster[0])
    }
    return mapped
}

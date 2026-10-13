import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TextFormat

public final class InstantPageMultiTextAdapter: ASDisplayNode, TextNodeProtocol {
    public struct Entry {
        public let item: InstantPageTextItem
        public let frameOrigin: CGPoint

        public init(item: InstantPageTextItem, frameOrigin: CGPoint) {
            self.item = item
            self.frameOrigin = frameOrigin
        }
    }

    private struct InternalEntry {
        let item: InstantPageTextItem
        let charOffset: Int
        let frameOrigin: CGPoint
    }

    private let entries: [InternalEntry]
    private let combinedString: NSAttributedString

    public init(entries: [Entry]) {
        let separator = NSAttributedString(string: "\n\n")
        let combined = NSMutableAttributedString()
        var internalEntries: [InternalEntry] = []
        for (index, entry) in entries.enumerated() {
            let charOffset = combined.length
            internalEntries.append(InternalEntry(item: entry.item, charOffset: charOffset, frameOrigin: entry.frameOrigin))
            combined.append(entry.item.attributedString)
            if index != entries.count - 1 {
                combined.append(separator)
            }
        }
        self.entries = internalEntries
        // `currentText` is what Translate / Share / Look Up receive for a selection, so the inline-attachment
        // placeholder (`U+FFFC`) must not reach them as a literal object-replacement box. Substituting a
        // space is safe for every OTHER consumer because it is length-preserving in UTF-16 — the offsets
        // `attributesAtPoint` and `textRangeRects(in:)` hand out stay valid — and `markdownForRange` reads
        // the per-entry strings, not this one, so the emoji marker it emits is unaffected.
        combined.replaceOccurrences(ofPlaceholder: instantPageInlineAttachmentPlaceholder, with: " ")
        self.combinedString = combined
        super.init()
        self.isUserInteractionEnabled = false
    }

    public var currentText: NSAttributedString? {
        return self.combinedString
    }

    public func attributesAtPoint(_ point: CGPoint, orNearest: Bool) -> (Int, [NSAttributedString.Key: Any])? {
        for entry in self.entries {
            let localPoint = CGPoint(x: point.x - entry.frameOrigin.x, y: point.y - entry.frameOrigin.y)
            if let (localIndex, attrs) = entry.item.attributesAtPoint(localPoint, orNearest: false) {
                return (entry.charOffset + localIndex, attrs)
            }
        }
        guard orNearest, !self.entries.isEmpty else {
            return nil
        }
        var nearestEntry = self.entries[0]
        var nearestDistance = CGFloat.greatestFiniteMagnitude
        for entry in self.entries {
            let frame = CGRect(origin: entry.frameOrigin, size: entry.item.frame.size)
            let distance: CGFloat
            if point.y < frame.minY {
                distance = frame.minY - point.y
            } else if point.y > frame.maxY {
                distance = point.y - frame.maxY
            } else {
                distance = 0.0
            }
            if distance < nearestDistance {
                nearestDistance = distance
                nearestEntry = entry
            }
        }
        let localPoint = CGPoint(x: point.x - nearestEntry.frameOrigin.x, y: point.y - nearestEntry.frameOrigin.y)
        if let (localIndex, attrs) = nearestEntry.item.attributesAtPoint(localPoint, orNearest: true) {
            return (nearestEntry.charOffset + localIndex, attrs)
        }
        return nil
    }

    public func textRangeRects(in range: NSRange) -> (rects: [CGRect], start: TextRangeRectEdge, end: TextRangeRectEdge)? {
        var allRects: [CGRect] = []
        var startEdge: TextRangeRectEdge?
        var endEdge: TextRangeRectEdge?
        for entry in self.entries {
            let itemLength = entry.item.attributedString.length
            let entryRange = NSRange(location: entry.charOffset, length: itemLength)
            let intersection = NSIntersectionRange(range, entryRange)
            if intersection.length == 0 {
                continue
            }
            let localRange = NSRange(location: intersection.location - entry.charOffset, length: intersection.length)
            guard let result = entry.item.textRangeRects(in: localRange) else {
                continue
            }
            for rect in result.rects {
                allRects.append(rect.offsetBy(dx: entry.frameOrigin.x, dy: entry.frameOrigin.y))
            }
            let translatedStart = TextRangeRectEdge(x: result.start.x + entry.frameOrigin.x, y: result.start.y + entry.frameOrigin.y, height: result.start.height)
            let translatedEnd = TextRangeRectEdge(x: result.end.x + entry.frameOrigin.x, y: result.end.y + entry.frameOrigin.y, height: result.end.height)
            if startEdge == nil {
                startEdge = translatedStart
            }
            endEdge = translatedEnd
        }
        guard !allRects.isEmpty, let start = startEdge, let end = endEdge else {
            return nil
        }
        return (allRects, start, end)
    }

    public func markdownForRange(_ range: NSRange) -> String {
        struct Segment {
            let context: InstantPageMarkdownBlockContext?
            let inline: String
        }

        var segments: [Segment] = []
        for entry in self.entries {
            let entryRange = NSRange(location: entry.charOffset, length: entry.item.attributedString.length)
            let intersection = NSIntersectionRange(range, entryRange)
            if intersection.length == 0 {
                continue
            }
            let localRange = NSRange(location: intersection.location - entry.charOffset, length: intersection.length)
            let slice = entry.item.attributedString.attributedSubstring(from: localRange)
            let inline = inlineMarkdown(from: slice)
            if inline.isEmpty {
                continue
            }
            segments.append(Segment(context: entry.item.markdownContext, inline: inline))
        }
        if segments.isEmpty {
            return ""
        }

        func quotePrefixed(_ text: String, depth: Int) -> String {
            guard depth > 0 else { return text }
            let q = String(repeating: ">", count: depth) + " "
            return text.split(separator: "\n", omittingEmptySubsequences: false).map { q + String($0) }.joined(separator: "\n")
        }

        func taskMarker(_ c: Bool?) -> String {
            switch c {
            case .some(false): return "[ ] "
            case .some(true): return "[x] "
            case .none: return ""
            }
        }

        // Renders one segment's block content WITHOUT the quote prefix and without
        // cross-segment coalescing. Used for segments inside a quoted run, where each
        // line carries its own depth and the whole quote is one `\n`-joined block.
        func renderContent(_ seg: Segment) -> String {
            switch seg.context?.kind {
            case let .code(language):
                return "```\(language ?? "")\n\(seg.inline)\n```"
            case .tableCell:
                return "| " + escapeSelectionTableCell(seg.inline) + " |"
            case let .listItem(_, marker, checked):
                return "\(marker) \(taskMarker(checked))" + seg.inline.replacingOccurrences(of: "\n", with: " ")
            case let .heading(level):
                let hashes = String(repeating: "#", count: max(1, min(6, level)))
                return "\(hashes) \(seg.inline)"
            case .title:
                return "# \(seg.inline)"
            case .paragraph, .none:
                return seg.inline
            }
        }

        var groups: [String] = []
        var index = 0
        while index < segments.count {
            let seg = segments[index]
            let depth = seg.context?.quoteDepth ?? 0

            // A blockquote is exploded by the layout into one text item per child line,
            // each stamped with quoteDepth > 0. Re-coalesce a run of consecutive quoted
            // segments into a single block whose lines are joined by `\n` (each carrying
            // its own `> ` depth), matching the whole-message converter — otherwise every
            // quote line would become its own block and be separated by a blank line.
            if depth > 0 {
                var lines: [String] = []
                var j = index
                while j < segments.count, let d = segments[j].context?.quoteDepth, d > 0 {
                    lines.append(quotePrefixed(renderContent(segments[j]), depth: d))
                    j += 1
                }
                groups.append(lines.joined(separator: "\n"))
                index = j
                continue
            }

            switch seg.context?.kind {
            case let .code(language):
                var body = [seg.inline]
                var j = index + 1
                while j < segments.count,
                      case let .code(lang2)? = segments[j].context?.kind,
                      lang2 == language,
                      (segments[j].context?.quoteDepth ?? 0) == depth {
                    body.append(segments[j].inline)
                    j += 1
                }
                let fence = "```\(language ?? "")\n" + body.joined(separator: "\n") + "\n```"
                groups.append(quotePrefixed(fence, depth: depth))
                index = j
            case let .tableCell(row, _, _):
                var rows: [[String]] = [[escapeSelectionTableCell(seg.inline)]]
                var currentRow = row
                var j = index + 1
                while j < segments.count,
                      case let .tableCell(row2, _, _)? = segments[j].context?.kind,
                      (segments[j].context?.quoteDepth ?? 0) == depth {
                    if row2 != currentRow {
                        rows.append([])
                        currentRow = row2
                    }
                    rows[rows.count - 1].append(escapeSelectionTableCell(segments[j].inline))
                    j += 1
                }
                let tableBlock = rows.map { "| " + $0.joined(separator: " | ") + " |" }.joined(separator: "\n")
                groups.append(quotePrefixed(tableBlock, depth: depth))
                index = j
            case let .listItem(_, marker, checked):
                let firstLine = "\(marker) \(taskMarker(checked))" + seg.inline.replacingOccurrences(of: "\n", with: " ")
                var lines = [firstLine]
                var j = index + 1
                while j < segments.count, case let .listItem(_, marker2, checked2)? = segments[j].context?.kind, (segments[j].context?.quoteDepth ?? 0) == depth {
                    lines.append("\(marker2) \(taskMarker(checked2))" + segments[j].inline.replacingOccurrences(of: "\n", with: " "))
                    j += 1
                }
                groups.append(quotePrefixed(lines.joined(separator: "\n"), depth: depth))
                index = j
            case let .heading(level):
                let hashes = String(repeating: "#", count: max(1, min(6, level)))
                groups.append(quotePrefixed("\(hashes) \(seg.inline)", depth: depth))
                index += 1
            case .title:
                groups.append(quotePrefixed("# \(seg.inline)", depth: depth))
                index += 1
            case .paragraph, .none:
                groups.append(quotePrefixed(seg.inline, depth: depth))
                index += 1
            }
        }

        return groups.joined(separator: "\n\n")
    }
}

private extension NSMutableAttributedString {
    /// Swaps every occurrence of a ONE-character placeholder for another one-character string, keeping
    /// each occurrence's attributes (`replaceCharacters(in:with:)` inherits them from the first replaced
    /// character) and, because both sides are one UTF-16 unit, every offset into the string.
    func replaceOccurrences(ofPlaceholder placeholder: String, with replacement: String) {
        guard placeholder.utf16.count == 1, replacement.utf16.count == 1 else {
            assertionFailure("both sides must be one UTF-16 unit or offsets shift")
            return
        }
        var searchRange = NSRange(location: 0, length: self.length)
        while true {
            let found = (self.string as NSString).range(of: placeholder, options: [], range: searchRange)
            guard found.location != NSNotFound else {
                return
            }
            self.replaceCharacters(in: found, with: replacement)
            let next = found.upperBound
            searchRange = NSRange(location: next, length: self.length - next)
        }
    }
}

private func escapeSelectionMarkdown(_ string: String) -> String {
    var result = ""
    result.reserveCapacity(string.count)
    for character in string {
        switch character {
        case "\\", "*", "_", "`", "[", "]", "~", "|":
            result.append("\\")
            result.append(character)
        default:
            result.append(character)
        }
    }
    return result
}

private func escapeSelectionTableCell(_ string: String) -> String {
    return string.replacingOccurrences(of: "\n", with: " ")
}

/// Converts a styled slice of an InstantPage text item into inline markdown,
/// reading the same attributes the renderer wrote (font-based bold/italic/mono,
/// strikethrough style, the TelegramTextAttributes.URL link item, custom emoji).
private func inlineMarkdown(from slice: NSAttributedString) -> String {
    let fullRange = NSRange(location: 0, length: slice.length)
    var result = ""

    slice.enumerateAttributes(in: fullRange, options: []) { attributes, range, _ in
        // Every inline attachment (emoji / image / formula / button pill) occupies one
        // `instantPageInlineAttachmentPlaceholder` (`U+FFFC`) cell. That character is layout machinery
        // and must never reach the clipboard: the emoji branch below replaces it with its marker, and
        // for the attachments this converter has no markdown for (image / formula / pill) a space is
        // what a reader expects to see in its place — which is also the pre-`U+FFFC` behaviour.
        let substring = (slice.string as NSString)
            .substring(with: range)
            .replacingOccurrences(of: instantPageInlineAttachmentPlaceholder, with: " ")

        // Custom emoji: emit the shared marker carrying the fileId. The display
        // placeholder carries no real alt, so alt is best-effort; whole-message copy /
        // edit reconstruction have the true alt.
        if let emojiAttribute = attributes[ChatTextInputAttributes.customEmoji] as? ChatTextInputTextCustomEmojiAttribute {
            // Non-empty link text required: CommonMark drops `[](url)` on re-parse.
            let alt = substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? " " : substring
            result += "[\(escapeCustomEmojiMarkdownAlt(alt))](\(customEmojiMarkdownURL(fileId: emojiAttribute.fileId)))"
            return
        }

        var bold = false
        var italic = false
        var mono = false
        if let font = attributes[.font] as? UIFont {
            let name = font.fontName.lowercased()
            if name.hasPrefix(".sfui") || name.hasPrefix(".applesystemui") {
                let traits = font.fontDescriptor.symbolicTraits
                if traits.contains(.traitMonoSpace) {
                    mono = true
                } else {
                    bold = traits.contains(.traitBold)
                    italic = traits.contains(.traitItalic)
                }
            } else if name.contains("menlo") || name.contains("courier") || name.contains("sfmono") {
                mono = true
            } else {
                if name.contains("bolditalic") {
                    bold = true; italic = true
                } else if name.contains("bold") {
                    bold = true
                } else if name.contains("italic") {
                    italic = true
                }
            }
        }
        let strike = attributes[.strikethroughStyle] != nil

        var inner: String
        if mono {
            // Inline code takes no nested emphasis; emit the raw text in backticks.
            inner = "`\(substring)`"
        } else {
            inner = escapeSelectionMarkdown(substring)
            if strike { inner = "~~\(inner)~~" }
            if bold && italic {
                inner = "***\(inner)***"
            } else if bold {
                inner = "**\(inner)**"
            } else if italic {
                inner = "*\(inner)*"
            }
        }

        if let urlItem = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? InstantPageUrlItem {
            let url = urlItem.url
            let needsBrackets = url.contains("(") || url.contains(")") || url.contains(" ")
            let destination = needsBrackets ? "<\(url)>" : url
            inner = "[\(inner)](\(destination))"
        }

        result += inner
    }

    return result
}

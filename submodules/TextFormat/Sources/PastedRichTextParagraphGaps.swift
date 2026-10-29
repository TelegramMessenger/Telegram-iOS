import Foundation
import UIKit

/// Paragraph spacing (after one paragraph, or before the next) that reads as a blank line. Keep in step with
/// `RTFDocumentParser.blankLineSpacingTwips` (RichTextEditorCore): WebKit's paragraph margins (≥ 12pt) and
/// Word's default 8pt after a paragraph pass, Google Docs' 6pt after a heading does not.
private let pastedParagraphGapBlankLineSpacing: CGFloat = 8.0

/// Pasted rich text (RTF, HTML) flattens to plain text with one "\n" per paragraph. A copied web page — a
/// ChatGPT reply in Safari — separates its paragraphs with margins only, which arrive as `NSParagraphStyle`
/// spacing and would be lost; this inserts a blank line wherever the spacing between two non-empty paragraphs
/// reaches `pastedParagraphGapBlankLineSpacing`. Never between two items of a list, never next to an empty
/// paragraph (no gap becomes two blank lines), and plain text, which has no paragraph style, is unchanged.
/// Paragraphs are split at "\n" only: a U+2028 line break (`<br>`) stays inside its paragraph.
public func attributedStringWithParagraphSpacingAsBlankLines(_ string: NSAttributedString) -> NSAttributedString {
    let text = string.string as NSString
    var paragraphs: [NSRange] = []
    var location = 0
    while true {
        let newline = text.range(of: "\n", options: .literal, range: NSRange(location: location, length: text.length - location))
        if newline.location == NSNotFound {
            paragraphs.append(NSRange(location: location, length: text.length - location))
            break
        }
        paragraphs.append(NSRange(location: location, length: newline.location - location))
        location = newline.location + 1
    }

    let result = NSMutableAttributedString(attributedString: string)
    // Back to front, so an insertion leaves the ranges still to visit where they were.
    for index in stride(from: paragraphs.count - 1, to: 0, by: -1) {
        let previous = paragraphs[index - 1]
        let next = paragraphs[index]
        guard previous.length != 0, next.length != 0 else {
            continue
        }
        let previousStyle = string.attribute(.paragraphStyle, at: previous.location, effectiveRange: nil) as? NSParagraphStyle
        let nextStyle = string.attribute(.paragraphStyle, at: next.location, effectiveRange: nil) as? NSParagraphStyle
        if let previousStyle, let nextStyle, !previousStyle.textLists.isEmpty, !nextStyle.textLists.isEmpty {
            continue
        }
        let spacing = max(previousStyle?.paragraphSpacing ?? 0.0, nextStyle?.paragraphSpacingBefore ?? 0.0)
        guard spacing >= pastedParagraphGapBlankLineSpacing else {
            continue
        }
        result.insert(NSAttributedString(string: "\n"), at: next.location)
    }
    return result
}

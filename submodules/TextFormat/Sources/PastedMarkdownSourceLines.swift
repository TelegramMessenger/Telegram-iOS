import Foundation

/// Reading pasted markdown as it was written (`MarkdownSourceLineBreaks.keep` in BrowserUI's `BrowserMarkdown`),
/// from Foundation's `NSAttributedString(markdown:)`: its soft breaks, and the source lines of its top-level
/// blocks. Here, beside the paste gate, so the parser's behaviour is pinned by `TextFormatTests`.

/// A CommonMark soft break — a single newline inside a paragraph — which Foundation emits as a `" "` run whose
/// inline presentation intent contains `.softBreak`.
@available(iOS 15.0, *)
public func markdownRunIsSoftBreak(_ attributes: [NSAttributedString.Key: Any], text: String) -> Bool {
    guard text == " " else {
        return false
    }
    if let intent = attributes[NSAttributedString.Key("NSInlinePresentationIntent")] as? InlinePresentationIntent {
        return intent.contains(.softBreak)
    } else if let intent = attributes[NSAttributedString.Key("NSInlinePresentationIntent")] as? NSNumber {
        return InlinePresentationIntent(rawValue: intent.uintValue).contains(.softBreak)
    }
    return false
}

/// The source lines each top-level block of a markdown parse spans, keyed by the block's (root presentation
/// intent's) identity. Needs the parse to have run with `appliesSourcePositionAttributes` (iOS 16); empty
/// before iOS 16. Runs Foundation gives no position (soft breaks, a thematic break) add nothing; a block none of
/// whose runs has one is absent. An indented code block's range ends past the blank line that ends it.
@available(iOS 15.0, *)
public func markdownTopLevelBlockSourceLines(_ attributedString: NSAttributedString) -> [Int: ClosedRange<Int>] {
    guard #available(iOS 16.0, *) else {
        return [:]
    }
    let positionKey = NSAttributedString.Key(AttributeScopes.FoundationAttributes.MarkdownSourcePositionAttribute.name)
    var result: [Int: ClosedRange<Int>] = [:]
    attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length), options: []) { attributes, _, _ in
        guard let intent = attributes[NSAttributedString.Key("NSPresentationIntent")] as? PresentationIntent, let root = intent.components.last else {
            return
        }
        guard let position = attributes[positionKey] as? AttributedString.MarkdownSourcePosition else {
            return
        }
        let lines = min(position.startLine, position.endLine) ... max(position.startLine, position.endLine)
        if let current = result[root.identity] {
            result[root.identity] = min(current.lowerBound, lines.lowerBound) ... max(current.upperBound, lines.upperBound)
        } else {
            result[root.identity] = lines
        }
    }
    return result
}

/// For consecutive top-level blocks with these source lines, whether a blank source line comes before each:
/// never before the first, nor next to a block whose lines are unknown.
public func markdownBlankLineBeforeBlocks(_ lines: [ClosedRange<Int>?]) -> [Bool] {
    var result: [Bool] = []
    var previousLastLine: Int?
    for blockLines in lines {
        if let previousLastLine, let blockLines {
            result.append(blockLines.lowerBound > previousLastLine + 1)
        } else {
            result.append(false)
        }
        previousLastLine = blockLines?.upperBound
    }
    return result
}

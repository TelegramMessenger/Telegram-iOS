import Foundation
import UIKit
import TelegramCore
import RichTextEditorCore
import TextFormat

/// Pure bidirectional bridge between the chat composer's `ChatTextInputAttributes`-keyed
/// `NSAttributedString` and the RichTextEditor `Document` model. Covers: body/quote paragraphs +
/// inline styles + spoiler + link + mention/date (via tg:// link schemes) + custom emoji (EmojiRef)
/// + code blocks (`.Pre`, as a first-class `Block.code` — no degradation to body).
enum ComposerDocumentBridge {
    /// composer attributed string → Document (host-push: initial load / draft restore / edit).
    static func document(from attributedText: NSAttributedString) -> Document {
        let fullString = attributedText.string as NSString
        var blocks: [Block] = []

        // Split `range` into paragraphs on "\n" and append a `.paragraph` block for each, preserving
        // per-paragraph attribute ranges. Scoped to a sub-range so the two-pass driver below can fill the
        // gaps BETWEEN code regions; paragraph NSRanges are absolute offsets into `fullString` (the
        // sub-range only bounds the scan, it does not rebase the offsets). Empty `range` appends nothing
        // (a code-region boundary's consumed separator must not yield a stray paragraph).
        func appendParagraphs(in range: NSRange) {
            guard range.length > 0 else { return }

            var paragraphRanges: [NSRange] = []
            var lineStart = range.location
            let end = range.location + range.length
            var i = range.location
            while i < end {
                if fullString.character(at: i) == 0x0A { // "\n"
                    paragraphRanges.append(NSRange(location: lineStart, length: i - lineStart))
                    lineStart = i + 1
                }
                i += 1
            }
            paragraphRanges.append(NSRange(location: lineStart, length: end - lineStart))

            for pRange in paragraphRanges {
                var runs: [TextRun] = []
                if pRange.length > 0 {
                    attributedText.enumerateAttributes(in: pRange, options: []) { dict, range, _ in
                        if let emoji = dict[ChatTextInputAttributes.customEmoji] as? ChatTextInputTextCustomEmojiAttribute {
                            // Map the composer's custom-emoji placeholder to a single-U+FFFC EmojiRef run.
                            // The original placeholder text (whatever the attribute rode on) is preserved as
                            // altText so the reverse path can re-emit it verbatim, while the Document interior
                            // stays one U+FFFC per the editor invariant. instanceID uses the editor's own
                            // BlockID.generate() convention.
                            var emojiCA = CharacterAttributes.plain
                            // SPOILER SURVIVES AN EMOJI RUN. `.plain` used to drop it, so inserting a
                            // custom emoji inside a spoiler split the spoiler in two with the emoji
                            // sitting unhidden in the gap — device trace: dust runs {0,3} and {4,4}
                            // with the emoji at {3,1} and `hiddenBySpoiler=0`. `emoji` and `spoiler`
                            // are independent model fields; an atom can be concealed like any other
                            // character. The same fix was needed one layer down in
                            // `AttributedStringMapper`, which dropped it for the same reason.
                            if dict[ChatTextInputAttributes.spoiler] != nil { emojiCA.spoiler = true }
                            emojiCA.emoji = EmojiRef(
                                id: String(emoji.fileId),
                                instanceID: BlockID.generate().rawValue,
                                altText: fullString.substring(with: range)
                            )
                            runs.append(TextRun(text: "\u{FFFC}", attributes: emojiCA))
                            return
                        }
                        let runText = fullString.substring(with: range)
                        var ca = CharacterAttributes.plain
                        if dict[ChatTextInputAttributes.bold] != nil { ca.bold = true }
                        if dict[ChatTextInputAttributes.italic] != nil { ca.italic = true }
                        if dict[ChatTextInputAttributes.monospace] != nil { ca.inlineCode = true }
                        if dict[ChatTextInputAttributes.strikethrough] != nil { ca.strikethrough = true }
                        if dict[ChatTextInputAttributes.underline] != nil { ca.underline = true }
                        if dict[ChatTextInputAttributes.spoiler] != nil { ca.spoiler = true }
                        if let mention = dict[ChatTextInputAttributes.textMention] as? ChatTextInputTextMentionAttribute {
                            ca.link = mentionMarkdownURL(peerId: mention.peerId)
                        } else if let date = dict[ChatTextInputAttributes.date] as? ChatTextInputTextDateAttribute {
                            ca.link = dateMarkdownURL(timestamp: date.date)
                        } else if let url = dict[ChatTextInputAttributes.textUrl] as? ChatTextInputTextUrlAttribute {
                            ca.link = url.url
                        }
                        runs.append(TextRun(text: runText, attributes: ca))
                    }
                }
                blocks.append(.paragraph(ParagraphBlock(
                    id: BlockID.generate(),
                    style: .body,
                    runs: runs
                )))
            }
        }

        // Two-pass: carve contiguous `.block`/.code regions into single `.code` blocks (a code block may
        // span interior "\n"s and must NOT fragment into per-line paragraphs), then fill the gaps with
        // `appendParagraphs`. The "\n" immediately before/after a code region is the block SEPARATOR — it is
        // consumed here (the forward path re-adds it), not turned into an empty paragraph.
        let codeRegions = codeBlockRanges(in: attributedText)   // ordered, non-overlapping
        var cursor = 0
        for region in codeRegions {
            var gapEnd = region.range.location
            if gapEnd > cursor && fullString.character(at: gapEnd - 1) == 0x0A { gapEnd -= 1 }   // drop separator
            if gapEnd > cursor {
                appendParagraphs(in: NSRange(location: cursor, length: gapEnd - cursor))
            }
            let codeText = fullString.substring(with: region.range)
            blocks.append(.code(CodeBlock(id: BlockID.generate(), language: region.language,
                                          runs: [TextRun(text: codeText)])))
            cursor = region.range.location + region.range.length
            if cursor < fullString.length && fullString.character(at: cursor) == 0x0A { cursor += 1 }   // drop separator
        }
        if cursor < fullString.length {
            appendParagraphs(in: NSRange(location: cursor, length: fullString.length - cursor))
        }

        if blocks.isEmpty {
            blocks = [.paragraph(ParagraphBlock(id: BlockID.generate()))]
        }
        return Document(blocks: blocks)
    }

    /// Document → composer attributed string (attributedText getter).
    static func attributedString(from document: Document, baseFontSize: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let marker = true as NSNumber
        let baseFont = UIFont.systemFont(ofSize: baseFontSize)
        var isFirstParagraph = true
        for block in document.blocks {
            if case let .code(code) = block {
                if !isFirstParagraph {
                    result.append(NSAttributedString(string: "\n", attributes: [.font: baseFont]))
                }
                isFirstParagraph = false
                let start = result.length
                // code.text is the full code string: code blocks carry only plain-text runs (no inline
                // formatting), so joining all runs yields the complete verbatim content.
                result.append(NSAttributedString(string: code.text, attributes: [.font: baseFont]))
                let len = result.length - start
                if len > 0 {
                    let attr = chatInputCodeBlockAttribute(language: code.language)
                    result.addAttribute(attr.key, value: attr.value, range: NSRange(location: start, length: len))
                }
                continue
            }
            if case let .pullQuote(pq) = block {
                if !isFirstParagraph {
                    result.append(NSAttributedString(string: "\n", attributes: [.font: baseFont]))
                }
                isFirstParagraph = false
                result.append(NSAttributedString(string: pq.text, attributes: [.font: baseFont]))
                continue
            }
            if case let .blockQuote(bq) = block {
                if bq.collapsed {
                    // A COLLAPSED block quote occupies exactly ONE flat placeholder char — matching the
                    // editor's composer flat axis (`composerParagraphs` emitAtom) and
                    // `ChatInputContent.blockQuote` blockFlatLength == 1.
                    if !isFirstParagraph {
                        result.append(NSAttributedString(string: "\n", attributes: [.font: baseFont]))
                    }
                    isFirstParagraph = false
                    let piece = NSMutableAttributedString(string: " ", attributes: [.font: baseFont])
                    piece.addAttribute(ChatTextInputAttributes.block,
                                       value: ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: true),
                                       range: NSRange(location: 0, length: piece.length))
                    result.append(piece)
                } else {
                    // Expanded block quote on the flat composer axis: recurse its children so
                    // composerSelectedRange counts the inner text. Matches Part-1's walk recursion.
                    // Append unconditionally (even for an empty quote) so the flat axis stays in sync
                    // with composerParagraphs() and ChatInputContent.plainText — an empty expanded quote
                    // contributes a "\n" separator (like a blank paragraph), preventing composerSelectedRange
                    // from exceeding attributedText.length.
                    let childStr = ComposerDocumentBridge.attributedString(from: Document(blocks: bq.children), baseFontSize: baseFontSize)
                    if !isFirstParagraph {
                        result.append(NSAttributedString(string: "\n", attributes: [.font: baseFont]))
                    }
                    isFirstParagraph = false
                    result.append(childStr)
                }
                continue
            }
            guard case let .paragraph(paragraph) = block else { continue }
            if !isFirstParagraph {
                result.append(NSAttributedString(string: "\n", attributes: [.font: baseFont]))
            }
            isFirstParagraph = false

            for run in paragraph.runs {
                if let emoji = run.attributes.emoji {
                    // Re-emit a custom emoji as a ChatTextInputAttributes.customEmoji run. Prefer the
                    // preserved placeholder text (altText) so the entity length/text matches what the user
                    // composed; fall back to a single U+FFFC. file: nil — the renderer/send path resolve the
                    // file from fileId. A non-numeric id (should not occur from this path) degrades to plain
                    // text rather than crashing.
                    let displayText = (emoji.altText?.isEmpty == false) ? emoji.altText! : "\u{FFFC}"
                    let piece = NSMutableAttributedString(string: displayText, attributes: [.font: baseFont])
                    let range = NSRange(location: 0, length: piece.length)
                    if let fileId = Int64(emoji.id) {
                        piece.addAttribute(
                            ChatTextInputAttributes.customEmoji,
                            value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: fileId, file: nil),
                            range: range
                        )
                    }
                    result.append(piece)
                    continue
                }
                let text = run.text
                if text.isEmpty { continue }
                let piece = NSMutableAttributedString(string: text, attributes: [.font: baseFont])
                let range = NSRange(location: 0, length: piece.length)
                let a = run.attributes
                if a.bold { piece.addAttribute(ChatTextInputAttributes.bold, value: marker, range: range) }
                if a.italic { piece.addAttribute(ChatTextInputAttributes.italic, value: marker, range: range) }
                if a.inlineCode { piece.addAttribute(ChatTextInputAttributes.monospace, value: marker, range: range) }
                if a.strikethrough { piece.addAttribute(ChatTextInputAttributes.strikethrough, value: marker, range: range) }
                if a.underline { piece.addAttribute(ChatTextInputAttributes.underline, value: marker, range: range) }
                if a.spoiler { piece.addAttribute(ChatTextInputAttributes.spoiler, value: marker, range: range) }
                if let link = a.link {
                    let attribute = chatInputLinkAttribute(forLink: link)
                    piece.addAttribute(attribute.key, value: attribute.value, range: range)
                }
                result.append(piece)
            }
        }
        return result
    }

    /// True if the two strings carry the same text and the same composer-meaningful attribute ranges
    /// (bold/italic/monospace/strikethrough/underline/spoiler/textUrl/block), ignoring font/color. Used by
    /// the node's `attributedText` setter to skip a redundant document rebuild (caret-thrash guard).
    static func composerContentEqual(_ lhs: NSAttributedString, _ rhs: NSAttributedString) -> Bool {
        if lhs.string != rhs.string { return false }
        let keys: [NSAttributedString.Key] = [
            ChatTextInputAttributes.bold, ChatTextInputAttributes.italic, ChatTextInputAttributes.monospace,
            ChatTextInputAttributes.strikethrough, ChatTextInputAttributes.underline, ChatTextInputAttributes.spoiler,
            ChatTextInputAttributes.textUrl, ChatTextInputAttributes.block,
            ChatTextInputAttributes.customEmoji, ChatTextInputAttributes.textMention, ChatTextInputAttributes.date
        ]
        let full = NSRange(location: 0, length: (lhs.string as NSString).length)
        for key in keys {
            var lRanges: [NSRange] = []
            var rRanges: [NSRange] = []
            lhs.enumerateAttribute(key, in: full, options: []) { value, range, _ in if value != nil { lRanges.append(range) } }
            rhs.enumerateAttribute(key, in: full, options: []) { value, range, _ in if value != nil { rRanges.append(range) } }
            if lRanges != rRanges { return false }
        }
        // `.textUrl` is the one key whose *value* carries semantic content that must round-trip (the URL
        // string). A same-range link with a changed URL passes the presence-range check above, so compare
        // the URL values too — otherwise an in-place URL edit would be silently dropped by the setter guard.
        var lUrls: [(NSRange, String)] = []
        var rUrls: [(NSRange, String)] = []
        lhs.enumerateAttribute(ChatTextInputAttributes.textUrl, in: full, options: []) { value, range, _ in
            if let url = value as? ChatTextInputTextUrlAttribute { lUrls.append((range, url.url)) }
        }
        rhs.enumerateAttribute(ChatTextInputAttributes.textUrl, in: full, options: []) { value, range, _ in
            if let url = value as? ChatTextInputTextUrlAttribute { rUrls.append((range, url.url)) }
        }
        if lUrls.count != rUrls.count { return false }
        for (l, r) in zip(lUrls, rUrls) where l.0 != r.0 || l.1 != r.1 { return false }
        // Custom emoji: compare fileId at each range explicitly. ChatTextInputTextCustomEmojiAttribute.isEqual
        // is identity-based, so isEqual would treat two equal-fileId instances (always freshly built on a
        // round-trip) as different; compare the fileId, mirroring the .textUrl block above.
        var lEmoji: [(NSRange, Int64)] = []
        var rEmoji: [(NSRange, Int64)] = []
        lhs.enumerateAttribute(ChatTextInputAttributes.customEmoji, in: full, options: []) { value, range, _ in
            if let v = value as? ChatTextInputTextCustomEmojiAttribute { lEmoji.append((range, v.fileId)) }
        }
        rhs.enumerateAttribute(ChatTextInputAttributes.customEmoji, in: full, options: []) { value, range, _ in
            if let v = value as? ChatTextInputTextCustomEmojiAttribute { rEmoji.append((range, v.fileId)) }
        }
        if lEmoji.count != rEmoji.count { return false }
        for (l, r) in zip(lEmoji, rEmoji) where l.0 != r.0 || l.1 != r.1 { return false }
        // .block carries semantic payload (quote vs code + language + isCollapsed). The presence-range
        // check above passes when only the payload changed, so compare values explicitly.
        func blockKindKey(_ q: ChatTextInputTextQuoteAttribute) -> String {
            switch q.kind {
            case .quote: return "q:\(q.isCollapsed)"
            case let .code(language): return "c:\(language ?? "\u{0}")"  // "\u{0}" = NUL sentinel for nil-language; NUL can't appear in a real language name, so it's unambiguous and distinct from ""
            }
        }
        var lBlocks: [(NSRange, String)] = []
        var rBlocks: [(NSRange, String)] = []
        lhs.enumerateAttribute(ChatTextInputAttributes.block, in: full, options: []) { value, range, _ in
            if let q = value as? ChatTextInputTextQuoteAttribute { lBlocks.append((range, blockKindKey(q))) }
        }
        rhs.enumerateAttribute(ChatTextInputAttributes.block, in: full, options: []) { value, range, _ in
            if let q = value as? ChatTextInputTextQuoteAttribute { rBlocks.append((range, blockKindKey(q))) }
        }
        if lBlocks.count != rBlocks.count { return false }
        for (l, r) in zip(lBlocks, rBlocks) where l.0 != r.0 || l.1 != r.1 { return false }
        // Mention and date also carry semantic payload; their attribute classes implement value-based isEqual
        // (peerId / timestamp), so compare the attribute values at matching ranges.
        for key in [ChatTextInputAttributes.textMention, ChatTextInputAttributes.date] {
            var lValues: [(NSRange, NSObject)] = []
            var rValues: [(NSRange, NSObject)] = []
            lhs.enumerateAttribute(key, in: full, options: []) { value, range, _ in if let v = value as? NSObject { lValues.append((range, v)) } }
            rhs.enumerateAttribute(key, in: full, options: []) { value, range, _ in if let v = value as? NSObject { rValues.append((range, v)) } }
            if lValues.count != rValues.count { return false }
            for (l, r) in zip(lValues, rValues) where l.0 != r.0 || !l.1.isEqual(r.1) { return false }
        }
        return true
    }
}

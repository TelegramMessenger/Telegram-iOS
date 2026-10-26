import Foundation

// Collecting the custom emoji a rich message displays.
//
// A rich message (`RichTextMessageAttribute`) carries its custom emoji as `RichText.textCustomEmoji`
// runs inside the page, not as `MessageTextEntity.CustomEmoji` entities, so every consumer that scans
// `textEntitiesAttribute` for emoji (the context menu's "this message contains emoji from …" tip, the
// notification extension's emoji glyphs) sees none. The switches below are EXHAUSTIVE (no `default`) on purpose: a new block or rich-text case
// must state where its text lives, rather than silently hiding the emoji inside it.

private func collectCustomEmoji(_ text: RichText, _ visit: (Int64, String) -> Void) {
    switch text {
    case .empty, .plain, .image, .formula:
        break
    case let .textCustomEmoji(fileId, alt):
        visit(fileId, alt)
    case let .bold(text), let .italic(text), let .underline(text), let .strikethrough(text), let .fixed(text), let .subscript(text), let .superscript(text), let .marked(text):
        collectCustomEmoji(text, visit)
    case let .url(text, _, _), let .email(text, _), let .phone(text, _), let .anchor(text, _):
        collectCustomEmoji(text, visit)
    case let .textAutoEmail(text), let .textAutoPhone(text), let .textAutoUrl(text), let .textBankCard(text), let .textTonAddress(text), let .textBotCommand(text), let .textCashtag(text), let .textHashtag(text), let .textMention(text), let .textSpoiler(text):
        collectCustomEmoji(text, visit)
    case let .textMentionName(text, _), let .textDate(text, _, _):
        collectCustomEmoji(text, visit)
    case let .textButton(button):
        collectCustomEmoji(button.text, visit)
    case let .concat(texts):
        for text in texts {
            collectCustomEmoji(text, visit)
        }
    }
}

private func collectCustomEmoji(_ caption: InstantPageCaption, _ visit: (Int64, String) -> Void) {
    collectCustomEmoji(caption.text, visit)
    collectCustomEmoji(caption.credit, visit)
}

private func collectCustomEmoji(_ blocks: [InstantPageBlock], _ visit: (Int64, String) -> Void) {
    for block in blocks {
        switch block {
        case .unsupported, .formula, .divider, .anchor, .channelBanner:
            break
        case let .title(text), let .subtitle(text), let .header(text), let .subheader(text), let .paragraph(text), let .footer(text), let .kicker(text), let .thinking(text):
            collectCustomEmoji(text, visit)
        case let .authorDate(author, _):
            collectCustomEmoji(author, visit)
        case let .heading(text, _), let .preformatted(text, _):
            collectCustomEmoji(text, visit)
        case let .list(items, _):
            for item in items {
                switch item {
                case .unknown:
                    break
                case let .text(text, _, _):
                    collectCustomEmoji(text, visit)
                case let .blocks(blocks, _, _):
                    collectCustomEmoji(blocks, visit)
                }
            }
        case let .blockQuote(blocks, caption, _):
            collectCustomEmoji(blocks, visit)
            collectCustomEmoji(caption, visit)
        case let .pullQuote(text, caption):
            collectCustomEmoji(text, visit)
            collectCustomEmoji(caption, visit)
        case let .image(_, caption, _, _, _), let .video(_, caption, _, _, _), let .audio(_, caption), let .document(_, caption), let .webEmbed(_, _, _, caption, _, _, _), let .map(_, _, _, _, caption):
            collectCustomEmoji(caption, visit)
        case let .buttonRow(_, buttons):
            for button in buttons {
                collectCustomEmoji(button.text, visit)
            }
        case let .cover(block):
            collectCustomEmoji([block], visit)
        case let .postEmbed(_, _, _, _, _, blocks, caption), let .collage(blocks, caption), let .slideshow(blocks, caption):
            collectCustomEmoji(blocks, visit)
            collectCustomEmoji(caption, visit)
        case let .table(title, rows, _, _, _):
            collectCustomEmoji(title, visit)
            for row in rows {
                for cell in row.cells {
                    if let text = cell.text {
                        collectCustomEmoji(text, visit)
                    }
                }
            }
        case let .details(title, blocks, _):
            collectCustomEmoji(title, visit)
            collectCustomEmoji(blocks, visit)
        case let .relatedArticles(title, _):
            collectCustomEmoji(title, visit)
        }
    }
}

public extension InstantPage {
    /// The file ids of every custom emoji in the page, in reading order, each listed once. Reaches
    /// emoji a flat text scan cannot: table cells, captions, collapsed quotes and details, button labels.
    var customEmojiFileIds: [Int64] {
        var result: [Int64] = []
        var seen = Set<Int64>()
        collectCustomEmoji(self.blocks, { fileId, _ in
            if seen.insert(fileId).inserted {
                result.append(fileId)
            }
        })
        return result
    }

    /// Every custom emoji in the page with its alt text, in reading order, repeats included.
    var customEmojiOccurrences: [(fileId: Int64, alt: String)] {
        var result: [(fileId: Int64, alt: String)] = []
        collectCustomEmoji(self.blocks, { fileId, alt in
            result.append((fileId, alt))
        })
        return result
    }
}

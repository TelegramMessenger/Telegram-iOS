import Foundation

// Collecting the custom emoji a rich message displays, and the text around them.
//
// A rich message (`RichTextMessageAttribute`) carries its custom emoji as `RichText.textCustomEmoji`
// runs inside the page, not as `MessageTextEntity.CustomEmoji` entities, so every consumer that scans
// `textEntitiesAttribute` for emoji (the context menu's "this message contains emoji from …" tip, the
// notification extension's emoji glyphs) sees none. The walk visits the page's text in reading order:
// each plain run, and each custom emoji as its alt text with its file id. The switches below are
// EXHAUSTIVE (no `default`) on purpose: a new block or rich-text case must state where its text lives,
// rather than silently hiding the emoji inside it.

private func visitText(_ text: RichText, _ visit: (String, Int64?) -> Void) {
    switch text {
    case .empty, .image, .formula:
        break
    case let .plain(text):
        visit(text, nil)
    case let .textCustomEmoji(fileId, alt):
        visit(alt, fileId)
    case let .bold(text), let .italic(text), let .underline(text), let .strikethrough(text), let .fixed(text), let .subscript(text), let .superscript(text), let .marked(text):
        visitText(text, visit)
    case let .url(text, _, _), let .email(text, _), let .phone(text, _), let .anchor(text, _):
        visitText(text, visit)
    case let .textAutoEmail(text), let .textAutoPhone(text), let .textAutoUrl(text), let .textBankCard(text), let .textTonAddress(text), let .textBotCommand(text), let .textCashtag(text), let .textHashtag(text), let .textMention(text), let .textSpoiler(text):
        visitText(text, visit)
    case let .textMentionName(text, _), let .textDate(text, _, _):
        visitText(text, visit)
    case let .textButton(button):
        visitText(button.text, visit)
    case let .concat(texts):
        for text in texts {
            visitText(text, visit)
        }
    }
}

private func visitText(_ caption: InstantPageCaption, _ visit: (String, Int64?) -> Void) {
    visitText(caption.text, visit)
    visitText(caption.credit, visit)
}

private func visitText(_ blocks: [InstantPageBlock], _ visit: (String, Int64?) -> Void) {
    for block in blocks {
        switch block {
        case .unsupported, .formula, .divider, .anchor, .channelBanner:
            break
        case let .title(text), let .subtitle(text), let .header(text), let .subheader(text), let .paragraph(text), let .footer(text), let .kicker(text), let .thinking(text):
            visitText(text, visit)
        case let .authorDate(author, _):
            visitText(author, visit)
        case let .heading(text, _), let .preformatted(text, _):
            visitText(text, visit)
        case let .list(items, _):
            for item in items {
                switch item {
                case .unknown:
                    break
                case let .text(text, _, _):
                    visitText(text, visit)
                case let .blocks(blocks, _, _):
                    visitText(blocks, visit)
                }
            }
        case let .blockQuote(blocks, caption, _):
            visitText(blocks, visit)
            visitText(caption, visit)
        case let .pullQuote(text, caption):
            visitText(text, visit)
            visitText(caption, visit)
        case let .image(_, caption, _, _, _), let .video(_, caption, _, _, _), let .audio(_, caption), let .document(_, caption), let .webEmbed(_, _, _, caption, _, _, _), let .map(_, _, _, _, caption):
            visitText(caption, visit)
        case let .buttonRow(_, buttons):
            for button in buttons {
                visitText(button.text, visit)
            }
        case let .cover(block):
            visitText([block], visit)
        case let .postEmbed(_, _, _, _, _, blocks, caption), let .collage(blocks, caption), let .slideshow(blocks, caption):
            visitText(blocks, visit)
            visitText(caption, visit)
        case let .table(title, rows, _, _, _):
            visitText(title, visit)
            for row in rows {
                for cell in row.cells {
                    if let text = cell.text {
                        visitText(text, visit)
                    }
                }
            }
        case let .details(title, blocks, _):
            visitText(title, visit)
            visitText(blocks, visit)
        case let .relatedArticles(title, _):
            visitText(title, visit)
        }
    }
}

public extension InstantPage {
    /// The file ids of every custom emoji in the page, in reading order, each listed once. Reaches
    /// emoji a flat text scan cannot: table cells, captions, collapsed quotes and details, button labels.
    var customEmojiFileIds: [Int64] {
        var result: [Int64] = []
        var seen = Set<Int64>()
        visitText(self.blocks, { _, fileId in
            if let fileId, seen.insert(fileId).inserted {
                result.append(fileId)
            }
        })
        return result
    }

    /// The page's text in reading order: each plain run (`customEmojiFileId` nil), and each custom emoji as
    /// its alt text with its file id, repeats included. A plain-text rendering of the page, such as a rich
    /// message's notification body, is made of these runs.
    var customEmojiTextRuns: [(text: String, customEmojiFileId: Int64?)] {
        var result: [(text: String, customEmojiFileId: Int64?)] = []
        visitText(self.blocks, { text, fileId in
            result.append((text, fileId))
        })
        return result
    }
}

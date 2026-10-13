import Foundation

// Collecting the custom emoji a rich message displays.
//
// A rich message (`RichTextMessageAttribute`) carries its custom emoji as `RichText.textCustomEmoji`
// runs inside the page, not as `MessageTextEntity.CustomEmoji` entities, so every consumer that scans
// `textEntitiesAttribute` for emoji (the context menu's "this message contains emoji from …" tip) sees
// none. The switches below are EXHAUSTIVE (no `default`) on purpose: a new block or rich-text case
// must state where its text lives, rather than silently hiding the emoji inside it.

private func collectCustomEmojiFileIds(_ text: RichText, into result: inout [Int64], seen: inout Set<Int64>) {
    switch text {
    case .empty, .plain, .image, .formula:
        break
    case let .textCustomEmoji(fileId, _):
        if seen.insert(fileId).inserted {
            result.append(fileId)
        }
    case let .bold(text), let .italic(text), let .underline(text), let .strikethrough(text), let .fixed(text), let .subscript(text), let .superscript(text), let .marked(text):
        collectCustomEmojiFileIds(text, into: &result, seen: &seen)
    case let .url(text, _, _), let .email(text, _), let .phone(text, _), let .anchor(text, _):
        collectCustomEmojiFileIds(text, into: &result, seen: &seen)
    case let .textAutoEmail(text), let .textAutoPhone(text), let .textAutoUrl(text), let .textBankCard(text), let .textTonAddress(text), let .textBotCommand(text), let .textCashtag(text), let .textHashtag(text), let .textMention(text), let .textSpoiler(text):
        collectCustomEmojiFileIds(text, into: &result, seen: &seen)
    case let .textMentionName(text, _), let .textDate(text, _, _):
        collectCustomEmojiFileIds(text, into: &result, seen: &seen)
    case let .textButton(button):
        collectCustomEmojiFileIds(button.text, into: &result, seen: &seen)
    case let .concat(texts):
        for text in texts {
            collectCustomEmojiFileIds(text, into: &result, seen: &seen)
        }
    }
}

private func collectCustomEmojiFileIds(_ caption: InstantPageCaption, into result: inout [Int64], seen: inout Set<Int64>) {
    collectCustomEmojiFileIds(caption.text, into: &result, seen: &seen)
    collectCustomEmojiFileIds(caption.credit, into: &result, seen: &seen)
}

private func collectCustomEmojiFileIds(_ blocks: [InstantPageBlock], into result: inout [Int64], seen: inout Set<Int64>) {
    for block in blocks {
        switch block {
        case .unsupported, .formula, .divider, .anchor, .channelBanner:
            break
        case let .title(text), let .subtitle(text), let .header(text), let .subheader(text), let .paragraph(text), let .footer(text), let .kicker(text), let .thinking(text):
            collectCustomEmojiFileIds(text, into: &result, seen: &seen)
        case let .authorDate(author, _):
            collectCustomEmojiFileIds(author, into: &result, seen: &seen)
        case let .heading(text, _), let .preformatted(text, _):
            collectCustomEmojiFileIds(text, into: &result, seen: &seen)
        case let .list(items, _):
            for item in items {
                switch item {
                case .unknown:
                    break
                case let .text(text, _, _):
                    collectCustomEmojiFileIds(text, into: &result, seen: &seen)
                case let .blocks(blocks, _, _):
                    collectCustomEmojiFileIds(blocks, into: &result, seen: &seen)
                }
            }
        case let .blockQuote(blocks, caption, _):
            collectCustomEmojiFileIds(blocks, into: &result, seen: &seen)
            collectCustomEmojiFileIds(caption, into: &result, seen: &seen)
        case let .pullQuote(text, caption):
            collectCustomEmojiFileIds(text, into: &result, seen: &seen)
            collectCustomEmojiFileIds(caption, into: &result, seen: &seen)
        case let .image(_, caption, _, _, _), let .video(_, caption, _, _, _), let .audio(_, caption), let .document(_, caption), let .webEmbed(_, _, _, caption, _, _, _), let .map(_, _, _, _, caption):
            collectCustomEmojiFileIds(caption, into: &result, seen: &seen)
        case let .buttonRow(_, buttons):
            for button in buttons {
                collectCustomEmojiFileIds(button.text, into: &result, seen: &seen)
            }
        case let .cover(block):
            collectCustomEmojiFileIds([block], into: &result, seen: &seen)
        case let .postEmbed(_, _, _, _, _, blocks, caption), let .collage(blocks, caption), let .slideshow(blocks, caption):
            collectCustomEmojiFileIds(blocks, into: &result, seen: &seen)
            collectCustomEmojiFileIds(caption, into: &result, seen: &seen)
        case let .table(title, rows, _, _, _):
            collectCustomEmojiFileIds(title, into: &result, seen: &seen)
            for row in rows {
                for cell in row.cells {
                    if let text = cell.text {
                        collectCustomEmojiFileIds(text, into: &result, seen: &seen)
                    }
                }
            }
        case let .details(title, blocks, _):
            collectCustomEmojiFileIds(title, into: &result, seen: &seen)
            collectCustomEmojiFileIds(blocks, into: &result, seen: &seen)
        case let .relatedArticles(title, _):
            collectCustomEmojiFileIds(title, into: &result, seen: &seen)
        }
    }
}

public extension InstantPage {
    /// The file ids of every custom emoji in the page, in reading order, each listed once. Reaches
    /// emoji a flat text scan cannot: table cells, captions, collapsed quotes and details, button labels.
    var customEmojiFileIds: [Int64] {
        var result: [Int64] = []
        var seen = Set<Int64>()
        collectCustomEmojiFileIds(self.blocks, into: &result, seen: &seen)
        return result
    }
}

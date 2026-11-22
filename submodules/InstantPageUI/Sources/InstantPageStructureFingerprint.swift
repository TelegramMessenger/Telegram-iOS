import Foundation
import TelegramCore

/// Content fingerprint of an `InstantPage`: the block tree's **case tags, child counts,
/// optional-child presence, and every string the user reads**.
///
/// Two pages with the same fingerprint render the same content, so `InstantPageV2View`'s positional
/// item-view reuse (`InstantPageV2StableItemId.positional`) carries state between them safely. A
/// different fingerprint means a reused view would show different content, which is what the
/// bubble's whole-content crossfade exists to dissolve rather than snap.
///
/// **The inclusion rule: strings the user reads are in, identities are out.** In:  every `RichText`
/// leaf, its wrapper case tags (so adding bold counts), link urls, emails, phones, custom-emoji
/// `alt`, `formula` latex, captions and credits, table cell text, list markers, button labels,
/// related-article titles. Out: `MediaId`, `webpageId`, `photoId`, custom-emoji `fileId`, mention
/// `peerId`, and invisible targets like `anchor` names.
///
/// Excluding media identity is load-bearing, not tidiness: the Local→Cloud send flip rewrites every
/// `MediaId` in the page — including the inline ones inside `RichText.image` — while the content the
/// user sees is unchanged. Folding them in would dissolve every rich message on send.
///
/// Still excluded as pure presentation payload: heading `level`, list `ordered`, preformatted
/// `language`, `blockQuote.collapsed`, `details.expanded`, `image.spoiler`, alignment and border
/// flags. Each already has its own animation, or is invisible.
///
/// The rule that neither half settles by itself: **optional presence is shape, optional value is
/// payload.** `InstantPageListItem`'s `checked: Bool?` contributes `nil` vs non-nil — a checkbox
/// marker either exists or it does not — but never `true` vs `false`. That is what keeps a checkbox
/// tap on the same-content path, where its own toggle animation lives.
///
/// `RichText.textDate` contributes its `date` timestamp, never the formatted string: the relative
/// date ("3 minutes ago") is produced at layout time from a stable model, so its refresh timer
/// re-lays-out without ever tripping a dissolve.
///
/// Returns a `Hasher`-derived `Int`: one word to store, no allocation (leaf strings are hashed in
/// place, never concatenated), and a collision only ever costs a missed crossfade. `Hasher`'s
/// per-process seed is irrelevant because values are only ever compared within one run — never
/// persisted, never sent.
public func instantPageStructureFingerprint(_ page: InstantPage) -> Int {
    var hasher = Hasher()
    hashStructure(blocks: page.blocks, into: &hasher)
    return hasher.finalize()
}

/// Emits the child count BEFORE the children. That is what makes nesting unambiguous: without it,
/// `[quote[a], b]` and `[quote[a, b]]` would produce the same token stream.
private func hashStructure(blocks: [InstantPageBlock], into hasher: inout Hasher) {
    hasher.combine(blocks.count)
    for block in blocks {
        hashStructure(block: block, into: &hasher)
    }
}

private func hashStructure(block: InstantPageBlock, into hasher: inout Hasher) {
    // The tag numbers are arbitrary and local to this function — they are never persisted, so they
    // need not track `InstantPageBlockType`'s raw values (which are `private` to TelegramCore).
    // The switch is exhaustive on purpose: a new block case must not silently hash as its neighbor.
    switch block {
    case .unsupported:
        hasher.combine(0)
    case let .title(text):
        hasher.combine(1)
        hashStructure(richText: text, into: &hasher)
    case let .subtitle(text):
        hasher.combine(2)
        hashStructure(richText: text, into: &hasher)
    case let .authorDate(author, date):
        hasher.combine(3)
        hashStructure(richText: author, into: &hasher)
        hasher.combine(date)
    case let .header(text):
        hasher.combine(4)
        hashStructure(richText: text, into: &hasher)
    case let .subheader(text):
        hasher.combine(5)
        hashStructure(richText: text, into: &hasher)
    case let .heading(text, _):
        // `level` stays excluded — presentation payload.
        hasher.combine(6)
        hashStructure(richText: text, into: &hasher)
    case let .formula(latex):
        // The latex source IS the formula's entire visible content; there is no RichText to carry it.
        hasher.combine(7)
        hasher.combine(latex)
    case let .paragraph(text):
        hasher.combine(8)
        hashStructure(richText: text, into: &hasher)
    case let .preformatted(text, _):
        // `language` stays excluded — it only selects the highlighter.
        hasher.combine(9)
        hashStructure(richText: text, into: &hasher)
    case let .footer(text):
        hasher.combine(10)
        hashStructure(richText: text, into: &hasher)
    case .divider:
        hasher.combine(11)
    case .anchor:
        // The anchor name is an invisible link target.
        hasher.combine(12)
    case let .list(items, _):
        // `ordered` stays excluded — presentation payload.
        hasher.combine(13)
        hasher.combine(items.count)
        for item in items {
            hashStructure(listItem: item, into: &hasher)
        }
    case let .blockQuote(blocks, caption, _):
        // `collapsed` stays excluded — it has its own animation.
        hasher.combine(14)
        hashStructure(blocks: blocks, into: &hasher)
        hashStructure(richText: caption, into: &hasher)
    case let .pullQuote(text, caption):
        hasher.combine(15)
        hashStructure(richText: text, into: &hasher)
        hashStructure(richText: caption, into: &hasher)
    case let .image(_, caption, _, _, _):
        // MediaId, url, webpageId and `spoiler` all excluded — identity and payload.
        hasher.combine(16)
        hashStructure(caption: caption, into: &hasher)
    case let .video(_, caption, _, _, _):
        hasher.combine(17)
        hashStructure(caption: caption, into: &hasher)
    case let .audio(_, caption):
        hasher.combine(18)
        hashStructure(caption: caption, into: &hasher)
    case let .document(_, caption):
        hasher.combine(19)
        hashStructure(caption: caption, into: &hasher)
    case let .buttonRow(_, buttons):
        // `alignment` excluded; each button contributes its visible label.
        hasher.combine(20)
        hasher.combine(buttons.count)
        for button in buttons {
            hashStructure(richText: button.text, into: &hasher)
        }
    case let .cover(block):
        hasher.combine(21)
        hashStructure(block: block, into: &hasher)
    case let .webEmbed(_, _, _, caption, _, _, _):
        hasher.combine(22)
        hashStructure(caption: caption, into: &hasher)
    case let .postEmbed(_, _, _, author, date, blocks, caption):
        // `author` and `date` are rendered in the embed header.
        hasher.combine(23)
        hasher.combine(author)
        hasher.combine(date)
        hashStructure(blocks: blocks, into: &hasher)
        hashStructure(caption: caption, into: &hasher)
    case let .collage(items, caption):
        hasher.combine(24)
        hashStructure(blocks: items, into: &hasher)
        hashStructure(caption: caption, into: &hasher)
    case let .slideshow(items, caption):
        hasher.combine(25)
        hashStructure(blocks: items, into: &hasher)
        hashStructure(caption: caption, into: &hasher)
    case let .channelBanner(channel):
        hasher.combine(26)
        hasher.combine(channel != nil)
    case let .kicker(text):
        hasher.combine(27)
        hashStructure(richText: text, into: &hasher)
    case let .thinking(text):
        hasher.combine(28)
        hashStructure(richText: text, into: &hasher)
    case let .table(title, rows, _, _, _):
        // `bordered`, `striped` and `compact` excluded — presentation payload.
        hasher.combine(29)
        hashStructure(richText: title, into: &hasher)
        hasher.combine(rows.count)
        for row in rows {
            hasher.combine(row.cells.count)
            for cell in row.cells {
                // Cell text is Optional: presence is shape, and the value is read by the user.
                hasher.combine(cell.text != nil)
                if let text = cell.text {
                    hashStructure(richText: text, into: &hasher)
                }
            }
        }
    case let .details(title, blocks, _):
        // `expanded` stays excluded — the node overrides it with `currentExpandedDetails` anyway.
        hasher.combine(30)
        hashStructure(richText: title, into: &hasher)
        hashStructure(blocks: blocks, into: &hasher)
    case let .relatedArticles(title, articles):
        hasher.combine(31)
        hashStructure(richText: title, into: &hasher)
        hasher.combine(articles.count)
        for article in articles {
            hasher.combine(article.title)
            hasher.combine(article.description)
            hasher.combine(article.author)
        }
    case let .map(_, _, _, _, caption):
        hasher.combine(32)
        hashStructure(caption: caption, into: &hasher)
    }
}

private func hashStructure(caption: InstantPageCaption, into hasher: inout Hasher) {
    hashStructure(richText: caption.text, into: &hasher)
    hashStructure(richText: caption.credit, into: &hasher)
}

private func hashStructure(listItem: InstantPageListItem, into hasher: inout Hasher) {
    switch listItem {
    case .unknown:
        hasher.combine(0)
    case let .text(text, marker, checked):
        hasher.combine(1)
        hashStructure(richText: text, into: &hasher)
        hasher.combine(marker)
        // Presence, not value — see the type doc.
        hasher.combine(checked != nil)
    case let .blocks(blocks, marker, checked):
        hasher.combine(2)
        hasher.combine(marker)
        hasher.combine(checked != nil)
        hashStructure(blocks: blocks, into: &hasher)
    }
}

/// Case tags AND leaf strings. The tags mean a formatting-only change — wrapping a word in `.bold`
/// — moves the fingerprint, which is intended: the reused text view would otherwise snap to the new
/// attributes with no transition.
private func hashStructure(richText: RichText, into hasher: inout Hasher) {
    switch richText {
    case .empty:
        hasher.combine(0)
    case let .plain(string):
        hasher.combine(1)
        hasher.combine(string)
    case let .bold(text):
        hasher.combine(2)
        hashStructure(richText: text, into: &hasher)
    case let .italic(text):
        hasher.combine(3)
        hashStructure(richText: text, into: &hasher)
    case let .underline(text):
        hasher.combine(4)
        hashStructure(richText: text, into: &hasher)
    case let .strikethrough(text):
        hasher.combine(5)
        hashStructure(richText: text, into: &hasher)
    case let .fixed(text):
        hasher.combine(6)
        hashStructure(richText: text, into: &hasher)
    case let .url(text, url, _):
        // `webpageId` excluded — identity.
        hasher.combine(7)
        hashStructure(richText: text, into: &hasher)
        hasher.combine(url)
    case let .email(text, email):
        hasher.combine(8)
        hashStructure(richText: text, into: &hasher)
        hasher.combine(email)
    case let .concat(texts):
        hasher.combine(9)
        hasher.combine(texts.count)
        for text in texts {
            hashStructure(richText: text, into: &hasher)
        }
    case let .subscript(text):
        hasher.combine(10)
        hashStructure(richText: text, into: &hasher)
    case let .superscript(text):
        hasher.combine(11)
        hashStructure(richText: text, into: &hasher)
    case let .marked(text):
        hasher.combine(12)
        hashStructure(richText: text, into: &hasher)
    case let .phone(text, phone):
        hasher.combine(13)
        hashStructure(richText: text, into: &hasher)
        hasher.combine(phone)
    case .image:
        // An INLINE image. Its MediaId is excluded for the same reason the block-level ones are:
        // it is rewritten by the Local→Cloud send flip while nothing visible changes.
        hasher.combine(14)
    case let .anchor(text, _):
        // The anchor name is an invisible link target.
        hasher.combine(15)
        hashStructure(richText: text, into: &hasher)
    case let .formula(latex):
        hasher.combine(16)
        hasher.combine(latex)
    case let .textCustomEmoji(_, alt):
        // `fileId` excluded — identity. Two different emoji essentially always differ in `alt`.
        hasher.combine(17)
        hasher.combine(alt)
    case let .textAutoEmail(text):
        hasher.combine(18)
        hashStructure(richText: text, into: &hasher)
    case let .textAutoPhone(text):
        hasher.combine(19)
        hashStructure(richText: text, into: &hasher)
    case let .textAutoUrl(text):
        hasher.combine(20)
        hashStructure(richText: text, into: &hasher)
    case let .textTonAddress(text):
        hasher.combine(30)
        hashStructure(richText: text, into: &hasher)
    case let .textBankCard(text):
        hasher.combine(21)
        hashStructure(richText: text, into: &hasher)
    case let .textBotCommand(text):
        hasher.combine(22)
        hashStructure(richText: text, into: &hasher)
    case let .textCashtag(text):
        hasher.combine(23)
        hashStructure(richText: text, into: &hasher)
    case let .textHashtag(text):
        hasher.combine(24)
        hashStructure(richText: text, into: &hasher)
    case let .textMention(text):
        hasher.combine(25)
        hashStructure(richText: text, into: &hasher)
    case let .textMentionName(text, _):
        // `peerId` excluded — identity.
        hasher.combine(26)
        hashStructure(richText: text, into: &hasher)
    case let .textSpoiler(text):
        hasher.combine(27)
        hashStructure(richText: text, into: &hasher)
    case let .textDate(text, date, _):
        // The MODEL timestamp, never the formatted string — the relative-date refresh timer
        // re-lays-out from this same stable value and so cannot trip a dissolve.
        hasher.combine(28)
        hashStructure(richText: text, into: &hasher)
        hasher.combine(date)
    case let .textButton(button):
        hasher.combine(29)
        hashStructure(richText: button.text, into: &hasher)
    }
}

import Foundation
import Postbox
internal import TelegramApi

// The users a rich message refers to by bare id: `textMentionName` runs and "User Profile" buttons,
// inline (`textButton`) or in a button row. The page carries only `user_id:long` for both, so sending it
// lists each user again as an `InputUser` in `inputRichMessage.users`, the way a plain message's mention
// entity carries `inputMessageEntityMentionName`. The switches below are EXHAUSTIVE (no `default`) on
// purpose: a new block or rich-text case must state whether it can refer to a user.

private func collectReferencedUserIds(_ action: ReplyMarkupButtonAction, _ visit: (PeerId) -> Void) {
    if case let .openUserProfile(peerId) = action {
        visit(peerId)
    }
}

private func collectReferencedUserIds(_ text: RichText, _ visit: (PeerId) -> Void) {
    switch text {
    case .empty, .plain, .image, .formula, .textCustomEmoji:
        break
    case let .bold(text), let .italic(text), let .underline(text), let .strikethrough(text), let .fixed(text), let .subscript(text), let .superscript(text), let .marked(text):
        collectReferencedUserIds(text, visit)
    case let .url(text, _, _), let .email(text, _), let .phone(text, _), let .anchor(text, _):
        collectReferencedUserIds(text, visit)
    case let .textAutoEmail(text), let .textAutoPhone(text), let .textAutoUrl(text), let .textBankCard(text), let .textTonAddress(text), let .textBotCommand(text), let .textCashtag(text), let .textHashtag(text), let .textMention(text), let .textSpoiler(text):
        collectReferencedUserIds(text, visit)
    case let .textMentionName(text, userId):
        // A rendered message's peers are looked up by these ids, so an id no user can have (a bogus page) is skipped.
        if userId > 0 {
            visit(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)))
        }
        collectReferencedUserIds(text, visit)
    case let .textDate(text, _, _):
        collectReferencedUserIds(text, visit)
    case let .textButton(button):
        collectReferencedUserIds(button.action, visit)
        collectReferencedUserIds(button.text, visit)
    case let .concat(texts):
        for text in texts {
            collectReferencedUserIds(text, visit)
        }
    }
}

private func collectReferencedUserIds(_ caption: InstantPageCaption, _ visit: (PeerId) -> Void) {
    collectReferencedUserIds(caption.text, visit)
    collectReferencedUserIds(caption.credit, visit)
}

private func collectReferencedUserIds(_ blocks: [InstantPageBlock], _ visit: (PeerId) -> Void) {
    for block in blocks {
        switch block {
        case .unsupported, .formula, .divider, .anchor, .channelBanner:
            break
        case let .title(text), let .subtitle(text), let .header(text), let .subheader(text), let .paragraph(text), let .footer(text), let .kicker(text), let .thinking(text):
            collectReferencedUserIds(text, visit)
        case let .authorDate(author, _):
            collectReferencedUserIds(author, visit)
        case let .heading(text, _), let .preformatted(text, _):
            collectReferencedUserIds(text, visit)
        case let .list(items, _):
            for item in items {
                switch item {
                case .unknown:
                    break
                case let .text(text, _, _):
                    collectReferencedUserIds(text, visit)
                case let .blocks(blocks, _, _):
                    collectReferencedUserIds(blocks, visit)
                }
            }
        case let .blockQuote(blocks, caption, _):
            collectReferencedUserIds(blocks, visit)
            collectReferencedUserIds(caption, visit)
        case let .pullQuote(text, caption):
            collectReferencedUserIds(text, visit)
            collectReferencedUserIds(caption, visit)
        case let .image(_, caption, _, _, _), let .video(_, caption, _, _, _), let .audio(_, caption), let .document(_, caption), let .webEmbed(_, _, _, caption, _, _, _), let .map(_, _, _, _, caption):
            collectReferencedUserIds(caption, visit)
        case let .buttonRow(_, buttons):
            for button in buttons {
                collectReferencedUserIds(button.action, visit)
                collectReferencedUserIds(button.text, visit)
            }
        case let .cover(block):
            collectReferencedUserIds([block], visit)
        case let .postEmbed(_, _, _, _, _, blocks, caption), let .collage(blocks, caption), let .slideshow(blocks, caption):
            collectReferencedUserIds(blocks, visit)
            collectReferencedUserIds(caption, visit)
        case let .table(title, rows, _, _, _):
            collectReferencedUserIds(title, visit)
            for row in rows {
                for cell in row.cells {
                    if let text = cell.text {
                        collectReferencedUserIds(text, visit)
                    }
                }
            }
        case let .details(title, blocks, _):
            collectReferencedUserIds(title, visit)
            collectReferencedUserIds(blocks, visit)
        case let .relatedArticles(title, _):
            collectReferencedUserIds(title, visit)
        }
    }
}

public extension InstantPage {
    /// The users the page refers to by id (mention names, "User Profile" buttons), in reading order,
    /// each listed once.
    var referencedUserIds: [PeerId] {
        var result: [PeerId] = []
        var seen = Set<PeerId>()
        collectReferencedUserIds(self.blocks, { peerId in
            if seen.insert(peerId).inserted {
                result.append(peerId)
            }
        })
        return result
    }
}

/// `inputRichMessage.users` for `instantPage`: every user it refers to that `peer` knows, as an
/// `InputUser`. A user that cannot be resolved is left out; the page still names it by id.
func apiInputRichMessageUsers(_ instantPage: InstantPage, peer: (PeerId) -> Peer?) -> [Api.InputUser] {
    return instantPage.referencedUserIds.compactMap { peerId in
        return peer(peerId).flatMap(apiInputUser)
    }
}

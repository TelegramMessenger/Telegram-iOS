import Foundation
import TelegramCore

/// What `ChatControllerNode.sendCurrentMessage` SENDS for a composer state, decided here rather than
/// inline in TelegramUI so a test that cannot link TelegramUI calls the same code the chat calls.
///
/// The composer harness's send-path oracle (`Tests/ComposerHarness/Tests/HarnessSendPathOracle.swift`)
/// used to mirror ~15 lines of this glue because they lived inside the chat's send loop; a mirror tests
/// the mirror (composer harness p20 fix wave). The chat and the oracle both call these now.

/// How a composer state is sent.
public enum ChatComposerSendRoute: Equatable {
    /// One message carrying a `RichTextMessageAttribute` built by `instantPage(from:)`.
    case rich
    /// Text + entities, one message per 4096-character piece (`chatComposerTextMessages`).
    case textEntities
}

/// The route: rich only for a NEW message whose content the entity set cannot express (headings,
/// lists, tables, media, pull quotes, details, formulas, buttons, a quote with an author or nested
/// content), and never when the user chose to send without formatting. Everything else — paragraphs,
/// one level of quote, code, mentions, links, dates, custom emoji — goes as text + entities.
public func chatComposerSendRoute(content: ChatInputContent, isNewMessage: Bool, sendWithoutFormatting: Bool) -> ChatComposerSendRoute {
    if !sendWithoutFormatting && isNewMessage && !content.isEntityExpressible() && !content.isEmpty {
        return .rich
    }
    return .textEntities
}

/// The text route's messages.
public struct ChatComposerTextMessages {
    /// The effective input text after the chat's typed-markdown conversion (`convertMarkdownToAttributes`).
    public let inputText: NSAttributedString
    /// One per non-empty 4096-character piece of the trimmed text, with the entities the chat sends.
    public let pieces: [(text: NSAttributedString, entities: [MessageTextEntity])]
}

/// The text route's messages for `effectiveInputText` (the composer's `inputText`, collapsed blocks
/// expanded by `expandedInputStateAttributedString`): typed markdown converted, the ends trimmed, split
/// at the message length limit, and each piece's entities generated. `businessLinkSetup` is the business
/// link editor's variant, which generates no links of its own.
public func chatComposerTextMessages(effectiveInputText: NSAttributedString, businessLinkSetup: Bool = false) -> ChatComposerTextMessages {
    let inputText = convertMarkdownToAttributes(effectiveInputText)
    var pieces: [(text: NSAttributedString, entities: [MessageTextEntity])] = []
    for text in breakChatInputText(trimChatInputText(inputText)) {
        if text.length == 0 {
            continue
        }
        let entities: [MessageTextEntity]
        if businessLinkSetup {
            entities = generateChatInputTextEntities(text, generateLinks: false)
        } else {
            entities = generateTextEntities(text.string, enabledTypes: .all, currentEntities: generateChatInputTextEntities(text, maxAnimatedEmojisInText: 0))
        }
        pieces.append((text, entities))
    }
    return ChatComposerTextMessages(inputText: inputText, pieces: pieces)
}

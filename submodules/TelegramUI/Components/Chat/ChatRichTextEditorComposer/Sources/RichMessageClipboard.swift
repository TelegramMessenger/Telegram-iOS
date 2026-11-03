import Foundation
import UIKit
import TelegramCore
import RichTextEditorCore
import RichTextEditorUIKit
import Pasteboard

/// Builds the pasteboard item for copying a RICH message — a `RichTextMessageAttribute`'s `InstantPage` —
/// in the new WYSIWYG-editor clipboard formats (the private fragment UTI + RTF + plain), so a copied rich
/// message pastes into the composer with full structure and into other apps as RTF. This replaces the
/// legacy "copy as markdown" path (which put raw `# Heading` text on the clipboard).
///
/// It reuses the existing, structurally-lossless two-hop that the edit-a-rich-message path already uses
/// (`ChatControllerLoadDisplayNode.setupEditMessage`): `InstantPage → ChatInputContent → Document`. The
/// `registerEmoji`/`registerMedia` closures mint editor-side refs for a one-shot serialization (no live
/// editor): the emoji's `altText` is filled by the bridge from the chat run's text, and media/tables
/// degrade per the editor's current fragment scope (their bytes aren't carried on the pasteboard).
/// Builds an editor `Document` fragment from a `ChatInputContent` using one-shot editor-side refs
/// (the same `registerEmoji`/`registerMedia` scheme as the rich-message clipboard: emoji `altText` is
/// filled by the bridge from the run's text; media/table refs are freshly minted). Shared by the
/// markdown-on-paste hosts and by `richMessagePasteboardItem(fromInstantPage:)`.
public func pasteFragmentDocument(fromChatInputContent content: ChatInputContent) -> Document {
    return document(
        fromChatInputContent: content,
        registerEmoji: { fileId, _ in EmojiRef(id: String(fileId), instanceID: BlockID.generate().rawValue) },
        registerMedia: { _ in BlockID.generate().rawValue }
    )
}

public func richMessagePasteboardItem(fromInstantPage page: InstantPage) -> [String: Any] {
    let doc = pasteFragmentDocument(fromChatInputContent: chatInputContent(fromInstantPage: page))
    return RichTextEditorClipboard.pasteboardItem(for: doc)
}

/// Copies a `ComposedRichMessage` to the pasteboard: `.plain` in the classic text-with-entities
/// formats, `.rich` in the structure-preserving rich-message formats (see
/// `richMessagePasteboardItem(fromInstantPage:)`), `.empty` copies nothing.
public func storeComposedRichMessageInPasteboard(_ message: ComposedRichMessage) {
    switch message {
    case let .rich(instantPage):
        UIPasteboard.general.items = [richMessagePasteboardItem(fromInstantPage: instantPage)]
    case let .plain(text, entities):
        storeMessageTextInPasteboard(text, entities: entities)
    case .empty:
        break
    }
}

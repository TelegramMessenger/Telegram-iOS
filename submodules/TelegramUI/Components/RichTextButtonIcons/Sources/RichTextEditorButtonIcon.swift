import Foundation
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextEditorMessageConversion

/// The icon provider an editor host registers with `RichTextEditorView.registerButtonIconProvider`.
///
/// The editor's own `ButtonAction` can name only the actions its Telegram-free model has words for
/// (`url`, `copyText`, `disabled`); everything else — callback, payment, web view, profile — travels
/// as an opaque `.unsupported(kind:payload:)`. Resolving the icon therefore has to go back through
/// `replyMarkupButtonAction(from:)`, the one place that blob is decoded, or a `.openUserProfile`
/// button would draw a generic icon in the composer and the profile icon in the sent message.
///
/// It also means the two sides agree on the ICONLESS actions by construction: an incoming `.callback`
/// decodes back to `.callback`, which `richTextButtonIconName` has no entry for, so the editor
/// reserves no width for it either.
///
/// The DECISION is the name lookup, not the rasterisation: an action with an icon whose asset fails to
/// load still returns a non-nil icon (with a nil image), so the pill reserves exactly what the sent
/// message will. See `RichTextButtonIcon`.
@available(iOS 13.0, *)
public func richTextEditorButtonIcon(for action: ButtonAction) -> RichTextButtonIcon? {
    let resolved = replyMarkupButtonAction(from: action)
    guard richTextButtonIconName(for: resolved) != nil else {
        return nil
    }
    return RichTextButtonIcon(image: { richTextButtonIcon(for: resolved, color: $0) })
}

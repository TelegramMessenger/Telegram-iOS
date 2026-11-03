import Foundation

/// Reduced shape of a TDLib reply preview, as projected for rendering. Either embedded
/// inside the host bubble's chrome (text / photo / video) or wrapped in its own mini-card
/// above a chrome-less sticker. Always read-only; produced by `replyPreview(...)`.
struct ReplyHeader: Equatable, Hashable {
    /// Source-author display name. `nil` when the source isn't in the local cache and
    /// no `MessageOrigin` provided one — view renders snippet only in that case.
    let senderName: String?
    /// Body text shown under the sender name. `quote.text` when the reply carries a
    /// `TextQuote`; else a label derived from the source content (`"Photo"`, `"Video"`,
    /// `"Sticker <emoji>"`, …). Never empty — see `replySnippet`.
    let snippet: String
    /// Inline minithumbnail bytes for `.messagePhoto` / `.messageVideo` sources. `nil`
    /// for stickers, text, and any case where TDLib didn't carry one. View decodes via
    /// `UIImage(data:)` and falls back to omitting the slot if decoding fails.
    let minithumbnail: Data?
    /// Host bubble's outgoing flag. Drives tint mapping inside bubble chrome (white
    /// text on accent fill vs primary on gray). Ignored by the sticker mini-card,
    /// which always uses incoming styling.
    let isOutgoing: Bool
    /// Palette index for the author name (incoming styling only); nil = uncolored.
    /// Set together with `senderName`.
    var senderColorIndex: Int? = nil
}

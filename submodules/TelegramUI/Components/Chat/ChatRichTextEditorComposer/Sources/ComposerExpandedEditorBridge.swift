import Foundation
import TelegramCore
import RichTextEditorCore

/// Convenience converters for the chat composer ↔ expanded article-editor (`RichTextAttachmentScreen`)
/// handoff. They wrap the structure-preserving `Document ↔ ChatInputContent` bridge with the media-store
/// collection / lookup the article editor speaks (`(Document, [String: Media])`), so the handoff can flow
/// entirely through the chat input STATE (`ChatInputContent`) rather than poking the composer node directly.

/// Stable, opaque editor-side key for a `Media`, derived from its `MediaId` (`"namespace:id"`), or an
/// object-identity fallback for an id-less medium. Shared by the composer node's media store
/// (`RichTextEditorChatInputNode.registerMediaValue`), the `documentMediaAndEmoji(fromChatInputContent:)`
/// expand seed, and `RichTextAttachmentScreen.attachedMedia`, so a medium keyed one way resolves the other.
public func composerMediaKey(_ media: EngineMedia) -> String {
    if let id = media.id {
        return "\(id.namespace):\(id.id)"
    } else {
        // No stable media id (rare): fall back to an object-identity key so the same value still
        // round-trips within a single set/get cycle.
        return "anon:\(ObjectIdentifier(media._asMedia() as AnyObject).hashValue)"
    }
}

/// Convert a chat-layer `ChatInputContent` to an editor `Document`, the media store it references (keyed by
/// `composerMediaKey`), and the custom-emoji file store (keyed by fileId) — the OUT (expand) half of the
/// composer ↔ article-editor handoff. The editor `Document` itself carries each custom emoji by fileId STRING
/// only (it has no `TelegramMediaFile` slot), so the files ride alongside in `emojiFiles`; the article editor
/// seeds its emoji store from that map so the emoji render and their files survive back out. The inverse is
/// `chatInputContent(fromDocument:media:emojiFiles:)`.
public func documentMediaAndEmoji(fromChatInputContent content: ChatInputContent) -> (document: Document, media: [String: EngineMedia], emojiFiles: [Int64: TelegramMediaFile]) {
    var media: [String: EngineMedia] = [:]
    var emojiFiles: [Int64: TelegramMediaFile] = [:]
    let doc = document(
        fromChatInputContent: content,
        registerEmoji: { fileId, file in
            if let file {
                emojiFiles[fileId] = file
            }
            return EmojiRef(id: String(fileId), instanceID: BlockID.generate().rawValue, altText: nil)
        },
        registerMedia: { value in
            let key = composerMediaKey(value)
            media[key] = value
            return key
        }
    )
    return (document: doc, media: media, emojiFiles: emojiFiles)
}

public func documentMediaAndEmojiAsync(engine: TelegramEngine, fromChatInputContent content: ChatInputContent) async -> (document: Document, media: [String: EngineMedia], emojiFiles: [Int64: TelegramMediaFile]) {
    var media: [String: EngineMedia] = [:]
    var emojiFiles: [Int64: TelegramMediaFile] = [:]
    var emojiFileIds = Set<Int64>()
    let doc = document(
        fromChatInputContent: content,
        registerEmoji: { fileId, file in
            emojiFileIds.insert(fileId)
            if let file {
                emojiFiles[fileId] = file
            }
            return EmojiRef(id: String(fileId), instanceID: BlockID.generate().rawValue, altText: nil)
        },
        registerMedia: { value in
            let key = composerMediaKey(value)
            media[key] = value
            return key
        }
    )
    let missingFileIds = emojiFileIds.subtracting(Set(emojiFiles.keys))
    if !missingFileIds.isEmpty {
        let addedFiles = await engine.stickers.resolveInlineStickersLocal(fileIds: Array(missingFileIds)).get()
        emojiFiles.merge(addedFiles, uniquingKeysWith: { lhs, _ in lhs })
    }
    return (document: doc, media: media, emojiFiles: emojiFiles)
}

/// Convert an expanded article editor's `Document` + its media store + its custom-emoji file store back to the
/// chat-layer `ChatInputContent` — the IN (collapse) half of the handoff (`RichTextAttachmentScreen.sendMessage`).
/// The inverse of `documentMediaAndEmoji(fromChatInputContent:)`. A medium is resolved from `media` (an
/// unresolved key drops the block); a custom emoji's `TelegramMediaFile` is resolved from `emojiFiles` (the
/// editor `Document` carries only the fileId) — re-attaching it is REQUIRED for the chat composer to render the
/// emoji, since its native node caches/renders by the file carried on the run. A non-numeric emoji id (should
/// not occur from this path) degrades the run to plain text; a missing file falls back to `nil` (the run still
/// round-trips structurally, but won't render until decoration re-derives the file).
public func chatInputContent(fromDocument document: Document, media: [String: EngineMedia], emojiFiles: [Int64: TelegramMediaFile]) -> ChatInputContent {
    return chatInputContent(
        fromDocument: document,
        resolveEmoji: { emojiRef in
            guard let fileId = Int64(emojiRef.id) else {
                return nil
            }
            return (fileId: fileId, file: emojiFiles[fileId])
        },
        resolveMedia: { mediaID in media[mediaID] }
    )
}

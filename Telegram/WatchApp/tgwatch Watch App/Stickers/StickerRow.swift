import Foundation
import TDShim

/// Builds a `StickerVisual` for `messageSticker` content. Returns `nil` for any other
/// content. Looks up the sticker's file id (and its thumbnail file id if present) in
/// `fileLocals` for the freshest local-path snapshot.
func stickerVisual(for content: MessageContent, fileLocals: [Int: File]) -> StickerVisual? {
    guard case .messageSticker(let m) = content else { return nil }
    let sticker = m.sticker
    let mainFile = fileLocals[sticker.sticker.id] ?? sticker.sticker
    let localPath: String? = (mainFile.local.isDownloadingCompleted && !mainFile.local.path.isEmpty)
        ? mainFile.local.path : nil

    var thumbnailFileId: Int? = nil
    var thumbnailLocalPath: String? = nil
    var thumbnailFormat: ThumbnailFormatKind? = nil
    if let thumb = sticker.thumbnail {
        let kind = thumbnailFormatKind(thumb.format)
        thumbnailFormat = kind
        if kind != .unsupported {
            thumbnailFileId = thumb.file.id
            let thumbFile = fileLocals[thumb.file.id] ?? thumb.file
            if thumbFile.local.isDownloadingCompleted && !thumbFile.local.path.isEmpty {
                thumbnailLocalPath = thumbFile.local.path
            }
        }
    }

    return StickerVisual(
        fileId: sticker.sticker.id,
        format: stickerFormatKind(sticker.format),
        width: sticker.width,
        height: sticker.height,
        emoji: sticker.emoji,
        localPath: localPath,
        thumbnailFileId: thumbnailFileId,
        thumbnailLocalPath: thumbnailLocalPath,
        thumbnailFormat: thumbnailFormat
    )
}

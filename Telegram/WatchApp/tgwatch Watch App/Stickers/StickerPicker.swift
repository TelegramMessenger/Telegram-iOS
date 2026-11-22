import Foundation
import TDShim

/// One sticker as the picker grid + send path need it. Built by
/// `pickerSticker(from:)` from a TDLibKit `Sticker`. `id` is the sticker body
/// file id so it is stable within a session and usable with `ForEach`.
struct PickerSticker: Identifiable, Equatable, Hashable {
    var id: Int { stickerFileId }

    /// File id of the sticker body (WEBP/TGS/WEBM). Also the lottie/full-webp
    /// render source.
    let stickerFileId: Int
    let format: StickerFormatKind
    /// Which file to download + how to decode it for the grid tile.
    let render: PickerRender

    // Send fields — sending uses the remote id, so no download is needed.
    let remoteFileId: String
    let emoji: String
    let width: Int
    let height: Int
}

/// How to produce a static grid-tile image for a sticker.
enum PickerRender: Equatable, Hashable {
    /// Decode `fileId` as a raster image (WebPKit for .webp, UIImage for jpeg/png).
    case raster(fileId: Int, format: ThumbnailFormatKind)
    /// Download the TGS body `fileId` and render frame 0 via RLottieKit.
    case lottie(fileId: Int)
    /// No previewable image (WEBM/video). Tile shows a placeholder; still sendable.
    case none
}

/// One installed sticker set as the picker list + detail need it.
struct PickerSet: Identifiable, Equatable, Hashable {
    var id: Int64 { setId.rawValue }
    let setId: TdInt64
    let title: String
    /// First cover sticker, rendered as the row's thumbnail. Nil if the set
    /// ships no covers.
    let cover: PickerSticker?
}

/// Picks the grid render path from the sticker's own format. WEBP prefers a
/// raster thumbnail (smaller), falling back to the full WEBP body when the
/// sticker has no raster thumbnail. TGS renders frame 0 from the lottie body.
/// WEBM has no watchOS-renderable preview.
func pickerRender(for sticker: Sticker) -> PickerRender {
    switch stickerFormatKind(sticker.format) {
    case .webp:
        if let thumb = sticker.thumbnail {
            let kind = thumbnailFormatKind(thumb.format)
            if kind != .unsupported {
                return .raster(fileId: thumb.file.id, format: kind)
            }
        }
        return .raster(fileId: sticker.sticker.id, format: .webp)
    case .tgs:
        return .lottie(fileId: sticker.sticker.id)
    case .unsupported:
        return .none
    }
}

func pickerSticker(from sticker: Sticker) -> PickerSticker {
    PickerSticker(
        stickerFileId: sticker.sticker.id,
        format: stickerFormatKind(sticker.format),
        render: pickerRender(for: sticker),
        remoteFileId: sticker.sticker.remote.id,
        emoji: sticker.emoji,
        width: sticker.width,
        height: sticker.height
    )
}

func pickerSet(from info: StickerSetInfo) -> PickerSet {
    PickerSet(
        setId: info.id,
        title: info.title,
        cover: info.covers.first.map(pickerSticker(from:))
    )
}

import Foundation
import TDShim

/// Per-sticker visual data the bubble view consumes. Built by `stickerVisual(for:fileLocals:)`
/// from `MessageContent.messageSticker` plus the store's latest `files[fileId]` snapshot.
///
/// Identifiable by `fileId` so it works with `.sheet(item:)` if a viewer is ever added.
struct StickerVisual: Identifiable, Equatable, Hashable {
    var id: Int { fileId }

    /// TDLib file id of the main sticker file (WEBP body / TGS body / WEBM body).
    let fileId: Int
    let format: StickerFormatKind
    /// Pixel width, as authored by the sender. Used for aspect ratio.
    let width: Int
    let height: Int
    /// Emoji associated with the sticker; may be empty when unknown.
    let emoji: String
    /// Filesystem path of the main sticker file; non-nil iff downloaded.
    let localPath: String?

    /// TDLib file id of the raster thumbnail (WEBP/JPEG/PNG). Nil when the sticker carries
    /// no usable raster thumbnail (or only a TGS / WEBM thumbnail).
    let thumbnailFileId: Int?
    let thumbnailLocalPath: String?
    let thumbnailFormat: ThumbnailFormatKind?
}

/// Three-way classification of `StickerFormat`. We only render `.webp` and `.tgs`
/// fully; `.unsupported` covers `stickerFormatWebm` and any future format.
enum StickerFormatKind: Equatable, Hashable {
    case webp
    case tgs
    case unsupported
}

/// Classification of `ThumbnailFormat` for the placeholder render path.
/// Only raster formats decode cleanly via `UIImage(contentsOfFile:)` — TGS/WEBM/GIF/MPEG4
/// thumbnails collapse to `.unsupported` (i.e. treat as no thumbnail).
enum ThumbnailFormatKind: Equatable, Hashable {
    case webp
    case jpeg
    case png
    case unsupported
}

func stickerFormatKind(_ format: StickerFormat) -> StickerFormatKind {
    switch format {
    case .stickerFormatWebp: return .webp
    case .stickerFormatTgs:  return .tgs
    case .stickerFormatWebm, .unsupported: return .unsupported
    }
}

func thumbnailFormatKind(_ format: ThumbnailFormat) -> ThumbnailFormatKind {
    switch format {
    case .thumbnailFormatWebp:  return .webp
    case .thumbnailFormatJpeg:  return .jpeg
    case .thumbnailFormatPng:   return .png
    case .thumbnailFormatTgs, .thumbnailFormatWebm, .thumbnailFormatGif, .thumbnailFormatMpeg4, .unsupported:
        return .unsupported
    }
}

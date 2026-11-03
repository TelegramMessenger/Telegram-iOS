import Foundation
import TDShim

/// Seam between `StickerPickerStore` and TDLib. Tests inject a fake; production
/// uses `TDLibStickerPickerLoader`. Send is intentionally NOT here — it goes
/// through `ChatHistoryLoader.sendSticker` so the chat store's pull-to-tail and
/// error handling apply.
protocol StickerPickerLoader: Sendable {
    func favoriteStickers() async throws -> [Sticker]
    func recentStickers() async throws -> [Sticker]
    func installedStickerSets() async throws -> [StickerSetInfo]
    func stickerSet(id: TdInt64) async throws -> [Sticker]
    func downloadFile(fileId: Int, priority: Int) async throws -> File
    func cancelDownloadFile(fileId: Int) async throws
}

struct TDLibStickerPickerLoader: StickerPickerLoader {
    let client: TDLibClient

    func favoriteStickers() async throws -> [Sticker] {
        try await client.getFavoriteStickers().stickers
    }

    func recentStickers() async throws -> [Sticker] {
        try await client.getRecentStickers(isAttached: false).stickers
    }

    func installedStickerSets() async throws -> [StickerSetInfo] {
        try await client.getInstalledStickerSets(stickerType: .stickerTypeRegular).sets
    }

    func stickerSet(id: TdInt64) async throws -> [Sticker] {
        try await client.getStickerSet(setId: id).stickers
    }

    func downloadFile(fileId: Int, priority: Int) async throws -> File {
        // synchronous=false → TDLib returns immediately and streams progress via updateFile.
        try await client.downloadFile(fileId: fileId, limit: 0, offset: 0, priority: priority, synchronous: false)
    }

    func cancelDownloadFile(fileId: Int) async throws {
        // onlyIfPending=false → cancel even if active.
        _ = try await client.cancelDownloadFile(fileId: fileId, onlyIfPending: false)
    }
}

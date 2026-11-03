import Foundation
import SwiftUI
import TDShim

/// Distinguishes the Saved-Messages bookmark glyph from a normal chat avatar.
enum AvatarKind: Equatable, Hashable {
    case savedMessages
    case normal
}

/// View-ready avatar projection carried on `ChatRow`. Holds no `Color` (stores a
/// palette index) so it stays trivially `Equatable`/`Hashable` and unit-testable.
struct AvatarVisual: Equatable, Hashable {
    var kind: AvatarKind
    /// 1-2 letters from the chat title; "" for `.savedMessages` or an empty title.
    var initials: String
    /// Index into `avatarPalette`, deterministic per chat id.
    var colorIndex: Int
    /// The `small` (160px) photo file id; nil when the chat has no photo.
    var photoFileId: Int?
    /// Set once the `small` file download has completed.
    var photoLocalPath: String?
    /// Instant minithumbnail JPEG bytes; nil when the chat has no photo.
    var mini: Data?
}

/// Telegram-ish 7-color palette. Single source of truth for both the projection
/// (modulo) and `AvatarView` (index → color). Index safety in `AvatarView` relies
/// on `avatarColorIndex` using this same `count`.
let avatarPalette: [Color] = [
    Color(red: 0.90, green: 0.34, blue: 0.34), // red
    Color(red: 0.94, green: 0.61, blue: 0.20), // orange
    Color(red: 0.55, green: 0.45, blue: 0.86), // purple
    Color(red: 0.40, green: 0.73, blue: 0.42), // green
    Color(red: 0.30, green: 0.70, blue: 0.78), // cyan
    Color(red: 0.36, green: 0.56, blue: 0.90), // blue
    Color(red: 0.90, green: 0.46, blue: 0.62), // pink
]

/// First extended-grapheme cluster of up to the first two whitespace-separated
/// words, uppercased. Empty/whitespace-only title → "".
func avatarInitials(from title: String) -> String {
    let words = title.split(whereSeparator: { $0.isWhitespace })
    guard let first = words.first?.first else { return "" }
    var result = String(first)
    if words.count > 1, let second = words[1].first {
        result.append(second)
    }
    return result.uppercased()
}

/// Deterministic palette index in `0..<avatarPalette.count` for any stable peer id
/// (user or chat). Overflow-safe for negative ids (avoids `abs(Int64.min)` trapping).
func paletteIndex(for id: Int64) -> Int {
    let count = Int64(avatarPalette.count)
    return Int(((id % count) + count) % count)
}

/// Deterministic palette index for a peer that has only a display name and no stable
/// id (e.g. a hidden-forward author). FNV-1a over the name's UTF-8 bytes, reduced
/// modulo the palette count — stable across process runs, unlike `String.hashValue`.
func paletteIndex(forName name: String) -> Int {
    var hash: UInt64 = 14695981039346656037 // FNV-1a 64-bit offset basis (0xcbf29ce484222325)
    for byte in name.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 1099511628211       // FNV-1a 64-bit prime (0x100000001b3)
    }
    return Int(hash % UInt64(avatarPalette.count))
}

/// Per-chat avatar fallback color index. Kept as a named alias so avatar call sites
/// and their tests stay expressive; delegates to the generic `paletteIndex(for:)`.
func avatarColorIndex(forChatId id: Int64) -> Int {
    paletteIndex(for: id)
}

/// Projects a cached chat into a view-ready `AvatarVisual`.
/// - Saved Messages (private chat with our own user id) → `.savedMessages`.
/// - Otherwise `.normal` with initials/color always populated; `photoLocalPath`
///   resolves from `fileLocals` only when the small file download has completed.
func avatarVisual(for chat: CachedChat, fileLocals: [Int: File], selfUserId: Int64?) -> AvatarVisual {
    if let selfUserId,
       case .chatTypePrivate(let p) = chat.type,
       p.userId == selfUserId {
        return AvatarVisual(
            kind: .savedMessages,
            initials: "",
            colorIndex: avatarColorIndex(forChatId: chat.id),
            photoFileId: nil,
            photoLocalPath: nil,
            mini: nil
        )
    }

    var localPath: String? = nil
    if let fileId = chat.avatarSmallFileId,
       let file = fileLocals[fileId],
       file.local.isDownloadingCompleted,
       !file.local.path.isEmpty {
        localPath = file.local.path
    }

    return AvatarVisual(
        kind: .normal,
        initials: avatarInitials(from: chat.title),
        colorIndex: avatarColorIndex(forChatId: chat.id),
        photoFileId: chat.avatarSmallFileId,
        photoLocalPath: localPath,
        mini: chat.avatarMini
    )
}

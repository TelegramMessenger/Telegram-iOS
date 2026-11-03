import Foundation
import TDShim

/// Per-photo visual data the bubble view consumes. The projection produces it from
/// `MessagePhoto.photo` + the store's latest `files[fileId]` snapshot.
///
/// Identifiable by `fileId` so it works with `.sheet(item:)` for the full-screen viewer.
struct PhotoVisual: Identifiable, Equatable, Hashable {
    /// TDLib file id of the chosen `PhotoSize`. Stable across re-projections.
    var id: Int { fileId }
    let fileId: Int
    /// Pixel width of the chosen `PhotoSize` (used for aspect ratio).
    let width: Int
    /// Pixel height of the chosen `PhotoSize`.
    let height: Int
    /// Tiny embedded JPEG (~40×40) carried inside the message; instantly available.
    let minithumbnail: Data?
    /// Filesystem path; non-nil iff `isDownloadingCompleted == true && !path.isEmpty`.
    let localPath: String?
}

/// Picks one `PhotoSize` to display on a 208pt-wide watch screen.
///
/// 1. Prefer the size with `type == "m"` (Telegram's ~320px-wide medium variant).
/// 2. Otherwise pick the largest size with `width <= 320`.
/// 3. Otherwise pick the smallest size available (all sizes are larger than 320).
/// 4. Returns `nil` only on an empty input array (TDLib invariant says this shouldn't happen).
func selectPhotoSize(_ sizes: [PhotoSize]) -> PhotoSize? {
    if let m = sizes.first(where: { $0.type == "m" }) { return m }
    let underBound = sizes.filter { $0.width <= 320 }
    if let largest = underBound.sorted(by: { $0.width > $1.width }).first { return largest }
    return sizes.sorted(by: { $0.width < $1.width }).first
}

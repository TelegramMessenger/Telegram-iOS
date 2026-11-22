import Foundation
import TDShim

/// Per-video data the bubble + viewer consume. The projection produces it from
/// `MessageVideo` + the store's latest `files[fileId]` snapshots for both the chosen
/// quality and the preview thumbnail.
///
/// Identifiable by `videoFileId` so it works with `.sheet(item:)` for the player.
struct VideoVisual: Identifiable, Equatable, Hashable {
    /// File id of the chosen quality (the file the viewer downloads on play).
    var id: Int { videoFileId }
    let videoFileId: Int
    /// Pixel width of the chosen quality (used for player aspect-fit).
    let width: Int
    /// Pixel height of the chosen quality.
    let height: Int
    /// Duration in seconds; rendered as the duration pill on the bubble.
    let duration: Int
    /// MIME type of the chosen file (e.g. "video/mp4"). Rarely needed by AVPlayer.
    let mimeType: String
    /// Bubble preview thumbnail data + lifecycle handles.
    let preview: VideoPreview
    /// Filesystem path of the chosen video file when downloaded; nil otherwise.
    let videoLocalPath: String?
}

/// Bubble preview thumbnail. Sourced from (in order) `MessageVideo.cover`,
/// `Video.thumbnail`, then `Video.minithumbnail`. The projection produces this
/// statically; `previewLocalPath` is filled in once `previewFileId` finishes
/// downloading via `updateFile`.
struct VideoPreview: Equatable, Hashable {
    /// File id of the preview surface (cover photo or video.thumbnail file).
    /// Nil when only `minithumbnail` is available.
    let previewFileId: Int?
    /// Pixel dimensions of the preview surface (for aspect-ratio math in the bubble).
    let previewWidth: Int
    let previewHeight: Int
    /// Tiny inline JPEG carried inside the message; instantly available, blurry.
    let minithumbnail: Data?
    /// Filesystem path; non-nil iff the preview file id is downloaded.
    let previewLocalPath: String?
}

/// Picks one video file to download and play on a watch screen.
///
/// 1. If `alternatives` is non-empty, pick the alternative with the smallest `width`.
///    Tie-break by smallest `height`. Always returns the lowest-resolution variant
///    available, since the watch screen is 208pt wide and HD is wasted bytes.
/// 2. Else return the primary `video`.
func selectVideoQuality(primary: Video, alternatives: [AlternativeVideo]) -> (file: File, width: Int, height: Int, mimeType: String) {
    if let chosen = alternatives.min(by: { lhs, rhs in
        if lhs.width != rhs.width { return lhs.width < rhs.width }
        return lhs.height < rhs.height
    }) {
        // AlternativeVideo's mimeType isn't directly modeled — TDLib transcodes to MP4.
        return (file: chosen.video, width: chosen.width, height: chosen.height, mimeType: "video/mp4")
    }
    return (file: primary.video, width: primary.width, height: primary.height, mimeType: primary.mimeType)
}

/// Picks one `PhotoSize` from a `MessageVideo.cover` for display on a watchOS screen.
/// Biased larger than `selectPhotoSize` because the cover is shown both in the 180pt
/// bubble AND blurred behind the full-screen video viewer's downloading state.
///
/// 1. Prefer `type == "x"` (Telegram's ~800px-wide large variant).
/// 2. Else `type == "m"` (~320px) — keeps backward-compat with senders that only ship medium.
/// 3. Else the largest size with `width <= 1024`.
/// 4. Else the smallest size available.
/// 5. Returns `nil` only on an empty input.
func selectVideoCoverSize(_ sizes: [PhotoSize]) -> PhotoSize? {
    if let x = sizes.first(where: { $0.type == "x" }) { return x }
    if let m = sizes.first(where: { $0.type == "m" }) { return m }
    let underBound = sizes.filter { $0.width <= 1024 }
    if let largest = underBound.sorted(by: { $0.width > $1.width }).first { return largest }
    return sizes.sorted(by: { $0.width < $1.width }).first
}

/// Picks the bubble preview thumbnail strategy. Cover (multi-size, reuse
/// `selectVideoCoverSize`) wins; then `Video.thumbnail` (single-file JPEG/MPEG4); else
/// only the inline `minithumbnail` is available.
func selectVideoPreview(_ message: MessageVideo) -> VideoPreview {
    if let cover = message.cover, let size = selectVideoCoverSize(cover.sizes) {
        return VideoPreview(
            previewFileId: size.photo.id,
            previewWidth: size.width,
            previewHeight: size.height,
            minithumbnail: cover.minithumbnail?.data,
            previewLocalPath: nil
        )
    }
    if let thumb = message.video.thumbnail {
        return VideoPreview(
            previewFileId: thumb.file.id,
            previewWidth: thumb.width,
            previewHeight: thumb.height,
            minithumbnail: message.video.minithumbnail?.data,
            previewLocalPath: nil
        )
    }
    return VideoPreview(
        previewFileId: nil,
        previewWidth: message.video.width,
        previewHeight: message.video.height,
        minithumbnail: message.video.minithumbnail?.data,
        previewLocalPath: nil
    )
}

/// Renders a duration label for the bubble's overlay pill. `M:SS` under an hour;
/// `H:MM:SS` at or above one hour. Always pads seconds (and minutes when in HH:MM:SS).
func formatDuration(_ seconds: Int) -> String {
    let s = max(0, seconds)
    let h = s / 3600
    let m = (s % 3600) / 60
    let sec = s % 60
    if h > 0 {
        return String(format: "%d:%02d:%02d", h, m, sec)
    }
    return String(format: "%d:%02d", m, sec)
}

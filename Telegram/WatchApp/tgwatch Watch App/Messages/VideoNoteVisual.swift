import Foundation
import TDShim

/// Per-round-note data the bubble + viewer consume. The projection produces it
/// from `MessageVideoNote` + the store's latest `files[fileId]` snapshots for both
/// the playable video file and (optionally) the thumbnail file.
///
/// Identifiable by `videoFileId` so it works with `.sheet(item:)` for the player.
struct VideoNoteVisual: Identifiable, Equatable, Hashable {
    /// File id of the playable video (the file the viewer downloads on tap).
    var id: Int { videoFileId }
    let videoFileId: Int
    /// Square side length in pixels (`VideoNote.length`); for reference — bubble
    /// + viewer use fixed display sizes.
    let length: Int
    /// Duration in seconds (0…60); rendered in the duration pill.
    let duration: Int
    /// File id of `VideoNote.thumbnail?.file` when present; nil when only
    /// `minithumbnail` is available.
    let thumbFileId: Int?
    /// Tiny inline JPEG carried by the message itself; instantly available, blurry.
    let minithumbnail: Data?
    /// Filesystem path of the thumbnail file once downloaded; nil otherwise.
    let thumbLocalPath: String?
    /// Filesystem path of the playable video file once downloaded; nil otherwise.
    let videoLocalPath: String?
}

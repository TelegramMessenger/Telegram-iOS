import Foundation

/// Per-music-message data the bubble + audio playback controller consume. Built
/// from a `MessageAudio` plus the latest `files[fileId]` snapshot for the audio
/// file. Identifiable by `audioFileId`.
struct AudioVisual: Identifiable, Equatable, Hashable {
    var id: Int { audioFileId }
    let audioFileId: Int
    /// Seconds, from `Audio.duration` (sender-defined; may be approximate).
    let duration: Int
    /// Display title — `Audio.title`, falling back to `fileName`, then "Audio".
    let title: String
    /// `Audio.performer`; empty string hides the performer line.
    let performer: String
    /// Embedded album-cover minithumbnail JPEG bytes; nil when absent. Rendered
    /// directly via `UIImage(data:)` — no download.
    let albumArt: Data?
    /// Caption text (formatting ignored, matching photo/video bubbles).
    let caption: String
    /// Filesystem path of the audio file once downloaded; nil otherwise.
    let localPath: String?
}

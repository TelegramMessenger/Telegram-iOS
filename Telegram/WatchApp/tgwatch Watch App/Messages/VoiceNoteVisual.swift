import Foundation

/// Per-voice-note data the bubble + playback controller consume. Built from
/// a `MessageVoiceNote` plus the latest `files[fileId]` snapshot for the voice
/// file. Identifiable by `voiceFileId`.
struct VoiceNoteVisual: Identifiable, Equatable, Hashable {
    var id: Int { voiceFileId }
    let voiceFileId: Int
    /// Seconds, from `VoiceNote.duration` (sender-defined; may be approximate).
    let duration: Int
    /// `VoiceNote.mimeType`; typically `audio/ogg`.
    let mimeType: String
    /// Telegram's 5-bit packed waveform; may be empty.
    let waveform: Data
    /// Caption text (formatting ignored, matching photo/video bubbles).
    let caption: String
    /// Filesystem path of the voice file once downloaded; nil otherwise.
    let localPath: String?
}

extension VoiceNoteVisual {
    /// Builds a visual for a locally-recorded draft (already on disk) for the
    /// record-sheet review screen. `voiceFileId` is a negative sentinel so it
    /// never collides with a real TDLib file id, and `localPath` points straight
    /// at the temp file so playback skips any download path.
    static func draft(fileURL: URL, duration: Int, waveform: Data) -> VoiceNoteVisual {
        VoiceNoteVisual(
            voiceFileId: -1,
            duration: duration,
            mimeType: "audio/ogg",
            waveform: waveform,
            caption: "",
            localPath: fileURL.path
        )
    }
}

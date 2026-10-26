import Foundation

/// What an attached `MediaBlock` is — drives the converter's `.image` vs `.video` vs `.audio` vs
/// `.document` InstantPage block and lets a demo/host label its placeholder. The editor renders
/// image/video identically (a hosted view sized from `naturalSize`); `.audio` and `.document` are
/// fixed-height rows and `.location` a map snapshot — only serialization, layout height, and the
/// host's hosted view care about the distinction.
public enum MediaKind: String, Codable, Equatable, CaseIterable {
    case image
    case video
    case location
    case audio
    case document

    /// True for a kind that has NO editable caption: the block is a bare atom (nodeSize 3, no caption
    /// paragraph, no leaf text region) whose caret rides its leading gap. Audio and document rows both
    /// behave this way; image/video/location carry a caption. Generalises the former audio-only checks.
    public var isCaptionless: Bool {
        switch self {
        case .audio, .document:
            return true
        case .image, .video, .location:
            return false
        }
    }
}

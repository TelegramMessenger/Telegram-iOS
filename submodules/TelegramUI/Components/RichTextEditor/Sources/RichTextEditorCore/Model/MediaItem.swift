import Foundation

/// One medium (image or video) inside a `MediaBlock` container. The container holds one or more of these
/// plus a single shared caption. `mediaID` is the host's opaque content key (mapped to a view via the
/// media-view provider and to a real `Media` at serialize time); the SAME `mediaID` may appear more than
/// once (in one container or across blocks).
public struct MediaItem: Codable, Equatable {
    public var mediaID: String
    public var kind: MediaKind
    public var naturalSize: Size2D
    /// Telegram-style spoiler: the medium is hidden behind an animated "dust" overlay until tapped.
    public var isSpoiler: Bool

    public init(mediaID: String, kind: MediaKind = .image, naturalSize: Size2D, isSpoiler: Bool = false) {
        self.mediaID = mediaID
        self.kind = kind
        self.naturalSize = naturalSize
        self.isSpoiler = isSpoiler
    }

    private enum CodingKeys: String, CodingKey { case mediaID, kind, naturalSize, isSpoiler }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.mediaID = try c.decode(String.self, forKey: .mediaID)
        self.kind = try c.decode(MediaKind.self, forKey: .kind)
        self.naturalSize = try c.decode(Size2D.self, forKey: .naturalSize)
        self.isSpoiler = try c.decodeIfPresent(Bool.self, forKey: .isSpoiler) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(mediaID, forKey: .mediaID)
        try c.encode(kind, forKey: .kind)
        try c.encode(naturalSize, forKey: .naturalSize)
        try c.encode(isSpoiler, forKey: .isSpoiler)
    }
}

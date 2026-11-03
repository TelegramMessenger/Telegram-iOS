import Foundation

/// How a multi-item media container (`items.count >= 2`) is laid out. Meaningful only for containers;
/// a single item is always a plain block. Default `.mosaic` (a packed grid → InstantPage `.collage`);
/// `.slideshow` is a swipeable carousel → InstantPage `.slideshow`.
public enum MediaDisplayMode: String, Codable, Equatable {
    case mosaic
    case slideshow
}

/// An attached media container (one or more images/videos) with a single shared editable caption. In the
/// position model this is a non-leaf node containing ONE media atom (size 1) — representing the whole
/// container — followed by the caption paragraph, regardless of how many items it holds. `.audio` /
/// `.location` are permanently single-item.
public struct MediaBlock: Codable, Equatable {
    public var id: BlockID
    /// The media in this container. Always non-empty. A photo/video album may hold >1; audio/location = 1.
    public var items: [MediaItem]
    /// Display width in points; nil = natural width. Honored only when `items.count == 1`.
    public var displayWidth: Double?
    /// Honored only when `items.count == 1` (a mosaic fills the width).
    public var alignment: MediaAlignment
    /// Layout mode for a multi-item container; honored only when `items.count >= 2`. Default `.mosaic`.
    public var displayMode: MediaDisplayMode
    public var caption: [TextRun]

    /// Container initializer.
    public init(
        id: BlockID,
        items: [MediaItem],
        displayWidth: Double? = nil,
        alignment: MediaAlignment = .center,
        displayMode: MediaDisplayMode = .mosaic,
        caption: [TextRun] = []
    ) {
        self.id = id
        self.items = items
        self.displayWidth = displayWidth
        self.alignment = alignment
        self.displayMode = displayMode
        self.caption = caption
    }

    /// Convenience single-media initializer — reproduces the pre-container API so existing call sites are
    /// unchanged. Wraps the medium into a one-item container.
    public init(
        id: BlockID,
        mediaID: String,
        kind: MediaKind = .image,
        naturalSize: Size2D,
        displayWidth: Double? = nil,
        alignment: MediaAlignment = .center,
        displayMode: MediaDisplayMode = .mosaic,
        caption: [TextRun] = []
    ) {
        self.init(id: id,
                  items: [MediaItem(mediaID: mediaID, kind: kind, naturalSize: naturalSize)],
                  displayWidth: displayWidth, alignment: alignment, displayMode: displayMode, caption: caption)
    }

    // Single-media convenience accessors (the FIRST item). Correct wherever the caller predates containers
    // (all existing sites operate on count-1 blocks); the multi-aware paths read `items` directly.
    public var mediaID: String { items.first?.mediaID ?? "" }
    public var kind: MediaKind { items.first?.kind ?? .image }
    public var naturalSize: Size2D { items.first?.naturalSize ?? Size2D(width: 0, height: 0) }
    /// True for an audio block (always single-item).
    public var isAudio: Bool { items.first?.kind == .audio }
    /// True for a caption-less row block (audio or document; both always single-item).
    public var isCaptionless: Bool { items.first?.kind.isCaptionless ?? false }

    public var captionUTF16Count: Int { caption.reduce(0) { $0 + $1.utf16Count } }

    // MARK: Codable (back-compat: a legacy flat mediaID/kind/naturalSize decodes into one item)

    private enum CodingKeys: String, CodingKey {
        case id, items, displayWidth, alignment, displayMode, caption
        // Legacy (pre-container) keys:
        case mediaID, kind, naturalSize
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(BlockID.self, forKey: .id)
        self.displayWidth = try c.decodeIfPresent(Double.self, forKey: .displayWidth)
        self.alignment = try c.decode(MediaAlignment.self, forKey: .alignment)
        self.displayMode = try c.decodeIfPresent(MediaDisplayMode.self, forKey: .displayMode) ?? .mosaic
        self.caption = try c.decode([TextRun].self, forKey: .caption)
        if let items = try c.decodeIfPresent([MediaItem].self, forKey: .items) {
            self.items = items
        } else {
            // Legacy single-media payload.
            let mediaID = try c.decode(String.self, forKey: .mediaID)
            let kind = try c.decode(MediaKind.self, forKey: .kind)
            let naturalSize = try c.decode(Size2D.self, forKey: .naturalSize)
            self.items = [MediaItem(mediaID: mediaID, kind: kind, naturalSize: naturalSize)]
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(items, forKey: .items)
        try c.encodeIfPresent(displayWidth, forKey: .displayWidth)
        try c.encode(alignment, forKey: .alignment)
        try c.encode(displayMode, forKey: .displayMode)
        try c.encode(caption, forKey: .caption)
    }
}

import Foundation

/// An inline custom-emoji reference stored on a `CharacterAttributes` of a one-`U+FFFC` `TextRun`.
/// `id` is the host's opaque key (mapped to a view at render time); `instanceID` is unique per
/// occurrence (the renderer reconciles host views by it, so a view + its animation survive edits/undo);
/// `altText` is the optional plain-text / Markdown form.
public struct EmojiRef: Codable, Equatable {
    public var id: String
    public var instanceID: String
    public var altText: String?

    public init(id: String, instanceID: String, altText: String? = nil) {
        self.id = id
        self.instanceID = instanceID
        self.altText = altText
    }
}

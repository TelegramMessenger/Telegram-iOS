import Foundation
import Postbox

/// An InstantPage button in the composer currency. Unlike `RichTextEditorCore.ButtonRef`, this layer
/// can name `ReplyMarkupButtonAction` directly, so no opaque blob appears here — the blob exists only
/// on the editor side, and `ButtonActionCodec` (RichTextEditorMessageConversion) bridges the two.
///
/// The label lives INSIDE the button; the carrying run's text is a bare `U+FFFC`, mirroring the
/// custom-emoji and formula invariants.
public struct ChatInputButton: Equatable, Codable {
    public var label: [ChatInputRun]
    public var action: ReplyMarkupButtonAction
    public var color: ReplyMarkupButton.Style.Color?
    /// `richButtonStyle`'s `link` bit, kept independent of `color` so `link + danger` round-trips.
    public var isLink: Bool

    public init(label: [ChatInputRun], action: ReplyMarkupButtonAction = .disabled, color: ReplyMarkupButton.Style.Color? = nil, isLink: Bool = false) {
        self.label = label
        self.action = action
        self.color = color
        self.isLink = isLink
    }

    private enum CodingKeys: String, CodingKey { case label, action, color, isLink }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.label = try container.decodeIfPresent([ChatInputRun].self, forKey: .label) ?? []
        // `ReplyMarkupButtonAction` is PostboxCoding, not Codable. Carried as a Postbox object blob via
        // the same `RawObjectData` idiom `ChatInputMediaItem` uses for its `Media` — a plain `Data` field
        // would not survive the `AdaptedPostbox*coder` path that drafts actually persist through.
        let raw = try container.decode(AdaptedPostboxDecoder.RawObjectData.self, forKey: .action)
        self.action = ReplyMarkupButtonAction(decoder: PostboxDecoder(buffer: MemoryBuffer(data: raw.data)))
        // Decoded as a raw `Int32` (NOT `Color.self`): the Postbox coder does not support the
        // `singleValueContainer` a `RawRepresentable` enum's synthesized Codable uses. -1 encodes nil.
        let rawColor = try container.decodeIfPresent(Int32.self, forKey: .color) ?? -1
        self.color = rawColor == -1 ? nil : ReplyMarkupButton.Style.Color(rawValue: rawColor)
        self.isLink = try container.decodeIfPresent(Bool.self, forKey: .isLink) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.label, forKey: .label)
        try container.encode(PostboxEncoder().encodeObjectToRawData(self.action), forKey: .action)
        try container.encode(self.color?.rawValue ?? -1, forKey: .color)
        try container.encode(self.isLink, forKey: .isLink)
    }
}

/// A block-level row of buttons — `InstantPageBlock.buttonRow`. The row owns the alignment; a pill
/// does not, so a per-pill alignment that could disagree across the row is not representable.
public struct ChatInputButtonRow: Equatable, Codable {
    public var buttons: [ChatInputButton]
    public var alignment: InstantPageButtonRowAlignment

    public init(buttons: [ChatInputButton], alignment: InstantPageButtonRowAlignment = .justify) {
        self.buttons = buttons
        self.alignment = alignment
    }

    private enum CodingKeys: String, CodingKey { case buttons, alignment }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.buttons = try container.decodeIfPresent([ChatInputButton].self, forKey: .buttons) ?? []
        // Raw `Int32` for the same reason as `color` above. `justify` is rawValue 0, so a row written
        // before this field existed (there are none, but the decode is lenient anyway) reads as justify.
        let raw = try container.decodeIfPresent(Int32.self, forKey: .alignment) ?? 0
        self.alignment = InstantPageButtonRowAlignment(rawValue: raw) ?? .justify
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.buttons, forKey: .buttons)
        try container.encode(self.alignment.rawValue, forKey: .alignment)
    }
}

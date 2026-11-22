import Foundation

public struct TextRun: Codable, Equatable {
    public var text: String
    public var attributes: CharacterAttributes

    public init(text: String, attributes: CharacterAttributes = .plain) {
        self.text = text
        self.attributes = attributes
    }

    /// Length in UTF-16 units (matches NSString / NSTextLocation semantics used by TextKit).
    public var utf16Count: Int { text.utf16.count }
}

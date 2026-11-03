import Foundation

public struct ParagraphAttributes: Codable, Equatable {
    public var alignment: TextAlignment
    public var firstLineIndent: Double
    public var headIndent: Double
    public var paragraphSpacingBefore: Double
    public var paragraphSpacingAfter: Double
    public var lineHeightMultiple: Double

    public init(
        alignment: TextAlignment = .natural,
        firstLineIndent: Double = 0,
        headIndent: Double = 0,
        paragraphSpacingBefore: Double = 0,
        paragraphSpacingAfter: Double = 0,
        lineHeightMultiple: Double = 1
    ) {
        self.alignment = alignment
        self.firstLineIndent = firstLineIndent
        self.headIndent = headIndent
        self.paragraphSpacingBefore = paragraphSpacingBefore
        self.paragraphSpacingAfter = paragraphSpacingAfter
        self.lineHeightMultiple = lineHeightMultiple
    }

    public static let `default` = ParagraphAttributes()
}

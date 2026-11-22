import Foundation
import UIKit
import Display

/// The four fonts a message's text is laid out in: its body and its bold, italic and bold-italic spans.
public struct ChatMessageTextFonts {
    public let regular: UIFont
    public let bold: UIFont
    public let italic: UIFont
    public let boldItalic: UIFont

    public init(regular: UIFont, bold: UIFont, italic: UIFont, boldItalic: UIFont) {
        self.regular = regular
        self.bold = bold
        self.italic = italic
        self.boldItalic = boldItalic
    }

    /// New York at the body size: bold is `.bold`, bold-italic `.semibold` plus italic (spec 5.11).
    public static func newYork(baseFontSize: CGFloat) -> ChatMessageTextFonts {
        return ChatMessageTextFonts(
            regular: Font.with(size: baseFontSize, design: .serif),
            bold: Font.with(size: baseFontSize, design: .serif, weight: .bold),
            italic: Font.with(size: baseFontSize, design: .serif, traits: .italic),
            boldItalic: Font.with(size: baseFontSize, design: .serif, weight: .semibold, traits: .italic)
        )
    }
}

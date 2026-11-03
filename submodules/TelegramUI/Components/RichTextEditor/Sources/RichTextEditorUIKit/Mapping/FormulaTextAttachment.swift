#if canImport(UIKit)
import UIKit

@available(iOS 13.0, *)
public struct RichTextFormulaRenderContext {
    public let latex: String
    public let fontSize: CGFloat
    public let textColor: UIColor

    public init(latex: String, fontSize: CGFloat, textColor: UIColor) {
        self.latex = latex
        self.fontSize = fontSize
        self.textColor = textColor
    }
}

@available(iOS 13.0, *)
public struct RichTextFormulaRenderResult {
    public let image: UIImage
    public let size: CGSize
    public let ascent: CGFloat
    public let descent: CGFloat

    public init(image: UIImage, size: CGSize, ascent: CGFloat, descent: CGFloat) {
        self.image = image
        self.size = size
        self.ascent = ascent
        self.descent = descent
    }
}

/// A rendered formula atom. The editor owns only the neutral image + baseline metrics; math rendering is
/// injected by the host so this package stays free of formula-rendering dependencies.
@available(iOS 13.0, *)
public final class FormulaTextAttachment: NSTextAttachment, RichTextInlineAttachment {
    public let latex: String
    let renderResult: RichTextFormulaRenderResult

    init(latex: String, renderResult: RichTextFormulaRenderResult) {
        self.latex = latex
        self.renderResult = renderResult
        super.init(data: nil, ofType: nil)
        self.image = renderResult.image
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) not used")
    }

    /// Whether `other` is a rendering of the SAME atom with the same geometry — what a document set
    /// asks when it decides whether an engine block changed. Deliberately NOT `isEqual`: two adjacent
    /// atoms with equal attachments would coalesce into one attribute run, and every consumer that
    /// walks attachments expects one object per character. A fresh render of an unchanged model mints
    /// new attachment objects, so `NSAttributedString` equality alone called every block holding one
    /// changed (composer harness p15, `HarnessAtomParagraphReplayIdentityTests`).
    public func drawsTheSameAs(_ other: NSTextAttachment) -> Bool {
        guard let other = other as? FormulaTextAttachment else { return false }
        return latex == other.latex && renderResult.size == other.renderResult.size
            && renderResult.ascent == other.renderResult.ascent && renderResult.descent == other.renderResult.descent
            && renderResult.image.size == other.renderResult.image.size
            && renderResult.image.scale == other.renderResult.image.scale
    }

    /// `RichTextInlineAttachment`: font-independent — a formula is rendered at a fixed size.
    public func reservedBox(forFont font: UIFont) -> CGRect { box() }

    private func box() -> CGRect {
        let width = max(1.0, renderResult.size.width)
        let height = max(1.0, renderResult.size.height)
        return CGRect(x: 0.0, y: -renderResult.descent, width: width, height: height)
    }

    @available(iOS 15.0, *)
    public override func attachmentBounds(for attributes: [NSAttributedString.Key: Any], location: NSTextLocation,
                                   textContainer: NSTextContainer?, proposedLineFragment: CGRect,
                                   position: CGPoint) -> CGRect {
        return box()
    }

    public override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect,
                                   glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        return box()
    }
}
#endif

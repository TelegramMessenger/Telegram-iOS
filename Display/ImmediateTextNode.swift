import Foundation

public final class ImmediateTextNode: TextNode {
    public var attributedText: NSAttributedString?
    public var textAlignment: NSTextAlignment = .natural
    public var maximumNumberOfLines: Int = 1
    public var lineSpacing: CGFloat = 0.0
    
    public func updateLayout(_ constrainedSize: CGSize) -> CGSize {
        let makeLayout = TextNode.asyncLayout(self)
        let (layout, apply) = makeLayout(TextNodeLayoutArguments(attributedString: self.attributedText, backgroundColor: nil, maximumNumberOfLines: self.maximumNumberOfLines, truncationType: .end, constrainedSize: constrainedSize, alignment: self.textAlignment, lineSpacing: self.lineSpacing, cutout: nil, insets: UIEdgeInsets()))
        let _ = apply()
        return layout.size
    }
}

import Foundation

public final class ImmediateTextNode: TextNode {
    public var attributedText: NSAttributedString?
    public var textAlignment: NSTextAlignment = .natural
    
    public func updateLayout(_ constrainedSize: CGSize) -> CGSize {
        let makeLayout = TextNode.asyncLayout(self)
        let (layout, apply) = makeLayout(TextNodeLayoutArguments(attributedString: self.attributedText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: constrainedSize, alignment: self.textAlignment, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
        let _ = apply()
        return layout.size
    }
}

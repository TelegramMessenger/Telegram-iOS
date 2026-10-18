import Foundation
import UIKit

/// A text drawn in two layers, as `MultiScaleTextNode`'s states are: `tintView` draws everything but emoji, in white, and
/// takes its colour from its layer's multiply colour (`textColor`), so a transition can run that colour on the render
/// server; `emojiView` draws only the emoji, untinted. A tint therefore never reaches the emoji.
open class SplitTintTextView: UIView {
    public let tintView: ImmediateTextView
    public let emojiView: ImmediateTextView

    /// The text: its fonts and attributes; its colour is `textColor`.
    public var attributedText: NSAttributedString?

    public var textColor: UIColor = .black {
        didSet {
            self.tintView.layer.layerTintColor = self.textColor.cgColor
        }
    }

    public var maximumNumberOfLines: Int = 1 {
        didSet {
            self.tintView.maximumNumberOfLines = self.maximumNumberOfLines
            self.emojiView.maximumNumberOfLines = self.maximumNumberOfLines
        }
    }

    public var truncationType: CTLineTruncationType = .end {
        didSet {
            self.tintView.truncationType = self.truncationType
            self.emojiView.truncationType = self.truncationType
        }
    }

    override public init(frame: CGRect) {
        self.tintView = ImmediateTextView()
        self.tintView.renderContentTypes = TextNode.RenderContentTypes.all.subtracting(.emoji)
        self.tintView.layer.layerTintColor = UIColor.black.cgColor
        self.emojiView = ImmediateTextView()
        self.emojiView.renderContentTypes = .emoji

        super.init(frame: frame)

        self.isUserInteractionEnabled = false
        self.addSubview(self.tintView)
        self.addSubview(self.emojiView)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func updateLayout(_ constrainedSize: CGSize) -> CGSize {
        var text: NSAttributedString?
        if let attributedText = self.attributedText {
            let white = NSMutableAttributedString(attributedString: attributedText)
            white.addAttribute(.foregroundColor, value: UIColor.white, range: NSRange(location: 0, length: white.length))
            text = white
        }
        self.tintView.attributedText = text
        self.emojiView.attributedText = text
        let size = self.tintView.updateLayout(constrainedSize)
        let _ = self.emojiView.updateLayout(constrainedSize)
        self.tintView.frame = CGRect(origin: CGPoint(), size: size)
        self.emojiView.frame = CGRect(origin: CGPoint(), size: size)
        return size
    }
}

import Foundation
import UIKit
import ChatInputTextNode
import ChatSendMessageActionUI

// Adapts any ChatRichTextInputNode backend to the send-options morph's source protocol by
// reading seam members only — so it works for the current UITextView backend and any future
// (e.g. TextKit-2) backend without change.
final class ChatRichTextInputMorphSource: ChatSendMessageContextScreenTextInputSource {
    private let node: ChatRichTextInputNode

    init(_ node: ChatRichTextInputNode) {
        self.node = node
    }

    var sourceView: UIView {
        // The inner editor view (== the old inputTextView). NOT asNode.view: under the
        // Model-A passive wrapper the editor child is inset within the wrapper, so the
        // wrapper's bounds/frame would shift the morph's start-frame geometry.
        return self.node.inputView
    }
    var attributedText: NSAttributedString? {
        return self.node.attributedText
    }
    var defaultTextContainerInset: UIEdgeInsets {
        return self.node.textContainerInset
    }
    var contentOffset: CGPoint {
        return self.node.inputContentOffset
    }
    var currentRightInset: CGFloat {
        return self.node.currentRightInset
    }
    var quoteLineStyle: ChatInputTextView.Theme.Quote.LineStyle? {
        return self.node.inputTheme?.quote.lineStyle
    }
}

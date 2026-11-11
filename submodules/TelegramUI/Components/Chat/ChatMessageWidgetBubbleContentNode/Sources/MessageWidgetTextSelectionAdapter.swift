import Foundation
import UIKit
import AsyncDisplayKit
import Display
import MessageWidget

/// What `TextSelectionNode` selects in a lifted widget bubble (sdk-v1 §5.10): the widget's selectable text, as its
/// runtime exported it, in the widget view's coordinates. `TextSelectionNode` keeps its text node for good, so a new
/// export (the widget keeps running) is swapped in here, in place.
final class MessageWidgetTextSelectionAdapter: ASDisplayNode, TextNodeProtocol {
    private(set) var text: MessageWidgetSelectableText
    private var attributedText: NSAttributedString

    init(text: MessageWidgetSelectableText) {
        self.text = text
        self.attributedText = NSAttributedString(string: text.text as String)
        super.init()
        self.isUserInteractionEnabled = false
    }

    func update(_ text: MessageWidgetSelectableText) {
        self.text = text
        self.attributedText = NSAttributedString(string: text.text as String)
    }

    var currentText: NSAttributedString? {
        return self.attributedText
    }

    func attributesAtPoint(_ point: CGPoint, orNearest: Bool) -> (Int, [NSAttributedString.Key: Any])? {
        return self.text.index(at: point, nearest: orNearest).map { ($0, [:]) }
    }

    func textRangeRects(in range: NSRange) -> (rects: [CGRect], start: TextRangeRectEdge, end: TextRangeRectEdge)? {
        guard let result = self.text.rangeRects(range) else {
            return nil
        }
        return (result.rects, TextRangeRectEdge(x: result.start.x, y: result.start.y, height: result.start.height), TextRangeRectEdge(x: result.end.x, y: result.end.y, height: result.end.height))
    }
}

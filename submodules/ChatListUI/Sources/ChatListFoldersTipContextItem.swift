import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ContextUI
import TelegramPresentationData
import AppBundle
import Markdown

final class ChatListFoldersTipContextItem: ContextMenuCustomItem {
    let text: String

    init(text: String) {
        self.text = text
    }

    func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return ChatListFoldersTipContextItemNode(presentationData: presentationData, text: self.text)
    }
}

private final class ChatListFoldersTipContextItemNode: ASDisplayNode, ContextMenuCustomNode {
    private let text: String
    private let textNode: ImmediateTextNode

    init(presentationData: PresentationData, text: String) {
        self.text = text
        self.textNode = ImmediateTextNode()
        self.textNode.isAccessibilityElement = false
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        self.textNode.maximumNumberOfLines = 2
        self.textNode.lineSpacing = 0.1

        super.init()

        self.isAccessibilityElement = true
        self.accessibilityTraits = [.staticText]
        self.isUserInteractionEnabled = false

        self.addSubnode(self.textNode)
        self.updateTheme(presentationData: presentationData)
    }

    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let sideInset: CGFloat = 18.0
        let verticalInset: CGFloat = 11.0
        let textSize = self.textNode.updateLayout(CGSize(width: max(1.0, constrainedWidth - sideInset * 2.0), height: .greatestFiniteMagnitude))

        return (CGSize(width: textSize.width + sideInset * 2.0, height: textSize.height + verticalInset * 2.0), { size, transition in
            let textFrame = CGRect(origin: CGPoint(x: sideInset, y: floor((size.height - textSize.height) / 2.0)), size: textSize)
            transition.updateFrameAdditive(node: self.textNode, frame: textFrame)
        })
    }

    func updateTheme(presentationData: PresentationData) {
        let fontSize = floor(presentationData.listsFontSize.baseDisplaySize * 14.0 / 17.0) - 1.0
        let textColor = presentationData.theme.contextMenu.primaryColor
        let image = generateTintedImage(image: UIImage(bundleImageName: "Chat List/ChatsMini"), color: textColor)
        let text = image != nil ? self.text : self.text.replacingOccurrences(of: "# ", with: "")
        let attributedText = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(
            body: MarkdownAttributeSet(font: Font.regular(fontSize), textColor: textColor),
            bold: MarkdownAttributeSet(font: Font.semibold(fontSize), textColor: textColor),
            link: MarkdownAttributeSet(font: Font.semibold(fontSize), textColor: textColor),
            linkAttribute: { _ in return nil }
        )))

        self.accessibilityLabel = attributedText.string.replacingOccurrences(of: "# ", with: "")

        if let image, let range = attributedText.string.range(of: "#") {
            let iconRange = NSRange(range, in: attributedText.string)
            let placeholderWidth = attributedText.attributedSubstring(from: iconRange).size().width
            // Reserve the icon's width without changing the surrounding line height.
            attributedText.addAttributes([
                .attachment: image,
                .kern: image.size.width - placeholderWidth
            ], range: iconRange)
        }
        self.textNode.attributedText = attributedText
    }

    func canBeHighlighted() -> Bool {
        return false
    }

    func updateIsHighlighted(isHighlighted: Bool) {
    }

    func performAction() {
    }
}

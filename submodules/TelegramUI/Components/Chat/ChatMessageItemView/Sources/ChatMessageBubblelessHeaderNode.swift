import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import AccountContext
import ChatMessageItem
import ChatMessageItemCommon

/// Without bubbles: the author's name and time that head an incoming run, for rows without a bubble header of their own
/// (stickers, animated stickers, large emoji). It matches the header `ChatMessageBubbleItemNode` draws for text and
/// media: the name in its colour, the time after it in the secondary colour, on the name's baseline, and a post's view
/// count after the time.
public final class ChatMessageBubblelessHeaderNode: ASDisplayNode {
    private var nameNode: TextNode?
    private var dateNode: TextNode?
    private var viewsIconNode: ASImageNode?
    private var viewsNode: TextNode?

    override public init() {
        super.init()

        self.isUserInteractionEnabled = false
    }

    // A layout made before the header existed hands back text nodes of its own, so the header takes whichever nodes its
    // layout applied to.
    private func update(nameNode: TextNode, dateNode: TextNode) {
        if self.nameNode !== nameNode {
            self.nameNode?.removeFromSupernode()
            nameNode.isUserInteractionEnabled = false
            self.nameNode = nameNode
            self.addSubnode(nameNode)
        }
        if self.dateNode !== dateNode {
            self.dateNode?.removeFromSupernode()
            dateNode.isUserInteractionEnabled = false
            self.dateNode = dateNode
            self.addSubnode(dateNode)
        }
    }

    private func updateViews(_ views: (icon: UIImage, iconFrame: CGRect, textFrame: CGRect, apply: () -> TextNode)?) {
        guard let views else {
            self.viewsIconNode?.removeFromSupernode()
            self.viewsIconNode = nil
            self.viewsNode?.removeFromSupernode()
            self.viewsNode = nil
            return
        }
        let iconNode: ASImageNode
        if let current = self.viewsIconNode {
            iconNode = current
        } else {
            iconNode = ASImageNode()
            iconNode.isLayerBacked = true
            iconNode.displaysAsynchronously = false
            self.viewsIconNode = iconNode
            self.addSubnode(iconNode)
        }
        iconNode.image = views.icon
        iconNode.frame = views.iconFrame
        let viewsNode = views.apply()
        if self.viewsNode !== viewsNode {
            self.viewsNode?.removeFromSupernode()
            viewsNode.isUserInteractionEnabled = false
            self.viewsNode = viewsNode
            self.addSubnode(viewsNode)
        }
        viewsNode.frame = views.textFrame
    }

    /// The name's font, which the run's lead (and so the avatar beside it) is measured from.
    public static func nameFont(presentationData: ChatPresentationData) -> UIFont {
        return Font.semibold(floor(presentationData.fontSize.baseDisplaySize * 14.0 / 17.0))
    }

    public static func asyncLayout(_ node: ChatMessageBubblelessHeaderNode?) -> (_ item: ChatMessageItem, _ author: EnginePeer, _ dateText: String, _ viewCount: Int?, _ constrainedWidth: CGFloat) -> (size: CGSize, nameHeight: CGFloat, apply: () -> ChatMessageBubblelessHeaderNode) {
        let nameLayout = TextNode.asyncLayout(node?.nameNode)
        let dateLayout = TextNode.asyncLayout(node?.dateNode)
        let viewsLayout = TextNode.asyncLayout(node?.viewsNode)

        return { item, author, dateText, viewCount, constrainedWidth in
            let theme = item.presentationData.theme.theme
            let nameFont = ChatMessageBubblelessHeaderNode.nameFont(presentationData: item.presentationData)
            let dateFont = Font.regular(chatMessageBubblelessHeaderTimeFontSize(baseDisplaySize: item.presentationData.fontSize.baseDisplaySize))

            let nameColor: UIColor
            switch author.nameColor {
            case let .preset(nameColorValue):
                nameColor = item.context.peerNameColors.get(nameColorValue, dark: theme.overallDarkAppearance).main
            case let .collectible(collectibleColor):
                nameColor = collectibleColor.peerNameColors(dark: theme.overallDarkAppearance).main
            default:
                nameColor = item.context.peerNameColors.get(.blue, dark: theme.overallDarkAppearance).main
            }

            let dateSpacing = chatMessageBubblelessHeaderTimeSpacing
            let secondaryColor = theme.chat.message.incoming.secondaryTextColor
            let (dateTextLayout, dateApply) = dateLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: dateText, font: dateFont, textColor: secondaryColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0.0, constrainedWidth * 0.5), height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))

            // A post's views follow the time: an eye and a short number, as in the header of a post with a bubble's
            // content (`ChatMessageBubbleItemNode`).
            var views: (icon: UIImage, layout: TextNodeLayout, apply: () -> TextNode)?
            var viewsWidth: CGFloat = 0.0
            if let viewCount {
                let viewsText = compactNumericCountString(viewCount, decimalSeparator: item.presentationData.dateTimeFormat.decimalSeparator)
                let (viewsTextLayout, viewsApply) = viewsLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: viewsText, font: dateFont, textColor: secondaryColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                let icon = PresentationResourcesChat.principalGraphics(theme: theme, wallpaper: item.presentationData.theme.wallpaper, bubbleCorners: item.presentationData.chatBubbleCorners).incomingDateAndStatusImpressionIcon
                views = (icon, viewsTextLayout, viewsApply)
                viewsWidth = chatMessageBubblelessHeaderViewsSpacing + icon.size.width + chatMessageBubblelessHeaderViewsIconSpacing + viewsTextLayout.size.width
            }

            let (nameTextLayout, nameApply) = nameLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: author.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder), font: nameFont, textColor: nameColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0.0, constrainedWidth - dateTextLayout.size.width - dateSpacing - viewsWidth), height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))

            let size = CGSize(width: nameTextLayout.size.width + dateSpacing + dateTextLayout.size.width + viewsWidth, height: nameTextLayout.size.height)

            return (size, nameTextLayout.size.height, {
                let node = node ?? ChatMessageBubblelessHeaderNode()
                let nameNode = nameApply()
                let dateNode = dateApply()
                node.update(nameNode: nameNode, dateNode: dateNode)
                nameNode.frame = CGRect(origin: CGPoint(), size: nameTextLayout.size)
                // Baselines line up: the smaller time sits lower by the difference in ascenders.
                let dateFrame = CGRect(origin: CGPoint(x: nameTextLayout.size.width + dateSpacing, y: floorToScreenPixels(nameFont.ascender - dateFont.ascender)), size: dateTextLayout.size)
                dateNode.frame = dateFrame
                node.updateViews(views.map { views in
                    let iconFrame = CGRect(origin: CGPoint(x: dateFrame.maxX + chatMessageBubblelessHeaderViewsSpacing, y: dateFrame.minY + 1.0 + floor((dateFrame.height - views.icon.size.height) * 0.5)), size: views.icon.size)
                    let textFrame = CGRect(origin: CGPoint(x: iconFrame.maxX + chatMessageBubblelessHeaderViewsIconSpacing, y: dateFrame.minY), size: views.layout.size)
                    return (views.icon, iconFrame, textFrame, views.apply)
                })
                return node
            })
        }
    }
}

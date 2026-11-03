import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramCore
import TelegramPresentationData
import AvatarNode
import AppBundle

final class PeerInfoScreenCommunityItem: PeerInfoScreenItem {
    let id: AnyHashable
    let context: AccountContext
    let community: TelegramCommunity
    let chatCount: Int?
    let action: () -> Void

    init(id: AnyHashable, context: AccountContext, community: TelegramCommunity, chatCount: Int?, action: @escaping () -> Void) {
        self.id = id
        self.context = context
        self.community = community
        self.chatCount = chatCount
        self.action = action
    }

    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenCommunityItemNode()
    }
}

private final class PeerInfoScreenCommunityItemNode: PeerInfoScreenItemNode {
    private let selectionNode: PeerInfoScreenSelectableBackgroundNode
    private let maskNode: ASImageNode
    private let avatarShadowNode: ASImageNode
    private let avatarNode: AvatarNode
    private let titleNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    private let arrowNode: ASImageNode
    private let bottomSeparatorNode: ASDisplayNode
    private let activateArea: AccessibilityAreaNode

    private var item: PeerInfoScreenCommunityItem?

    override init() {
        var bringToFrontForHighlightImpl: (() -> Void)?
        self.selectionNode = PeerInfoScreenSelectableBackgroundNode(bringToFrontForHighlight: {
            bringToFrontForHighlightImpl?()
        })

        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false

        self.avatarShadowNode = ASImageNode()
        self.avatarShadowNode.displaysAsynchronously = false
        self.avatarShadowNode.displayWithoutProcessing = true

        self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 18.0))

        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.maximumNumberOfLines = 1

        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.displaysAsynchronously = false
        self.subtitleNode.isUserInteractionEnabled = false
        self.subtitleNode.maximumNumberOfLines = 1

        self.arrowNode = ASImageNode()
        self.arrowNode.isLayerBacked = true
        self.arrowNode.displaysAsynchronously = false
        self.arrowNode.displayWithoutProcessing = true
        self.arrowNode.isUserInteractionEnabled = false

        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true

        self.activateArea = AccessibilityAreaNode()

        super.init()

        bringToFrontForHighlightImpl = { [weak self] in
            self?.bringToFrontForHighlight?()
        }

        self.addSubnode(self.bottomSeparatorNode)
        self.addSubnode(self.selectionNode)
        self.addSubnode(self.maskNode)
        self.addSubnode(self.avatarShadowNode)
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.arrowNode)
        self.addSubnode(self.activateArea)
    }

    override func update(context: AccountContext, width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenCommunityItem else {
            return 10.0
        }

        self.item = item
        self.selectionNode.pressed = item.action

        let sideInset: CGFloat = 16.0 + safeInsets.left
        let avatarSize: CGFloat = 30.0
        let height: CGFloat = 58.0
        let titleFont = Font.regular(presentationData.listsFontSize.itemListBaseFontSize)
        let subtitleFont = Font.regular(13.0)

        let subtitle: String?
        if let chatCount = item.chatCount {
            subtitle = presentationData.strings.PeerInfo_Community(Int32(clamping: chatCount))
        } else {
            subtitle = nil
        }

        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        self.titleNode.attributedText = NSAttributedString(string: item.community.title, font: titleFont, textColor: presentationData.theme.list.itemPrimaryTextColor)
        self.subtitleNode.attributedText = NSAttributedString(string: subtitle ?? "", font: subtitleFont, textColor: presentationData.theme.list.itemSecondaryTextColor)

        self.avatarNode.setPeer(
            context: item.context,
            theme: presentationData.theme,
            peer: EnginePeer(item.community),
            clipStyle: .roundedRect,
            displayDimensions: CGSize(width: avatarSize, height: avatarSize)
        )

        let arrowImage = PresentationResourcesItemList.disclosureArrowImage(presentationData.theme)
        self.arrowNode.image = arrowImage

        let rightInset: CGFloat = 16.0 + safeInsets.right + (arrowImage?.size.width ?? 0.0) + 12.0
        let textLeftInset = sideInset + avatarSize + 12.0
        let textConstrainedWidth = max(1.0, width - textLeftInset - rightInset)
        let titleSize = self.titleNode.updateLayout(CGSize(width: textConstrainedWidth, height: .greatestFiniteMagnitude))
        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: textConstrainedWidth, height: .greatestFiniteMagnitude))

        let avatarFrame = CGRect(
            origin: CGPoint(x: sideInset, y: floorToScreenPixels((height - avatarSize) / 2.0)),
            size: CGSize(width: avatarSize, height: avatarSize)
        )
        if let shadowImage = UIImage(bundleImageName: "Components/CommunityShadow") {
            self.avatarShadowNode.isHidden = false
            self.avatarShadowNode.image = generateTintedImage(image: shadowImage, color: presentationData.theme.list.itemSecondaryTextColor)

            let aspectRatio = shadowImage.size.width / shadowImage.size.height
            let shadowSize = CGSize(width: floor(avatarSize * aspectRatio * 0.98), height: avatarSize)
            transition.updateFrame(node: self.avatarShadowNode, frame: shadowSize.centered(around: avatarFrame.center).offsetBy(dx: -5.0 + UIScreenPixel, dy: 0.0))
        } else {
            self.avatarShadowNode.isHidden = true
        }
        transition.updateFrame(node: self.avatarNode, frame: avatarFrame)

        let textHeight: CGFloat
        if subtitle != nil {
            textHeight = titleSize.height + subtitleSize.height + 2.0
        } else {
            textHeight = titleSize.height
        }
        let textTop = floorToScreenPixels((height - textHeight) / 2.0)
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: textLeftInset, y: textTop), size: titleSize))
        transition.updateFrame(node: self.subtitleNode, frame: CGRect(origin: CGPoint(x: textLeftInset, y: textTop + titleSize.height + 1.0), size: subtitleSize))
        transition.updateAlpha(node: self.subtitleNode, alpha: subtitle == nil ? 0.0 : 1.0)

        if let arrowImage {
            let arrowFrame = CGRect(
                origin: CGPoint(x: width - 7.0 - arrowImage.size.width - safeInsets.right, y: floorToScreenPixels((height - arrowImage.size.height) / 2.0)),
                size: arrowImage.size
            )
            transition.updateFrame(node: self.arrowNode, frame: arrowFrame)
        }

        let hasCorners = hasCorners && (topItem == nil || bottomItem == nil)
        let hasTopCorners = hasCorners && topItem == nil
        let hasBottomCorners = hasCorners && bottomItem == nil

        self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners, glass: true) : nil
        self.maskNode.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))
        self.bottomSeparatorNode.isHidden = hasBottomCorners

        let highlightNodeOffset: CGFloat = topItem == nil ? 0.0 : UIScreenPixel
        self.selectionNode.update(size: CGSize(width: width, height: height + highlightNodeOffset), theme: presentationData.theme, transition: transition)
        transition.updateFrame(node: self.selectionNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -highlightNodeOffset), size: CGSize(width: width, height: height + highlightNodeOffset)))

        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: textLeftInset, y: height - UIScreenPixel), size: CGSize(width: width - textLeftInset - 16.0 - safeInsets.right, height: UIScreenPixel)))
        transition.updateAlpha(node: self.bottomSeparatorNode, alpha: bottomItem == nil ? 0.0 : 1.0)

        self.activateArea.accessibilityLabel = item.community.title
        self.activateArea.accessibilityValue = subtitle
        self.activateArea.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))

        return height
    }
}

import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import TelegramPresentationData
import ContextUI
import AgentConnectScreen

/// A connected AI provider on an agent bot's profile: tap makes it the active one, long press opens its context menu.
/// With `action` nil (the only provider, nothing to switch to) tap opens the context menu too.
final class PeerInfoScreenAgentProviderItem: PeerInfoScreenItem {
    let id: AnyHashable
    let context: AccountContext
    let provider: EngineAgentProvider
    let isActive: Bool
    let action: (() -> Void)?
    let contextAction: (ASDisplayNode, ContextGesture?) -> Void

    init(id: AnyHashable, context: AccountContext, provider: EngineAgentProvider, isActive: Bool, action: (() -> Void)?, contextAction: @escaping (ASDisplayNode, ContextGesture?) -> Void) {
        self.id = id
        self.context = context
        self.provider = provider
        self.isActive = isActive
        self.action = action
        self.contextAction = contextAction
    }

    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenAgentProviderItemNode()
    }
}

private final class PeerInfoScreenAgentProviderItemNode: PeerInfoScreenItemNode {
    private let containerNode: ContextControllerSourceNode
    private let contextSourceNode: ContextExtractedContentContainingNode
    private let extractedBackgroundImageNode: ASImageNode
    private let selectionNode: PeerInfoScreenSelectableBackgroundNode
    private let maskNode: ASImageNode
    private let icon = ComponentView<Empty>()
    private let titleNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    private let checkNode: ASImageNode
    private let bottomSeparatorNode: ASDisplayNode
    private let activateArea: AccessibilityAreaNode

    private var item: PeerInfoScreenAgentProviderItem?
    private var theme: PresentationTheme?

    override init() {
        var bringToFrontForHighlightImpl: (() -> Void)?

        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()

        self.extractedBackgroundImageNode = ASImageNode()
        self.extractedBackgroundImageNode.displaysAsynchronously = false
        self.extractedBackgroundImageNode.alpha = 0.0

        self.selectionNode = PeerInfoScreenSelectableBackgroundNode(bringToFrontForHighlight: {
            bringToFrontForHighlightImpl?()
        })

        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false

        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.maximumNumberOfLines = 1

        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.displaysAsynchronously = false
        self.subtitleNode.isUserInteractionEnabled = false
        self.subtitleNode.maximumNumberOfLines = 1

        self.checkNode = ASImageNode()
        self.checkNode.isLayerBacked = true
        self.checkNode.displaysAsynchronously = false
        self.checkNode.displayWithoutProcessing = true

        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true

        self.activateArea = AccessibilityAreaNode()

        super.init()

        bringToFrontForHighlightImpl = { [weak self] in
            self?.bringToFrontForHighlight?()
        }

        self.addSubnode(self.bottomSeparatorNode)

        // The highlight button sits inside the context container so that the container's long press gesture sees the
        // same touches; the extracted content takes none, or it would cover the button.
        self.containerNode.addSubnode(self.selectionNode)
        self.contextSourceNode.isUserInteractionEnabled = false
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)

        self.addSubnode(self.maskNode)

        self.contextSourceNode.contentNode.addSubnode(self.extractedBackgroundImageNode)
        self.contextSourceNode.contentNode.addSubnode(self.titleNode)
        self.contextSourceNode.contentNode.addSubnode(self.subtitleNode)
        self.contextSourceNode.contentNode.addSubnode(self.checkNode)

        self.addSubnode(self.activateArea)

        self.containerNode.activated = { [weak self] gesture, _ in
            guard let self, let item = self.item else {
                gesture.cancel()
                return
            }
            item.contextAction(self.contextSourceNode, gesture)
        }

        self.contextSourceNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, transition in
            guard let self, let theme = self.theme else {
                return
            }
            if isExtracted {
                self.extractedBackgroundImageNode.image = generateStretchableFilledCircleImage(diameter: 52.0, color: theme.list.plainBackgroundColor)
            }
            transition.updateAlpha(node: self.extractedBackgroundImageNode, alpha: isExtracted ? 1.0 : 0.0)
        }
    }

    override func update(context: AccountContext, width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenAgentProviderItem else {
            return 10.0
        }

        self.item = item
        self.theme = presentationData.theme
        if let action = item.action {
            self.selectionNode.pressed = action
        } else {
            self.selectionNode.pressed = { [weak self] in
                guard let self, let item = self.item else {
                    return
                }
                item.contextAction(self.contextSourceNode, nil)
            }
        }

        let sideInset: CGFloat = 16.0 + safeInsets.left
        let iconSize: CGFloat = 30.0
        let height: CGFloat = 60.0

        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        self.titleNode.attributedText = NSAttributedString(string: item.provider.title, font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize), textColor: presentationData.theme.list.itemPrimaryTextColor)
        self.subtitleNode.attributedText = NSAttributedString(string: item.provider.vendor, font: Font.regular(floor(presentationData.listsFontSize.itemListBaseFontSize * 15.0 / 17.0)), textColor: presentationData.theme.list.itemSecondaryTextColor)

        let checkImage = PresentationResourcesItemList.checkIconImage(presentationData.theme)
        self.checkNode.image = checkImage
        self.checkNode.isHidden = !item.isActive

        let iconFrame = CGRect(origin: CGPoint(x: sideInset, y: floorToScreenPixels((height - iconSize) / 2.0)), size: CGSize(width: iconSize, height: iconSize))
        let _ = self.icon.update(
            transition: .immediate,
            component: AnyComponent(AgentProviderIconComponent(context: item.context, theme: presentationData.theme, provider: item.provider, size: iconSize)),
            environment: {},
            containerSize: iconFrame.size
        )
        if let iconView = self.icon.view {
            if iconView.superview == nil {
                self.contextSourceNode.contentNode.view.addSubview(iconView)
            }
            transition.updateFrame(view: iconView, frame: iconFrame)
        }

        let rightInset: CGFloat = 16.0 + safeInsets.right + (item.isActive ? (checkImage?.size.width ?? 0.0) + 12.0 : 0.0)
        let textLeftInset = sideInset + iconSize + 16.0
        let textConstrainedWidth = max(1.0, width - textLeftInset - rightInset)
        let titleSize = self.titleNode.updateLayout(CGSize(width: textConstrainedWidth, height: .greatestFiniteMagnitude))
        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: textConstrainedWidth, height: .greatestFiniteMagnitude))

        let textHeight = titleSize.height + subtitleSize.height + 1.0
        let textTop = floorToScreenPixels((height - textHeight) / 2.0)
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: textLeftInset, y: textTop), size: titleSize))
        transition.updateFrame(node: self.subtitleNode, frame: CGRect(origin: CGPoint(x: textLeftInset, y: textTop + titleSize.height + 1.0), size: subtitleSize))

        if let checkImage {
            transition.updateFrame(node: self.checkNode, frame: CGRect(origin: CGPoint(x: width - 16.0 - safeInsets.right - checkImage.size.width, y: floorToScreenPixels((height - checkImage.size.height) / 2.0)), size: checkImage.size))
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

        let contentSize = CGSize(width: width, height: height)
        self.containerNode.frame = CGRect(origin: CGPoint(), size: contentSize)
        self.contextSourceNode.frame = CGRect(origin: CGPoint(), size: contentSize)
        self.contextSourceNode.contentNode.frame = CGRect(origin: CGPoint(), size: contentSize)
        self.extractedBackgroundImageNode.frame = CGRect(origin: CGPoint(), size: contentSize)
        self.contextSourceNode.contentRect = CGRect(origin: CGPoint(), size: contentSize)

        self.activateArea.accessibilityLabel = item.provider.title
        self.activateArea.accessibilityValue = item.provider.vendor
        self.activateArea.accessibilityTraits = item.isActive ? [.button, .selected] : .button
        // The same paths as the tap (the action, or the menu when there is none) and the long press (the menu).
        self.activateArea.activate = { [weak self] in
            guard let self, let item = self.item else {
                return false
            }
            if let action = item.action {
                action()
            } else {
                item.contextAction(self.contextSourceNode, nil)
            }
            return true
        }
        if self.activateArea.view.accessibilityCustomActions?.first?.name != presentationData.strings.Common_More {
            self.activateArea.view.accessibilityCustomActions = [UIAccessibilityCustomAction(name: presentationData.strings.Common_More, actionHandler: { [weak self] _ in
                guard let self, let item = self.item else {
                    return false
                }
                item.contextAction(self.contextSourceNode, nil)
                return true
            })]
        }
        self.activateArea.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))

        return height
    }
}

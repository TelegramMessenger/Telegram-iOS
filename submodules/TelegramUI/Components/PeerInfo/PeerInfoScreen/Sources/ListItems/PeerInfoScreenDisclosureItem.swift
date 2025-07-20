import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import TextNodeWithEntities
import AccountContext

final class PeerInfoScreenDisclosureItem: PeerInfoScreenItem {
    enum Label {
        enum LabelColor {
            case generic
            case accent
        }
        
        case none
        case text(String)
        case attributedText(NSAttributedString)
        case coloredText(String, LabelColor)
        case badge(String, UIColor)
        case semitransparentBadge(String, UIColor)
        case titleBadge(String, UIColor)
        case image(UIImage, CGSize)
        case labelBadge(String)
        
        var text: String {
            switch self {
            case .none, .image:
                return ""
            case let .attributedText(text):
                return text.string
            case let .text(text), let .coloredText(text, _), let .badge(text, _), let .semitransparentBadge(text, _), let .titleBadge(text, _), let .labelBadge(text):
                return text
            }
        }
        
        var badgeColor: UIColor? {
            switch self {
            case .none, .text, .coloredText, .image, .attributedText, .labelBadge:
                return nil
            case let .badge(_, color), let .semitransparentBadge(_, color), let .titleBadge(_, color):
                return color
            }
        }
    }
    
    let id: AnyHashable
    let label: Label
    let additionalBadgeLabel: String?
    let additionalBadgeIcon: UIImage?
    let text: String
    let icon: UIImage?
    let iconSignal: Signal<UIImage?, NoError>?
    let hasArrow: Bool
    let action: (() -> Void)?
    
    init(id: AnyHashable, label: Label = .none, additionalBadgeLabel: String? = nil, additionalBadgeIcon: UIImage? = nil, text: String, icon: UIImage? = nil, iconSignal: Signal<UIImage?, NoError>? = nil, hasArrow: Bool = true, action: (() -> Void)?) {
        self.id = id
        self.label = label
        self.additionalBadgeLabel = additionalBadgeLabel
        self.additionalBadgeIcon = additionalBadgeIcon
        self.text = text
        self.icon = icon
        self.iconSignal = iconSignal
        self.hasArrow = hasArrow
        self.action = action
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenDisclosureItemNode()
    }
}

private final class PeerInfoScreenDisclosureItemNode: PeerInfoScreenItemNode {
    private let selectionNode: PeerInfoScreenSelectableBackgroundNode
    private let maskNode: ASImageNode
    private let iconNode: ASImageNode
    private let labelBadgeNode: ASImageNode
    private let labelNode: ImmediateTextNodeWithEntities
    private var additionalLabelNode: ImmediateTextNode?
    private var additionalLabelBadgeNode: ASImageNode?
    private let textNode: ImmediateTextNode
    private let arrowNode: ASImageNode
    private let bottomSeparatorNode: ASDisplayNode
    private let activateArea: AccessibilityAreaNode
    
    private var iconDisposable = MetaDisposable()
    
    private var item: PeerInfoScreenDisclosureItem?
    
    override init() {
        var bringToFrontForHighlightImpl: (() -> Void)?
        self.selectionNode = PeerInfoScreenSelectableBackgroundNode(bringToFrontForHighlight: { bringToFrontForHighlightImpl?() })
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displaysAsynchronously = false
        
        self.labelBadgeNode = ASImageNode()
        self.labelBadgeNode.displayWithoutProcessing = true
        self.labelBadgeNode.displaysAsynchronously = false
        self.labelBadgeNode.isLayerBacked = true
        
        self.labelNode = ImmediateTextNodeWithEntities()
        self.labelNode.displaysAsynchronously = false
        self.labelNode.isUserInteractionEnabled = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
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
        self.addSubnode(self.labelNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.arrowNode)
        self.addSubnode(self.activateArea)
    }
    
    deinit {
        self.iconDisposable.dispose()
    }
    
    override func update(context: AccountContext, width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenDisclosureItem else {
            return 10.0
        }
        
        let previousItem = self.item
        self.item = item
        
        self.selectionNode.pressed = item.action
        
        let sideInset: CGFloat = 16.0 + safeInsets.left
        let leftInset = (item.icon == nil && item.iconSignal == nil ? sideInset : sideInset + 29.0 + 16.0)
        let rightInset = sideInset + (item.hasArrow ? 18.0 : 0.0)
        let separatorInset = item.icon == nil && item.iconSignal == nil ? sideInset : leftInset - 1.0
        let titleFont = Font.regular(presentationData.listsFontSize.itemListBaseFontSize)
        
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let textColorValue: UIColor = presentationData.theme.list.itemPrimaryTextColor
        let labelColorValue: UIColor
        let labelFont: UIFont
        if case let .semitransparentBadge(_, color) = item.label {
            labelColorValue = color
            labelFont = Font.semibold(14.0)
        } else if case .badge = item.label {
            labelColorValue = presentationData.theme.list.itemCheckColors.foregroundColor
            labelFont = Font.regular(15.0)
        } else if case .titleBadge = item.label {
            labelColorValue = presentationData.theme.list.itemCheckColors.foregroundColor
            labelFont = Font.medium(11.0)
        } else if case .labelBadge = item.label {
            labelColorValue = presentationData.theme.list.itemCheckColors.foregroundColor
            labelFont = Font.medium(12.0)
        } else if case let .coloredText(_, color) = item.label {
            switch color {
            case .generic:
                labelColorValue = presentationData.theme.list.itemSecondaryTextColor
            case .accent:
                labelColorValue = presentationData.theme.list.itemAccentColor
            }
            labelFont = titleFont
        } else {
            labelColorValue = presentationData.theme.list.itemSecondaryTextColor
            labelFont = titleFont
        }
        
        self.labelNode.arguments = TextNodeWithEntities.Arguments(
            context: context,
            cache: context.animationCache,
            renderer: context.animationRenderer,
            placeholderColor: .clear,
            attemptSynchronous: true
        )
        
        if case let .attributedText(text) = item.label {
            self.labelNode.attributedText = text
        } else {
            self.labelNode.attributedText = NSAttributedString(string: item.label.text, font: labelFont, textColor: labelColorValue)
        }
        self.textNode.maximumNumberOfLines = 1
        self.textNode.attributedText = NSAttributedString(string: item.text, font: titleFont, textColor: textColorValue)
        
        let textSize = self.textNode.updateLayout(CGSize(width: width - (leftInset + rightInset), height: .greatestFiniteMagnitude))
        var labelConstrainWidth = width - textSize.width - (leftInset + rightInset)
        if case .semitransparentBadge = item.label {
            labelConstrainWidth -= 16.0
        }
        let labelSize = self.labelNode.updateLayout(CGSize(width: labelConstrainWidth, height: .greatestFiniteMagnitude))
        
        let textFrame = CGRect(origin: CGPoint(x: leftInset, y: 12.0), size: textSize)
        
        let height = textSize.height + 24.0
        
        if item.icon != nil || item.iconSignal != nil {
            if self.iconNode.supernode == nil {
                self.addSubnode(self.iconNode)
            }
            let iconSize: CGSize
            if let icon = item.icon {
                self.iconNode.image = icon
                iconSize = icon.size
            } else if let iconSignal = item.iconSignal {
                if previousItem?.text != item.text {
                    self.iconNode.image = nil
                    self.iconDisposable.set((iconSignal
                    |> deliverOnMainQueue).startStrict(next: { [weak self] icon in
                        if let self {
                            self.iconNode.image = icon
                        }
                    }))
                }
                iconSize = CGSize(width: 29.0, height: 29.0)
            } else {
                iconSize = CGSize(width: 29.0, height: 29.0)
            }
            let iconFrame = CGRect(origin: CGPoint(x: sideInset, y: floorToScreenPixels((height - iconSize.height) / 2.0)), size: iconSize)
            transition.updateFrame(node: self.iconNode, frame: iconFrame)
        } else if self.iconNode.supernode != nil {
            self.iconNode.image = nil
            self.iconNode.removeFromSupernode()
        }
        
        if item.hasArrow, let arrowImage = PresentationResourcesItemList.disclosureArrowImage(presentationData.theme) {
            self.arrowNode.image = arrowImage
            let arrowFrame = CGRect(origin: CGPoint(x: width - 7.0 - arrowImage.size.width - safeInsets.right, y: floorToScreenPixels((height - arrowImage.size.height) / 2.0)), size: arrowImage.size)
            transition.updateFrame(node: self.arrowNode, frame: arrowFrame)
        }
        
        var badgeDiameter: CGFloat = 20.0
        if case let .image(image, imageSize) = item.label {
            self.labelBadgeNode.image = image
            badgeDiameter = imageSize.height
            if self.labelBadgeNode.supernode == nil {
                self.insertSubnode(self.labelBadgeNode, belowSubnode: self.labelNode)
            }
        } else if case let .semitransparentBadge(text, badgeColor) = item.label, !text.isEmpty {
            badgeDiameter = 24.0
            if previousItem?.label.badgeColor != badgeColor {
                self.labelBadgeNode.image = generateStretchableFilledCircleImage(diameter: badgeDiameter, color: badgeColor.withAlphaComponent(0.1))
            }
            if self.labelBadgeNode.supernode == nil {
                self.insertSubnode(self.labelBadgeNode, belowSubnode: self.labelNode)
            }
        } else if case let .badge(text, badgeColor) = item.label, !text.isEmpty {
            if previousItem?.label.badgeColor != badgeColor {
                self.labelBadgeNode.image = generateStretchableFilledCircleImage(diameter: badgeDiameter, color: badgeColor)
            }
            if self.labelBadgeNode.supernode == nil {
                self.insertSubnode(self.labelBadgeNode, belowSubnode: self.labelNode)
            }
        } else if case let .titleBadge(text, badgeColor) = item.label, !text.isEmpty {
            if previousItem?.label.badgeColor != badgeColor {
                self.labelBadgeNode.image = generateFilledRoundedRectImage(size: CGSize(width: 16.0, height: 16.0), cornerRadius: 5.0, color: badgeColor)?.stretchableImage(withLeftCapWidth: 6, topCapHeight: 6)
            }
            if self.labelBadgeNode.supernode == nil {
                self.insertSubnode(self.labelBadgeNode, belowSubnode: self.labelNode)
            }
        } else if case let .labelBadge(text) = item.label, !text.isEmpty {
            let badgeColor = presentationData.theme.list.itemCheckColors.fillColor
            if previousItem?.label.badgeColor != badgeColor {
                self.labelBadgeNode.image = generateFilledRoundedRectImage(size: CGSize(width: 16.0, height: 16.0), cornerRadius: 5.0, color: badgeColor)?.stretchableImage(withLeftCapWidth: 6, topCapHeight: 6)
            }
            if self.labelBadgeNode.supernode == nil {
                self.insertSubnode(self.labelBadgeNode, belowSubnode: self.labelNode)
            }
        } else {
            self.labelBadgeNode.removeFromSupernode()
        }
        
        if item.additionalBadgeLabel != nil {
            if previousItem?.additionalBadgeLabel == nil {
                let additionalLabelBadgeNode: ASImageNode
                if let current = self.additionalLabelBadgeNode {
                    additionalLabelBadgeNode = current
                } else {
                    additionalLabelBadgeNode = ASImageNode()
                    additionalLabelBadgeNode.isUserInteractionEnabled = false
                    self.additionalLabelBadgeNode = additionalLabelBadgeNode
                    self.insertSubnode(additionalLabelBadgeNode, belowSubnode: self.labelNode)
                }
                additionalLabelBadgeNode.image = generateFilledRoundedRectImage(size: CGSize(width: 16.0, height: 16.0), cornerRadius: 5.0, color: presentationData.theme.list.itemCheckColors.fillColor)?.stretchableImage(withLeftCapWidth: 6, topCapHeight: 6)
            }
        }
        
        if let additionalBadgeIcon = item.additionalBadgeIcon {
            let additionalLabelBadgeNode: ASImageNode
            if let current = self.additionalLabelBadgeNode {
                additionalLabelBadgeNode = current
            } else {
                additionalLabelBadgeNode = ASImageNode()
                additionalLabelBadgeNode.isUserInteractionEnabled = false
                self.additionalLabelBadgeNode = additionalLabelBadgeNode
                self.insertSubnode(additionalLabelBadgeNode, belowSubnode: self.labelNode)
            }
            additionalLabelBadgeNode.image = additionalBadgeIcon
        } else if item.additionalBadgeLabel == nil {
            if let additionalLabelBadgeNode = self.additionalLabelBadgeNode {
                self.additionalLabelBadgeNode = nil
                additionalLabelBadgeNode.removeFromSupernode()
            }
        }
        
        var badgeWidth = max(badgeDiameter, labelSize.width + 10.0)
        if case .semitransparentBadge = item.label {
            badgeWidth += 2.0
        }
        let labelFrame: CGRect
        if case .semitransparentBadge = item.label {
            labelFrame = CGRect(origin: CGPoint(x: width - rightInset - badgeWidth + (badgeWidth - labelSize.width) / 2.0, y: floor((height - labelSize.height) / 2.0)), size: labelSize)
        } else if case .badge = item.label {
            labelFrame = CGRect(origin: CGPoint(x: width - rightInset - badgeWidth + (badgeWidth - labelSize.width) / 2.0, y: floor((height - labelSize.height) / 2.0)), size: labelSize)
        } else if case .titleBadge = item.label {
            labelFrame = CGRect(origin: CGPoint(x: textFrame.maxX + 10.0, y: floor((height - labelSize.height) / 2.0) + 1.0), size: labelSize)
        } else if case .labelBadge = item.label {
            labelFrame = CGRect(origin: CGPoint(x: width - rightInset - badgeWidth + (badgeWidth - labelSize.width) / 2.0, y: floor((height - labelSize.height) / 2.0)), size: labelSize)
        } else {
            labelFrame = CGRect(origin: CGPoint(x: width - rightInset - labelSize.width, y: 12.0), size: labelSize)
        }
        
        if let additionalBadgeLabel = item.additionalBadgeLabel {
            let additionalLabelNode: ImmediateTextNode
            if let current = self.additionalLabelNode {
                additionalLabelNode = current
            } else {
                additionalLabelNode = ImmediateTextNode()
                additionalLabelNode.isUserInteractionEnabled = false
                self.additionalLabelNode = additionalLabelNode
                self.addSubnode(additionalLabelNode)
            }
            
            additionalLabelNode.attributedText = NSAttributedString(string: additionalBadgeLabel, font: Font.medium(11.0), textColor: presentationData.theme.list.itemCheckColors.foregroundColor)
            let additionalLabelSize = additionalLabelNode.updateLayout(CGSize(width: labelConstrainWidth, height: .greatestFiniteMagnitude))
            additionalLabelNode.frame = CGRect(origin: CGPoint(x: textFrame.maxX + 10.0, y: floor((height - additionalLabelSize.height) / 2.0) + 1.0), size: additionalLabelSize)
        } else if let additionalLabelNode = self.additionalLabelNode {
            self.additionalLabelNode = nil
            additionalLabelNode.removeFromSupernode()
        }
        
        if let additionalLabelBadgeNode = self.additionalLabelBadgeNode, let image = additionalLabelBadgeNode.image {
            if item.additionalBadgeLabel != nil, let additionalLabelNode = self.additionalLabelNode {
                additionalLabelBadgeNode.frame = additionalLabelNode.frame.insetBy(dx: -4.0, dy: -2.0 + UIScreenPixel)
            } else {
                let additionalLabelSize = image.size
                additionalLabelBadgeNode.frame = CGRect(origin: CGPoint(x: textFrame.maxX + 6.0, y: floor((height - additionalLabelSize.height) / 2.0) + 1.0), size: additionalLabelSize)
            }
        }
        
        let labelBadgeNodeFrame: CGRect
        if case let .image(_, imageSize) = item.label {
            labelBadgeNodeFrame = CGRect(origin: CGPoint(x: width - rightInset - imageSize.width, y: floorToScreenPixels(textFrame.midY - imageSize.height / 2.0)), size: imageSize)
        } else if case .titleBadge = item.label {
            labelBadgeNodeFrame = labelFrame.insetBy(dx: -4.0, dy: -2.0 + UIScreenPixel)
        } else if case .labelBadge = item.label {
            labelBadgeNodeFrame = labelFrame.insetBy(dx: -4.0, dy: -2.0 + UIScreenPixel)
        } else if let additionalLabelNode = self.additionalLabelNode {
            labelBadgeNodeFrame = additionalLabelNode.frame.insetBy(dx: -4.0, dy: -2.0 + UIScreenPixel)
        } else {
            labelBadgeNodeFrame = CGRect(origin: CGPoint(x: width - rightInset - badgeWidth, y: floorToScreenPixels(labelFrame.midY - badgeDiameter / 2.0)), size: CGSize(width: badgeWidth, height: badgeDiameter))
        }
        
        self.activateArea.accessibilityLabel = item.text
        self.activateArea.accessibilityValue = item.label.text
        
        transition.updateFrame(node: self.labelBadgeNode, frame: labelBadgeNodeFrame)
        if self.labelNode.bounds.size != labelFrame.size {
            self.labelNode.frame = labelFrame
        } else {
            transition.updateFrame(node: self.labelNode, frame: labelFrame)
        }
        transition.updateFrame(node: self.textNode, frame: textFrame)
        
        let hasCorners = hasCorners && (topItem == nil || bottomItem == nil)
        let hasTopCorners = hasCorners && topItem == nil
        let hasBottomCorners = hasCorners && bottomItem == nil
        
        self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
        self.maskNode.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))
        self.bottomSeparatorNode.isHidden = hasBottomCorners
        
        let highlightNodeOffset: CGFloat = topItem == nil ? 0.0 : UIScreenPixel
        self.selectionNode.update(size: CGSize(width: width, height: height + highlightNodeOffset), theme: presentationData.theme, transition: transition)
        transition.updateFrame(node: self.selectionNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -highlightNodeOffset), size: CGSize(width: width, height: height + highlightNodeOffset)))
        
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: separatorInset, y: height - UIScreenPixel), size: CGSize(width: width - separatorInset, height: UIScreenPixel)))
        transition.updateAlpha(node: self.bottomSeparatorNode, alpha: bottomItem == nil ? 0.0 : 1.0)
        
        self.activateArea.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))
        
        return height
    }
}

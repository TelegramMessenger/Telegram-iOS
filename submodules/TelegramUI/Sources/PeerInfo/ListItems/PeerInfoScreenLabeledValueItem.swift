import AsyncDisplayKit
import Display
import TelegramPresentationData
import AccountContext
import TextFormat
import UIKit
import AppBundle
import TelegramStringFormatting

enum PeerInfoScreenLabeledValueTextColor {
    case primary
    case accent
}

enum PeerInfoScreenLabeledValueTextBehavior: Equatable {
    case singleLine
    case multiLine(maxLines: Int, enabledEntities: EnabledEntityTypes)
}

enum PeerInfoScreenLabeledValueIcon {
    case qrCode
}

final class PeerInfoScreenLabeledValueItem: PeerInfoScreenItem {
    let id: AnyHashable
    let label: String
    let text: String
    let textColor: PeerInfoScreenLabeledValueTextColor
    let textBehavior: PeerInfoScreenLabeledValueTextBehavior
    let icon: PeerInfoScreenLabeledValueIcon?
    let action: (() -> Void)?
    let longTapAction: ((ASDisplayNode) -> Void)?
    let linkItemAction: ((TextLinkItemActionType, TextLinkItem) -> Void)?
    let iconAction: (() -> Void)?
    let requestLayout: () -> Void
    
    init(
        id: AnyHashable,
        label: String,
        text: String,
        textColor: PeerInfoScreenLabeledValueTextColor = .primary,
        textBehavior: PeerInfoScreenLabeledValueTextBehavior = .singleLine,
        icon: PeerInfoScreenLabeledValueIcon? = nil,
        action: (() -> Void)?,
        longTapAction: ((ASDisplayNode) -> Void)? = nil,
        linkItemAction: ((TextLinkItemActionType, TextLinkItem) -> Void)? = nil,
        iconAction: (() -> Void)? = nil,
        requestLayout: @escaping () -> Void
    ) {
        self.id = id
        self.label = label
        self.text = text
        self.textColor = textColor
        self.textBehavior = textBehavior
        self.icon = icon
        self.action = action
        self.longTapAction = longTapAction
        self.linkItemAction = linkItemAction
        self.iconAction = iconAction
        self.requestLayout = requestLayout
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenLabeledValueItemNode()
    }
}

private func generateExpandBackground(size: CGSize, color: UIColor) -> UIImage? {
    return generateImage(size, rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        var locations: [CGFloat] = [0.0, 1.0]
        let colors: [CGColor] = [color.withAlphaComponent(0.0).cgColor, color.cgColor]
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 40.0, y: size.height), options: CGGradientDrawingOptions())
        context.setFillColor(color.cgColor)
        context.fill(CGRect(origin: CGPoint(x: 40.0, y: 0.0), size: CGSize(width: size.width - 40.0, height: size.height)))
    })
}

private final class PeerInfoScreenLabeledValueItemNode: PeerInfoScreenItemNode {
    private let selectionNode: PeerInfoScreenSelectableBackgroundNode
    private let maskNode: ASImageNode
    private let labelNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let bottomSeparatorNode: ASDisplayNode
    
    private let expandBackgroundNode: ASImageNode
    private let expandNode: ImmediateTextNode
    private let expandButonNode: HighlightTrackingButtonNode
    
    private let iconNode: ASImageNode
    private let iconButtonNode: HighlightTrackingButtonNode
    
    private var linkHighlightingNode: LinkHighlightingNode?
    
    private let activateArea: AccessibilityAreaNode
    
    private var item: PeerInfoScreenLabeledValueItem?
    private var theme: PresentationTheme?
    
    private var isExpanded: Bool = false
    
    override init() {
        var bringToFrontForHighlightImpl: (() -> Void)?
        self.selectionNode = PeerInfoScreenSelectableBackgroundNode(bringToFrontForHighlight: { bringToFrontForHighlightImpl?() })
        self.selectionNode.isUserInteractionEnabled = false
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.labelNode = ImmediateTextNode()
        self.labelNode.displaysAsynchronously = false
        self.labelNode.isUserInteractionEnabled = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
        
        self.expandBackgroundNode = ASImageNode()
        self.expandBackgroundNode.displaysAsynchronously = false
        
        self.expandNode = ImmediateTextNode()
        self.expandNode.displaysAsynchronously = false
        self.expandNode.isUserInteractionEnabled = false
        
        self.expandButonNode = HighlightTrackingButtonNode()
        
        self.iconNode = ASImageNode()
        self.iconNode.contentMode = .center
        self.iconNode.displaysAsynchronously = false
        
        self.iconButtonNode = HighlightTrackingButtonNode()
        
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
        
        self.addSubnode(self.expandBackgroundNode)
        self.addSubnode(self.expandNode)
        self.addSubnode(self.expandButonNode)
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.iconButtonNode)
        
        self.addSubnode(self.activateArea)
        
        self.expandButonNode.addTarget(self, action: #selector(self.expandPressed), forControlEvents: .touchUpInside)
        self.expandButonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.expandNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.expandNode.alpha = 0.4
                } else {
                    strongSelf.expandNode.alpha = 1.0
                    strongSelf.expandNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.iconButtonNode.addTarget(self, action: #selector(self.iconPressed), forControlEvents: .touchUpInside)
        self.iconButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.iconNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.iconNode.alpha = 0.4
                } else {
                    strongSelf.iconNode.alpha = 1.0
                    strongSelf.iconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    @objc private func expandPressed() {
        self.isExpanded = true
        self.item?.requestLayout()
    }
    
    @objc private func iconPressed() {
        self.item?.iconAction?()
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { [weak self] point in
            guard let strongSelf = self, let item = strongSelf.item else {
                return .keepWithSingleTap
            }
            if !strongSelf.iconButtonNode.isHidden, strongSelf.iconButtonNode.view.hitTest(strongSelf.view.convert(point, to: strongSelf.iconButtonNode.view), with: nil) != nil {
                return .fail
            }
            if !strongSelf.expandButonNode.isHidden, strongSelf.expandButonNode.view.hitTest(strongSelf.view.convert(point, to: strongSelf.expandButonNode.view), with: nil) != nil {
                return .fail
            }
            if let _ = strongSelf.linkItemAtPoint(point) {
                return .waitForSingleTap
            }
            if item.longTapAction != nil {
                return .waitForSingleTap
            }
            if item.action != nil {
                return .keepWithSingleTap
            }
            return .fail
        }
        recognizer.highlight = { [weak self] point in
            guard let strongSelf = self else {
                return
            }
            if !strongSelf.iconButtonNode.isHidden, let point = point, strongSelf.iconButtonNode.frame.contains(point) {
            } else {
                strongSelf.updateTouchesAtPoint(point)
            }
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    @objc private func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                switch gesture {
                case .tap, .longTap:
                    if let item = self.item {
                        if let linkItem = self.linkItemAtPoint(location) {
                            item.linkItemAction?(gesture == .tap ? .tap : .longTap, linkItem)
                        } else if case .longTap = gesture {
                            item.longTapAction?(self)
                        } else if case .tap = gesture {
                            item.action?()
                        }
                    }
                default:
                    break
                }
            }
        default:
            break
        }
    }
    
    override func update(width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenLabeledValueItem else {
            return 10.0
        }
        
        self.item = item
        self.theme = presentationData.theme
        
        self.selectionNode.pressed = item.action
        
        let sideInset: CGFloat = 16.0 + safeInsets.left
        
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let textColorValue: UIColor
        switch item.textColor {
        case .primary:
            textColorValue = presentationData.theme.list.itemPrimaryTextColor
        case .accent:
            textColorValue = presentationData.theme.list.itemAccentColor
        }
        
        self.expandNode.attributedText = NSAttributedString(string: presentationData.strings.PeerInfo_BioExpand, font: Font.regular(17.0), textColor: presentationData.theme.list.itemAccentColor)
        let expandSize = self.expandNode.updateLayout(CGSize(width: width, height: 100.0))
        
        self.labelNode.attributedText = NSAttributedString(string: item.label, font: Font.regular(14.0), textColor: presentationData.theme.list.itemPrimaryTextColor)
        
        var text = item.text
        let maxNumberOfLines: Int
        switch item.textBehavior {
        case .singleLine:
            maxNumberOfLines = 1
            self.textNode.maximumNumberOfLines = maxNumberOfLines
            self.textNode.cutout = nil
            self.textNode.attributedText = NSAttributedString(string: item.text, font: Font.regular(17.0), textColor: textColorValue)
        case let .multiLine(maxLines, enabledEntities):
            if !self.isExpanded {
                text = trimToLineCount(text, lineCount: 3)
            }
            
            maxNumberOfLines = self.isExpanded ? maxLines : 3
            self.textNode.maximumNumberOfLines = maxNumberOfLines
            if enabledEntities.isEmpty {
                self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(17.0), textColor: textColorValue)
            } else {
                let fontSize: CGFloat = 17.0
                
                let baseFont = Font.regular(fontSize)
                let linkFont = baseFont
                let boldFont = Font.medium(fontSize)
                let italicFont = Font.italic(fontSize)
                let boldItalicFont = Font.semiboldItalic(fontSize)
                let titleFixedFont = Font.monospace(fontSize)
                
                let entities = generateTextEntities(text, enabledTypes: enabledEntities)
                self.textNode.attributedText = stringWithAppliedEntities(text, entities: entities, baseColor: textColorValue, linkColor: presentationData.theme.list.itemAccentColor, baseFont: baseFont, linkFont: linkFont, boldFont: boldFont, italicFont: italicFont, boldItalicFont: boldItalicFont, fixedFont: titleFixedFont, blockQuoteFont: baseFont)
            }
        }
        
        if let icon = item.icon {
            let iconImage: UIImage?
            switch icon {
            case .qrCode:
                iconImage = UIImage(bundleImageName: "Settings/QrIcon")
            }
            self.iconNode.image = generateTintedImage(image: iconImage, color: presentationData.theme.list.itemAccentColor)
            self.iconNode.isHidden = false
            self.iconButtonNode.isHidden = false
        } else {
            self.iconNode.isHidden = true
            self.iconButtonNode.isHidden = true
        }
        
        let additionalSideInset: CGFloat = !self.iconNode.isHidden ? 32.0 : 0.0
        let labelSize = self.labelNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: .greatestFiniteMagnitude))
        let textLayout = self.textNode.updateLayoutInfo(CGSize(width: width - sideInset * 2.0 - additionalSideInset, height: .greatestFiniteMagnitude))
        let textSize = textLayout.size
        
        var displayMore = false
        if !self.isExpanded {
            if textLayout.truncated || text.count < item.text.count {
                displayMore = true
            }
        }
        
        if case .multiLine = item.textBehavior, displayMore {
            self.expandBackgroundNode.isHidden = false
            self.expandNode.isHidden = false
            self.expandButonNode.isHidden = false
        } else {
            self.expandBackgroundNode.isHidden = true
            self.expandNode.isHidden = true
            self.expandButonNode.isHidden = true
        }
        
        let labelFrame = CGRect(origin: CGPoint(x: sideInset, y: 11.0), size: labelSize)
        let textFrame = CGRect(origin: CGPoint(x: sideInset, y: labelFrame.maxY + 3.0), size: textSize)
        
        let expandFrame = CGRect(origin: CGPoint(x: width - safeInsets.right - expandSize.width - 14.0 - UIScreenPixel, y: textFrame.maxY - expandSize.height), size: expandSize)
        self.expandNode.frame = expandFrame
        self.expandButonNode.frame = expandFrame.insetBy(dx: -8.0, dy: -8.0)
        
        var expandBackgroundFrame = expandFrame
        expandBackgroundFrame.origin.x -= 50.0
        expandBackgroundFrame.size.width += 50.0
        self.expandBackgroundNode.frame = expandBackgroundFrame
        self.expandBackgroundNode.image = generateExpandBackground(size: expandBackgroundFrame.size, color: presentationData.theme.list.itemBlocksBackgroundColor)
        
        transition.updateFrame(node: self.labelNode, frame: labelFrame)
        transition.updateFrame(node: self.textNode, frame: textFrame)
        
        let height = labelSize.height + 3.0 + textSize.height + 22.0
        
        let iconButtonFrame = CGRect(x: width - safeInsets.right - height, y: 0.0, width: height, height: height)
        transition.updateFrame(node: self.iconButtonNode, frame: iconButtonFrame)
        if let iconSize = self.iconNode.image?.size {
            transition.updateFrame(node: self.iconNode, frame: CGRect(origin: CGPoint(x: width - safeInsets.right - sideInset - iconSize.width + 5.0, y: floorToScreenPixels((height - iconSize.height) / 2.0)), size: iconSize))
        }
        
        let highlightNodeOffset: CGFloat = topItem == nil ? 0.0 : UIScreenPixel
        self.selectionNode.update(size: CGSize(width: width, height: height + highlightNodeOffset), theme: presentationData.theme, transition: transition)
        transition.updateFrame(node: self.selectionNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -highlightNodeOffset), size: CGSize(width: width, height: height + highlightNodeOffset)))
        
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: sideInset, y: height - UIScreenPixel), size: CGSize(width: width - sideInset, height: UIScreenPixel)))
        transition.updateAlpha(node: self.bottomSeparatorNode, alpha: bottomItem == nil ? 0.0 : 1.0)
        
        let hasCorners = hasCorners && (topItem == nil || bottomItem == nil)
        let hasTopCorners = hasCorners && topItem == nil
        let hasBottomCorners = hasCorners && bottomItem == nil
        
        self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
        self.maskNode.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))
        self.bottomSeparatorNode.isHidden = hasBottomCorners
        
        self.activateArea.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: height))
        self.activateArea.accessibilityLabel = item.label
        self.activateArea.accessibilityValue = item.text
        
        return height
    }
    
    private func linkItemAtPoint(_ point: CGPoint) -> TextLinkItem? {
        let textNodeFrame = self.textNode.frame
        if let (_, attributes) = self.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                return .url(url: url, concealed: false)
            } else if let peerName = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                return .mention(peerName)
            } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                return .hashtag(hashtag.peerName, hashtag.hashtag)
            } else {
                return nil
            }
        }
        return nil
    }
    
    private func updateTouchesAtPoint(_ point: CGPoint?) {
        guard let item = self.item, let theme = self.theme else {
            return
        }
        var rects: [CGRect]?
        if let point = point {
            let textNodeFrame = self.textNode.frame
            if let (index, attributes) = self.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
                let possibleNames: [String] = [
                    TelegramTextAttributes.URL,
                    TelegramTextAttributes.PeerMention,
                    TelegramTextAttributes.PeerTextMention,
                    TelegramTextAttributes.BotCommand,
                    TelegramTextAttributes.Hashtag
                ]
                for name in possibleNames {
                    if let _ = attributes[NSAttributedString.Key(rawValue: name)] {
                        rects = self.textNode.attributeRects(name: name, at: index)
                        break
                    }
                }
            }
        }
        
        if let rects = rects {
            let linkHighlightingNode: LinkHighlightingNode
            if let current = self.linkHighlightingNode {
                linkHighlightingNode = current
            } else {
                linkHighlightingNode = LinkHighlightingNode(color: theme.list.itemAccentColor.withAlphaComponent(0.5))
                self.linkHighlightingNode = linkHighlightingNode
                self.insertSubnode(linkHighlightingNode, belowSubnode: self.textNode)
            }
            linkHighlightingNode.frame = self.textNode.frame
            linkHighlightingNode.updateRects(rects)
        } else if let linkHighlightingNode = self.linkHighlightingNode {
            self.linkHighlightingNode = nil
            linkHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak linkHighlightingNode] _ in
                linkHighlightingNode?.removeFromSupernode()
            })
        }
        
        if point != nil && rects == nil && item.action != nil {
            self.selectionNode.updateIsHighlighted(true)
        } else {
            self.selectionNode.updateIsHighlighted(false)
        }
    }
}
